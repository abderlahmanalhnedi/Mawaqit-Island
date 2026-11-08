import Foundation
import ServiceManagement

/// Uses Apple's macOS 13+ Login Items mechanism. Never registers without
/// an explicit user action in Preferences.
@MainActor
enum LaunchAtLogin {
    static var enabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ shouldStart: Bool) throws {
        let service = SMAppService.mainApp
        if shouldStart {
            if service.status != .enabled {
                try service.register()
            }
        } else if service.status != .notRegistered {
            try service.unregister()
        }
    }
}
