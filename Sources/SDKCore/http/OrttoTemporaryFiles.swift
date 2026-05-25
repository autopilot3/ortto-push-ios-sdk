//
//  OrttoTemporaryFiles.swift
//
//  Created on 25/5/2026.
//

import Foundation

enum OrttoTemporaryFiles {
    static func directory(for kind: OrttoDownloadKind, fileManager: FileManager = .default) -> URL {
        fileManager.temporaryDirectory
            .appendingPathComponent("ortto_sdk", isDirectory: true)
            .appendingPathComponent(kind.directoryName, isDirectory: true)
    }

    static func moveDownloadedFile(
        from temporaryURL: URL,
        response: URLResponse?,
        originalURL: URL,
        kind: OrttoDownloadKind,
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = directory(for: kind, fileManager: fileManager)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileName = uniqueFileName(response: response, originalURL: originalURL)
        let destinationURL = directory.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }

    private static func uniqueFileName(response: URLResponse?, originalURL: URL) -> String {
        let suggestedName = response?.suggestedFilename
        let urlName = originalURL.lastPathComponent.isEmpty ? nil : originalURL.lastPathComponent
        let baseName = suggestedName ?? urlName ?? "download"

        return "\(UUID().uuidString)_\(baseName)"
    }
}
