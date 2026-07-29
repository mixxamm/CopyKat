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
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search clipboard history", text: $model.query)
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
                LazyVStack(spacing: 2) {
                    ForEach(Array(model.items.enumerated()), id: \.element.persistentModelID) { index, item in
                        ItemRow(item: item, isSelected: index == model.selectedIndex, imageStore: imageStore)
                            .id(index)
                            .onTapGesture { onCommit(item) }
                    }
                }
                .padding(6)
            }
            .onChange(of: model.selectedIndex) { _, index in
                proxy.scrollTo(index)
            }
        }
    }
}
