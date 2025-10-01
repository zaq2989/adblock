//
//  SharedStorage.swift
//  CleanView
//
//  App Groups shared storage utilities
//

import Foundation

/// Utility class for managing App Groups shared storage
class SharedStorage {

    // MARK: - Container URL

    /// Get the shared App Group container URL
    static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroups.identifier
        )
    }

    // MARK: - File Operations

    /// Save data to shared container
    static func save(_ data: Data, to fileName: String) throws {
        guard let containerURL = containerURL else {
            throw StorageError.containerNotFound
        }

        let fileURL = containerURL.appendingPathComponent(fileName)
        try data.write(to: fileURL)
    }

    /// Load data from shared container
    static func load(from fileName: String) throws -> Data {
        guard let containerURL = containerURL else {
            throw StorageError.containerNotFound
        }

        let fileURL = containerURL.appendingPathComponent(fileName)
        return try Data(contentsOf: fileURL)
    }

    /// Check if file exists in shared container
    static func fileExists(_ fileName: String) -> Bool {
        guard let containerURL = containerURL else { return false }

        let fileURL = containerURL.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// Delete file from shared container
    static func delete(_ fileName: String) throws {
        guard let containerURL = containerURL else {
            throw StorageError.containerNotFound
        }

        let fileURL = containerURL.appendingPathComponent(fileName)
        try FileManager.default.removeItem(at: fileURL)
    }

    /// Get file URL in shared container
    static func fileURL(for fileName: String) -> URL? {
        containerURL?.appendingPathComponent(fileName)
    }

    // MARK: - JSON Operations

    /// Save JSON encodable object to shared container
    static func saveJSON<T: Encodable>(_ object: T, to fileName: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(object)
        try save(data, to: fileName)
    }

    /// Load JSON decodable object from shared container
    static func loadJSON<T: Decodable>(_ type: T.Type, from fileName: String) throws -> T {
        let data = try load(from: fileName)
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }

    // MARK: - UserDefaults

    /// Get shared UserDefaults for App Group
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroups.identifier)
    }

    /// Save value to shared UserDefaults
    static func setSharedDefault(_ value: Any?, forKey key: String) {
        sharedDefaults?.set(value, forKey: key)
    }

    /// Get value from shared UserDefaults
    static func getSharedDefault(forKey key: String) -> Any? {
        sharedDefaults?.object(forKey: key)
    }

    // MARK: - Directory Management

    /// Create directory in shared container if needed
    static func createDirectoryIfNeeded(_ directoryName: String) throws {
        guard let containerURL = containerURL else {
            throw StorageError.containerNotFound
        }

        let directoryURL = containerURL.appendingPathComponent(directoryName)

        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        }
    }

    /// List files in shared container
    static func listFiles(in directory: String? = nil) throws -> [String] {
        guard let containerURL = containerURL else {
            throw StorageError.containerNotFound
        }

        let directoryURL = directory != nil ?
            containerURL.appendingPathComponent(directory!) : containerURL

        let contents = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )

        return contents.map { $0.lastPathComponent }
    }

    // MARK: - Migration

    /// Migrate data from app container to shared container
    static func migrateFromAppContainer(fileName: String) throws {
        let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        let sourceURL = documentsURL.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: sourceURL.path) {
            let data = try Data(contentsOf: sourceURL)
            try save(data, to: fileName)
            try FileManager.default.removeItem(at: sourceURL)
        }
    }

    // MARK: - Cleanup

    /// Clean up old or temporary files
    static func cleanup(olderThan days: Int) {
        guard let containerURL = containerURL else { return }

        let cutoffDate = Date().addingTimeInterval(-Double(days * 86400))

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: containerURL,
                includingPropertiesForKeys: [.contentModificationDateKey]
            )

            for url in contents {
                if url.lastPathComponent.hasPrefix("temp_") {
                    if let attributes = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                       let modificationDate = attributes.contentModificationDate,
                       modificationDate < cutoffDate {
                        try? FileManager.default.removeItem(at: url)
                    }
                }
            }
        } catch {
            print("Cleanup failed: \(error)")
        }
    }

    // MARK: - Storage Info

    /// Get storage size used by app group
    static var usedStorageSize: Int64 {
        guard let containerURL = containerURL else { return 0 }

        var size: Int64 = 0

        if let enumerator = FileManager.default.enumerator(
            at: containerURL,
            includingPropertiesForKeys: [.fileSizeKey]
        ) {
            for case let url as URL in enumerator {
                if let attributes = try? url.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = attributes.fileSize {
                    size += Int64(fileSize)
                }
            }
        }

        return size
    }

    /// Format bytes to human readable string
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Errors
enum StorageError: Error, LocalizedError {
    case containerNotFound
    case fileNotFound
    case saveFailed
    case loadFailed

    var errorDescription: String? {
        switch self {
        case .containerNotFound:
            return "App Group container not found"
        case .fileNotFound:
            return "File not found in shared storage"
        case .saveFailed:
            return "Failed to save to shared storage"
        case .loadFailed:
            return "Failed to load from shared storage"
        }
    }
}