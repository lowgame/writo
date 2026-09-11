import SwiftUI
import AppKit

final class EditorScroller: NSScroller {
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }
}

final class EditorTextView: NSTextView {
    private var lastActiveParagraphRange: NSRange? = nil
    private var lastTypewriterState: Bool = false
    var hadSearchHighlights: Bool = false

    override func resetCursorRects() {
        // Exclude the right region so mouse cursor turns to arrow/pointer over the scrollbar
        let textWidth = max(0, bounds.width - 16)
        let textBounds = NSRect(x: 0, y: 0, width: textWidth, height: bounds.height)
        addCursorRect(textBounds, cursor: .iBeam)
    }

    func centerCursorInViewport() {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer,
              let scrollView = enclosingScrollView else { return }
        let clipView = scrollView.contentView

        let sel = selectedRange()
        let glyphRange = layoutManager.glyphRange(forCharacterRange: sel, actualCharacterRange: nil)
        let glyphRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        let cursorY = glyphRect.midY + textContainerInset.height
        let targetY = cursorY - (clipView.bounds.height / 2)
        let maxY = max(0, bounds.height - clipView.bounds.height)
        let clampedY = max(0, min(targetY, maxY))

        // Only scroll if difference is noticeable
        if abs(clipView.bounds.origin.y - clampedY) > 2.0 {
            clipView.scroll(to: NSPoint(x: 0, y: clampedY))
            scrollView.reflectScrolledClipView(clipView)
        }
    }

    func updateParagraphFocus(isTypewriter: Bool) {
        guard let layoutManager = layoutManager else { return }
        let totalLength = string.utf16.count
        guard totalLength > 0 else { return }

        let appearance = window?.effectiveAppearance ?? effectiveAppearance
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let normalColor = isDark ? NSColor(white: 0.98, alpha: 1.0) : NSColor(white: 0.05, alpha: 1.0)
        let dimmedColor = isDark ? NSColor(white: 0.32, alpha: 1.0) : NSColor(white: 0.70, alpha: 1.0)

        if !isTypewriter {
            if lastTypewriterState {
                if let lastRange = lastActiveParagraphRange, lastRange.location + lastRange.length <= totalLength {
                    layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: lastRange)
                }
                textColor = normalColor
                lastActiveParagraphRange = nil
                lastTypewriterState = false
            }
            return
        }

        // Mode is active: Set default text color to dimmed once
        if !lastTypewriterState {
            textColor = dimmedColor
            lastTypewriterState = true
        }

        let nsString = string as NSString
        let currentSel = selectedRange()
        let activeParagraph = nsString.paragraphRange(for: currentSel)

        // PERFORMANCE KEY: If user is typing in the SAME paragraph, do nothing!
        if let lastRange = lastActiveParagraphRange,
           lastRange == activeParagraph,
           lastTypewriterState {
            return
        }

        // Only swap highlight between the previous paragraph and new paragraph (O(1) operation)
        if let prevRange = lastActiveParagraphRange, prevRange.location + prevRange.length <= totalLength {
            layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: prevRange)
        }

        if activeParagraph.location + activeParagraph.length <= totalLength {
            layoutManager.addTemporaryAttribute(.foregroundColor, value: normalColor, forCharacterRange: activeParagraph)
        }

        lastActiveParagraphRange = activeParagraph
    }
}

final class EditorScrollView: NSScrollView {
    weak var editorTextView: EditorTextView?
    var isTypewriterMode: Bool = false {
        didSet {
            updateInsets()
            if isTypewriterMode && !oldValue {
                editorTextView?.centerCursorInViewport()
            }
        }
    }
    var wasTypewriterMode: Bool = false

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateInsets()
    }

    override func layout() {
        super.layout()
        updateInsets()
    }

    func updateInsets() {
        guard let textView = editorTextView else { return }
        let maxTextWidth: CGFloat = 700
        let viewportWidth = contentSize.width
        let viewportHeight = contentSize.height
        guard viewportWidth > 0, viewportHeight > 0 else { return }

        let horizontalMargin = max(48, (viewportWidth - maxTextWidth) / 2)
        let verticalInset: CGFloat = isTypewriterMode ? max(36, viewportHeight * 0.4) : 36

        if abs(textView.textContainerInset.width - horizontalMargin) > 0.5 ||
           abs(textView.textContainerInset.height - verticalInset) > 0.5 {
            textView.textContainerInset = NSSize(width: horizontalMargin, height: verticalInset)
            textView.needsLayout = true
            textView.needsDisplay = true
        }
    }
}

public struct MacEditorView: NSViewRepresentable {
    @Binding public var text: String
    public var searchQuery: String = ""
    public var isTypewriterMode: Bool = false
    @Binding public var scrollPercentage: Int
    public var isEditable: Bool = true
    public var themeMode: ThemeMode = .system

    public init(
        text: Binding<String>,
        searchQuery: String = "",
        isTypewriterMode: Bool = false,
        scrollPercentage: Binding<Int> = .constant(0),
        isEditable: Bool = true,
        themeMode: ThemeMode = .system
    ) {
        self._text = text
        self.searchQuery = searchQuery
        self.isTypewriterMode = isTypewriterMode
        self._scrollPercentage = scrollPercentage
        self.isEditable = isEditable
        self.themeMode = themeMode
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = EditorScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.isTypewriterMode = isTypewriterMode
        scrollView.postsFrameChangedNotifications = true
        scrollView.verticalScroller = nil

        let clipView = scrollView.contentView
        clipView.postsBoundsChangedNotifications = true

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.clipViewBoundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: clipView
        )

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewFrameDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )

        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = EditorTextView(frame: .zero, textContainer: textContainer)
        textView.minSize = NSSize(width: 0.0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        // Strict Typographic & Monochrome Setup
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.focusRingType = .none

        // Centered Golden-Measure Insets (700pt maximum readable line width)
        let maxTextWidth: CGFloat = 700
        let horizontalMargin = max(48, (contentSize.width - maxTextWidth) / 2)
        let verticalInset: CGFloat = isTypewriterMode ? max(36, contentSize.height * 0.4) : 36
        textView.textContainerInset = NSSize(width: horizontalMargin, height: verticalInset)

        textView.delegate = context.coordinator
        scrollView.documentView = textView
        scrollView.editorTextView = textView
        context.coordinator.textView = textView
        scrollView.updateInsets()

        applyMasterTypography(to: textView)
        updateColors(for: textView)
        textView.string = text
        let fullRange = NSRange(location: 0, length: textView.string.utf16.count)
        if fullRange.length > 0 {
            textView.textStorage?.addAttribute(.kern, value: 0.38, range: fullRange)
        }
        applyMasterTypography(to: textView)
        updateHighlights(in: textView, query: searchQuery)
        textView.updateParagraphFocus(isTypewriter: isTypewriterMode)

        DispatchQueue.main.async {
            context.coordinator.updateScrollPercentage(async: true)
        }

        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let scrollView = nsView as? EditorScrollView,
              let textView = scrollView.documentView as? EditorTextView else { return }

        // Vertical scroller is completely disabled in all modes (replaced by minimal % indicator)
        if scrollView.hasVerticalScroller {
            scrollView.hasVerticalScroller = false
        }
        scrollView.verticalScroller?.isHidden = true

        updateColors(for: textView)
        textView.isEditable = isEditable

        let enteredTypewriter = isTypewriterMode && !scrollView.wasTypewriterMode
        scrollView.isTypewriterMode = isTypewriterMode
        scrollView.wasTypewriterMode = isTypewriterMode
        scrollView.updateInsets()

        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            let fullRange = NSRange(location: 0, length: textView.string.utf16.count)
            if fullRange.length > 0 {
                textView.textStorage?.addAttribute(.kern, value: 0.38, range: fullRange)
            }
            if selectedRange.location + selectedRange.length <= text.count {
                textView.setSelectedRange(selectedRange)
            }
        }

        applyMasterTypography(to: textView)
        updateHighlights(in: textView, query: searchQuery)
        textView.updateParagraphFocus(isTypewriter: isTypewriterMode)

        if enteredTypewriter {
            textView.centerCursorInViewport()
        }

        context.coordinator.updateScrollPercentage(async: true)
    }

    private func applyMasterTypography(to textView: NSTextView) {
        let fontSize: CGFloat = 18.5
        // Master typeface: Charter (Matthew Carter's legendary editorial serif)
        // Fallback: Apple System Serif (New York)
        let font: NSFont
        if let charter = NSFont(name: "Charter", size: fontSize) {
            font = charter
        } else if let descriptor = NSFont.systemFont(ofSize: fontSize, weight: .regular).fontDescriptor.withDesign(.serif) {
            font = NSFont(descriptor: descriptor, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        } else {
            font = NSFont.systemFont(ofSize: fontSize)
        }

        if textView.font != font {
            textView.font = font
        }

        let pStyle = NSMutableParagraphStyle()
        // Ultra-tight leading (0.5pt) and zero extra paragraph spacing (0.0pt) for compact, disciplined lines
        pStyle.lineSpacing = 0.5
        pStyle.paragraphSpacing = 0.0
        pStyle.alignment = .left

        textView.defaultParagraphStyle = pStyle

        if let textStorage = textView.textStorage, textStorage.length > 0 {
            textStorage.addAttribute(.paragraphStyle, value: pStyle, range: NSRange(location: 0, length: textStorage.length))
        }

        let appearance = textView.window?.effectiveAppearance ?? textView.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let textColor = isDark ? NSColor(white: 0.98, alpha: 1.0) : NSColor(white: 0.05, alpha: 1.0)

        // Expanded letter-spacing (tracking / kern) for luxury editorial aesthetic
        let letterSpacing: CGFloat = 0.38

        var typingAttrs = textView.typingAttributes
        typingAttrs[.font] = font
        typingAttrs[.paragraphStyle] = pStyle
        typingAttrs[.kern] = letterSpacing
        if !isTypewriterMode {
            typingAttrs[.foregroundColor] = textColor
        }
        textView.typingAttributes = typingAttrs
    }

    private func updateColors(for textView: NSTextView) {
        let appearance = textView.window?.effectiveAppearance ?? textView.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let textColor = isDark ? NSColor(white: 0.98, alpha: 1.0) : NSColor(white: 0.05, alpha: 1.0)
        let cursorColor = textColor
        let selectionColor = isDark ? NSColor(white: 0.22, alpha: 1.0) : NSColor(white: 0.88, alpha: 1.0)

        textView.insertionPointColor = cursorColor
        textView.selectedTextAttributes = [
            .backgroundColor: selectionColor,
            .foregroundColor: textColor
        ]

        if !isTypewriterMode {
            textView.textColor = textColor
        }
    }

    private func updateHighlights(in textView: EditorTextView, query: String) {
        guard let layoutManager = textView.layoutManager else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            if textView.hadSearchHighlights {
                let fullRange = NSRange(location: 0, length: textView.string.utf16.count)
                layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
                textView.hadSearchHighlights = false
            }
            return
        }

        let fullRange = NSRange(location: 0, length: textView.string.utf16.count)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
        textView.hadSearchHighlights = true

        let nsString = textView.string as NSString
        var searchRange = NSRange(location: 0, length: nsString.length)

        let appearance = textView.window?.effectiveAppearance ?? textView.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let highlightBg = isDark ? NSColor(white: 0.32, alpha: 1.0) : NSColor(white: 0.80, alpha: 1.0)

        var firstFound = false
        while searchRange.location < nsString.length {
            let foundRange = nsString.range(of: trimmed, options: .caseInsensitive, range: searchRange)
            if foundRange.location == NSNotFound { break }

            layoutManager.addTemporaryAttribute(.backgroundColor, value: highlightBg, forCharacterRange: foundRange)

            if !firstFound {
                textView.scrollRangeToVisible(foundRange)
                firstFound = true
            }

            let nextLocation = foundRange.location + max(foundRange.length, 1)
            searchRange = NSRange(location: nextLocation, length: nsString.length - nextLocation)
        }
    }

    @MainActor
    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacEditorView
        weak var textView: EditorTextView?

        init(_ parent: MacEditorView) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func clipViewBoundsDidChange(_ notification: Notification) {
            updateScrollPercentage(async: false)
        }

        @objc func scrollViewFrameDidChange(_ notification: Notification) {
            guard let scrollView = notification.object as? EditorScrollView else { return }
            scrollView.updateInsets()
            updateScrollPercentage(async: false)
        }

        func updateScrollPercentage(async: Bool = false) {
            guard let textView = textView,
                  let scrollView = textView.enclosingScrollView else { return }
            let clipView = scrollView.contentView
            let docHeight = textView.bounds.height
            let clipHeight = clipView.bounds.height
            let maxScroll = max(0, docHeight - clipHeight)
            let currentY = clipView.bounds.origin.y

            let pct: Int
            if maxScroll > 1.0 {
                let clampedY = max(0, min(maxScroll, currentY))
                pct = max(0, min(100, Int(round((clampedY / maxScroll) * 100.0))))
            } else {
                let total = max(1, textView.string.utf16.count)
                let pos = textView.selectedRange().location
                pct = max(0, min(100, Int(round((Double(pos) / Double(total)) * 100.0))))
            }

            if parent.scrollPercentage != pct {
                if async {
                    Task { @MainActor [weak self] in
                        self?.parent.scrollPercentage = pct
                    }
                } else {
                    parent.scrollPercentage = pct
                }
            }
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? EditorTextView else { return }
            self.parent.text = textView.string
            self.parent.updateHighlights(in: textView, query: self.parent.searchQuery)
            if self.parent.isTypewriterMode {
                textView.centerCursorInViewport()
                textView.updateParagraphFocus(isTypewriter: true)
            }
            updateScrollPercentage(async: false)
        }

        public func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? EditorTextView else { return }
            if self.parent.isTypewriterMode {
                textView.centerCursorInViewport()
                textView.updateParagraphFocus(isTypewriter: true)
            }
            updateScrollPercentage(async: false)
        }
    }
}
