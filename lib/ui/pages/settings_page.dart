import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// Everything that is set once and forgotten: switches, name, prompt volume,
/// auto power-off, button mapping.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.deps});
  final AppDeps deps;

  UiSnapshot get s => deps.s;

  bool get _hasAny =>
      s.booleanAttributes.isNotEmpty ||
      s.pairNameSupported ||
      s.promptVolumeSupported ||
      s.powerOffSupported ||
      s.buttonEvents.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final block = deps.block;
    return PageBody(
      children: [
        if (block != null) ...[
          NoticeBar(
            text: block.text,
            actionLabel: block.actionLabel,
            onAction: block.tab == null ? null : () => deps.go(block.tab!),
          ),
          const SizedBox(height: Tk.s5),
        ],
        if (!_hasAny)
          const AppCard(
            title: '设备设置',
            children: [EmptyNote('当前协议和产品配置没有提供可设置项。')],
          )
        else ...[
          if (s.booleanAttributes.isNotEmpty) ...[
            AppCard(
              title: '开关',
              children: [
                for (final attribute in s.booleanAttributes)
                  ToggleRow(
                    title: attribute.label,
                    state: attribute.value == null
                        ? '状态未知，先刷新状态'
                        : '设备回报：${attribute.value! ? '开启' : '关闭'}',
                    value: attribute.value ?? false,
                    onChanged: deps.controls && attribute.value != null
                        ? (value) => deps.run(
                            () => deps.model.setBooleanAttribute(
                              attribute.id,
                              value,
                            ),
                          )
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: Tk.s5),
          ],
          if (s.pairNameSupported ||
              s.promptVolumeSupported ||
              s.powerOffSupported) ...[
            AppCard(
              title: '设备',
              children: [
                if (s.pairNameSupported) ...[
                  Readout(label: '配对名称', value: s.pairName),
                  const SizedBox(height: Tk.s2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: deps.controls ? () => _rename(context) : null,
                      child: const Text('重命名'),
                    ),
                  ),
                  const SizedBox(height: Tk.s5),
                ],
                if (s.promptVolumeSupported)
                  _options(
                    label: '提示音量',
                    reported: s.promptVolume,
                    options: s.promptVolumeOptions,
                    send: deps.model.setPromptVolume,
                  ),
                if (s.powerOffSupported)
                  _options(
                    label: '自动关机',
                    reported: s.powerOffMinutes,
                    options: s.powerOffOptions,
                    send: deps.model.setPowerOffMinutes,
                  ),
              ],
            ),
            const SizedBox(height: Tk.s5),
          ],
          if (s.buttonEvents.isNotEmpty)
            AppCard(
              title: '按键',
              children: [
                for (var i = 0; i < s.buttonEvents.length; i++) ...[
                  if (i > 0) ...[
                    const SizedBox(height: Tk.s5),
                    const Divider(),
                    const SizedBox(height: Tk.s4),
                  ],
                  _event(s.buttonEvents[i]),
                ],
              ],
            ),
          const SizedBox(height: Tk.s4),
          Text('选项全部来自产品配置；选择即发送，选中项是设备回报的值。', style: Tk.note),
        ],
      ],
    );
  }

  Widget _options({
    required String label,
    required int? reported,
    required List<UiIntegerOption> options,
    required Future<void> Function(int) send,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FieldLabel(label),
      if (options.isEmpty)
        const EmptyNote('产品配置没有给出可用值，界面不推测范围。')
      else
        ChoiceRow(
          children: [
            for (final option in options)
              Choice(
                label: option.label,
                selected: reported == option.value,
                onTap: deps.controls
                    ? () => deps.run(() => send(option.value))
                    : null,
              ),
          ],
        ),
      const SizedBox(height: Tk.s5),
    ],
  );

  Widget _event(UiButtonEvent event) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FieldLabel(event.label),
      if (event.functions.isEmpty)
        const EmptyNote('这个按键事件没有可选功能。')
      else
        ChoiceRow(
          children: [
            for (final function in event.functions)
              Choice(
                label: function.label,
                selected: event.currentFunctionId == function.id,
                onTap: deps.controls
                    ? () => deps.run(
                        () => deps.model.setButtonMapping(
                          event.eventId,
                          function.id,
                        ),
                      )
                    : null,
              ),
          ],
        ),
      if (event.currentFunctionId == null) ...[
        const SizedBox(height: Tk.s2),
        Text('设备尚未回报这个按键的当前功能。', style: Tk.note),
      ],
    ],
  );

  Future<void> _rename(BuildContext context) async {
    final input = TextEditingController(text: s.pairName ?? '');
    final before = s;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改配对名称'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: input,
            autofocus: true,
            decoration: const InputDecoration(labelText: '新名称'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = input.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('发送'),
          ),
        ],
      ),
    );
    input.dispose();
    if (result == null) return;
    // The dialog was open while the link could change: revalidate against the
    // live snapshot before sending anything.
    final current = deps.model.snapshot.value;
    if (current.connection != UiConnection.connected ||
        !current.pairNameSupported ||
        !current.configurationReady ||
        current.deviceId != before.deviceId ||
        current.protocolId != before.protocolId) {
      return;
    }
    await deps.run(() => deps.model.setPairName(result));
  }
}
