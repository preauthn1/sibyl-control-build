import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'models.dart';
import 'pages/device_page.dart';
import 'pages/log_page.dart';
import 'pages/settings_page.dart';
import 'pages/sound_page.dart';
import 'theme.dart';
import 'widgets.dart';

// The UI contract lives in models.dart; it is re-exported so the controller
// keeps importing this one file and nothing in it changed.
export 'models.dart';

class EarbudApp extends StatelessWidget {
  const EarbudApp({super.key, required this.model});
  final EarbudViewModel model;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Sibyl Control',
    theme: Tk.theme(),
    home: _Shell(model: model),
  );
}

class _Shell extends StatefulWidget {
  const _Shell({required this.model});
  final EarbudViewModel model;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  AppTab _tab = AppTab.device;
  bool _running = false;
  String? _error;

  /// One operation at a time, one place that reports failures.
  Future<void> _run(Future<void> Function() operation) async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      await operation();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _go(AppTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<UiSnapshot>(
    valueListenable: widget.model.snapshot,
    builder: (context, s, _) {
      final deps = AppDeps(
        s: s,
        model: widget.model,
        running: _running,
        run: _run,
        go: _go,
      );
      final busy = _running || s.busy;
      final wide = MediaQuery.sizeOf(context).width >= 900;
      final page = switch (_tab) {
        AppTab.device => DevicePage(deps: deps),
        AppTab.sound => SoundPage(deps: deps),
        AppTab.settings => SettingsPage(deps: deps),
        AppTab.log => LogPage(deps: deps),
      };
      final body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(deps: deps, showPower: _tab != AppTab.device),
          // Always two pixels tall, so starting work never shifts the page.
          SizedBox(
            height: 2,
            child: busy ? const LinearProgressIndicator() : null,
          ),
          if (s.preview) _Strip(colour: Tk.warn, text: '演示模式 · 页面上的数据不是来自蓝牙设备'),
          if (_error != null)
            _Strip(
              colour: Tk.danger,
              text: _error!,
              onClose: () => setState(() => _error = null),
            ),
          Expanded(child: page),
        ],
      );
      return Scaffold(
        body: SafeArea(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Rail(
                      tab: _tab,
                      onSelect: _go,
                      snapshot: s,
                      locked: !deps.controls,
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                )
              : body,
        ),
        bottomNavigationBar: wide
            ? null
            : _Bar(tab: _tab, onSelect: _go, locked: !deps.controls),
      );
    },
  );
}

/// Destinations, in the order the work happens.
const _destinations = <(AppTab, IconData, String)>[
  (AppTab.device, Icons.bluetooth_rounded, '设备'),
  (AppTab.sound, Icons.graphic_eq_rounded, '声音'),
  (AppTab.settings, Icons.tune_rounded, '设置'),
  (AppTab.log, Icons.article_outlined, '日志'),
];

class _Header extends StatelessWidget {
  const _Header({required this.deps, required this.showPower});
  final AppDeps deps;

  /// Battery is stated once per screen: in the bar everywhere except the
  /// device page, which shows the three meters in full.
  final bool showPower;

  @override
  Widget build(BuildContext context) {
    final s = deps.s;
    final connected = deps.connected;
    final colour = switch (s.connection) {
      UiConnection.connected => Tk.ok,
      UiConnection.connecting || UiConnection.disconnecting => Tk.warn,
      UiConnection.disconnected => Tk.muted,
    };
    final narrow = MediaQuery.sizeOf(context).width < 640;
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: PageBody.gutter(context)),
      decoration: const BoxDecoration(
        color: Tk.surface,
        border: Border(bottom: BorderSide(color: Tk.line)),
      ),
      alignment: Alignment.center,
      child: _Wrap(
        child: Row(
          children: [
            // The left group takes the free space, so the status always ends
            // on the page's right line. A loose Flexible beside a Spacer
            // would leave the end of the row short.
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Tk.accent,
                      borderRadius: BorderRadius.circular(Tk.rSm),
                    ),
                    child: const Text(
                      'S',
                      style: TextStyle(
                        color: Tk.accentInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: Tk.s3),
                  Text('Sibyl Control', style: Tk.display),
                  if (!narrow &&
                      connected &&
                      showPower &&
                      s.deviceName != null) ...[
                    const SizedBox(width: Tk.s3),
                    Flexible(
                      child: Text(
                        s.deviceName!,
                        style: Tk.note,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (connected && showPower && !narrow) ...[
              _Cell(label: 'L', percent: s.leftBattery),
              const SizedBox(width: Tk.s4),
              _Cell(label: 'R', percent: s.rightBattery),
              const SizedBox(width: Tk.s4),
              _Cell(label: '仓', percent: s.caseBattery),
              const SizedBox(width: Tk.s5),
            ],
            StatusDot(colour: colour, label: deps.connectionLabel),
          ],
        ),
      ),
    );
  }
}

/// The one content wrap, shared by the header, the strips and every page,
/// so one left line and one right line run down the whole window.
class _Wrap extends StatelessWidget {
  const _Wrap({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: PageBody.maxWidth),
    child: child,
  );
}

/// One battery value in the header. Unknown reads "—".
class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.percent});
  final String label;
  final int? percent;

  @override
  Widget build(BuildContext context) {
    final value = percent != null && percent! >= 0 && percent! <= 100
        ? percent
        : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Tk.label),
        const SizedBox(width: Tk.s2),
        Text(
          value == null ? '—' : '$value%',
          style: Tk.title.copyWith(color: value == null ? Tk.muted : Tk.ink),
        ),
      ],
    );
  }
}

/// A one-line strip under the header: preview warning or the last failure.
/// It sits on the same wrap as the header and the page below it.
class _Strip extends StatelessWidget {
  const _Strip({required this.colour, required this.text, this.onClose});
  final Color colour;
  final String text;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: PageBody.gutter(context)),
    decoration: const BoxDecoration(
      color: Tk.surface,
      border: Border(bottom: BorderSide(color: Tk.line)),
    ),
    alignment: Alignment.center,
    child: _Wrap(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Tk.s2),
        child: Row(
          children: [
            Container(width: 2, height: 20, color: colour),
            const SizedBox(width: Tk.s3),
            Expanded(
              child: Text(text, style: Tk.body.copyWith(color: colour)),
            ),
            if (onClose != null)
              IconButton(
                onPressed: onClose,
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                tooltip: '关闭',
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Desktop navigation: one word per destination, a 2px bar on the current one.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.tab,
    required this.onSelect,
    required this.snapshot,
    required this.locked,
  });
  final AppTab tab;
  final ValueChanged<AppTab> onSelect;
  final UiSnapshot snapshot;

  /// Sound and settings can be opened at any time, but they are marked while
  /// the device cannot be controlled, so the empty panes are no surprise.
  final bool locked;

  @override
  Widget build(BuildContext context) => Container(
    width: 184,
    color: Tk.surface,
    padding: const EdgeInsets.symmetric(vertical: Tk.s4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (destination, icon, label) in _destinations)
          _RailItem(
            icon: icon,
            label: label,
            selected: destination == tab,
            locked:
                locked &&
                (destination == AppTab.sound || destination == AppTab.settings),
            onTap: () => onSelect(destination),
          ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tk.s4),
          child: Text(
            snapshot.configurationReady ? '配置已载入' : '未载入产品配置',
            style: Tk.label,
          ),
        ),
      ],
    ),
  );
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.locked,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: AnimatedContainer(
      duration: Tk.mIn,
      curve: Tk.ease,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: Tk.s4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: selected ? Tk.accent : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: selected ? Tk.accent : Tk.muted),
          const SizedBox(width: Tk.s3),
          Expanded(
            child: Text(
              label,
              style: Tk.title.copyWith(color: selected ? Tk.ink : Tk.muted),
            ),
          ),
          if (locked)
            const Tooltip(
              message: '连接设备并载入产品配置后可用',
              child: Icon(Icons.lock_outline, size: 13, color: Tk.muted),
            ),
        ],
      ),
    ),
  );
}

/// Phone navigation: the same four words, the same 2px bar.
class _Bar extends StatelessWidget {
  const _Bar({required this.tab, required this.onSelect, required this.locked});
  final AppTab tab;
  final ValueChanged<AppTab> onSelect;
  final bool locked;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Tk.surface,
      border: Border(top: BorderSide(color: Tk.line)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            for (final (destination, icon, label) in _destinations)
              Expanded(
                child: InkWell(
                  onTap: () => onSelect(destination),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: destination == tab
                              ? Tk.accent
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              icon,
                              size: 18,
                              color: destination == tab ? Tk.accent : Tk.muted,
                            ),
                            if (locked &&
                                (destination == AppTab.sound ||
                                    destination == AppTab.settings))
                              const Positioned(
                                right: -6,
                                top: -2,
                                child: Icon(
                                  Icons.lock_outline,
                                  size: 11,
                                  color: Tk.muted,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: Tk.s1),
                        Text(
                          label,
                          style: Tk.label.copyWith(
                            color: destination == tab ? Tk.ink : Tk.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
