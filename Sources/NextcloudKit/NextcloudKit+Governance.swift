// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire

public extension NextcloudKit {
    /// Returns the sensitivity labels the user may apply to an entity.
    func getGovernanceAvailableSensitivityLabels(entityType: String = "FILES",
                                                 entityId: String,
                                                 account: String,
                                                 options: NKRequestOptions = NKRequestOptions(),
                                                 taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, labels: [NKGovernanceLabel]?, responseData: AFDataResponse<Data>?, error: NKError) {
        await getGovernanceAvailableLabels(entityType: entityType, entityId: entityId, labelKind: "sensitivity", account: account, options: options, taskHandler: taskHandler)
    }

    /// Returns the retention labels the user may apply to an entity.
    func getGovernanceAvailableRetentionLabels(entityType: String = "FILES",
                                               entityId: String,
                                               account: String,
                                               options: NKRequestOptions = NKRequestOptions(),
                                               taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, labels: [NKGovernanceLabel]?, responseData: AFDataResponse<Data>?, error: NKError) {
        await getGovernanceAvailableLabels(entityType: entityType, entityId: entityId, labelKind: "retention", account: account, options: options, taskHandler: taskHandler)
    }

    /// Returns the hold labels the user may apply to an entity.
    func getGovernanceAvailableHoldLabels(entityType: String = "FILES",
                                          entityId: String,
                                          account: String,
                                          options: NKRequestOptions = NKRequestOptions(),
                                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, labels: [NKGovernanceLabel]?, responseData: AFDataResponse<Data>?, error: NKError) {
        await getGovernanceAvailableLabels(entityType: entityType, entityId: entityId, labelKind: "hold", account: account, options: options, taskHandler: taskHandler)
    }

    /// Returns all labels applied to an entity, grouped by type and filtered to those visible to the user.
    func getGovernanceLabels(entityType: String = "FILES",
                             entityId: String,
                             account: String,
                             options: NKRequestOptions = NKRequestOptions(),
                             taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, labels: NKGovernanceEntityLabels?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withCheckedContinuation { continuation in
            let endpoint = governancePath(entityType: entityType, entityId: entityId) + "?format=json"
            guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
                  let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
                  let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
                return options.queue.async {
                    continuation.resume(returning: (account, nil, nil, .urlError))
                }
            }

            nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)
                    options.queue.async {
                        continuation.resume(returning: (account, nil, response, error))
                    }
                case .success(let data):
                    if let result = try? JSONDecoder().decode(GovernanceOCS<NKGovernanceEntityLabels>.self, from: data) {
                        options.queue.async {
                            continuation.resume(returning: (account, result.ocs.data, response, .success))
                        }
                    } else {
                        options.queue.async {
                            continuation.resume(returning: (account, nil, response, .invalidData))
                        }
                    }
                }
            }
        }
    }

    /// Applies a label to an entity. Only one label per type may be active (except hold, which allows multiple).
    func setGovernanceLabel(entityType: String = "FILES",
                            entityId: String,
                            labelType: NKGovernanceLabelType,
                            labelId: String,
                            account: String,
                            options: NKRequestOptions = NKRequestOptions(),
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, responseData: AFDataResponse<Data>?, error: NKError) {
        await applyGovernanceLabel(method: .post, entityType: entityType, entityId: entityId, labelType: labelType, labelId: labelId, account: account, options: options, taskHandler: taskHandler)
    }

    /// Removes a label from an entity.
    func removeGovernanceLabel(entityType: String = "FILES",
                               entityId: String,
                               labelType: NKGovernanceLabelType,
                               labelId: String,
                               account: String,
                               options: NKRequestOptions = NKRequestOptions(),
                               taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }
    ) async -> (account: String, responseData: AFDataResponse<Data>?, error: NKError) {
        await applyGovernanceLabel(method: .delete, entityType: entityType, entityId: entityId, labelType: labelType, labelId: labelId, account: account, options: options, taskHandler: taskHandler)
    }

    private func governancePath(entityType: String, entityId: String) -> String {
        "ocs/v2.php/apps/governance/v1/labels/\(entityType)/\(entityId)"
    }

    private func getGovernanceAvailableLabels(entityType: String,
                                              entityId: String,
                                              labelKind: String,
                                              account: String,
                                              options: NKRequestOptions,
                                              taskHandler: @escaping (_ task: URLSessionTask) -> Void
    ) async -> (account: String, labels: [NKGovernanceLabel]?, responseData: AFDataResponse<Data>?, error: NKError) {
        await withCheckedContinuation { continuation in
            let endpoint = governancePath(entityType: entityType, entityId: entityId) + "/\(labelKind)/available?format=json"
            guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
                  let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
                  let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
                return options.queue.async {
                    continuation.resume(returning: (account, nil, nil, .urlError))
                }
            }

            nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                switch response.result {
                case .failure(let error):
                    let error = NKError(error: error, afResponse: response, responseData: response.data)
                    options.queue.async {
                        continuation.resume(returning: (account, nil, response, error))
                    }
                case .success(let data):
                    if let result = try? JSONDecoder().decode(GovernanceOCS<[NKGovernanceLabel]>.self, from: data) {
                        options.queue.async {
                            continuation.resume(returning: (account, result.ocs.data, response, .success))
                        }
                    } else {
                        options.queue.async {
                            continuation.resume(returning: (account, nil, response, .invalidData))
                        }
                    }
                }
            }
        }
    }

    private func applyGovernanceLabel(method: HTTPMethod,
                                      entityType: String,
                                      entityId: String,
                                      labelType: NKGovernanceLabelType,
                                      labelId: String,
                                      account: String,
                                      options: NKRequestOptions,
                                      taskHandler: @escaping (_ task: URLSessionTask) -> Void
    ) async -> (account: String, responseData: AFDataResponse<Data>?, error: NKError) {
        await withCheckedContinuation { continuation in
            let endpoint = governancePath(entityType: entityType, entityId: entityId) + "/\(labelType.rawValue)/\(labelId)?format=json"
            guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
                  let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
                  let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
                return options.queue.async {
                    continuation.resume(returning: (account, nil, .urlError))
                }
            }

            nkSession.sessionData.request(url, method: method, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                taskHandler(task)
            }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
                let result = self.evaluateResponse(response)
                options.queue.async {
                    continuation.resume(returning: (account, response, result))
                }
            }
        }
    }
}

private struct GovernanceOCS<T: Decodable>: Decodable {
    let ocs: Inner

    struct Inner: Decodable {
        let data: T
    }
}
