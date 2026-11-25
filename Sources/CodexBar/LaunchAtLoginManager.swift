import ServiceManagement

enum LaunchAtLoginManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled || self.needsApproval
    }

    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func openSettings() { SMAppService.openSystemSettingsLoginItems() }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled, !self.isEnabled {
            try service.register()
        } else if !enabled, self.isEnabled {
            try service.unregister()
        }
    }
}
