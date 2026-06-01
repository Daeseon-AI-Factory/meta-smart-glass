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
<!-- skipped: 324f8ee docs(log): record product decisions + 'labeling vs learning' direction [no-log] -->

## On-device model: 600-class OIV7 swap tanked accuracy, reverted

- **Symptom**: After swapping the Live detector from `yolo11n` (COCO 80) to `yolov8n-oiv7` (Open Images V7, 600 classes), on-device detection recognized *fewer* objects and felt slower on the iPhone — user: "정확도가 병신이다", "뭔가 더 인식을 못하는거 같은데?? 좀 느린거같기도".
- **Cause**: OIV7 nano has far lower accuracy than the COCO models (Ultralytics-reported mAP ≈ 18 vs yolo11n ≈ 39), so per-detection confidence is low — at the `confidence > 0.5` gate most detections were filtered out, giving *less* coverage despite 7.5× the classes. The YOLOv8 backbone is also slightly heavier than yolo11. Dropping the gate to 0.25 surfaced more boxes but accuracy was still poor. The regression was the *model family + training set*, not the class count (80→600 head added only 1.7MB).
- **Fix**: reverted to `yolo11n` (`git restore` of `ios-app/SmartGlass/yolo11n.mlpackage`, removed `yolov8n-oiv7.mlpackage`); model name + confidence (0.5) restored in `ios-app/SmartGlass/LiveDetection.swift`. Breadth for non-COCO objects (밥솥/자판기/젓가락 — none in COCO 80) is deferred to a cloud tap (Gemini), not a bigger on-device model.
- **Commit**: bd56457
- **Pattern**: More classes ≠ better detection. A large-taxonomy model (OIV7) trades away per-class accuracy; for real-time on-device, keep a small high-accuracy COCO model and cover the long tail via a cloud lookup.

## Phone hit Grafana, not our backend: IPv4/IPv6 port collision on 3001

- **Symptom**: `curl http://localhost:3001/health` returned **Grafana HTML** (not our JSON); the phone's cloud features were intermittently broken.
  ```
  <!DOCTYPE html> ... <title>Grafana</title> ...
  ```
- **Cause**: two processes LISTENing on 3001 — our Bun backend on IPv4 (`*:3001`) and a Docker/Grafana container on IPv6 (`[::]:3001`). `localhost` resolves IPv6 (`::1`) first → Grafana. The phone reaching `.local:3001` over IPv6 hit Grafana too.
- **Fix**: moved the backend off the contested port — `backend/.env` `PORT=8787` (gitignored) and `ios-app/project.yml` `BackendBaseURL` → `:8787`. Verified our backend on `127.0.0.1:8787` + a real Gemini `/api/suggest` call (1036ms). Grafana untouched.
- **Commit**: dadf24d
- **Pattern**: A host port can carry separate IPv4 and IPv6 bindings; `localhost` (IPv6-first) can route to a different process than `127.0.0.1`. Check ownership with `lsof -nP -iTCP:<port> -sTCP:LISTEN` and avoid ports a Docker container may also bind.

## Docker container "Up" + empty logs + health fails (but the app is fine)

- **Symptom**: after `docker run`, host `curl /health` failed, `docker logs` was empty, yet `docker ps` showed the container **Up** (ExitCode 0).
- **Cause**: not the app — the *check*. `curl --retry-connrefused` only retries on connection-refused, but Docker's port proxy opens the host port immediately, so during the ~1s boot you get a connection **reset**, not refused → no retry, gave up before boot finished. Probing inside the container (`docker exec ... bun -e 'fetch(...)'`) returned healthy JSON and logs showed `Server running at http://localhost:8080`.
- **Fix**: poll from inside the container / wait for boot before checking. Image is correct (372MB, builds, runs, serves `/health`).
- **Commit**: dadf24d
- **Pattern**: A failing container health check can be tooling/timing, not the app. On "Up + empty logs + no response", probe from *inside* the container first to separate the app from the host port-proxy layer.
