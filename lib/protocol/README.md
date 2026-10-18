# Offline Dart protocol API

Import `lib/protocol/protocol.dart`. The sole dependency is `dart:typed_data`.
These are static-source reconstructions, not hardware-verified protocols.

## Frames and codecs

- `BleFrame(sequence, command, payload)` and `BleCodec.encode/decode`: ordinary `FF seq len cmd payload AA`; content length includes command. Decode requires exactly one complete frame.
- `QccFrame(group, opcode, [payload])` and `QccCodec.encode/decode`: `00 1D group opcode payload`. `operation` masks opcode with `7F`; `isQueueAck` checks group bit 0. Optional `expectedPayloadLength` enforces packet shape.
- `RtkFrame(sequence, opcode, [params])` and `RtkCodec.encode/decode`: `AA seq lengthLE16 opcodeLE16 params`, no trailer. Transport is SPP/RFCOMM, not ordinary BLE.
- Frame payload accessors return copies. Invalid integer ranges throw `RangeError`; invalid packet structure throws `FormatException`. Unsupported button/mode selections throw `ArgumentError`.
- `ProtocolSequence()` generates 0..255; `ProtocolSequence(rtk: true)` generates 1..255. Call `take()` for a new outbound frame. RTK ACKs share the generator; retries reuse bytes and sequence.

## Daily builders

`BleCodec`: `query(sequence, attributes)`, `gaming(sequence, bool)`, `anc(sequence, mode, level)`, `button(sequence, event, function)`, `eq(sequence, type, gains: signedGains)`.

`QccCodec`: `queryBattery()`, `queryGaming()`, `queryFirmware()`, `queryEq()`, `gaming(bool)`, `button(event, function)`, `eq(type, gains: signedGains)`.

QCC EQ returns ordered frames, not transmitted bytes: preset types 0..127 return one selection; types 128..255 return selection of slot63 then custom data. Supply signed integer gains -128..127 (not unsigned two's-complement bytes). Missing bands become zero. More than ten bands are deliberately rejected. Each coefficient is signed int16 `gain * 60`, big-endian. `decodeGainBlock` reads only the exact 20-byte coefficient block, **not** opcode05 EQ-response records (which have a different seven-byte-per-band layout).

`RtkCodec`: `listeningMode(sequence, mode, group: ...)`, `legacyAnc`, `legacyLlApt`, `toggleGaming(sequence)`, `queryGaming`, `queryBudInfo`, `queryLegacyBattery`. Modern listening mode requires known report capability. Groups must come from runtime device state. `toggleGaming` is explicitly non-idempotent; there is no misleading RTK boolean setter. Direct bud-info query likewise requires known capability; no guessed multi-step workflow is run.

No OTA, factory reset, automatic capability discovery or transport execution is included. Generic low-level encoders accept arbitrary numeric opcodes but there are no dangerous-command convenience builders.

## Incremental parsers

- `BleStreamParser({maxFrameLength: 259})`
- `RtkStreamParser({maxFrameLength: 65539})`
- `QccStreamParser(payloadLength: (group, rawOpcode) => knownLengthOrNull, maxFrameLength: 4096)`

Call `add(List<int> chunk)` for zero or more frames; any fragmentation or coalescing is accepted. Observe `bufferedBytes`, `discardedBytes`; call `reset()` on disconnect or a transport deadline. Retained state is bounded by the configured maximum. Bytes outside 0..255 reject the entire chunk before changing state.

**QCC has no on-wire length or trailer.** A mandatory direction-specific external opcode-to-length schema is required for stream parsing. Unknown schema entries are rejected, not guessed. For a complete transport-delimited QCC notification, use `QccCodec.decode(notification, expectedPayloadLength: ...)`. Searching for the next `00 1D` inside arbitrary payload is not sound framing.

All length-prefixed protocols can contain a corrupt but plausible incomplete length that is indistinguishable from a legitimate fragment. Parsers retain it until completed or explicitly reset rather than speculatively skipping an inner marker. They cannot detect arbitrary corruption of a structurally valid no-checksum frame.

## Discovery and battery

`AdvertisedDevice.fromManufacturerData(companyId, payload)` expects the company identifier already removed, as provided by common scan APIs. `fromManufacturerAdValue(value)` expects a complete type-FF AD **value**, company ID included (not the AD type/length bytes).

Company ID is `0xC912` (LE in raw AD value); payload model is BE at offsets0..1, minimum payload length12. Models `0x3821`/`0x3E71` select `qccBle`/`rtkSpp`; other models select the APK's ordinary fallback without claiming device compatibility. `advertisedClassicAddress` is not the independently discovered BLE connection address. The optional second address requires at least18 payload bytes.

`BatteryStatus.fromBle(frame)` accepts command0C; `fromQcc(frame)` accepts operation32, including response high-bit masking. Both require exactly three bytes, in left/right/case order. Each low7-bit percentage must be0..100, high bit denotes charging. Unknown sentinel percentages are rejected rather than fabricated. Unrelated opcodes return null. Advertisement batteries remain raw bytes. RTK battery response layout is not established and is not invented.

## Validation status and sources

`dart tool/protocol_check.dart` is a dependency-free explicit-check script (no test framework). It contains synthetic vectors, signed EQ extremes, packet splitting at every offset, coalescing, malformed lengths, embedded marker bytes, strict ranges, ACK bits, advertising identification and battery parsing. The authoring subagent intentionally did not execute or analyze Dart; the parent agent owns serialized validation.

Sources: `static_recovered/BLUETOOTH_PROTOCOL.zh.md`, `RTK_PROTOCOL.md`, `ANC_UI_MAPPING.md`, `BUTTON_MAPPING.md`, `DISCOVERY_EQ.md`, `FINAL.zh.md` under the adjacent `sibyl-bluetooth` workspace. No panel cache is available: no product frequencies, gain UI limits, ANC levels, preset names or button function labels are invented.
