// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON
import SwiftyXMLParser

public extension NextcloudKit {

    // MARK: - Album

    func fetchAllAlbums(
        for account: String,
        options: NKRequestOptions = NKRequestOptions(),
        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
        completion: @escaping (Result<[NKPhotoAlbum], Error>) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let endpoint = albumEndpoint(userId: nkSession.userId),
              let url = nkCommonInstance.createStandardUrl(
                serverUrl: nkSession.urlBase,
                endpoint: endpoint
              ),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(.failure(NKError.urlError)) }
        }
        let propfindXML = """
        <?xml version="1.0"?>
        <d:propfind xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns" xmlns:nc="http://nextcloud.org/ns" xmlns:ocs="http://open-collaboration-services.org/ns">
            <d:prop>
                <nc:last-photo />
                <nc:nbItems />
                <nc:location />
                <nc:dateRange />
                <nc:collaborators />
            </d:prop>
        </d:propfind>
        """
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: HTTPMethod(rawValue: "PROPFIND"), headers: headers)
            urlRequest.httpBody = propfindXML.data(using: .utf8)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(.failure(NKError(error: error))) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(.failure(error)) }

            case .success:
                guard let data = response.data else {
                    return options.queue.async { completion(.failure(NKError.invalidData)) }
                }

                let albums = self.parseAlbumsXML(account: account, data: data)
                options.queue.async { completion(.success(albums)) }
            }
        }
    }

    func createNewAlbum(
        for account: String,
        albumName: String,
        options: NKRequestOptions = NKRequestOptions(),
        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
        completion: @escaping (Result<String, NKError>) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let endpoint = albumEndpoint(userId: nkSession.userId, albumName: albumName),
              let url = nkCommonInstance.createStandardUrl(
                serverUrl: nkSession.urlBase,
                endpoint: endpoint
              ),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(.failure(NKError.urlError)) }
        }
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: HTTPMethod(rawValue: "MKCOL"), headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(.failure(NKError(error: error))) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(.failure(error)) }

            case .success:
                options.queue.async { completion(.success(account)) }
            }
        }
    }

    func renameAlbum(
        account: String,
        from name: String,
        to newName: String,
        options: NKRequestOptions = NKRequestOptions(),
        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
        completion: @escaping (Result<String, Error>) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let endpoint = albumEndpoint(userId: nkSession.userId, albumName: name),
              let url = nkCommonInstance.createStandardUrl(
                serverUrl: nkSession.urlBase,
                endpoint: endpoint
              ),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(.failure(NKError.urlError)) }
        }
        guard let destinationEndpoint = albumEndpoint(userId: nkSession.userId, albumName: newName),
              let destinationUrl = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: destinationEndpoint),
              let destination = try? destinationUrl.asURL() else {
            return options.queue.async { completion(.failure(NKError.urlError)) }
        }

        // Add the required MOVE header
        headers.add(name: "Destination", value: destination.absoluteString)
        // Disallow overwriting an existing destination to avoid silent data loss
        headers.add(name: "Overwrite", value: "F")

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: .init(rawValue: "MOVE"), headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(.failure(NKError(error: error))) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(.failure(error)) }

            case .success:
                options.queue.async { completion(.success((account))) }
            }
        }
    }

    func deleteAlbum(
        albumName: String,
        account: String,
        options: NKRequestOptions = NKRequestOptions(),
        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
        completion: @escaping (Result<String, Error>) -> Void) {

        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let endpoint = albumEndpoint(userId: nkSession.userId, albumName: albumName),
              let url = nkCommonInstance.createStandardUrl(
                serverUrl: nkSession.urlBase,
                endpoint: endpoint
              ),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(.failure(NKError.urlError)) }
        }

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: .delete, headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(.failure(NKError(error: error))) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(.failure(error)) }

            case .success:
                options.queue.async { completion(.success((account))) }
            }
        }
    }

    // MARK: - Album Photo

    func fetchAlbumPhotos(
        for album: String,
        account: String,
        options: NKRequestOptions = NKRequestOptions(),
        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
        completion: @escaping (Result<[NKFile], Error>) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let endpoint = albumEndpoint(userId: nkSession.userId, albumName: album),
              let url = nkCommonInstance.createStandardUrl(
                serverUrl: nkSession.urlBase,
                endpoint: endpoint
              ),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/xml", accept: "application/xml") else {
            return options.queue.async { completion(.failure(NKError.urlError)) }
        }
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: HTTPMethod(rawValue: "PROPFIND"), headers: headers)
            urlRequest.httpBody = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).getRequestBodyFile(createProperties: options.createProperties, removeProperties: options.removeProperties).data(using: .utf8)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(.failure(NKError(error: error))) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(.failure(error)) }

            case .success:
                guard let data = response.data else {
                    return options.queue.async { completion(.failure(NKError.invalidData)) }
                }
                Task {
                    let files = await NKDataFileXML(nkCommonInstance: self.nkCommonInstance).convertDataFile(xmlData: data, nkSession: nkSession, rootFileName: self.nkCommonInstance.rootFileName, showHiddenFiles: true, includeHiddenFiles: [])
                    options.queue.async { completion(.success(files)) }
                }
            }
        }
    }

    func copyPhotoToAlbum(
        account: String,
        sourcePath: String,
        albumName: String,
        fileName: String,
        options: NKRequestOptions = NKRequestOptions(),
        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
        completion: @escaping (Result<String, Error>) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(.failure(NKError.urlError)) }
        }
        guard let destinationEndpoint = albumEndpoint(userId: nkSession.userId, albumName: albumName, fileName: fileName),
              let destinationUrl = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: destinationEndpoint),
              let destination = try? destinationUrl.asURL() else {
            return options.queue.async { completion(.failure(NKError.urlError)) }
        }
        let sourceUrlString: String = {
            if sourcePath.lowercased().hasPrefix("http") {
                return sourcePath
            } else {
                return nkSession.urlBase + sourcePath
            }
        }()
        guard let sourceUrl = sourceUrlString.encodedToUrl else {
            return options.queue.async { completion(.failure(NKError.urlError)) }
        }

        headers.add(
            name: "Destination",
            value: destination.absoluteString
        )

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: sourceUrl, method: .init(rawValue: "COPY"), headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(.failure(NKError(error: error))) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(.failure(error)) }

            case .success:
                options.queue.async { completion(.success((account))) }
            }
        }
    }

    func deletePhotoFromAlbum(albumName: String,
                              fileName: String,
                              account: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                              completion: @escaping (Result<String, Error>) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let endpoint = albumEndpoint(userId: nkSession.userId, albumName: albumName, fileName: fileName),
              let url = nkCommonInstance.createStandardUrl(
                serverUrl: nkSession.urlBase,
                endpoint: endpoint
              ),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(.failure(NKError.urlError)) }
        }

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: .delete, headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return options.queue.async { completion(.failure(NKError(error: error))) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(.failure(error)) }

            case .success:
                options.queue.async { completion(.success((account))) }
            }
        }
    }

    func deletePhotoFromAlbumAsync(
        albumName: String,
        fileName: String,
        account: String,
        options: NKRequestOptions = NKRequestOptions(),
        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            deletePhotoFromAlbum(
                albumName: albumName,
                fileName: fileName,
                account: account,
                options: options,
                taskHandler: taskHandler
            ) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - Helper

    // Encode each raw path component once, including literal percent signs and slashes.
    private func albumEndpoint(userId: String, albumName: String? = nil, fileName: String? = nil) -> String? {
        let allowedCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var components = ["remote.php", "dav", "photos", userId, "albums"]
        if let albumName { components.append(albumName) }
        if let fileName { components.append(fileName) }

        var encodedComponents: [String] = []
        for component in components {
            guard let encoded = component.addingPercentEncoding(withAllowedCharacters: allowedCharacters) else { return nil }
            encodedComponents.append(encoded)
        }
        return encodedComponents.joined(separator: "/") + (fileName == nil ? "/" : "")
    }

    private func parseAlbumsXML(account: String, data: Data) -> [NKPhotoAlbum] {
        let xml = XML.parse(data)
        var albums: [NKPhotoAlbum] = []
        let elements = xml["d:multistatus", "d:response"]

        for element in elements {
            let href = element["d:href"].element?.text ?? ""
            let prop = element["d:propstat"]["d:prop"]
            let lastPhoto = prop["nc:last-photo"].element?.text
            let nbItems = prop["nc:nbItems"].element?.text.flatMap { Int($0) }
            let location = prop["nc:location"].element?.text
            let dateRange = prop["nc:dateRange"].element?.text
            let collaborators = prop["nc:collaborators"].element?.text

            // Optionally skip entries with 404 status
            let status = element["d:propstat"]["d:status"].element?.text ?? ""
            if status.contains("200") {
                let album = NKPhotoAlbum(
                    account: account,
                    href: href,
                    lastPhotoId: lastPhoto,
                    itemCount: nbItems,
                    location: location,
                    dateRange: dateRange,
                    collaborators: collaborators
                )
                albums.append(album)
            }
        }

        return albums
    }
}
