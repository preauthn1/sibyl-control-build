import 'models.dart';

/// The four places in the app. One screen holds one of them at a time.
enum AppTab { device, sound, settings, log }

/// Why controls are not available, in one sentence, with the one action that
/// fixes it. The UI states this ONCE per screen instead of repeating a
/// different apology under every control.
class Block {
  const Block(this.text, {this.actionLabel, this.tab});
  final String text;
  final String? actionLabel;
  final AppTab? tab;
}

/// Everything a page needs. The gates below are the same predicates the
/// previous single-page UI used; only their presentation changed.
class AppDeps {
  const AppDeps({
    required this.s,
    required this.model,
    required this.running,
    required this.run,
    required this.go,
  });

  final UiSnapshot s;
  final EarbudViewModel model;
  final bool running;

  /// Runs one view-model call under the single-operation lock.
  final Future<void> Function(Future<void> Function()) run;

  /// Moves to another tab (used by a block's action).
  final void Function(AppTab) go;

  bool get idle => !s.busy && !running;
  bool get connected => s.connection == UiConnection.connected;
  bool get disconnected => s.connection == UiConnection.disconnected;
  bool get protocolReady =>
      s.protocolId != null && s.protocols.any((p) => p.id == s.protocolId);
  bool get controls =>
      idle && connected && s.configurationReady && protocolReady;

  String get connectionLabel => switch (s.connection) {
    UiConnection.disconnected => '未连接',
    UiConnection.connecting => '正在连接',
    UiConnection.connected => '已连接',
    UiConnection.disconnecting => '正在断开',
  };

  UiProtocol? get protocol {
    for (final p in s.protocols) {
      if (p.id == s.protocolId) return p;
    }
    return null;
  }

  /// The first unmet precondition for sending anything to the device.
  Block? get block {
    if (!connected) {
      return const Block('控制需要先连接耳机。', actionLabel: '去连接', tab: AppTab.device);
    }
    if (!protocolReady) {
      return const Block('控制器未提供可用协议，无法下发指令。');
    }
    if (!s.configurationReady) {
      return const Block(
        '尚未载入产品配置，功能范围未知，控制保持关闭。',
        actionLabel: '载入配置',
        tab: AppTab.device,
      );
    }
    if (!idle) return const Block('正在执行上一条操作。');
    return null;
  }

  /// The label a mode id should be shown with. Raw ids are only exposed when
  /// the loaded configuration does not name them.
  String ancModeLabel(int? id) {
    if (id == null) return '未知';
    for (final m in s.ancModes) {
      if (m.id == id) return m.label;
    }
    return '模式 $id（不在配置中）';
  }
}
