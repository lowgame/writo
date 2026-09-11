import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
public final class AppState {
    public var notes: [Note] = []
    public var archivedNotes: [Note] = []
    public var selectedNoteId: String? = nil
    public var searchQuery: String = ""
    public var isSidebarVisible: Bool = true
    public var isViewingArchive: Bool = false
    public var isSearchFocused: Bool = false
    public var isTypewriterMode: Bool = false
    public var scrollPercentage: Int = 0

    // MARK: - Theme Mode
    private let themeModeKey = "WritoThemeMode"
    public var themeMode: ThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: themeModeKey)
            applyThemeAppearance()
        }
    }

    // Active buffer for instant writing without lag
    public var activeContent: String = ""

    // Non-destructive Undo Stack
    private var undoStack: [Note] = []

    private var sidebarWasVisibleBeforeTypewriter: Bool = true

    private let storage: NoteStorage
    private var saveTask: Task<Void, Never>? = nil

    public init(storage: NoteStorage = .shared) {
        self.storage = storage
        let savedThemeRaw = UserDefaults.standard.string(forKey: "WritoThemeMode") ?? ThemeMode.system.rawValue
        self.themeMode = ThemeMode(rawValue: savedThemeRaw) ?? .system
        loadAllNotes()
        selectInitialNote()
        applyThemeAppearance()
    }

    public var activeNote: Note? {
        if isViewingArchive {
            return archivedNotes.first { $0.id == selectedNoteId }
        } else {
            return notes.first { $0.id == selectedNoteId }
        }
    }

    public var filteredNotes: [Note] {
        let source = isViewingArchive ? archivedNotes : notes
        let sorted = source.sorted { $0.createdAt > $1.createdAt }
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return sorted
        }
        return sorted.filter { note in
            note.displayTitle.lowercased().contains(query) ||
            note.content.lowercased().contains(query)
        }
    }

    // MARK: - Cumulative Stats

    public var totalWordCount: Int {
        var count = 0
        var activeCounted = false
        for note in notes {
            if note.id == selectedNoteId {
                count += AppState.countWords(in: activeContent)
                activeCounted = true
            } else {
                count += AppState.countWords(in: note.content)
            }
        }
        for note in archivedNotes {
            if note.id == selectedNoteId {
                count += AppState.countWords(in: activeContent)
                activeCounted = true
            } else {
                count += AppState.countWords(in: note.content)
            }
        }
        if !activeCounted && selectedNoteId != nil && !activeContent.isEmpty {
            count += AppState.countWords(in: activeContent)
        }
        return count
    }

    public var totalCharacterCount: Int {
        var count = 0
        var activeCounted = false
        for note in notes {
            if note.id == selectedNoteId {
                count += AppState.countCharacters(in: activeContent)
                activeCounted = true
            } else {
                count += AppState.countCharacters(in: note.content)
            }
        }
        for note in archivedNotes {
            if note.id == selectedNoteId {
                count += AppState.countCharacters(in: activeContent)
                activeCounted = true
            } else {
                count += AppState.countCharacters(in: note.content)
            }
        }
        if !activeCounted && selectedNoteId != nil && !activeContent.isEmpty {
            count += AppState.countCharacters(in: activeContent)
        }
        return count
    }

    public var formattedTotalWordCount: String {
        AppState.numberFormatter.string(from: NSNumber(value: totalWordCount)) ?? "\(totalWordCount)"
    }

    public var formattedTotalCharCount: String {
        AppState.numberFormatter.string(from: NSNumber(value: totalCharacterCount)) ?? "\(totalCharacterCount)"
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        return formatter
    }()

    public static func countWords(in text: String) -> Int {
        var count = 0
        var inWord = false
        for byte in text.utf8 {
            if byte == 32 || byte == 10 || byte == 13 || byte == 9 {
                inWord = false
            } else if !inWord {
                inWord = true
                count += 1
            }
        }
        return count
    }

    public static func countCharacters(in text: String) -> Int {
        return text.utf16.count
    }

    // MARK: - Intents / Actions

    public func loadAllNotes() {
        self.notes = storage.loadActiveNotes().sorted { $0.createdAt > $1.createdAt }
        self.archivedNotes = storage.loadArchivedNotes().sorted { $0.createdAt > $1.createdAt }
    }

    private func selectInitialNote() {
        if let first = notes.first {
            selectNote(id: first.id)
        } else {
            selectedNoteId = nil
            activeContent = ""
        }
    }

    public func selectNote(id: String?) {
        // Flush any pending save for previous note before switching
        flushSave()

        selectedNoteId = id
        if let note = activeNote {
            activeContent = note.content
        } else {
            activeContent = ""
        }
    }

    public func updateActiveContent(_ newContent: String) {
        guard let noteId = selectedNoteId else { return }
        self.activeContent = newContent

        // Update in-memory note immediately
        if let index = notes.firstIndex(where: { $0.id == noteId }) {
            notes[index].content = newContent
            notes[index].updatedAt = Date()
            let updated = notes[index]

            // Debounced write to disk
            saveTask?.cancel()
            saveTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000) // 400ms debounce
                if let saved = try? self.storage.saveNote(updated) {
                    if let currentIndex = self.notes.firstIndex(where: { $0.id == noteId }) {
                        self.notes[currentIndex].filename = saved.filename
                        self.notes[currentIndex].hasCustomFilename = saved.hasCustomFilename
                        self.notes[currentIndex].updatedAt = saved.updatedAt
                    }
                }
            }
        }
    }

    public func flushSave() {
        saveTask?.cancel()
        saveTask = nil
        guard let note = activeNote, !note.isArchived else { return }
        if let saved = try? storage.saveNote(note) {
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index].filename = saved.filename
                notes[index].hasCustomFilename = saved.hasCustomFilename
                notes[index].updatedAt = saved.updatedAt
            }
        }
        notes.sort { $0.createdAt > $1.createdAt }
    }

    public func renameActiveNote(to newName: String) {
        guard let note = activeNote else { return }
        flushSave()
        do {
            let updated = try storage.renameNote(note, to: newName)
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index] = updated
            }
            if let archIndex = archivedNotes.firstIndex(where: { $0.id == note.id }) {
                archivedNotes[archIndex] = updated
            }
            notes.sort { $0.createdAt > $1.createdAt }
        } catch {
            print("Rename active note failed: \(error)")
        }
    }

    public func focusSearch() {
        if !isSidebarVisible {
            withAnimation(MonocleTheme.spring) {
                isSidebarVisible = true
            }
        }
        isSearchFocused = true
    }

    public func createNote(initialTitle: String? = nil, initialContent: String? = nil) {
        flushSave()

        var content = initialContent ?? ""
        if content.isEmpty, let title = initialTitle, !title.isEmpty {
            content = "\(title)\n\n"
        }

        let newNote = Note(content: content)
        do {
            let saved = try storage.saveNote(newNote)
            notes.insert(saved, at: 0)
            notes.sort { $0.createdAt > $1.createdAt }
            selectNote(id: saved.id)
            searchQuery = ""
        } catch {
            // Local fallback
            notes.insert(newNote, at: 0)
            notes.sort { $0.createdAt > $1.createdAt }
            selectNote(id: newNote.id)
        }
    }

    public func searchOrNew() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        // If exact or close match exists, select it
        if let match = filteredNotes.first {
            selectNote(id: match.id)
        } else {
            // No match -> create with this title
            createNote(initialTitle: query)
        }
    }

    public func archiveSelectedNote() {
        guard let current = activeNote, !current.isArchived else { return }
        flushSave()

        do {
            let archived = try storage.archiveNote(current)
            notes.removeAll { $0.id == current.id }
            archivedNotes.insert(archived, at: 0)
            undoStack.append(archived)

            // Select next available note
            if let next = notes.first {
                selectNote(id: next.id)
            } else {
                selectedNoteId = nil
                activeContent = ""
            }
        } catch {
            print("Archive failed: \(error)")
        }
    }

    public func restoreNote(id: String) {
        guard let note = archivedNotes.first(where: { $0.id == id }) else { return }
        flushSave()

        do {
            let restored = try storage.restoreNote(note)
            archivedNotes.removeAll { $0.id == note.id }
            undoStack.removeAll { $0.id == note.id }
            notes.insert(restored, at: 0)
            notes.sort { $0.createdAt > $1.createdAt }

            if isViewingArchive {
                if let next = archivedNotes.first {
                    selectNote(id: next.id)
                } else {
                    isViewingArchive = false
                    selectNote(id: restored.id)
                }
            } else {
                selectNote(id: restored.id)
            }
        } catch {
            print("Restore failed: \(error)")
        }
    }

    public func restoreSelectedNote() {
        guard let current = activeNote, current.isArchived else { return }
        restoreNote(id: current.id)
    }

    public func undoLastArchive() {
        if let last = undoStack.popLast() {
            restoreNote(id: last.id)
        } else if isViewingArchive, let current = activeNote {
            restoreNote(id: current.id)
        }
    }

    public func permanentlyDeleteSelectedNote() {
        guard let current = activeNote, current.isArchived else { return }
        flushSave()

        do {
            try storage.permanentlyDeleteNote(current)
            archivedNotes.removeAll { $0.id == current.id }
            undoStack.removeAll { $0.id == current.id }

            if let next = archivedNotes.first {
                selectNote(id: next.id)
            } else {
                selectedNoteId = nil
                activeContent = ""
            }
        } catch {
            print("Permanent delete failed: \(error)")
        }
    }

    public func permanentlyDeleteNote(id: String) {
        guard let note = archivedNotes.first(where: { $0.id == id }) else { return }
        if selectedNoteId == id {
            flushSave()
        }
        do {
            try storage.permanentlyDeleteNote(note)
            archivedNotes.removeAll { $0.id == id }
            undoStack.removeAll { $0.id == id }
            if selectedNoteId == id {
                if let next = archivedNotes.first {
                    selectNote(id: next.id)
                } else {
                    selectedNoteId = nil
                    activeContent = ""
                }
            }
        } catch {
            print("Permanent delete failed: \(error)")
        }
    }

    public func toggleSidebar() {
        withAnimation(MonocleTheme.spring) {
            isSidebarVisible.toggle()
        }
    }

    private let typewriterUsageKey = "WritoTypewriterUsageCount"

    public var typewriterUsageCount: Int {
        get { UserDefaults.standard.integer(forKey: typewriterUsageKey) }
        set { UserDefaults.standard.set(newValue, forKey: typewriterUsageKey) }
    }

    public var shouldShowTypewriterHint: Bool {
        typewriterUsageCount < 3 && !isTypewriterMode
    }

    public func toggleTypewriterMode() {
        withAnimation(MonocleTheme.spring) {
            if !isTypewriterMode {
                sidebarWasVisibleBeforeTypewriter = isSidebarVisible
                isTypewriterMode = true
                isSidebarVisible = false
                if typewriterUsageCount < 3 {
                    typewriterUsageCount += 1
                }
            } else {
                isTypewriterMode = false
                if sidebarWasVisibleBeforeTypewriter {
                    isSidebarVisible = true
                }
            }
        }
    }

    public func toggleArchiveView() {
        flushSave()
        withAnimation(MonocleTheme.spring) {
            isViewingArchive.toggle()
            if isViewingArchive {
                selectNote(id: archivedNotes.first?.id)
            } else {
                selectNote(id: notes.first?.id)
            }
        }
    }

    // MARK: - Theme Actions

    public func toggleTheme() {
        switch themeMode {
        case .system:
            let isDark: Bool
            if let app = NSApp {
                isDark = app.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            } else {
                isDark = false
            }
            themeMode = isDark ? .light : .dark
        case .dark:
            themeMode = .light
        case .light:
            themeMode = .dark
        }
    }

    public func setTheme(_ mode: ThemeMode) {
        themeMode = mode
    }

    public func applyThemeAppearance() {
        guard let app = NSApp else { return }
        let appearance = themeMode.nsAppearance
        app.appearance = appearance
        for window in app.windows {
            window.appearance = appearance
        }
    }
}
