// Opt-in, standalone offline checks for the parent agent to run if permitted.
// NOT executed during this static-only implementation. All bytes below are
// synthetic, source-derived vectors, NOT captured hardware responses.
// No Flutter imports, sockets, BLE, sample execution, builders or test packages.
import '../lib/protocol/protocol.dart';
import '../lib/protocol/rtk_session.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

void bytes(List<int> actual, List<int> expected, String message) {
  check(actual.length == expected.length, '$message: length');
  for (var i = 0; i < expected.length; i++) {
    check(actual[i] == expected[i], '$message: byte $i');
  }
}

void rejects(void Function() action, String message) {
  try {
    action();
  } on FormatException {
    return;
  } on ArgumentError {
    return;
  } on StateError {
    return;
  }
  throw StateError('$message: expected rejection');
}

RtkCapabilities config({bool modern = true, int apt = 2, int? version = 4}) =>
    RtkCapabilities(
      listeningModeReportSupported: modern,
      ancSupported: true,
      aptFeatureType: apt,
      ancGroup: 7,
      aptGroup: 9,
      eqSpecVersion: version,
      eqPresetIds: [0, 1],
      budInfoReqSupported: true,
    );

void main() {
  final session = RtkSession(capabilities: config());
  check(session.state.gaming == null && session.state.ancId == null &&
      session.state.leftBattery == null, 'initial state unknown');
  final ack = session.accept(RtkFrame(1, 0, [4, 0, 0]));
  check(ack.ack!.succeeded && ack.ack!.opcode == 4 && !ack.needsAck,
      'transport ACK decode');
  check(session.state.gaming == null, 'ACK is not gaming confirmation');
  check(!session.accept(RtkFrame(2, 0, [4, 0, 4])).ack!.succeeded,
      'BUSY is not success');
  rejects(() => session.accept(RtkFrame(3, 0, [4, 0])), 'short ACK');
  check(session.state.lastAck!.status == 4, 'malformed ACK is atomic');
  bytes(RtkCodec.encode(RtkCommands.ack(1, 0x0e00)),
      [0xaa, 1, 5, 0, 0, 0, 0, 0x0e, 0], 'outgoing event ACK');
  rejects(() => RtkCommands.ack(1, 0), 'do not ACK ACK');

  session.accept(RtkFrame(4, 0x0e00, [1, 0x34, 0x12, 4, 2]));
  check(session.state.gaming == true &&
      session.state.gamingReport!.latency == 0x1234 &&
      session.state.gamingReport!.maxLevel == 4 &&
      session.state.gamingReport!.currentLevel == 2, 'gaming report');
  check(!session.accept(RtkFrame(5, 0x0e01, [0])).recognized &&
      session.state.gaming == true, '0E01 is not gaming report');
  session.accept(RtkFrame(6, 0x0e00, [0]));
  check(session.state.gaming == false &&
      session.state.gamingReport!.latency == null, 'optional latency absent');
  rejects(() => session.accept(RtkFrame(7, 0x0e00)), 'empty gaming');

  session.accept(RtkFrame(8, 0x0c3c, [2, 7]));
  check(session.state.ancId == 1 && session.state.listeningReport!.group == 7,
      'ANC report');
  session.accept(RtkFrame(9, 0x0c3b, [0]));
  check(session.state.ancId == 1 && session.state.lastListeningResult == 0,
      'listening operation result not state');
  for (final entry in {0: 2, 1: 3, 2: 1, 3: 3}.entries) {
    session.accept(RtkFrame(10, 0x0c3c, [entry.key, 0]));
    check(session.state.ancId == entry.value, 'listening app mapping');
  }
  session.accept(RtkFrame(11, 0x0c3c, [0x7f, 0]));
  check(session.state.ancId == null, 'unknown listening mode not off');
  rejects(() => session.accept(RtkFrame(12, 0x0c3c, [2])), 'short listening');

  session.accept(RtkFrame(13, 0x22, [1, 1, 0x12, 80, 70, 60]));
  check(session.state.leftBattery == 80 && session.state.rightBattery == 70 &&
      session.state.caseBattery == 60, 'direct bud-info battery');
  session.accept(RtkFrame(14, 0x22, [1, 2, 0x21, 80, 70]));
  check(session.state.caseBattery == null && !session.state.battery!.caseSupported,
      'absent case is not zero');
  session.accept(RtkFrame(15, 0x22, [1, 1, 0x12, 0xff, 0x80, 0xff]));
  check(session.state.leftBattery == null && session.state.rightBattery == null &&
      session.state.caseBattery == null, 'no invented charging-bit mask');
  check(!session.accept(RtkFrame(16, 0x19, [2, 80, 70])).recognized,
      'legacy primary/secondary not relabelled left/right');
  rejects(() => session.accept(RtkFrame(17, 0x22, [1, 1, 0, 80])), 'short battery');

  bytes(RtkCodec.encode(session.listeningMode(1, 1)!),
      [0xaa, 1, 4, 0, 0x3b, 0x0c, 2, 7], 'modern ANC configured group');
  bytes(session.listeningMode(1, 3)!.params, [3, 9], 'modern LLAPT');
  bytes(session.listeningMode(1, 2)!.params, [0, 0], 'modern off');
  bytes(RtkCommands.listeningMode(1, 3, capabilities: config(apt: 1))!.params,
      [1, 0], 'modern DSP APT');
  check(RtkCommands.queryListeningMode(1).opcode == 0x0c3c, 'query listening');
  final legacy = RtkSession(capabilities: config(modern: false));
  final both = RtkLegacyListeningState(ancEnabled: true, aptEnabled: true);
  check(legacy.listeningMode(1, 2, legacyState: both)!.opcode == 0x0c23,
      'legacy off prioritizes APT');
  bytes(legacy.listeningMode(1, 2, legacyState: both)!.params,
      [0, 0], 'legacy LLAPT off');
  final ancOnly = RtkLegacyListeningState(ancEnabled: true, aptEnabled: false);
  check(legacy.listeningMode(1, 2, legacyState: ancOnly)!.opcode == 0x0c21,
      'legacy ANC off');
  final off = RtkLegacyListeningState(ancEnabled: false, aptEnabled: false);
  check(legacy.listeningMode(1, 2, legacyState: off) == null, 'legacy off no-op');
  rejects(() => legacy.listeningMode(1, 3), 'legacy needs current state');
  bytes(RtkCommands.listeningMode(1, 3,
      capabilities: config(modern: false, apt: 1), legacyState: off)!.params,
      [0, 0x65], 'legacy DSP APT toggle');
  rejects(() => RtkCapabilities.fromJson({}), 'no guessed ANC capabilities');
  rejects(() => RtkCapabilities.fromJson({
    'listeningModeReportSupported': 1,
  }), 'capability boolean must be literal boolean');
  rejects(() => session.listeningMode(1, 0), 'no app/wire mode confusion');

  bytes(RtkCodec.encode(session.eqPreset(1, 1)),
      [0xaa, 1, 4, 0, 5, 2, 1, 0], 'EQ version4 type0/mode0');
  bytes(RtkCodec.encode(RtkSession(capabilities: config(version: 2)).eqPreset(1, 1)),
      [0xaa, 1, 3, 0, 5, 2, 1], 'EQ version1..3');
  bytes(RtkCodec.encode(RtkCommands.setEqEntryIndex(1,
      eqSpecVersion: 0, eqType: 0, eqMode: 0, index: 0x1234)),
      [0xaa, 1, 4, 0, 8, 2, 0x34, 0x12], 'EQ legacy index16');
  check(RtkCommands.setEqEntryIndex(1, eqSpecVersion: 4,
      eqType: 1, eqMode: 0, index: 1).opcode == 0x020b, 'EQ type1');
  rejects(() => RtkCommands.setEqEntryIndex(1, eqSpecVersion: 2,
      eqType: 0, eqMode: 1, index: 1), 'unsupported gaming EQ');
  rejects(() => RtkCommands.setEqEntryIndex(1, eqSpecVersion: 4,
      eqType: 0, eqMode: 0, index: 256), 'no silent index truncation');
  rejects(() => session.eqPreset(1, 2), 'unconfigured preset');
  rejects(() => RtkSession(capabilities: config(version: null)).eqPreset(1, 1),
      'unknown EQ version stays gated');
  check(session.queryBudInfo(1).opcode == 0x21, 'explicit bud query');

  final stream = RtkStreamParser();
  final frameBytes = RtkCodec.encode(RtkFrame(1, 0x0e00, [1]));
  check(stream.add(frameBytes.sublist(0, 3)).isEmpty, 'fragment header');
  final frames = stream.add([...frameBytes.sublist(3), ...frameBytes]);
  check(frames.length == 2 && frames.every((f) => f.opcode == 0x0e00),
      'fragmented/coalesced stream');
  final sequence = ProtocolSequence(rtk: true, initial: 255);
  check(sequence.take() == 255 && sequence.take() == 1, 'shared sequence wrap');
  session.reset();
  check(session.state.gaming == null && session.state.lastAck == null &&
      session.state.battery == null, 'disconnect reset');
  print('RTK source-derived offline checks passed; no hardware claim.');
}
