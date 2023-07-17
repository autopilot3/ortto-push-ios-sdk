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
    internal let dataSourceKey: String
    internal let captureJsURL: URL
    internal let apiHost: URL
    
    private var lock = os_unfair_lock()
    
    private static let orttoWidgetQueueKey = "ortto_widgets_queue"
    
    internal var sessionId: String { get {
        Ortto.shared.getSessionId()!
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
    
    private var _queue: [String] {
        get {
            UserDefaults.standard.array(forKey: Self.orttoWidgetQueueKey) as? [String] ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.orttoWidgetQueueKey)
        }
    }
    private var _timer: Timer?
    
    public private(set) static var shared: OrttoCapture!
    
    init(dataSourceKey: String, captureJSURL: URL, apiHost: URL) {
        self.dataSourceKey = dataSourceKey
        self.captureJsURL = captureJSURL
        self.apiHost = apiHost
        
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func appDidBecomeActive() -> Void {
        processNextWidgetFromQueue()
    }
    
    public func processNextWidgetFromQueue() -> Void {
        if _queue.isEmpty {
            return
        }
        
        _timer?.invalidate()
        
        _timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            if let widgetId = self._queue.popLast() {
                self.showWidget(widgetId)
            }
        }
    }
    
    public func queueWidget(_ id: String) -> Void {
        var queue = _queue
        let sizeBefore = queue.count
        
        // make sure we can't queue the same widget twice
        queue = Array(Set([id] + queue))
        let sizeAfter = queue.count
        
        if sizeAfter != sizeBefore {
            _queue = queue
            
            if queue.count == 1 {
                _timer?.invalidate()
            }
        }
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
            self.widgetView.setWidgetId(id)
            self.widgetView.load() { webView in
                if let rootViewController = self.keyWindow?.rootViewController {
                    rootViewController.edgesForExtendedLayout = [.all]
                    
                    // this is to hide the keyboard in the case that it is currently open
                    rootViewController.view.endEditing(true)
                    
                    webView.frame = rootViewController.view.bounds
                    rootViewController.view.addSubview(webView)
                }
            }
        }
    }
    
    public func hideWidget() {
        // add timer to give animation time to play and modal to fade out
        _ = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            DispatchQueue.main.async {
                self.widgetView.setWidgetId(nil)
                self.widgetView.webView.removeFromSuperview()
            }
            
            self.isWidgetActive = false
            self.processNextWidgetFromQueue()
        }
    }
    
    public static func initialize(dataSourceKey: String, captureJsURL: URL, apiHost: URL) throws -> Void {
        
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
