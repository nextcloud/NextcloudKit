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
                         completion: @escaping (_ account: String, _ capabilities: NKCapabilities.Capabilities?, _ responseData: AFDataResponse<Data>?, _ error: NKError) -> Void) {
        let endpoint = "ocs/v1.php/cloud/capabilities"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
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
                                                                                                            capabilities: NKCapabilities.Capabilities?,
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
    func setCapabilitiesAsync(account: String, data: Data? = nil) async throws -> NKCapabilities.Capabilities {
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
            let capabilities = NKCapabilities.Capabilities()

            // Version info
            capabilities.serverVersion = data.version.string
            capabilities.serverVersionMajor = data.version.major

            // Populate capabilities from decoded JSON
            capabilities.fileSharingApiEnabled = json.filessharing?.apienabled ?? false
            capabilities.fileSharingDefaultPermission = json.filessharing?.defaultpermissions ?? 0
            capabilities.fileSharingPubPasswdEnforced = json.filessharing?.ncpublic?.password?.enforced ?? false
            capabilities.fileSharingPubExpireDateEnforced = json.filessharing?.ncpublic?.expiredate?.enforced ?? false
            capabilities.fileSharingPubExpireDateDays = json.filessharing?.ncpublic?.expiredate?.days ?? 0
            capabilities.fileSharingInternalExpireDateEnforced = json.filessharing?.ncpublic?.expiredateinternal?.enforced ?? false
            capabilities.fileSharingInternalExpireDateDays = json.filessharing?.ncpublic?.expiredateinternal?.days ?? 0
            capabilities.fileSharingRemoteExpireDateEnforced = json.filessharing?.ncpublic?.expiredateremote?.enforced ?? false
            capabilities.fileSharingRemoteExpireDateDays = json.filessharing?.ncpublic?.expiredateremote?.days ?? 0
            capabilities.fileSharingDownloadLimit = json.downloadLimit?.enabled ?? false
            capabilities.fileSharingDownloadLimitDefaultLimit = json.downloadLimit?.defaultLimit ?? 1

            capabilities.themingColor = json.theming?.color ?? ""
            capabilities.themingColorElement = json.theming?.colorelement ?? ""
            capabilities.themingColorText = json.theming?.colortext ?? ""
            capabilities.themingName = json.theming?.name ?? ""
            capabilities.themingSlogan = json.theming?.slogan ?? ""

            capabilities.e2EEEnabled = json.endtoendencryption?.enabled ?? false
            capabilities.e2EEApiVersion = json.endtoendencryption?.apiversion ?? ""

            capabilities.richDocumentsEnabled = json.richdocuments?.directediting ?? false
            capabilities.richDocumentsMimetypes.removeAll()
            capabilities.richDocumentsMimetypes = json.richdocuments?.mimetypes ?? []

            capabilities.assistantEnabled = json.assistant?.enabled ?? false

            capabilities.activityEnabled = json.activity != nil
            capabilities.activity = json.activity?.apiv2 ?? []

            capabilities.notification = json.notifications?.ocsendpoints ?? []

            capabilities.filesUndelete = json.files?.undelete ?? false
            capabilities.filesLockVersion = json.files?.locking ?? ""
            capabilities.filesComments = json.files?.comments ?? false
            capabilities.filesBigfilechunking = json.files?.bigfilechunking ?? false

            capabilities.userStatusEnabled = json.userstatus?.enabled ?? false
            capabilities.externalSites = json.external != nil
            capabilities.groupfoldersEnabled = json.groupfolders?.hasGroupFolders ?? false

            if capabilities.serverVersionMajor >= 28 {
                capabilities.isLivePhotoServerAvailable = true
            }

            capabilities.securityGuardDiagnostics = json.securityguard?.diagnostics ?? false

            capabilities.forbiddenFileNames = json.files?.forbiddenFileNames ?? []
            capabilities.forbiddenFileNameBasenames = json.files?.forbiddenFileNameBasenames ?? []
            capabilities.forbiddenFileNameCharacters = json.files?.forbiddenFileNameCharacters ?? []
            capabilities.forbiddenFileNameExtensions = json.files?.forbiddenFileNameExtensions ?? []

            capabilities.recommendations = json.recommendations?.enabled ?? false
            capabilities.termsOfService = json.termsOfService?.enabled ?? false

            // Persist capabilities in shared store
            await NKCapabilities.shared.appendCapabilities(for: account, capabilities: capabilities)
            return capabilities
        } catch {
            nkLog(error: "Could not decode json capabilities: \(error.localizedDescription)")
            throw error
        }
    }
}

/// A concurrency-safe store for capabilities associated with Nextcloud accounts.
actor CapabilitiesStore {
    private var store: [String: NKCapabilities.Capabilities] = [:]

    func get(_ account: String) -> NKCapabilities.Capabilities? {
        return store[account]
    }

    func set(_ account: String, value: NKCapabilities.Capabilities) {
        store[account] = value
    }
}

/// Singleton container and public API for accessing and caching capabilities.
final public class NKCapabilities: Sendable {
    public static let shared = NKCapabilities()

    private let store = CapabilitiesStore()

    public class Capabilities: @unchecked Sendable {
        public var serverVersionMajor: Int                          = 0
        public var serverVersion: String                            = ""
        public var fileSharingApiEnabled: Bool                      = false
        public var fileSharingPubPasswdEnforced: Bool               = false
        public var fileSharingPubExpireDateEnforced: Bool           = false
        public var fileSharingPubExpireDateDays: Int                = 0
        public var fileSharingInternalExpireDateEnforced: Bool      = false
        public var fileSharingInternalExpireDateDays: Int           = 0
        public var fileSharingRemoteExpireDateEnforced: Bool        = false
        public var fileSharingRemoteExpireDateDays: Int             = 0
        public var fileSharingDefaultPermission: Int                = 0
        public var fileSharingDownloadLimit: Bool                   = false
        public var fileSharingDownloadLimitDefaultLimit: Int        = 1
        public var themingColor: String                             = ""
        public var themingColorElement: String                      = ""
        public var themingColorText: String                         = ""
        public var themingName: String                              = ""
        public var themingSlogan: String                            = ""
        public var e2EEEnabled: Bool                                = false
        public var e2EEApiVersion: String                           = ""
        public var richDocumentsEnabled: Bool                       = false
        public var richDocumentsMimetypes: [String]                 = []
        public var activity: [String]                               = []
        public var notification: [String]                           = []
        public var filesUndelete: Bool                              = false
        public var filesLockVersion: String                         = ""    // NC 24
        public var filesComments: Bool                              = false // NC 20
        public var filesBigfilechunking: Bool                       = false
        public var userStatusEnabled: Bool                          = false
        public var externalSites: Bool                              = false
        public var activityEnabled: Bool                            = false
        public var groupfoldersEnabled: Bool                        = false // NC27
        public var assistantEnabled: Bool                           = false // NC28
        public var isLivePhotoServerAvailable: Bool                 = false // NC28
        public var securityGuardDiagnostics                         = false
        public var forbiddenFileNames: [String]                     = []
        public var forbiddenFileNameBasenames: [String]             = []
        public var forbiddenFileNameCharacters: [String]            = []
        public var forbiddenFileNameExtensions: [String]            = []
        public var recommendations: Bool                            = false
        public var termsOfService: Bool                             = false

        public var directEditingEditors: [NKEditorDetailsEditor]    = []
        public var directEditingCreators: [NKEditorDetailsCreator]  = []
        public var directEditingTemplates: [NKEditorTemplate]       = []

        public init() {}
    }

    // MARK: - Public API

    public func appendCapabilities(for account: String, capabilities: Capabilities) async {
        await store.set(account, value: capabilities)
    }

    public func getCapabilities(for account: String?) async -> Capabilities {
        guard let account else {
            return Capabilities()
        }
        return await store.get(account) ?? Capabilities()
    }
}
