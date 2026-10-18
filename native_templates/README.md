# RFCOMM integration

`MainActivity.kt` is a complete Flutter embedding-v2 activity template. Copy it
to the generated Android Kotlin source directory; its package is
`dev.sibyl.control` (adjust to the scaffold's namespace if different). If another
activity already installs native channels, merge this handler rather than
replacing those channels. Only one Android RFCOMM transport may be active at once
(the MethodChannel/EventChannel identify a single native socket).

The owning app must add `ffi` to pubspec dependencies and these manifest entries:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-feature android:name="android.hardware.bluetooth" android:required="false" />
```

Request runtime Bluetooth permissions in the app's existing BLE-plugin permission
flow before RFCOMM connect. This activity checks `BLUETOOTH_CONNECT` (API 31+),
legacy Bluetooth permission and adapter-enabled state; it does not display a
permission prompt or enable Bluetooth. This adapter does not scan, cancel
Bluetooth discovery (which would require an additional Android 12 permission),
or initiate any activity until the app calls `connect` explicitly.

## Wire contract

- MethodChannel `dev.sibyl.control/rfcomm`:
  - `connect`: map `{address: "AA:BB:CC:DD:EE:FF"}`; channel rejected on Android.
  - `write`: Uint8List, maximum 1 MiB; await writes sequentially.
  - `disconnect`: no arguments; closes the active/pending socket on an executor.
- EventChannel `dev.sibyl.control/rfcomm_rx`:
  - Uint8List for received data.
  - `{type: "error", message: "..."}` for terminal transport failures.
  - `{type: "disconnected"}` for closure.

Android attempts **secure** public-API RFCOMM using RTK service UUID
`6A24EEAB-4B65-4693-986B-3C26C352264F`, then standard SPP UUID
`00001101-0000-1000-8000-00805F9B34FB`. Each connect attempt is closed by a watchdog
after 12 seconds. There is no hidden-channel reflection or insecure fallback.
Reads and writes run on background executors; a 10-second write watchdog closes
the socket to unblock a stalled write. Close also interrupts a blocked read or
connect. Errors propagate both through method replies and the event stream.

Desktop native handles stay in a dedicated Dart isolate. Sockets are nonblocking;
connect/poll/read/write are not performed on the Flutter UI isolate. Poll ticks
are capped at eight 4 KiB reads. Connect deadline is 25 seconds overall (up to
12 seconds per Windows UUID attempt); write deadline is 10 seconds. On Windows,
Winsock `SOCKADDR_BTH` uses the header's one-byte packing: size 30, offsets
family=0, address=2, GUID=10, port=26. A zero port plus UUID delegates SDP to
Winsock. Linux `sockaddr_rc` uses size 10, family=0, bdaddr=2, channel=8.

Linux accepts explicit channels 1..30 or invokes BlueZ `sdptool browse --xml
ADDRESS` for at most 10 seconds with a 1 MiB output cap. It only accepts channels
in records whose service-class list contains the RTK or SPP UUID and whose
protocol-descriptor list identifies RFCOMM. Missing sdptool, absent service or
invalid channel is an explicit error, never a guessed channel 1. Linux tries
SDP-resolved RTK channels before SDP-resolved SPP channels within the same total
deadline; explicit-channel requests try only that channel.

`RfcommTransport.dispose()` additionally closes streams and terminates the
native worker; `disconnect()` keeps streams reusable. Subscribe to `received`
and `errors` before connecting. This source delivery has not been compiled or
hardware-tested; the parent build task owns dependency resolution, scaffold
integration, analysis and platform builds. No hardware operations were run.
