import SwiftUI

public struct MainView: View {
    @Bindable var state: AppState

    public var body: some View {
        HStack(spacing: 0) {
            if state.isSidebarVisible {
                SidebarView(state: state)
                    .transition(.move(edge: .leading).combined(with: .opacity))

                Rectangle()
                    .fill(MonocleTheme.microBorder)
                    .frame(width: 1)
                    .ignoresSafeArea()
            }

            EditorView(state: state)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(MonocleTheme.background)
        .animation(MonocleTheme.spring, value: state.isSidebarVisible)
        .background(WindowConfigurator(themeMode: state.themeMode))
    }
}

private struct WindowConfigurator: NSViewRepresentable {
    var themeMode: ThemeMode

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.tabbingMode = .disallowed
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.appearance = themeMode.nsAppearance
                if let tabGroup = window.tabGroup, tabGroup.isTabBarVisible {
                    window.toggleTabBar(nil)
                }
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                window.tabbingMode = .disallowed
                window.appearance = themeMode.nsAppearance
                if let tabGroup = window.tabGroup, tabGroup.isTabBarVisible {
                    window.toggleTabBar(nil)
                }
            }
        }
    }
}
