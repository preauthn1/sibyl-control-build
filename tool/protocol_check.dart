// Run manually: dart tool/protocol_check.dart
// Synthetic offline fixtures derived from documented static formulas; not captures.
// No package:test, Flutter, network, hardware, scan, or device writes.
import '../lib/protocol/protocol.dart';

int _checks = 0;
void check(bool condition, String description) {
  _checks++;
  if (!condition) throw StateError('Check failed: $description');
}

void bytesEqual(List<int> actual, List<int> expected, String description) {
  check(
    actual.length == expected.length &&
        List.generate(
          actual.length,
          (i) => actual[i] == expected[i],
        ).every((v) => v),
    '$description: got $actual, expected $expected',
  );
}

void rejects(void Function() action, String description) {
  var rejected = false;
  try {
    action();
  } on FormatException {
    rejected = true;
  } on ArgumentError {
    rejected = true;
  }
  check(rejected, description);
}

void main() {
  final ble = BleCodec.encode(BleCodec.gaming(7, true));
  bytesEqual(ble, [0xff, 7, 2, 0x0e, 1, 0xaa], 'ordinary gaming vector');
  final decoded = BleCodec.decode(ble);
  check(
    decoded.sequence == 7 && decoded.command == 14,
    'ordinary decode header',
  );
  bytesEqual(decoded.payload, [1], 'ordinary decode payload');
  bytesEqual(BleCodec.encode(BleCodec.query(0, [12])), [
    255,
    0,
    2,
    250,
    12,
    170,
  ], 'ordinary battery query');
  bytesEqual(BleCodec.encode(BleCodec.anc(2, 3, 9)), [
    255,
    2,
    3,
    9,
    3,
    9,
    170,
  ], 'panel ANC IDs remain literal');
  bytesEqual(BleCodec.button(1, 21, 199).payload, [
    21,
    199,
  ], 'panel button IDs');
  bytesEqual(BleCodec.eq(0, 255, gains: [-128, -1, 0, 127]).payload, [
    255,
    128,
    255,
    0,
    127,
  ], 'ordinary signed gain encoding');
  check(BleCodec.eq(0, 0).payload.length == 11, 'ordinary null EQ zero-fill');
  final defensive = decoded.payload;
  defensive[0] = 99;
  check(decoded.payload[0] == 1, 'payload is defensive copy');

  for (var split = 0; split <= ble.length; split++) {
    final parser = BleStreamParser();
    final frames = [
      ...parser.add(ble.sublist(0, split)),
      ...parser.add(ble.sublist(split)),
    ];
    check(
      frames.length == 1 && parser.bufferedBytes == 0,
      'ordinary fragmentation split $split',
    );
  }
  final bleParser = BleStreamParser();
  check(
    bleParser.add([9, 8, ...ble, ...ble]).length == 2,
    'ordinary noise + coalesced frames',
  );
  check(bleParser.discardedBytes == 2, 'ordinary noise accounting');
  check(
    bleParser.add([255, 1, 0, ...ble]).length == 1,
    'ordinary zero length resync',
  );
  check(
    bleParser.add([255, 1, 1, 9, 0, ...ble]).length == 1,
    'ordinary bad trailer resync',
  );
  final embeddedMarker = BleCodec.encode(BleFrame(0, 2, [255, 1, 1, 2, 170]));
  check(
    bleParser.add(embeddedMarker).single.payload.length == 5,
    'ordinary embedded sync is data',
  );
  bleParser.add([255, 2, 200]);
  check(bleParser.bufferedBytes == 3, 'plausible incomplete BLE retained');
  bleParser.reset();
  check(bleParser.bufferedBytes == 0, 'transport timeout can reset BLE');
  final cappedBle = BleStreamParser(maxFrameLength: 10);
  check(
    cappedBle.add([255, 1, 250, ...ble]).length == 1,
    'application BLE cap rejects absurd length',
  );

  rejects(() => BleCodec.decode([255, 0, 0, 170]), 'short BLE');
  rejects(() => BleCodec.decode([...ble, 0]), 'BLE trailing garbage');
  rejects(() => BleCodec.decode([255, 1, 1, 2, 0]), 'BLE bad trailer');
  rejects(() => BleFrame(256, 1, []), 'sequence cannot wrap silently');
  rejects(() => BleFrame(0, -1, []), 'negative command rejected');
  rejects(() => BleFrame(0, 1, List.filled(255, 0)), 'BLE oversized payload');
  rejects(() => BleFrame(0, 1, [256]), 'byte cannot truncate silently');
  rejects(() => BleCodec.query(0, []), 'empty query rejected');
  rejects(() => BleCodec.anc(0, 1, -1), 'ANC negative level rejected');
  rejects(() => BleCodec.eq(0, 255, gains: [128]), 'gain signed bounds');
  rejects(() => bleParser.add([256]), 'stream invalid byte rejected');
  check(bleParser.bufferedBytes == 0, 'invalid chunk is atomic');

  final maximumBle = BleCodec.encode(
    BleFrame(255, 255, List.filled(254, 0xaa)),
  );
  check(
    maximumBle.length == 259 &&
        BleStreamParser().add(maximumBle).single.payload.length == 254,
    'BLE max wire length',
  );

  bytesEqual(QccCodec.encode(QccCodec.queryBattery()), [
    0,
    29,
    0,
    50,
  ], 'QCC query');
  bytesEqual(QccCodec.encode(QccCodec.gaming(false)), [
    0,
    29,
    0,
    83,
    0,
  ], 'QCC gaming');
  bytesEqual(QccCodec.encode(QccCodec.button(21, 7)), [
    0,
    29,
    0,
    75,
    2,
    4,
    7,
    1,
  ], 'QCC event-side mapping');
  rejects(() => QccCodec.button(4, 0), 'unknown QCC button is not remapped');
  bytesEqual(QccCodec.encode(QccCodec.eq(127).single), [
    0,
    29,
    10,
    3,
    127,
  ], 'QCC preset');
  final custom = QccCodec.eq(255, gains: [-128, -1, 0, 1, 127]);
  check(custom.length == 2, 'custom EQ is ordered two-packet operation');
  bytesEqual(QccCodec.encode(custom.first), [
    0,
    29,
    10,
    3,
    63,
  ], 'custom slot63');
  bytesEqual(QccCodec.encode(custom.last), [
    0, 29, 10, 6, 0, 9,
    0xe2, 0x00, // -128 * 60 = -7680, signed BE
    0xff, 0xc4, // -1 * 60 = -60
    0, 0, 0, 0x3c, 0x1d, 0xc4, // 0, +1, +127
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  ], 'QCC signed gain *60 big-endian boundary vector');
  bytesEqual(QccCodec.decodeGainBlock(custom.last.payload.sublist(2)), [
    -128,
    -1,
    0,
    1,
    127,
    0,
    0,
    0,
    0,
    0,
  ], 'QCC gain round-trip');
  rejects(
    () => QccCodec.eq(255, gains: List.filled(11, 0)),
    'excess bands rejected',
  );
  rejects(() => QccCodec.eq(255, gains: [-129]), 'QCC signed gain lower bound');
  rejects(() => QccCodec.eq(256), 'EQ type range');
  rejects(() => QccCodec.decode([0, 28, 0, 50]), 'QCC wrong prefix');
  rejects(() => QccCodec.decode([0, 29, 0]), 'QCC truncated header');
  rejects(
    () => QccCodec.decode([0, 29, 0, 50], expectedPayloadLength: 3),
    'QCC exact payload length validation',
  );
  rejects(
    () => QccCodec.decodeGainBlock(List.filled(19, 0)),
    'gain block length',
  );
  rejects(
    () => QccCodec.decodeGainBlock([0, 1, ...List.filled(18, 0)]),
    'non-integral scaled gain rejected',
  );
  final response = [0, 29, 1, 0xb2, 0x80 | 50, 99, 100];
  final qccDecoded = QccCodec.decode(response, expectedPayloadLength: 3);
  check(
    qccDecoded.isQueueAck && qccDecoded.operation == 50,
    'QCC ACK/opcode bits',
  );
  // Only this known battery-response shape is registered. Unknown opcodes
  // cannot be framed safely in a lengthless protocol and are discarded.
  QccStreamParser qccParser() => QccStreamParser(
    payloadLength: (group, opcode) =>
        group == 1 && (opcode & 0x7f) == 0x32 ? 3 : null,
  );
  for (var split = 0; split <= response.length; split++) {
    final parser = qccParser();
    final frames = [
      ...parser.add(response.sublist(0, split)),
      ...parser.add(response.sublist(split)),
    ];
    check(
      frames.length == 1 && parser.bufferedBytes == 0,
      'QCC fragmentation split $split',
    );
  }
  check(
    qccParser().add([7, 0, 29, 0, 0x7f, ...response, ...response]).length == 2,
    'QCC unknown schema + noise + coalescing',
  );
  final embeddedQcc = QccStreamParser(
    payloadLength: (g, op) => op == 6 ? 4 : null,
  );
  check(
    embeddedQcc.add([0, 29, 10, 6, 0, 29, 10, 6]).length == 1,
    'QCC prefix in payload is not a delimiter',
  );

  final rtk = RtkCodec.encode(RtkCodec.listeningMode(1, 2, group: 7));
  bytesEqual(rtk, [170, 1, 4, 0, 59, 12, 2, 7], 'RTK new ANC');
  bytesEqual(RtkCodec.encode(RtkCodec.toggleGaming(255)), [
    170,
    255,
    4,
    0,
    4,
    0,
    0,
    128,
  ], 'RTK gaming is toggle');
  bytesEqual(RtkCodec.encode(RtkCodec.queryGaming(1)), [
    170,
    1,
    2,
    0,
    1,
    14,
  ], 'RTK gaming query');
  bytesEqual(RtkCodec.encode(RtkCodec.queryBudInfo(1)), [
    170,
    1,
    2,
    0,
    33,
    0,
  ], 'RTK direct bud-info query');
  bytesEqual(RtkCodec.encode(RtkCodec.queryLegacyBattery(1)), [
    170,
    1,
    3,
    0,
    24,
    0,
    2,
  ], 'RTK legacy battery query');
  final rtkDecoded = RtkCodec.decode(rtk);
  check(
    rtkDecoded.sequence == 1 && rtkDecoded.opcode == 0x0c3b,
    'RTK LE decode',
  );
  bytesEqual(rtkDecoded.params, [2, 7], 'RTK params');
  for (var split = 0; split <= rtk.length; split++) {
    final parser = RtkStreamParser();
    final frames = [
      ...parser.add(rtk.sublist(0, split)),
      ...parser.add(rtk.sublist(split)),
    ];
    check(
      frames.length == 1 && parser.bufferedBytes == 0,
      'RTK fragmentation split $split',
    );
  }
  final rtkParser = RtkStreamParser(maxFrameLength: 100);
  check(
    rtkParser.add([8, 170, 0, 1, 0, ...rtk, ...rtk]).length == 2,
    'RTK invalid short length + coalescing',
  );
  check(
    rtkParser.add([170, 1, 255, 255, ...rtk]).length == 1,
    'RTK configured cap rejects oversized candidate',
  );
  final markerRtk = RtkCodec.encode(RtkFrame(3, 0xffff, [170, 1, 2, 0]));
  check(
    rtkParser.add(markerRtk).single.params.length == 4,
    'RTK inner sync is data',
  );
  rejects(() => RtkCodec.decode([...rtk, 170]), 'RTK has no trailer');
  rejects(
    () => RtkCodec.decode([170, 1, 1, 0, 0, 0]),
    'RTK length excludes opcode',
  );
  rejects(() => RtkFrame(0, 65536), 'opcode uint16 bound');
  rejects(() => RtkFrame(0, 1, List.filled(65534, 0)), 'RTK max params bound');
  rejects(() => RtkCodec.listeningMode(0, 4, group: 0), 'unknown RTK mode');
  rejects(() => RtkCodec.listeningMode(0, 0, group: 1), 'RTK off fixed group');
  final longRtk = RtkCodec.encode(RtkFrame(1, 0x1234, List.filled(254, 0)));
  bytesEqual(longRtk.sublist(2, 6), [0, 1, 0x34, 0x12], 'RTK 16-bit LE length');
  check(
    RtkStreamParser().add(longRtk).single.params.length == 254,
    'RTK length above one byte',
  );

  final battery = BatteryStatus.fromBle(BleFrame(0, 12, [178, 99, 100]))!;
  check(
    battery.left.percent == 50 &&
        battery.left.charging &&
        battery.right.percent == 99 &&
        !battery.right.charging &&
        battery.caseBattery.percent == 100,
    'ordinary battery order/charging',
  );
  check(
    BatteryStatus.fromQcc(qccDecoded)!.left.percent == 50,
    'QCC battery response',
  );
  check(
    BatteryStatus.fromBle(BleFrame(0, 9, [])) == null,
    'unrelated ordinary opcode is not battery',
  );
  rejects(
    () => BatteryStatus.fromBle(BleFrame(0, 12, [50, 50])),
    'truncated battery',
  );
  rejects(
    () => BatteryStatus.fromBle(BleFrame(0, 12, [127, 50, 50])),
    'unknown battery sentinel is not invented as a percentage',
  );

  final manufacturerPayload = [
    0x38,
    0x21,
    50,
    60,
    70,
    0x20,
    1,
    2,
    3,
    4,
    5,
    6,
    10,
    11,
    12,
    13,
    14,
    15,
  ];
  final adv = AdvertisedDevice.fromManufacturerData(
    0xc912,
    manufacturerPayload,
  )!;
  check(
    adv.family == ProtocolFamily.qccBle && adv.modelId == 0x3821,
    'company/model are distinct fields',
  );
  check(
    adv.advertisedClassicAddress == '01:02:03:04:05:06' &&
        adv.otherAddress == '0A:0B:0C:0D:0E:0F' &&
        adv.popupRequested,
    'advertised addresses/popup',
  );
  bytesEqual(adv.rawBatteryBytes, [50, 60, 70], 'raw advertisement batteries');
  check(
    AdvertisedDevice.fromManufacturerAdValue([
          0x12,
          0xc9,
          ...manufacturerPayload,
        ])!.family ==
        ProtocolFamily.qccBle,
    'AD company LE vs model BE',
  );
  check(
    AdvertisedDevice.fromManufacturerData(0xc912, [
          0x3e,
          0x71,
          ...manufacturerPayload.sublist(2),
        ])!.family ==
        ProtocolFamily.rtkSpp,
    'RTK model',
  );
  check(
    AdvertisedDevice.fromManufacturerData(0xc912, [
          0,
          1,
          ...manufacturerPayload.sublist(2, 12),
        ])!.family ==
        ProtocolFamily.ordinaryBle,
    'other model ordinary code-path fallback, not compatibility promise',
  );
  check(
    AdvertisedDevice.fromManufacturerData(0x1234, []) == null,
    'other company ignored',
  );
  rejects(
    () => AdvertisedDevice.fromManufacturerData(0xc912, List.filled(11, 0)),
    'manufacturer minimum payload',
  );
  rejects(
    () => AdvertisedDevice.fromManufacturerAdValue([0x12]),
    'missing company byte',
  );

  final ordinarySeq = ProtocolSequence(initial: 255);
  check(
    ordinarySeq.take() == 255 && ordinarySeq.take() == 0,
    'ordinary seq rollover',
  );
  final rtkSeq = ProtocolSequence(rtk: true, initial: 255);
  check(rtkSeq.take() == 255 && rtkSeq.take() == 1, 'RTK seq excludes zero');
  rejects(
    () => ProtocolSequence(rtk: true, initial: 0),
    'RTK outgoing seq starts nonzero',
  );
  print('PASS: $_checks offline protocol checks (synthetic fixtures only).');
}
