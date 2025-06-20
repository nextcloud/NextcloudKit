// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension NextcloudKit {
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
                completionHandler: @escaping (_ account: String, _ ocId: String?, _ etag: String?, _ date: Date?, _ size: Int64, _ responseData: AFDataResponse<Data>?, _ nkError: NKError) -> Void) {
        var convertible: URLConvertible?
        var uploadedSize: Int64 = 0
        var uploadCompleted = false

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

        let request = nkSession.sessionData.upload(fileNameLocalPathUrl, to: url, method: .put, headers: headers, interceptor: NKInterceptor(nkCommonInstance: nkCommonInstance), fileManager: .default).validate(statusCode: 200..<300).onURLSessionTaskCreation(perform: { task in
            task.taskDescription = options.taskDescription
            options.queue.async { taskHandler(task) }
        }) .uploadProgress { progress in
            uploadedSize = progress.totalUnitCount
            uploadCompleted = progress.fractionCompleted == 1.0
            options.queue.async { progressHandler(progress) }
        } .responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            var ocId: String?, etag: String?, date: Date?
            var result: NKError
            
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
            
            if !uploadCompleted {
                nkLog(error: "Upload incomplete: only \(uploadedSize) bytes sent.")
                result = .uploadIncomplete
            } else {
                result = self.evaluateResponse(response)
            }

            options.queue.async {
                completionHandler(account, ocId, etag, date, uploadedSize, response, result)
            }
        }

        options.queue.async { requestHandler(request) }
    }

    /// - Parameters:
    ///     - directory: The local directory where is the file to be split
    ///     - fileName: The name of the file to be splites
    ///     - date: If exist the date of file
    ///     - creationDate: If exist the creation date of file
    ///     - serverUrl: The serverURL where the file will be deposited once reassembled
    ///     - chunkFolder: The name of temp folder, usually NSUUID().uuidString
    ///     - filesChunk: The struct it will contain all file names with the increment size  still to be sent.
    ///                Example filename: "3","4","5" .... size: 30000000, 40000000, 43000000
    ///     - chunkSizeInMB: Size in MB of chunk

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

        // check space
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
        let fileURL = URL(fileURLWithPath: directory as String)
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                freeDisk = capacity
            }
        } catch { }
        #endif

        #if os(visionOS) || os(iOS)
        if freeDisk < fileNameLocalSize * 4 {
            // It seems there is not enough space to send the file
            return completion(account, nil, nil, .errorChunkNoEnoughMemory)
        }
        #endif

        func createFolder(completion: @escaping (_ errorCode: NKError) -> Void) {
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

        createFolder { error in
            guard error == .success else {
                return completion(account, nil, nil, .errorChunkCreateFolder)
            }
            var uploadNKError = NKError()

            let outputDirectory = fileChunksOutputDirectory ?? directory
            self.nkCommonInstance.chunkedFile(inputDirectory: directory, outputDirectory: outputDirectory, fileName: fileName, chunkSize: chunkSize, filesChunk: filesChunk) { num in
                numChunks(num)
            } counterChunk: { counter in
                counterChunk(counter)
            } completion: { filesChunk in
                if filesChunk.isEmpty {
                    // The file for sending could not be created
                    return completion(account, nil, nil, .errorChunkFilesEmpty)
                }
                var filesChunkOutput = filesChunk
                start(filesChunkOutput)

                for fileChunk in filesChunk {
                    let serverUrlFileName = serverUrlChunkFolder + "/" + fileChunk.fileName
                    let fileNameLocalPath = outputDirectory + "/" + fileChunk.fileName
                    let fileSize = self.nkCommonInstance.getFileSize(filePath: fileNameLocalPath)
                    if fileSize == 0 {
                        // The file could not be sent
                        return completion(account, nil, nil, .errorChunkFileNull)
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
                    return completion(account, filesChunkOutput, nil, .errorChunkFileUpload)
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
}
