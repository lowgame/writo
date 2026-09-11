import SwiftUI

public struct NoteRowView: View {
    public let note: Note
    public let isSelected: Bool
    public let onSelect: () -> Void

    public init(
        note: Note,
        isSelected: Bool,
        onSelect: @escaping () -> Void
    ) {
        self.note = note
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .firstTextBaseline, spacing: MonocleTheme.spacingS) {
                Text(note.displayTitle)
                    .font(MonocleTheme.charterFont(size: 14.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? MonocleTheme.background : MonocleTheme.foreground)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(formattedDate(note.createdAt))
                    .font(MonocleTheme.fontMeta)
                    .foregroundStyle(
                        isSelected
                            ? MonocleTheme.background.opacity(0.7)
                            : MonocleTheme.neutral
                    )
                    .lineLimit(1)
            }
            .padding(.horizontal, MonocleTheme.spacingM)
            .padding(.vertical, MonocleTheme.spacingS + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background(
            isSelected ? MonocleTheme.foreground : Color.clear
        )
        .contentShape(Rectangle())
    }

    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let dateYear = calendar.component(.year, from: date)

        if currentYear == dateYear {
            return NoteRowView.dayMonthFormatter.string(from: date)
        } else {
            return NoteRowView.dayMonthYearFormatter.string(from: date)
        }
    }

    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter
    }()

    private static let dayMonthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("dMMMyyyy")
        return formatter
    }()
}
