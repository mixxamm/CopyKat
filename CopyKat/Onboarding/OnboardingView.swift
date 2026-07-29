import SwiftUI

struct OnboardingView: View {
    let appState: AppState
    let onFinish: () -> Void

    @State private var step = 0
    @State private var fastPaste = AppSettings.fastPasteEnabled

    private let stepCount = 4

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: welcome
                case 1: directPaste
                case 2: fastPasteStep
                default: wrapUp
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(32)

            Divider()

            HStack {
                HStack(spacing: 7) {
                    ForEach(0..<stepCount, id: \.self) { index in
                        Circle()
                            .fill(index == step ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }
                Spacer()
                Button(step == stepCount - 1 ? String(localized: "Get Started") : String(localized: "Continue")) {
                    if step == stepCount - 1 {
                        onFinish()
                    } else {
                        step += 1
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 520, height: 420)
    }

    private var welcome: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Welcome to CopyKat")
                .font(.title.weight(.bold))
            Text("Everything you copy is saved: text, images and files. Press ⇧⌘V any time to search your clipboard history.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var directPaste: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor)
            Text("Paste directly into any app")
                .font(.title2.weight(.bold))
            Text("With the Accessibility permission, choosing an item pastes it straight into the app you're working in. Without it, items are only copied.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if appState.pasteService.isAccessibilityTrusted {
                Label("Direct paste is enabled", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Enable in System Settings") {
                    appState.pasteService.promptForAccessibility()
                    appState.pasteService.openAccessibilitySettings()
                }
            }
        }
    }

    private var fastPasteStep: some View {
        VStack(spacing: 14) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor)
            Text("Fast paste")
                .font(.title2.weight(.bold))
            Text("Hold the shortcut, tap V to walk through recent items, and let go to paste. Double-tap V when you want to search instead.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Toggle("Enable fast paste", isOn: $fastPaste)
                .onChange(of: fastPaste) { _, value in
                    AppSettings.fastPasteEnabled = value
                }
        }
    }

    private var wrapUp: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor)
            Text("You're all set")
                .font(.title2.weight(.bold))
            Text("CopyKat lives in your menu bar. Pin items with ⌘P, paste the top ones with ⌘1 to ⌘9, and tweak everything in Settings.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}
