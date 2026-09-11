import SwiftUI

public struct SidebarView: View {
    @Bindable var state: AppState
    @FocusState private var isSearchFocused: Bool

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Search Input (Pure, Quiet, Zero Preachy Placeholders)
            HStack {
                TextField("", text: $state.searchQuery)
                    .textFieldStyle(.plain)
                    .font(MonocleTheme.charterFont(size: 13.5))
                    .foregroundStyle(MonocleTheme.foreground)
                    .focused($isSearchFocused)
                    .onSubmit {
                        state.searchOrNew()
                    }

                if !state.searchQuery.isEmpty {
                    Button(action: { state.searchQuery = "" }) {
                        Text("×")
                            .font(MonocleTheme.fontBody)
                            .foregroundStyle(MonocleTheme.neutral)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, MonocleTheme.spacingM)
            .padding(.vertical, MonocleTheme.spacingS)
            .background(MonocleTheme.microBorder.opacity(0.20))
            .padding(.horizontal, MonocleTheme.spacingM)
            .padding(.top, MonocleTheme.spacingM)
            .padding(.bottom, MonocleTheme.spacingS)
            .onChange(of: state.isSearchFocused) { _, newValue in
                if newValue {
                    isSearchFocused = true
                    state.isSearchFocused = false
                }
            }

            // MARK: - Note List (Pure Typography, Zero Noise)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(state.filteredNotes) { note in
                        NoteRowView(
                            note: note,
                            isSelected: note.id == state.selectedNoteId,
                            onSelect: { state.selectNote(id: note.id) }
                        )
                    }
                }
            }

            // MARK: - Sidebar Footer: Archive, Theme & Stats (H • K on the right)
            Rectangle()
                .fill(MonocleTheme.microBorder.opacity(0.35))
                .frame(height: 1)

            HStack(spacing: MonocleTheme.spacingM) {
                Button(action: { state.toggleArchiveView() }) {
                    HStack(spacing: 4) {
                        Image(systemName: state.isViewingArchive ? "archivebox.fill" : "archivebox")
                            .font(.system(size: 11.5, weight: state.isViewingArchive ? .semibold : .regular))
                        if !state.archivedNotes.isEmpty {
                            Text("\(state.archivedNotes.count)")
                                .font(MonocleTheme.fontMeta)
                        }
                    }
                    .foregroundStyle(state.isViewingArchive ? MonocleTheme.foreground : MonocleTheme.neutral)
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(state.isViewingArchive ? "Aktif Notlara Dön" : "Arşiv")

                Button(action: { state.toggleTheme() }) {
                    Image(systemName: themeIconName)
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundStyle(MonocleTheme.neutral)
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Tema: \(state.themeMode.title) (⌘D)")

                Spacer()

                HStack(spacing: MonocleTheme.spacingS) {
                    Text("\(state.formattedTotalCharCount)")
                        .font(MonocleTheme.fontMeta)
                        .foregroundStyle(MonocleTheme.neutral)

                    Text("•")
                        .font(MonocleTheme.fontMeta)
                        .foregroundStyle(MonocleTheme.microBorder)

                    Text("\(state.formattedTotalWordCount)")
                        .font(MonocleTheme.fontMeta)
                        .foregroundStyle(MonocleTheme.neutral)
                }
                .help("Toplam: \(state.formattedTotalCharCount) harf • \(state.formattedTotalWordCount) kelime")
            }
            .padding(.horizontal, MonocleTheme.spacingM)
            .padding(.vertical, MonocleTheme.spacingS)
        }
        .frame(width: MonocleTheme.sidebarWidth)
        .background(MonocleTheme.sidebarBackground)
    }

    private var themeIconName: String {
        switch state.themeMode {
        case .dark: return "circle.fill"
        case .light: return "circle"
        case .system: return "circle.lefthalf.filled"
        }
    }
}
