// UI data contract shared by the controller and every page.
// Moved out of earbud_app.dart unchanged so the view layer can be split
// into pages without touching the controller's import or any field name.
import 'package:flutter/foundation.dart';

// Pure UI contract. The controller owns discovery, transport, acknowledgements,
// capability/config validation, and ALL reported device state. No optimistic
// connection/control state is synthesized here. Dispose the model in its owner.
enum UiConnection { disconnected, connecting, connected, disconnecting }

@immutable
class UiDevice {
  const UiDevice({
    required this.id,
    required this.name,
    this.detail,
    this.rssi,
  });
  final String id;
  final String name;
  final String? detail;
  final int? rssi;
}

@immutable
class UiProtocol {
  const UiProtocol({
    required this.id,
    required this.label,
    required this.detail,
  });
  final String id;
  final String label;
  final String detail;
}

@immutable
class UiAncMode {
  const UiAncMode({
    required this.id,
    required this.label,
    required this.defaultLevel,
    required this.allowedLevels,
  });
  // Product panel modes[].cmdid, NEVER a list index.
  final int id;
  final String label;
  final int defaultLevel;
  // Exact product-configured values, not an inferred min/max range.
  final List<int> allowedLevels;
}

@immutable
class UiEqConfig {
  const UiEqConfig({
    required this.bandLabels,
    required this.minGain,
    required this.maxGain,
    this.unit = '协议增益',
  });
  // Must contain exactly ten labels derived from product configuration.
  // Do not invent frequencies or assume protocol gain units are dB.
  final List<String> bandLabels;
  final int minGain;
  final int maxGain;
  final String unit;
  bool get valid =>
      bandLabels.length == 10 &&
      minGain < maxGain &&
      minGain >= -128 &&
      maxGain <= 127;
}

// These IDs and choices MUST come from the selected product configuration.
// Null state means unknown, never a product default or a confirmed write.
@immutable
class UiBooleanAttribute {
  const UiBooleanAttribute({required this.id, required this.label, this.value});
  final int id;
  final String label;
  final bool? value;
}

@immutable
class UiEqPreset {
  const UiEqPreset({required this.id, required this.label});
  final int id;
  final String label;
}

@immutable
class UiButtonFunction {
  const UiButtonFunction({required this.id, required this.label});
  final int id;
  final String label;
}

@immutable
class UiButtonEvent {
  UiButtonEvent({
    required this.eventId,
    required this.label,
    required List<UiButtonFunction> functions,
    this.currentFunctionId,
  }) : functions = List.unmodifiable(functions);
  // Panel BtnSideInfo.eventID and FuncItem.cmd, not indices or universal enums.
  final int eventId;
  final String label;
  final List<UiButtonFunction> functions;
  final int? currentFunctionId;
}

@immutable
class UiIntegerOption {
  const UiIntegerOption({required this.value, required this.label});
  final int value;
  final String label;
}

@immutable
class UiLogEntry {
  const UiLogEntry({
    required this.time,
    required this.message,
    this.level = 'INFO',
  });
  final String time;
  final String message;
  final String level;
}

@immutable
class UiSnapshot {
  const UiSnapshot({
    this.devices = const [],
    this.scanning = false,
    this.scanAvailable = false,
    this.connection = UiConnection.disconnected,
    this.deviceName,
    this.deviceId,
    this.statusDetail,
    this.leftBattery,
    this.rightBattery,
    this.caseBattery,
    this.protocols = const [],
    this.protocolId,
    this.configurationReady = false,
    this.configurationNote = '尚未载入产品配置；控制保持禁用。',
    this.hardwareVerified = false,
    this.ancSupported = false,
    this.ancModes = const [],
    this.ancModeId,
    this.ancLevel,
    this.gameSupported = false,
    this.gameEnabled,
    this.eqSupported = false,
    this.eqConfig,
    this.eqGains,
    this.booleanAttributes = const [],
    this.eqPresets = const [],
    this.eqPresetId,
    this.buttonEvents = const [],
    this.pairNameSupported = false,
    this.pairName,
    this.promptVolumeSupported = false,
    this.promptVolume,
    this.promptVolumeOptions = const [],
    this.powerOffSupported = false,
    this.powerOffMinutes,
    this.powerOffOptions = const [],
    this.busy = false,
    this.logs = const [],
    this.preview = false,
  });
  final List<UiDevice> devices;
  final bool scanning;
  final bool scanAvailable;
  final UiConnection connection;
  final String? deviceName;
  final String? deviceId;
  final String? statusDetail;
  // Null means unknown. Out-of-range values are also shown as unknown.
  final int? leftBattery;
  final int? rightBattery;
  final int? caseBattery;
  final List<UiProtocol> protocols;
  final String? protocolId;
  final bool configurationReady;
  final String configurationNote;
  final bool hardwareVerified;
  final bool ancSupported;
  final List<UiAncMode> ancModes;
  final int? ancModeId;
  final int? ancLevel;
  final bool gameSupported;
  final bool? gameEnabled;
  final bool eqSupported;
  final UiEqConfig? eqConfig;
  // Reported values only; null is not silently replaced with a flat EQ.
  final List<int>? eqGains;
  final List<UiBooleanAttribute> booleanAttributes;
  final List<UiEqPreset> eqPresets;
  final int? eqPresetId;
  final List<UiButtonEvent> buttonEvents;
  final bool pairNameSupported;
  final String? pairName;
  final bool promptVolumeSupported;
  final int? promptVolume;
  // Exact configured choices; empty means no writable values known.
  final List<UiIntegerOption> promptVolumeOptions;
  final bool powerOffSupported;
  final int? powerOffMinutes;
  final List<UiIntegerOption> powerOffOptions;
  final bool busy;
  final List<UiLogEntry> logs;
  // A preview adapter MUST set this true for every snapshot.
  final bool preview;
}

/// Implement using a ChangeNotifier or ValueNotifier-backed controller.
/// All methods must revalidate connection, capabilities, protocol and bounds at
/// dispatch time. Resolve a Future after enqueue/operation as appropriate, and
/// report actual confirmations separately through [snapshot]. No OTA/reset API.
abstract class EarbudViewModel {
  ValueListenable<UiSnapshot> get snapshot;
  Future<void> startScan();
  Future<void> stopScan();
  Future<void> connect(String deviceId);
  Future<void> disconnect();
  Future<void> selectProtocol(String protocolId);
  Future<void> loadProductConfiguration();
  Future<void> refreshStatus();
  Future<void> setBooleanAttribute(int attributeId, bool value);
  Future<void> setPromptVolume(int volume);
  Future<void> setPowerOffMinutes(int minutes);
  Future<void> setPairName(String name);
  Future<void> setButtonMapping(int eventId, int functionId);
  Future<void> selectEqPreset(int presetId);
  Future<void> setAnc(int modeId, int level);
  // RTK adapters must query first and conditionally toggle; never blind-retry.
  Future<void> setGameEnabled(bool enabled);
  // Exactly ten signed integer gains. The adapter owns wire encoding/custom ID.
  Future<void> setEqualizer(List<int> gains);
  Future<void> clearLogs();
  Future<void> importConfiguration(String json);
  Future<void> connectAddress(String address, {int? rfcommChannel});
}
