import Foundation
import ServiceManagement

@MainActor
public final class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()

    @Published public private(set) var isEnabled: Bool = false

    private init() {
        refresh()
    }

    public func refresh() {
        if #available(macOS 13.0, *) {
            isEnabled = (SMAppService.mainApp.status == .enabled)
        } else {
            isEnabled = UserDefaults.standard.bool(forKey: "LaunchAtLogin")
        }
    }

    public func toggle() {
        setLaunchAtLogin(!isEnabled)
    }

    public func setLaunchAtLogin(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("[writo] Launch at login error: \(error)")
            }
            isEnabled = (SMAppService.mainApp.status == .enabled)
        } else {
            isEnabled = enable
            UserDefaults.standard.set(enable, forKey: "LaunchAtLogin")
        }
    }
}
