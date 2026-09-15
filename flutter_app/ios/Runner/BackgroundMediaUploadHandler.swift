import Flutter
import Foundation

/// 使用 background URLSession 执行大媒体上传，避免 Flutter 进入后台后网络任务被系统挂起。
final class BackgroundMediaUploadHandler: NSObject {
  static let sessionIdentifier = "com.good.pet.hospital.background-media-upload"

  private let workQueue = DispatchQueue(
    label: "com.good.pet.hospital.background-media-upload",
    qos: .utility
  )
  private var responseBodies: [Int: Data] = [:]
  private var backgroundEventsCompletionHandler: (() -> Void)?
  private lazy var session: URLSession = {
    let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
    configuration.sessionSendsLaunchEvents = true
    configuration.timeoutIntervalForRequest = 24 * 60 * 60
    configuration.timeoutIntervalForResource = 7 * 24 * 60 * 60
    return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
  }()

  private let channel: FlutterMethodChannel

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.good.pet.hospital/background_media_upload",
      binaryMessenger: binaryMessenger
    )
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  func handlesBackgroundEvents(for identifier: String) -> Bool {
    identifier == Self.sessionIdentifier
  }

  func setBackgroundEventsCompletionHandler(_ completionHandler: @escaping () -> Void) {
    workQueue.async { [weak self] in
      guard let self else {
        DispatchQueue.main.async(execute: completionHandler)
        return
      }
      // App 被后台 URLSession 重新拉起时，需要先以相同 identifier 重建 session，
      // 系统才会把未完成事件交给当前 delegate。
      self.backgroundEventsCompletionHandler = completionHandler
      _ = self.session
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "enqueue":
      guard let task = BackgroundMediaUploadTask(arguments: call.arguments) else {
        result(FlutterError(code: "invalid_task", message: "媒体上传任务参数无效", details: nil))
        return
      }
      enqueue(task, result: result)
    case "status":
      guard
        let arguments = call.arguments as? [String: Any],
        let taskId = arguments["taskId"] as? String,
        !taskId.isEmpty
      else {
        result(FlutterError(code: "invalid_task", message: "媒体上传任务标识无效", details: nil))
        return
      }
      result(BackgroundMediaUploadStore.status(for: taskId))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func enqueue(_ task: BackgroundMediaUploadTask, result: @escaping FlutterResult) {
    workQueue.async { [weak self] in
      guard let self else { return }
      if BackgroundMediaUploadStore.isCompleted(taskId: task.taskId) {
        DispatchQueue.main.async { result(task.taskId) }
        return
      }

      self.session.getAllTasks { existingTasks in
        if existingTasks.contains(where: { $0.taskDescription == task.taskId }) {
          BackgroundMediaUploadStore.markRunning(taskId: task.taskId)
          DispatchQueue.main.async { result(task.taskId) }
          return
        }

        do {
          let bodyFile = try task.writeMultipartBody()
          var request = URLRequest(url: task.url)
          request.httpMethod = "POST"
          task.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
          request.setValue("multipart/form-data; boundary=\(task.boundary)", forHTTPHeaderField: "Content-Type")
          let size = try FileManager.default.attributesOfItem(atPath: bodyFile.path)[.size] as? NSNumber
          if let size {
            request.setValue(size.stringValue, forHTTPHeaderField: "Content-Length")
          }
          let uploadTask = self.session.uploadTask(with: request, fromFile: bodyFile)
          uploadTask.taskDescription = task.taskId
          BackgroundMediaUploadStore.markRunning(taskId: task.taskId)
          uploadTask.resume()
          DispatchQueue.main.async { result(task.taskId) }
        } catch {
          BackgroundMediaUploadStore.markFailed(
            taskId: task.taskId,
            message: error.localizedDescription
          )
          DispatchQueue.main.async {
            result(FlutterError(
              code: "enqueue_failed",
              message: error.localizedDescription,
              details: nil
            ))
          }
        }
      }
    }
  }
}

extension BackgroundMediaUploadHandler: URLSessionDataDelegate, URLSessionTaskDelegate {
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    workQueue.async { [weak self] in
      self?.responseBodies[dataTask.taskIdentifier, default: Data()].append(data)
    }
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    guard let taskId = task.taskDescription, !taskId.isEmpty else { return }
    workQueue.async { [weak self] in
      guard let self else { return }
      let body = self.responseBodies.removeValue(forKey: task.taskIdentifier)
        .flatMap { String(data: $0, encoding: .utf8) } ?? ""
      if let error {
        BackgroundMediaUploadStore.markFailed(taskId: taskId, message: error.localizedDescription)
      } else {
        let statusCode = (task.response as? HTTPURLResponse)?.statusCode ?? 0
        // 将 HTTP 错误响应交给 Dart 原有解析逻辑处理，避免丢失后端错误信息。
        BackgroundMediaUploadStore.markCompleted(
          taskId: taskId,
          statusCode: statusCode,
          body: body
        )
      }
      BackgroundMediaUploadTask.removeBodyFile(taskId: taskId)
    }
  }

  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    workQueue.async { [weak self] in
      guard let self, let completionHandler = self.backgroundEventsCompletionHandler else { return }
      self.backgroundEventsCompletionHandler = nil
      DispatchQueue.main.async(execute: completionHandler)
    }
  }
}

private struct BackgroundMediaUploadTask {
  let taskId: String
  let url: URL
  let headers: [String: String]
  let fields: [String: String]
  let files: [BackgroundMediaUploadFile]
  let boundary: String

  init?(arguments: Any?) {
    guard
      let values = arguments as? [String: Any],
      let taskId = values["taskId"] as? String,
      !taskId.isEmpty,
      let urlValue = values["url"] as? String,
      let url = URL(string: urlValue),
      let rawFiles = values["files"] as? [[String: Any]]
    else {
      return nil
    }
    let files = rawFiles.compactMap(BackgroundMediaUploadFile.init)
    guard files.count == rawFiles.count, !files.isEmpty else { return nil }
    self.taskId = taskId
    self.url = url
    self.headers = Self.stringMap(values["headers"])
    self.fields = Self.stringMap(values["fields"])
    self.files = files
    self.boundary = "----PetHospitalUpload\(UUID().uuidString)"
  }

  func writeMultipartBody() throws -> URL {
    let destination = Self.bodyFileURL(taskId: taskId)
    let manager = FileManager.default
    try manager.createDirectory(
      at: destination.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try? manager.removeItem(at: destination)
    manager.createFile(atPath: destination.path, contents: nil)
    let output = try FileHandle(forWritingTo: destination)
    defer { output.closeFile() }

    for (name, value) in fields {
      output.write(Data("--\(boundary)\r\n".utf8))
      output.write(Data(
        "Content-Disposition: form-data; name=\"\(name.escapeHeader())\"\r\n\r\n".utf8
      ))
      output.write(Data(value.utf8))
      output.write(Data("\r\n".utf8))
    }
    for file in files {
      guard FileManager.default.fileExists(atPath: file.path.path) else {
        throw CocoaError(.fileNoSuchFile)
      }
      output.write(Data("--\(boundary)\r\n".utf8))
      let contentDisposition =
        "Content-Disposition: form-data; name=\"\(file.field.escapeHeader())\"; " +
        "filename=\"\(file.fileName.escapeHeader())\"\r\n"
      output.write(Data(contentDisposition.utf8))
      output.write(Data("Content-Type: \(file.mimeType)\r\n\r\n".utf8))
      let input = try FileHandle(forReadingFrom: file.path)
      defer { input.closeFile() }
      while true {
        let data = input.readData(ofLength: 64 * 1024)
        if data.isEmpty { break }
        output.write(data)
      }
      output.write(Data("\r\n".utf8))
    }
    output.write(Data("--\(boundary)--\r\n".utf8))
    return destination
  }

  static func removeBodyFile(taskId: String) {
    try? FileManager.default.removeItem(at: bodyFileURL(taskId: taskId))
  }

  private static func bodyFileURL(taskId: String) -> URL {
    let safeTaskId = taskId.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
    return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("background-media-upload", isDirectory: true)
      .appendingPathComponent("\(safeTaskId).multipart")
  }

  private static func stringMap(_ value: Any?) -> [String: String] {
    (value as? [String: Any])?.reduce(into: [:]) { result, item in
      if let string = item.value as? String {
        result[item.key] = string
      }
    } ?? [:]
  }
}

private struct BackgroundMediaUploadFile {
  let field: String
  let path: URL
  let fileName: String
  let mimeType: String

  init?(_ values: [String: Any]) {
    guard
      let field = values["field"] as? String,
      let pathValue = values["path"] as? String,
      let fileName = values["fileName"] as? String,
      let mimeType = values["mimeType"] as? String,
      !field.isEmpty,
      !pathValue.isEmpty,
      !fileName.isEmpty,
      !mimeType.isEmpty
    else {
      return nil
    }
    self.field = field
    self.path = URL(fileURLWithPath: pathValue)
    self.fileName = fileName
    self.mimeType = mimeType
  }
}

private enum BackgroundMediaUploadStore {
  private static let prefix = "background-media-upload."
  private static let retention: TimeInterval = 24 * 60 * 60

  static func status(for taskId: String) -> [String: Any] {
    guard
      let record = UserDefaults.standard.dictionary(forKey: key(taskId)),
      let updatedAt = record["updatedAt"] as? TimeInterval
    else {
      return ["state": "unknown"]
    }
    guard Date().timeIntervalSince1970 - updatedAt <= retention else {
      UserDefaults.standard.removeObject(forKey: key(taskId))
      return ["state": "unknown"]
    }
    return [
      "state": record["state"] as? String ?? "unknown",
      "statusCode": record["statusCode"] as? Int ?? 0,
      "body": record["body"] as? String ?? "",
      "message": record["message"] as? String ?? "",
    ]
  }

  static func isCompleted(taskId: String) -> Bool {
    status(for: taskId)["state"] as? String == "completed"
  }

  static func markRunning(taskId: String) {
    write(taskId: taskId, state: "running")
  }

  static func markCompleted(taskId: String, statusCode: Int, body: String) {
    write(taskId: taskId, state: "completed", statusCode: statusCode, body: body)
  }

  static func markFailed(taskId: String, message: String) {
    write(taskId: taskId, state: "failed", message: message)
  }

  private static func write(
    taskId: String,
    state: String,
    statusCode: Int = 0,
    body: String = "",
    message: String = ""
  ) {
    UserDefaults.standard.set([
      "state": state,
      "statusCode": statusCode,
      "body": body,
      "message": message,
      "updatedAt": Date().timeIntervalSince1970,
    ], forKey: key(taskId))
  }

  private static func key(_ taskId: String) -> String {
    "\(prefix)\(taskId)"
  }
}

private extension String {
  func escapeHeader() -> String {
    replacingOccurrences(of: "\"", with: "_")
      .replacingOccurrences(of: "\r", with: "_")
      .replacingOccurrences(of: "\n", with: "_")
  }
}
