import 'package:flutter/material.dart';

/// One system for the whole app: one palette, one spacing scale, one radius
/// family, one type scale, one button pair, one card recipe, one chip.
/// Nothing below is re-declared in a page; pages only consume these tokens.
class Tk {
  Tk._();

  // Palette "blue-black-cornflower" (dark-neutral, technical subject).
  // The interface stays neutral; the accent is the only tinted surface and
  // appears on the primary button, the selected chip, state marks and focus.
  // No violet or lavender anywhere.
  static const bg = Color(0xFF0A0D14);
  static const surface = Color(0xFF131824);
  static const surfaceSunk = Color(0xFF080B11);
  static const ink = Color(0xFFE9EDF3);
  static const muted = Color(0xFF8891A1);
  static const line = Color(0xFF232B3B);
  static const lineStrong = Color(0xFF34405A);
  static const accent = Color(0xFF5AB9FC);
  static const accentInk = Color(0xFF071019);
  static const ok = Color(0xFF5BD6A4);
  static const warn = Color(0xFFF0B429);
  static const danger = Color(0xFFF0616B);

  // Spacing scale. Every gap, margin and padding is one of these.
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;
  static const s7 = 48.0;

  // Radius family "sharp": cards 8, panels 6, controls 4.
  static const rLg = 8.0;
  static const rMd = 6.0;
  static const rSm = 4.0;

  // Type scale. One size per kind of element, app-wide. Nothing under 12.
  static const display = TextStyle(
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: ink,
  );
  static const h2 = TextStyle(
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: ink,
  );
  static const title = TextStyle(
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: ink,
  );
  static const body = TextStyle(fontSize: 15, height: 1.55, color: ink);
  static const label = TextStyle(
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w500,
    color: muted,
  );
  static const note = TextStyle(fontSize: 14, height: 1.55, color: muted);
  static const stat = TextStyle(
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w600,
    color: ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const mono = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['Noto Sans Mono', 'DejaVu Sans Mono', 'monospace'],
    fontSize: 13,
    height: 1.5,
    color: ink,
  );

  // Motion: one duration set, no bounce, no overshoot.
  static const mIn = Duration(milliseconds: 140);
  static const mOut = Duration(milliseconds: 200);
  static const ease = Cubic(0.2, 0.8, 0.2, 1);

  static ThemeData theme() {
    const scheme = ColorScheme.dark(
      primary: accent,
      onPrimary: accentInk,
      secondary: accent,
      onSecondary: accentInk,
      surface: surface,
      onSurface: ink,
      error: danger,
      onError: accentInk,
      outline: lineStrong,
      outlineVariant: line,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      dividerTheme: const DividerThemeData(color: line, space: 1, thickness: 1),
      iconTheme: const IconThemeData(color: muted, size: 18),
      // One button pair: filled = the single main action of a view,
      // outlined = every secondary. Text buttons only for minor/destructive.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: accentInk,
          disabledBackgroundColor: line,
          disabledForegroundColor: muted,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: s4),
          textStyle: title,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(rSm)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          disabledForegroundColor: muted,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: s4),
          textStyle: title,
          side: const BorderSide(color: lineStrong),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(rSm)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: muted,
          disabledForegroundColor: line,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: s3),
          textStyle: label.copyWith(color: null),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(rSm)),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSunk,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: s3,
          vertical: s3,
        ),
        labelStyle: label,
        hintStyle: note,
        helperStyle: note,
        errorStyle: note.copyWith(color: danger),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(rSm)),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(rSm)),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(rSm)),
          borderSide: BorderSide(color: accent, width: 2),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: line,
        thumbColor: accent,
        disabledActiveTrackColor: lineStrong,
        disabledInactiveTrackColor: line,
        disabledThumbColor: lineStrong,
        trackHeight: 3,
        showValueIndicator: ShowValueIndicator.never,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accentInk : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : surfaceSunk,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(lineStrong),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: h2,
        contentTextStyle: body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(rLg)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: body,
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: Colors.transparent,
        linearMinHeight: 2,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceSunk,
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(rSm),
        ),
        textStyle: note.copyWith(color: ink),
      ),
    );
  }
}
