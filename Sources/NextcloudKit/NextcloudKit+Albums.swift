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
            return options.queue.async {
                completion(.failure(NKError.urlError))
            }
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
                    return options.queue.async {
                        completion(.failure(NKError.invalidData))
                    }
                }

                let albums = self.parseAlbumsXML(data: data)
                completion(.success(albums))
            }
        }
    }

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

}
