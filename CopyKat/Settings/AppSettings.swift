import Foundation

enum AppSettings {
    private static let defaults = UserDefaults.standard

    // Preferences live under the bundle identifier, so renaming it would reset
    // everyone's settings. Copy the old domain over once.
    private static let legacyDomain = "dev.mixxamm.CopyKat"

    static func migrateLegacyDefaults() {
        let migratedKey = "migratedFromLegacyDomain"
        guard !defaults.bool(forKey: migratedKey),
              let legacy = UserDefaults(suiteName: legacyDomain)
        else { return }

        for (key, value) in legacy.persistentDomain(forName: legacyDomain) ?? [:]
        where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
        }
        defaults.set(true, forKey: migratedKey)
    }

    static var maxItems: Int {
        get {
            let value = defaults.integer(forKey: "maxItems")
            return value > 0 ? value : 200
        }
        set { defaults.set(newValue, forKey: "maxItems") }
    }

    static var unlimitedHistory: Bool {
        get { defaults.bool(forKey: "unlimitedHistory") }
        set { defaults.set(newValue, forKey: "unlimitedHistory") }
    }

    // nil when the user turned the cap off, so the store keeps everything.
    static var historyLimit: Int? {
        unlimitedHistory ? nil : maxItems
    }

    static var excludedBundleIDs: [String] {
        get { defaults.stringArray(forKey: "excludedBundleIDs") ?? [] }
        set { defaults.set(newValue, forKey: "excludedBundleIDs") }
    }

    // Password managers that don't mark their clipboard writes with the
    // concealed-type convention (Apple's own Passwords app among them), so we
    // exclude them by app identity instead.
    static let builtInExcludedBundleIDs: Set<String> = [
        "com.apple.Passwords",
        "com.apple.keychainaccess",
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "org.keepassxc.keepassxc",
        "com.dashlane.dashlanephonefinal",
        "com.lastpass.lastpassmacdesktop",
        "in.sinew.Enpass-Desktop",
        "me.proton.pass.electron",
        "com.keepersecurity.passwords",
    ]

    static var effectiveExcludedBundleIDs: Set<String> {
        builtInExcludedBundleIDs.union(excludedBundleIDs)
    }

    // The panel reopens with the highlight on the item pasted last, tracked by
    // content hash so it survives restarts and reordering.
    static var lastPastedContentHash: String? {
        get { defaults.string(forKey: "lastPastedContentHash") }
        set { defaults.set(newValue, forKey: "lastPastedContentHash") }
    }

    // Off by default: the sliding list reads as distracting to most people,
    // while the jump keeps the highlight in the same spot just as well.
    static var animateScrolling: Bool {
        get { defaults.bool(forKey: "animateScrolling") }
        set { defaults.set(newValue, forKey: "animateScrolling") }
    }

    static var fastPasteEnabled: Bool {
        get { defaults.bool(forKey: "fastPasteEnabled") }
        set { defaults.set(newValue, forKey: "fastPasteEnabled") }
    }

    static var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: "hasCompletedOnboarding") }
        set { defaults.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    // Set when the user explicitly chose copy-only over granting Accessibility;
    // it silences the permission dialog for good.
    static var accessibilityDeclined: Bool {
        get { defaults.bool(forKey: "accessibilityDeclined") }
        set { defaults.set(newValue, forKey: "accessibilityDeclined") }
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
