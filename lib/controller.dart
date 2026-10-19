import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_ble/universal_ble.dart';
import 'config/product_config.dart';
import 'protocol/protocol.dart';
import 'protocol/rtk_session.dart';
import 'transport/ble_transport.dart';
import 'transport/rfcomm_transport.dart';
import 'ui/earbud_app.dart';

class EarbudController implements EarbudViewModel {
  final ValueNotifier<UiSnapshot> state = ValueNotifier(const UiSnapshot());
  @override
  ValueListenable<UiSnapshot> get snapshot => state;
  final ble = BleTransport();
  final rfcomm = RfcommTransport();
  final Map<String, BleDevice> devices = {};
  final Map<String, AdvertisedDevice> identities = {};
  final List<UiLogEntry> logs = [];
  final bleParser = BleStreamParser();
  final rtkParser = RtkStreamParser();
  String protocol = 'ordinary';
  int? _activeModelId;
  String? _productName;
  final Map<int, int> _attributes = {};
  final Map<int, int> _buttonFunctions = {};
  String? _pairName;
  int? _eqPresetId;
  String? _firmwareVersion;
  RtkSession? _rtkSession;
  void _configureRtk() {
    final r = config?['rtk'];
    _rtkSession = r is Map<String, dynamic>
        ? RtkSession(capabilities: RtkCapabilities.fromJson(r))
        : null;
  }

  UiConnection connection = UiConnection.disconnected;
  String? connectedId;
  bool scanning = false, busy = false;
  int sequence = 0;
  int? left, right, box, ancId, ancLevel;
  bool? gaming;
  List<int>? gains;
  Map<String, dynamic>? config;
  Future<void> _tail = Future.value();
  Completer<void>? _confirmation;
  int _epoch = 0;
  int? _pendingOpcode;
  int? _lastRtkReceive;
  bool _rtkReady = false;
  Timer? _scanTimer;
  EarbudController() {
    UniversalBle.onScanResult = _scanResult;
    ble.received.listen(_receive);
    rfcomm.received.listen(_receive);
    ble.errors.listen(_linkError);
    rfcomm.errors.listen(_linkError);
    _publish();
  }
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString('productConfiguration');
    if (text != null) {
      try {
        await importConfiguration(text);
      } catch (e) {
        _log('配置载入失败：$e');
      }
    }
  }

  void _log(String text) {
    final now = DateTime.now().toLocal().toIso8601String().substring(11, 19);
    logs.insert(0, UiLogEntry(time: now, message: text));
    if (logs.length > 160) logs.removeLast();
    _publish();
  }

  void _linkError(String error) {
    _log(error);
    unawaited(disconnect());
  }

  void _publish() {
    final modes = <UiAncMode>[];
    for (final raw in (config?['ancModes'] as List? ?? [])) {
      final m = raw as Map;
      modes.add(
        UiAncMode(
          id: m['id'] as int,
          label: m['label'] as String,
          defaultLevel: m['defaultLevel'] as int,
          allowedLevels: (m['levels'] as List).cast<int>(),
        ),
      );
    }
    final eq = config?['eq'] as Map?;
    state.value = UiSnapshot(
      devices: devices.values
          .map(
            (d) => UiDevice(
              id: d.deviceId,
              name: d.rawName ?? d.name ?? '未命名耳机',
              rssi: d.rssi,
              detail: identities[d.deviceId] == null
                  ? '未识别型号，需手动选择协议'
                  : '型号 0x${identities[d.deviceId]!.modelId.toRadixString(16)}',
            ),
          )
          .toList(),
      scanning: scanning,
      scanAvailable: true,
      connection: connection,
      deviceName: connectedId == null
          ? null
          : _productName ?? devices[connectedId]?.rawName ?? connectedId,
      deviceId: connectedId,
      statusDetail: '硬件互操作尚未验证；只在你点击后连接或发指令',
      leftBattery: left,
      rightBattery: right,
      caseBattery: box,
      protocols: const [
        UiProtocol(id: 'ordinary', label: '普通 BLE', detail: 'FE/F1/F2 · FF 帧'),
        UiProtocol(id: 'qcc', label: 'QCC BLE', detail: '00 1D · 自定义 EQ'),
        UiProtocol(id: 'rtk', label: 'RTK SPP', detail: '经典蓝牙 RFCOMM'),
      ],
      protocolId: protocol,
      configurationReady: config != null,
      configurationNote: config == null
          ? '连接后点击“读取产品配置”，按型号载入支持功能。'
          : '配置型号 ${config!['modelId']}；仅开放原厂配置和已确认协议支持的功能。',
      ancSupported:
          modes.isNotEmpty &&
          (protocol != 'rtk' ||
              _rtkSession?.capabilities.listeningModeReportSupported == true),
      ancModes: modes,
      ancModeId: ancId,
      ancLevel: ancLevel,
      gameSupported:
          config?['game'] == true && (protocol != 'rtk' || _rtkReady),
      gameEnabled: gaming,
      eqSupported: eq != null && protocol != 'rtk',
      eqConfig: eq == null
          ? null
          : UiEqConfig(
              bandLabels: (eq['labels'] as List).cast<String>(),
              minGain: eq['min'] as int,
              maxGain: eq['max'] as int,
            ),
      eqGains: gains,
      booleanAttributes: [
        for (final t in (config?['toggles'] as List? ?? []))
          if (protocol != 'rtk' &&
              (protocol != 'qcc' || [77, 79, 81].contains(t['id'])))
            UiBooleanAttribute(
              id: t['id'],
              label: t['label'],
              value: _attributes[t['id']] == null
                  ? null
                  : _attributes[t['id']] == 1,
            ),
      ],
      eqPresets: [
        for (final p in (config?['eqPresets'] as List? ?? []))
          UiEqPreset(id: p['id'], label: p['label']),
      ],
      eqPresetId: _eqPresetId,
      buttonEvents: [
        for (final b in (config?['buttons'] as List? ?? []))
          if (protocol != 'rtk')
            UiButtonEvent(
              eventId: b['eventId'],
              label: b['label'],
              functions: [
                for (final f in b['functions'])
                  UiButtonFunction(id: f['id'], label: f['label']),
              ],
              currentFunctionId: _buttonFunctions[b['eventId']],
            ),
      ],
      pairNameSupported: config?['rename'] == true && protocol != 'rtk',
      pairName: _pairName,
      promptVolumeSupported:
          config?['promptVolume'] != null && protocol == 'ordinary',
      promptVolume: _attributes[41],
      promptVolumeOptions: [
        for (final o in (config?['promptVolume']?['options'] as List? ?? []))
          UiIntegerOption(value: o['value'], label: o['label']),
      ],
      powerOffSupported: config?['powerOff'] != null && protocol == 'ordinary',
      powerOffMinutes: _attributes[32],
      powerOffOptions: [
        for (final o in (config?['powerOff']?['options'] as List? ?? []))
          UiIntegerOption(value: o['value'], label: o['label']),
      ],
      busy: busy,
      logs: List.unmodifiable(logs),
    );
  }

  Future<void> importConfiguration(String text) async {
    if (connection == UiConnection.connected && protocol == 'rtk')
      throw StateError('当前 RTK 配置读取中，请勿手动覆盖');
    if (connection == UiConnection.connecting ||
        connection == UiConnection.disconnecting)
      throw StateError('连接状态变化中，请稍后导入配置');
    final raw = jsonDecode(text);
    if (raw is! Map<String, dynamic>) throw FormatException('配置须为 JSON 对象');
    final model = raw['modelId'];
    if (model is! int || model < 0 || model > 65535)
      throw FormatException('modelId 应为 0..65535 整数');
    if (connection == UiConnection.connected &&
        _activeModelId != null &&
        model != _activeModelId)
      throw StateError('配置型号与已连接设备不符');
    final modes = raw['ancModes'] ?? [];
    if (modes is! List || modes.length > 32)
      throw FormatException('ancModes 格式错误');
    final ids = <int>{};
    for (final m in modes) {
      if (m is! Map ||
          m['id'] is! int ||
          m['id'] < 0 ||
          m['id'] > 255 ||
          !ids.add(m['id']) ||
          m['label'] is! String ||
          m['levels'] is! List ||
          (m['levels'] as List).isEmpty ||
          (m['levels'] as List).any((x) => x is! int || x < 0 || x > 255) ||
          !(m['levels'] as List).contains(m['defaultLevel']))
        throw FormatException('ANC 模式/档位无效');
    }
    final eq = raw['eq'];
    if (eq != null &&
        (eq is! Map ||
            eq['labels'] is! List ||
            eq['labels'].length != 10 ||
            (eq['labels'] as List).any((x) => x is! String) ||
            eq['min'] is! int ||
            eq['max'] is! int ||
            eq['min'] < -128 ||
            eq['max'] > 127 ||
            eq['min'] >= eq['max']))
      throw FormatException('EQ 需要10个频段标签和合法有符号增益范围');
    if (raw['game'] != null && raw['game'] is! bool)
      throw FormatException('game 须为布尔值');
    config = raw;
    _configureRtk();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('productConfiguration', jsonEncode(raw));
    _log('已保存产品配置，未向设备发送数据');
  }

  void _scanResult(BleDevice device) {
    AdvertisedDevice? identity;
    for (final m in device.manufacturerDataList) {
      try {
        identity = AdvertisedDevice.fromManufacturerData(
          m.companyId,
          m.payload,
        );
      } catch (_) {}
      if (identity != null) break;
    }
    if (identity == null && !device.services.contains(BleTransport.service))
      return;
    devices[device.deviceId] = device;
    if (identity != null) identities[device.deviceId] = identity;
    _publish();
  }

  @override
  Future<void> startScan() async {
    await UniversalBle.requestPermissions();
    await UniversalBle.startScan();
    scanning = true;
    _publish();
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(seconds: 15), () {
      if (scanning)
        unawaited(stopScan().catchError((Object e) => _log('停止扫描失败：$e')));
    });
  }

  @override
  Future<void> stopScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    if (scanning) await UniversalBle.stopScan();
    scanning = false;
    _publish();
  }

  @override
  Future<void> selectProtocol(String id) async {
    if (connection != UiConnection.disconnected) throw StateError('请先断开连接');
    if (!['ordinary', 'qcc', 'rtk'].contains(id)) throw ArgumentError('未知协议');
    protocol = id;
    _publish();
  }

  @override
  Future<void> connect(String deviceId) => connectAddress(deviceId);
  Future<void> connectAddress(String address, {int? rfcommChannel}) async {
    if (connection != UiConnection.disconnected) throw StateError('已有连接操作');
    final connectEpoch = ++_epoch;
    connection = UiConnection.connecting;
    connectedId = address;
    _publish();
    try {
      await stopScan();
    } catch (_) {
      if (connectEpoch == _epoch) {
        connection = UiConnection.disconnected;
        connectedId = null;
        _publish();
      }
      rethrow;
    }
    if (connectEpoch != _epoch) throw StateError('连接已取消');
    final identity = identities[address];
    _activeModelId = identity?.modelId ?? config?['modelId'] as int?;
    if (identity != null) {
      protocol = switch (identity.family) {
        ProtocolFamily.ordinaryBle => 'ordinary',
        ProtocolFamily.qccBle => 'qcc',
        ProtocolFamily.rtkSpp => 'rtk',
      };
      if (config != null && config!['modelId'] != identity.modelId) {
        await disconnect();
        throw StateError('产品配置与广播型号不符，请更换配置');
      }
    }
    try {
      await UniversalBle.requestPermissions();
      if (connectEpoch != _epoch) throw StateError('连接已取消');
      if (protocol == 'rtk') {
        await rfcomm.connect(
          identity?.advertisedClassicAddress ?? address,
          channel: rfcommChannel,
        );
      } else {
        await ble.connect(address);
      }
      if (connectEpoch != _epoch) {
        await ble.disconnect();
        await rfcomm.disconnect();
        throw StateError('连接已取消');
      }
      sequence = protocol == 'rtk' ? 1 : 0;
      connection = UiConnection.connected;
      _log('连接已建立；尚未证明控制兼容性');
      await refresh();
    } catch (e) {
      await disconnect();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _epoch++;
    if (_confirmation != null && !_confirmation!.isCompleted)
      _confirmation!.completeError(StateError('连接已取消'));
    _confirmation = null;
    _pendingOpcode = null;
    _rtkReady = false;
    _lastRtkReceive = null;
    bleParser.reset();
    rtkParser.reset();
    connection = UiConnection.disconnecting;
    _publish();
    await ble.disconnect();
    await rfcomm.disconnect();
    connectedId = null;
    left = right = box = ancId = ancLevel = null;
    gaming = null;
    gains = null;
    connection = UiConnection.disconnected;
    busy = false;
    _publish();
  }

  int _next() {
    final n = sequence;
    sequence = protocol == 'rtk' ? (sequence % 255) + 1 : (sequence + 1) & 255;
    return n;
  }

  Future<void> _send(Uint8List data, {bool confirm = true}) {
    final epoch = _epoch;
    final task = _tail.catchError((Object _) {}).then((_) async {
      if (epoch != _epoch || connection != UiConnection.connected)
        throw StateError('连接已变更');
      final pending = Completer<void>();
      // Attach a listener immediately: cancellation may arrive during write().
      unawaited(pending.future.catchError((Object _) {}));
      if (confirm) {
        _confirmation = pending;
        _pendingOpcode = protocol == 'rtk'
            ? data[4] | (data[5] << 8)
            : protocol == 'qcc'
            ? data[3] & 0x7f
            : data[3];
      }
      _log('TX ${_hex(data)}');
      try {
        if (protocol == 'rtk') {
          await rfcomm.write(data);
        } else {
          await ble.write(data);
        }
        if (confirm) await pending.future.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        // WS200-class devices execute commands and report via status pushes
        // (cmd=9 ANC etc.) but never send the 0xFE queue ack. The original
        // app's transport also just continued after its timeout (no retry,
        // no disconnect). Keep the link alive; state pushes remain the
        // source of truth for what the device actually did.
        _log('未收到应用层确认；设备可能已执行，以状态回报为准');
      } finally {
        if (identical(_confirmation, pending)) {
          _confirmation = null;
          _pendingOpcode = null;
        }
      }
    });
    _tail = task.catchError((Object _) {});
    return task;
  }

  Future<void> refresh() async {
    if (protocol == 'ordinary') {
      await _send(BleCodec.encode(BleCodec.query(_next(), [12, 9, 14, 2])));
    } else if (protocol == 'qcc') {
      await _send(QccCodec.encode(QccCodec.queryBattery()));
      await _send(QccCodec.encode(QccCodec.queryGaming()));
      await _send(QccCodec.encode(QccCodec.queryEq()));
    } else {
      await _send(RtkCodec.encode(RtkCodec.queryGaming(_next())));
      _log('RTK 游戏状态查询已发送；ANC/EQ 仍等待完整能力协商');
    }
  }

  @override
  Future<void> loadProductConfiguration() async {
    if (busy) throw StateError('操作中');
    final model = _activeModelId ?? config?['modelId'] as int?;
    if (model == null) throw StateError('未识别型号，请通过扫描连接设备以读取广播型号');
    final epoch = _epoch;
    busy = true;
    _publish();
    try {
      final loaded = await ProductConfigClient().loadProductConfiguration(
        model,
        firmwareVersion: _firmwareVersion ?? '0.0.0',
      );
      if (epoch != _epoch) throw StateError('设备已变更，丢弃配置');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('productConfiguration', jsonEncode(loaded));
      config = loaded;
      _configureRtk();
      _productName = loaded['productName'] as String?;
      _log('原厂产品配置已载入，支持的功能已开放');
      if (connection == UiConnection.connected) await refresh();
    } finally {
      busy = false;
      _publish();
    }
  }

  @override
  Future<void> refreshStatus() => refresh();

  Future<void> _queryAttribute(int id) async {
    if (protocol == 'qcc') {
      final ops = {
        1: 0x4a,
        2: 2,
        12: 0x32,
        13: 0x54,
        14: 0x52,
        39: 0x3d,
        77: 0x4c,
        79: 0x4e,
        81: 0x50,
      };
      final op = ops[id];
      if (op == null) throw StateError('该属性没有已确认的QCC查询映射');
      await _send(
        QccCodec.encode(id == 2 ? QccCodec.queryEq() : QccFrame(0, op)),
      );
    } else if (protocol == 'ordinary') {
      await _send(BleCodec.encode(BleCodec.query(_next(), [id])));
    } else {
      throw StateError('RTK 该属性查询尚无可用映射');
    }
  }

  @override
  Future<void> setBooleanAttribute(int attributeId, bool value) async {
    _guard();
    if (!(config?['toggles'] as List? ?? []).any((t) => t['id'] == attributeId))
      throw ArgumentError('配置不支持该开关');
    if ([4, 5, 6, 250, 254].contains(attributeId))
      throw ArgumentError('不允许危险或保留命令');
    if (protocol == 'qcc') {
      final op = {77: 77, 79: 79, 81: 81}[attributeId];
      if (op == null) throw StateError('无已确认QCC开关映射');
      await _send(QccCodec.encode(QccFrame(0, op, [value ? 1 : 0])));
    } else {
      await _send(
        BleCodec.encode(BleFrame(_next(), attributeId, [value ? 1 : 0])),
      );
    }
    await _queryAttribute(attributeId);
  }

  @override
  Future<void> setPromptVolume(int volume) async {
    _guard();
    if (protocol != 'ordinary' ||
        !(config?['promptVolume']?['options'] as List? ?? []).any(
          (o) => o['value'] == volume,
        ))
      throw ArgumentError('不支持该提示音量');
    await _send(BleCodec.encode(BleFrame(_next(), 41, [volume])));
    await _queryAttribute(41);
  }

  @override
  Future<void> setPowerOffMinutes(int minutes) async {
    _guard();
    if (protocol != 'ordinary' ||
        !(config?['powerOff']?['options'] as List? ?? []).any(
          (o) => o['value'] == minutes,
        ))
      throw ArgumentError('不支持该定时选项');
    await _send(
      BleCodec.encode(
        BleFrame(_next(), 32, [minutes & 255, (minutes >> 8) & 255]),
      ),
    );
    await _queryAttribute(32);
  }

  @override
  Future<void> setPairName(String name) async {
    _guard();
    if (config?['rename'] != true) throw StateError('产品未声明名称设置');
    final bytes = utf8.encode(name.trim());
    if (bytes.isEmpty ||
        bytes.length > 24 ||
        name.contains(RegExp(r'[\x00-\x1f]')))
      throw ArgumentError('名称须为1–24个UTF-8字节且无控制字符');
    await _send(
      protocol == 'qcc'
          ? QccCodec.encode(QccFrame(0, 0x3e, [...bytes, 0]))
          : BleCodec.encode(BleFrame(_next(), 39, bytes)),
    );
    await _queryAttribute(39);
  }

  @override
  Future<void> setButtonMapping(int eventId, int functionId) async {
    _guard();
    if (!(config?['buttons'] as List? ?? []).any(
      (b) =>
          b['eventId'] == eventId &&
          (b['functions'] as List).any((f) => f['id'] == functionId),
    ))
      throw ArgumentError('按键/功能不在产品配置中');
    await _send(
      protocol == 'qcc'
          ? QccCodec.encode(QccCodec.button(eventId, functionId))
          : BleCodec.encode(BleCodec.button(_next(), eventId, functionId)),
    );
    await _queryAttribute(1);
  }

  @override
  Future<void> selectEqPreset(int presetId) async {
    if (protocol == 'rtk') {
      final s = _rtkSession;
      if (s == null) throw StateError('缺少RTK能力');
      await _send(RtkCodec.encode(s.eqPreset(_next(), presetId)));
      return;
    }
    _guard();
    final list = (config?['eqPresets'] as List? ?? []).where(
      (p) => p['id'] == presetId,
    );
    if (list.isEmpty) throw ArgumentError('未知EQ预设');
    final p = list.first;
    if (protocol == 'qcc') {
      for (final frame in QccCodec.eq(
        presetId,
        gains: (p['gains'] as List?)?.cast<int>(),
      )) {
        await _send(QccCodec.encode(frame));
      }
    } else {
      await _send(
        BleCodec.encode(
          BleCodec.eq(
            _next(),
            presetId,
            gains: (p['gains'] as List?)?.cast<int>(),
          ),
        ),
      );
    }
    await _queryAttribute(2);
  }

  void _guard() {
    if (connection != UiConnection.connected || config == null)
      throw StateError('需要连接和产品配置');
    if (protocol == 'rtk') throw StateError('RTK 写入需能力协商，当前保持锁定');
  }

  @override
  Future<void> setAnc(int modeId, int level) async {
    if (protocol == 'rtk') {
      final session = _rtkSession;
      if (session == null) throw StateError('缺少RTK明确能力配置');
      final command = session.listeningMode(_next(), modeId);
      if (command != null) await _send(RtkCodec.encode(command));
      await _send(RtkCodec.encode(RtkCommands.queryListeningMode(_next())));
      return;
    }
    _guard();
    final modes = (config!['ancModes'] as List? ?? []).where(
      (m) => m['id'] == modeId && (m['levels'] as List).contains(level),
    );
    if (modes.isEmpty) throw ArgumentError('模式或档位不在产品配置中');
    await _send(BleCodec.encode(BleCodec.anc(_next(), modeId, level)));
    await _send(BleCodec.encode(BleCodec.query(_next(), [9])));
  }

  @override
  Future<void> setGameEnabled(bool enabled) async {
    if (protocol == 'rtk') {
      if (connection != UiConnection.connected ||
          config?['game'] != true ||
          !_rtkReady ||
          gaming == null)
        throw StateError('RTK 需要先收到游戏模式状态');
      if (gaming == enabled) return;
      await _send(RtkCodec.encode(RtkCodec.toggleGaming(_next())));
      await _send(RtkCodec.encode(RtkCodec.queryGaming(_next())));
      return;
    }
    _guard();
    if (config!['game'] != true) throw StateError('配置未启用游戏模式');
    await _send(
      protocol == 'qcc'
          ? QccCodec.encode(QccCodec.gaming(enabled))
          : BleCodec.encode(BleCodec.gaming(_next(), enabled)),
    );
    await _send(
      protocol == 'qcc'
          ? QccCodec.encode(QccCodec.queryGaming())
          : BleCodec.encode(BleCodec.query(_next(), [14])),
    );
  }

  @override
  Future<void> setEqualizer(List<int> values) async {
    _guard();
    final eq = config!['eq'] as Map?;
    if (eq == null ||
        values.length != 10 ||
        values.any((g) => g < eq['min'] || g > eq['max']))
      throw ArgumentError('EQ 超出配置范围');
    if (protocol == 'qcc') {
      for (final f in QccCodec.eq(255, gains: values)) {
        await _send(QccCodec.encode(f));
      }
    } else {
      await _send(BleCodec.encode(BleCodec.eq(_next(), 255, gains: values)));
    }
    await _send(
      protocol == 'qcc'
          ? QccCodec.encode(QccCodec.queryEq())
          : BleCodec.encode(BleCodec.query(_next(), [2])),
    );
  }

  void _confirm() {
    if (_confirmation != null && !_confirmation!.isCompleted)
      _confirmation!.complete();
  }

  void _battery(BatteryStatus? b) {
    if (b != null) {
      left = b.left.percent;
      right = b.right.percent;
      // Raw 0 with no charging flag means the device did not report a real
      // case level (protocol has no explicit "absent" marker); show unknown
      // instead of a misleading 0%.
      box = (b.caseBattery.percent == 0 && !b.caseBattery.charging)
          ? null
          : b.caseBattery.percent;
    }
  }

  void _receive(Uint8List bytes) {
    _log('RX ${_hex(bytes)}');
    try {
      if (protocol == 'rtk') {
        for (final f in rtkParser.add(bytes)) {
          if (f.opcode == 0) {
            if (f.params.length < 3) {
              _log('丢弃过短 RTK ACK');
              continue;
            }
            final ack = f.params[0] | (f.params[1] << 8);
            if (ack == _pendingOpcode) {
              if (f.params[2] == 0) {
                _confirm();
              } else if (_confirmation != null && !_confirmation!.isCompleted) {
                _confirmation!.completeError(
                  StateError('RTK 命令被拒绝：${f.params[2]}'),
                );
              }
            }
          } else {
            final ack = RtkCodec.encode(
              RtkFrame(_next(), 0, [f.opcode & 255, f.opcode >> 8, 0]),
            );
            unawaited(
              rfcomm.write(ack).catchError((Object e) => _linkError('$e')),
            );
            if (_lastRtkReceive == f.sequence) continue;
            _lastRtkReceive = f.sequence;
            if (f.opcode == 0x0e00 && f.params.isNotEmpty) {
              gaming = f.params[0] == 1;
              _rtkReady = true;
            }
            if (f.opcode == 0x0c3c && f.params.length >= 2) {
              ancId = f.params[0] == 2
                  ? 1
                  : f.params[0] == 0
                  ? 2
                  : 3;
              ancLevel = f.params[1];
            }
            _log('RTK 状态 opcode 0x${f.opcode.toRadixString(16)}');
          }
        }
      } else if (bytes.isNotEmpty && bytes[0] == 0) {
        final f = QccCodec.decode(bytes);
        if (f.isQueueAck) _confirm();
        _battery(BatteryStatus.fromQcc(f));
        if (f.operation == 2 && f.payload.isNotEmpty)
          _eqPresetId = f.payload[0];
        if (f.operation == 0x3d)
          _pairName = utf8.decode(
            f.payload.takeWhile((b) => b != 0).toList(),
            allowMalformed: true,
          );
        if (f.operation == 0x54 && f.payload.length >= 3)
          _firmwareVersion = f.payload
              .take(3)
              .map((n) => (n - 48) & 255)
              .join('.');
        final attr = {0x4c: 77, 0x4e: 79, 0x50: 81}[f.operation];
        if (attr != null && f.payload.isNotEmpty)
          _attributes[attr] = f.payload[0];
        if (f.operation == 0x4a && f.payload.length >= 10) {
          final ids = [1, 2, 3, 5, 17, 18, 19, 21];
          final indexes = [1, 2, 3, 4, 6, 7, 8, 9];
          for (var i = 0; i < 8; i++) {
            _buttonFunctions[ids[i]] = f.payload[indexes[i]];
          }
        }
        if (f.operation == 0x52 && f.payload.isNotEmpty)
          gaming = f.payload[0] == 1;
        if (f.operation == 2 && f.payload.isNotEmpty && f.payload[0] == 63) {
          unawaited(
            _send(
              QccCodec.encode(QccFrame(0x0a, 5, [0, 9])),
            ).catchError((Object e) => _log('$e')),
          );
        }
        if (f.operation == 5 && f.payload.length >= 72) {
          final p = f.payload;
          gains = List.generate(10, (i) {
            final n = (p[2 + i * 7 + 5] << 8) | p[2 + i * 7 + 6];
            return (n >= 32768 ? n - 65536 : n) ~/ 60;
          });
        }
      } else {
        for (final f in bleParser.add(bytes)) {
          if (f.isQueueAck) _confirm();
          _battery(BatteryStatus.fromBle(f));
          if (f.command == 13 && f.payload.length >= 3)
            _firmwareVersion = f.payload.take(3).join('.');
          if (f.command == 39)
            _pairName = utf8.decode(
              f.payload.takeWhile((b) => b != 0).toList(),
              allowMalformed: true,
            );
          if (f.command == 1 && f.payload.length.isEven) {
            for (var i = 0; i < f.payload.length; i += 2) {
              _buttonFunctions[f.payload[i]] = f.payload[i + 1];
            }
          }
          if (f.command == 32 && f.payload.length >= 2)
            _attributes[32] = f.payload[0] | (f.payload[1] << 8);
          if (f.payload.isNotEmpty &&
              ![1, 2, 9, 10, 12, 13, 32, 39, 254].contains(f.command)) {
            var v = 0;
            for (var i = 0; i < f.payload.length && i < 4; i++) {
              v |= f.payload[i] << (8 * i);
            }
            _attributes[f.command] = v;
          }
          if (f.command == 2 && f.payload.isNotEmpty)
            _eqPresetId = f.payload[0];
          if (f.command == 9 && f.payload.length >= 2) {
            ancId = f.payload[0];
            ancLevel = f.payload[1];
          }
          if (f.command == 14 && f.payload.isNotEmpty)
            gaming = f.payload[0] == 1;
          if (f.command == 2 && f.payload.length >= 11)
            gains = f.payload
                .sublist(1, 11)
                .map((n) => n > 127 ? n - 256 : n)
                .toList();
        }
      }
      _publish();
    } catch (e) {
      _log('丢弃无效通知：$e');
    }
  }

  String _hex(List<int> data) =>
      data.map((n) => n.toRadixString(16).padLeft(2, '0')).join(' ');
  @override
  Future<void> clearLogs() async {
    logs.clear();
    _publish();
  }
}
