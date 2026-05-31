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
<!-- skipped: 7cfb48e docs(log): record live-camera feature + first troubleshooting entry [no-log] -->
<!-- skipped: 7fe9703 chore(ios): configurable backend base URL for device testing [no-log] -->

## Gemini 2.5 Flash: empty / truncated structured output

- **Symptom**: `POST /api/suggest` returned `502`: `gemini: no JSON object found in response`. (`/api/translate` worked; latency ~2.3s.)
- **Cause**: Gemini 2.5 Flash has *thinking* on by default, and thinking tokens count against `maxOutputTokens`. With `maxOutputTokens: 400`, thinking consumed the budget and left no room for the JSON body — translate's tiny output squeaked through, suggest's longer JSON did not.
- **Fix**: in `backend/src/providers/gemini.ts` set `config.thinkingConfig = { thinkingBudget: 0 }` (disable thinking — simple, latency-sensitive tasks) and raise `maxOutputTokens` to 1024. Translate latency dropped 2316ms → 670ms; suggest returns valid JSON.
- **Commit**: de3ab15
- **Pattern**: On Gemini 2.5+ Flash, thinking is on by default and eats `maxOutputTokens`; for short / structured / latency-sensitive calls, set `thinkingBudget: 0` and leave the output enough token headroom.
<!-- skipped: bf8d049 docs(log): record Gemini provider + thinking-budget fix [no-log] -->

## Real-device backend access: phone can't reach the Mac

- **Symptom**: On a physical iPhone the app showed `could not connect to the server`, then after pointing at a LAN IP, the request hung on "translating…" for ~60s. The Mac itself timed out connecting to its own `ipconfig` IP.
- **Cause**: three stacked issues — (1) `Bun.serve` bound to `localhost` only, so nothing answered on the LAN interface; (2) the iOS app used `localhost`, which on a phone is the phone itself; (3) the LAN IP was **hardcoded** into `Info.plist` and went stale every time the Mac's IP changed (hotspot 172.20.x → WiFi 192.168.x). macOS firewall was already off, ruling it out.
- **Fix**: (1) `Bun.serve({ hostname: "0.0.0.0" })` to bind all interfaces; (2) `BackendClient` reads `BackendBaseURL` from Info.plist; (3) set it to the Mac's **`.local` mDNS hostname** (`Daeseons-MacBook-Pro.local`) instead of an IP — Bonjour resolves the current IP automatically, so it survives network changes (same WiFi; hotspot mDNS is flaky). Commits `7fe9703`, `abb0668`.
- **Pattern**: For phone→Mac dev, bind `0.0.0.0`, never `localhost`; address the Mac by its `.local` hostname (not a hardcoded IP) so it doesn't break when the IP changes. Covered by ATS `NSAllowsLocalNetworking`.
<!-- skipped: 0b4f75d docs(log): record Look (object labeling) + device-access fix [no-log] -->
