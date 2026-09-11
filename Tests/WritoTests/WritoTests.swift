import XCTest
@testable import Writo

final class WritoTests: XCTestCase {
    var tempDirectory: URL!
    var storage: NoteStorage!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WritoTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        storage = NoteStorage(customVaultURL: tempDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Note Model Tests
    func testNoteTitleExtraction() {
        let content1 = "# Harika Bir Fikir\nDetaylar burada."
        XCTAssertEqual(Note.extractTitle(from: content1), "Harika Bir Fikir")

        let content2 = "### Üçüncü Seviye Başlık\nİçerik"
        XCTAssertEqual(Note.extractTitle(from: content2), "Üçüncü Seviye Başlık")

        let content3 = "\n\n   # Boşluklu Başlık   \nMetin"
        XCTAssertEqual(Note.extractTitle(from: content3), "Boşluklu Başlık")

        let content4 = "Başlıksız sadece düz metin"
        XCTAssertEqual(Note.extractTitle(from: content4), "Başlıksız sadece düz metin")
    }

    func testSlugifyTurkishCharacters() {
        let title = "Çalışma Günlüğü"
        let slug = Note.slugify(title: title)
        XCTAssertEqual(slug, "calisma-gunlugu")
        XCTAssertTrue(slug.count <= 20)
    }

    func testSlugifyLengthCappedAt20Characters() {
        let longTitle = "asdasdasdasdasdasdasdasdasdasdasdasdasdasdasdasdasd"
        let slug = Note.slugify(title: longTitle)
        XCTAssertEqual(slug.count, 20)
        XCTAssertEqual(slug, String(longTitle.prefix(20)))
    }

    func testPreviewSnippet() {
        let content = "# Başlık\nBu bir önizleme satırıdır.\nÜçüncü satır."
        let note = Note(content: content)
        XCTAssertEqual(note.previewSnippet, "Bu bir önizleme satırıdır.")
    }

    // MARK: - Storage Tests
    func testSaveAndLoadNote() throws {
        let note = Note(content: "# Deneme Notu\nİçerik açıklaması")
        _ = try storage.saveNote(note)

        let loaded = storage.loadActiveNotes()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.displayTitle, "Deneme Notu")
        XCTAssertEqual(loaded.first?.content, note.content)
    }

    func testNonDestructiveArchiveAndRestore() throws {
        let note = Note(content: "# Arşivlenecek Not\nBu not arşivlenmelidir.")
        let saved = try storage.saveNote(note)

        XCTAssertEqual(storage.loadActiveNotes().count, 1)
        XCTAssertEqual(storage.loadArchivedNotes().count, 0)

        // Archive
        let archived = try storage.archiveNote(saved)
        XCTAssertTrue(archived.isArchived)
        XCTAssertEqual(storage.loadActiveNotes().count, 0)
        XCTAssertEqual(storage.loadArchivedNotes().count, 1)

        // Restore
        let restored = try storage.restoreNote(archived)
        XCTAssertFalse(restored.isArchived)
        XCTAssertEqual(storage.loadActiveNotes().count, 1)
        XCTAssertEqual(storage.loadArchivedNotes().count, 0)
    }

    // MARK: - AppState Tests
    @MainActor
    func testAppStateSearchAndUnifiedCreate() {
        let state = AppState(storage: storage)
        state.notes.removeAll()

        state.createNote(initialTitle: "Alışveriş Listesi")
        state.createNote(initialTitle: "Kitap Önerileri")

        XCTAssertEqual(state.notes.count, 2)

        // Search match
        state.searchQuery = "alışveriş"
        XCTAssertEqual(state.filteredNotes.count, 1)
        XCTAssertEqual(state.filteredNotes.first?.displayTitle, "Alışveriş Listesi")

        // Search no-match + Enter to create
        state.searchQuery = "Yeni Bir Proje"
        XCTAssertEqual(state.filteredNotes.count, 0)

        state.searchOrNew()
        XCTAssertEqual(state.notes.count, 3)
        XCTAssertEqual(state.activeNote?.displayTitle, "Yeni Bir Proje")
    }

    @MainActor
    func testAppStateArchiveAndUndo() {
        let state = AppState(storage: storage)
        state.notes.removeAll()

        state.createNote(initialTitle: "Silinecek Not")
        XCTAssertEqual(state.notes.count, 1)

        state.archiveSelectedNote()
        XCTAssertEqual(state.notes.count, 0)
        XCTAssertEqual(state.archivedNotes.count, 1)

        // Reversible action via undo
        state.undoLastArchive()
        XCTAssertEqual(state.notes.count, 1)
        XCTAssertEqual(state.archivedNotes.count, 0)
        XCTAssertEqual(state.activeNote?.displayTitle, "Silinecek Not")
    }

    @MainActor
    func testTypewriterModeTogglesSidebarAndState() {
        let state = AppState(storage: storage)
        state.isSidebarVisible = true
        state.isTypewriterMode = false

        // Turn on typewriter mode -> closes sidebar and activates typewriter mode
        state.toggleTypewriterMode()
        XCTAssertTrue(state.isTypewriterMode)
        XCTAssertFalse(state.isSidebarVisible)

        // Turn off typewriter mode -> restores sidebar to visible
        state.toggleTypewriterMode()
        XCTAssertFalse(state.isTypewriterMode)
        XCTAssertTrue(state.isSidebarVisible)
    }

    @MainActor
    func testPermanentlyDeleteArchivedNote() throws {
        let state = AppState(storage: storage)
        state.notes.removeAll()

        state.createNote(initialTitle: "Kalıcı Silinecek Not")
        XCTAssertEqual(state.notes.count, 1)

        state.archiveSelectedNote()
        XCTAssertEqual(state.notes.count, 0)
        XCTAssertEqual(state.archivedNotes.count, 1)

        // Select the archived note in archive view
        state.toggleArchiveView()
        XCTAssertTrue(state.isViewingArchive)
        XCTAssertNotNil(state.activeNote)
        XCTAssertEqual(state.activeNote?.displayTitle, "Kalıcı Silinecek Not")

        // Permanently delete
        state.permanentlyDeleteSelectedNote()
        XCTAssertEqual(state.archivedNotes.count, 0)
        XCTAssertNil(state.activeNote)
    }

    @MainActor
    func testCustomFilenamePreservedUntilUserChangesAgain() throws {
        let state = AppState(storage: storage)
        state.notes.removeAll()

        state.createNote(initialTitle: "İlk Otomatik Başlık")
        XCTAssertEqual(state.activeNote?.filename, "ilk-otomatik-baslik.md")

        // User manually renames from the top
        state.renameActiveNote(to: "benim-ozel-notum")
        XCTAssertEqual(state.activeNote?.filename, "benim-ozel-notum.md")
        XCTAssertTrue(state.activeNote?.hasCustomFilename == true)

        // User edits note content substantially
        state.updateActiveContent("# Yepyeni Bambaşka Başlık\nYeni içerik...")
        state.flushSave()

        // Filename MUST remain the custom one!
        XCTAssertEqual(state.activeNote?.filename, "benim-ozel-notum.md")
        XCTAssertEqual(state.notes.first?.filename, "benim-ozel-notum.md")

        // User renames again
        state.renameActiveNote(to: "ikinci-ozel-ad")
        XCTAssertEqual(state.activeNote?.filename, "ikinci-ozel-ad.md")

        // User edits note content again
        state.updateActiveContent("# Üçüncü Başlık\nİçerik")
        state.flushSave()

        // Filename MUST remain the latest custom one!
        XCTAssertEqual(state.activeNote?.filename, "ikinci-ozel-ad.md")
    }

    @MainActor
    func testCustomFilenameReflectedInDisplayTitle() {
        let note1 = Note(filename: "proje-plani.md", content: "# Eski Baslik\nIcerik", hasCustomFilename: true)
        XCTAssertEqual(note1.displayTitle, "proje-plani")

        let state = AppState(storage: storage)
        state.notes.removeAll()
        state.createNote(initialTitle: "Baslangic Notu")
        XCTAssertEqual(state.activeNote?.displayTitle, "Baslangic Notu")

        // User renames note
        state.renameActiveNote(to: "Toplanti Notlari 2026")
        XCTAssertEqual(state.activeNote?.displayTitle, "Toplanti Notlari 2026")
        XCTAssertEqual(state.filteredNotes.first?.displayTitle, "Toplanti Notlari 2026")
    }

    @MainActor
    func testTypewriterHintBehaviorAndCountCap() {
        let state = AppState(storage: storage)
        state.typewriterUsageCount = 0

        XCTAssertTrue(state.shouldShowTypewriterHint)

        // 1st use
        state.toggleTypewriterMode()
        XCTAssertEqual(state.typewriterUsageCount, 1)
        XCTAssertFalse(state.shouldShowTypewriterHint) // false because isTypewriterMode is true

        // Exit typewriter mode
        state.toggleTypewriterMode()
        XCTAssertEqual(state.typewriterUsageCount, 1)
        XCTAssertTrue(state.shouldShowTypewriterHint) // true because count < 3 and not in typewriter mode

        // 2nd use
        state.toggleTypewriterMode()
        XCTAssertEqual(state.typewriterUsageCount, 2)
        state.toggleTypewriterMode()

        // 3rd use
        state.toggleTypewriterMode()
        XCTAssertEqual(state.typewriterUsageCount, 3)
        state.toggleTypewriterMode()

        // After 3 uses, should never show hint again
        XCTAssertFalse(state.shouldShowTypewriterHint)

        // 4th toggle should not increment past 3
        state.toggleTypewriterMode()
        XCTAssertEqual(state.typewriterUsageCount, 3)
        state.toggleTypewriterMode()
        XCTAssertFalse(state.shouldShowTypewriterHint)
    }

    @MainActor
    func testEmptyNotesState() {
        let state = AppState(storage: storage)
        state.notes.removeAll()
        state.selectNote(id: nil)

        XCTAssertTrue(state.notes.isEmpty)
        XCTAssertNil(state.activeNote)
    }

    @MainActor
    func testThemeModeSwitchingAndPersistence() {
        let state = AppState(storage: storage)

        state.setTheme(.light)
        XCTAssertEqual(state.themeMode, .light)
        XCTAssertEqual(state.themeMode.colorScheme, .light)
        XCTAssertNotNil(state.themeMode.nsAppearance)

        state.toggleTheme()
        XCTAssertEqual(state.themeMode, .dark)
        XCTAssertEqual(state.themeMode.colorScheme, .dark)
        XCTAssertNotNil(state.themeMode.nsAppearance)

        state.toggleTheme()
        XCTAssertEqual(state.themeMode, .light)

        state.setTheme(.system)
        XCTAssertEqual(state.themeMode, .system)
        XCTAssertNil(state.themeMode.colorScheme)
        XCTAssertNil(state.themeMode.nsAppearance)

        // Verify persistence
        let raw = UserDefaults.standard.string(forKey: "WritoThemeMode")
        XCTAssertEqual(raw, "system")

        state.setTheme(.dark)
        let rawDark = UserDefaults.standard.string(forKey: "WritoThemeMode")
        XCTAssertEqual(rawDark, "dark")
    }

    @MainActor
    func testNotesSortedByCreationDateDescending() {
        let state = AppState(storage: storage)
        state.notes.removeAll()

        let now = Date()
        let note1 = Note(id: "1", content: "Not 1", createdAt: now.addingTimeInterval(-100))
        let note2 = Note(id: "2", content: "Not 2", createdAt: now)
        let note3 = Note(id: "3", content: "Not 3", createdAt: now.addingTimeInterval(-50))

        state.notes = [note1, note2, note3]

        let sorted = state.filteredNotes
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].id, "2")
        XCTAssertEqual(sorted[1].id, "3")
        XCTAssertEqual(sorted[2].id, "1")
    }

    @MainActor
    func testRestoreArchivedNoteDirectlyAndFromArchiveView() {
        let state = AppState(storage: storage)
        state.notes.removeAll()

        state.createNote(initialTitle: "Kurtarilacak Not")
        let noteId = state.notes.first!.id

        // Archive note
        state.archiveSelectedNote()
        XCTAssertEqual(state.notes.count, 0)
        XCTAssertEqual(state.archivedNotes.count, 1)

        // Switch to archive view
        state.toggleArchiveView()
        XCTAssertTrue(state.isViewingArchive)
        XCTAssertEqual(state.activeNote?.id, noteId)

        // Click restore (restoreSelectedNote)
        state.restoreSelectedNote()
        XCTAssertEqual(state.notes.count, 1)
        XCTAssertEqual(state.archivedNotes.count, 0)
        XCTAssertEqual(state.notes.first?.id, noteId)
        XCTAssertFalse(state.notes.first?.isArchived ?? true)

        // Test restoreNote(id:) directly
        state.archiveSelectedNote()
        XCTAssertEqual(state.notes.count, 0)
        XCTAssertEqual(state.archivedNotes.count, 1)

        state.restoreNote(id: noteId)
        XCTAssertEqual(state.notes.count, 1)
        XCTAssertEqual(state.archivedNotes.count, 0)
        XCTAssertEqual(state.activeNote?.id, noteId)
    }

    @MainActor
    func testEmptyArchiveStateDoesNotShowActiveNote() {
        let state = AppState(storage: storage)
        state.notes.removeAll()
        state.archivedNotes.removeAll()

        state.toggleArchiveView()
        XCTAssertTrue(state.isViewingArchive)
        XCTAssertNil(state.activeNote)
    }

    @MainActor
    func testCumulativeWordAndCharacterCounts() {
        let state = AppState(storage: storage)
        state.notes.removeAll()
        state.archivedNotes.removeAll()

        // 1. Empty state
        XCTAssertEqual(state.totalWordCount, 0)
        XCTAssertEqual(state.totalCharacterCount, 0)

        // 2. Create first note
        state.createNote(initialContent: "Merhaba dunya!") // 2 words, 14 chars
        XCTAssertEqual(state.totalWordCount, 2)
        XCTAssertEqual(state.totalCharacterCount, 14)

        // 3. Create second note
        state.createNote(initialContent: "Swift harika bir dil.") // 4 words, 21 chars
        // Now note 2 is active, note 1 is saved
        XCTAssertEqual(state.totalWordCount, 6)
        XCTAssertEqual(state.totalCharacterCount, 35)

        // 4. Create third note and archive it
        state.createNote(initialContent: "Eski not") // 2 words, 8 chars
        state.archiveSelectedNote()
        XCTAssertEqual(state.archivedNotes.count, 1)

        // Total should include active notes + archived notes: 2 + 4 + 2 = 8 words, 14 + 21 + 8 = 43 chars
        XCTAssertEqual(state.totalWordCount, 8)
        XCTAssertEqual(state.totalCharacterCount, 43)

        // 5. Test real-time live active content update
        state.updateActiveContent("Guncellenmis metin buraya yazildi") // 4 words, 33 chars
        // Note was originally 4 words, now 4 words, 33 chars
        XCTAssertEqual(state.totalWordCount, 8)
        XCTAssertEqual(state.totalCharacterCount, 55)

        // 6. Test formatted strings
        XCTAssertFalse(state.formattedTotalWordCount.isEmpty)
        XCTAssertFalse(state.formattedTotalCharCount.isEmpty)
    }

    @MainActor
    func testPathTraversalSanitizationInRename() throws {
        let state = AppState(storage: storage)
        state.notes.removeAll()
        state.createNote(initialTitle: "Guvenli Not", initialContent: "Icerik")

        // Attempt path traversal via rename
        state.renameActiveNote(to: "../../etc/passwd")

        // Must be sanitized and stay inside vault
        let filename = state.activeNote?.filename ?? ""
        XCTAssertFalse(filename.contains("/"))
        XCTAssertFalse(filename.contains(".."))
        XCTAssertTrue(filename.hasSuffix(".md"))
        XCTAssertEqual(filename, "etc-passwd.md")
    }
}


