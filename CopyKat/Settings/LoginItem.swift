import ServiceManagement

// macOS can refuse to (un)register a login item, so callers toggle and then
// take the real state back rather than trusting their own optimism.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // The status below reports what actually happened.
        }
        return isEnabled
    }
}
