import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// Listening controls: ANC, low-latency mode, equaliser.
class SoundPage extends StatefulWidget {
  const SoundPage({super.key, required this.deps});
  final AppDeps deps;

  @override
  State<SoundPage> createState() => _SoundPageState();
}

class _SoundPageState extends State<SoundPage> {
  /// The mode whose levels are being chosen. Nothing is sent until a level is
  /// picked, and this is never shown as the device's state.
  int? _pendingMode;

  /// Edited gains waiting to be sent. Null means the view shows device values.
  List<int>? _draftEq;

  String? _context;

  AppDeps get deps => widget.deps;
  UiSnapshot get s => deps.s;

  void _resetOnContextChange() {
    // Drafts belong to one device, protocol and configuration — not to a
    // notification. Reset them only when that context actually changes.
    final signature =
        '${s.deviceId}|${s.connection.name}|${s.protocolId}|'
        '${s.configurationReady}|'
        '${s.ancModes.map((m) => '${m.id}:${m.allowedLevels.join(',')}').join(';')}|'
        '${s.eqConfig?.minGain}|${s.eqConfig?.maxGain}|'
        '${s.eqConfig?.bandLabels.join(',')}';
    if (_context != signature) {
      _context = signature;
      _pendingMode = null;
      _draftEq = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _resetOnContextChange();
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
        _anc(),
        const SizedBox(height: Tk.s5),
        _game(),
        const SizedBox(height: Tk.s5),
        _eq(),
        const SizedBox(height: Tk.s4),
        Text('发送成功只代表指令已下发；界面上的状态始终来自设备回报。', style: Tk.note),
      ],
    );
  }

  // ------------------------------------------------------------------- ANC

  Widget _anc() {
    final enabled = deps.controls && s.ancSupported;
    final selected = _pendingMode ?? s.ancModeId;
    UiAncMode? mode;
    for (final m in s.ancModes) {
      if (m.id == selected) mode = m;
    }
    final levels = mode?.allowedLevels ?? const <int>[];
    final showLevels = mode != null && levels.length > 1;
    return AppCard(
      title: '降噪 / 环境声',
      trailing: Text(
        s.ancSupported ? deps.ancModeLabel(s.ancModeId) : '不支持',
        style: Tk.title.copyWith(
          color: s.ancModeId == null ? Tk.muted : Tk.ink,
        ),
      ),
      children: [
        if (s.ancModes.isEmpty)
          const EmptyNote('产品配置里没有降噪模式。')
        else ...[
          ChoiceRow(
            children: [
              for (final m in s.ancModes)
                Choice(
                  label: m.label,
                  selected: m.id == selected,
                  onTap: enabled
                      ? () {
                          if (m.allowedLevels.length == 1) {
                            setState(() => _pendingMode = null);
                            deps.run(
                              () => deps.model.setAnc(
                                m.id,
                                m.allowedLevels.first,
                              ),
                            );
                          } else {
                            setState(() => _pendingMode = m.id);
                          }
                        }
                      : null,
                ),
            ],
          ),
          if (showLevels) ...[
            const SizedBox(height: Tk.s4),
            FieldLabel('${mode.label} · 强度'),
            ChoiceRow(
              children: [
                for (final level in levels)
                  Choice(
                    label: '$level',
                    selected: s.ancModeId == mode.id && s.ancLevel == level,
                    onTap: enabled
                        ? () {
                            final id = mode!.id;
                            setState(() => _pendingMode = null);
                            deps.run(() => deps.model.setAnc(id, level));
                          }
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: Tk.s2),
            Text('强度为产品配置里的 level 值，不是统一的降噪深度。', style: Tk.note),
          ] else if (mode != null && levels.isEmpty) ...[
            const SizedBox(height: Tk.s3),
            Text('该模式没有可用的 level，不能下发。', style: Tk.note),
          ],
          const SizedBox(height: Tk.s3),
          Text(
            '设备回报：${deps.ancModeLabel(s.ancModeId)}'
            '${s.ancLevel == null ? '' : ' · 强度 ${s.ancLevel}'}',
            style: Tk.note,
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------------ game

  Widget _game() {
    final known = s.gameEnabled != null;
    return AppCard(
      title: '低延迟模式',
      children: [
        ToggleRow(
          title: '游戏模式',
          state: !s.gameSupported
              ? '当前协议或产品配置没有这个功能'
              : known
              ? '设备回报：${s.gameEnabled! ? '开启' : '关闭'}'
              : '状态未知，先刷新状态再切换',
          value: s.gameEnabled ?? false,
          onChanged: deps.controls && s.gameSupported && known
              ? (value) => deps.run(() => deps.model.setGameEnabled(value))
              : null,
        ),
        if (s.gameSupported && !known) ...[
          const SizedBox(height: Tk.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: deps.idle && deps.connected
                  ? () => deps.run(deps.model.refreshStatus)
                  : null,
              child: const Text('刷新状态'),
            ),
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------------------- EQ

  Widget _eq() {
    final config = s.eqConfig;
    final valid = config != null && config.valid;
    final reported = s.eqGains;
    final reportedValid =
        valid &&
        reported != null &&
        reported.length == 10 &&
        reported.every((g) => g >= config.minGain && g <= config.maxGain);
    final gains = _draftEq ?? (reportedValid ? reported : null);
    final enabled = deps.controls && s.eqSupported && valid;
    final dirty = _draftEq != null;

    return AppCard(
      title: '均衡器',
      trailing: dirty
          ? const StatusDot(colour: Tk.warn, label: '草稿未发送')
          : Text(reportedValid ? '设备回报' : '未回报', style: Tk.label),
      children: [
        if (s.eqPresets.isNotEmpty) ...[
          const FieldLabel('预设'),
          ChoiceRow(
            children: [
              for (final preset in s.eqPresets)
                Choice(
                  label: preset.label,
                  selected: s.eqPresetId == preset.id,
                  onTap: deps.controls && s.eqSupported
                      ? () =>
                            deps.run(() => deps.model.selectEqPreset(preset.id))
                      : null,
                ),
            ],
          ),
          const SizedBox(height: Tk.s5),
        ],
        if (!valid)
          const EmptyNote('没有有效的 10 段产品配置，界面不会假设频率或增益范围。')
        else ...[
          FieldLabel(
            '10 段增益（${config.minGain} … ${config.maxGain} ${config.unit}）',
          ),
          _bands(config, gains, enabled),
          const SizedBox(height: Tk.s4),
          if (gains == null)
            Row(
              children: [
                OutlinedButton(
                  onPressed: enabled
                      ? () => setState(
                          () => _draftEq = List<int>.filled(
                            10,
                            0.clamp(config.minGain, config.maxGain).toInt(),
                          ),
                        )
                      : null,
                  child: const Text('新建草稿'),
                ),
                const SizedBox(width: Tk.s3),
                Expanded(
                  child: Text('设备没有回报 EQ。草稿是你要发送的值，不是当前状态。', style: Tk.note),
                ),
              ],
            )
          else
            Row(
              children: [
                FilledButton(
                  onPressed: enabled && dirty
                      ? () => deps.run(
                          () => deps.model.setEqualizer(
                            List<int>.unmodifiable(_draftEq!),
                          ),
                        )
                      : null,
                  child: const Text('发送'),
                ),
                const SizedBox(width: Tk.s3),
                OutlinedButton(
                  onPressed: dirty && deps.idle
                      ? () => setState(() => _draftEq = null)
                      : null,
                  child: Text(reportedValid ? '还原为设备值' : '清除草稿'),
                ),
              ],
            ),
        ],
      ],
    );
  }

  /// Ten vertical faders in one strip, the way an equaliser is read.
  Widget _bands(UiEqConfig config, List<int>? gains, bool enabled) {
    final min = config.minGain.toDouble();
    final max = config.maxGain.toDouble();
    final divisions = config.maxGain - config.minGain;
    Widget band(int index) {
      final value = gains?[index];
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value == null ? '—' : '$value',
            style: Tk.label.copyWith(color: value == null ? Tk.muted : Tk.ink),
          ),
          const SizedBox(height: Tk.s2),
          SizedBox(
            height: 150,
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                value: (value?.toDouble() ?? 0).clamp(min, max).toDouble(),
                min: min,
                max: max,
                divisions: divisions > 0 ? divisions : null,
                onChanged: enabled && gains != null
                    ? (v) => setState(() {
                        final next = List<int>.of(gains);
                        next[index] = v.round();
                        _draftEq = next;
                      })
                    : null,
              ),
            ),
          ),
          const SizedBox(height: Tk.s2),
          SizedBox(
            width: 44,
            child: Text(
              config.bandLabels[index],
              textAlign: TextAlign.center,
              style: Tk.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = [for (var i = 0; i < 10; i++) band(i)];
        if (constraints.maxWidth >= 520) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [for (final column in columns) Expanded(child: column)],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final column in columns)
                Padding(
                  padding: const EdgeInsets.only(right: Tk.s2),
                  child: SizedBox(width: 48, child: column),
                ),
            ],
          ),
        );
      },
    );
  }
}
