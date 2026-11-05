import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// Connect, power and product configuration. What the page shows depends on
/// the state you are in: the connect flow when there is no link, the device
/// itself once there is one.
class DevicePage extends StatefulWidget {
  const DevicePage({super.key, required this.deps});
  final AppDeps deps;

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  /// A scan has been started at least once in this session. Before that the
  /// page says "not scanned yet" instead of claiming nothing was found.
  bool _scanned = false;

  /// The protocol picker and the address dialog stay folded away: a device
  /// that advertises its model selects its own protocol.
  bool _advanced = false;

  AppDeps get deps => widget.deps;

  @override
  Widget build(BuildContext context) {
    final s = deps.s;
    return PageBody(
      children: deps.connected
          ? [
              _connected(context),
              const SizedBox(height: Tk.s5),
              _power(),
              const SizedBox(height: Tk.s5),
              _configuration(context),
            ]
          : [
              _connect(context),
              const SizedBox(height: Tk.s5),
              _configuration(context),
              if (s.preview) ...[
                const SizedBox(height: Tk.s5),
                const NoticeBar(
                  tone: NoticeTone.warn,
                  text: '演示模式：页面上的设备、电量和状态都是示例，不是蓝牙连接的结果。',
                ),
              ],
            ],
    );
  }

  // ---------------------------------------------------------------- connected

  Widget _connected(BuildContext context) {
    final s = deps.s;
    // The window bar already states the connection; it is not repeated here.
    // The one filled action of this view is loading the configuration while
    // it is missing, and refreshing state once everything is in place.
    final needsConfig = !s.configurationReady;
    return AppCard(
      title: '连接',
      children: [
        Readout(label: '设备', value: s.deviceName),
        Readout(label: '地址', value: s.deviceId),
        Readout(label: '协议', value: deps.protocol?.label),
        if (s.statusDetail != null) Readout(label: '说明', value: s.statusDetail),
        const SizedBox(height: Tk.s3),
        Row(
          children: [
            if (needsConfig)
              OutlinedButton(
                onPressed: deps.idle
                    ? () => deps.run(deps.model.refreshStatus)
                    : null,
                child: const Text('刷新状态'),
              )
            else
              FilledButton(
                onPressed: deps.idle
                    ? () => deps.run(deps.model.refreshStatus)
                    : null,
                child: const Text('刷新状态'),
              ),
            const SizedBox(width: Tk.s3),
            OutlinedButton(
              onPressed: deps.idle
                  ? () => deps.run(deps.model.disconnect)
                  : null,
              style: OutlinedButton.styleFrom(foregroundColor: Tk.danger),
              child: const Text('断开连接'),
            ),
          ],
        ),
        const SizedBox(height: Tk.s3),
        Text('更换设备请先断开连接。', style: Tk.note),
      ],
    );
  }

  Widget _power() {
    final s = deps.s;
    int? value(int? raw) => raw != null && raw >= 0 && raw <= 100 ? raw : null;
    return AppCard(
      title: '电量',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: BatteryMeter(label: '左耳', percent: value(s.leftBattery)),
            ),
            const SizedBox(width: Tk.s5),
            Expanded(
              child: BatteryMeter(label: '右耳', percent: value(s.rightBattery)),
            ),
            const SizedBox(width: Tk.s5),
            Expanded(
              child: BatteryMeter(label: '充电仓', percent: value(s.caseBattery)),
            ),
          ],
        ),
        const SizedBox(height: Tk.s4),
        Text('未上报的电量显示“—”，不会按 0% 画进度条。', style: Tk.note),
      ],
    );
  }

  // ------------------------------------------------------------ connect flow

  Widget _connect(BuildContext context) {
    final s = deps.s;
    final busyLink =
        s.connection == UiConnection.connecting ||
        s.connection == UiConnection.disconnecting;
    final canScan = deps.idle && s.scanAvailable && deps.disconnected;
    final canConnect = deps.idle && deps.disconnected && deps.protocolReady;
    return AppCard(
      title: '连接耳机',
      subtitle: busyLink ? deps.connectionLabel : null,
      children: [
        const StepRow(
          index: 1,
          done: false,
          current: true,
          text: '打开耳机并进入配对模式，扫描后点击设备连接',
        ),
        StepRow(
          index: 2,
          done: s.configurationReady,
          text: '载入与型号匹配的产品配置，声音和设置才会解锁',
        ),
        const SizedBox(height: Tk.s4),
        const Divider(),
        const SizedBox(height: Tk.s4),
        Row(
          children: [
            FilledButton(
              onPressed: canScan
                  ? () {
                      setState(() => _scanned = true);
                      deps.run(
                        s.scanning ? deps.model.stopScan : deps.model.startScan,
                      );
                    }
                  : null,
              child: Text(s.scanning ? '停止扫描' : '扫描设备'),
            ),
            const SizedBox(width: Tk.s3),
            if (s.scanning)
              Expanded(child: Text('扫描中，等待真实广播…', style: Tk.note))
            else if (!s.scanAvailable)
              Expanded(child: Text('当前平台、权限或传输尚未就绪，扫描不可用。', style: Tk.note)),
          ],
        ),
        const SizedBox(height: Tk.s4),
        if (s.devices.isEmpty) ...[
          EmptyNote(
            s.scanning
                ? '正在搜索附近的耳机…'
                : _scanned
                ? '这次扫描没有发现设备。确认耳机仍在配对模式后重试。'
                : '还没有扫描。点击“扫描设备”开始搜索。',
          ),
          if (_scanned && !s.scanning)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => deps.go(AppTab.log),
                child: Text(
                  '仍然找不到？查看日志',
                  style: Tk.title.copyWith(color: Tk.accent),
                ),
              ),
            ),
        ] else
          for (final device in s.devices) ...[
            _deviceRow(device, canConnect),
            const SizedBox(height: Tk.s2),
          ],
        const SizedBox(height: Tk.s3),
        const Divider(),
        const SizedBox(height: Tk.s2),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _advanced = !_advanced),
            icon: Icon(
              _advanced ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: Tk.muted,
            ),
            label: Text(
              _advanced ? '收起高级选项' : '高级：协议与手动地址',
              style: Tk.title.copyWith(color: Tk.muted),
            ),
          ),
        ),
        if (_advanced) ...[
          const SizedBox(height: Tk.s3),
          const FieldLabel('协议'),
          ChoiceRow(
            children: [
              for (final p in s.protocols)
                Choice(
                  label: p.label,
                  selected: s.protocolId == p.id,
                  onTap: deps.idle && deps.disconnected
                      ? () => deps.run(() => deps.model.selectProtocol(p.id))
                      : null,
                ),
            ],
          ),
          if (s.protocols.isEmpty) const EmptyNote('控制器尚未提供可用协议。'),
          const SizedBox(height: Tk.s2),
          Text(
            deps.protocol == null
                ? '三种协议的帧格式和能力互不通用。'
                : '${deps.protocol!.detail} · 广播中能识别型号的设备，连接时会自动切换协议。',
            style: Tk.note,
          ),
          const SizedBox(height: Tk.s4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: deps.idle && deps.disconnected
                  ? () => _manualConnect(context)
                  : null,
              child: const Text('输入蓝牙地址连接'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _deviceRow(UiDevice device, bool canConnect) => HoverRow(
    onTap: canConnect
        ? () => deps.run(() => deps.model.connect(device.id))
        : null,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device.name.isEmpty ? '未命名设备' : device.name,
                style: Tk.title,
              ),
              const SizedBox(height: Tk.s1),
              Text(device.id, style: Tk.mono.copyWith(color: Tk.muted)),
              if (device.detail != null) ...[
                const SizedBox(height: Tk.s1),
                Text(device.detail!, style: Tk.note),
              ],
            ],
          ),
        ),
        const SizedBox(width: Tk.s4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SignalBars(rssi: device.rssi),
            const SizedBox(height: Tk.s2),
            Text(
              canConnect ? '点击连接' : '连接不可用',
              style: Tk.label.copyWith(
                color: canConnect ? Tk.accent : Tk.muted,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  // ----------------------------------------------------------- configuration

  Widget _configuration(BuildContext context) {
    final s = deps.s;
    return AppCard(
      title: '产品配置',
      subtitle: '配置只保存在本机；导入 JSON 需在断开状态下进行。',
      trailing: s.configurationReady
          ? const StatusDot(colour: Tk.ok, label: '已载入')
          : const StatusDot(colour: Tk.warn, label: '未载入'),
      children: [
        Text(s.configurationNote, style: Tk.body),
        const SizedBox(height: Tk.s4),
        Row(
          children: [
            if (deps.connected)
              FilledButton(
                onPressed: deps.idle
                    ? () => deps.run(deps.model.loadProductConfiguration)
                    : null,
                child: const Text('读取产品配置'),
              )
            else
              const OutlinedButton(onPressed: null, child: Text('读取产品配置')),
            const SizedBox(width: Tk.s3),
            OutlinedButton(
              onPressed: deps.idle && deps.disconnected
                  ? () => _importConfiguration(context)
                  : null,
              child: const Text('导入 JSON'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _importConfiguration(BuildContext context) async {
    final input = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入产品配置'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('粘贴本型号已确认的配置。其他型号的档位或增益范围不通用。', style: Tk.note),
                const SizedBox(height: Tk.s4),
                TextField(
                  controller: input,
                  minLines: 8,
                  maxLines: 16,
                  style: Tk.mono,
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
    if (result != null) {
      await deps.run(() => deps.model.importConfiguration(result));
    }
  }

  Future<void> _manualConnect(BuildContext context) async {
    final address = TextEditingController();
    final channel = TextEditingController();
    final result = await showDialog<(String, int?)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入地址连接'),
        content: SizedBox(
          width: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'RTK 使用经典蓝牙地址。Linux 可填已确认的 RFCOMM channel，留空则查询 SDP。',
                style: Tk.note,
              ),
              const SizedBox(height: Tk.s4),
              TextField(
                controller: address,
                autofocus: true,
                style: Tk.mono,
                decoration: const InputDecoration(
                  labelText: '蓝牙地址',
                  hintText: 'AA:BB:CC:DD:EE:FF',
                ),
              ),
              const SizedBox(height: Tk.s3),
              TextField(
                controller: channel,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'RFCOMM channel（可选，1–30）',
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
    if (result != null && result.$1.isNotEmpty) {
      await deps.run(
        () => deps.model.connectAddress(result.$1, rfcommChannel: result.$2),
      );
    }
  }
}
