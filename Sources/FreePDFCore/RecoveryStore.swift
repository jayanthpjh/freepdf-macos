import Foundation

/// Stores exact PDF snapshots, preserving PDFKit's encryption, in an application-owned folder.
public struct RecoveryStore {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }
    public func save(_ data: Data, id: UUID) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let file = directory.appendingPathComponent(id.uuidString + ".pdf")
        try data.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
    public func remove(id: UUID) throws {
        let file = directory.appendingPathComponent(id.uuidString + ".pdf")
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }
    public func files() throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "pdf" && UUID(uuidString: $0.deletingPathExtension().lastPathComponent) != nil }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
