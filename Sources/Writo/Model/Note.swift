import Foundation

public struct Note: Identifiable, Equatable, Sendable {
    public let id: String
    public var filename: String
    public var content: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isArchived: Bool
    public var hasCustomFilename: Bool

    public init(
        id: String = UUID().uuidString,
        filename: String? = nil,
        content: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isArchived: Bool = false,
        hasCustomFilename: Bool = false
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.hasCustomFilename = hasCustomFilename

        if let filename = filename {
            self.filename = filename
        } else {
            let sanitized = Note.slugify(title: Note.extractTitle(from: content))
            self.filename = "\(sanitized).md"
        }
    }

    public var displayTitle: String {
        if hasCustomFilename {
            let name = filename.hasSuffix(".md") ? String(filename.dropLast(3)) : filename
            if !name.isEmpty {
                return name
            }
        }
        let title = Note.extractTitle(from: content)
        return title.isEmpty ? "—" : title
    }

    public var previewSnippet: String {
        var foundTitle = false
        var snippet = ""
        var count = 0

        content.enumerateLines { line, stop in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }

            if !foundTitle {
                foundTitle = true
            } else {
                let clean = trimmed
                    .replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "[*`_~>\\[\\]]", with: "", options: .regularExpression)
                snippet = clean
                stop = true
            }
            count += 1
            if count >= 10 { stop = true }
        }

        return snippet
    }

    public static func extractTitle(from text: String) -> String {
        var result = ""
        var lineCount = 0
        text.enumerateLines { line, stop in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                let clean = trimmed.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                result = clean.trimmingCharacters(in: .whitespaces)
                stop = true
            }
            lineCount += 1
            if lineCount >= 10 { stop = true }
        }
        return result
    }

    public static func slugify(title: String) -> String {
        let clean = title
            .replacingOccurrences(of: "İ", with: "i")
            .replacingOccurrences(of: "I", with: "i")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "ı", with: "i")
            .replacingOccurrences(of: "\u{0307}", with: "")
            .replacingOccurrences(of: "ğ", with: "g")
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ş", with: "s")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ç", with: "c")

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let filtered = clean.unicodeScalars.filter { allowed.contains($0) }
        var result = String(filtered).replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        // Maximum 20 characters as requested
        if result.count > 20 {
            result = String(result.prefix(20)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        }

        return result.isEmpty ? "not-\(Int(Date().timeIntervalSince1970))" : result
    }
}
