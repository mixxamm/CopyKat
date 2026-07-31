import XCTest
import SwiftData
@testable import CopyKat

@MainActor
final class PanelViewModelTests: XCTestCase {
    private var store: HistoryStore!
    private var model: PanelViewModel!
    private var imageDirectory: URL!

    override func setUpWithError() throws {
        imageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PanelViewModelTests-\(UUID().uuidString)")
        let imageStore = try ImageStore(directory: imageDirectory)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ClipboardItem.self, configurations: config)
        store = HistoryStore(container: container, imageStore: imageStore)
        model = PanelViewModel(store: store)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: imageDirectory)
    }

    private func seed(_ texts: [String]) throws {
        for text in texts {
            try store.add(ClipboardCandidate(content: .text(text), sourceAppBundleID: nil, sourceAppName: nil))
        }
        model.reset()
    }

    private func seedApp(_ text: String, app: String?) throws {
        try store.add(ClipboardCandidate(content: .text(text), sourceAppBundleID: app, sourceAppName: app))
    }


    func testDeleteIsUndoableAndRestoresTheItem() throws {
        try seed(["a", "b", "c"])
        let middle = try XCTUnwrap(model.items.first { $0.text == "b" })

        model.delete(middle)
        XCTAssertEqual(model.items.map(\.text), ["c", "a"])
        XCTAssertTrue(model.canUndoDelete)

        model.undoDelete()

        XCTAssertEqual(model.items.map(\.text), ["c", "b", "a"])
        XCTAssertEqual(model.selectedItem?.text, "b")
        XCTAssertFalse(model.canUndoDelete)
    }

    func testUndoWalksBackThroughSeveralDeletions() throws {
        try seed(["a", "b", "c"])
        model.deleteSelected()
        model.deleteSelected()
        XCTAssertEqual(model.items.map(\.text), ["a"])

        model.undoDelete()
        XCTAssertEqual(model.items.map(\.text), ["b", "a"])
        model.undoDelete()
        XCTAssertEqual(model.items.map(\.text), ["c", "b", "a"])
        XCTAssertFalse(model.canUndoDelete)
    }

    func testUndoDoesNothingOnceTheWindowHasPassed() throws {
        try seed(["a", "b"])
        let item = try XCTUnwrap(model.items.first)
        store.deleteUndoably(item, at: .now.addingTimeInterval(-HistoryStore.undoWindow - 1))

        XCTAssertNil(store.undoLastDelete())
        XCTAssertFalse(model.canUndoDelete)
    }

    func testUndoKeepsAPinnedItemPinned() throws {
        try seed(["a"])
        let item = try XCTUnwrap(model.items.first)
        model.togglePin(item)

        model.deleteSelected()
        model.undoDelete()

        XCTAssertEqual(model.items.count, 1)
        XCTAssertTrue(model.items.first?.isPinned ?? false)
        XCTAssertNotNil(model.items.first?.pinShortcutID)
    }

    func testUndoDoesNotDuplicateContentCopiedAgainMeanwhile() throws {
        try seed(["a"])
        let item = try XCTUnwrap(model.items.first)
        model.delete(item)

        try store.add(ClipboardCandidate(content: .text("a"), sourceAppBundleID: nil, sourceAppName: nil))
        model.undoDelete()

        XCTAssertEqual(model.items.map(\.text), ["a"])
    }

    func testSearchHiddenAlsoShrinksThePanel() throws {
        let previous = AppSettings.hideSearchBar
        defer { AppSettings.hideSearchBar = previous }
        AppSettings.hideSearchBar = true

        try seed(["a"])

        XCTAssertFalse(model.searchIsVisible)
        XCTAssertLessThan(
            PanelSize.current(listIsVisible: true, searchIsVisible: false).height,
            PanelSize.current(listIsVisible: true, searchIsVisible: true).height
        )
    }

    func testListStaysVisibleWhenTheSettingIsOff() throws {
        let previous = AppSettings.hideListUntilSearch
        defer { AppSettings.hideListUntilSearch = previous }
        AppSettings.hideListUntilSearch = false

        try seed(["a", "b"])

        XCTAssertTrue(model.listIsVisible)
        XCTAssertEqual(PanelSize.current(listIsVisible: model.listIsVisible), PanelSize.full)
    }

    func testHiddenListComesBackWhileSearchingAndGoesAwayAgain() throws {
        let previous = AppSettings.hideListUntilSearch
        defer { AppSettings.hideListUntilSearch = previous }
        AppSettings.hideListUntilSearch = true

        try seed(["apple", "banana"])
        XCTAssertFalse(model.listIsVisible)
        XCTAssertEqual(PanelSize.current(listIsVisible: model.listIsVisible), PanelSize.previewOnly)

        model.query = "app"
        XCTAssertTrue(model.listIsVisible)

        model.query = ""
        XCTAssertFalse(model.listIsVisible)
    }

    func testHiddenListStillCyclesThroughItems() throws {
        let previous = AppSettings.hideListUntilSearch
        defer { AppSettings.hideListUntilSearch = previous }
        AppSettings.hideListUntilSearch = true

        try seed(["a", "b", "c"])
        XCTAssertFalse(model.listIsVisible)

        model.moveSelection(1)
        XCTAssertEqual(model.selectedItem?.text, "b")
        model.moveSelection(1)
        XCTAssertEqual(model.selectedItem?.text, "a")
        XCTAssertFalse(model.listIsVisible)
    }

    func testSettingIsPickedUpOnTheNextOpen() throws {
        let previous = AppSettings.hideListUntilSearch
        defer { AppSettings.hideListUntilSearch = previous }
        AppSettings.hideListUntilSearch = false

        try seed(["a"])
        XCTAssertTrue(model.listIsVisible)

        AppSettings.hideListUntilSearch = true
        model.reset()

        XCTAssertFalse(model.listIsVisible)
    }

    func testRefreshWithNewItemsAsksForRecentring() throws {
        try seed(["a", "b"])
        let before = model.openToken
        try store.add(ClipboardCandidate(content: .text("c"), sourceAppBundleID: nil, sourceAppName: nil))
        model.refresh()
        XCTAssertGreaterThan(model.openToken, before)

        let unchanged = model.openToken
        model.refresh()
        XCTAssertEqual(model.openToken, unchanged)
    }




    func testResetRestoresHighlightToLastPastedItem() throws {
        let previous = AppSettings.lastPastedContentHash
        defer { AppSettings.lastPastedContentHash = previous }

        try seed(["a", "b", "c"])
        let middle = try XCTUnwrap(model.items.first { $0.text == "b" })
        AppSettings.lastPastedContentHash = middle.contentHash

        model.reset()

        XCTAssertEqual(model.selectedItem?.text, "b")
    }

    func testResetFallsBackToFirstWhenLastPastedItemIsGone() throws {
        let previous = AppSettings.lastPastedContentHash
        defer { AppSettings.lastPastedContentHash = previous }

        try seed(["a", "b"])
        AppSettings.lastPastedContentHash = "text:nonexistent"

        model.reset()

        XCTAssertEqual(model.selectedIndex, 0)
    }

    func testSelectionFollowsItemWhenListRefreshesInBackground() throws {
        try seed(["a", "b", "c"])
        model.moveSelection(1)
        let selectedText = try XCTUnwrap(model.selectedItem?.text)

        try store.add(ClipboardCandidate(content: .text("new arrival"), sourceAppBundleID: nil, sourceAppName: nil))
        model.refresh()

        XCTAssertEqual(model.selectedItem?.text, selectedText)
        XCTAssertEqual(model.items.count, 4)
    }

    func testBackfillGivesLegacyPinsAShortcutID() throws {
        try seed(["legacy"])
        let item = try XCTUnwrap(model.items.first)
        store.togglePin(item)
        item.pinShortcutID = nil

        store.backfillPinShortcutIDs()

        XCTAssertNotNil(item.pinShortcutID)
    }

    func testQuickPasteItemUsesOneBasedPositions() throws {
        try seed(["a", "b", "c"])
        XCTAssertEqual(model.quickPasteItem(at: 1)?.text, "c")
        XCTAssertEqual(model.quickPasteItem(at: 3)?.text, "a")
        XCTAssertNil(model.quickPasteItem(at: 0))
        XCTAssertNil(model.quickPasteItem(at: 4))
        XCTAssertNil(model.quickPasteItem(at: 10))
    }

    func testQuickPasteFollowsFilteredList() throws {
        try seed(["apple", "banana", "avocado"])
        model.query = "a"
        XCTAssertEqual(model.quickPasteItem(at: 1)?.text, model.items.first?.text)
    }

    func testTogglePinAndDeleteSpecificItem() throws {
        try seed(["a", "b", "c"])
        let middle = try XCTUnwrap(model.items.first { $0.text == "b" })
        model.togglePin(middle)
        XCTAssertEqual(model.items.first?.text, "b")
        model.delete(middle)
        XCTAssertEqual(model.items.map(\.text), ["c", "a"])
    }

    func testResetShowsAllItemsWithFirstSelected() throws {
        try seed(["a", "b", "c"])
        XCTAssertEqual(model.items.count, 3)
        XCTAssertEqual(model.selectedIndex, 0)
        XCTAssertEqual(model.selectedItem?.text, "c")
    }

    func testQueryFiltersAndResetsSelection() throws {
        try seed(["apple pie", "banana", "apple juice"])
        model.moveSelection(2)
        model.query = "apple"
        XCTAssertEqual(model.items.count, 2)
        XCTAssertEqual(model.selectedIndex, 0)
    }

    func testMoveSelectionClampsAtBounds() throws {
        try seed(["a", "b"])
        model.moveSelection(-1)
        XCTAssertEqual(model.selectedIndex, 0)
        model.moveSelection(5)
        XCTAssertEqual(model.selectedIndex, 1)
    }

    func testSelectedItemNilWhenEmpty() {
        model.reset()
        XCTAssertNil(model.selectedItem)
    }

    func testDeleteSelectedKeepsValidSelection() throws {
        try seed(["a", "b"])
        model.deleteSelected()
        XCTAssertEqual(model.items.count, 1)
        XCTAssertEqual(model.selectedIndex, 0)
        model.deleteSelected()
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertNil(model.selectedItem)
    }

    func testTogglePinSelectedRefreshes() throws {
        try seed(["a", "b"])
        model.moveSelection(1)
        model.togglePinSelected()
        XCTAssertEqual(model.items.first?.text, "a")
        XCTAssertTrue(model.items.first?.isPinned ?? false)
    }
}
