import Foundation

enum AppSettings {
    private static let defaults = UserDefaults.standard

    static var maxItems: Int {
        get {
            let value = defaults.integer(forKey: "maxItems")
            return value > 0 ? value : 200
        }
        set { defaults.set(newValue, forKey: "maxItems") }
    }

    static var excludedBundleIDs: [String] {
        get { defaults.stringArray(forKey: "excludedBundleIDs") ?? [] }
        set { defaults.set(newValue, forKey: "excludedBundleIDs") }
    }

    static var hasPromptedAccessibility: Bool {
        get { defaults.bool(forKey: "hasPromptedAccessibility") }
        set { defaults.set(newValue, forKey: "hasPromptedAccessibility") }
    }

    static var selectedSettingsTab: String {
        get { defaults.string(forKey: selectedSettingsTabKey) ?? SettingsTab.general.rawValue }
        set { defaults.set(newValue, forKey: selectedSettingsTabKey) }
    }
    static let selectedSettingsTabKey = "selectedSettingsTab"

    // Read via @AppStorage in the views so the menu bar updates live.
    static let menuBarIconKey = "menuBarIcon"
    static let defaultMenuBarIcon = "doc.on.clipboard"
    static let menuBarIconOptions = [
        "doc.on.clipboard", "clipboard", "list.clipboard", "cat.fill", "paperclip",
    ]
}
