//
//  File.swift
//  
//
//  Created by Mitch Flindell on 7/6/2023.
//

import SwiftUI
import WebKit
import SwiftSoup
import OrttoPushSDKCore

internal class OrttoWidgetView {
    static private var htmlString: String = ""
    
    private let closeWidgetRequestHandler: (() -> Void)
    private let messageHandler: WidgetViewMessageHandler
    private let navigationDelegate: WidgetViewNavigationDelegate
    private let uiDelegate: WidgetViewUIDelegate
    internal let webView: WKWebView
    internal var loaded: Bool = false
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
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
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
        if loaded {
            getAp3cConfig(widgetId: self.widgetId) { config in
                do {
                    try self.webView.setAp3cConfig(config)
                    
                    self.webView.ap3cStart() { (result, error) in
                        if let error = error {
                            Ortto.log().error("Error starting widget: \(error)")
                        } else {
                            completionHandler(self.webView)
                        }
                    }
                } catch {
                    Ortto.log().error("Error setting config: \(error)")
                }
            }
            
            return
        }
        
        do {
            navigationDelegate.setCompletionHandler() { (result, error) in
                if result == .success {
                    completionHandler(self.webView)
                }
            
                if let error = error {
                    Ortto.log().error("Error loading widget: \(error)")
                }
            }
            
            let htmlString = try {
                if (OrttoWidgetView.htmlString.isEmpty) {
                    let htmlFile = Bundle.module.url(forResource: "index", withExtension: "html")!
                    
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
            
            webView.loadHTMLString(htmlString, baseURL: Bundle.module.bundleURL)
            
            self.loaded = true
        } catch {
            print("Error loading HTML: \(error)")
        }
    }
}

struct Ap3cMessage: Codable {
    let type: String
}

internal class WidgetViewMessageHandler: NSObject, WKScriptMessageHandler {
    internal let closeWidgetRequestHandler: () -> Void
    
    init(_ closeWidgetRequestHandler: @escaping () -> Void) {
        self.closeWidgetRequestHandler = closeWidgetRequestHandler
    }
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "log", let messageBody = message.body as? String {
            Ortto.log().debug("JavaScript console.log: \(messageBody)")
        } else if message.name == "error", let messageBody = message.body as? String {
            Ortto.log().debug("JavaScript error: \(messageBody)")
        } else if (message.name == "messageHandler") {
            let messageBody = message.body as? [String: Any]
            
            if let type = messageBody?["type"] as? String {
                switch (type) {
                case "widget-close":
                    self.closeWidgetRequestHandler()
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
            
            window.onerror = function(message, source, lineno, colno, error) {
                const errorData = {
                    message: message,
                    source: source,
                    lineno: lineno,
                    colno: colno,
                    error: String(error) // Ensure the error object is converted to a string
                };
            
                // Send errorData to Swift
                window.webkit.messageHandlers.error.postMessage(JSON.stringify(errorData));
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
            let appJs = Bundle.module.url(forResource: "app", withExtension: "js")!
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
        
        getAp3cConfig(widgetId: self.widgetId) { config in
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
                        },
//                        .filter { widget in
//                            if let expiry = widget.expiry {
//                                return !expiry.timeIntervalSinceNow.isLess(than: 0)
//                            }
//
//                            return true
//                        },
                    hasLogo: widgetsResponse.hasLogo,
                    enabledGdpr: widgetsResponse.enabledGdpr,
                    recaptchaSiteKey: widgetsResponse.recaptchaSiteKey,
                    countryCode: widgetsResponse.countryCode,
                    serviceWorkerUrl: widgetsResponse.serviceWorkerUrl,
                    cdnUrl: widgetsResponse.cdnUrl
                )
            } else {
                return widgetsResponse
            }
        }()
        
        completion(data)
    }
}

internal func getAp3cConfig(widgetId: String?, completion: @escaping (WebViewConfig) -> Void) -> Void {
    fetchWidgets(widgetId) { data in
        let config = WebViewConfig(
            token: OrttoCapture.shared.dataSourceKey,
            endpoint: OrttoCapture.shared.apiHost.absoluteString,
            captureJsUrl: OrttoCapture.shared.captureJsURL.absoluteString,
            data: data
        )
        
        completion(config)
    }
}
