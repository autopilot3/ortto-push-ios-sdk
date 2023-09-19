//
//  Log.swift
//  
//
//  Created by Mitch Flindell on 24/11/2022.
//

import Foundation
#if canImport(os)
import os.log
#endif

public protocol OrttoLogger {
    func info(_ message: String)
    func warn(_ message: String)
    func error(_ message: String)
    func debug(_ message: String)
}

public enum LogLevel {
    case debug
    case error
    case info
    case warning
}

public class PrintLogger: OrttoLogger {
    private let system = "com.ortto.sdk"
    private let category = "ORTTO"
    
    #if canImport(os)
    private func log(_ message: String, _ level: OSLogType) {
        if #available(iOS 14, *) {
            let logger = os.Logger(subsystem: self.system, category: self.category)
            logger.log(level: level, "\(message, privacy: .public)")
        } else {
            let logger = OSLog(subsystem: system, category: category)
            os_log("%{public}@", log: logger, type: level, message)
        }
    }
    
    public func info(_ message: String) {
        log(message, .info)
    }
    
    public func warn(_ message: String) {
        log(message, .fault)
    }
    
    public func error(_ message: String) {
        log(message, .error)
    }
    
    public func debug(_ message: String) {
        log(message, .debug)
    }
    #endif
}
