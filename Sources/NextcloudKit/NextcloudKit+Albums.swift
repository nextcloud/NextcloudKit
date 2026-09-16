// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON
import SwiftyXMLParser

public extension NextcloudKit {
    func fetchAllAlbums(
        for account: String,
        options: NKRequestOptions = NKRequestOptions(),
        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
        completion: @escaping (Result<[NKPhotoAlbum], Error>) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(
                serverUrl: nkSession.urlBase,
                endpoint: nkSession.urlBase + "/remote.php/dav/photos/" + nkSession.userId + "/albums/"
              ),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return completion(.failure(NKError.urlError))
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
            return completion(.failure(NKError(error: error)))
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                completion(.failure(error))

            case .success:
                guard let data = response.data else {
                    return completion(.failure(NKError.invalidData))
                }

                let albums = self.parseAlbumsXML(account: account, data: data)
                completion(.success(albums))
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
              let url = nkCommonInstance.createStandardUrl(
                serverUrl: nkSession.urlBase,
                endpoint: nkSession.urlBase + "/remote.php/dav/photos/" + nkSession.userId + "/albums/\(albumName)/"
              ),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return completion(.failure(NKError.urlError))
        }
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: HTTPMethod(rawValue: "MKCOL"), headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return completion(.failure(NKError(error: error)))
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                completion(.failure(error))

            case .success:
                completion(.success(account))
            }
        }
    }

    func fetchAlbumPhotos(
        for album: String,
        account: String,
        options: NKRequestOptions = NKRequestOptions(),
        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
        completion: @escaping (Result<[NKFile], Error>) -> Void
    ) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(
                serverUrl: nkSession.urlBase,
                endpoint: nkSession.urlBase + "/remote.php/dav/photos/" + nkSession.userId + "/albums/" + album + "/"
              ),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/xml", accept: "application/xml") else {
            return completion(.failure(NKError.urlError))
        }
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: HTTPMethod(rawValue: "PROPFIND"), headers: headers)
            urlRequest.httpBody = NKDataFileXML(nkCommonInstance: self.nkCommonInstance).getRequestBodyFile(createProperties: options.createProperties, removeProperties: options.removeProperties).data(using: .utf8)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return completion(.failure(NKError(error: error)))
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                completion(.failure(error))

            case .success:
                guard let data = response.data else {
                    return options.queue.async {
                        completion(.failure(NKError.invalidData))
                    }
                }
                Task {
                    let files = await NKDataFileXML(nkCommonInstance: self.nkCommonInstance).convertDataFile(xmlData: data, nkSession: nkSession, rootFileName: self.nkCommonInstance.rootFileName, showHiddenFiles: true, includeHiddenFiles: [])
                    completion(.success(files))
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
                return completion(.failure(NKError.urlError))
            }
            let destinationPath = "/remote.php/dav/photos/" + nkSession.userId + "/albums/" + albumName + "/" + fileName
            let sourceUrlString: String = {
                if sourcePath.lowercased().hasPrefix("http") {
                    return sourcePath
                } else {
                    return nkSession.urlBase + sourcePath
                }
            }()
            guard let sourceUrl = sourceUrlString.encodedToUrl else {
                return completion(.failure(NKError.urlError))
            }

            headers.add(
                name: "Destination",
                value: destinationPath.urlEncoded ?? destinationPath
            )

            var urlRequest: URLRequest
            do {
                try urlRequest = URLRequest(url: sourceUrl, method: .init(rawValue: "COPY"), headers: headers)
                urlRequest.timeoutInterval = options.timeout
            } catch {
                return completion(.failure(NKError(error: error)))
            }

            nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)
                    completion(.failure(error))

                case .success:
                    completion(.success((account)))
                }
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
              let url = nkCommonInstance.createStandardUrl(
                serverUrl: nkSession.urlBase,
                endpoint: nkSession.urlBase + "/remote.php/dav/photos/" + nkSession.userId + "/albums/" + albumName + "/" + fileName
              ),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return completion(.failure(NKError.urlError))
        }

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: .delete, headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return completion(.failure(NKError(error: error)))
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                completion(.failure(error))

            case .success:
                completion(.success((account)))
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

    func renameAlbum(
        account: String,
        from name: String,
        to newName: String,
        options: NKRequestOptions = NKRequestOptions(),
        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
        completion: @escaping (Result<String, Error>) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(
                serverUrl: nkSession.urlBase,
                endpoint: nkSession.urlBase + "/remote.php/dav/photos/" + nkSession.userId + "/albums/" + name + "/"
              ),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return completion(.failure(NKError.urlError))
        }
        let destinationHeader = "/remote.php/dav/photos/" + nkSession.userId + "/albums/" + newName + "/"

        // Add the required MOVE header
        headers.add(
            name: "Destination",
            value: destinationHeader.addingPercentEncoding(
                withAllowedCharacters: CharacterSet.urlQueryAllowed.subtracting(["+", "?", "&"])
            ) ?? destinationHeader
        )
        // Disallow overwriting an existing destination to avoid silent data loss
        headers.add(name: "Overwrite", value: "F")

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: .init(rawValue: "MOVE"), headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return completion(.failure(NKError(error: error)))
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                completion(.failure(error))

            case .success:
                completion(.success((account)))
            }
        }
    }

    // MARK: - Helper

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
