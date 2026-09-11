import SwiftUI

public struct EditorView: View {
    @Bindable var state: AppState

    @State private var isArchiveArmed: Bool = false
    @State private var archiveDisarmTask: Task<Void, Never>? = nil
    @State private var isDeleteArmed: Bool = false
    @State private var deleteDisarmTask: Task<Void, Never>? = nil
    @State private var isEditingFilename: Bool = false
    @State private var editingFilenameText: String = ""
    @FocusState private var isFilenameFocused: Bool

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Meta Bar (Radical Essentialism & Pure Data-Ink)
            if !state.isTypewriterMode {
                HStack(spacing: MonocleTheme.spacingM) {
                    if !state.isSidebarVisible {
                        Button(action: { state.toggleSidebar() }) {
                            Text("◨")
                                .font(MonocleTheme.fontSubtitle)
                                .foregroundStyle(MonocleTheme.neutral)
                        }
                        .buttonStyle(.plain)
                        .help("Kenar çubuğunu aç (⌘B)")
                    }

                    if let note = state.activeNote {
                        if isEditingFilename {
                            TextField("", text: $editingFilenameText)
                                .textFieldStyle(.plain)
                                .font(MonocleTheme.fontMeta)
                                .foregroundStyle(MonocleTheme.foreground)
                                .frame(maxWidth: 240)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(MonocleTheme.microBorder.opacity(0.35))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .focused($isFilenameFocused)
                                .onSubmit {
                                    commitFilename()
                                }
                                .onExitCommand {
                                    isEditingFilename = false
                                }
                        } else {
                            Button(action: {
                                editingFilenameText = note.filename.hasSuffix(".md") ? String(note.filename.dropLast(3)) : note.filename
                                isEditingFilename = true
                                isFilenameFocused = true
                            }) {
                                Text(note.filename)
                                    .font(MonocleTheme.fontMeta)
                                    .foregroundStyle(MonocleTheme.neutral)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .buttonStyle(.plain)
                            .help("Dosya adını değiştirmek için tıkla")
                        }
                    }

                    Spacer()

                    if let note = state.activeNote {
                        HStack(spacing: MonocleTheme.spacingS) {
                            Text("\(characterCount(state.activeContent))")
                                .font(MonocleTheme.fontMeta)
                                .foregroundStyle(MonocleTheme.neutral)

                            Text("•")
                                .font(MonocleTheme.fontMeta)
                                .foregroundStyle(MonocleTheme.microBorder)

                            Text("\(wordCount(state.activeContent))")
                                .font(MonocleTheme.fontMeta)
                                .foregroundStyle(MonocleTheme.neutral)

                            Text("•")
                                .font(MonocleTheme.fontMeta)
                                .foregroundStyle(MonocleTheme.microBorder)

                            if note.isArchived {
                                Button(action: {
                                    state.restoreSelectedNote()
                                }) {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundStyle(MonocleTheme.neutral)
                                        .frame(width: 20, height: 20)
                                }
                                .buttonStyle(.plain)
                                .help("Arşivden Çıkar (⌥⌘Z)")

                                Text("•")
                                    .font(MonocleTheme.fontMeta)
                                    .foregroundStyle(MonocleTheme.microBorder)

                                Button(action: {
                                    if isDeleteArmed {
                                        deleteDisarmTask?.cancel()
                                        isDeleteArmed = false
                                        state.permanentlyDeleteSelectedNote()
                                    } else {
                                        isDeleteArmed = true
                                        deleteDisarmTask?.cancel()
                                        deleteDisarmTask = Task {
                                            try? await Task.sleep(nanoseconds: 3_500_000_000)
                                            if !Task.isCancelled {
                                                await MainActor.run {
                                                    isDeleteArmed = false
                                                }
                                            }
                                        }
                                    }
                                }) {
                                    Image(systemName: isDeleteArmed ? "trash.fill" : "trash")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundStyle(isDeleteArmed ? MonocleTheme.foreground : MonocleTheme.neutral)
                                        .frame(width: 20, height: 20)
                                        .background(
                                            isDeleteArmed
                                                ? MonocleTheme.microBorder.opacity(0.4)
                                                : Color.clear
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                }
                                .buttonStyle(.plain)
                                .help(isDeleteArmed ? "Kalıcı olarak silmek için tekrar tıkla" : "Kalıcı Olarak Sil")
                            } else {
                                Button(action: {
                                    if isArchiveArmed {
                                        archiveDisarmTask?.cancel()
                                        isArchiveArmed = false
                                        state.archiveSelectedNote()
                                    } else {
                                        isArchiveArmed = true
                                        archiveDisarmTask?.cancel()
                                        archiveDisarmTask = Task {
                                            try? await Task.sleep(nanoseconds: 3_500_000_000)
                                            if !Task.isCancelled {
                                                await MainActor.run {
                                                    isArchiveArmed = false
                                                }
                                            }
                                        }
                                    }
                                }) {
                                    Image(systemName: isArchiveArmed ? "archivebox.fill" : "archivebox")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundStyle(isArchiveArmed ? MonocleTheme.foreground : MonocleTheme.neutral)
                                        .frame(width: 20, height: 20)
                                        .background(
                                            isArchiveArmed
                                                ? MonocleTheme.microBorder.opacity(0.4)
                                                : Color.clear
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                }
                                .buttonStyle(.plain)
                                .help(isArchiveArmed ? "Arşivlemek için tekrar tıkla" : "Arşivle (⌘⌫)")
                            }
                        }
                    }
                }
                .padding(.horizontal, MonocleTheme.spacingXL)
                .padding(.vertical, MonocleTheme.spacingS)
                .background(MonocleTheme.background)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // MARK: - Editor Canvas
            if state.activeNote != nil {
                ZStack(alignment: .bottomTrailing) {
                    MacEditorView(
                        text: Binding(
                            get: { state.activeContent },
                            set: { state.updateActiveContent($0) }
                        ),
                        searchQuery: state.searchQuery,
                        isTypewriterMode: state.isTypewriterMode,
                        scrollPercentage: Binding(
                            get: { state.scrollPercentage },
                            set: { state.scrollPercentage = $0 }
                        ),
                        isEditable: !(state.activeNote?.isArchived ?? false),
                        themeMode: state.themeMode
                    )
                    .background(MonocleTheme.background)

                    HStack(spacing: MonocleTheme.spacingM) {
                        if state.shouldShowTypewriterHint && paragraphCount(state.activeContent) > 3 {
                            Button(action: {
                                state.toggleTypewriterMode()
                            }) {
                                Text("⌘T")
                                    .font(MonocleTheme.fontMeta)
                                    .foregroundStyle(MonocleTheme.neutral)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(MonocleTheme.microBorder.opacity(0.35))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            .buttonStyle(.plain)
                            .help("Daktilo Modu (⌘T)")
                            .transition(.opacity)
                        }

                        Text("\(state.scrollPercentage)%")
                            .font(MonocleTheme.fontMeta)
                            .foregroundStyle(MonocleTheme.neutral)
                    }
                    .padding(.trailing, MonocleTheme.spacingXL)
                    .padding(.bottom, MonocleTheme.spacingL)
                    .allowsHitTesting(true)
                }
            } else if !state.isViewingArchive {
                Button(action: {
                    state.createNote()
                }) {
                    VStack {
                        Text("⌘N")
                            .font(MonocleTheme.charterFont(size: 26, weight: .regular))
                            .foregroundStyle(MonocleTheme.neutral.opacity(0.40))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Yeni Not (⌘N)")
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(MonocleTheme.background)
        .animation(MonocleTheme.spring, value: state.isTypewriterMode)
        .animation(MonocleTheme.spring, value: state.shouldShowTypewriterHint)
        .onChange(of: state.selectedNoteId) { _, _ in
            archiveDisarmTask?.cancel()
            isArchiveArmed = false
            deleteDisarmTask?.cancel()
            isDeleteArmed = false
            isEditingFilename = false
        }
        .onChange(of: isFilenameFocused) { _, focused in
            if !focused && isEditingFilename {
                commitFilename()
            }
        }
    }

    private func commitFilename() {
        let trimmed = editingFilenameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            state.renameActiveNote(to: trimmed)
        }
        isEditingFilename = false
    }

    private func paragraphCount(_ text: String) -> Int {
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.count
    }

    private func wordCount(_ text: String) -> Int {
        AppState.countWords(in: text)
    }

    private func characterCount(_ text: String) -> Int {
        AppState.countCharacters(in: text)
    }
}
