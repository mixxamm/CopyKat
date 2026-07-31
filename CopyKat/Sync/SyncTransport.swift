import Foundation

// A way to carry qualifying history between devices. CloudKit is the first
// transport; a local-network one (for people who would rather not spend
// iCloud storage) is the anticipated second. Everything upstream — the
// policy, the record mapping, the store hooks — is transport-agnostic on
// purpose, so a new transport implements these three calls and plugs into
// the same `historyChanged` pipeline.
@MainActor
protocol SyncTransport: AnyObject {
    // Bring the transport up if the user's settings allow it. Safe to call
    // repeatedly; a running transport ignores it.
    func start()

    func stop()

    // The history or the sync policy moved; ship the difference when
    // convenient. Debouncing is the transport's own business.
    func scheduleReconcile()
}

extension CloudSyncController: SyncTransport {}
