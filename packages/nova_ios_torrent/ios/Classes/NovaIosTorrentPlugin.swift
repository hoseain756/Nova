import Flutter
import Foundation
import TorrServerKit

public final class NovaIosTorrentPlugin: NSObject, FlutterPlugin {
  private static let shared = NovaIosTorrentPlugin()
  private let worker = DispatchQueue(label: "nova.ios_torrent.engine")
  private var port: Int?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "noor/ios_torrent", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(shared, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(true)
    case "start":
      worker.async { [self] in
        if let port, TorrserverkitIsRunning() {
          DispatchQueue.main.async { result("http://127.0.0.1:\(port)") }
          return
        }
        let dataDir = FileManager.default.urls(
          for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent("NovaTorrent", isDirectory: true).path
        for _ in 0..<10 {
          let candidate = Int.random(in: 20000...55000)
          let error = TorrserverkitStartServer(candidate, dataDir)
          if error.isEmpty {
            port = candidate
            DispatchQueue.main.async { result("http://127.0.0.1:\(candidate)") }
            return
          }
        }
        DispatchQueue.main.async {
          result(FlutterError(code: "engine_start_failed", message: nil, details: nil))
        }
      }
    case "stop":
      worker.async { [self] in
        let error = TorrserverkitStopServer()
        if error.isEmpty {
          port = nil
          DispatchQueue.main.async { result(nil) }
        } else {
          DispatchQueue.main.async {
            result(FlutterError(code: "engine_stop_failed", message: nil, details: nil))
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
