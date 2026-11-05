// Development-only preview harness. It renders the real UI against a stub
// view model so layouts can be reviewed without hardware. Every snapshot it
// publishes sets preview: true, so the running app states on screen that the
// data is not from a Bluetooth device. It is never wired into main.dart.
//
//   flutter run -t tool/ui_preview.dart -d linux
//   flutter build linux -t tool/ui_preview.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sibyl_control/ui/earbud_app.dart';

void main() => runApp(EarbudApp(model: PreviewModel()));

class PreviewModel implements EarbudViewModel {
  PreviewModel() {
    state.value = _build();
  }

  final ValueNotifier<UiSnapshot> state = ValueNotifier(const UiSnapshot());

  @override
  ValueListenable<UiSnapshot> get snapshot => state;

  bool connected = true;
  bool configured = true;
  bool scanning = false;
  int ancModeId = 2;
  int ancLevel = 3;
  bool game = false;
  List<int> gains = const [2, 1, 0, -1, -2, -1, 0, 1, 2, 1];
  int? preset = 11;
  int promptVolume = 2;
  int powerOff = 30;
  final Map<int, bool> toggles = {77: true, 79: false, 81: true};
  final Map<int, int> buttons = {1: 101, 2: 203};
  String pairName = 'SIBYL S1';
  final List<UiLogEntry> logs = [
    const UiLogEntry(time: '17:20:41', message: '连接已建立；尚未证明控制兼容性'),
    const UiLogEntry(time: '17:20:42', message: 'TX 0xFF 06 … 查询电量'),
    const UiLogEntry(time: '17:20:42', message: 'RX 电量 左 86 右 84 仓 未上报'),
    const UiLogEntry(
      time: '17:20:43',
      message: '产品配置已载入：modelId 16017',
      level: 'WARN',
    ),
  ];

  UiSnapshot _build() => UiSnapshot(
    preview: true,
    devices: connected
        ? const []
        : const [
            UiDevice(
              id: 'AA:BB:CC:11:22:33',
              name: 'SIBYL S1',
              detail: '型号 0x3e71',
              rssi: -52,
            ),
            UiDevice(
              id: 'AA:BB:CC:44:55:66',
              name: 'Unknown earbuds',
              detail: '未识别型号，需手动选择协议',
              rssi: -78,
            ),
          ],
    scanning: scanning,
    scanAvailable: true,
    connection: connected ? UiConnection.connected : UiConnection.disconnected,
    deviceName: connected ? 'SIBYL S1' : null,
    deviceId: connected ? 'AA:BB:CC:11:22:33' : null,
    statusDetail: connected ? '硬件互操作尚未验证；只在你点击后连接或发指令' : null,
    leftBattery: connected ? 86 : null,
    rightBattery: connected ? 84 : null,
    caseBattery: null,
    protocols: const [
      UiProtocol(id: 'ordinary', label: '普通 BLE', detail: 'FE/F1/F2 · FF 帧'),
      UiProtocol(id: 'qcc', label: 'QCC BLE', detail: '00 1D · 自定义 EQ'),
      UiProtocol(id: 'rtk', label: 'RTK SPP', detail: '经典蓝牙 RFCOMM'),
    ],
    protocolId: 'ordinary',
    configurationReady: configured,
    configurationNote: configured
        ? '配置型号 16017；仅开放原厂配置和已确认协议支持的功能。'
        : '连接后点击“从设备读取”，按型号载入支持功能。',
    ancSupported: configured,
    ancModes: configured
        ? const [
            UiAncMode(id: 1, label: '关闭', defaultLevel: 0, allowedLevels: [0]),
            UiAncMode(
              id: 2,
              label: '降噪',
              defaultLevel: 1,
              allowedLevels: [1, 2, 3],
            ),
            UiAncMode(
              id: 3,
              label: '通透',
              defaultLevel: 1,
              allowedLevels: [1, 2],
            ),
          ]
        : const [],
    ancModeId: connected ? ancModeId : null,
    ancLevel: connected ? ancLevel : null,
    gameSupported: configured,
    gameEnabled: connected ? game : null,
    eqSupported: configured,
    eqConfig: configured
        ? const UiEqConfig(
            bandLabels: [
              '32',
              '64',
              '125',
              '250',
              '500',
              '1k',
              '2k',
              '4k',
              '8k',
              '16k',
            ],
            minGain: -8,
            maxGain: 8,
          )
        : null,
    eqGains: connected ? gains : null,
    eqPresets: configured
        ? const [
            UiEqPreset(id: 10, label: '原声'),
            UiEqPreset(id: 11, label: '低音增强'),
            UiEqPreset(id: 12, label: '人声'),
          ]
        : const [],
    eqPresetId: connected ? preset : null,
    booleanAttributes: configured
        ? [
            UiBooleanAttribute(id: 77, label: '入耳检测', value: toggles[77]),
            UiBooleanAttribute(id: 79, label: '触控锁定', value: toggles[79]),
            UiBooleanAttribute(id: 81, label: '低音增强', value: toggles[81]),
          ]
        : const [],
    buttonEvents: configured
        ? [
            UiButtonEvent(
              eventId: 1,
              label: '左耳 · 双击',
              currentFunctionId: buttons[1],
              functions: const [
                UiButtonFunction(id: 101, label: '上一曲'),
                UiButtonFunction(id: 102, label: '下一曲'),
                UiButtonFunction(id: 103, label: '播放 / 暂停'),
              ],
            ),
            UiButtonEvent(
              eventId: 2,
              label: '右耳 · 长按',
              currentFunctionId: buttons[2],
              functions: const [
                UiButtonFunction(id: 201, label: '切换降噪'),
                UiButtonFunction(id: 202, label: '语音助手'),
                UiButtonFunction(id: 203, label: '音量 +'),
              ],
            ),
          ]
        : const [],
    pairNameSupported: configured,
    pairName: connected ? pairName : null,
    promptVolumeSupported: configured,
    promptVolume: connected ? promptVolume : null,
    promptVolumeOptions: const [
      UiIntegerOption(value: 1, label: '低'),
      UiIntegerOption(value: 2, label: '中'),
      UiIntegerOption(value: 3, label: '高'),
    ],
    powerOffSupported: configured,
    powerOffMinutes: connected ? powerOff : null,
    powerOffOptions: const [
      UiIntegerOption(value: 0, label: '不关机'),
      UiIntegerOption(value: 15, label: '15 分钟'),
      UiIntegerOption(value: 30, label: '30 分钟'),
    ],
    logs: List.unmodifiable(logs),
  );

  void _publish() => state.value = _build();

  @override
  Future<void> startScan() async {
    scanning = true;
    _publish();
  }

  @override
  Future<void> stopScan() async {
    scanning = false;
    _publish();
  }

  @override
  Future<void> connect(String deviceId) async {
    connected = true;
    _publish();
  }

  @override
  Future<void> connectAddress(String address, {int? rfcommChannel}) async {
    connected = true;
    _publish();
  }

  @override
  Future<void> disconnect() async {
    connected = false;
    _publish();
  }

  @override
  Future<void> selectProtocol(String protocolId) async => _publish();

  @override
  Future<void> loadProductConfiguration() async {
    configured = true;
    _publish();
  }

  @override
  Future<void> importConfiguration(String json) async {
    configured = true;
    _publish();
  }

  @override
  Future<void> refreshStatus() async => _publish();

  @override
  Future<void> setAnc(int modeId, int level) async {
    ancModeId = modeId;
    ancLevel = level;
    _publish();
  }

  @override
  Future<void> setGameEnabled(bool enabled) async {
    game = enabled;
    _publish();
  }

  @override
  Future<void> setEqualizer(List<int> values) async {
    gains = List<int>.unmodifiable(values);
    preset = null;
    _publish();
  }

  @override
  Future<void> selectEqPreset(int presetId) async {
    preset = presetId;
    _publish();
  }

  @override
  Future<void> setBooleanAttribute(int attributeId, bool value) async {
    toggles[attributeId] = value;
    _publish();
  }

  @override
  Future<void> setButtonMapping(int eventId, int functionId) async {
    buttons[eventId] = functionId;
    _publish();
  }

  @override
  Future<void> setPairName(String name) async {
    pairName = name;
    _publish();
  }

  @override
  Future<void> setPromptVolume(int volume) async {
    promptVolume = volume;
    _publish();
  }

  @override
  Future<void> setPowerOffMinutes(int minutes) async {
    powerOff = minutes;
    _publish();
  }

  @override
  Future<void> clearLogs() async {
    logs.clear();
    _publish();
  }
}
