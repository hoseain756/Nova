import Flutter
import UIKit

/// Forwards ACTION-VIEW-style links (custom-scheme OAuth returns, magnet
/// links, App/Universal Links) to the Dart side over the `noor/links`
/// EventChannel — the same channel the Android host uses, so Dart routing
/// stays platform-agnostic.
///
/// Links captured before Dart starts listening (cold start) are parked and
/// delivered on first listen, mirroring Android's pendingLink behavior.
final class NoorLinkForwarder: NSObject, FlutterStreamHandler {
    static let shared = NoorLinkForwarder()

    private var sink: FlutterEventSink?
    private var pending: String?
    private var attached = false

    /// Registers the `noor/links` EventChannel on the engine's messenger.
    /// Idempotent: safe to call on every scene connection / URL event.
    func attach(messenger: FlutterBinaryMessenger) {
        guard !attached else { return }
        attached = true
        FlutterEventChannel(name: "noor/links", binaryMessenger: messenger)
            .setStreamHandler(self)
    }

    func forward(_ link: String) {
        if let sink = sink {
            DispatchQueue.main.async { sink(link) }
        } else {
            pending = link
        }
    }

    func onListen(
        withArguments _: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        sink = events
        if let pending {
            self.pending = nil
            DispatchQueue.main.async { events(pending) }
        }
        return nil
    }

    func onCancel(withArguments _: Any?) {
        sink = nil
    }
}

class SceneDelegate: FlutterSceneDelegate {
    private var chromeOverlay: NovaChromeOverlay?

    var canPresentChrome: Bool {
        if #available(iOS 26.0, *) {
            return UIDevice.current.userInterfaceIdiom == .phone
                && window?.rootViewController is FlutterViewController
        }
        return false
    }

    func setChromePresentation(
        _ state: [String: Any],
        onSelect: @escaping (String, Int) -> Void,
        onAction: @escaping (String, Int) -> Void
    ) {
        guard canPresentChrome, let root = window?.rootViewController else { return }
        if chromeOverlay == nil {
            let overlay = NovaChromeOverlay(frame: root.view.bounds)
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            root.view.addSubview(overlay)
            chromeOverlay = overlay
        }
        chromeOverlay?.apply(state, onSelect: onSelect, onAction: onAction)
    }

    func removeChrome() {
        chromeOverlay?.removeFromSuperview()
        chromeOverlay = nil
    }

    override func sceneDidDisconnect(_ scene: UIScene) {
        removeChrome()
        super.sceneDidDisconnect(scene)
    }

    // MARK: - Scene lifecycle

    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)
        attachForwarder()
        // Cold-start deep link (app launched by tapping a noor:// or
        // app.noor.mobile:// URL).
        for context in connectionOptions.urlContexts {
            NoorLinkForwarder.shared.forward(context.url.absoluteString)
        }
    }

    override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        super.scene(scene, openURLContexts: URLContexts)
        attachForwarder()
        // Warm-start deep link (app already running in the background).
        for context in URLContexts {
            NoorLinkForwarder.shared.forward(context.url.absoluteString)
        }
    }

    // MARK: - Helpers

    private func attachForwarder() {
        if let controller = window?.rootViewController as? FlutterViewController {
            NoorLinkForwarder.shared.attach(messenger: controller.binaryMessenger)
        }
    }
}

/// A transparent sibling of Flutter's view. Only the system bar receives taps;
/// all other touches pass through to Flutter. No native destination owns content.
private final class NovaChromeOverlay: UIView, UITabBarDelegate {
    private let bar = UITabBar()
    private let searchButton = UIButton(type: .system)
    private let detailBackButton = UIButton(type: .system)
    private let detailShareButton = UIButton(type: .system)
    private let detailMoreButton = UIButton(type: .system)
    private var confirmedId = ""
    private var revision = -1
    private var ids: [String] = []
    private var onIntent: ((String, Int) -> Void)?
    private var onAction: ((String, Int) -> Void)?
    private var searchLeading: NSLayoutConstraint?
    private var searchTrailing: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        bar.delegate = self
        addSubview(bar)
        if #available(iOS 26.0, *) {
            var configuration = UIButton.Configuration.glass()
            configuration.image = UIImage(systemName: "magnifyingglass")
            searchButton.configuration = configuration
        }
        searchButton.accessibilityIdentifier = "search"
        searchButton.translatesAutoresizingMaskIntoConstraints = false
        searchButton.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)
        addSubview(searchButton)
        NSLayoutConstraint.activate([
            searchButton.widthAnchor.constraint(equalToConstant: 48),
            searchButton.heightAnchor.constraint(equalToConstant: 48),
            searchButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12)
        ])
        searchLeading = searchButton.leadingAnchor.constraint(
            equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 20
        )
        searchTrailing = searchButton.trailingAnchor.constraint(
            equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -20
        )
        searchTrailing?.isActive = true
        for (button, symbol, identifier) in [
            (detailBackButton, "chevron.backward", "detail.back"),
            (detailShareButton, "square.and.arrow.up", "detail.share"),
            (detailMoreButton, "ellipsis", "detail.more")
        ] {
            if #available(iOS 26.0, *) {
                var configuration = UIButton.Configuration.glass()
                configuration.image = UIImage(systemName: symbol)
                button.configuration = configuration
            }
            button.accessibilityIdentifier = identifier
            button.isHidden = true
            button.translatesAutoresizingMaskIntoConstraints = false
            addSubview(button)
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 48),
                button.heightAnchor.constraint(equalToConstant: 48),
                button.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12)
            ])
        }
        NSLayoutConstraint.activate([
            detailBackButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            detailMoreButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            detailShareButton.trailingAnchor.constraint(equalTo: detailMoreButton.leadingAnchor, constant: -8)
        ])
        detailBackButton.addTarget(self, action: #selector(detailBackTapped), for: .touchUpInside)
        detailShareButton.addTarget(self, action: #selector(detailShareTapped), for: .touchUpInside)
        detailMoreButton.showsMenuAsPrimaryAction = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = bar.sizeThatFits(CGSize(width: bounds.width, height: 0)).height
        bar.frame = CGRect(x: 0, y: bounds.height - height, width: bounds.width, height: height)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for button in [detailBackButton, detailShareButton, detailMoreButton] {
            let local = convert(point, to: button)
            if !button.isHidden && button.bounds.contains(local) {
                return button.hitTest(local, with: event)
            }
        }
        if !searchButton.isHidden, searchButton.frame.contains(point) {
            return searchButton.hitTest(convert(point, to: searchButton), with: event)
        }
        guard !bar.isHidden, bar.frame.contains(point) else { return nil }
        return bar.hitTest(convert(point, to: bar), with: event)
    }

    func apply(
        _ state: [String: Any],
        onSelect: @escaping (String, Int) -> Void,
        onAction: @escaping (String, Int) -> Void
    ) {
        guard let nextRevision = state["revision"] as? Int, nextRevision > revision,
              let selected = state["selectedId"] as? String,
              let tabs = state["tabs"] as? [[String: Any]],
              let rtl = state["rtl"] as? Bool,
              let dark = state["dark"] as? Bool,
              let visible = state["visible"] as? Bool,
              let searchVisible = state["searchVisible"] as? Bool,
              let searchLabel = state["searchLabel"] as? String,
              let active = state["active"] as? Bool else { return }
        revision = nextRevision
        confirmedId = selected
        self.onIntent = onSelect
        self.onAction = onAction
        semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        bar.semanticContentAttribute = semanticContentAttribute
        searchButton.semanticContentAttribute = semanticContentAttribute
        if rtl {
            searchTrailing?.isActive = false
            searchLeading?.isActive = true
        } else {
            searchLeading?.isActive = false
            searchTrailing?.isActive = true
        }
        bar.overrideUserInterfaceStyle = dark ? .dark : .light
        let entries = tabs.compactMap { tab -> (String, UITabBarItem)? in
            guard let id = tab["id"] as? String,
                  let title = tab["label"] as? String else { return nil }
            let symbol: String
            switch id {
            case "home": symbol = "house"
            case "anime": symbol = "sparkles"
            case "kids": symbol = "figure.child"
            case "library": symbol = "books.vertical"
            case "settings": symbol = "gearshape"
            default: return nil
            }
            let item = UITabBarItem(title: title, image: UIImage(systemName: symbol), tag: 0)
            item.isEnabled = tab["enabled"] as? Bool ?? true
            return (id, item)
        }
        ids = entries.map { $0.0 }
        bar.setItems(entries.map { $0.1 }, animated: false)
        bar.selectedItem = bar.items?[safe: ids.firstIndex(of: selected)]
        bar.isHidden = !visible || !active
        searchButton.isHidden = !visible || !active || !searchVisible
        searchButton.accessibilityLabel = searchLabel
        searchButton.overrideUserInterfaceStyle = dark ? .dark : .light
        let detail = state["detail"] as? [String: Any]
        let detailVisible = active
            && detail?["backLabel"] is String
            && detail?["shareLabel"] is String
            && detail?["moreLabel"] is String
            && detail?["menu"] is [[String: Any]]
        detailBackButton.isHidden = !detailVisible
        detailShareButton.isHidden = !detailVisible
        detailMoreButton.isHidden = !detailVisible
        for button in [detailBackButton, detailShareButton, detailMoreButton] {
            button.semanticContentAttribute = semanticContentAttribute
            button.overrideUserInterfaceStyle = dark ? .dark : .light
        }
        if let detail,
           let backLabel = detail["backLabel"] as? String,
           let shareLabel = detail["shareLabel"] as? String,
           let moreLabel = detail["moreLabel"] as? String,
           let menu = detail["menu"] as? [[String: Any]] {
            detailBackButton.accessibilityLabel = backLabel
            detailShareButton.accessibilityLabel = shareLabel
            detailShareButton.isEnabled = detail["shareEnabled"] as? Bool ?? true
            detailMoreButton.accessibilityLabel = moreLabel
            let symbols = [
                "detail.sources": "square.stack",
                "detail.list": "list.bullet",
                "detail.track": "chart.line.uptrend.xyaxis"
            ]
            let actions = menu.compactMap { item -> UIAction? in
                guard let id = item["id"] as? String,
                      let title = item["label"] as? String,
                      let symbol = symbols[id] else { return nil }
                let enabled = item["enabled"] as? Bool ?? false
                return UIAction(
                    title: title,
                    image: UIImage(systemName: symbol),
                    attributes: enabled ? [] : [.disabled]
                ) { [weak self] _ in
                    self?.onAction?(id, nextRevision)
                }
            }
            detailMoreButton.menu = UIMenu(children: actions)
            detailMoreButton.isEnabled = actions.contains { !$0.attributes.contains(.disabled) }
        } else {
            detailMoreButton.menu = nil
        }
        setNeedsLayout()
    }

    @objc private func searchTapped() {
        onAction?("search", revision)
    }

    @objc private func detailBackTapped() {
        onAction?("detail.back", revision)
    }

    @objc private func detailShareTapped() {
        if detailShareButton.isEnabled {
            onAction?("detail.share", revision)
        }
    }

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let index = tabBar.items?.firstIndex(of: item), ids.indices.contains(index) else { return }
        let requested = ids[index]
        // UIKit highlights a tap immediately; restore Flutter's confirmed state
        // while its asynchronous Kids gate or route decision runs.
        tabBar.selectedItem = tabBar.items?[safe: ids.firstIndex(of: confirmedId)]
        onIntent?(requested, revision)
    }
}

private extension Array {
    subscript(safe index: Int?) -> Element? {
        guard let index, indices.contains(index) else { return nil }
        return self[index]
    }
}
