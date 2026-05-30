# Troubleshooting log

Issues hit and the fix for each. Newest at the bottom.

Format for each entry: **Symptom** · **Cause** · **Fix** · **Commit** · (optional **Pattern**).

When you fix a non-trivial issue, append an entry below. The Stop hook in `.claude/settings.json` reminds about this after any recent commit.

---

## How to add a new entry

```markdown
## <short title>

- **Symptom**: <literal error message or observable behavior>
- **Cause**: <verified explanation> (or `Hypothesis: ... Verified by: ...`)
- **Fix**: <files/functions changed, mechanism>
- **Commit**: <hash from `git rev-parse HEAD` AFTER committing>
- **Pattern**: <one-line recurring lesson — optional>
```

Concrete only. Numbers, file paths, commit hashes. No "lessons learned" essays.
<!-- skipped: 3614d7d Add Claude Code project-log system + backfill project history [no-log] -->
<!-- skipped: 18703e3 docs(log): record Phase 1 /api/suggest feature [no-log] -->
<!-- skipped: f4a8643 docs(log): record scan/translate feature [no-log] -->

## Swift 6 strict concurrency + AVFoundation camera

- **Symptom**: `xcodebuild` failed under `SWIFT_STRICT_CONCURRENCY: complete`:
  ```
  Camera.swift: error: passing closure as a 'sending' parameter risks causing data races between main actor-isolated code and concurrent execution of the closure
  ScanView.swift: error: non-Sendable 'some View'-typed result can not be returned from main actor-isolated instance method 'sourceLabel(_:systemImage:)' to nonisolated context
  ```
- **Cause**: (1) `AVCaptureSession` is non-Sendable, so capturing it into `Task.detached` for off-main `startRunning()`/`stopRunning()` crosses an actor boundary. (2) `sourceLabel(...)` was a `@MainActor` `View` method returning `some View`, called inside PhotosPicker's nonisolated label closure.
- **Fix**: (1) wrap the session in an `@unchecked Sendable` `SessionBox` to carry it into the detached task; the photo-capture delegate maps to a `Sendable Result<Data, CameraError>` before hopping to `@MainActor`. (2) extract the label into a `SourceButtonLabel: View` struct (constructed, not a MainActor method call). Files: `ios-app/SmartGlass/Camera.swift`, `ios-app/SmartGlass/ScanView.swift`.
- **Commit**: 9272b69
- **Pattern**: Under strict concurrency, move non-Sendable AVFoundation types into a background `Task` via an `@unchecked Sendable` box, and build reusable SwiftUI labels as `View` structs (not `@MainActor` methods) so nonisolated closures can construct them.
