import XCTest
import SwiftData
@testable import CopyCat

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
