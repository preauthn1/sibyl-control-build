/// Offline codecs reconstructed from SIBYL MUSIC 1.26 static sources.
/// No transport, scans, scheduling, OTA or reset operations live here.
/// Numbers describe wire ranges, not a product's supported UI configuration.
library;

import 'dart:typed_data';

int _range(int value, int min, int max, String name) {
  if (value < min || value > max) {
    throw RangeError.range(value, min, max, name);
  }
  return value;
}

int _u8(int value, String name) => _range(value, 0, 255, name);
int _u16(int value, String name) => _range(value, 0, 65535, name);

Uint8List _bytes(List<int> values) {
  for (final value in values) {
    _u8(value, 'byte');
  }
  return Uint8List.fromList(values);
}

void _require(bool condition, String message) {
  if (!condition) throw FormatException(message);
}

/// Immutable frame payload: accessors return defensive copies.
class BleFrame {
  final int sequence;
  final int command;
  final Uint8List _payload;
  BleFrame(this.sequence, this.command, List<int> payload)
    : _payload = _bytes(payload) {
    _u8(sequence, 'sequence');
    _u8(command, 'command');
    _range(payload.length, 0, 254, 'payload.length');
  }
  Uint8List get payload => Uint8List.fromList(_payload);
  bool get isQueueAck => command == 0xfe;
}

class BleCodec {
  static const serviceUuid = '000000FE-0000-1000-8000-00805f9b34fb';
  static const writeUuid = '000000F1-0000-1000-8000-00805f9b34fb';
  static const notifyUuid = '000000F2-0000-1000-8000-00805f9b34fb';

  static Uint8List encode(BleFrame frame) => _bytes([
    0xff,
    frame.sequence,
    frame._payload.length + 1,
    frame.command,
    ...frame._payload,
    0xaa,
  ]);

  /// Exactly one complete frame. Rejects trailing bytes and truncation.
  static BleFrame decode(List<int> data) {
    final bytes = _bytes(data);
    _require(bytes.length >= 5, 'BLE frame shorter than 5 bytes');
    _require(bytes[0] == 0xff, 'BLE sync must be FF');
    _require(bytes[2] >= 1, 'BLE content length must include command');
    _require(bytes.length == bytes[2] + 4, 'BLE length mismatch');
    _require(bytes.last == 0xaa, 'BLE trailer must be AA');
    return BleFrame(bytes[1], bytes[3], bytes.sublist(4, bytes.length - 1));
  }

  static BleFrame query(int sequence, List<int> attributes) {
    if (attributes.isEmpty)
      throw ArgumentError('At least one attribute required');
    return BleFrame(sequence, 0xfa, attributes);
  }

  static BleFrame gaming(int sequence, bool enabled) =>
      BleFrame(sequence, 0x0e, [enabled ? 1 : 0]);

  /// Mode and level must come from the actual panel, not list indices.
  /// APK also uses this ordinary frame for non-RTK QCC ANC; support is unknown.
  static BleFrame anc(int sequence, int mode, int level) =>
      BleFrame(sequence, 9, [_u8(mode, 'mode'), _u8(level, 'level')]);

  static BleFrame button(int sequence, int event, int function) =>
      BleFrame(sequence, 1, [_u8(event, 'event'), _u8(function, 'function')]);

  /// Explicit signed gains avoid silently wrapping out-of-range UI input.
  /// Null gains reproduce the APK's ten zero bytes; non-null length is preserved.
  static BleFrame eq(int sequence, int type, {List<int>? gains}) =>
      BleFrame(sequence, 2, [_u8(type, 'type'), ..._signedGainBytes(gains)]);
}

List<int> _signedGainBytes(List<int>? gains) => gains == null
    ? List<int>.filled(10, 0)
    : [for (final gain in gains) _range(gain, -128, 127, 'gain') & 0xff];

class QccFrame {
  final int group;

  /// Raw opcode, including its response high bit.
  final int opcode;
  final Uint8List _payload;
  QccFrame(this.group, this.opcode, [List<int> payload = const []])
    : _payload = _bytes(payload) {
    _u8(group, 'group');
    _u8(opcode, 'opcode');
  }
  Uint8List get payload => Uint8List.fromList(_payload);
  int get operation => opcode & 0x7f;
  bool get isQueueAck => (group & 1) != 0;
}

class QccCodec {
  /// QCC has no embedded packet length or trailer. Transport boundaries or an
  /// external opcode-length schema are essential; never split by 00 1D alone.
  static Uint8List encode(QccFrame frame) =>
      _bytes([0, 0x1d, frame.group, frame.opcode, ...frame._payload]);

  static QccFrame decode(List<int> data, {int? expectedPayloadLength}) {
    final bytes = _bytes(data);
    _require(bytes.length >= 4, 'QCC header shorter than 4 bytes');
    _require(bytes[0] == 0 && bytes[1] == 0x1d, 'QCC prefix must be 00 1D');
    if (expectedPayloadLength != null) {
      _range(expectedPayloadLength, 0, 65535, 'expectedPayloadLength');
      _require(
        bytes.length == 4 + expectedPayloadLength,
        'QCC length mismatch',
      );
    }
    return QccFrame(bytes[2], bytes[3], bytes.sublist(4));
  }

  static QccFrame queryBattery() => QccFrame(0, 0x32);
  static QccFrame queryGaming() => QccFrame(0, 0x52);
  static QccFrame queryFirmware() => QccFrame(0, 0x54);
  static QccFrame queryEq() => QccFrame(0x0a, 2);
  static QccFrame gaming(bool enabled) => QccFrame(0, 0x53, [enabled ? 1 : 0]);

  static QccFrame button(int event, int function) {
    const mapping = {
      1: [1, 1],
      2: [1, 2],
      3: [1, 3],
      5: [1, 4],
      17: [2, 1],
      18: [2, 2],
      19: [2, 3],
      21: [2, 4],
    };
    final pair = mapping[event];
    if (pair == null)
      throw ArgumentError.value(event, 'event', 'Unknown QCC event');
    return QccFrame(0, 0x4b, [...pair, _u8(function, 'function'), 1]);
  }

  /// Returns one preset packet or two ordered custom packets. Never auto-sends.
  /// Custom gains are signed bytes, zero-padded to ten; excess is rejected,
  /// rather than silently discarded like the Android implementation.
  static List<QccFrame> eq(int type, {List<int>? gains}) {
    _u8(type, 'type');
    if (gains != null) {
      _range(gains.length, 0, 10, 'gains.length');
      _signedGainBytes(gains); // Validate even for a preset that ignores gains.
    }
    if (type < 128)
      return [
        QccFrame(0x0a, 3, [type]),
      ];
    final coefficients = ByteData(20);
    for (var i = 0; i < 10; i++) {
      final gain = gains != null && i < gains.length ? gains[i] : 0;
      coefficients.setInt16(i * 2, gain * 60, Endian.big);
    }
    return [
      QccFrame(0x0a, 3, [0x3f]),
      QccFrame(0x0a, 6, [0, 9, ...coefficients.buffer.asUint8List()]),
    ];
  }

  /// Decode the exact 20-byte coefficient block produced by [eq].
  /// Does NOT treat the differently structured opcode05 response as this block.
  static List<int> decodeGainBlock(List<int> coefficients) {
    final bytes = _bytes(coefficients);
    _require(bytes.length == 20, 'QCC gain block must contain 20 bytes');
    final data = ByteData.sublistView(bytes);
    return [
      for (var i = 0; i < 10; i++)
        _decodeGain(data.getInt16(i * 2, Endian.big)),
    ];
  }

  static int _decodeGain(int scaled) {
    _require(scaled % 60 == 0, 'QCC coefficient is not an integer gain * 60');
    return _range(scaled ~/ 60, -128, 127, 'gain');
  }
}

class RtkFrame {
  final int sequence;
  final int opcode;
  final Uint8List _params;
  RtkFrame(this.sequence, this.opcode, [List<int> params = const []])
    : _params = _bytes(params) {
    _u8(sequence, 'sequence');
    _u16(opcode, 'opcode');
    _range(params.length, 0, 65533, 'params.length');
  }
  Uint8List get params => Uint8List.fromList(_params);
}

class RtkCodec {
  static const preferredSppUuid = '6A24EEAB-4B65-4693-986B-3C26C352264F';
  static const fallbackSppUuid = '00001101-0000-1000-8000-00805F9B34FB';

  static Uint8List encode(RtkFrame frame) {
    final bytes = Uint8List(frame._params.length + 6);
    bytes[0] = 0xaa;
    bytes[1] = frame.sequence;
    final data = ByteData.sublistView(bytes);
    data.setUint16(2, frame._params.length + 2, Endian.little);
    data.setUint16(4, frame.opcode, Endian.little);
    bytes.setRange(6, bytes.length, frame._params);
    return bytes;
  }

  static RtkFrame decode(List<int> data) {
    final bytes = _bytes(data);
    _require(bytes.length >= 6, 'RTK frame shorter than 6 bytes');
    _require(bytes[0] == 0xaa, 'RTK sync must be AA');
    final view = ByteData.sublistView(bytes);
    final length = view.getUint16(2, Endian.little);
    _require(length >= 2 && bytes.length == length + 4, 'RTK length mismatch');
    return RtkFrame(
      bytes[1],
      view.getUint16(4, Endian.little),
      bytes.sublist(6),
    );
  }

  /// Use only after capability discovery confirms the modern report path.
  /// Mode/group are wire values, not ordinary ANC IDs or panel level values.
  static RtkFrame listeningMode(int sequence, int mode, {required int group}) {
    if (mode != 0 && mode != 1 && mode != 2 && mode != 3) {
      throw ArgumentError.value(mode, 'mode', 'Expected 0, 1, 2 or 3');
    }
    _u8(group, 'group');
    if ((mode == 0 || mode == 1) && group != 0) {
      throw ArgumentError('Off/non-LLAPT mode requires group 0');
    }
    return RtkFrame(sequence, 0x0c3b, [mode, group]);
  }

  static RtkFrame legacyAnc(int sequence, bool enabled, {required int group}) =>
      RtkFrame(sequence, 0x0c21, [enabled ? 1 : 0, _u8(group, 'group')]);
  static RtkFrame legacyLlApt(
    int sequence,
    bool enabled, {
    required int group,
  }) => RtkFrame(sequence, 0x0c23, [enabled ? 1 : 0, _u8(group, 'group')]);

  /// A non-idempotent toggle, deliberately not a bool setter.
  static RtkFrame toggleGaming(int sequence) =>
      RtkFrame(sequence, 4, [0, 0x80]);
  static RtkFrame queryGaming(int sequence) => RtkFrame(sequence, 0x0e01);

  /// Caller must know whether direct bud-info requests are supported.
  static RtkFrame queryBudInfo(int sequence) => RtkFrame(sequence, 0x21);
  static RtkFrame queryLegacyBattery(int sequence) =>
      RtkFrame(sequence, 0x18, [2]);
  // RTK battery RESPONSE layout is not established by the recovered notes.
}

/// Caller-owned sequence generator. RTK commands and ACKs must share one
/// instance; retransmits must reuse the original encoded packet.
class ProtocolSequence {
  final bool rtk;
  int _next;
  ProtocolSequence({this.rtk = false, int? initial})
    : _next = initial ?? (rtk ? 1 : 0) {
    _range(_next, rtk ? 1 : 0, 255, 'initial');
  }
  int take() {
    final result = _next;
    _next = _next == 255 ? (rtk ? 1 : 0) : _next + 1;
    return result;
  }
}

typedef QccPayloadLength = int? Function(int group, int rawOpcode);

/// Streaming parser with bounded retained state, fragmentation and coalescing.
/// Invalid candidates resync one byte at a time, never by a marker in payload.
/// A plausible but incomplete length cannot be distinguished from corruption:
/// call reset() on a transport deadline/disconnect. No speculative inner-header
/// skipping, which could otherwise corrupt valid fragmented binary payloads.
class PacketStreamParser<T> {
  final List<int> _buffer = [];
  final int maxFrameLength;
  final int Function(List<int>) _length;
  final T Function(List<int>) _decode;
  int discardedBytes = 0;

  PacketStreamParser._(this.maxFrameLength, this._length, this._decode);
  int get bufferedBytes => _buffer.length;
  void reset() => _buffer.clear();

  List<T> add(List<int> chunk) {
    // Validate before changing parser state; Uint8List.fromList alone wraps.
    final checked = _bytes(chunk);
    final result = <T>[];
    for (final byte in checked) {
      _buffer.add(byte);
      while (_buffer.isNotEmpty) {
        final length = _length(_buffer); // 0 = need header, -1 = invalid.
        if (length < 0 || length > maxFrameLength) {
          _buffer.removeAt(0);
          discardedBytes++;
          continue;
        }
        if (length == 0 || _buffer.length < length) break;
        final candidate = _buffer.sublist(0, length);
        try {
          result.add(_decode(candidate));
          _buffer.removeRange(0, length);
        } on FormatException {
          _buffer.removeAt(0);
          discardedBytes++;
        }
      }
    }
    return result;
  }
}

class BleStreamParser extends PacketStreamParser<BleFrame> {
  BleStreamParser({int maxFrameLength = 259})
    : super._(_range(maxFrameLength, 5, 259, 'maxFrameLength'), (b) {
        if (b[0] != 0xff) return -1;
        if (b.length < 3) return 0;
        return b[2] < 1 ? -1 : b[2] + 4;
      }, BleCodec.decode);
}

class RtkStreamParser extends PacketStreamParser<RtkFrame> {
  RtkStreamParser({int maxFrameLength = 65539})
    : super._(_range(maxFrameLength, 6, 65539, 'maxFrameLength'), (b) {
        if (b[0] != 0xaa) return -1;
        if (b.length < 4) return 0;
        final length = b[2] | (b[3] << 8);
        return length < 2 ? -1 : length + 4;
      }, RtkCodec.decode);
}

class QccStreamParser extends PacketStreamParser<QccFrame> {
  /// A schema for the relevant direction is mandatory because QCC is lengthless.
  /// Return null to reject unknown opcodes, not to guess a frame boundary.
  QccStreamParser({
    required QccPayloadLength payloadLength,
    int maxFrameLength = 4096,
  }) : super._(_range(maxFrameLength, 4, 65539, 'maxFrameLength'), (b) {
         if (b[0] != 0) return -1;
         if (b.length < 2) return 0;
         if (b[1] != 0x1d) return -1;
         if (b.length < 4) return 0;
         final length = payloadLength(b[2], b[3]);
         if (length == null) return -1;
         _range(length, 0, 65535, 'resolved payload length');
         return length + 4;
       }, (b) => QccCodec.decode(b));
}

class BatteryCell {
  final int percent;
  final bool charging;
  BatteryCell(this.percent, this.charging) {
    _range(percent, 0, 100, 'percent');
  }
  static BatteryCell decode(int raw) {
    _u8(raw, 'battery');
    return BatteryCell(raw & 0x7f, (raw & 0x80) != 0);
  }
}

class BatteryStatus {
  final BatteryCell left;
  final BatteryCell right;
  final BatteryCell caseBattery;
  BatteryStatus(this.left, this.right, this.caseBattery);
  static BatteryStatus _decode(List<int> data) {
    _require(
      data.length == 3,
      'Battery requires exactly left/right/case bytes',
    );
    return BatteryStatus(
      BatteryCell.decode(data[0]),
      BatteryCell.decode(data[1]),
      BatteryCell.decode(data[2]),
    );
  }

  static BatteryStatus? fromBle(BleFrame frame) =>
      frame.command == 0x0c ? _decode(frame._payload) : null;
  static BatteryStatus? fromQcc(QccFrame frame) =>
      frame.operation == 0x32 ? _decode(frame._payload) : null;
}

enum ProtocolFamily { ordinaryBle, qccBle, rtkSpp }

class AdvertisedDevice {
  static const manufacturerId = 0xc912;
  final int modelId;
  final ProtocolFamily family;
  final Uint8List _data;
  AdvertisedDevice._(this.modelId, this.family, this._data);

  /// Manufacturer payload excluding the company ID. Never infer by name.
  static AdvertisedDevice? fromManufacturerData(
    int companyId,
    List<int> payload,
  ) {
    _u16(companyId, 'companyId');
    final data = _bytes(payload);
    if (companyId != manufacturerId) return null;
    _require(
      data.length >= 12,
      'C912 manufacturer payload shorter than 12 bytes',
    );
    final model = (data[0] << 8) | data[1];
    final family = model == 0x3821
        ? ProtocolFamily.qccBle
        : model == 0x3e71
        ? ProtocolFamily.rtkSpp
        : ProtocolFamily.ordinaryBle;
    return AdvertisedDevice._(model, family, data);
  }

  /// A complete type-FF AD value includes the company ID in little-endian.
  static AdvertisedDevice? fromManufacturerAdValue(List<int> value) {
    final bytes = _bytes(value);
    _require(bytes.length >= 2, 'Manufacturer AD value lacks company ID');
    return fromManufacturerData(bytes[0] | (bytes[1] << 8), bytes.sublist(2));
  }

  Uint8List get payload => Uint8List.fromList(_data);
  Uint8List get rawBatteryBytes => Uint8List.fromList(_data.sublist(2, 5));
  bool get popupRequested => (_data[5] & 0x20) != 0;
  String get advertisedClassicAddress => _address(_data.sublist(6, 12));
  String? get otherAddress =>
      _data.length >= 18 ? _address(_data.sublist(12, 18)) : null;
  // Classic address is NOT the independently discovered GATT peripheral address.
  static String _address(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');
}
