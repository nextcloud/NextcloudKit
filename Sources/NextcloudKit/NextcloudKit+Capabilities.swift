// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

#if os(macOS)
import Foundation
import AppKit
#else
import UIKit
#endif
import Alamofire

//  Provides APIs to retrieve and store server capabilities for a Nextcloud account.
//  The capabilities endpoint returns server and feature flags, which are parsed,
//  cached, and made accessible for feature checks throughout the app.

public extension NextcloudKit {

    /// Retrieves the capabilities of the Nextcloud server for the given account.
    /// - Parameters:
    ///   - account: The account identifier.
    ///   - options: Additional request options.
    ///   - taskHandler: Callback for the underlying URL session task.
    ///   - completion: Callback returning parsed capabilities or an error.
    func getCapabilities(account: String,
                         options: NKRequestOptions = NKRequestOptions(),
                         taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                         completion: @escaping (_ account: String, _ capabilities: NCCapabilities.Capabilities?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v1.php/cloud/capabilities"
        guard let nkSession = nkCommonInstance.getSession(account: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint, options: options),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = NKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            case .success:
                Task {
                    do {
                        let capabilities = try await self.setCapabilitiesAsync(account: account, data: response.data)
                        options.queue.async {
                            completion(account, capabilities, response, .success)
                        }
                    } catch {
                        nkLog(debug: "Capabilities decoding failed: \\(error)")
                        options.queue.async {
                            completion(account, nil, response, .invalidData)
                        }
                    }
                }
            }
        }
    }

    /// Asynchronous wrapper around `getCapabilities`, returning a result tuple.
    /// - Parameters:
    ///   - account: The Nextcloud account identifier.
    ///   - options: Request options, such as queue, custom headers, etc.
    ///   - taskHandler: Callback for the underlying `URLSessionTask`.
    /// - Returns: A tuple containing account, parsed capabilities, response data, and result error.
    func getCapabilitiesAsync(account: String,
                              options: NKRequestOptions = NKRequestOptions(),
                              taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in }) async -> (account: String,
                                                                                                            capabilities: NCCapabilities.Capabilities?,
                                                                                                            responseData: AFDataResponse<Data>?,
                                                                                                            error: NKError) {
        await withUnsafeContinuation { continuation in
            getCapabilities(account: account,
                            options: options,
                            taskHandler: taskHandler) { account, capabilities,responseData, error in
                continuation.resume(returning: (account, capabilities, responseData, error))
            }
        }
    }

    /// Asynchronously decodes and applies server capabilities from JSON data.
    /// - Parameters:
    ///   - account: The Nextcloud account identifier.
    ///   - data: The raw JSON data returned from the capabilities endpoint.
    /// - Returns: A fully populated `NCCapabilities.Capabilities` object.
    /// - Throws: An error if decoding fails or data is missing.
    func setCapabilitiesAsync(account: String, data: Data? = nil) async throws -> NCCapabilities.Capabilities {
        guard let jsonData = data else {
            throw NSError(domain: "SetCapabilities", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing JSON data"])
        }

        struct CapabilityNextcloud: Codable {
            struct Ocs: Codable {
                let meta: Meta
                let data: Data

                struct Meta: Codable {
                    let status: String?
                    let message: String?
                    let statuscode: Int?
                }

                struct Data: Codable {
                    let version: Version
                    let capabilities: Capabilities

                    struct Version: Codable {
                        let string: String
                        let major: Int
                    }

                    struct Capabilities: Codable {
                        let downloadLimit: DownloadLimit?
                        let filessharing: FilesSharing?
                        let theming: Theming?
                        let endtoendencryption: EndToEndEncryption?
                        let richdocuments: RichDocuments?
                        let activity: Activity?
                        let notifications: Notifications?
                        let files: Files?
                        let userstatus: UserStatus?
                        let external: External?
                        let groupfolders: GroupFolders?
                        let securityguard: SecurityGuard?
                        let assistant: Assistant?
                        let recommendations: Recommendations?
                        let termsOfService: TermsOfService?

                        enum CodingKeys: String, CodingKey {
                            case downloadLimit = "downloadlimit"
                            case filessharing = "files_sharing"
                            case theming
                            case endtoendencryption = "end-to-end-encryption"
                            case richdocuments, activity, notifications, files
                            case userstatus = "user_status"
                            case external, groupfolders
                            case securityguard = "security_guard"
                            case assistant
                            case recommendations
                            case termsOfService = "terms_of_service"
                        }

                        struct DownloadLimit: Codable {
                            let enabled: Bool?
                            let defaultLimit: Int?
                        }

                        struct FilesSharing: Codable {
                            let apienabled: Bool?
                            let groupsharing: Bool?
                            let resharing: Bool?
                            let defaultpermissions: Int?
                            let ncpublic: Public?

                            enum CodingKeys: String, CodingKey {
                                case apienabled = "api_enabled"
                                case groupsharing = "group_sharing"
                                case resharing
                                case defaultpermissions = "default_permissions"
                                case ncpublic = "public"
                            }

                            struct Public: Codable {
                                let enabled: Bool
                                let upload: Bool?
                                let password: Password?
                                let sendmail: Bool?
                                let uploadfilesdrop: Bool?
                                let multiplelinks: Bool?
                                let expiredate: ExpireDate?
                                let expiredateinternal: ExpireDate?
                                let expiredateremote: ExpireDate?

                                enum CodingKeys: String, CodingKey {
                                    case upload, enabled, password
                                    case sendmail = "send_mail"
                                    case uploadfilesdrop = "upload_files_drop"
                                    case multiplelinks = "multiple_links"
                                    case expiredate = "expire_date"
                                    case expiredateinternal = "expire_date_internal"
                                    case expiredateremote = "expire_date_remote"
                                }

                                struct Password: Codable {
                                    let enforced: Bool?
                                    let askForOptionalPassword: Bool?
                                }

                                struct ExpireDate: Codable {
                                    let enforced: Bool?
                                    let days: Int?
                                }
                            }
                        }

                        struct Theming: Codable {
                            let color: String?
                            let colorelement: String?
                            let colortext: String?
                            let colorelementbright: String?
                            let backgrounddefault: Bool?
                            let backgroundplain: Bool?
                            let colorelementdark: String?
                            let name: String?
                            let slogan: String?
                            let url: String?
                            let logo: String?
                            let background: String?
                            let logoheader: String?
                            let favicon: String?

                            enum CodingKeys: String, CodingKey {
                                case color
                                case colorelement = "color-element"
                                case colortext = "color-text"
                                case colorelementbright = "color-element-bright"
                                case backgrounddefault = "background-default"
                                case backgroundplain = "background-plain"
                                case colorelementdark = "color-element-dark"
                                case name, slogan, url, logo, background, logoheader, favicon
                            }
                        }

                        struct EndToEndEncryption: Codable {
                            let enabled: Bool?
                            let apiversion: String?
                            let keysexist: Bool?

                            enum CodingKeys: String, CodingKey {
                                case enabled
                                case apiversion = "api-version"
                                case keysexist = "keys-exist"
                            }
                        }

                        struct RichDocuments: Codable {
                            let mimetypes: [String]?
                            let directediting: Bool?

                            enum CodingKeys: String, CodingKey {
                                case mimetypes
                                case directediting = "direct_editing"
                            }
                        }

                        struct Activity: Codable {
                            let apiv2: [String]?
                        }

                        struct Notifications: Codable {
                            let ocsendpoints: [String]?

                            enum CodingKeys: String, CodingKey {
                                case ocsendpoints = "ocs-endpoints"
                            }
                        }

                        struct TermsOfService: Codable {
                            let enabled: Bool?
                            let termuuid: String?

                            enum CodingKeys: String, CodingKey {
                                case enabled
                                case termuuid = "term_uuid"
                            }
                        }

                        struct Files: Codable {
                            let undelete: Bool?
                            let locking: String?
                            let comments: Bool?
                            let versioning: Bool?
                            let directEditing: DirectEditing?
                            let bigfilechunking: Bool?
                            let versiondeletion: Bool?
                            let versionlabeling: Bool?
                            let forbiddenFileNames: [String]?
                            let forbiddenFileNameBasenames: [String]?
                            let forbiddenFileNameCharacters: [String]?
                            let forbiddenFileNameExtensions: [String]?

                            enum CodingKeys: String, CodingKey {
                                case undelete, locking, comments, versioning, directEditing, bigfilechunking
                                case versiondeletion = "version_deletion"
                                case versionlabeling = "version_labeling"
                                case forbiddenFileNames = "forbidden_filenames"
                                case forbiddenFileNameBasenames = "forbidden_filename_basenames"
                                case forbiddenFileNameCharacters = "forbidden_filename_characters"
                                case forbiddenFileNameExtensions = "forbidden_filename_extensions"
                            }

                            struct DirectEditing: Codable {
                                let url: String?
                                let etag: String?
                                let supportsFileId: Bool?
                            }
                        }

                        struct UserStatus: Codable {
                            let enabled: Bool?
                            let restore: Bool?
                            let supportsemoji: Bool?

                            enum CodingKeys: String, CodingKey {
                                case enabled, restore
                                case supportsemoji = "supports_emoji"
                            }
                        }

                        struct External: Codable {
                            let v1: [String]?
                        }

                        struct GroupFolders: Codable {
                            let hasGroupFolders: Bool?
                        }

                        struct SecurityGuard: Codable {
                            let diagnostics: Bool?
                        }

                        struct Assistant: Codable {
                            let enabled: Bool?
                            let version: String?
                        }

                        struct Recommendations: Codable {
                            let enabled: Bool?
                        }
                    }
                }
            }

            let ocs: Ocs
        }

        if NKLogFileManager.shared.logLevel >= .normal {
            jsonData.printJson()
        }

        do {
            // Decode the full JSON structure
            let decoded = try JSONDecoder().decode(CapabilityNextcloud.self, from: jsonData)
            let data = decoded.ocs.data
            let json = data.capabilities

            // Initialize capabilities
            let capabilities = NCCapabilities.Capabilities()

            // Version info
            capabilities.capabilityServerVersion = data.version.string
            capabilities.capabilityServerVersionMajor = data.version.major

            // Populate capabilities from decoded JSON
            capabilities.capabilityFileSharingApiEnabled = json.filessharing?.apienabled ?? false
            capabilities.capabilityFileSharingDefaultPermission = json.filessharing?.defaultpermissions ?? 0
            capabilities.capabilityFileSharingPubPasswdEnforced = json.filessharing?.ncpublic?.password?.enforced ?? false
            capabilities.capabilityFileSharingPubExpireDateEnforced = json.filessharing?.ncpublic?.expiredate?.enforced ?? false
            capabilities.capabilityFileSharingPubExpireDateDays = json.filessharing?.ncpublic?.expiredate?.days ?? 0
            capabilities.capabilityFileSharingInternalExpireDateEnforced = json.filessharing?.ncpublic?.expiredateinternal?.enforced ?? false
            capabilities.capabilityFileSharingInternalExpireDateDays = json.filessharing?.ncpublic?.expiredateinternal?.days ?? 0
            capabilities.capabilityFileSharingRemoteExpireDateEnforced = json.filessharing?.ncpublic?.expiredateremote?.enforced ?? false
            capabilities.capabilityFileSharingRemoteExpireDateDays = json.filessharing?.ncpublic?.expiredateremote?.days ?? 0
            capabilities.capabilityFileSharingDownloadLimit = json.downloadLimit?.enabled ?? false
            capabilities.capabilityFileSharingDownloadLimitDefaultLimit = json.downloadLimit?.defaultLimit ?? 1

            capabilities.capabilityThemingColor = json.theming?.color ?? ""
            capabilities.capabilityThemingColorElement = json.theming?.colorelement ?? ""
            capabilities.capabilityThemingColorText = json.theming?.colortext ?? ""
            capabilities.capabilityThemingName = json.theming?.name ?? ""
            capabilities.capabilityThemingSlogan = json.theming?.slogan ?? ""

            capabilities.capabilityE2EEEnabled = json.endtoendencryption?.enabled ?? false
            capabilities.capabilityE2EEApiVersion = json.endtoendencryption?.apiversion ?? ""

            capabilities.capabilityRichDocumentsEnabled = json.richdocuments?.directediting ?? false
            capabilities.capabilityRichDocumentsMimetypes.removeAll()
            capabilities.capabilityRichDocumentsMimetypes = json.richdocuments?.mimetypes ?? []

            capabilities.capabilityAssistantEnabled = json.assistant?.enabled ?? false

            capabilities.capabilityActivityEnabled = json.activity != nil
            capabilities.capabilityActivity = json.activity?.apiv2 ?? []

            capabilities.capabilityNotification = json.notifications?.ocsendpoints ?? []

            capabilities.capabilityFilesUndelete = json.files?.undelete ?? false
            capabilities.capabilityFilesLockVersion = json.files?.locking ?? ""
            capabilities.capabilityFilesComments = json.files?.comments ?? false
            capabilities.capabilityFilesBigfilechunking = json.files?.bigfilechunking ?? false

            capabilities.capabilityUserStatusEnabled = json.userstatus?.enabled ?? false
            capabilities.capabilityExternalSites = json.external != nil
            capabilities.capabilityGroupfoldersEnabled = json.groupfolders?.hasGroupFolders ?? false

            if capabilities.capabilityServerVersionMajor >= 28 {
                capabilities.isLivePhotoServerAvailable = true
            }

            capabilities.capabilitySecurityGuardDiagnostics = json.securityguard?.diagnostics ?? false

            capabilities.capabilityForbiddenFileNames = json.files?.forbiddenFileNames ?? []
            capabilities.capabilityForbiddenFileNameBasenames = json.files?.forbiddenFileNameBasenames ?? []
            capabilities.capabilityForbiddenFileNameCharacters = json.files?.forbiddenFileNameCharacters ?? []
            capabilities.capabilityForbiddenFileNameExtensions = json.files?.forbiddenFileNameExtensions ?? []

            capabilities.capabilityRecommendations = json.recommendations?.enabled ?? false
            capabilities.capabilityTermsOfService = json.termsOfService?.enabled ?? false

            // Persist capabilities in shared store
            await NCCapabilities.shared.appendCapabilities(for: account, capabilities: capabilities)
            return capabilities

        } catch {
            nkLog(error: "Could not decode json capabilities: \(error.localizedDescription)")
            throw error
        }
    }
}

/// A concurrency-safe store for capabilities associated with Nextcloud accounts.
actor CapabilitiesStore {
    private var store: [String: NCCapabilities.Capabilities] = [:]

    func get(_ account: String) -> NCCapabilities.Capabilities? {
        return store[account]
    }

    func set(_ account: String, value: NCCapabilities.Capabilities) {
        store[account] = value
    }

    func shouldDisableSharesView(for account: String) -> Bool {
        guard let capability = store[account] else {
            return true
        }
        return (!capability.capabilityFileSharingApiEnabled &&
                !capability.capabilityFilesComments &&
                capability.capabilityActivity.isEmpty)
    }
}

/// Singleton container and public API for accessing and caching capabilities.
final public class NCCapabilities: Sendable {
    public static let shared = NCCapabilities()

    private let store = CapabilitiesStore()

    public class Capabilities: @unchecked Sendable {
        public var capabilityServerVersionMajor: Int                       = 0
        public var capabilityServerVersion: String                         = ""
        public var capabilityFileSharingApiEnabled: Bool                   = false
        public var capabilityFileSharingPubPasswdEnforced: Bool            = false
        public var capabilityFileSharingPubExpireDateEnforced: Bool        = false
        public var capabilityFileSharingPubExpireDateDays: Int             = 0
        public var capabilityFileSharingInternalExpireDateEnforced: Bool   = false
        public var capabilityFileSharingInternalExpireDateDays: Int        = 0
        public var capabilityFileSharingRemoteExpireDateEnforced: Bool     = false
        public var capabilityFileSharingRemoteExpireDateDays: Int          = 0
        public var capabilityFileSharingDefaultPermission: Int             = 0
        public var capabilityFileSharingDownloadLimit: Bool                = false
        public var capabilityFileSharingDownloadLimitDefaultLimit: Int     = 1
        public var capabilityThemingColor: String                          = ""
        public var capabilityThemingColorElement: String                   = ""
        public var capabilityThemingColorText: String                      = ""
        public var capabilityThemingName: String                           = ""
        public var capabilityThemingSlogan: String                         = ""
        public var capabilityE2EEEnabled: Bool                             = false
        public var capabilityE2EEApiVersion: String                        = ""
        public var capabilityRichDocumentsEnabled: Bool                    = false
        public var capabilityRichDocumentsMimetypes: [String] = []
        public var capabilityActivity: [String] = []
        public var capabilityNotification: [String] = []
        public var capabilityFilesUndelete: Bool                           = false
        public var capabilityFilesLockVersion: String                      = ""    // NC 24
        public var capabilityFilesComments: Bool                           = false // NC 20
        public var capabilityFilesBigfilechunking: Bool                    = false
        public var capabilityUserStatusEnabled: Bool                       = false
        public var capabilityExternalSites: Bool                           = false
        public var capabilityActivityEnabled: Bool                         = false
        public var capabilityGroupfoldersEnabled: Bool                     = false // NC27
        public var capabilityAssistantEnabled: Bool                        = false // NC28
        public var isLivePhotoServerAvailable: Bool                        = false // NC28
        public var capabilitySecurityGuardDiagnostics                      = false
        public var capabilityForbiddenFileNames: [String]                  = []
        public var capabilityForbiddenFileNameBasenames: [String]          = []
        public var capabilityForbiddenFileNameCharacters: [String]         = []
        public var capabilityForbiddenFileNameExtensions: [String]         = []
        public var capabilityRecommendations: Bool                         = false
        public var capabilityTermsOfService: Bool                          = false
    }

    // MARK: - Public API

    public func disableSharesView(for account: String) async -> Bool {
        await store.shouldDisableSharesView(for: account)
    }

    public func getCapabilities(for account: String) async -> Capabilities? {
        await store.get(account)
    }

    public func appendCapabilities(for account: String, capabilities: Capabilities) async {
        await store.set(account, value: capabilities)
    }
}
