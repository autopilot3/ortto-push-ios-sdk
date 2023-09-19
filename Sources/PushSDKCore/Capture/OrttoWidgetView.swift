//
//  File.swift
//  
//
//  Created by Mitch Flindell on 7/6/2023.
//

import SwiftUI
import WebKit
import SwiftSoup

internal func getWebViewBundle() -> Bundle {
    #if SWIFT_PACKAGE
    Bundle.module
    #else
    let rootBundle = Bundle(for: OrttoWidgetView.self)
    
    guard let webViewBundleUrl = rootBundle.url(forResource: "WebView", withExtension: "bundle") else {
        fatalError("Cannot access WebView bundle.")
    }

    guard let webViewBundle = Bundle(url: webViewBundleUrl) else {
        fatalError("Cannot create WebView bundle")
    }
    
    return webViewBundle
    #endif
}

internal class OrttoWidgetView {
    static private var htmlString: String = ""
    
    private let closeWidgetRequestHandler: (() -> Void)
    private let messageHandler: WidgetViewMessageHandler
    private let navigationDelegate: WidgetViewNavigationDelegate
    private let uiDelegate: WidgetViewUIDelegate
    internal let webView: WKWebView
    internal var widgetId: String?
    
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
    
    public func setWidgetId(_ id: String?) -> Void {
        self.widgetId = id
        navigationDelegate.widgetId = id
    }
    
    public func load(_ completionHandler: @escaping (_ webView: WKWebView) -> Void) {
        do {
            navigationDelegate.setCompletionHandler() { (result, error) in
                if result == .success {
                    completionHandler(self.webView)
                }
            
                if let error = error {
                    Ortto.log().error("Error loading widget: \(error)")
                }
            }
            
            let webViewBundle = getWebViewBundle()
            
            let htmlString = try {
                if (OrttoWidgetView.htmlString.isEmpty) {
                    let htmlFile = webViewBundle.url(forResource: "index", withExtension: "html")!
                    
                    // need to remove script tag, as it will fail to load due to CORS
                    // will load it manually when the page loads
                    let doc = try SwiftSoup.parse(String(contentsOf: htmlFile))
                    let head = doc.head()!
                    
                    let scriptEl = try? head.select("script[src='app.js']").first()
                    try scriptEl?.remove()
                    
                    OrttoWidgetView.htmlString = try doc.outerHtml()
                }
                
                return OrttoWidgetView.htmlString
            }()
            
            webView.loadHTMLString(htmlString, baseURL: webViewBundle.bundleURL)
        } catch {
            print("Error loading HTML: \(error)")
        }
    }
}

internal class WidgetViewMessageHandler: NSObject, WKScriptMessageHandler {
    internal let closeWidgetRequestHandler: () -> Void
    
    init(_ closeWidgetRequestHandler: @escaping () -> Void) {
        self.closeWidgetRequestHandler = closeWidgetRequestHandler
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "log", let messageBody = message.body as? String {
            Ortto.log().debug("JavaScript console.log: \(messageBody)")
        } else if (message.name == "messageHandler") {
            let messageBody = message.body as? [String: Any]
            
            if let type = messageBody?["type"] as? String {
                switch (type) {
                case "widget-close":
                    self.closeWidgetRequestHandler()
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

internal class WidgetViewNavigationDelegate: NSObject, WKNavigationDelegate {
    internal let closeWidgetRequestHandler: () -> Void
    internal var completionHandler: ((_ result: (LoadWidgetResult, error: (any Error)?)) -> Void)?
    internal var widgetId: String?
    
    init(_ closeWidgetRequestHandler: @escaping () -> Void) {
        self.closeWidgetRequestHandler = closeWidgetRequestHandler
    }
    
    internal func setCompletionHandler(_ completionHandler: @escaping ((LoadWidgetResult, (any Error)?)) -> Void) {
        self.completionHandler = completionHandler
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
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
            
            webView.evaluateJavaScript(consoleLogScript) { (result, error) in
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
            let appJs = getWebViewBundle().url(forResource: "app", withExtension: "js")!
            try webView.evaluateJavaScript(String(contentsOf: appJs)) { (_, error) in
                if let error = error {
                    Ortto.log().debug("Error evaluating app.js: \(error)")
                    self.completionHandler?((.fail, error))
                    return
                }
            }
        } catch {
            Ortto.log().debug("Error evaluating app.js: \(error)")
            self.completionHandler?((.fail, error))
            return
        }
        
        if (ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1") {
            self.completionHandler?((.fail, nil))
            return
        }
        
        getAp3cConfig(widgetId: self.widgetId) { result in
            switch (result) {
            case .success(let config):
                DispatchQueue.main.async {
                    do {
                        try webView.setAp3cConfig(config) { (result, error) in
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
                
                    webView.ap3cStart() { (result, error) in
                        if let error = error {
                            Ortto.log().error("Error evaluating start script: \(error)")
                            self.completionHandler?((.fail, error))
                            return
                        }
                    }
                }
            case .fail(let error):
                Ortto.log().error("Could not get config: \(error)")
                self.completionHandler?((.fail, nil))
            }
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
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

internal class WidgetViewUIDelegate: NSObject, WKUIDelegate {
}

enum LoadWidgetResult: Error {
    case success, fail
}

internal extension WKWebView {
    func setAp3cConfig(_ config: WebViewConfig, completionHandler: ((Bool?, Error?) -> Void)? = nil) throws -> Void {
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        let json = String(data: data, encoding: .utf8)!
        
        self.evaluateJavaScript("ap3cWebView.setConfig(\(json)); ap3cWebView.hasConfig()") { (result, error) in
            
            if let intResult = result as? Int {
                completionHandler?(Bool(intResult > 0), error)
            } else {
                completionHandler?(false, error)
            }
        }
    }
    
    func ap3cStart(completionHandler: ((Any?, Error?) -> Void)? = nil) -> Void {
        self.evaluateJavaScript("ap3cWebView.start()") { (result, error) in
            completionHandler?(result, error)
        }
    }
}

internal func fetchWidgets(_ widgetId: String?, completion: @escaping (WidgetsResponse) -> Void) -> Void {
    let user = Ortto.shared.identifier
    
    let request = WidgetsGetRequest.init(
        sessionId: OrttoCapture.shared.sessionId,
        applicationKey: OrttoCapture.shared.dataSourceKey,
        contactId: user?.contactID,
        emailAddress: user?.email
    )
    
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
            Ortto.shared.setSessionId(sessionId)
        }
        
        completion(data)
    }
}

internal func getScreenName() -> String? {
    Ortto.shared.screenName
}

internal func getAppName() -> String? {
    if let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String {
        return "\(appName) (iOS)"
    }
    
    return nil
}

internal func getPageContext() -> [String: String] {
    var context: [String: String] = [String: String]()
    
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

enum Ap3cConfigResult {
    case success(_ config: WebViewConfig)
    case fail(_ error: Ap3cConfigError)
}

enum Ap3cConfigError: Error {
    case captureJsURLMissing
    case apiHostMissing
}

internal func getAp3cConfig(widgetId: String?, completion: @escaping (Ap3cConfigResult) -> Void) -> Void {
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
