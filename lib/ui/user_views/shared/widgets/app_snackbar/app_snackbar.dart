import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

// ===========================================================
//  APP SNACKBAR v2 – Modern, vivid colors (no theme dependency)
// ===========================================================
//  Quick use:
//    AppSnackBar.show(context, 'Saved');           // blue info
//    AppSnackBar.success(context, 'Done!');        // green
//    AppSnackBar.warning(context, 'Be careful');   // yellow
//    AppSnackBar.error(context, 'Failed');         // red
// -----------------------------------------------------------
//  Design tweaks:
//  • Custom vibrant palette (Material Design brand tints)
//  • Subtle drop shadow + 14‑px text + icon
//  • Floating with 12‑px radius, consistent margin
//  • API unchanged – just replace file and hot‑restart
// ===========================================================

enum SnackType { info, success, warning, error }

class AppSnackBar {
  // Public helpers
  static void show(
      BuildContext context,
      String message, {
        SnackType type = SnackType.info,
        Duration duration = const Duration(seconds: 3),
      }) {
    final cfg = _palette[type]!;

    final bar = SnackBar(
      content: Row(
        children: [
          Icon(cfg.icon, color: cfg.fg, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cfg.fg, fontSize: 14, height: 1.3),
            ),
          ),
        ],
      ),
      backgroundColor: cfg.bg,
      elevation: 8,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: duration,
    );

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(bar);
  }

  // Convenience wrappers
  static void success(BuildContext c, String m, {Duration? d}) =>
      show(c, m, type: SnackType.success, duration: d ?? const Duration(seconds: 3));
  static void warning(BuildContext c, String m, {Duration? d}) =>
      show(c, m, type: SnackType.warning, duration: d ?? const Duration(seconds: 3));
  static void error(BuildContext c, String m, {Duration? d}) =>
      show(c, m, type: SnackType.error, duration: d ?? const Duration(seconds: 3));

  // ---------------------------------------------------------
  // Private static palette (no theme dependency)
  // ---------------------------------------------------------
  static final Map<SnackType, _Cfg> _palette = {
    SnackType.info: _Cfg(const Color(0xFF2196F3), Colors.white, Ionicons.information_circle_outline),
    SnackType.success: _Cfg(const Color(0xFF4CAF50), Colors.white, Icons.check_circle_outline),
    SnackType.warning: _Cfg(const Color(0xFFFFC107), Colors.black87, Icons.warning_amber_rounded),
    SnackType.error: _Cfg(const Color(0xFFF44336), Colors.white, Icons.error_outline_rounded),
  };
}

class _Cfg {
  const _Cfg(this.bg, this.fg, this.icon);
  final Color bg;
  final Color fg;
  final IconData icon;
}