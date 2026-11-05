# Sibyl Control 0.1 — Flutter Android / Windows / Linux

![Sibyl Control](assets/branding/banner-wordmark.png)

Unofficial earbud controller based on static analysis of the user-provided SIBYL MUSIC 1.26 APK. One Flutter UI and controller are shared across all three targets; desktop gets a navigation rail, phones get a bottom bar, and both show the same four screens.

## UI

The interface is one system, not a page of stacked cards:

- **Four screens** — 设备 (connect, battery, product configuration), 声音 (ANC, low-latency, equaliser), 设置 (switches, name, prompt volume, auto power-off, buttons), 日志 (log and the honesty statement). Rail at ≥900 px, bottom bar below it.
- **One design system** in `lib/ui/theme.dart`: one palette (no violet), one 4/8/12/16/24/32/48 spacing scale, one sharp radius family (8/6/4), one type scale, one button pair (filled = the single main action of a view, outlined = every secondary), one chip, one card, one switch row.
- **One blocking sentence per screen.** When a control cannot be used, the screen says why once at the top and offers the action that fixes it, instead of repeating a different apology under every control.
- **No typing where a list exists.** ANC strength is chosen from the configured levels; the old free-text `level` field is gone. The equaliser is ten vertical faders in one strip, horizontally scrollable on a phone.
- **Unknown stays unknown.** An unreported battery shows "—" over a dashed track, never a 0 % bar; drafts are badged and never presented as device state.
- `tool/ui_preview.dart` renders the UI against a stub model (`preview: true` on every snapshot) for layout review without hardware: `flutter run -t tool/ui_preview.dart -d linux`.

## Branding assets

`assets/branding/` holds the product mark. The concept was drafted with an
image model and then **redrawn as SVG** (`icon.svg`, `mark.svg`,
`mark-bold.svg`) so every exported size is crisp and uses only the app's three
colours — a geometric S built from two 270° arcs, light cornflower `#5AB9FC`
on `#0A0D14`.

- `assets/mark.png` — the transparent mark the header renders at 26 px (heavier
  stroke master, so it does not read as a section sign beside the wordmark).
- `assets/branding/app_icon.ico` — Windows multi-resolution icon (16→256; 16 and
  24 come from a thicker master because a naive downscale washes the stroke
  out). The Windows workflow re-copies it after `flutter create`, which
  otherwise restores the stock Flutter icon.
- `android/app/src/main/res/mipmap-*/ic_launcher.png` — launcher icons, 48→192.
- `assets/branding/banner-wordmark.png` — repository header.
- Rebuild everything with `rsvg-convert` from the SVGs; no raster master is
  edited by hand.

The Linux runner still uses the GTK default window icon: wiring it needs a
`.desktop` entry at install time, which this repo does not ship.

## Implemented
- BLE discovery using manufacturer0xC912 / FE service, vendor/model decoding (ordinary/QCC/RTK), manual address entry, connection lifecycle and notifications.
- Ordinary BLE and QCC: reported battery, configured ANC modes/levels, gaming, ten-band custom EQ. Writes remain disabled without explicit product configuration.
- BLE transport validates FE/F1 and notify characteristics, negotiates MTU, rejects oversized unfragmentable writes instead of inventing a fragmentation protocol.
- RTK: real RFCOMM transports for Android, Windows Winsock and Linux BlueZ sockets; basic ACK/status handling and gaming query-before-toggle. ANC/EQ writes remain locked because capability/group negotiation is not yet fully ported.
- No automatic connection/scan on launch. No OTA, factory reset or clear-pairing controls.
- No fabricated device data. Unknown battery/state displays unknown; sliders edit drafts, not reported state. Only explicit clicks send control packets.
- Bounded logs remain in memory; product configuration is stored locally with shared_preferences, no cloud sync.

## Configuration
Use “导入 JSON” on the 设备 screen while disconnected, or “读取产品配置” once connected. The following is a SCHEMA EXAMPLE ONLY, NOT A VERIFIED PRODUCT PRESET:

```json
{
  "modelId": 123,
  "ancModes": [
    {"id": 1, "label": "降噪", "defaultLevel": 0, "levels": [0]},
    {"id": 2, "label": "关闭", "defaultLevel": 0, "levels": [0]},
    {"id": 3, "label": "通透", "defaultLevel": 0, "levels": [0]}
  ],
  "game": true,
  "eq": {"labels": ["Band1", "Band2", "Band3", "Band4", "Band5", "Band6", "Band7", "Band8", "Band9", "Band10"], "min": -12, "max": 12}
}
```

Replace EVERY capability, mode, level, frequency label and gain range with values confirmed for your product; do not import this example unchanged. Manufacturer model ID mismatch blocks a scanned device. Manual connection cannot independently verify a model: the user must select the correct protocol/configuration. QCC's ANC UI path in the original APK uses the ordinary frame; hardware support is unverified.

## Platform prerequisites
- Android: Bluetooth runtime permissions prompted only on action. Android12+ SCAN/CONNECT; Android11 and older location permission for BLE. Native RFCOMM runs on background executors.
- Linux: BlueZ/system D-Bus and an enabled adapter; local user must have BlueZ permission. RTK without explicit channel requires `sdptool` (often bluez-deprecated); explicit channels must be confirmed, not guessed. Launch under a graphical session.
- Windows: Windows10+ Bluetooth LE adapter/driver; run `flutter build windows --release` on Windows with Visual Studio2022 C++ desktop tools. Winsock RFCOMM includes correct Bluetooth sockaddr alignment and UUID fallback; Windows compilation/runtime is not verified from Linux.

## Build / validation
Flutter3.47.7 / Dart3.13.5 used on the build host. Run sequentially:

```
flutter pub get
dart analyze lib tool
dart tool/protocol_check.dart
CMAKE_BUILD_PARALLEL_LEVEL=1 flutter build linux --release
flutter build apk --debug --target-platform android-arm64
```

Android gradle.properties caps workers1/heap768MiB, disables parallel/daemon and uses in-process Kotlin. No pytest, no tests through wrappers, no full heavyweight test suite. `protocol_check.dart` is a small standalone offline check of explicit synthetic vectors, fragmentation/bounds and signed arithmetic; it does not validate hardware.

## Limits
This is an initial implementation, not universal hardware compatibility. Reverse-engineered wire format is not device acceptance. ACK alone is not a reported final state; timeouts do not imply failure or success and toggles are never automatically retried. Product-specific configs were not present in the APK and were not fetched. No earphone was scanned/connected and no control command sent during development. RTK ANC/EQ and full SDK capability bootstrap remain incomplete. Android debug APK, if built, is not a production-signed release. Windows executable must be built/validated on Windows.

See VERIFICATION.md for actual per-platform outcomes. The source and generated runners are provided so the unbuilt target is not represented as a binary deliverable.
