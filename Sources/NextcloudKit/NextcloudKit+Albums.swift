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
        completion: @escaping (Result<[NKAlbumDTO], Error>) -> Void
    ) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(
                serverUrl: nkSession.urlBase,
                endpoint: nkSession.urlBase + "/remote.php/dav/photos/" + nkSession.userId + "/albums/"
              ),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return completion(.failure(NKError.urlError))
        }
        let method = HTTPMethod(rawValue: "PROPFIND")
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
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = propfindXML.data(using: .utf8)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return completion(.failure(NKError(error: error)))
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            // Explicit 404 check
            if response.response?.statusCode == 404 {
                return completion(.success([]))
            }

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                completion(.failure(error))

            case .success:
                guard let data = response.data else {
                    return completion(.failure(NKError.invalidData))
                }

                let albums = self.parseAlbumsXML(data: data)
                completion(.success(albums))
            }
        }
    }

    func createNewAlbum(
        for account: String,
        albumName: String,
        options: NKRequestOptions = NKRequestOptions(),
        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
        completion: @escaping (Result<Bool, NKError>) -> Void
    ) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(
                serverUrl: nkSession.urlBase,
                endpoint: nkSession.urlBase + "/remote.php/dav/photos/" + nkSession.userId + "/albums/\(albumName)/"
              ),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return completion(.failure(NKError.urlError))
        }
        let method = HTTPMethod(rawValue: "MKCOL")

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return completion(.failure(NKError(error: error)))
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            // Explicit 405 check -> treat as conflict (album already exists)
            if let statusCode = response.response?.statusCode, statusCode == 405 {
                // Resolve localized message so UI using `localizedDescription` shows the proper text
                let message = NSLocalizedString("_album_already_exists_", comment: "Album already exists")
                // Build an NSError carrying the localized description
                let nsError = NSError(domain: "NextcloudKit", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message])
                return completion(.failure(NKError(error: nsError)))
            }

            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                completion(.failure(error))

            case .success:
                completion(.success(true))
            }
        }
    }

    func fetchAlbumPhotos(
        for album: String,
        account: String,
        options: NKRequestOptions = NKRequestOptions(),
        taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
        completion: @escaping (Result<[NKAlbumPhotoDTO], Error>) -> Void
    ) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(
                serverUrl: nkSession.urlBase,
                endpoint: nkSession.urlBase + "/remote.php/dav/photos/" + nkSession.userId + "/albums/" + album + "/"
              ),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return completion(.failure(NKError.urlError))
        }
        let method = HTTPMethod(rawValue: "PROPFIND")

        let propfindXML = """
        <d:propfind xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns"
        xmlns:nc="http://nextcloud.org/ns" xmlns:ocs="http://open-collaborationservices.org/ns">
         <d:prop>
         <d:getcontentlength />
         <d:getcontenttype />
         <d:getetag />
         <d:getlastmodified />
         <d:resourcetype />
         <nc:metadata-photos-size />
         <nc:metadata-photos-original_date_time />
         <nc:metadata-files-live-photo />
         <nc:has-preview />
         <nc:hidden />
         <oc:favorite />
         <oc:fileid />
         <oc:permissions />
         </d:prop>
        </d:propfind>
        """

        var urlRequest: URLRequest
        do {
            try urlRequest = URLRequest(url: url, method: method, headers: headers)
            urlRequest.httpBody = propfindXML.data(using: .utf8)
            urlRequest.timeoutInterval = options.timeout
        } catch {
            return completion(.failure(NKError(error: error)))
        }

        nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            // Explicit 404 check
            if response.response?.statusCode == 404 {
                return completion(.success([]))
            }

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

                let photos = self.parseAlbumPhotosXML(data: data)
                options.queue.async {
                    completion(.success(photos))
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
            completion: @escaping (Result<Void, Error>) -> Void
        ) {
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
                return options.queue.async { completion(.failure(NKError(error: error))) }
            }

            nkSession.sessionData.request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                let statusCode = response.response?.statusCode
                // Explicit 404 check
                if statusCode == 404 || statusCode == 403 {
                    return completion(.success(()))
                }

                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)
                    completion(.failure(error))

                case .success:
                    completion(.success(()))
                }
            }
        }
    }

    // MARK: - Helper

    private func parseAlbumsXML(data: Data) -> [NKAlbumDTO] {
        let xml = XML.parse(data)
        var albums: [NKAlbumDTO] = []
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
                let album = NKAlbumDTO(
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

    private func parseAlbumPhotosXML(data: Data) -> [NKAlbumPhotoDTO] {
        let xml = XML.parse(data)
        var photos: [NKAlbumPhotoDTO] = []
        let elements = xml["d:multistatus", "d:response"]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

        for element in elements {
            let href = element["d:href"].element?.text ?? ""
            let fileName = URL(string: href)?.lastPathComponent ?? href
            let propstats: [XML.Element] = element["d:propstat"].all ?? []

            for propstat in propstats {
                let ps = XML.Accessor(propstat)
                let status = ps["d:status"].element?.text ?? ""
                guard status.contains("200") else { continue }
                let prop = ps["d:prop"]

                guard let fileId = prop["oc:fileid"].element?.text else { continue }

                let contentType = prop["d:getcontenttype"].element?.text ?? ""
                let contentLength = prop["d:getcontentlength"].element?.text.flatMap { Int($0) } ?? 0
                let lastModified = prop["d:getlastmodified"].element?.text.flatMap {
                    formatter.date(from: $0)
                } ?? Date()

                let hasPreview = prop["nc:has-preview"].element?.text == "true"
                let isHidden = prop["nc:hidden"].element?.text == "true"
                let isFavorite = prop["oc:favorite"].element?.text == "1"
                let permissions = prop["oc:permissions"].element?.text ?? ""

                let originalDateTime = prop["nc:metadata-photos-original_date_time"]
                    .element?.text.flatMap { Double($0) }
                    .flatMap { Date(timeIntervalSince1970: $0) }

                let sizeNode = prop["nc:metadata-photos-size"]
                let width = sizeNode["width"].element?.text.flatMap { Int($0) }
                let height = sizeNode["height"].element?.text.flatMap { Int($0) }

                let photo = NKAlbumPhotoDTO(
                    fileId: fileId,
                    fileName: fileName,
                    contentType: contentType,
                    contentLength: contentLength,
                    lastModified: lastModified,
                    hasPreview: hasPreview,
                    isHidden: isHidden,
                    isFavorite: isFavorite,
                    permissions: permissions,
                    originalDateTime: originalDateTime,
                    width: width,
                    height: height
                )

                photos.append(photo)
            }
        }

        return photos
    }
}
