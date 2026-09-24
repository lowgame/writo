import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSWindow.allowsAutomaticWindowTabbing = false

        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") ?? Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = iconImage
        }

        // Wipe any saved tab bar preferences
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys {
            if key.contains("Tabbing") || key.contains("TabBar") {
                defaults.removeObject(forKey: key)
            }
        }

        for window in NSApp.windows {
            window.tabbingMode = .disallowed
            if let tabGroup = window.tabGroup, tabGroup.isTabBarVisible {
                window.toggleTabBar(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct WritoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var state = AppState()

    var body: some Scene {
        Window("Writo", id: "main") {
            MainView(state: state)
                .frame(minWidth: 680, minHeight: 440)
                .background(MonocleTheme.background)
                .preferredColorScheme(state.themeMode.colorScheme)
                .onReceive(DistributedNotificationCenter.default().publisher(for: Notification.Name("family.o.saveAll"))) { _ in
                    state.saveToiCloud()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 960, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Yeni Not") {
                    state.createNote()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(replacing: .saveItem) {
                Button("iCloud'a Kaydet") {
                    state.saveToiCloud()
                }
                .keyboardShortcut("s", modifiers: .command)
            }

            CommandGroup(replacing: .undoRedo) {
                Button("Geri Al") {
                    NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: .command)

                Button("Yinele") {
                    NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }

            CommandGroup(after: .textEditing) {
                Button("Ara veya Oluştur...") {
                    state.focusSearch()
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            CommandMenu("Not") {
                Button("Notu Arşivle") {
                    state.archiveSelectedNote()
                }
                .keyboardShortcut(.delete, modifiers: .command)

                Button("Arşivlenen Notu Geri Getir") {
                    state.undoLastArchive()
                }
                .keyboardShortcut("z", modifiers: [.command, .option])

                Button("Notu Kalıcı Olarak Sil") {
                    state.permanentlyDeleteSelectedNote()
                }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
            }

            CommandMenu("Görünüm") {
                Button(state.isSidebarVisible ? "Kenar Çubuğunu Gizle" : "Kenar Çubuğunu Göster") {
                    state.toggleSidebar()
                }
                .keyboardShortcut("b", modifiers: .command)

                Button(state.isTypewriterMode ? "Daktilo Modundan Çık" : "Daktilo ve Odak Modu") {
                    state.toggleTypewriterMode()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button(state.isViewingArchive ? "Aktif Notlara Dön" : "Arşivi Göster") {
                    state.toggleArchiveView()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Divider()

                Button("Temayı Değiştir") {
                    state.toggleTheme()
                }
                .keyboardShortcut("d", modifiers: .command)

                Menu("Tema Tercihi") {
                    Button(action: { state.setTheme(.system) }) {
                        HStack {
                            Text("Sistem")
                            if state.themeMode == .system {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Button(action: { state.setTheme(.light) }) {
                        HStack {
                            Text("Açık Mod")
                            if state.themeMode == .light {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Button(action: { state.setTheme(.dark) }) {
                        HStack {
                            Text("Koyu Mod")
                            if state.themeMode == .dark {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            CommandMenu("Ayarlar") {
                Button(action: {
                    LaunchAtLoginManager.shared.toggle()
                }) {
                    HStack {
                        Text("Başlangıçta Aç")
                        if LaunchAtLoginManager.shared.isEnabled {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Button("iCloud'a Kaydet") {
                    state.saveToiCloud()
                }
            }
        }
    }
}
