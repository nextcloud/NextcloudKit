// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
    /// Uploads a file to the Nextcloud server.
    ///
    /// - Parameters:
    ///   - serverUrlFileName: The remote server URL or path where the file will be uploaded.
    ///   - fileNameLocalPath: The local file path to be uploaded.
    ///   - dateCreationFile: Optional creation date to include in headers (X-OC-CTime).
    ///   - dateModificationFile: Optional modification date to include in headers (X-OC-MTime).
    ///   - overwrite: If true, the remote file will be overwritten if it already exists.
    ///   - account: The account associated with the upload session.
    ///   - options: Optional configuration for the request (headers, queue, timeout, etc.).
    ///   - requestHandler: Called with the created UploadRequest.
    ///   - taskHandler: Called with the underlying URLSessionTask when it's created.
    ///   - progressHandler: Called periodically with upload progress.
    ///   - completionHandler: Called at the end of the upload with:
    ///     - account: The account used.
    ///     - ocId: The server-side file identifier.
    ///     - etag: The entity tag for versioning.
    ///     - date: The server date of the operation.
    ///     - size: The total uploaded size in bytes.
    ///     - headers: The response headers.
    ///     - nkError: The result status.
    func upload(serverUrlFileName: Any,
                fileNameLocalPath: String,
                dateCreationFile: Date? = nil,
                dateModificationFile: Date? = nil,
                overwrite: Bool = false,
                account: String,
                options: NKRequestOptions = NKRequestOptions(),
                requestHandler: @escaping (_ request: UploadRequest) -> Void = { _ in },
                taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                progressHandler: @escaping (_ progress: Progress) -> Void = { _ in },
                completionHandler: @escaping (_ account: String, _ ocId: String?, _ etag: String?, _ date: Date?, _ size: Int64, _ response: AFDataResponse<Data>?, _ nkError: NKError) -> Void) {
        var convertible: URLConvertible?
        var uploadedSize: Int64 = 0

        if serverUrlFileName is URL {
            convertible = serverUrlFileName as? URLConvertible
        } else if serverUrlFileName is String || serverUrlFileName is NSString {
            convertible = (serverUrlFileName as? String)?.encodedToUrl
        }
        guard let url = convertible,
              let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              var headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completionHandler(account, nil, nil, nil, 0, nil, .urlError) }
        }
        let fileNameLocalPathUrl = URL(fileURLWithPath: fileNameLocalPath)
        // Epoch of linux do not permitted negativ value
        if let dateCreationFile, dateCreationFile.timeIntervalSince1970 > 0 {
            headers.update(name: "X-OC-CTime", value: "\(dateCreationFile.timeIntervalSince1970)")
        }
        // Epoch of linux do not permitted negativ value
        if let dateModificationFile, dateModificationFile.timeIntervalSince1970 > 0 {
            headers.update(name: "X-OC-MTime", value: "\(dateModificationFile.timeIntervalSince1970)")
        }
        if overwrite {
            headers.update(name: "Overwrite", value: "true")
        }
        headers.update(.contentType("application/octet-stream"))

        let request = nkSession.sessionData.upload(fileNameLocalPathUrl, to: url, method: .put, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance), fileManager: .default).validate(statusCode: 200..<300).onURLSessionTaskCreation(perform: { task in
            task.taskDescription = options.taskDescription
            options.queue.async { taskHandler(task) }
        }) .uploadProgress { progress in
            uploadedSize = progress.totalUnitCount
            options.queue.async { progressHandler(progress) }
        } .responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            var ocId: String?, etag: String?, date: Date?

            if self.nkCommonInstance.findHeader("oc-fileid", allHeaderFields: response.response?.allHeaderFields) != nil {
                ocId = self.nkCommonInstance.findHeader("oc-fileid", allHeaderFields: response.response?.allHeaderFields)
            } else if self.nkCommonInstance.findHeader("fileid", allHeaderFields: response.response?.allHeaderFields) != nil {
                ocId = self.nkCommonInstance.findHeader("fileid", allHeaderFields: response.response?.allHeaderFields)
            }
            if self.nkCommonInstance.findHeader("oc-etag", allHeaderFields: response.response?.allHeaderFields) != nil {
                etag = self.nkCommonInstance.findHeader("oc-etag", allHeaderFields: response.response?.allHeaderFields)
            } else if self.nkCommonInstance.findHeader("etag", allHeaderFields: response.response?.allHeaderFields) != nil {
                etag = self.nkCommonInstance.findHeader("etag", allHeaderFields: response.response?.allHeaderFields)
            }
            if etag != nil {
                etag = etag?.replacingOccurrences(of: "\"", with: "")
            }
            if let dateRaw = self.nkCommonInstance.findHeader("date", allHeaderFields: response.response?.allHeaderFields) {
                date = dateRaw.parsedDate(using: "EEE, dd MMM y HH:mm:ss zzz")
            }

            options.queue.async {
                completionHandler(account, ocId, etag, date, uploadedSize, response, self.evaluateResponse(response))
            }
        }

        options.queue.async {
            requestHandler(request)
        }
    }

    /// Asynchronously uploads a file to the Nextcloud server.
    ///
    /// - Parameters:
    ///   - serverUrlFileName: The remote server URL or path where the file will be uploaded.
    ///   - fileNameLocalPath: The local file path to be uploaded.
    ///   - dateCreationFile: Optional creation date to include in headers (X-OC-CTime).
    ///   - dateModificationFile: Optional modification date to include in headers (X-OC-MTime).
    ///   - overwrite: If true, the remote file will be overwritten if it already exists.
    ///   - account: The account associated with the upload session.
    ///   - options: Optional configuration for the request (headers, queue, timeout, etc.).
    ///   - requestHandler: Called with the created UploadRequest.
    ///   - taskHandler: Called with the underlying URLSessionTask when it's created.
    ///   - progressHandler: Called periodically with upload progress.
    ///
    /// - Returns: A tuple containing:
    ///   - account: The account used for the upload.
    ///   - ocId: The remote file identifier returned by the server.
    ///   - etag: The file etag returned by the server.
    ///   - date: The server timestamp.
    ///   - size: The size of the uploaded file in bytes.
    ///   - headers: The raw HTTP response headers.
    ///   - error: The NKError result of the upload.
    func uploadAsync(serverUrlFileName: Any,
                     fileNameLocalPath: String,
                     dateCreationFile: Date? = nil,
                     dateModificationFile: Date? = nil,
                     overwrite: Bool = false,
                     account: String,
                     options: NKRequestOptions = NKRequestOptions(),
                     requestHandler: @escaping (_ request: UploadRequest) -> Void = { _ in },
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     progressHandler: @escaping (_ progress: Progress) -> Void = { _ in }
    ) async -> (
        account: String,
        ocId: String?,
        etag: String?,
        date: Date?,
        size: Int64,
        response: AFDataResponse<Data>?,
        error: NKError
    ) {
        await withCheckedContinuation { continuation in
            upload(serverUrlFileName: serverUrlFileName,
                   fileNameLocalPath: fileNameLocalPath,
                   dateCreationFile: dateCreationFile,
                   dateModificationFile: dateModificationFile,
                   overwrite: overwrite,
                   account: account,
                   options: options,
                   requestHandler: requestHandler,
                   taskHandler: taskHandler,
                   progressHandler: progressHandler) { account, ocId, etag, date, size, response, error in
                continuation.resume(returning: (
                    account: account,
                    ocId: ocId,
                    etag: etag,
                    date: date,
                    size: size,
                    response: response,
                    error: error
                ))
            }
        }
    }

    /// Upload a file using Nextcloud chunked upload with cooperative cancellation.
    /// - Important: Cancellation is cooperative. Cancelling the parent Task will:
    ///   1) Stop chunk generation (chunkedFile checks Task.isCancelled)
    ///   2) Abort the upload loop; the currently running HTTP request is also cancelled if captured via `requestHandler`.
    func uploadChunkAsync(directory: String,
                          fileChunksOutputDirectory: String? = nil,
                          fileName: String,
                          destinationFileName: String? = nil,
                          date: Date?,
                          creationDate: Date?,
                          serverUrl: String,
                          chunkFolder: String,
                          filesChunk: [(fileName: String, size: Int64)],
                          chunkSize: Int,
                          account: String,
                          options: NKRequestOptions = NKRequestOptions(),
                          chunkCountHandler: @escaping (_ num: Int) -> Void = { _ in },
                          chunkProgressHandler: @escaping (_ counter: Int) -> Void = { _ in },
                          uploadStart: @escaping (_ filesChunk: [(fileName: String, size: Int64)]) -> Void = { _ in },
                          uploadTaskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                          uploadProgressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> Void = { _, _, _ in },
                          uploaded: @escaping (_ fileChunk: (fileName: String, size: Int64)) -> Void = { _ in },
                          assembling: @escaping () -> Void = { }
    ) async throws -> (account: String, remainingChunks: [(fileName: String, size: Int64)]?, file: NKFile?) {

        // Resolve session
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account) else {
            throw NKError.urlError
        }

        // Build endpoints and headers
        let fileNameLocalSize = self.nkCommonInstance.getFileSize(filePath: directory + "/" + fileName)
        let serverUrlChunkFolder = nkSession.urlBase + "/" + nkSession.dav + "/uploads/" + nkSession.userId + "/" + chunkFolder
        let serverUrlFileName = nkSession.urlBase + "/" + nkSession.dav + "/files/" + nkSession.userId
            + self.nkCommonInstance.returnPathfromServerUrl(serverUrl, urlBase: nkSession.urlBase, userId: nkSession.userId)
            + "/" + (destinationFileName ?? fileName)

        if options.customHeader == nil { options.customHeader = [:] }
        options.customHeader?["Destination"] = serverUrlFileName.urlEncoded
        options.customHeader?["OC-Total-Length"] = String(fileNameLocalSize)

        // Disk space preflight (best-effort strict version: throw if query fails)
        #if os(macOS)
        let fsAttributes = try FileManager.default.attributesOfFileSystem(forPath: "/")
        let freeDisk = (fsAttributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        #else
        let outputPath = fileChunksOutputDirectory ?? directory
        let outputURL = URL(fileURLWithPath: outputPath)
        let freeDisk: Int64 = {
            do {
                let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey]
                let values = try outputURL.resourceValues(forKeys: keys)
                if let important = values.volumeAvailableCapacityForImportantUsage { return important }
                if let legacy = values.volumeAvailableCapacity { return Int64(legacy) }
                // Neither key available: treat as failure
                throw NSError(domain: "uploadChunkAsync", code: -101, userInfo: [NSLocalizedDescriptionKey: "Unable to determine available disk space."])
            } catch {
                // Re-throw as NKError to keep uniform error handling
                // (Up to you: you can also return .errorChunkNoEnoughMemory directly)
                return 0
            }
        }()
        #endif

        #if os(visionOS) || os(iOS) || os(macOS)
        // Require roughly 3x headroom to be safe (chunks + temp + HTTP plumbing)
        if freeDisk < fileNameLocalSize * 3 {
            throw NKError.errorChunkNoEnoughMemory
        }
        #endif

        // Ensure remote chunk folder exists (read or create)
        try Task.checkCancellation()
        var readErr = await readFileOrFolderAsync(serverUrlFileName: serverUrlChunkFolder,
                                                  depth: "0",
                                                  account: account,
                                                  options: options).error
        if readErr.errorCode == 404 {
            readErr = await createFolderAsync(serverUrlFileName: serverUrlChunkFolder,
                                              account: account,
                                              options: options).error
        }
        guard readErr == .success else {
            throw NKError.errorChunkCreateFolder
        }

        let outputDirectory = fileChunksOutputDirectory ?? directory

        // 1) Generate chunks (async, cancellable)
        let chunkedFiles: [(fileName: String, size: Int64)]
        do {
            chunkedFiles = try await self.nkCommonInstance.chunkedFile(
                inputDirectory: directory,
                outputDirectory: outputDirectory,
                fileName: fileName,
                chunkSize: chunkSize,
                filesChunk: filesChunk,
                chunkCountHandler: { num in
                    chunkCountHandler(num)
                },
                chunkProgressHandler: { counter in
                    chunkProgressHandler(counter)
                }
            )
        } catch let ns as NSError where ns.domain == "chunkedFile" {
            // Preserve your original domain/codes from chunkedFile
            throw NKError(error: ns)
        } catch {
            throw NKError(error: error)
        }

        try Task.checkCancellation()

        guard !chunkedFiles.isEmpty else {
            throw NKError(error: NSError(domain: "chunkedFile", code: -5,
                                         userInfo: [NSLocalizedDescriptionKey: "Files empty."]))
        }

        // Notify start upload
        uploadStart(chunkedFiles)

        // Keep a reference to the current UploadRequest to allow low-level cancellation
        var currentRequest: UploadRequest?

        // 2) Upload each chunk with cooperative cancellation
        for fileChunk in chunkedFiles {
            try Task.checkCancellation()

            let serverUrlFileNameChunk = serverUrlChunkFolder + "/" + fileChunk.fileName
            let fileNameLocalPath = outputDirectory + "/" + fileChunk.fileName
            let sz = self.nkCommonInstance.getFileSize(filePath: fileNameLocalPath)
            guard sz > 0 else {
                throw NKError(error: NSError(domain: "chunkedFile", code: -6,
                                             userInfo: [NSLocalizedDescriptionKey: "File empty."]))
            }

            // Perform upload; expose and capture the request to allow .cancel()
            let results = await self.uploadAsync(
                serverUrlFileName: serverUrlFileNameChunk,
                fileNameLocalPath: fileNameLocalPath,
                account: account,
                options: options,
                requestHandler: { request in
                    // Store a reference so we can cancel immediately if Task gets cancelled mid-flight
                    currentRequest = request
                },
                taskHandler: { task in
                    uploadTaskHandler(task)
                },
                progressHandler: { _ in
                    // Convert chunk cumulative size to global progress
                    let totalBytesExpected = fileNameLocalSize
                    let totalBytes = fileChunk.size
                    let fractionCompleted = Double(totalBytes) / Double(totalBytesExpected)
                    uploadProgressHandler(totalBytesExpected, totalBytes, fractionCompleted)
                }
            )

            // If the parent task was cancelled during the request, ensure the HTTP layer is cancelled too
            if Task.isCancelled {
                currentRequest?.cancel()
                throw NKError(error: NSError(domain: "chunkedFile", code: -5,
                                             userInfo: [NSLocalizedDescriptionKey: "Cancelled by Task."]))
            }

            // Check upload result
            let uploadNKError = results.error
            if uploadNKError != .success {
                // Return early with remaining chunks so the caller can resume later
                if let idx = chunkedFiles.firstIndex(where: { $0.fileName == fileChunk.fileName }) {
                    let remaining = Array(chunkedFiles.suffix(from: idx))
                    return (account, remaining, nil)
                } else {
                    return (account, chunkedFiles, nil)
                }
            }

            // Optional per-chunk callback
            uploaded(fileChunk)
        }

        try Task.checkCancellation()

        // 3) Assemble the chunks (MOVE .file -> final path)
        let serverUrlFileNameSource = serverUrlChunkFolder + "/.file"

        // Attach creation/modification times if valid (Linux epoch must be > 0)
        if let creationDate, creationDate.timeIntervalSince1970 > 0 {
            options.customHeader?["X-OC-CTime"] = "\(creationDate.timeIntervalSince1970)"
        }
        if let date, date.timeIntervalSince1970 > 0 {
            options.customHeader?["X-OC-MTime"] = "\(date.timeIntervalSince1970)"
        }

        // Compute assemble timeout based on size
        let assembleSizeInGB = Double(fileNameLocalSize) / 1e9
        let assembleTimePerGB: Double = 3 * 60  // 3 minutes per GB
        let assembleTimeMin: Double = 60        // 1 minute
        let assembleTimeMax: Double = 30 * 60   // 30 minutes
        options.timeout = max(assembleTimeMin, min(assembleTimePerGB * assembleSizeInGB, assembleTimeMax))

        assembling()

        let moveRes = await moveFileOrFolderAsync(serverUrlFileNameSource: serverUrlFileNameSource,
                                                  serverUrlFileNameDestination: serverUrlFileName,
                                                  overwrite: true,
                                                  account: account,
                                                  options: options)

        guard moveRes.error == .success else {
            // Provide remaining chunks in case caller wants to retry assemble later
            return (account, [], nil)
        }

        try Task.checkCancellation()

        // 4) Read back the final file to return NKFile
        let readRes = await readFileOrFolderAsync(serverUrlFileName: serverUrlFileName,
                                                  depth: "0",
                                                  account: account,
                                                  options: options)

        guard readRes.error == .success, let file = readRes.files?.first else {
            throw NKError.errorChunkMoveFile
        }

        return (account, nil, file)
    }
}
