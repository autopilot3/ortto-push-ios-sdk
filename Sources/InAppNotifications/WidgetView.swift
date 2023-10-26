//
//  WidgetView.swift
//
//
//  Created by Mitch Flindell on 7/6/2023.
//

import OrttoSDKCore
import SwiftSoup
import SwiftUI
import WebKit

class WidgetViewUIDelegate: NSObject, WKUIDelegate {}

class WidgetView {
    private static var htmlString: String = ""

    private let closeWidgetRequestHandler: () -> Void
    private let messageHandler: WidgetViewMessageHandler
    private let navigationDelegate: WidgetViewNavigationDelegate
    private let uiDelegate: WidgetViewUIDelegate
    let webView: WKWebView
    var widgetId: String?

    public init(closeWidgetRequestHandler: @escaping () -> Void) {
        self.closeWidgetRequestHandler = closeWidgetRequestHandler
        messageHandler = WidgetViewMessageHandler(closeWidgetRequestHandler)
        navigationDelegate = WidgetViewNavigationDelegate(closeWidgetRequestHandler)
        uiDelegate = WidgetViewUIDelegate()

        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true

        let contentController = WKUserContentController()
        contentController.add(messageHandler, name: "log")
        contentController.add(messageHandler, name: "error")
        contentController.add(messageHandler, name: "messageHandler")

        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        configuration.userContentController = contentController

        let webView = FullScreenWebView(frame: .zero, configuration: configuration)
        webView.uiDelegate = uiDelegate
        webView.navigationDelegate = navigationDelegate
        webView.backgroundColor = .clear
        webView.isOpaque = false

        self.webView = webView
    }

    public func setWidgetId(_ id: String?) {
        widgetId = id
        navigationDelegate.widgetId = id
    }

    public func load(_ completionHandler: @escaping (_ webView: WKWebView) -> Void) {
        do {
            navigationDelegate.setCompletionHandler { result, error in
                if result == .success {
                    completionHandler(self.webView)
                }

                if let error = error {
                    Ortto.log().error("Error loading widget: \(error)")
                }
            }

            let webViewBundle = OrttoCapture.getWebViewBundle()

            let htmlString = try {
                if WidgetView.htmlString.isEmpty {
                    let htmlFile = webViewBundle.url(forResource: "index", withExtension: "html")!

                    // need to remove script tag, as it will fail to load due to CORS
                    // will load it manually when the page loads
                    let doc = try SwiftSoup.parse(String(contentsOf: htmlFile))
                    let head = doc.head()!

                    let scriptEl = try? head.select("script[src='app.js']").first()
                    try scriptEl?.remove()

                    WidgetView.htmlString = try doc.outerHtml()
                }

                return WidgetView.htmlString
            }()

            webView.loadHTMLString(htmlString, baseURL: webViewBundle.bundleURL)
        } catch {
            print("Error loading HTML: \(error)")
        }
    }
}

class WidgetViewMessageHandler: NSObject, WKScriptMessageHandler {
    let closeWidgetRequestHandler: () -> Void

    init(_ closeWidgetRequestHandler: @escaping () -> Void) {
        self.closeWidgetRequestHandler = closeWidgetRequestHandler
    }

    public func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "log", let messageBody = message.body as? String {
            Ortto.log().debug("JavaScript console.log: \(messageBody)")
        } else if message.name == "messageHandler" {
            let messageBody = message.body as? [String: Any]

            if let type = messageBody?["type"] as? String {
                switch type {
                case "widget-close":
                    closeWidgetRequestHandler()
                case "ap3c-track":
                    guard let payload = messageBody?["payload"] as? [String: Any] else {
                        return
                    }

                    Ortto.log().debug("ap3c-track: \(payload)")
                case "unhandled-error":
                    guard let payload = messageBody?["payload"] as? [String: Any] else {
                        return
                    }

                    Ortto.log().error("Unhandled web view error: \(payload)")
                default:
                    return
                }
            }
        }
    }
}

class WidgetViewNavigationDelegate: NSObject, WKNavigationDelegate {
    let closeWidgetRequestHandler: () -> Void
    var completionHandler: ((_ result: (LoadWidgetResult, error: (any Error)?)) -> Void)?
    var widgetId: String?

    init(_ closeWidgetRequestHandler: @escaping () -> Void) {
        self.closeWidgetRequestHandler = closeWidgetRequestHandler
    }

    func setCompletionHandler(_ completionHandler: @escaping ((LoadWidgetResult, (any Error)?)) -> Void) {
        self.completionHandler = completionHandler
    }

    public func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        // override console.log to pass logs to xcode
        do {
            let consoleLogScript =
                """
                console.log = function(message) {
                    window.webkit.messageHandlers.log.postMessage(message);
                };

                console.log("Log handlers installed")

                true;
                """

            webView.evaluateJavaScript(consoleLogScript) { _, error in
                if let error = error {
                    Ortto.log().debug("Error setting console.log: \(error)")
                    self.completionHandler?((.fail, error))
                    return
                }
            }
        }

        // loading app.js from the script tag will fail due to CORS
        // so we evaluate it manually here
        do {
            let appJs = OrttoCapture.getWebViewBundle().url(forResource: "app", withExtension: "js")!
            try webView.evaluateJavaScript(String(contentsOf: appJs)) { _, error in
                if let error = error {
                    Ortto.log().debug("Error evaluating app.js: \(error)")
                    self.completionHandler?((.fail, error))
                    return
                }
            }
        } catch {
            Ortto.log().debug("Error evaluating app.js: \(error)")
            completionHandler?((.fail, error))
            return
        }

        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            completionHandler?((.fail, nil))
            return
        }

        OrttoCapture.shared.getAp3cConfig(widgetId: widgetId) { result in
            switch result {
            case let .success(config):
                DispatchQueue.main.async {
                    do {
                        try webView.setAp3cConfig(config) { result, error in
                            if let result = result {
                                Ortto.log().debug("Ap3c config loaded: \(result)")
                                self.completionHandler?((.success, nil))
                            }

                            if let error = error {
                                self.completionHandler?((.fail, error))
                            }
                        }
                    } catch {
                        Ortto.log().error("Error evaluating start script: \(error)")
                        self.completionHandler?((.fail, error))
                    }

                    webView.ap3cStart { _, error in
                        if let error = error {
                            Ortto.log().error("Error evaluating start script: \(error)")
                            self.completionHandler?((.fail, error))
                            return
                        }
                    }
                }
            case let .fail(error):
                Ortto.log().error("Could not get config: \(error)")
                self.completionHandler?((.fail, nil))
            }
        }
    }

    func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        if let url = navigationAction.request.url {
            if url.scheme == "file" {
                return .allow
            }

            if await UIApplication.shared.canOpenURL(url) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url)
                }

                return .cancel
            }
        }

        return .allow
    }
}

extension WKWebView {
    func setAp3cConfig(_ config: WebViewConfig, completionHandler: ((Bool?, Error?) -> Void)? = nil) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let json = String(data: data, encoding: .utf8)!

        evaluateJavaScript("ap3cWebView.setConfig(\(json)); ap3cWebView.hasConfig()") { result, error in

            if let intResult = result as? Int {
                completionHandler?(Bool(intResult > 0), error)
            } else {
                completionHandler?(false, error)
            }
        }
    }

    func ap3cStart(completionHandler: ((Any?, Error?) -> Void)? = nil) {
        evaluateJavaScript("ap3cWebView.start()") { result, error in
            completionHandler?(result, error)
        }
    }
}

enum LoadWidgetResult: Error {
    case success, fail
}

func getScreenName() -> String? {
    Ortto.shared.screenName
}

func getAppName() -> String? {
    if let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String {
        return "\(appName) (iOS)"
    }

    return nil
}

func getPageContext() -> [String: String] {
    var context = [String: String]()
    let shownOnScreen = {
        if let screenName = getScreenName() {
            return screenName
        } else if let appName = getAppName() {
            return appName
        } else {
            return "Unknown"
        }
    }()

    context.updateValue(shownOnScreen, forKey: "shown_on_screen")

    return context
}
