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

internal struct OrttoWidgetView {
    static private var htmlString: String = ""
    
    private let closeWidgetRequestHandler: (() -> Void)
    private let messageHandler: WidgetViewMessageHandler
    private let navigationDelegate: WidgetViewNavigationDelegate
    private let uiDelegate: WidgetViewUIDelegate
    internal let webView: WKWebView
    
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
        
        let webView = WKWebView(frame: UIScreen.main.bounds, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.uiDelegate = uiDelegate
        webView.navigationDelegate = navigationDelegate
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        self.webView = webView
    }
    
    public func setWidgetId(_ id: String?) -> Void {
        navigationDelegate.widgetId = id
    }
    
    public func load(_ completionHandler: @escaping (_ webView: WKWebView) -> Void) {
        do {
            navigationDelegate.setCompletionHandler() { (result, error) in
                if result == .success {
                    completionHandler(webView)
                }
            
                if let error = error {
                    print("Error loading widget: \(error)")
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
            print("JavaScript console.log: \(messageBody)")
        } else if message.name == "error", let messageBody = message.body as? String {
            print("JavaScript error: \(messageBody)")
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
                    print("Error setting console.log: \(error)")
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
                    print("Error evaluating app.js: \(error)")
                    self.completionHandler?((.fail, error))
                    return
                }
            }
        } catch {
            print("Error evaluating app.js: \(error)")
            self.completionHandler?((.fail, error))
            return
        }
        
        if (ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1") {
            self.completionHandler?((.fail, nil))
            return
        }
        
        let user = Ortto.shared.identifier
        
        let request = WidgetsGetRequest.init(
            sessionId: OrttoCapture.shared.sessionId,
            applicationKey: OrttoCapture.shared.dataSourceKey,
            contactId: user?.contactID,
            emailAddress: user?.email
        )
        
        CaptureAPI.fetchWidgets(request) { widgetsResponse in
            let data: WidgetsResponse = {
                if let widgetId = self.widgetId {
                    return WidgetsResponse(
                        widgets: widgetsResponse.widgets.filter { widget in
                            widget.id == widgetId
                        }
                    )
                } else {
                    return widgetsResponse
                }
            }()
            
            if data.widgets.isEmpty {
                self.closeWidgetRequestHandler()
                return
            }
            
            do {
                // TODO: dont do this
                let captureJsEndpoint = OrttoCapture.shared.captureJsURL.deletingLastPathComponent().absoluteString
                let config = WebViewConfig(
                    token: OrttoCapture.shared.dataSourceKey,
                    endpoint: captureJsEndpoint,
                    data: data
                )
                
                let encoder = JSONEncoder()
                let data = try encoder.encode(config)
                let json = String(data: data, encoding: .utf8)!
                let script = "ap3cWebView.setConfig(\(json)); ap3cWebView.start(); ap3cWebView.hasConfig()"
                
                DispatchQueue.main.async {
                    webView.evaluateJavaScript(script) { (result, error) in
                        if let error = error {
                            print("Error evaluating start script: \(error)")
                            self.completionHandler?((.fail, error))
                            return
                        }
                        
                        if let result = result {
                            print("Ap3c config loaded: \(result)")
                            self.completionHandler?((.success, nil))
                        }
                    }
                }
            } catch {
                print("Error evaluating start script: \(error)")
                self.completionHandler?((.fail, error))
            }
        }
    }
}

internal class WidgetViewUIDelegate: NSObject, WKUIDelegate {
}

enum LoadWidgetResult: Error {
    case success, fail
}
