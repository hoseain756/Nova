import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var chromeChannel: FlutterMethodChannel?
  private var downloadsChannel: FlutterMethodChannel?
  private var appIconChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    NovaBackgroundDownloads.shared.startAtLaunch()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    if !NovaBackgroundDownloads.shared.acceptBackgroundEvents(
      identifier: identifier, completionHandler: completionHandler
    ) {
      super.application(
        application,
        handleEventsForBackgroundURLSession: identifier,
        completionHandler: completionHandler
      )
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NOVAChromeBridge") else {
      return
    }
    chromeChannel = FlutterMethodChannel(
      name: "nova/ios_chrome/v1",
      binaryMessenger: registrar.messenger()
    )
    downloadsChannel = FlutterMethodChannel(
      name: "nova/ios_downloads",
      binaryMessenger: registrar.messenger()
    )
    downloadsChannel?.setMethodCallHandler { call, result in
      NovaBackgroundDownloads.shared.handle(call, result: result)
    }
    appIconChannel = FlutterMethodChannel(
      name: "nova/app_icon",
      binaryMessenger: registrar.messenger()
    )
    appIconChannel?.setMethodCallHandler { call, result in
      let app = UIApplication.shared
      let names = ["clear": "AppIconClear", "dark": "AppIconDark"]
      func snapshot() -> [String: Any] {
        let selected = names.first(where: { $0.value == app.alternateIconName })?.key ?? "classic"
        return [
          "supported": app.supportsAlternateIcons,
          "selected": selected,
          "ids": ["classic", "clear", "dark"]
        ]
      }
      switch call.method {
      case "get": result(snapshot())
      case "set":
        guard app.supportsAlternateIcons,
              let args = call.arguments as? [String: Any],
              let id = args["id"] as? String,
              id == "classic" || names[id] != nil else {
          result(FlutterError(code: "invalid_icon", message: nil, details: nil))
          return
        }
        app.setAlternateIconName(names[id]) { error in
          DispatchQueue.main.async {
            if error == nil {
              result(snapshot())
            } else {
              result(FlutterError(code: "icon_change_failed", message: nil, details: nil))
            }
          }
        }
      default: result(FlutterMethodNotImplemented)
      }
    }
    chromeChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getCapabilities":
        if #available(iOS 26.0, *) {
          result([
            "osMajor": ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            "systemGlassAvailable": true,
            "nativeChromeAvailable": UIDevice.current.userInterfaceIdiom == .phone
              && UIApplication.shared.connectedScenes.contains { ($0.delegate as? SceneDelegate)?.canPresentChrome == true },
            "phoneIdiom": UIDevice.current.userInterfaceIdiom == .phone
          ])
        } else {
          result([
            "osMajor": ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            "systemGlassAvailable": false,
            "nativeChromeAvailable": false,
            "phoneIdiom": UIDevice.current.userInterfaceIdiom == .phone
          ])
        }
      case "setPresentation":
        // Flutter confirms route and chrome state before UIKit renders it.
        guard let state = call.arguments as? [String: Any],
              state["revision"] is Int,
              state["selectedId"] is String,
              state["tabs"] is [[String: Any]],
              state["visible"] is Bool,
              state["locale"] is String,
              state["rtl"] is Bool,
              state["dark"] is Bool,
              state["active"] is Bool,
              state["searchVisible"] is Bool,
              state["searchLabel"] is String,
              (state["detail"] is NSNull || state["detail"] is [String: Any]) else {
          result(FlutterError(code: "invalid_presentation", message: nil, details: nil))
          return
        }
        guard let scene = UIApplication.shared.connectedScenes
          .compactMap({ $0.delegate as? SceneDelegate }).first(where: { $0.canPresentChrome }) else {
          result(FlutterError(code: "native_chrome_unavailable", message: nil, details: nil))
          return
        }
        scene.setChromePresentation(
          state,
          onSelect: { [weak self] id, revision in
            self?.chromeChannel?.invokeMethod("selectIntent", arguments: ["id": id, "revision": revision])
          },
          onAction: { [weak self] id, revision in
            self?.chromeChannel?.invokeMethod("actionIntent", arguments: ["id": id, "revision": revision])
          }
        )
        result(nil)
      case "dispose":
        UIApplication.shared.connectedScenes.compactMap { $0.delegate as? SceneDelegate }
          .forEach { $0.removeChrome() }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
