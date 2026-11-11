import Flutter
import UIKit

/// UIKit owns transient choices and switches so iOS 26 can supply its current
/// system appearance, accessibility, motion, and Liquid Glass behavior.
final class NovaNativeControls: NSObject, UIPopoverPresentationControllerDelegate {
    static let shared = NovaNativeControls()
    private var channel: FlutterMethodChannel?
    private var pendingChoice: FlutterResult?

    func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        registrar.register(NovaSwitchFactory(messenger: messenger), withId: "nova/ios_switch")
        let channel = FlutterMethodChannel(name: "nova/ios_controls", binaryMessenger: messenger)
        self.channel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "isAvailable" {
            result(true)
            return
        }
        guard call.method == "presentAlert" || call.method == "presentChoices",
              let args = call.arguments as? [String: Any],
              let actions = args["actions"] as? [[String: Any]],
              !actions.isEmpty,
              actions.count <= 30,
              pendingChoice == nil,
              let presenter = visiblePresenter() else {
            result(FlutterError(code: "native_controls_unavailable", message: nil, details: nil))
            return
        }
        let style: UIAlertController.Style = call.method == "presentAlert" ? .alert : .actionSheet
        let alert = UIAlertController(
            title: args["title"] as? String,
            message: (args["message"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            preferredStyle: style
        )
        let dark = args["dark"] as? Bool ?? false
        alert.overrideUserInterfaceStyle = dark ? .dark : .light
        alert.view.semanticContentAttribute = args["rtl"] as? Bool == true
            ? .forceRightToLeft : .forceLeftToRight
        pendingChoice = result
        for (index, entry) in actions.enumerated() {
            guard let label = entry["label"] as? String, !label.isEmpty else {
                finish(nil)
                return
            }
            let actionStyle: UIAlertAction.Style
            switch entry["style"] as? String {
            case "cancel": actionStyle = .cancel
            case "destructive": actionStyle = .destructive
            default: actionStyle = .default
            }
            alert.addAction(UIAlertAction(title: label, style: actionStyle) { [weak self] _ in
                self?.finish(index)
            })
        }
        if let popover = alert.popoverPresentationController {
            popover.delegate = self
            popover.sourceView = presenter.view
            if let rect = args["sourceRect"] as? [Double], rect.count == 4 {
                popover.sourceRect = CGRect(x: rect[0], y: rect[1], width: rect[2], height: rect[3])
            } else {
                popover.sourceRect = CGRect(x: presenter.view.bounds.midX,
                                            y: presenter.view.bounds.midY, width: 1, height: 1)
            }
            popover.permittedArrowDirections = [.up, .down]
        }
        presenter.present(alert, animated: true)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        finish(nil)
    }

    func cancelPending() {
        finish(nil)
    }

    private func finish(_ value: Int?) {
        guard let result = pendingChoice else { return }
        pendingChoice = nil
        result(value)
    }

    private func visiblePresenter() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        guard let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first,
              var controller = window.rootViewController else { return nil }
        while let presented = controller.presentedViewController {
            controller = presented
        }
        return controller
    }
}

private final class NovaSwitchFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        NovaSwitchView(frame: frame, viewId: viewId, args: args as? [String: Any], messenger: messenger)
    }
}

private final class NovaSwitchView: NSObject, FlutterPlatformView {
    private let container: UIView
    private let control = UISwitch()
    private let channel: FlutterMethodChannel

    init(frame: CGRect, viewId: Int64, args: [String: Any]?, messenger: FlutterBinaryMessenger) {
        container = UIView(frame: frame)
        channel = FlutterMethodChannel(name: "nova/ios_switch/\(viewId)", binaryMessenger: messenger)
        super.init()
        container.backgroundColor = .clear
        control.translatesAutoresizingMaskIntoConstraints = false
        control.onTintColor = UIColor(red: 0.82, green: 0.23, blue: 0.28, alpha: 1)
        control.isOn = args?["value"] as? Bool ?? false
        control.isEnabled = args?["enabled"] as? Bool ?? true
        control.accessibilityLabel = args?["label"] as? String
        container.overrideUserInterfaceStyle = args?["dark"] as? Bool == true ? .dark : .light
        container.semanticContentAttribute = args?["rtl"] as? Bool == true
            ? .forceRightToLeft : .forceLeftToRight
        control.addTarget(self, action: #selector(changed), for: .valueChanged)
        container.addSubview(control)
        NSLayoutConstraint.activate([
            control.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self, call.method == "update",
                  let state = call.arguments as? [String: Any] else {
                result(FlutterMethodNotImplemented)
                return
            }
            if let value = state["value"] as? Bool { self.control.setOn(value, animated: true) }
            if let enabled = state["enabled"] as? Bool { self.control.isEnabled = enabled }
            if let label = state["label"] as? String { self.control.accessibilityLabel = label }
            if let dark = state["dark"] as? Bool {
                self.container.overrideUserInterfaceStyle = dark ? .dark : .light
            }
            if let rtl = state["rtl"] as? Bool {
                self.container.semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
            }
            result(nil)
        }
    }

    deinit { channel.setMethodCallHandler(nil) }

    func view() -> UIView { container }

    @objc private func changed() {
        channel.invokeMethod("changed", arguments: control.isOn)
    }
}
