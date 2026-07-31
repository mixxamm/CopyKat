# Vision indexing for images

Status: agreed, to build on the Mac app before the iPhone companion starts.

## What this is

Copied images stop being blind spots in search. Every image that enters the
history is run through Apple's Vision framework, on device, and what Vision finds
becomes part of the item: recognized text, decoded QR codes, and classification
labels. The existing fuzzy search then simply matches against it.

Everything runs locally. No network, no cloud, which keeps the privacy story
intact word for word.

## Availability

Read from the SDK headers, not from blog posts: `VNRecognizeTextRequest`,
`VNClassifyImageRequest` and `VNGenerateImageFeaturePrintRequest` are
macOS 10.15+, `VNDetectBarcodesRequest` is 10.13+. Our deployment target is
14.0, so no availability guards are needed anywhere. OCR supports ~32 languages
including nearly all 18 the app ships in.

## Features

1. **Searchable screenshots.** OCR text is stored on the item and joins the
   fuzzy-search haystack next to the item text and the source app name.
2. **Paste as text.** An image with recognized text can be pasted *as* that text:
   ⌥-Enter in the panel, and a context-menu action. The injected text is recorded
   in the self-write tracker so pasting does not grow the history.
3. **QR codes.** Decoded payloads are stored, shown in the preview pane, pasteable
   and searchable.
4. **Labels.** `VNClassifyImageRequest` classifications above a confidence
   threshold are stored as tags and searchable. They are English identifiers and
   are shown as-is; translating a ~1000-class taxonomy is not worth it.

The dedicated animal request is skipped: it only knows cats and dogs, which the
classifier already covers.

## Shape

- `ClipboardItem` gains `recognizedText: String?`, `qrPayload: String?`,
  `imageLabels: String?` (space-joined) and `visionIndexed: Bool` — all with
  defaults, so the migration is additive and the fields are CloudKit-ready.
- A new `ImageIndexer` runs the three Vision requests off the main thread and
  hands results back to the store, which saves on the main actor.
- Indexing happens when an image is added. At launch, unindexed images (from
  histories that predate this feature) are backfilled serially in the background.
- A settings toggle, on by default, gates the whole thing. Local-only, so opt-out
  rather than opt-in.

## Tests

Vision itself is Apple's; what we test is our plumbing around it, with generated
fixtures rather than checked-in bitmaps: an image with rendered text must come
back findable through the search, a CoreImage-generated QR code must decode to
its payload, and paste-as-text must put the text on the pasteboard without
adding a history item.
