//
//  File.swift
//  
//
//  Created by Mitch Flindell on 21/6/2023.
//

import Foundation
import OrttoPushSDKCore
import SwiftUI

public class OrttoCapture: ObservableObject, Capture {
    internal var sessionId: String { get {
        Ortto.shared.getSessionId()!
    }}
    internal let dataSourceKey: String
    internal let captureJsURL: URL
    internal let keyWindow: UIWindow
    
    private var _widgetView: OrttoWidgetView?
    internal var widgetView: OrttoWidgetView {
        get {
            if _widgetView == nil {
                _widgetView = OrttoWidgetView(closeWidgetRequestHandler: self.hideWidget)
            }
            
            return _widgetView!
        }
    }
    
    public private(set) static var shared: OrttoCapture!
    
    init(dataSourceKey: String, captureJSURL: URL, keyWindow: UIWindow) {
        self.dataSourceKey = dataSourceKey
        self.captureJsURL = captureJSURL
        self.keyWindow = keyWindow
    }
    
    public func showWidget(_ id: String) {
        DispatchQueue.main.async {
            self.widgetView.setWidgetId(id)
            self.widgetView.load() { webView in
                let rootViewController = self.keyWindow.rootViewController!
                rootViewController.view.addSubview(webView)
                rootViewController.edgesForExtendedLayout = [.all]
            }
        }
    }
    
    public func hideWidget() {
        DispatchQueue.main.async {
            self.widgetView.setWidgetId(nil)
            self.widgetView.webView.removeFromSuperview()
        }
    }
    
    public static func initialize(dataSourceKey: String, captureJsURL: URL) throws -> Void {
        guard let keyWindow = Self.getKeyWindow() else {
            throw CaptureInitializationError.noKeyWindow
        }
        
        shared = OrttoCapture(
            dataSourceKey: dataSourceKey,
            captureJSURL: captureJsURL,
            keyWindow: keyWindow
        )
        
        Ortto.shared.capture = shared
    }
    
    static func getKeyWindow() -> UIWindow? {
        UIApplication
            .shared
            .connectedScenes
            .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
            .last { $0.isKeyWindow }
    }
}

enum CaptureInitializationError: Error {
    case noKeyWindow
}
