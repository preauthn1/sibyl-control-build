import 'package:flutter/material.dart';

import 'theme.dart';

/// Shared parts. One card recipe, one chip, one switch row, one notice bar,
/// one meter. A page never invents a second version of any of these.

bool stillMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// The page column: one wrap, equal left and right edges at every width,
/// and a scrollbar that is always visible while the page overflows, so
/// nothing ever looks severed at the bottom of the window.
class PageBody extends StatefulWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;

  /// The one content width and the one gutter, shared with the header so
  /// every left edge in the app lines up.
  static const maxWidth = 900.0;
  static double gutter(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 520 ? Tk.s4 : Tk.s6;

  @override
  State<PageBody> createState() => _PageBodyState();
}

class _PageBodyState extends State<PageBody> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gutter = PageBody.gutter(context);
    return Scrollbar(
      controller: _scroll,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(gutter, Tk.s5, gutter, Tk.s7),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: PageBody.maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
          ),
        ),
      ),
    );
  }
}

/// The one card. Title, optional right-hand status, content. Never a box in a
/// box: a card's children are rows and controls, not further framed panels.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tk.surface,
        border: Border.all(color: Tk.line),
        borderRadius: BorderRadius.circular(Tk.rLg),
      ),
      padding: const EdgeInsets.all(Tk.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Tk.h2),
                    if (subtitle != null) ...[
                      const SizedBox(height: Tk.s1),
                      Text(subtitle!, style: Tk.note),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: Tk.s3),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: Tk.s4),
          ...children,
        ],
      ),
    );
  }
}

/// A small label above a group inside a card.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Tk.s2),
    child: Row(
      children: [
        Expanded(child: Text(text, style: Tk.label)),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

/// The one chip. Used for protocols, ANC modes and levels, EQ presets,
/// integer options and button functions — nothing else selects in this app.
class Choice extends StatelessWidget {
  const Choice({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    // The chip sizes to its label: no alignment property here, or the box
    // would expand to the full width it is offered.
    return Material(
      color: selected ? Tk.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(Tk.rSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Tk.rSm),
        child: AnimatedContainer(
          duration: Tk.mIn,
          curve: Tk.ease,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 34),
          padding: const EdgeInsets.symmetric(
            horizontal: Tk.s3,
            vertical: Tk.s2,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? Tk.accent
                  : enabled
                  ? Tk.lineStrong
                  : Tk.line,
            ),
            borderRadius: BorderRadius.circular(Tk.rSm),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              label,
              style: Tk.title.copyWith(
                color: selected
                    ? Tk.accentInk
                    : enabled
                    ? Tk.ink
                    : Tk.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of chips with the app's one gap.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: Tk.s2, runSpacing: Tk.s2, children: children);
}

enum NoticeTone { neutral, warn, danger }

/// One notice bar. A page shows at most one, and only when it blocks or warns.
class NoticeBar extends StatelessWidget {
  const NoticeBar({
    super.key,
    required this.text,
    this.tone = NoticeTone.neutral,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });
  final String text;
  final NoticeTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colour = switch (tone) {
      NoticeTone.neutral => Tk.accent,
      NoticeTone.warn => Tk.warn,
      NoticeTone.danger => Tk.danger,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(Tk.s4, Tk.s3, Tk.s2, Tk.s3),
      decoration: BoxDecoration(
        color: Tk.surface,
        border: Border(left: BorderSide(color: colour, width: 2)),
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(Tk.rMd),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(text, style: Tk.body)),
          if (actionLabel != null) ...[
            const SizedBox(width: Tk.s3),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: Tk.title.copyWith(color: colour),
              ),
            ),
          ],
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              tooltip: '关闭',
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}

/// Connection state as one dot plus one word.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.colour, required this.label});
  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
      ),
      const SizedBox(width: Tk.s2),
      Text(label, style: Tk.title),
    ],
  );
}

/// A reported value with its name. Unknown is "—", never a zero.
class Readout extends StatelessWidget {
  const Readout({super.key, required this.label, required this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Tk.s2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 108, child: Text(label, style: Tk.label)),
        Expanded(
          child: Text(
            value ?? '—',
            style: value == null ? Tk.body.copyWith(color: Tk.muted) : Tk.body,
          ),
        ),
      ],
    ),
  );
}

/// Battery meter. An unreported battery draws an empty muted track and "—",
/// so nothing can be misread as 0%.
class BatteryMeter extends StatelessWidget {
  const BatteryMeter({super.key, required this.label, required this.percent});
  final String label;
  final int? percent;

  @override
  Widget build(BuildContext context) {
    final value = percent;
    final low = value != null && value <= 20;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Tk.label),
        const SizedBox(height: Tk.s2),
        Text(
          value == null ? '—' : '$value%',
          style: value == null
              ? Tk.stat.copyWith(color: Tk.muted)
              : Tk.stat.copyWith(color: low ? Tk.warn : Tk.ink),
        ),
        const SizedBox(height: Tk.s3),
        SizedBox(
          height: 4,
          child: value == null
              ? const _DashedTrack()
              : ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(
                    children: [
                      Container(color: Tk.surfaceSunk),
                      FractionallySizedBox(
                        widthFactor: (value / 100).clamp(0.0, 1.0),
                        child: Container(color: low ? Tk.warn : Tk.accent),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// An unreported value: short dashes, never a full-width empty rail.
class _DashedTrack extends StatelessWidget {
  const _DashedTrack();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = (constraints.maxWidth / 10).floor().clamp(1, 40);
      return Row(
        children: [
          for (var i = 0; i < count; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(color: Tk.line),
              ),
            ),
        ],
      );
    },
  );
}

/// One switch row. Title, the device-reported state underneath, one switch.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.title,
    required this.state,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String state;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Tk.s2),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: onChanged == null
                    ? Tk.title.copyWith(color: Tk.muted)
                    : Tk.title,
              ),
              const SizedBox(height: Tk.s1),
              Text(state, style: Tk.note),
            ],
          ),
        ),
        const SizedBox(width: Tk.s3),
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}

/// A tappable row that answers the pointer: it lifts 2px and its border
/// brightens on hover, and presses in on click. Used for device rows.
class HoverRow extends StatefulWidget {
  const HoverRow({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<HoverRow> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final still = stillMotion(context);
    final lift = !enabled || still
        ? 0.0
        : _down
        ? 1.0
        : _hover
        ? -2.0
        : 0.0;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        child: AnimatedSlide(
          duration: _hover ? Tk.mIn : Tk.mOut,
          curve: Tk.ease,
          offset: Offset(0, lift / 56),
          child: Material(
            color: Tk.surfaceSunk,
            borderRadius: BorderRadius.circular(Tk.rMd),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(Tk.rMd),
              child: AnimatedContainer(
                duration: Tk.mIn,
                curve: Tk.ease,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _hover && enabled ? Tk.lineStrong : Tk.line,
                  ),
                  borderRadius: BorderRadius.circular(Tk.rMd),
                ),
                padding: const EdgeInsets.all(Tk.s4),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Signal strength as four bars; never a bare dBm number on its own line.
class SignalBars extends StatelessWidget {
  const SignalBars({super.key, required this.rssi});
  final int? rssi;

  @override
  Widget build(BuildContext context) {
    final value = rssi;
    final bars = value == null
        ? 0
        : value >= -55
        ? 4
        : value >= -67
        ? 3
        : value >= -80
        ? 2
        : 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 1; i <= 4; i++) ...[
          Container(
            width: 3,
            height: 4.0 + i * 3,
            decoration: BoxDecoration(
              color: i <= bars ? Tk.accent : Tk.line,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          if (i < 4) const SizedBox(width: 2),
        ],
        const SizedBox(width: Tk.s2),
        Text(value == null ? '信号未知' : '$value dBm', style: Tk.label),
      ],
    );
  }
}

/// The one empty state: a plain sentence, muted, never an apology card.
class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Tk.s4),
    child: Text(text, style: Tk.note),
  );
}

/// A numbered step on the connect path. Numbers, not radio circles: these
/// report progress, they are not a choice.
class StepRow extends StatelessWidget {
  const StepRow({
    super.key,
    required this.index,
    required this.done,
    required this.text,
    this.current = false,
  });
  final int index;
  final bool done;
  final bool current;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Tk.s2),
    child: Row(
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? Tk.ok : Colors.transparent,
            border: Border.all(
              color: done
                  ? Tk.ok
                  : current
                  ? Tk.accent
                  : Tk.lineStrong,
            ),
            borderRadius: BorderRadius.circular(Tk.rSm),
          ),
          child: done
              ? const Icon(Icons.check, size: 13, color: Tk.accentInk)
              : Text(
                  '$index',
                  style: Tk.label.copyWith(
                    color: current ? Tk.accent : Tk.muted,
                  ),
                ),
        ),
        const SizedBox(width: Tk.s3),
        Expanded(
          child: Text(
            text,
            style: done ? Tk.body.copyWith(color: Tk.muted) : Tk.body,
          ),
        ),
      ],
    ),
  );
}
