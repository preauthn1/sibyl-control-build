import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// The log, and the honest statement about what this app does and does not
/// know. Both used to be repeated on every screen; they live here.
class LogPage extends StatelessWidget {
  const LogPage({super.key, required this.deps});
  final AppDeps deps;

  @override
  Widget build(BuildContext context) {
    final s = deps.s;
    // The controller keeps the newest entry first, which is what you need
    // right after an operation, so the newest stays at the top.
    final entries = s.logs.take(200).toList();
    return PageBody(
      children: [
        AppCard(
          title: '日志',
          subtitle: s.logs.length > entries.length
              ? '${s.logs.length} 条 · 显示最新 ${entries.length} 条'
              : '${s.logs.length} 条',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: entries.isEmpty
                    ? null
                    : () => _copy(context, entries),
                child: const Text('复制'),
              ),
              const SizedBox(width: Tk.s2),
              OutlinedButton(
                onPressed: deps.idle && s.logs.isNotEmpty
                    ? () => _clear(context)
                    : null,
                style: OutlinedButton.styleFrom(foregroundColor: Tk.danger),
                child: const Text('清空'),
              ),
            ],
          ),
          children: [
            if (entries.isEmpty)
              const EmptyNote('暂无日志。日志只来自真实控制器，不会生成收发记录。')
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 420),
                padding: const EdgeInsets.all(Tk.s3),
                decoration: BoxDecoration(
                  color: Tk.surfaceSunk,
                  border: Border.all(color: Tk.line),
                  borderRadius: BorderRadius.circular(Tk.rMd),
                ),
                child: Scrollbar(
                  child: ListView.builder(
                    primary: false,
                    shrinkWrap: true,
                    itemCount: entries.length,
                    itemBuilder: (context, index) =>
                        _Entry(entry: entries[index]),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Tk.s5),
        AppCard(
          title: '这个界面能保证什么',
          children: [
            _line('显示的电量、降噪模式、EQ 和开关状态全部来自设备回报；没有回报就显示“—”。'),
            _line('发送成功只说明指令已下发，不代表设备已经执行；执行结果以随后的回报为准。'),
            _line('可用功能由产品配置决定。普通 BLE、QCC BLE、RTK 三种协议的编码和能力互不通用。'),
            _line(
              '硬件互操作性'
              '${deps.s.hardwareVerified ? '已由控制器标记为已验证' : '尚未验证：静态协议分析不等于设备兼容'}。',
            ),
            _line('不含 OTA、固件写入和恢复出厂功能。'),
            _line('日志里的地址和凭据由控制器脱敏；产品配置只保存在本机。'),
          ],
        ),
      ],
    );
  }

  void _copy(BuildContext context, List<UiLogEntry> entries) {
    Clipboard.setData(
      ClipboardData(
        text: entries
            .map((e) => '${e.time} [${e.level}] ${e.message}')
            .join('\n'),
      ),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制可见日志')));
  }

  Future<void> _clear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空日志'),
        content: const Text('本机的协议与事件记录会被删除，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Tk.danger),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) await deps.run(deps.model.clearLogs);
  }

  Widget _line(String text) => Padding(
    padding: const EdgeInsets.only(bottom: Tk.s3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 9),
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: Tk.muted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: Tk.s3),
        Expanded(child: Text(text, style: Tk.body)),
      ],
    ),
  );
}

/// One log line: time and level on the monospace grid, the message in the
/// reading face so Chinese text keeps its normal spacing.
class _Entry extends StatelessWidget {
  const _Entry({required this.entry});
  final UiLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final colour = switch (entry.level) {
      'ERROR' => Tk.danger,
      'WARN' => Tk.warn,
      _ => Tk.muted,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: Tk.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(entry.time, style: Tk.mono.copyWith(color: Tk.muted)),
          const SizedBox(width: Tk.s3),
          SizedBox(
            width: 46,
            child: Text(entry.level, style: Tk.mono.copyWith(color: colour)),
          ),
          const SizedBox(width: Tk.s2),
          Expanded(child: SelectableText(entry.message, style: Tk.body)),
        ],
      ),
    );
  }
}
