//
//  OrttoTestCase.swift
//
//  Created on 25/5/2026.
//

import Foundation
@testable import OrttoSDKCore
import XCTest

class OrttoTestCase: XCTestCase {
    private var startedAt: Date?

    override func setUp() {
        super.setUp()

        startedAt = Date()
        TestTranscript.shared.startTest(name, startedAt: startedAt)
    }

    override func tearDown() {
        super.tearDown()
    }
}

private final class TestTranscript: NSObject, XCTestObservation {
    static let shared = TestTranscript()

    private let lock = NSLock()
    private let logger = TestTranscriptLogger()
    private var didInstallObserver = false
    private var didPrintHeader = false
    private var startedAtByTestName: [String: Date] = [:]

    override private init() {
        super.init()
    }

    func startTest(_ name: String, startedAt: Date?) {
        installObserverIfNeeded()

        lock.lock()
        if !didPrintHeader {
            emit("")
            emit("ORTTO TEST TRANSCRIPT")
            didPrintHeader = true
        }
        startedAtByTestName[name] = startedAt
        lock.unlock()

        Ortto.shared.setLogger(customLogger: logger)
        logger.startTest(name)

        emit("")
        emit("RUN \(name)")
    }

    func testCaseDidFinish(_ testCase: XCTestCase) {
        let name = testCase.name
        let logs = logger.finishTest(name)

        for entry in logs {
            emit("  \(entry)")
        }

        let duration = startedAt(for: name).map { String(format: "(%.3fs)", Date().timeIntervalSince($0)) } ?? ""
        let result = testCase.testRun?.hasSucceeded == true ? "PASS" : "FAIL"
        emit("\(result) \(name) \(duration)")
    }

    private func installObserverIfNeeded() {
        lock.lock()
        defer { lock.unlock() }

        guard !didInstallObserver else {
            return
        }

        XCTestObservationCenter.shared.addTestObserver(self)
        didInstallObserver = true
    }

    private func startedAt(for name: String) -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return startedAtByTestName.removeValue(forKey: name)
    }

    private func emit(_ message: String) {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
    }
}

private final class TestTranscriptLogger: OrttoLogger {
    private let lock = NSLock()
    private var currentTestName: String?
    private var logsByTestName: [String: [String]] = [:]

    func startTest(_ name: String) {
        lock.lock()
        currentTestName = name
        logsByTestName[name] = []
        lock.unlock()
    }

    func finishTest(_ name: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }

        if currentTestName == name {
            currentTestName = nil
        }

        return logsByTestName.removeValue(forKey: name) ?? []
    }

    func record(_ level: String, _ message: String) {
        let entry = "[\(level.uppercased())] \(message)"

        lock.lock()
        defer { lock.unlock() }

        guard let currentTestName else {
            FileHandle.standardError.write(Data("  \(entry)\n".utf8))
            return
        }

        logsByTestName[currentTestName, default: []].append(entry)
    }

    func info(_ message: String) {
        record("info", message)
    }

    func warn(_ message: String) {
        record("warn", message)
    }

    func error(_ message: String) {
        record("error", message)
    }

    func debug(_ message: String) {
        record("debug", message)
    }
}
