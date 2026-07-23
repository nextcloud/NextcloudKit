// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

/// Endpoints for the unified-sharing OCS API (`ocs/v2.php/apps/sharing/api/v1/...`).
public extension NextcloudKit {
    // MARK: - List & search

    /// `GET /shares` — paginated list of shares the current user can see.
    func listUnifiedShares(sourceClass: String? = nil,
                           lastShareID: String? = nil,
                           limit: Int? = nil,
                           account: String,
                           options: NKRequestOptions = NKRequestOptions(),
                           taskHandler: @Sendable @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, shares: [NKUnifiedShare]?, responseData: AFDataResponse<Data>?, error: NKError) {
        let endpoint = "ocs/v2.php/apps/sharing/api/v1/shares"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return (account, nil, nil, .urlError)
        }

        var parameters: [String: String] = [:]
        if let sourceClass { parameters["sourceClass"] = sourceClass }
        if let lastShareID { parameters["lastShareID"] = lastShareID }
        if let limit { parameters["limit"] = String(limit) }

        let response = await nkSession.sessionData
            .request(url, method: .get, parameters: parameters, encoding: URLEncoding.default,
                     headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
            .validate(statusCode: 200..<300)
            .onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }
            .serializingData()
            .response

        return decodeUnifiedShareList(response: response, account: account)
    }

    /// `GET /recipients` — search recipients (users, groups, federated …) by free-text query.
    func searchUnifiedShareRecipients(query: String,
                                      recipientTypeClass: String? = nil,
                                      limit: Int? = nil,
                                      offset: Int? = nil,
                                      account: String,
                                      options: NKRequestOptions = NKRequestOptions(),
                                      taskHandler: @Sendable @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, recipients: [NKUnifiedShareRecipient]?, responseData: AFDataResponse<Data>?, error: NKError) {
        let endpoint = "ocs/v2.php/apps/sharing/api/v1/recipients"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return (account, nil, nil, .urlError)
        }

        var parameters: [String: String] = ["query": query]
        if let recipientTypeClass { parameters["recipientTypeClass"] = recipientTypeClass }
        if let limit { parameters["limit"] = String(limit) }
        if let offset { parameters["offset"] = String(offset) }

        let response = await nkSession.sessionData
            .request(url, method: .get, parameters: parameters, encoding: URLEncoding.default,
                     headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
            .validate(statusCode: 200..<300)
            .onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }
            .serializingData()
            .response

        switch response.result {
        case .failure(let error):
            return (account, nil, response, NKError(error: error, afResponse: response, responseData: response.data))
        case .success(let data):
            do {
                let wrap = try JSONDecoder().decode(NKOCSWrapper<[NKUnifiedShareRecipient]>.self, from: data)
                guard 200..<300 ~= wrap.ocs.meta.statuscode else {
                    return (account, nil, response, NKError(statusCode: wrap.ocs.meta.statuscode, fallbackDescription: wrap.ocs.meta.message ?? "", responseData: data))
                }
                return (account, wrap.ocs.data, response, .success)
            } catch {
                return (account, nil, response, NKError(error: error, responseData: data))
            }
        }
    }

    // MARK: - Single share lifecycle

    /// `POST /share` — create a new (draft) share. Returns the created share.
    func createUnifiedShare(account: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            taskHandler: @Sendable @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, share: NKUnifiedShare?, responseData: AFDataResponse<Data>?, error: NKError) {
        let endpoint = "ocs/v2.php/apps/sharing/api/v1/share"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return (account, nil, nil, .urlError)
        }

        let response = await nkSession.sessionData
            .request(url, method: .post, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
            .validate(statusCode: 200..<300)
            .onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }
            .serializingData()
            .response

        return decodeUnifiedShare(response: response, account: account)
    }

    /// `POST /share/{id}` — fetch a specific share. Modelled as POST because the body carries
    /// `secret` and free-form `arguments` per the OpenAPI.
    func getUnifiedShare(id: String,
                         secret: String? = nil,
                         arguments: [String: Any]? = nil,
                         account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @Sendable @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, share: NKUnifiedShare?, responseData: AFDataResponse<Data>?, error: NKError) {
        guard let encodedId = id.urlEncoded else {
            return (account, nil, nil, .urlError)
        }
        let endpoint = "ocs/v2.php/apps/sharing/api/v1/share/\(encodedId)"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return (account, nil, nil, .urlError)
        }

        var body: [String: Any] = [:]
        if let secret { body["secret"] = secret }
        if let arguments { body["arguments"] = arguments }

        var urlRequest: URLRequest

        do {
            urlRequest = try URLRequest(url: url, method: .post, headers: headers)
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if !body.isEmpty {
                urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
            }
        } catch {
            return (account, nil, nil, NKError(error: error))
        }

        let response = await nkSession.sessionData
            .request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
            .validate(statusCode: 200..<300)
            .onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }
            .serializingData()
            .response

        return decodeUnifiedShare(response: response, account: account)
    }

    /// `DELETE /share/{id}` — 204 success, no response body.
    func deleteUnifiedShare(id: String,
                            account: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            taskHandler: @Sendable @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, responseData: AFDataResponse<Data>?, error: NKError) {
        guard let encodedId = id.urlEncoded else {
            return (account, nil, .urlError)
        }
        let endpoint = "ocs/v2.php/apps/sharing/api/v1/share/\(encodedId)"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return (account, nil, .urlError)
        }

        let response = await nkSession.sessionData
            .request(url, method: .delete, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
            .validate(statusCode: 200..<300)
            .onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }
            .serializingData()
            .response

        switch response.result {
        case .failure(let error):
            return (account, response, NKError(error: error, afResponse: response, responseData: response.data))
        case .success:
            return (account, response, .success)
        }
    }

    // MARK: - Share mutations (return the updated share)

    /// `PUT /share/{id}/enabled` — toggle a permission.
    func setUnifiedSharePermissionEnabled(id: String,
                                          permissionClass: String,
                                          enabled: Bool,
                                          account: String,
                                          options: NKRequestOptions = NKRequestOptions(),
                                          taskHandler: @Sendable @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, share: NKUnifiedShare?, responseData: AFDataResponse<Data>?, error: NKError) {
        await mutateUnifiedShare(method: .put,
                                 subpath: "enabled",
                                 id: id,
                                 body: ["class": permissionClass, "enabled": enabled],
                                 account: account,
                                 options: options,
                                 taskHandler: taskHandler)
    }

    /// `PUT /share/{id}/property` — set a property's value.
    func setUnifiedShareProperty(id: String,
                                 propertyClass: String,
                                 value: String?,
                                 account: String,
                                 options: NKRequestOptions = NKRequestOptions(),
                                 taskHandler: @Sendable @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, share: NKUnifiedShare?, responseData: AFDataResponse<Data>?, error: NKError) {
        var body: [String: Any] = ["class": propertyClass]
        if let value { body["value"] = value }
        return await mutateUnifiedShare(method: .put,
                                        subpath: "property",
                                        id: id,
                                        body: body,
                                        account: account,
                                        options: options,
                                        taskHandler: taskHandler)
    }

    /// `PUT /share/{id}/state` — transition state (active/draft/deleted).
    func setUnifiedShareState(id: String,
                              state: NKUnifiedShareState,
                              account: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @Sendable @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, share: NKUnifiedShare?, responseData: AFDataResponse<Data>?, error: NKError) {
        await mutateUnifiedShare(method: .put,
                                 subpath: "state",
                                 id: id,
                                 body: ["state": state.rawValue],
                                 account: account,
                                 options: options,
                                 taskHandler: taskHandler)
    }

    /// `POST /share/{id}/recipient` — add a recipient.
    func addUnifiedShareRecipient(id: String,
                                  recipientClass: String,
                                  value: String,
                                  instance: String? = nil,
                                  account: String,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  taskHandler: @Sendable @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, share: NKUnifiedShare?, responseData: AFDataResponse<Data>?, error: NKError) {
        var body: [String: Any] = ["class": recipientClass, "value": value]
        if let instance { body["instance"] = instance }
        return await mutateUnifiedShare(method: .post,
                                        subpath: "recipient",
                                        id: id,
                                        body: body,
                                        account: account,
                                        options: options,
                                        taskHandler: taskHandler)
    }

    /// `DELETE /share/{id}/recipient` — remove a recipient. Parameters travel as query string.
    func removeUnifiedShareRecipient(id: String,
                                     recipientClass: String,
                                     value: String,
                                     instance: String? = nil,
                                     account: String,
                                     options: NKRequestOptions = NKRequestOptions(),
                                     taskHandler: @Sendable @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, share: NKUnifiedShare?, responseData: AFDataResponse<Data>?, error: NKError) {
        var query: [String: String] = ["class": recipientClass, "value": value]
        if let instance { query["instance"] = instance }
        return await mutateUnifiedShareWithQuery(method: .delete,
                                                 subpath: "recipient",
                                                 id: id,
                                                 query: query,
                                                 account: account,
                                                 options: options,
                                                 taskHandler: taskHandler)
    }

    /// `POST /share/{id}/source` — add a source.
    func addUnifiedShareSource(id: String,
                               sourceClass: String,
                               value: String,
                               account: String,
                               options: NKRequestOptions = NKRequestOptions(),
                               taskHandler: @Sendable @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, share: NKUnifiedShare?, responseData: AFDataResponse<Data>?, error: NKError) {
        await mutateUnifiedShare(method: .post,
                                 subpath: "source",
                                 id: id,
                                 body: ["class": sourceClass, "value": value],
                                 account: account,
                                 options: options,
                                 taskHandler: taskHandler)
    }

    /// `DELETE /share/{id}/source` — remove a source. Parameters travel as query string.
    func removeUnifiedShareSource(id: String,
                                  sourceClass: String,
                                  value: String,
                                  account: String,
                                  options: NKRequestOptions = NKRequestOptions(),
                                  taskHandler: @Sendable @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, share: NKUnifiedShare?, responseData: AFDataResponse<Data>?, error: NKError) {
        await mutateUnifiedShareWithQuery(method: .delete,
                                          subpath: "source",
                                          id: id,
                                          query: ["class": sourceClass, "value": value],
                                          account: account,
                                          options: options,
                                          taskHandler: taskHandler)
    }

    // MARK: - Private helpers

    /// Shared body-carrying mutation that returns the updated share.
    private func mutateUnifiedShare(method: HTTPMethod,
                                    subpath: String,
                                    id: String,
                                    body: [String: Any],
                                    account: String,
                                    options: NKRequestOptions,
                                    taskHandler: @Sendable @escaping (_ task: URLSessionTask) -> Void
    ) async -> (account: String, share: NKUnifiedShare?, responseData: AFDataResponse<Data>?, error: NKError) {
        guard let encodedId = id.urlEncoded else {
            return (account, nil, nil, .urlError)
        }
        let endpoint = "ocs/v2.php/apps/sharing/api/v1/share/\(encodedId)/\(subpath)"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return (account, nil, nil, .urlError)
        }

        var urlRequest: URLRequest

        do {
            urlRequest = try URLRequest(url: url, method: method, headers: headers)
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return (account, nil, nil, NKError(error: error))
        }

        let response = await nkSession.sessionData
            .request(urlRequest, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
            .validate(statusCode: 200..<300)
            .onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }
            .serializingData()
            .response

        return decodeUnifiedShare(response: response, account: account)
    }

    /// Shared query-carrying mutation (DELETE subresources) that returns the updated share.
    private func mutateUnifiedShareWithQuery(method: HTTPMethod,
                                             subpath: String,
                                             id: String,
                                             query: [String: String],
                                             account: String,
                                             options: NKRequestOptions,
                                             taskHandler: @Sendable @escaping (_ task: URLSessionTask) -> Void
    ) async -> (account: String, share: NKUnifiedShare?, responseData: AFDataResponse<Data>?, error: NKError) {
        guard let encodedId = id.urlEncoded else {
            return (account, nil, nil, .urlError)
        }
        let endpoint = "ocs/v2.php/apps/sharing/api/v1/share/\(encodedId)/\(subpath)"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return (account, nil, nil, .urlError)
        }

        let response = await nkSession.sessionData
            .request(url, method: method, parameters: query, encoding: URLEncoding.queryString,
                     headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance))
            .validate(statusCode: 200..<300)
            .onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }
            .serializingData()
            .response

        return decodeUnifiedShare(response: response, account: account)
    }

    /// Decode an OCS response containing a single `Share`.
    private func decodeUnifiedShare(response: AFDataResponse<Data>,
                                    account: String
    ) -> (account: String, share: NKUnifiedShare?, responseData: AFDataResponse<Data>?, error: NKError) {
        switch response.result {
        case .failure(let error):
            return (account, nil, response, NKError(error: error, afResponse: response, responseData: response.data))
        case .success(let data):
            do {
                let wrap = try JSONDecoder().decode(NKOCSWrapper<NKUnifiedShare>.self, from: data)
                guard 200..<300 ~= wrap.ocs.meta.statuscode else {
                    return (account, nil, response, NKError(statusCode: wrap.ocs.meta.statuscode, fallbackDescription: wrap.ocs.meta.message ?? "", responseData: data))
                }
                return (account, wrap.ocs.data, response, .success)
            } catch {
                return (account, nil, response, NKError(error: error, responseData: data))
            }
        }
    }

    /// Decode an OCS response containing an array of `Share`.
    private func decodeUnifiedShareList(response: AFDataResponse<Data>,
                                        account: String
    ) -> (account: String, shares: [NKUnifiedShare]?, responseData: AFDataResponse<Data>?, error: NKError) {
        switch response.result {
        case .failure(let error):
            return (account, nil, response, NKError(error: error, afResponse: response, responseData: response.data))
        case .success(let data):
            do {
                let wrap = try JSONDecoder().decode(NKOCSWrapper<[NKUnifiedShare]>.self, from: data)
                guard 200..<300 ~= wrap.ocs.meta.statuscode else {
                    return (account, nil, response, NKError(statusCode: wrap.ocs.meta.statuscode, fallbackDescription: wrap.ocs.meta.message ?? "", responseData: data))
                }
                return (account, wrap.ocs.data, response, .success)
            } catch {
                return (account, nil, response, NKError(error: error, responseData: data))
            }
        }
    }
}
