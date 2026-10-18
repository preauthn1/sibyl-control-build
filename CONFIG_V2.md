# Config v2 — Android user feedback follow-up

User reported Android connects and battery displays correctly; other controls were grey. This is USER-REPORTED connection/read verification for an unspecified model/protocol, not our independent hardware test.

## Implemented and compiled
- All pages remain native Flutter Material widgets. No WebView dependency or embedded HTML UI.
- Added explicit Read product configuration action on connected device, plus Refresh status. Scanned manufacturer model ID is used to select one exact original product configuration.
- Static-recovered read-only config client requests only HTTPS product list/control-panel endpoints when user presses the button; no login/token/bind/OTA calls. No such business requests were executed during development.
- Configuration controls supported ANC modes/levels, game, custom EQ, EQ presets, confirmed generic switches and configurable button mappings. Product config is persisted locally. Unknown fields/capabilities remain disabled with explanations.
- Added native settings UI and methods for rename/timer/prompt volume when explicitly configured. Original panel conversion does NOT invent ranges; unsupported numeric controls remain omitted.
- RTK static helper added ACK/status/battery and version-dependent EQ preset/explicit-capability ANC encoding. Full runtime capability discovery is NOT implemented, so these remain gated unless explicit matching capability config is available. RTK custom coefficient generation remains incomplete.

## Verified
- Dart analyze: No issues found (analyze_v2.log).
- Protocol check109 synthetic vectors passed.
- Config check36 synthetic checks passed, no network/device I/O.
- RTK source-derived offline checks passed, no hardware claim.
- Android ARM64 release-mode preview BUILD SUCCESSFUL in1m24s (build_android_v2.log).
- APK apksigner verify passed; same Android Debug signing certificate as previous preview, not production signed.
- APK: dist/sibyl-control-android-arm64-config-v2.apk, bytes22727249, SHA2562d740c19a33ad223cc039faa6166f2626b7e308675e00e72e6a76db48ab139cd.

## Unverified / incomplete
- Whether original configuration service currently accepts anonymous access; the static original interceptor permits absent Authorization but server behavior was not contacted/verified.
- Exact user's model and protocol; device controls need actual matching config and user confirmation of state changes.
- Complete RTK capability bootstrap and custom EQ; Windows binary build/runtime.
- No claim that every earphone feature is complete or works across all devices. Hardware/control acceptance remains outstanding.

## User steps
Install config-v2 over the preview. Scan/connect as before, then press Read product configuration. On success supported controls appear/enable. If request fails, preserve its exact error and device model/protocol shown in UI; a successful Bluetooth connection alone does not prove config service access. Manual config import remains available. Do not guess another product profile.
