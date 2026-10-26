import Flutter
import Foundation
import UIKit
import UserNotifications

/// System-owned HTTP file transfers. The same session is recreated at launch so
/// iOS can deliver completion after suspending or terminating the Flutter engine.
final class NovaBackgroundDownloads: NSObject, URLSessionDownloadDelegate {
    static let shared = NovaBackgroundDownloads()
    let identifier = "app.noor.mobile.background-downloads"
    private let storageKey = "nova.ios.downloads.v1"
    private var backgroundCompletionHandler: (() -> Void)?
    private var lastSaved = [String: Date]()
    private var started = false

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: identifier)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        let queue = OperationQueue.main
        return URLSession(configuration: config, delegate: self, delegateQueue: queue)
    }()

    private var records: [String: [String: Any]] {
        get {
            (UserDefaults.standard.dictionary(forKey: storageKey) ?? [:])
                .compactMapValues { $0 as? [String: Any] }
        }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }

    func startAtLaunch() {
        _ = session
        guard !started else { return }
        started = true
        // A user force-quit can cancel system transfers without relaunching
        // NOVA. Give URLSession time to reattach its tasks and deliver events,
        // then make orphaned rows retryable instead of leaving them active.
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.reconcileMissingTasks()
        }
    }

    private func reconcileMissingTasks() {
        session.getAllTasks { [weak self] tasks in
            DispatchQueue.main.async {
                guard let self else { return }
                let active = Set(tasks.map(\.taskIdentifier))
                var all = self.records
                for (id, value) in all where value["status"] as? String == "downloading" {
                    var row = value
                    guard let taskId = (row["taskId"] as? NSNumber)?.intValue,
                          !active.contains(taskId) else { continue }
                    if let fileName = row["fileName"] as? String,
                       self.validFileName(fileName, id: id),
                       let root = try? self.directory() {
                        let file = root.appendingPathComponent(fileName, isDirectory: false)
                        let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
                        if (try? self.isVideoFile(file)) == true,
                           let size = (attributes?[.size] as? NSNumber)?.int64Value {
                            row["received"] = size
                            row["total"] = size
                            row["status"] = "complete"
                            row.removeValue(forKey: "error")
                            all[id] = row
                            self.notify(row, status: "complete")
                            continue
                        }
                    }
                    row["status"] = "failed"
                    row["error"] = "interrupted"
                    all[id] = row
                }
                self.records = all
            }
        }
    }

    func acceptBackgroundEvents(identifier: String, completionHandler: @escaping () -> Void) -> Bool {
        guard identifier == self.identifier else { return false }
        startAtLaunch()
        backgroundCompletionHandler = completionHandler
        return true
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "enqueue": enqueue(call.arguments, result: result)
        case "query":
            guard let id = (call.arguments as? [String: Any])?["id"] as? String else {
                result(FlutterError(code: "invalid_id", message: nil, details: nil)); return
            }
            result(records[id].map { publicState($0) })
        case "cancel", "remove":
            guard let id = (call.arguments as? [String: Any])?["id"] as? String,
                  UUID(uuidString: id) != nil else {
                result(FlutterError(code: "invalid_id", message: nil, details: nil)); return
            }
            let remove = call.method == "remove"
            var all = records
            let taskId = (all[id]?["taskId"] as? NSNumber)?.intValue
            if remove {
                all.removeValue(forKey: id)
            } else if var row = all[id] {
                row["status"] = "cancelled"
                row.removeValue(forKey: "error")
                all[id] = row
            }
            records = all
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId(id)])
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId(id)])
            session.getAllTasks { tasks in
                tasks.filter { task in
                    task.taskDescription == id || taskId.map { $0 == task.taskIdentifier } == true
                }.forEach { $0.cancel() }
                DispatchQueue.main.async { result(nil) }
            }
        default: result(FlutterMethodNotImplemented)
        }
    }

    private func enqueue(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let id = args["id"] as? String, UUID(uuidString: id) != nil,
              let title = args["title"] as? String, !title.isEmpty,
              let fileName = args["fileName"] as? String,
              validFileName(fileName, id: id),
              let urlString = args["url"] as? String,
              let url = URL(string: urlString),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil,
              let headers = args["headers"] as? [String: String],
              headers.allSatisfy({ !$0.key.contains("\r") && !$0.key.contains("\n")
                  && !$0.value.contains("\r") && !$0.value.contains("\n") }),
              let labels = args["labels"] as? [String: String] else {
            result(FlutterError(code: "invalid_source", message: nil, details: nil)); return
        }
        do { try ensureDirectory() } catch {
            result(FlutterError(code: "storage", message: nil, details: nil)); return
        }
        let begin = { [weak self] in
            guard let self else { return }
            self.session.getAllTasks { tasks in
                DispatchQueue.main.async {
                    let previousTaskId = (self.records[id]?["taskId"] as? NSNumber)?.intValue
                    tasks.filter { task in
                        task.taskDescription == id || previousTaskId.map { $0 == task.taskIdentifier } == true
                    }
                        .forEach { $0.cancel() }
                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
                    let task = self.session.downloadTask(with: request)
                    task.taskDescription = id
                    var all = self.records
                    all[id] = [
                        "id": id, "title": title, "fileName": fileName,
                        "status": "downloading", "received": 0, "total": 0,
                        "taskId": task.taskIdentifier, "labels": labels,
                        "notifiedStep": -1
                    ]
                    self.records = all
                    task.resume()
                    result(nil)
                }
            }
        }
        // Permission is requested at the user's download action. A denied
        // notification request must never prevent the transfer itself.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            DispatchQueue.main.async(execute: begin)
        }
    }

    private func validFileName(_ name: String, id: String) -> Bool {
        let allowed = ["mp4", "mkv", "webm", "avi", "mov", "m4v"]
        return allowed.contains { name.lowercased() == "\(id.lowercased()).\($0)" }
    }

    private func directory() throws -> URL {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "NOVAStorage", code: 1)
        }
        return documents.appendingPathComponent("nova_downloads", isDirectory: true)
    }

    private func ensureDirectory() throws {
        let root = try directory()
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue,
                  (try root.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink != true else {
                throw NSError(domain: "NOVAStorage", code: 2)
            }
        } else {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        }
    }

    private func publicState(_ row: [String: Any]) -> [String: Any] {
        var value: [String: Any] = [
            "status": row["status"] ?? "failed",
            "received": row["received"] ?? 0,
            "total": row["total"] ?? 0
        ]
        if let error = row["error"] { value["error"] = error }
        return value
    }

    private func notificationId(_ id: String) -> String { "nova.download.\(id)" }

    private func notify(_ row: [String: Any], status: String) {
        guard let id = row["id"] as? String,
              let title = row["title"] as? String else { return }
        let labels = row["labels"] as? [String: String] ?? [:]
        let content = UNMutableNotificationContent()
        switch status {
        case "complete":
            content.title = labels["complete"] ?? "Download complete"
            content.body = title
            content.sound = .default
        case "failed":
            content.title = labels["stopped"] ?? "Download stopped"
            content.body = title
        default:
            content.title = labels["progress"] ?? "Downloading in the background"
            let received = (row["received"] as? NSNumber)?.int64Value ?? 0
            let total = (row["total"] as? NSNumber)?.int64Value ?? 0
            content.body = total > 0 ? "\(title) · \(min(100, Int(received * 100 / total)))%" : title
        }
        if #available(iOS 15.0, *), status == "downloading" {
            content.interruptionLevel = .passive
        }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationId(id)])
        center.removeDeliveredNotifications(withIdentifiers: [notificationId(id)])
        let trigger: UNNotificationTrigger? = status == "downloading"
            ? UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false) : nil
        center.add(UNNotificationRequest(identifier: notificationId(id), content: content, trigger: trigger))
    }

    func publishProgressSnapshots() {
        for (id, value) in records where value["status"] as? String == "downloading" {
            var row = value
            notify(row, status: "downloading")
            row["notifiedStep"] = progressStep(row)
            var all = records
            all[id] = row
            records = all
        }
    }

    private func progressStep(_ row: [String: Any]) -> Int {
        let received = (row["received"] as? NSNumber)?.int64Value ?? 0
        let total = (row["total"] as? NSNumber)?.int64Value ?? 0
        return total > 0 ? min(3, Int(received * 4 / total)) : 0
    }

    private func matchingRow(_ task: URLSessionTask) -> (String, [String: Any])? {
        let all = records
        if let id = task.taskDescription, let row = all[id],
           let saved = (row["taskId"] as? NSNumber)?.intValue,
           saved == task.taskIdentifier { return (id, row) }
        return all.first { element in
            guard let saved = (element.value["taskId"] as? NSNumber)?.intValue else { return false }
            return saved == task.taskIdentifier
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let (id, original) = matchingRow(downloadTask),
              original["status"] as? String == "downloading" else { return }
        var row = original
        row["received"] = totalBytesWritten
        row["total"] = max(0, totalBytesExpectedToWrite)
        let step = progressStep(row)
        let shouldNotify = step > ((row["notifiedStep"] as? NSNumber)?.intValue ?? -1)
        let now = Date()
        if !shouldNotify, now.timeIntervalSince(lastSaved[id] ?? .distantPast) < 1 { return }
        if shouldNotify { row["notifiedStep"] = step }
        var all = records
        all[id] = row
        records = all
        lastSaved[id] = now
        if shouldNotify && UIApplication.shared.applicationState != .active {
            notify(row, status: "downloading")
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let (id, original) = matchingRow(downloadTask),
              original["status"] as? String == "downloading",
              let fileName = original["fileName"] as? String,
              validFileName(fileName, id: id) else { return }
        var row = original
        do {
            guard let response = downloadTask.response as? HTTPURLResponse else {
                throw NSError(domain: "NOVAInvalidSource", code: 1)
            }
            let contentType = (response.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
            let bytes = (try FileManager.default.attributesOfItem(atPath: location.path)[.size] as? NSNumber)?.int64Value ?? 0
            let expected = response.expectedContentLength
            guard (200...299).contains(response.statusCode),
                  !["text/", "json", "mpegurl", "dash+xml"].contains(where: { contentType.contains($0) }),
                  (expected <= 0 || response.value(forHTTPHeaderField: "Content-Encoding") != nil || bytes == expected),
                  try isVideoFile(location) else {
                throw NSError(domain: "NOVAInvalidSource", code: 1)
            }
            try ensureDirectory()
            let destination = try directory().appendingPathComponent(fileName, isDirectory: false)
            guard !FileManager.default.fileExists(atPath: destination.path) else {
                throw NSError(domain: "NOVAStorage", code: 3)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            row["received"] = bytes
            row["total"] = bytes
            row["status"] = "complete"
            row.removeValue(forKey: "error")
            var all = records
            all[id] = row
            records = all
            notify(row, status: "complete")
        } catch {
            row["status"] = "failed"
            row["error"] = (error as NSError).domain == "NOVAInvalidSource" ? "invalidSource" : "storage"
            var all = records
            all[id] = row
            records = all
            notify(row, status: "failed")
        }
    }

    private func isVideoFile(_ url: URL) throws -> Bool {
        let file = try FileHandle(forReadingFrom: url)
        defer { file.closeFile() }
        let data = file.readData(ofLength: 64)
        let bytes = [UInt8](data)
        guard bytes.count >= 16 else { return false }
        func ascii(_ offset: Int, _ text: String) -> Bool {
            let value = Array(text.utf8)
            return bytes.count >= offset + value.count &&
                Array(bytes[offset..<(offset + value.count)]) == value
        }
        return ascii(4, "ftyp") || ascii(4, "moov") || ascii(4, "mdat") ||
            Array(bytes.prefix(4)) == [0x1a, 0x45, 0xdf, 0xa3] ||
            (ascii(0, "RIFF") && (ascii(8, "AVI ") || ascii(8, "AVIX")))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard error != nil, let (id, original) = matchingRow(task),
              original["status"] as? String == "downloading" else { return }
        var row = original
        row["status"] = "failed"
        row["error"] = "network"
        var all = records
        all[id] = row
        records = all
        notify(row, status: "failed")
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        let completion = backgroundCompletionHandler
        backgroundCompletionHandler = nil
        DispatchQueue.main.async { completion?() }
    }
}
