import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class EarbudApp extends StatelessWidget {
  const EarbudApp({super.key, required this.model});
  final EarbudViewModel model;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8B83FF),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sibyl Control',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFF0C1020),
        cardTheme: const CardThemeData(
          color: Color(0xFF171D33),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
      ),
      home: _EarbudHome(model: model),
    );
  }
}

class _EarbudHome extends StatefulWidget {
  const _EarbudHome({required this.model});
  final EarbudViewModel model;
  @override
  State<_EarbudHome> createState() => _EarbudHomeState();
}

class _EarbudHomeState extends State<_EarbudHome> {
  final _level = TextEditingController();
  int? _draftMode;
  List<int>? _draftEq;
  String? _draftContext;
  bool _running = false;

  @override
  void dispose() {
    _level.dispose();
    super.dispose();
  }

  Future<void> _invoke(Future<void> Function() operation) async {
    if (_running) return;
    setState(() => _running = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  bool _idle(UiSnapshot s) => !s.busy && !_running;
  bool _controls(UiSnapshot s) =>
      _idle(s) &&
      s.connection == UiConnection.connected &&
      s.configurationReady &&
      s.protocolId != null &&
      s.protocols.any((p) => p.id == s.protocolId);

  String _connectionLabel(UiConnection state) => switch (state) {
    UiConnection.disconnected => '未连接',
    UiConnection.connecting => '正在连接',
    UiConnection.connected => '已连接',
    UiConnection.disconnecting => '正在断开',
  };

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<UiSnapshot>(
    valueListenable: widget.model.snapshot,
    builder: (context, s, _) {
      // Reset drafts across transport/device/config changes, not notifications.
      final signature =
          '${s.deviceId}|${s.connection.name}|${s.protocolId}|'
          '${s.configurationReady}|${s.ancModes.map((m) => '${m.id}:${m.defaultLevel}:${m.allowedLevels.join(',')}').join(';')}|'
          '${s.eqConfig?.minGain}|${s.eqConfig?.maxGain}|'
          '${s.eqConfig?.bandLabels.join(',')}';
      if (_draftContext != signature) {
        _draftContext = signature;
        _draftMode = null;
        _draftEq = null;
        _level.clear();
      }
      return Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 960;
              final padding = constraints.maxWidth < 480 ? 16.0 : 28.0;
              return SingleChildScrollView(
                padding: EdgeInsets.all(padding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(s),
                        const SizedBox(height: 20),
                        _notice(s),
                        const SizedBox(height: 20),
                        if (_running || s.busy) ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: 16),
                        ],
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: Column(
                                  children: [
                                    _connection(s),
                                    const SizedBox(height: 18),
                                    _devices(s),
                                    const SizedBox(height: 18),
                                    _protocol(s),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 6,
                                child: Column(
                                  children: [
                                    _battery(s),
                                    const SizedBox(height: 18),
                                    _anc(s),
                                    const SizedBox(height: 18),
                                    _game(s),
                                    const SizedBox(height: 18),
                                    _eq(s),
                                    ..._dailyControls(s),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _connection(s),
                          const SizedBox(height: 18),
                          _battery(s),
                          const SizedBox(height: 18),
                          _devices(s),
                          const SizedBox(height: 18),
                          _protocol(s),
                          const SizedBox(height: 18),
                          _anc(s),
                          const SizedBox(height: 18),
                          _game(s),
                          const SizedBox(height: 18),
                          _eq(s),
                          ..._dailyControls(s),
                        ],
                        const SizedBox(height: 20),
                        _logs(s),
                        const SizedBox(height: 16),
                        const Text(
                          '不包含 OTA、固件写入或恢复出厂功能。',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );

  Widget _header(UiSnapshot s) => Wrap(
    spacing: 20,
    runSpacing: 12,
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.headphones_rounded, size: 34, color: Color(0xFFAAA4FF)),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SIBYL / CONTROL',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              Text('耳机控制台 · Android / Windows / Linux'),
            ],
          ),
        ],
      ),
      Chip(
        avatar: Icon(
          s.preview ? Icons.science_outlined : Icons.bluetooth,
          size: 18,
        ),
        label: Text(s.preview ? '演示模式 · 非真实设备' : '真实状态 · 控制器提供'),
      ),
    ],
  );

  Widget _notice(UiSnapshot s) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: s.preview ? const Color(0xFF493018) : const Color(0xFF222445),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: s.preview ? Colors.orangeAccent : const Color(0xFF53528A),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.preview
              ? '演示 / PREVIEW — 所有数据均为演示，不代表蓝牙连接'
              : s.hardwareVerified
              ? '硬件验证状态由控制器报告'
              : '硬件未验证 · 静态协议不等于设备兼容',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(s.configurationNote),
        const SizedBox(height: 6),
        const Text(
          'ANC ID / level、游戏命令与 EQ 范围须来自产品配置。普通 BLE、QCC BLE、RTK 的编码与能力不可混用；QCC ANC 支持仍需实机确认。发送完成不代表设备已执行。',
        ),
      ],
    ),
  );

  Widget _card(String title, IconData icon, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFAAA4FF), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    ),
  );

  Widget _connection(UiSnapshot s) => _card('连接状态', Icons.link_rounded, [
    Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        Chip(label: Text(_connectionLabel(s.connection))),
        if (s.deviceName != null) Chip(label: Text(s.deviceName!)),
      ],
    ),
    if (s.deviceId != null) SelectableText(s.deviceId!),
    if (s.statusDetail != null) ...[
      const SizedBox(height: 8),
      Text(s.statusDetail!),
    ],
    const SizedBox(height: 12),
    OutlinedButton.icon(
      onPressed: _idle(s) && s.connection == UiConnection.connected
          ? () => _invoke(widget.model.disconnect)
          : null,
      icon: const Icon(Icons.link_off),
      label: const Text('断开连接'),
    ),
    OutlinedButton.icon(
      onPressed: _idle(s) && s.connection == UiConnection.connected
          ? () => _invoke(widget.model.refreshStatus)
          : null,
      icon: const Icon(Icons.refresh),
      label: const Text('刷新状态'),
    ),
  ]);

  Widget _devices(UiSnapshot s) => _card('发现设备', Icons.radar_rounded, [
    FilledButton.tonalIcon(
      onPressed:
          _idle(s) &&
              s.scanAvailable &&
              s.connection == UiConnection.disconnected
          ? () => _invoke(
              s.scanning ? widget.model.stopScan : widget.model.startScan,
            )
          : null,
      icon: Icon(s.scanning ? Icons.stop_rounded : Icons.search_rounded),
      label: Text(s.scanning ? '停止扫描' : '扫描设备'),
    ),
    if (s.scanning) ...[
      const SizedBox(height: 12),
      const LinearProgressIndicator(),
    ],
    const SizedBox(height: 12),
    if (!s.scanAvailable) const Text('当前平台 / 权限 / 传输尚未就绪，扫描不可用。'),
    if (s.devices.isEmpty)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(s.scanning ? '扫描中，等待真实广播…' : '暂无扫描结果；不会自动生成设备。'),
      ),
    ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: ListView.separated(
        shrinkWrap: true,
        primary: false,
        itemCount: s.devices.length,
        separatorBuilder: (_, index) => const Divider(height: 20),
        itemBuilder: (context, index) {
          final device = s.devices[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                device.name.isEmpty ? '未命名设备' : device.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(device.id, style: Theme.of(context).textTheme.bodySmall),
              if (device.detail != null) Text(device.detail!),
              if (device.rssi != null) Text('信号 ${device.rssi} dBm'),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed:
                      _idle(s) &&
                          !s.scanning &&
                          s.connection == UiConnection.disconnected &&
                          s.protocols.any((p) => p.id == s.protocolId)
                      ? () => _invoke(() => widget.model.connect(device.id))
                      : null,
                  icon: const Icon(Icons.bluetooth_connected),
                  label: const Text('连接'),
                ),
              ),
            ],
          );
        },
      ),
    ),
    const Text('停止扫描并选择匹配的协议后连接；不按设备名称猜测芯片。'),
  ]);

  Widget _battery(UiSnapshot s) {
    Widget item(String title, int? raw, IconData icon) {
      final value =
          s.connection == UiConnection.connected &&
              raw != null &&
              raw >= 0 &&
              raw <= 100
          ? raw
          : null;
      return Expanded(
        child: Column(
          children: [
            Icon(icon, size: 30, color: const Color(0xFFAAA4FF)),
            const SizedBox(height: 10),
            Text(title),
            const SizedBox(height: 4),
            Text(
              value == null ? '未知' : '$value%',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: value == null ? 0 : value / 100,
              color: value == null ? Colors.blueGrey : null,
            ),
          ],
        ),
      );
    }

    return _card('设备电量', Icons.battery_charging_full_rounded, [
      Row(
        children: [
          item('左耳', s.leftBattery, Icons.headphones),
          const SizedBox(width: 18),
          item('右耳', s.rightBattery, Icons.headphones),
          const SizedBox(width: 18),
          item('充电仓', s.caseBattery, Icons.battery_std),
        ],
      ),
      const SizedBox(height: 14),
      const Text('仅展示设备报告；未上报的电量显示“未知”。'),
    ]);
  }

  Future<void> _importConfiguration() async {
    final input = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入产品配置'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('粘贴已确认的产品配置。不要套用其他型号的档位或增益范围；配置仅保存在本机。'),
                const SizedBox(height: 12),
                TextField(
                  controller: input,
                  minLines: 8,
                  maxLines: 16,
                  decoration: const InputDecoration(labelText: 'JSON 配置'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    input.dispose();
    if (result != null)
      await _invoke(() => widget.model.importConfiguration(result));
  }

  Future<void> _connectAddress() async {
    final address = TextEditingController();
    final channel = TextEditingController();
    final result = await showDialog<(String, int?)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('手动连接'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '先选择协议。RTK 使用经典蓝牙地址；Linux 可指定已确认的 RFCOMM channel，留空则查询 SDP。',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: address,
                decoration: const InputDecoration(
                  labelText: '蓝牙地址 AA:BB:CC:DD:EE:FF',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: channel,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'RFCOMM channel（可选 1–30）',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              address.text.trim(),
              channel.text.isEmpty ? null : int.tryParse(channel.text),
            )),
            child: const Text('连接'),
          ),
        ],
      ),
    );
    address.dispose();
    channel.dispose();
    if (result != null)
      await _invoke(
        () => widget.model.connectAddress(result.$1, rfcommChannel: result.$2),
      );
  }

  Widget _protocol(UiSnapshot s) => _card('协议配置', Icons.tune_rounded, [
    if (s.protocols.isEmpty) const Text('控制器尚未提供可用协议。'),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: s.protocols
          .map(
            (p) => ChoiceChip(
              label: Text(p.label),
              selected: s.protocolId == p.id,
              onSelected:
                  _idle(s) &&
                      !s.scanning &&
                      s.connection == UiConnection.disconnected
                  ? (_) => _invoke(() => widget.model.selectProtocol(p.id))
                  : null,
            ),
          )
          .toList(),
    ),
    const SizedBox(height: 12),
    ...s.protocols
        .where((p) => p.id == s.protocolId)
        .map((p) => Text(p.detail)),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _idle(s) && s.connection == UiConnection.disconnected
              ? _importConfiguration
              : null,
          icon: const Icon(Icons.data_object),
          label: const Text('导入产品配置'),
        ),
        FilledButton.tonalIcon(
          // Reading configuration must not depend on configurationReady.
          onPressed: _idle(s) && s.connection == UiConnection.connected
              ? () => _invoke(widget.model.loadProductConfiguration)
              : null,
          icon: const Icon(Icons.download_rounded),
          label: const Text('读取产品配置'),
        ),
        OutlinedButton.icon(
          onPressed:
              _idle(s) &&
                  !s.scanning &&
                  s.connection == UiConnection.disconnected
              ? _connectAddress
              : null,
          icon: const Icon(Icons.link),
          label: const Text('手动地址连接'),
        ),
      ],
    ),
    const SizedBox(height: 8),
    const Text('仅断开且停止扫描后可切换协议。能力及配置须由控制器校验；RTK 游戏开关需先查询再按需 toggle。'),
  ]);

  Widget _anc(UiSnapshot s) {
    final selected = _draftMode ?? s.ancModeId;
    final matches = s.ancModes.where((m) => m.id == selected);
    final mode = matches.isEmpty ? null : matches.first;
    final enabled = _controls(s) && s.ancSupported;
    final entered = int.tryParse(_level.text.trim());
    final valid =
        mode != null && entered != null && mode.allowedLevels.contains(entered);
    return _card('ANC / 环境声', Icons.noise_control_off_rounded, [
      Text('设备报告：模式 ${s.ancModeId ?? '未知'} · level ${s.ancLevel ?? '未知'}'),
      const SizedBox(height: 12),
      if (s.ancModes.isEmpty) const Text('暂无已配置的 ANC 模式。'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: s.ancModes
            .map(
              (m) => ChoiceChip(
                label: Text(m.label),
                selected: m.id == selected,
                onSelected: enabled
                    ? (_) => setState(() {
                        _draftMode = m.id;
                        _level.text = '${m.defaultLevel}';
                      })
                    : null,
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _level,
        enabled: enabled && mode != null,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: '自定义 level（待发送）',
          hintText: '先选择模式，再输入配置允许的值',
          errorText: _level.text.isNotEmpty && !valid
              ? '不在该模式允许的 level 列表中'
              : null,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        mode == null
            ? 'level 不代表统一的开关或降噪强度。'
            : '模式 ID ${mode.id} · 允许 level：${mode.allowedLevels.join(' / ')}',
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: enabled && valid
            ? () => _invoke(() => widget.model.setAnc(mode.id, entered))
            : null,
        icon: const Icon(Icons.send_rounded),
        label: const Text('发送 ANC 设置'),
      ),
      if (!enabled) const Text('需连接设备、产品配置就绪且确认支持 ANC。'),
    ]);
  }

  Widget _game(UiSnapshot s) =>
      _card('低延迟 / 游戏', Icons.sports_esports_outlined, [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('游戏模式'),
          subtitle: Text(
            s.gameEnabled == null
                ? '设备状态未知；先查询再切换'
                : '设备报告：${s.gameEnabled! ? '开启' : '关闭'}',
          ),
          value: s.gameEnabled ?? false,
          onChanged: _controls(s) && s.gameSupported && s.gameEnabled != null
              ? (value) => _invoke(() => widget.model.setGameEnabled(value))
              : null,
        ),
        if (!s.gameSupported) const Text('当前协议 / 产品配置未启用游戏模式。'),
      ]);

  Widget _eq(UiSnapshot s) {
    final config = s.eqConfig;
    final reported = s.eqGains;
    final valid = config != null && config.valid;
    final reportedValid =
        valid &&
        reported != null &&
        reported.length == 10 &&
        reported.every((g) => g >= config.minGain && g <= config.maxGain);
    final gains = _draftEq ?? (reportedValid ? reported : null);
    final enabled = _controls(s) && s.eqSupported && valid;
    return _card('10 段均衡器', Icons.graphic_eq_rounded, [
      if (s.eqPresets.isNotEmpty) ...[
        const Text('产品 EQ 预设（选择即发送，选中状态仅来自设备报告）'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: s.eqPresets.map((preset) => ChoiceChip(
            label: Text(preset.label),
            selected: s.eqPresetId == preset.id,
            onSelected: _controls(s) && s.eqSupported
                ? (_) => _invoke(() => widget.model.selectEqPreset(preset.id))
                : null,
          )).toList(),
        ),
        const SizedBox(height: 16),
      ],
      const Text('拖动仅编辑草稿，点击发送才下发；设备状态由控制器回报。'),
      const SizedBox(height: 12),
      if (!valid) const Text('缺少有效的 10 段产品配置；不假定频率或增益范围。'),
      if (valid && gains == null) ...[
        const Text('设备 EQ 未上报或范围无效。可显式创建待发送草稿，不代表当前 EQ。'),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: enabled
              ? () => setState(() {
                  _draftEq = List<int>.filled(
                    10,
                    0.clamp(config.minGain, config.maxGain).toInt(),
                  );
                })
              : null,
          child: const Text('创建 EQ 草稿'),
        ),
      ],
      // Always render ten controls, including the unavailable/unknown state.
      ...List.generate(10, (index) {
        final value = gains?[index];
        final min = valid ? config.minGain.toDouble() : -1.0;
        final max = valid ? config.maxGain.toDouble() : 1.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    valid ? config.bandLabels[index] : '频段 ${index + 1}',
                  ),
                ),
                Text(value == null ? '未知' : '$value ${config!.unit}'),
              ],
            ),
            Slider(
              value: (value?.toDouble() ?? 0).clamp(min, max).toDouble(),
              min: min,
              max: max,
              divisions: valid ? config.maxGain - config.minGain : 2,
              label: value == null ? '未知' : '$value ${config!.unit}',
              onChanged: enabled && gains != null
                  ? (v) => setState(() {
                      _draftEq = List<int>.of(gains);
                      _draftEq![index] = v.round();
                    })
                  : null,
            ),
          ],
        );
      }),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: enabled && _draftEq != null
                ? () => _invoke(
                    () => widget.model.setEqualizer(
                      List<int>.unmodifiable(_draftEq!),
                    ),
                  )
                : null,
            icon: const Icon(Icons.send_rounded),
            label: const Text('发送 10 段 EQ'),
          ),
          OutlinedButton(
            onPressed: _draftEq != null && _idle(s)
                ? () => setState(() => _draftEq = null)
                : null,
            child: const Text('丢弃草稿'),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(_draftEq == null ? '当前显示：设备报告（未上报则未知）' : '当前显示：待发送草稿 · 非设备确认'),
    ]);
  }

  Future<void> _rename(UiSnapshot s) async {
    final form = GlobalKey<FormState>();
    var name = s.pairName ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改配对名称'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: form,
            child: TextFormField(
              initialValue: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: '新名称'),
              onChanged: (value) => name = value,
              validator: (value) => value == null || value.trim().isEmpty
                  ? '请输入非空名称'
                  : null,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, name);
            },
            child: const Text('发送名称'),
          ),
        ],
      ),
    );
    if (!mounted || result == null) return;
    final current = widget.model.snapshot.value;
    if (!_controls(current) || !current.pairNameSupported ||
        current.deviceId != s.deviceId || current.protocolId != s.protocolId) {
      return;
    }
    await _invoke(() => widget.model.setPairName(result));
  }

  Widget _integerChoices({
    required UiSnapshot snapshot,
    required String title,
    required int? reported,
    required List<UiIntegerOption> options,
    required Future<void> Function(int) send,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('$title · 设备报告：${reported ?? '未知'}'),
      const SizedBox(height: 8),
      if (options.isEmpty) const Text('缺少产品配置允许的值；不推测范围。'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((option) => ChoiceChip(
          label: Text(option.label),
          selected: reported == option.value,
          onSelected: _controls(snapshot)
              ? (_) => _invoke(() => send(option.value))
              : null,
        )).toList(),
      ),
      const SizedBox(height: 16),
    ],
  );

  List<Widget> _dailyControls(UiSnapshot s) => [
    if (s.booleanAttributes.isNotEmpty) ...[
      const SizedBox(height: 18),
      _card('日常功能', Icons.toggle_on_outlined, [
        ...s.booleanAttributes.map((attribute) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(attribute.label),
          subtitle: Text(attribute.value == null
              ? '状态未知，请先刷新状态'
              : '设备报告：${attribute.value! ? '开启' : '关闭'}'),
          value: attribute.value ?? false,
          onChanged: _controls(s) && attribute.value != null
              ? (value) => _invoke(() => widget.model.setBooleanAttribute(
                    attribute.id, value))
              : null,
        )),
      ]),
    ],
    if (s.pairNameSupported || s.promptVolumeSupported || s.powerOffSupported) ...[
      const SizedBox(height: 18),
      _card('设备设置', Icons.settings_outlined, [
        if (s.pairNameSupported) ...[
          Text('配对名称 · 设备报告：${s.pairName ?? '未知'}'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _controls(s) ? () => _rename(s) : null,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('重命名'),
          ),
          const SizedBox(height: 16),
        ],
        if (s.promptVolumeSupported)
          _integerChoices(
            snapshot: s,
            title: '提示音量',
            reported: s.promptVolume,
            options: s.promptVolumeOptions,
            send: widget.model.setPromptVolume,
          ),
        if (s.powerOffSupported)
          _integerChoices(
            snapshot: s,
            title: '定时关机（分钟）',
            reported: s.powerOffMinutes,
            options: s.powerOffOptions,
            send: widget.model.setPowerOffMinutes,
          ),
        const Text('选项和范围来自产品配置；发送后等待设备确认，不在界面伪造状态。'),
      ]),
    ],
    if (s.buttonEvents.isNotEmpty) ...[
      const SizedBox(height: 18),
      _card('按键映射', Icons.touch_app_outlined, [
        const Text('事件与功能均来自产品配置；选择即发送，选中项仅为设备报告。'),
        ...s.buttonEvents.map((event) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(event.label),
              Text('设备报告 function：${event.currentFunctionId ?? '未知'}'),
              if (event.functions.isEmpty) const Text('该事件没有已配置的可选功能。'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: event.functions.map((function) => ChoiceChip(
                  label: Text(function.label),
                  selected: event.currentFunctionId == function.id,
                  onSelected: _controls(s)
                      ? (_) => _invoke(() => widget.model.setButtonMapping(
                            event.eventId, function.id))
                      : null,
                )).toList(),
              ),
            ],
          ),
        )),
      ]),
    ],
  ];

  Widget _logs(UiSnapshot s) => _card('协议与事件日志', Icons.terminal_rounded, [
    Row(
      children: [
        Expanded(child: Text('${s.logs.length} 条 · 显示最近 200 条')),
        TextButton.icon(
          onPressed: _idle(s) && s.logs.isNotEmpty
              ? () => _invoke(widget.model.clearLogs)
              : null,
          icon: const Icon(Icons.clear_all),
          label: const Text('清空'),
        ),
      ],
    ),
    const SizedBox(height: 10),
    Container(
      height: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1020),
        borderRadius: BorderRadius.circular(12),
      ),
      child: s.logs.isEmpty
          ? const Align(
              alignment: Alignment.topLeft,
              child: Text('暂无日志。日志由真实控制器提供，不生成伪造收发记录。'),
            )
          : ListView(
              primary: false,
              children: s.logs.reversed
                  .take(200)
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SelectableText(
                        '${entry.time} [${entry.level}] ${entry.message}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    ),
    const SizedBox(height: 8),
    const Text('控制器应脱敏地址、凭据与个人信息；日志中的 TX 不等于 ACK 或执行成功。'),
  ]);
}
