import SwiftData
import SwiftUI

struct PanelView: View {
    @Bindable var model: PanelViewModel
    let imageStore: ImageStore
    let onCommit: (ClipboardItem) -> Void
    let onDismiss: () -> Void
    let onRecordShortcut: (ClipboardItem) -> Void

    @FocusState private var searchFocused: Bool
    @State private var scrolledID: PersistentIdentifier?

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
        GeometryReader { geometry in
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    // Real spacer views, not contentMargins: only actual content
                    // gives the scroll view room to move, so the first rows can
                    // reach the centre line instead of clamping at the top.
                    Color.clear.frame(height: edgeRunway(in: geometry))
                    ForEach(model.entries) { entry in
                        switch entry {
                        case .header(let section):
                            sectionHeader(for: section)
                                .id(entry.id)
                        case .row(let item, let index, let indented, let showsSourceApp):
                            ItemRow(
                                item: item,
                                isSelected: item.persistentModelID == model.selectedID,
                                imageStore: imageStore,
                                showsSourceApp: showsSourceApp,
                                quickPasteBadge: index < 9 ? index + 1 : nil
                            )
                            .padding(.leading, indented ? 18 : 0)
                            .id(entry.id)
                            .onTapGesture { onCommit(item) }
                            .contextMenu {
                                Button(item.isPinned ? String(localized: "Unpin") : String(localized: "Pin")) {
                                    model.togglePin(item)
                                }
                                if item.isPinned {
                                    Button("Record Shortcut…") { onRecordShortcut(item) }
                                }
                                Divider()
                                Button("Delete", role: .destructive) { model.delete(item) }
                            }
                        }
                    }
                    Color.clear.frame(height: edgeRunway(in: geometry))
                }
                .scrollTargetLayout()
                .padding(6)
            }
            .scrollPosition(id: $scrolledID, anchor: .center)
            .onChange(of: model.selectedID) { _, id in
                scrolledID = id
                guard let id else { return }
                // Keep the highlight at a fixed height and move the list under
                // it, so the eye never has to chase the selection while cycling.
                if AppSettings.animateScrolling, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                } else {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            // Both hooks are needed: on the very first showing the view is
            // created after the token already changed, so onChange never fires.
            .onChange(of: model.openToken) { _, _ in centre(proxy) }
            .onAppear { centre(proxy) }
        }
        }
    }

    // Scrolling straight away lands on a list that has not been laid out yet,
    // so hop to the next runloop pass first.
    // LazyVStack estimates the height of rows it has not built yet, so a single
    // scroll lands beside the mark whenever the list just changed. A second
    // pass, once the real heights are known, settles it exactly.
    private func centre(_ proxy: ScrollViewProxy) {
        for delay in [0.0, 0.05, 0.15] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard let id = model.selectedID else { return }
                scrolledID = id
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }

    // A full half viewport of runway. Rows vary in height, and anything less
    // leaves the first row a few points above centre because the scroll offset
    // it would need is negative and gets clamped to zero.
    private func edgeRunway(in geometry: GeometryProxy) -> CGFloat {
        geometry.size.height / 2
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
