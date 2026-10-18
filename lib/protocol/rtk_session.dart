/// Static-only RTK helpers; no transport, Flutter dependency or auto-send.
///
/// Controller integration:
/// 1. Parse the product's explicit `rtk` map with RtkCapabilities.fromJson.
///    Missing capability values are errors, NOT a legacy/modern heuristic.
/// 2. Keep one RtkSession and one ProtocolSequence(rtk: true) per connection.
/// 3. Feed RtkStreamParser frames to session.accept(frame). Catch FormatException
///    and log/drop malformed events. Inspect state.lastAck separately from state
///    reports: ACK success does not prove the requested setting was applied.
/// 4. For each non-ACK event, caller may send RtkCodec.encode(
///    RtkCommands.ack(sharedSequence.take(), frame.opcode)). ACKs and commands
///    share the sequence generator. Never ACK an ACK or re-toggle on retry.
/// 5. Encode session.listeningMode(seq, appMode), session.eqPreset(seq, id), or
///    RtkCodec.toggleGaming(seq); enqueue/send with the controller's own policy.
///    Modern listening query: RtkCommands.queryListeningMode(seq).
/// 6. Only publish state updates after receiving reports; never optimistically
///    set gaming/ANC/EQ from an ACK. Reset/discard session on disconnect.
///
/// JSON example (illustrative, NOT a product capability assertion):
/// {"listeningModeReportSupported":true,"ancSupported":true,
///  "aptFeatureType":2,"ancGroup":0,"aptGroup":0,
///  "eqSpecVersion":4,"eqPresetIds":[0,1],"budInfoReqSupported":true}
/// appMode is SIBYL ANCBean ID: 1=ANC, 2=off, 3=APT. It is not a
/// wire-mode, group number, or UI level. Resolve IDs from the loaded config.
/// Legacy off/APT additionally require explicit, current legacyState; unknown
/// state throws rather than blindly sending a non-idempotent DSP APT toggle.
/// Caller must refresh that state after each operation (this helper does not
/// guess legacy flags from modern reports or infer them from successful ACKs).
///
/// CONFIRMED means recovered static source, never hardware interoperability.
/// Evidence root: sibyl-bluetooth/static_recovered/.
/// - ACK: rtk_details/AckPacket.java:24-41 (opcode 0000, params idLE/status).
/// - Gaming: VendorBase_c.java:832-840 and rtk_details/LowLatencyInfo.java:19-35.
///   Request 0E01 responds via event 0E00, NOT 0E01 (ear detection).
/// - Listening: VendorBase_c.java:590-615; 0C3B is operation result, while
///   0C3C carries mode/group (rtk_details/ListeningModeStatus.java:15-19).
/// - ANC branch: VendorModelClient.java:203-227,249-262,452-499.
/// - EQ call: RTKDeviceClient.java:373-375, Builder(0,0,index).
///   EqModelClient.java:520-521 supplies getEqSpecVersion(), NOT cmd-set
///   version. Configuration must preserve that distinction.
///   SetEqEntryIndexReq.encode: type0/version<1 => 0208 indexLE16;
///   version1..3 => 0205 index8 (mode1 rejected); version>=4 => 0205 index8/mode8;
///   type1 => 020B index8. All selectors are caller supplied, not guessed.
/// - Battery: VendorBase_c.java:659-666 event 0022 -> bbpro.i.a parser
///   -> DeviceStatusInfo.toRwsInfo -> RTKDeviceClient.java:294-301.
///   bbpro.i.a:29-60 reads [budType,activeBud,channels,left,right,case?].
///   DeviceStatusInfo.java:118-130 maps left/right/case without a charging bit.
///   These additional single-class sources were inspected under
///   /tmp/sibyl-rtk-helper/; sample was not executed.
/// - Legacy battery status has PRIMARY/SECONDARY bytes, not left/right;
///   DeviceStatusInfo0.toRwsInfo depends on chip/package/RWS metadata. No legacy
///   left/right/case decoder is invented here. Do NOT use BatteryStatus.fromBle
///   or BatteryCell.decode for RTK, or treat a missing case byte as 0%.
library;

import 'protocol.dart';

int _range(int value, int min, int max, String name) {
  if (value < min || value > max) {
    throw RangeError.range(value, min, max, name);
  }
  return value;
}

void _need(List<int> p, int min, String name) {
  if (p.length < min) throw FormatException('$name requires >= $min bytes');
}

/// Only values explicitly obtained from configuration/capability discovery.
/// No model-name, model-ID or successful-connection inference.
class RtkCapabilities {
  final bool listeningModeReportSupported;
  final bool ancSupported;
  /// SDK feature type: 0=none, 1=DSP APT, 2=LLAPT.
  final int aptFeatureType;
  final int ancGroup;
  final int aptGroup;
  /// Null means EQ version is unknown and EQ writes remain unavailable.
  final int? eqSpecVersion;
  /// Null means the product's supported presets are not configured.
  final Set<int>? eqPresetIds;
  /// Null means unknown: direct bud query must not be assumed supported.
  final bool? budInfoReqSupported;

  RtkCapabilities({
    required this.listeningModeReportSupported,
    required this.ancSupported,
    required this.aptFeatureType,
    required this.ancGroup,
    required this.aptGroup,
    this.eqSpecVersion,
    Iterable<int>? eqPresetIds,
    this.budInfoReqSupported,
  }) : eqPresetIds = eqPresetIds == null ? null : Set.unmodifiable(eqPresetIds) {
    _range(aptFeatureType, 0, 2, 'aptFeatureType');
    _range(ancGroup, 0, 255, 'ancGroup');
    _range(aptGroup, 0, 255, 'aptGroup');
    if (eqSpecVersion != null) {
      _range(eqSpecVersion!, 0, 65535, 'eqSpecVersion');
    }
    for (final id in this.eqPresetIds ?? <int>{}) {
      _range(id, 0, eqSpecVersion == 0 ? 65535 : 255, 'eqPresetId');
    }
  }

  factory RtkCapabilities.fromJson(Map<String, dynamic> json) {
    T requiredValue<T>(String key) {
      final value = json[key];
      if (value is! T) throw FormatException('rtk.$key must be $T');
      return value;
    }
    final version = json['eqSpecVersion'];
    final ids = json['eqPresetIds'];
    final bud = json['budInfoReqSupported'];
    if (version != null && version is! int) {
      throw const FormatException('rtk.eqSpecVersion must be an integer');
    }
    if (bud != null && bud is! bool) {
      throw const FormatException('rtk.budInfoReqSupported must be a boolean');
    }
    if (ids != null && (ids is! List || ids.any((id) => id is! int))) {
      throw const FormatException('rtk.eqPresetIds must be an integer list');
    }
    return RtkCapabilities(
      listeningModeReportSupported: requiredValue<bool>('listeningModeReportSupported'),
      ancSupported: requiredValue<bool>('ancSupported'),
      aptFeatureType: requiredValue<int>('aptFeatureType'),
      ancGroup: requiredValue<int>('ancGroup'),
      aptGroup: requiredValue<int>('aptGroup'),
      eqSpecVersion: version as int?,
      eqPresetIds: ids == null ? null : (ids as List).cast<int>(),
      budInfoReqSupported: bud as bool?,
    );
  }

  bool get eqPresetSupported => eqSpecVersion != null &&
      eqPresetIds != null && eqPresetIds!.isNotEmpty;
}

class RtkAck {
  final int opcode;
  final int status;
  const RtkAck(this.opcode, this.status);
  bool get succeeded => status == 0;
}

class RtkGamingReport {
  final bool enabled;
  /// Absent optional fields remain null, not the SDK's artificial zero/-1.
  final int? latency;
  final int? maxLevel;
  final int? currentLevel;
  const RtkGamingReport(this.enabled, this.latency, this.maxLevel, this.currentLevel);
}

class RtkListeningReport {
  final int mode;
  final int group;
  const RtkListeningReport(this.mode, this.group);
  /// Preserve unknown wire modes; don't relabel them as off.
  int? get appMode => switch (mode) { 0 => 2, 1 || 3 => 3, 2 => 1, _ => null };
}

/// Explicit current SDK-equivalent legacy state; ACKs do not populate this.
class RtkLegacyListeningState {
  final bool ancEnabled;
  final bool aptEnabled;
  const RtkLegacyListeningState({required this.ancEnabled, required this.aptEnabled});
}

/// Direct bud-info event only. Keep raw bytes; unknown/sentinel/out-of-range
/// values have null percentages. No RTK charging-bit interpretation is proven.
class RtkBatteryReport {
  final int budType;
  final int activeBud;
  final int channels;
  final int leftRaw;
  final int rightRaw;
  final int? caseRaw;
  const RtkBatteryReport(this.budType, this.activeBud, this.channels,
      this.leftRaw, this.rightRaw, this.caseRaw);
  bool get caseSupported => caseRaw != null && caseRaw != 255;
  int? get leftPercent => _percent(leftRaw);
  int? get rightPercent => _percent(rightRaw);
  int? get casePercent => caseSupported ? _percent(caseRaw) : null;
  static int? _percent(int? raw) => raw != null && raw <= 100 && raw >= 0 ? raw : null;
}

/// One decoded event, or unknown (all fields null). Malformed known events throw
/// before any state changes. No EQ report layout is inferred from its request.
class RtkUpdate {
  final RtkFrame frame;
  final RtkAck? ack;
  final RtkGamingReport? gaming;
  final RtkListeningReport? listening;
  final RtkBatteryReport? battery;
  /// Raw 0C3B operation result; not a listening-mode report or transport ACK.
  final int? listeningResult;
  const RtkUpdate._(this.frame, {this.ack, this.gaming, this.listening,
      this.battery, this.listeningResult});
  bool get recognized => ack != null || gaming != null || listening != null ||
      battery != null || listeningResult != null;
  bool get needsAck => frame.opcode != 0;
}

class RtkDecoder {
  static RtkUpdate decode(RtkFrame frame) {
    final p = frame.params;
    switch (frame.opcode) {
      case 0:
        _need(p, 3, 'RTK ACK'); // SDK's <2 guard still accesses index2: fix guard.
        return RtkUpdate._(frame, ack: RtkAck(p[0] | (p[1] << 8), p[2]));
      case 0x0e00:
        _need(p, 1, 'RTK gaming report');
        return RtkUpdate._(frame, gaming: RtkGamingReport(
          p[0] == 1, p.length >= 3 ? p[1] | (p[2] << 8) : null,
          p.length >= 5 ? p[3] : null, p.length >= 5 ? p[4] : null));
      case 0x0c3c:
        _need(p, 2, 'RTK listening report');
        return RtkUpdate._(frame, listening: RtkListeningReport(p[0], p[1]));
      case 0x0c3b:
        _need(p, 1, 'RTK listening operation result');
        return RtkUpdate._(frame, listeningResult: p[0]);
      case 0x0022:
        _need(p, 5, 'RTK direct bud-info report');
        return RtkUpdate._(frame, battery: RtkBatteryReport(
          p[0], p[1], p[2], p[3], p[4], p.length >= 6 ? p[5] : null));
      default:
        return RtkUpdate._(frame);
    }
  }
}

/// Immutable observed state. Null = not observed on this connection.
class RtkState {
  final RtkAck? lastAck;
  final RtkGamingReport? gamingReport;
  final RtkListeningReport? listeningReport;
  final RtkBatteryReport? battery;
  final int? lastListeningResult;
  const RtkState({this.lastAck, this.gamingReport, this.listeningReport,
      this.battery, this.lastListeningResult});
  bool? get gaming => gamingReport?.enabled;
  int? get ancId => listeningReport?.appMode;
  int? get leftBattery => battery?.leftPercent;
  int? get rightBattery => battery?.rightPercent;
  int? get caseBattery => battery?.casePercent;
  RtkState apply(RtkUpdate update) => RtkState(
    lastAck: update.ack ?? lastAck,
    gamingReport: update.gaming ?? gamingReport,
    listeningReport: update.listening ?? listeningReport,
    battery: update.battery ?? battery,
    lastListeningResult: update.listeningResult ?? lastListeningResult,
  );
}

class RtkCommands {
  static RtkFrame ack(int sequence, int eventOpcode, {int status = 0}) {
    _range(eventOpcode, 1, 65535, 'eventOpcode');
    _range(status, 0, 255, 'status');
    return RtkFrame(sequence, 0, [eventOpcode & 255, eventOpcode >> 8, status]);
  }

  static RtkFrame queryListeningMode(int sequence) => RtkFrame(sequence, 0x0c3c);

  /// Exact SetEqEntryIndexReq.encode branches, with rejected truncation rather
  /// than Java's silent index/mode wrapping. Does not advertise product support.
  static RtkFrame setEqEntryIndex(int sequence, {
    required int eqSpecVersion, required int eqType, required int eqMode,
    required int index,
  }) {
    _range(eqSpecVersion, 0, 65535, 'eqSpecVersion');
    _range(eqType, 0, 1, 'eqType');
    _range(eqMode, 0, 255, 'eqMode');
    _range(index, 0, eqType == 0 && eqSpecVersion == 0 ? 65535 : 255, 'index');
    if (eqType == 1) return RtkFrame(sequence, 0x020b, [index]);
    if (eqSpecVersion >= 4) return RtkFrame(sequence, 0x0205, [index, eqMode]);
    if (eqSpecVersion == 0) return RtkFrame(sequence, 0x0208, [index & 255, index >> 8]);
    if (eqMode == 1) throw StateError('SDK disallows gaming EQ index for eqSpecVersion 1..3');
    return RtkFrame(sequence, 0x0205, [index]);
  }

  /// Reproduces VendorModelClient.setListeningMode, including the legacy
  /// APT-first off branch. Null means already in requested legacy state;
  /// it does NOT authorize suppressing any future query or optimistic update.
  static RtkFrame? listeningMode(int sequence, int appMode, {
    required RtkCapabilities capabilities,
    RtkLegacyListeningState? legacyState,
  }) {
    if (appMode != 1 && appMode != 2 && appMode != 3) {
      throw ArgumentError.value(appMode, 'appMode', 'Expected ANC=1/off=2/APT=3');
    }
    final c = capabilities;
    if (appMode == 1 && !c.ancSupported) throw StateError('ANC not configured');
    if (appMode == 3 && c.aptFeatureType == 0) throw StateError('APT not configured');
    if (c.listeningModeReportSupported) {
      final mode = appMode == 1 ? 2 : appMode == 2 ? 0 : c.aptFeatureType == 2 ? 3 : 1;
      final group = mode == 2 ? c.ancGroup : mode == 3 ? c.aptGroup : 0;
      return RtkCodec.listeningMode(sequence, mode, group: group);
    }
    if (appMode == 1) return RtkCodec.legacyAnc(sequence, true, group: c.ancGroup);
    if (legacyState == null) throw StateError('Legacy off/APT requires current ANC/APT state');
    if (appMode == 2) {
      if (legacyState.aptEnabled) {
        if (c.aptFeatureType == 0) throw StateError('APT state conflicts with configured capabilities');
        return c.aptFeatureType == 2
            ? RtkCodec.legacyLlApt(sequence, false, group: 0)
            : RtkFrame(sequence, 4, [0, 0x65]);
      }
      return legacyState.ancEnabled ? RtkCodec.legacyAnc(sequence, false, group: 0) : null;
    }
    if (legacyState.aptEnabled) return null;
    return c.aptFeatureType == 2
        ? RtkCodec.legacyLlApt(sequence, true, group: c.aptGroup)
        : RtkFrame(sequence, 4, [0, 0x65]);
  }
}

class RtkSession {
  final RtkCapabilities capabilities;
  RtkState _state = const RtkState();
  RtkSession({required this.capabilities});
  RtkState get state => _state;
  RtkUpdate accept(RtkFrame frame) {
    final update = RtkDecoder.decode(frame);
    _state = _state.apply(update);
    return update;
  }
  void reset() => _state = const RtkState();
  RtkFrame? listeningMode(int sequence, int appMode, {
    RtkLegacyListeningState? legacyState,
  }) => RtkCommands.listeningMode(sequence, appMode,
      capabilities: capabilities, legacyState: legacyState);

  /// Only configured IDs, normal audio EQ type0/mode0, matching the APP caller.
  RtkFrame eqPreset(int sequence, int index) {
    if (!capabilities.eqPresetSupported || !capabilities.eqPresetIds!.contains(index)) {
      throw StateError('EQ version/preset not explicitly configured');
    }
    return RtkCommands.setEqEntryIndex(sequence,
      eqSpecVersion: capabilities.eqSpecVersion!, eqType: 0, eqMode: 0, index: index);
  }

  /// Only direct bud-info is exposed here. Legacy battery needs the SDK's
  /// ordered role/side/state/status task; a lone query is not equivalent.
  RtkFrame queryBudInfo(int sequence) {
    if (capabilities.budInfoReqSupported != true) {
      throw StateError('Direct bud-info support not explicitly configured');
    }
    return RtkCodec.queryBudInfo(sequence);
  }
}
