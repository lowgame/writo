import SwiftUI

public struct MainView: View {
    @Bindable var state: AppState

    public var body: some View {
        ZStack {
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

            if state.isSavedToCloudOverlayVisible {
                ZStack {
                    MonocleTheme.background.opacity(0.85)
                        .ignoresSafeArea()

                    VStack(spacing: 8) {
                        Image(systemName: "icloud.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(MonocleTheme.foreground)

                        Text("saved to icloud")
                            .font(MonocleTheme.charterFont(size: 14, weight: .semibold))
                            .foregroundStyle(MonocleTheme.foreground)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(MonocleTheme.background)
                            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 6)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(MonocleTheme.microBorder, lineWidth: 1)
                    )
                }
                .transition(.opacity)
                .zIndex(1000)
            }
        }
        .animation(MonocleTheme.spring, value: state.isSavedToCloudOverlayVisible)
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
