import SwiftUI

struct PanelView: View {
    @Bindable var model: PanelViewModel
    let imageStore: ImageStore
    let onCommit: (ClipboardItem) -> Void
    let onDismiss: () -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            HStack(spacing: 0) {
                itemList
                    .frame(width: 300)
                Divider()
                PreviewPane(item: model.selectedItem, imageStore: imageStore)
            }
        }
        .frame(width: 720, height: 440)
        .background(VisualEffectView())
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.separator, lineWidth: 1)
        )
        .onAppear { searchFocused = true }
        .onKeyPress(.downArrow) { model.moveSelection(1); return .handled }
        .onKeyPress(.upArrow) { model.moveSelection(-1); return .handled }
        // With a query, ←/→ belong to the text caret; on an empty field they
        // walk the list, Spotlight-style.
        .onKeyPress(.rightArrow) {
            guard model.query.isEmpty else { return .ignored }
            model.moveSelection(1)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            guard model.query.isEmpty else { return .ignored }
            model.moveSelection(-1)
            return .handled
        }
        .onKeyPress(.return) {
            guard let item = model.selectedItem else { return .ignored }
            onCommit(item)
            return .handled
        }
        .onKeyPress(.escape) { onDismiss(); return .handled }
        .onKeyPress("p", phases: .down) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            model.togglePinSelected()
            return .handled
        }
        .onKeyPress(.delete, phases: .down) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            model.deleteSelected()
            return .handled
        }
        .onKeyPress(phases: .down) { press in
            guard press.modifiers.contains(.command),
                  let digit = press.characters.first?.wholeNumberValue,
                  let item = model.quickPasteItem(at: digit)
            else { return .ignored }
            onCommit(item)
            return .handled
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                model.isFastSession
                    ? LocalizedStringKey("Double-tap V to search")
                    : LocalizedStringKey("Search clipboard history"),
                text: $model.query
            )
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($searchFocused)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
    }

    private var itemList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(model.sections, id: \.id) { section in
                        if section.isGrouped {
                            sectionHeader(for: section)
                        }
                        ForEach(Array(section.items.enumerated()), id: \.element.persistentModelID) { offset, item in
                            let index = section.firstIndex + offset
                            ItemRow(
                                item: item,
                                isSelected: item.persistentModelID == model.selectedID,
                                imageStore: imageStore,
                                showsSourceApp: !section.isGrouped,
                                quickPasteBadge: index < 9 ? index + 1 : nil
                            )
                            .padding(.leading, section.isGrouped ? 18 : 0)
                            .id(item.persistentModelID)
                            .onTapGesture { onCommit(item) }
                            .contextMenu {
                                Button(item.isPinned ? String(localized: "Unpin") : String(localized: "Pin")) {
                                    model.togglePin(item)
                                }
                                if item.isPinned {
                                    Button("Record Shortcut…") {
                                        AppSettings.selectedSettingsTab = SettingsTab.pins.rawValue
                                        SettingsOpener.open()
                                    }
                                }
                                Divider()
                                Button("Delete", role: .destructive) { model.delete(item) }
                            }
                        }
                    }
                }
                .padding(6)
            }
            .onChange(of: model.selectedID) { _, id in
                if let id {
                    proxy.scrollTo(id)
                }
            }
        }
    }

    private func sectionHeader(for section: PanelSection) -> some View {
        HStack(spacing: 6) {
            if let icon = AppIconProvider.icon(forBundleID: section.sourceAppBundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            }
            Text(section.sourceAppName ?? "")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }
}
