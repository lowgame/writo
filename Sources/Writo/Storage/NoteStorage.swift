import Foundation

public final class NoteStorage: @unchecked Sendable {
    public static let shared = NoteStorage()

    private let fileManager = FileManager.default
    public private(set) var vaultURL: URL
    public private(set) var archiveURL: URL
    private var customFilenames: Set<String> = []
    public let isCustomVault: Bool

    public init(customVaultURL: URL? = nil) {
        self.isCustomVault = (customVaultURL != nil)
        if let custom = customVaultURL {
            self.vaultURL = custom
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.vaultURL = appSupport.appendingPathComponent("Writo", isDirectory: true)
        }
        self.archiveURL = self.vaultURL.appendingPathComponent(".archive", isDirectory: true)
        ensureDirectoriesExist()
        loadCustomFilenames()

        if customVaultURL == nil {
            migrateFromLegacyVaultIfNeeded()
            createLibrarySymlinkIfNeeded()
        }
    }

    private var customFilenamesFile: URL {
        vaultURL.appendingPathComponent(".custom_filenames.json")
    }

    private func loadCustomFilenames() {
        if let data = try? Data(contentsOf: customFilenamesFile),
           let list = try? JSONDecoder().decode([String].self, from: data) {
            customFilenames = Set(list)
        } else if let saved = UserDefaults.standard.stringArray(forKey: "WritoCustomFilenames") {
            customFilenames = Set(saved)
        }
    }

    private func saveCustomFilenames() {
        let list = Array(customFilenames)
        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: customFilenamesFile, options: .atomic)
        }
        UserDefaults.standard.set(list, forKey: "WritoCustomFilenames")
    }

    private func ensureDirectoriesExist() {
        try? fileManager.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: archiveURL, withIntermediateDirectories: true)
    }

    private var isRunningTests: Bool {
        isCustomVault || NSClassFromString("XCTestCase") != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    public var iCloudVaultURL: URL? {
        guard !isRunningTests else { return nil }
        let home = fileManager.homeDirectoryForCurrentUser
        let cloudContainer = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        if fileManager.fileExists(atPath: cloudContainer.path) {
            let cloudWrito = cloudContainer.appendingPathComponent("writo", isDirectory: true)
            if !fileManager.fileExists(atPath: cloudWrito.path) {
                try? fileManager.createDirectory(at: cloudWrito, withIntermediateDirectories: true)
            }
            return cloudWrito
        }
        return nil
    }

    public var iCloudArchiveURL: URL? {
        guard let cloudVault = iCloudVaultURL else { return nil }
        let cloudArchive = cloudVault.appendingPathComponent(".archive", isDirectory: true)
        if !fileManager.fileExists(atPath: cloudArchive.path) {
            try? fileManager.createDirectory(at: cloudArchive, withIntermediateDirectories: true)
        }
        return cloudArchive
    }

    public func syncWithCloud(isArchived: Bool) {
        let localDir = isArchived ? archiveURL : vaultURL
        guard let cloudDir = isArchived ? iCloudArchiveURL : iCloudVaultURL else { return }

        // 1. Sync from iCloud to Local
        if let cloudFiles = try? fileManager.contentsOfDirectory(at: cloudDir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) {
            for cloudFile in cloudFiles where cloudFile.pathExtension.lowercased() == "md" {
                let localFile = localDir.appendingPathComponent(cloudFile.lastPathComponent)
                if !fileManager.fileExists(atPath: localFile.path) {
                    try? fileManager.copyItem(at: cloudFile, to: localFile)
                } else {
                    let cloudMod = (try? cloudFile.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let localMod = (try? localFile.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    if cloudMod > localMod {
                        try? fileManager.removeItem(at: localFile)
                        try? fileManager.copyItem(at: cloudFile, to: localFile)
                    }
                }
            }
        }

        // 2. Sync from Local to iCloud
        if let localFiles = try? fileManager.contentsOfDirectory(at: localDir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) {
            for localFile in localFiles where localFile.pathExtension.lowercased() == "md" {
                let cloudFile = cloudDir.appendingPathComponent(localFile.lastPathComponent)
                if !fileManager.fileExists(atPath: cloudFile.path) {
                    try? fileManager.copyItem(at: localFile, to: cloudFile)
                } else {
                    let localMod = (try? localFile.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let cloudMod = (try? cloudFile.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    if localMod > cloudMod {
                        try? fileManager.removeItem(at: cloudFile)
                        try? fileManager.copyItem(at: localFile, to: cloudFile)
                    }
                }
            }
        }
    }

    private func migrateFromLegacyVaultIfNeeded() {
        guard let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let legacyVault = docs.appendingPathComponent("Writo", isDirectory: true)
        guard fileManager.fileExists(atPath: legacyVault.path), legacyVault != vaultURL else { return }

        if let items = try? fileManager.contentsOfDirectory(atPath: legacyVault.path) {
            for item in items {
                let src = legacyVault.appendingPathComponent(item)
                let dst = vaultURL.appendingPathComponent(item)
                if !fileManager.fileExists(atPath: dst.path) {
                    try? fileManager.copyItem(at: src, to: dst)
                }
            }
        }
    }

    private func createLibrarySymlinkIfNeeded() {
        guard let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else { return }
        let libraryWrito = library.appendingPathComponent("Writo", isDirectory: true)
        if !fileManager.fileExists(atPath: libraryWrito.path) {
            try? fileManager.createSymbolicLink(at: libraryWrito, withDestinationURL: vaultURL)
        }
    }

    // MARK: - Read Notes
    public func loadActiveNotes() -> [Note] {
        syncWithCloud(isArchived: false)
        return loadNotes(from: vaultURL, isArchived: false)
    }

    public func loadArchivedNotes() -> [Note] {
        syncWithCloud(isArchived: true)
        return loadNotes(from: archiveURL, isArchived: true)
    }

    private func loadNotes(from directory: URL, isArchived: Bool) -> [Note] {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var notes: [Note] = []
        for fileURL in fileURLs where fileURL.pathExtension.lowercased() == "md" {
            let filename = fileURL.lastPathComponent
            let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""

            var createdAt = Date()
            var updatedAt = Date()

            if let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey]) {
                createdAt = values.creationDate ?? Date()
                updatedAt = values.contentModificationDate ?? Date()
            }

            let id = filename.replacingOccurrences(of: ".md", with: "")
            let isCustom = customFilenames.contains(filename)
            notes.append(Note(
                id: id,
                filename: filename,
                content: content,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isArchived: isArchived,
                hasCustomFilename: isCustom
            ))
        }

        return notes.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Rename Note (User Explicit Override)
    @discardableResult
    public func renameNote(_ note: Note, to newFilename: String) throws -> Note {
        ensureDirectoriesExist()

        // Defense-in-depth: Strip path traversal tokens, directory separators, and control characters
        let stripped = newFilename
            .replacingOccurrences(of: "..", with: "")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".-"))

        var sanitized = stripped
        if !sanitized.hasSuffix(".md") {
            sanitized += ".md"
        }
        guard !sanitized.isEmpty, sanitized != ".md" else { return note }

        let targetDir = (note.isArchived ? archiveURL : vaultURL).standardizedFileURL
        let oldURL = targetDir.appendingPathComponent(note.filename).standardizedFileURL
        let newURL = targetDir.appendingPathComponent(sanitized).standardizedFileURL

        // Path traversal guard: Ensure target stays strictly inside the target directory
        guard newURL.deletingLastPathComponent().standardizedFileURL == targetDir else {
            return note
        }

        if oldURL != newURL && fileManager.fileExists(atPath: oldURL.path) {
            if !fileManager.fileExists(atPath: newURL.path) {
                try fileManager.moveItem(at: oldURL, to: newURL)
            }
        }

        if let cloudTargetDir = (note.isArchived ? iCloudArchiveURL : iCloudVaultURL)?.standardizedFileURL {
            let oldCloudURL = cloudTargetDir.appendingPathComponent(note.filename).standardizedFileURL
            let newCloudURL = cloudTargetDir.appendingPathComponent(sanitized).standardizedFileURL
            if oldCloudURL != newCloudURL && fileManager.fileExists(atPath: oldCloudURL.path) {
                if !fileManager.fileExists(atPath: newCloudURL.path) {
                    try? fileManager.moveItem(at: oldCloudURL, to: newCloudURL)
                }
            }
        }

        customFilenames.remove(note.filename)
        customFilenames.insert(sanitized)
        saveCustomFilenames()

        var updated = note
        updated.filename = sanitized
        updated.hasCustomFilename = true
        return updated
    }

    // MARK: - Save Note
    @discardableResult
    public func saveNote(_ note: Note) throws -> Note {
        ensureDirectoriesExist()
        var updatedNote = note
        let targetDir = note.isArchived ? archiveURL : vaultURL

        let isCustom = customFilenames.contains(note.filename) || note.hasCustomFilename

        if isCustom {
            // Keep user's custom filename permanently until changed again by user
            customFilenames.insert(note.filename)
            saveCustomFilenames()
            updatedNote.hasCustomFilename = true
        } else {
            // Determine appropriate filename from title (max 20 chars)
            let expectedSlug = Note.slugify(title: Note.extractTitle(from: note.content))
            let expectedFilename = "\(expectedSlug).md"

            // If file previously existed with a different filename, rename it
            if note.filename != expectedFilename && !note.filename.isEmpty {
                let oldURL = targetDir.appendingPathComponent(note.filename)
                let newURL = targetDir.appendingPathComponent(expectedFilename)

                // Only rename if new name isn't clashing with another distinct file
                if !fileManager.fileExists(atPath: newURL.path) || oldURL == newURL {
                    try? fileManager.moveItem(at: oldURL, to: newURL)
                    updatedNote.filename = expectedFilename
                }
            }
        }

        let finalURL = targetDir.appendingPathComponent(updatedNote.filename)
        try updatedNote.content.write(to: finalURL, atomically: true, encoding: .utf8)
        updatedNote.updatedAt = Date()

        if let cloudTargetDir = note.isArchived ? iCloudArchiveURL : iCloudVaultURL {
            let cloudURL = cloudTargetDir.appendingPathComponent(updatedNote.filename)
            try? updatedNote.content.write(to: cloudURL, atomically: false, encoding: .utf8)
        }

        return updatedNote
    }

    // MARK: - Non-Destructive Soft Archive
    @discardableResult
    public func archiveNote(_ note: Note) throws -> Note {
        ensureDirectoriesExist()
        let sourceURL = vaultURL.appendingPathComponent(note.filename)
        let destURL = archiveURL.appendingPathComponent(note.filename)

        if fileManager.fileExists(atPath: sourceURL.path) {
            // Remove any existing archive collision first
            if fileManager.fileExists(atPath: destURL.path) {
                try? fileManager.removeItem(at: destURL)
            }
            try fileManager.moveItem(at: sourceURL, to: destURL)
        }

        if let cloudVault = iCloudVaultURL, let cloudArchive = iCloudArchiveURL {
            let cloudSrc = cloudVault.appendingPathComponent(note.filename)
            let cloudDst = cloudArchive.appendingPathComponent(note.filename)
            if fileManager.fileExists(atPath: cloudSrc.path) {
                if fileManager.fileExists(atPath: cloudDst.path) {
                    try? fileManager.removeItem(at: cloudDst)
                }
                try? fileManager.moveItem(at: cloudSrc, to: cloudDst)
            }
        }

        var archivedNote = note
        archivedNote.isArchived = true
        archivedNote.updatedAt = Date()
        return archivedNote
    }

    // MARK: - Undo Soft Archive (Restore)
    @discardableResult
    public func restoreNote(_ note: Note) throws -> Note {
        ensureDirectoriesExist()
        let sourceURL = archiveURL.appendingPathComponent(note.filename)
        let destURL = vaultURL.appendingPathComponent(note.filename)

        var finalFilename = note.filename

        if fileManager.fileExists(atPath: sourceURL.path) {
            if fileManager.fileExists(atPath: destURL.path) {
                // If a new note with same name was created, resolve by prefixing timestamp
                let backupName = "\(Int(Date().timeIntervalSince1970))-\(note.filename)"
                finalFilename = backupName
                let altURL = vaultURL.appendingPathComponent(backupName)
                try fileManager.moveItem(at: sourceURL, to: altURL)
            } else {
                try fileManager.moveItem(at: sourceURL, to: destURL)
            }
        }

        if let cloudVault = iCloudVaultURL, let cloudArchive = iCloudArchiveURL {
            let cloudSrc = cloudArchive.appendingPathComponent(note.filename)
            let cloudDst = cloudVault.appendingPathComponent(finalFilename)
            if fileManager.fileExists(atPath: cloudSrc.path) {
                if !fileManager.fileExists(atPath: cloudDst.path) {
                    try? fileManager.moveItem(at: cloudSrc, to: cloudDst)
                }
            }
        }

        var restoredNote = note
        restoredNote.filename = finalFilename
        restoredNote.isArchived = false
        restoredNote.updatedAt = Date()
        return restoredNote
    }

    // MARK: - Permanent Deletion
    public func permanentlyDeleteNote(_ note: Note) throws {
        ensureDirectoriesExist()
        let targetDir = note.isArchived ? archiveURL : vaultURL
        let fileURL = targetDir.appendingPathComponent(note.filename)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }

        if let cloudTargetDir = note.isArchived ? iCloudArchiveURL : iCloudVaultURL {
            let cloudFileURL = cloudTargetDir.appendingPathComponent(note.filename)
            if fileManager.fileExists(atPath: cloudFileURL.path) {
                try? fileManager.removeItem(at: cloudFileURL)
            }
        }

        customFilenames.remove(note.filename)
        saveCustomFilenames()
    }

    public func saveAllToCloud(notes: [Note], archivedNotes: [Note]) {
        for note in notes {
            _ = try? saveNote(note)
        }
        for note in archivedNotes {
            _ = try? saveNote(note)
        }
        syncWithCloud(isArchived: false)
        syncWithCloud(isArchived: true)
    }
}
