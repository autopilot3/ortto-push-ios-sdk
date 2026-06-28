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
        var baseName = suggestedName ?? urlName ?? "download"

        // UNNotificationAttachment infers the media type from the file extension,
        // so the saved file MUST have one. `suggestedFilename` is frequently
        // "Unknown" (no extension), which makes the attachment fail silently —
        // derive an extension from the response MIME type, then the URL.
        if (baseName as NSString).pathExtension.isEmpty {
            let urlExt = urlName.map { ($0 as NSString).pathExtension } ?? ""
            let ext = mimeExtension(response?.mimeType) ?? (urlExt.isEmpty ? "img" : urlExt)
            baseName = "\(baseName).\(ext)"
        }

        return "\(UUID().uuidString)_\(baseName)"
    }

    private static func mimeExtension(_ mimeType: String?) -> String? {
        switch mimeType?.lowercased() {
        case "image/jpeg", "image/jpg": return "jpg"
        case "image/png": return "png"
        case "image/gif": return "gif"
        case "image/webp": return "webp"
        case "image/heic", "image/heif": return "heic"
        default: return nil
        }
    }
}
