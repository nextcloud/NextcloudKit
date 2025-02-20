//
//  Test.swift
//  NextcloudKit
//
//  Created by Milen Pivchev on 12.02.25.
//

import Testing
import NextcloudKit

struct Test {
    let urlBase = ""
    let account = ""
    let user = ""
    let password = ""
    let groupIdentifier = "group.it.twsweb.Crypto-Cloud"
    let userAgent = "Mozilla/5.0 (iOS) Nextcloud-iOS/6.3.0"

    @Test func TestGetTypes() async throws {
        await withCheckedContinuation { continuation in
            NextcloudKit.shared.appendSession(account: account,
                                              urlBase: urlBase,
                                              user: user,
                                              userId: user,
                                              password: password,
                                              userAgent: userAgent,
                                              nextcloudVersion: 31,
                                              groupIdentifier: groupIdentifier)

            NextcloudKit.shared.getUserProfile(account: account) { account, userProfile, _, error in
                if error == .success, let userProfile {
                    NextcloudKit.shared.updateSession(account: account, userId: userProfile.userId)

                    NextcloudKit.shared.textProcessingGetTypesV2(account: account) { account, types, responseData, error in
                        print(error)
                        print(types)
                        continuation.resume()
                    }
                }

            }
        }
    }

    @Test func TestCreate() async throws {
        await withCheckedContinuation { continuation in
            NextcloudKit.shared.appendSession(account: account,
                                              urlBase: urlBase,
                                              user: user,
                                              userId: user,
                                              password: password,
                                              userAgent: userAgent,
                                              nextcloudVersion: 31,
                                              groupIdentifier: groupIdentifier)

            NextcloudKit.shared.getUserProfile(account: account) { account, userProfile, _, error in
                if error == .success, let userProfile {
                    NextcloudKit.shared.updateSession(account: account, userId: userProfile.userId)

                    NextcloudKit.shared.textProcessingGetTypesV2(account: account) { account, types, responseData, error in
                        print(error)
                        print(types)
                        guard let type = types?.first(where: {$0.id == "core:text2text"}) else { return }
                        NextcloudKit.shared.textProcessingScheduleV2(input: "TestFROM2", taskType: type, account: account) { account, task, responseData, error in
                            print(error)
                            print(task)
                            print(responseData?.response)
                            continuation.resume()
                        }
                    }

                }

            }
        }
    }

    @Test func TestGetList() async throws {
        await withCheckedContinuation { continuation in
            NextcloudKit.shared.appendSession(account: account,
                                              urlBase: urlBase,
                                              user: user,
                                              userId: user,
                                              password: password,
                                              userAgent: userAgent,
                                              nextcloudVersion: 31,
                                              groupIdentifier: groupIdentifier)

            NextcloudKit.shared.getUserProfile(account: account) { account, userProfile, _, error in
                if error == .success, let userProfile {
                    NextcloudKit.shared.updateSession(account: account, userId: userProfile.userId)

                    NextcloudKit.shared.textProcessingGetTypesV2(account: account) { account, types, responseData, error in
                        print(error)
                        print(types)
                        guard let type = types?.first(where: {$0.id == "core:text2text"}) else { return }
                        NextcloudKit.shared.textProcessingGetTasksV2(taskType: type.id ?? "", account: account) { account, task, responseData, error in
                            print(task)

                            continuation.resume()
                        }

                    }
                }

            }

        }
    }

    @Test func TestDeleteTask() async throws {
        await withCheckedContinuation { continuation in
            NextcloudKit.shared.appendSession(account: account,
                                              urlBase: urlBase,
                                              user: user,
                                              userId: user,
                                              password: password,
                                              userAgent: userAgent,
                                              nextcloudVersion: 31,
                                              groupIdentifier: groupIdentifier)

            NextcloudKit.shared.getUserProfile(account: account) { account, userProfile, _, error in
                if error == .success, let userProfile {
                    NextcloudKit.shared.updateSession(account: account, userId: userProfile.userId)

                    NextcloudKit.shared.textProcessingGetTypesV2(account: account) { account, types, responseData, error in
                        print(error)
                        print(types)
                        guard let type = types?.first(where: {$0.id == "core:text2text"}) else { return }
                        NextcloudKit.shared.textProcessingGetTasksV2(taskType: type.id ?? "", account: account) { account, task, responseData, error in
                            print(task)

                            NextcloudKit.shared.textProcessingDeleteTaskV2(taskId: task?.tasks.first?.id ?? 0, account: account) { account, responseData, error in
                                print(error)
                                continuation.resume()
                            }

                        }

                    }
                }

            }

        }
    }
}
