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

    /// Uploads a file in multiple chunks to the Nextcloud server using TUS-like behavior.
    ///
    /// - Parameters:
    ///   - directory: The local directory containing the original file.
    ///   - fileChunksOutputDirectory: Optional custom output directory for chunks (default is same as `directory`).
    ///   - fileName: Name of the original file to split and upload.
    ///   - destinationFileName: Optional custom filename to be used on the server.
    ///   - date: The modification date to be set on the uploaded file.
    ///   - creationDate: The creation date to be set on the uploaded file.
    ///   - serverUrl: The destination server path.
    ///   - chunkFolder: A temporary folder name (usually a UUID).
    ///   - filesChunk: List of chunk identifiers and their expected sizes.
    ///   - chunkSize: Size of each chunk in bytes.
    ///   - account: The Nextcloud account used for authentication.
    ///   - options: Request options (headers, queue, etc.).
    ///   - numChunks: Callback invoked with total number of chunks.
    ///   - counterChunk: Callback invoked with the index of the chunk being uploaded.
    ///   - start: Called when chunk upload begins, with the full chunk list.
    ///   - requestHandler: Handler to inspect the upload request.
    ///   - taskHandler: Handler to inspect the upload task.
    ///   - progressHandler: Progress callback with expected bytes, transferred bytes, and fraction completed.
    ///   - uploaded: Called each time a chunk is successfully uploaded.
    ///   - completion: Called when all chunks are uploaded and reassembled. Returns:
    ///     - account: The user account used.
    ///     - filesChunk: Remaining chunks (if any).
    ///     - file: The final `NKFile` metadata for the uploaded file.
    ///     - error: Upload result as `NKError`.
    func uploadChunk(directory: String,
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
                     numChunks: @escaping (_ num: Int) -> Void = { _ in },
                     counterChunk: @escaping (_ counter: Int) -> Void = { _ in },
                     start: @escaping (_ filesChunk: [(fileName: String, size: Int64)]) -> Void = { _ in },
                     requestHandler: @escaping (_ request: UploadRequest) -> Void = { _ in },
                     taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                     progressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> Void = { _, _, _ in },
                     uploaded: @escaping (_ fileChunk: (fileName: String, size: Int64)) -> Void = { _ in },
                     assembling: @escaping () -> Void = { },
                     completion: @escaping (_ account: String, _ filesChunk: [(fileName: String, size: Int64)]?, _ file: NKFile?, _ error: NKError) -> Void) {
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account) else {
            return completion(account, nil, nil, .urlError)
        }
        let fileNameLocalSize = self.nkCommonInstance.getFileSize(filePath: directory + "/" + fileName)
        let serverUrlChunkFolder = nkSession.urlBase + "/" + nkSession.dav + "/uploads/" + nkSession.userId + "/" + chunkFolder
        let serverUrlFileName = nkSession.urlBase + "/" + nkSession.dav + "/files/" + nkSession.userId + self.nkCommonInstance.returnPathfromServerUrl(serverUrl, urlBase: nkSession.urlBase, userId: nkSession.userId) + "/" + (destinationFileName ?? fileName)
        if options.customHeader == nil {
            options.customHeader = [:]
        }
        options.customHeader?["Destination"] = serverUrlFileName.urlEncoded
        options.customHeader?["OC-Total-Length"] = String(fileNameLocalSize)

        // Check available disk space
        #if os(macOS)
        var fsAttributes: [FileAttributeKey: Any]
        do {
            fsAttributes = try FileManager.default.attributesOfFileSystem(forPath: "/")
        } catch {
            return completion(account, nil, nil, .errorChunkNoEnoughMemory)
        }
        let freeDisk = ((fsAttributes[FileAttributeKey.systemFreeSize] ?? 0) as? Int64) ?? 0
        #elseif os(visionOS) || os(iOS)
        var freeDisk: Int64 = 0
        let outputPath = fileChunksOutputDirectory ?? directory
        let outputURL = URL(fileURLWithPath: outputPath)

        do {
            let keys: Set<URLResourceKey> = [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey
            ]
            let values = try outputURL.resourceValues(forKeys: keys)

            if let importantUsage = values.volumeAvailableCapacityForImportantUsage {
                freeDisk = importantUsage
            } else if let legacyCapacity = values.volumeAvailableCapacity {
                freeDisk = Int64(legacyCapacity)
            }
        } catch {
            // fallback zero
            freeDisk = 0
        }
        #endif

        #if os(visionOS) || os(iOS)
        if freeDisk < fileNameLocalSize * 3 {
            // It seems there is not enough space to send the file
            return completion(account, nil, nil, .errorChunkNoEnoughMemory)
        }
        #endif

        // Ensure upload chunk folder exists
        func createFolderIfNeeded(completion: @escaping (_ errorCode: NKError) -> Void) {
            readFileOrFolder(serverUrlFileName: serverUrlChunkFolder, depth: "0", account: account, options: options) { _, _, _, error in
                if error == .success {
                    completion(NKError())
                } else if error.errorCode == 404 {
                    self.createFolder(serverUrlFileName: serverUrlChunkFolder, account: account, options: options) { _, _, _, _, error in
                        completion(error)
                    }
                } else {
                    completion(error)
                }
            }
        }

        createFolderIfNeeded { error in
            guard error == .success else {
                return completion(account, nil, nil, .errorChunkCreateFolder)
            }
            let outputDirectory = fileChunksOutputDirectory ?? directory
            var uploadNKError = NKError()


            self.nkCommonInstance.chunkedFile(inputDirectory: directory,
                                              outputDirectory: outputDirectory,
                                              fileName: fileName,
                                              chunkSize: chunkSize,
                                              filesChunk: filesChunk) { num in
                numChunks(num)
            } counterChunk: { counter in
                counterChunk(counter)
            } completion: { filesChunk, error in

                // Check chunking error
                if let error {
                    return completion(account, nil, nil, NKError(error: error))
                }

                guard !filesChunk.isEmpty else {
                    return completion(account, nil, nil, NKError(error: NSError(domain: "chunkedFile", code: -5,userInfo: [NSLocalizedDescriptionKey: "Files empty."])))
                }

                var filesChunkOutput = filesChunk
                start(filesChunkOutput)

                for fileChunk in filesChunk {
                    let serverUrlFileName = serverUrlChunkFolder + "/" + fileChunk.fileName
                    let fileNameLocalPath = outputDirectory + "/" + fileChunk.fileName
                    let fileSize = self.nkCommonInstance.getFileSize(filePath: fileNameLocalPath)

                    if fileSize == 0 {
                        // The file could not be sent
                        return completion(account, nil, nil, NKError(error: NSError(domain: "chunkedFile", code: -6,userInfo: [NSLocalizedDescriptionKey: "File empty."])))
                    }

                    let semaphore = DispatchSemaphore(value: 0)
                    self.upload(serverUrlFileName: serverUrlFileName, fileNameLocalPath: fileNameLocalPath, account: account, options: options, requestHandler: { request in
                        requestHandler(request)
                    }, taskHandler: { task in
                        taskHandler(task)
                    }, progressHandler: { _ in
                        let totalBytesExpected = fileNameLocalSize
                        let totalBytes = fileChunk.size
                        let fractionCompleted = Double(totalBytes) / Double(totalBytesExpected)
                        progressHandler(totalBytesExpected, totalBytes, fractionCompleted)
                    }) { _, _, _, _, _, _, error in
                        if error == .success {
                            filesChunkOutput.removeFirst()
                            uploaded(fileChunk)
                        }
                        uploadNKError = error
                        semaphore.signal()
                    }
                    semaphore.wait()

                    if uploadNKError != .success {
                        break
                    }
                }

                guard uploadNKError == .success else {
                    return completion(account, filesChunkOutput, nil, uploadNKError)
                }

                // Assemble the chunks
                let serverUrlFileNameSource = serverUrlChunkFolder + "/.file"
                // Epoch of linux do not permitted negativ value
                if let creationDate, creationDate.timeIntervalSince1970 > 0 {
                    options.customHeader?["X-OC-CTime"] = "\(creationDate.timeIntervalSince1970)"
                }
                // Epoch of linux do not permitted negativ value
                if let date, date.timeIntervalSince1970 > 0 {
                    options.customHeader?["X-OC-MTime"] = "\(date.timeIntervalSince1970)"
                }
                // Calculate Assemble Timeout
                let assembleSizeInGB = Double(fileNameLocalSize) / 1e9
                let assembleTimePerGB: Double = 3 * 60  // 3  min
                let assembleTimeMin: Double = 60        // 60 sec
                let assembleTimeMax: Double = 30 * 60   // 30 min
                options.timeout = max(assembleTimeMin, min(assembleTimePerGB * assembleSizeInGB, assembleTimeMax))

                assembling()

                self.moveFileOrFolder(serverUrlFileNameSource: serverUrlFileNameSource, serverUrlFileNameDestination: serverUrlFileName, overwrite: true, account: account, options: options) { _, _, error in
                    guard error == .success else {
                        return completion(account, filesChunkOutput, nil,.errorChunkMoveFile)
                    }
                    self.readFileOrFolder(serverUrlFileName: serverUrlFileName, depth: "0", account: account, options: NKRequestOptions(queue: self.nkCommonInstance.backgroundQueue)) { _, files, _, error in
                        guard error == .success, let file = files?.first else {
                            return completion(account, filesChunkOutput, nil, .errorChunkMoveFile)
                        }
                        return completion(account, filesChunkOutput, file, error)
                    }
                }
            }
        }
    }

    /// Asynchronously uploads a file in chunks and assembles it on the Nextcloud server.
    ///
    /// - Parameters: Same as the sync version.
    /// - Returns: A tuple containing:
    ///   - account: The user account used.
    ///   - remainingChunks: Remaining chunks if any failed (or nil if success).
    ///   - file: The final file metadata object.
    ///   - error: Upload result as `NKError`.
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
                          numChunks: @escaping (_ num: Int) -> Void = { _ in },
                          counterChunk: @escaping (_ counter: Int) -> Void = { _ in },
                          start: @escaping (_ filesChunk: [(fileName: String, size: Int64)]) -> Void = { _ in },
                          requestHandler: @escaping (_ request: UploadRequest) -> Void = { _ in },
                          taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                          progressHandler: @escaping (_ totalBytesExpected: Int64, _ totalBytes: Int64, _ fractionCompleted: Double) -> Void = { _, _, _ in },
                          assembling: @escaping () -> Void = { },
                          uploaded: @escaping (_ fileChunk: (fileName: String, size: Int64)) -> Void = { _ in }
    ) async -> (account: String, remainingChunks: [(fileName: String, size: Int64)]?, file: NKFile?, error: NKError) {
        await withCheckedContinuation { continuation in
            uploadChunk(directory: directory,
                        fileChunksOutputDirectory: fileChunksOutputDirectory,
                        fileName: fileName,
                        destinationFileName: destinationFileName,
                        date: date,
                        creationDate: creationDate,
                        serverUrl: serverUrl,
                        chunkFolder: chunkFolder,
                        filesChunk: filesChunk,
                        chunkSize: chunkSize,
                        account: account,
                        options: options,
                        numChunks: numChunks,
                        counterChunk: counterChunk,
                        start: start,
                        requestHandler: requestHandler,
                        taskHandler: taskHandler,
                        progressHandler: progressHandler,
                        uploaded: uploaded,
                        assembling: assembling) { account, remaining, file, error in
                continuation.resume(returning: (account: account, remainingChunks: remaining, file: file, error: error))
            }
        }
    }
}
