//
//  File.swift
//  
//
//  Created by Mitch Flindell on 21/6/2023.
//

import Foundation
import SwiftUI
import Reachability

public class OrttoCapture: ObservableObject, Capture {
    internal let dataSourceKey: String
    internal let captureJsURL: URL?
    internal let apiHost: URL?
    internal let reachability: Reachability
    
    private var lock = os_unfair_lock()
    
    private static let orttoWidgetQueueKey = "ortto_widgets_queue"
    
    internal var sessionId: String? { get {
        Ortto.shared.getSessionId()
    }}
    internal var keyWindow: UIWindow? {
        get {
            Self.getKeyWindow()
        }
    }
    public var isWidgetActive: Bool = false
    
    private var _widgetView: OrttoWidgetView?
    internal var widgetView: OrttoWidgetView {
        get {
            if _widgetView == nil {
                _widgetView = OrttoWidgetView(closeWidgetRequestHandler: self.hideWidget)
            }
            
            return _widgetView!
        }
    }
    
    private var _queue: WidgetQueue
    private var _timer: Timer?
    
    public private(set) static var shared: OrttoCapture!
    
    init(dataSourceKey: String, captureJSURL: URL?, apiHost: URL?) {
        self.dataSourceKey = dataSourceKey
        self.captureJsURL = captureJSURL
        self.apiHost = apiHost
        self._queue = WidgetQueue()
        self.reachability = try! Reachability()
        
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        reachability.whenReachable = { _ in
            self.processNextWidgetFromQueue()
        }
        
        reachability.whenUnreachable = { _ in
            self._timer?.invalidate()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func appDidBecomeActive() -> Void {
        processNextWidgetFromQueue()
    }
    
    public func processNextWidgetFromQueue() -> Void {
        _timer?.invalidate()
        
        _timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            if let widgetId = self._queue.peekLast() {
                self.showWidget(widgetId)
            }
        }
    }
    
    public func queueWidget(_ id: String) -> Void {
        _queue.queue(id)
    }
    
    public func showWidget(_ id: String) {
        let canShowWidget = {
            os_unfair_lock_lock(&lock)
            
            var canShowWidget = false
            
            if !isWidgetActive {
                isWidgetActive = true
                canShowWidget = true
            }
            
            os_unfair_lock_unlock(&lock)
            
            return canShowWidget
        }()
        
        if !canShowWidget {
            return
        }
        
        DispatchQueue.main.async {
            self._queue.remove(id)
            
            self.widgetView.setWidgetId(id)
            self.widgetView.load() { webView in
                let webViewController = UIViewController()
                webViewController.edgesForExtendedLayout = .all
                webViewController.extendedLayoutIncludesOpaqueBars = true
                webViewController.view.backgroundColor = .clear
                webViewController.view.isOpaque = false
                
                webViewController.view.addSubview(webView)
                webView.translatesAutoresizingMaskIntoConstraints = false
                
                NSLayoutConstraint.activate([
                    webView.topAnchor.constraint(equalTo: webViewController.view.topAnchor),
                    webView.bottomAnchor.constraint(equalTo: webViewController.view.bottomAnchor),
                    webView.leadingAnchor.constraint(equalTo: webViewController.view.leadingAnchor),
                    webView.trailingAnchor.constraint(equalTo: webViewController.view.trailingAnchor)
                ])
                
                webViewController.modalPresentationStyle = .overFullScreen
                webViewController.modalTransitionStyle = .crossDissolve
                
                let rootViewController = self.keyWindow?.rootViewController
            
                // this is to hide the keyboard in the case that it is currently open
                rootViewController?.view.endEditing(true)
                
                rootViewController?.present(webViewController, animated: true)
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
    
    public static func initialize(dataSourceKey: String, captureJsURL: URL?, apiHost: URL?) throws -> Void {
        
        shared = OrttoCapture(
            dataSourceKey: dataSourceKey,
            captureJSURL: captureJsURL,
            apiHost: apiHost
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
