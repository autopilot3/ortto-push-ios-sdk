//
//  OrttoCapture.swift
//
//
//  Created by Mitch Flindell on 21/6/2023.
//

import Foundation
import OrttoSDKCore
import SwiftUI
import UIKit

public protocol Capture {
    func showWidget(_ id: String) -> Promise<Result<Void, Error>>
    func queueWidget(_ id: String)
    static func getKeyWindow() -> UIWindow?
}

enum Ap3cConfigResult {
    case success(_ config: WebViewConfig)
    case fail(_ error: Ap3cConfigError)
}

enum Ap3cConfigError: Error {
    case captureJsURLMissing
    case apiHostMissing
}

public class OrttoCapture: ObservableObject, Capture {
    let dataSourceKey: String
    let captureJsURL: URL?
    let apiHost: URL?
    var reachability: Reachability?
    public var isWidgetActive: Bool = false
    private var _queue: WidgetQueue
    private var _timer: Timer?
    private var _widgetView: WidgetView?
    private var lock = os_unfair_lock()
    private static let orttoWidgetQueueKey = "ortto_widgets_queue"

    var sessionId: String? {
        Ortto.shared.userStorage.session
    }

    var keyWindow: UIWindow? {
        Self.getKeyWindow()
    }

    var widgetView: WidgetView {
        if _widgetView == nil {
            _widgetView = WidgetView(closeWidgetRequestHandler: hideWidget)
        }

        return _widgetView!
    }

    private var retainedWebViewController: UIViewController?

    private func retainWebViewController(_ viewController: UIViewController) {
        retainedWebViewController = viewController
    }

    private func releaseWebViewController() {
        retainedWebViewController = nil
    }

    public private(set) static var shared: OrttoCapture!

    init(dataSourceKey: String, captureJSURL: URL?, apiHost: URL?) {
        self.dataSourceKey = dataSourceKey
        captureJsURL = captureJSURL
        self.apiHost = apiHost
        _queue = WidgetQueue()

        do {
            reachability = try Reachability()
        } catch {
            Ortto.log().error("OrttoCapture@init:Failed to initialize Reachability")
            return
        }

        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)

        reachability?.whenReachable = { _ in
            self.processNextWidgetFromQueue()
        }

        reachability?.whenUnreachable = { _ in
            self._timer?.invalidate()
        }
    }

    public static func initialize(dataSourceKey: String, captureJsURL: String, apiHost: String) throws {
        try initialize(dataSourceKey: dataSourceKey, captureJsURL: URL(string: captureJsURL), apiHost: URL(string: apiHost))
    }

    public static func initialize(dataSourceKey: String, captureJsURL: URL?, apiHost: URL?) throws {
        shared = OrttoCapture(
            dataSourceKey: dataSourceKey,
            captureJSURL: captureJsURL,
            apiHost: apiHost
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func appDidBecomeActive() {
        processNextWidgetFromQueue()
    }

    public func processNextWidgetFromQueue() {
        _timer?.invalidate()
        _timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            if let widgetId = self._queue.peekLast() {
                self.showWidget(widgetId)
            }
        }
    }

    public func queueWidget(_ id: String) {
        _queue.queue(id)
    }

    public func showWidget(_ id: String) -> Promise<Result<Void, Error>> {
        return Promise { resolver in
            // Check if we're on the main thread
            guard Thread.isMainThread else {
                DispatchQueue.main.async {
                    self.showWidget(id).then { result in
                        resolver(result)
                    }
                }
                return
            }

            // Check if widget can be shown
            let canShowWidget = {
                os_unfair_lock_lock(&self.lock)
                defer { os_unfair_lock_unlock(&self.lock) }

                if !self.isWidgetActive {
                    self.isWidgetActive = true
                    return true
                }
                return false
            }()

            if !canShowWidget {
                resolver(.failure(WidgetError.alreadyActive))
                return
            }

            self._queue.remove(id)

            // Check for keyWindow and rootViewController
            guard let keyWindow = self.keyWindow,
                  let rootViewController = keyWindow.rootViewController else {
                resolver(.failure(WidgetError.noKeyWindowOrRootViewController))
                return
            }

            self.widgetView.setWidgetId(id)
            self.widgetView.load { webView in

                let webViewController = UIViewController()
                webViewController.edgesForExtendedLayout = .all
                webViewController.extendedLayoutIncludesOpaqueBars = true
                webViewController.view.backgroundColor = .clear
                webViewController.view.isOpaque = false

                webViewController.view.addSubview(webView)
                webView.translatesAutoresizingMaskIntoConstraints = false

                do {
                    try NSLayoutConstraint.activate([
                        webView.topAnchor.constraint(equalTo: webViewController.view.topAnchor),
                        webView.bottomAnchor.constraint(equalTo: webViewController.view.bottomAnchor),
                        webView.leadingAnchor.constraint(equalTo: webViewController.view.leadingAnchor),
                        webView.trailingAnchor.constraint(equalTo: webViewController.view.trailingAnchor),
                    ])
                } catch {
                    resolver(.failure(WidgetError.constraintActivationFailed(error)))
                    return
                }

                webViewController.modalPresentationStyle = .overFullScreen
                webViewController.modalTransitionStyle = .crossDissolve

                // Hide keyboard if it's open
                rootViewController.view.endEditing(true)

                // Retain webViewController to prevent deallocation
                self.retainWebViewController(webViewController)

                // Set a timeout for presentation
                let timeout = DispatchWorkItem {
                    resolver(.failure(WidgetError.presentationTimeout))
                    self.releaseWebViewController()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: timeout)

                rootViewController.present(webViewController, animated: true) {
                    timeout.cancel()
                    self.releaseWebViewController()
                    resolver(.success(()))
                }
            }
        }
    }

    public func hideWidget() {
        // add timer to give animation time to play and modal to fade out
        _ = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            DispatchQueue.main.async {
                self.widgetView.setWidgetId(nil)
                self.keyWindow?.rootViewController?.dismiss(animated: true)
            }

            self.isWidgetActive = false
            self.processNextWidgetFromQueue()
        }
    }

    public static func getKeyWindow() -> UIWindow? {
        UIApplication
            .shared
            .connectedScenes
            .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
            .last { $0.isKeyWindow }
    }

    static func getWebViewBundle() -> Bundle {
        #if SWIFT_PACKAGE
            Bundle.module
        #else
            let rootBundle = Bundle(for: WidgetView.self)

            guard let webViewBundleUrl = rootBundle.url(forResource: "WebView", withExtension: "bundle") else {
                fatalError("Cannot access WebView bundle.")
            }

            guard let webViewBundle = Bundle(url: webViewBundleUrl) else {
                fatalError("Cannot create WebView bundle")
            }

            return webViewBundle
        #endif
    }

    func getAp3cConfig(widgetId: String?, completion: @escaping (Ap3cConfigResult) -> Void) {
        guard let captureJsURL = OrttoCapture.shared.captureJsURL else {
            completion(.fail(.captureJsURLMissing))
            return
        }

        guard let apiHost = OrttoCapture.shared.apiHost else {
            completion(.fail(.apiHostMissing))
            return
        }

        fetchWidgets(widgetId) { data in
            let config = WebViewConfig(
                token: OrttoCapture.shared.dataSourceKey,
                endpoint: apiHost.absoluteString,
                captureJsUrl: captureJsURL.absoluteString,
                data: data,
                context: getPageContext()
            )

            completion(.success(config))
        }
    }

    func fetchWidgets(_ widgetId: String?, completion: @escaping (WidgetsResponse) -> Void) {
        let user = Ortto.shared.userStorage.user

        let request = WidgetsGetRequest(
            sessionId: OrttoCapture.shared.sessionId,
            applicationKey: OrttoCapture.shared.dataSourceKey,
            contactId: user?.contactID,
            emailAddress: user?.email
        )
        
        debugPrint(request)

        CaptureAPI.fetchWidgets(request) { widgetsResponse in
            let data: WidgetsResponse = {
                if let widgetId = widgetId {
                    return WidgetsResponse(
                        widgets: widgetsResponse.widgets
                            .filter { widget in
                                widget.id == widgetId && widget.type == WidgetType.popup
                            }
                            .filter { widget in
                                if let expiry = widget.expiry {
                                    let diff = expiry.timeIntervalSinceNow

                                    return !diff.isLess(than: 0)
                                }

                                return true
                            },
                        hasLogo: widgetsResponse.hasLogo,
                        enabledGdpr: widgetsResponse.enabledGdpr,
                        recaptchaSiteKey: widgetsResponse.recaptchaSiteKey,
                        countryCode: widgetsResponse.countryCode,
                        serviceWorkerUrl: widgetsResponse.serviceWorkerUrl,
                        cdnUrl: widgetsResponse.cdnUrl,
                        sessionId: widgetsResponse.sessionId
                    )
                } else {
                    return widgetsResponse
                }
            }()

            if let sessionId = data.sessionId {
                Ortto.shared.userStorage.session = sessionId
            }

            completion(data)
        }
    }
}

public enum WidgetError: LocalizedError {
    case alreadyActive
    case noKeyWindowOrRootViewController
    case webViewLoadFailed
    case constraintActivationFailed(Error)
    case presentationTimeout

    public var errorDescription: String? {
        switch self {
        case .alreadyActive:
            return "A widget is already active and cannot be shown at this time."
        case .noKeyWindowOrRootViewController:
            return "Unable to find the key window or root view controller."
        case .webViewLoadFailed:
            return "Failed to load the web view for the widget."
        case .constraintActivationFailed(let error):
            return "Failed to activate layout constraints: \(error.localizedDescription)"
        case .presentationTimeout:
            return "Widget presentation timed out."
        }
    }
}

// Simple Promise implementation
public class Promise<T> {
    private var result: T?
    private var completionHandlers: [(T) -> Void] = []

    public init(_ closure: (@escaping (T) -> Void) -> Void) {
        closure { result in
            self.result = result
            self.completionHandlers.forEach { $0(result) }
            self.completionHandlers.removeAll()
        }
    }

    public func then(_ handler: @escaping (T) -> Void) {
        if let result = result {
            handler(result)
        } else {
            completionHandlers.append(handler)
        }
    }
}
