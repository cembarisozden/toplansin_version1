import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math' as math;

// ===========================================================
//  NANO LOADER – OverlayEntry‑based, always closes correctly
// ===========================================================
//  Public API (unchanged):
//    showLoader(context);   // open loader overlay
//    hideLoader();          // close loader overlay
//
//  Design tweaks v3
//  • OverlayEntry instead of dialog → unaffected by other dialogs
//  • 3‑dot wave with larger initial scale (0.3‑1.0) → anında fark edilir
//  • Single AnimationController → minimal CPU/GPU
//
// ===========================================================

OverlayEntry? _loaderEntry; // holds current loader

// ──────────── PUBLIC HELPERS ────────────
void showLoader(BuildContext context) {
  if (_loaderEntry != null) return; // already showing

  final size = MediaQuery.of(context).size;
  final sigma = size.shortestSide / 35; // adaptive blur

  _loaderEntry = OverlayEntry(
    builder: (_) => Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: Container(color: Colors.black38),
          ),
        ),
        const Center(child: _WaveDots()),
      ],
    ),
  );

  Overlay.of(context, rootOverlay: true).insert(_loaderEntry!);
}

void hideLoader() {
  _loaderEntry?..remove();
  _loaderEntry = null;
}

// ───────────── DOT SPINNER ─────────────
class _WaveDots extends StatefulWidget {
  const _WaveDots({
    this.dotSize = 16,
    this.gap = 10,
    this.duration = const Duration(milliseconds: 1200),
    super.key,
  });

  final double dotSize;
  final double gap;
  final Duration duration;

  @override
  State<_WaveDots> createState() => _WaveDotsState();
}

class _WaveDotsState extends State<_WaveDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
  AnimationController(vsync: this, duration: widget.duration)..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Colors.white;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final v = _ctrl.value * 2 * math.pi; // 0 – 2π
        const phases = [0.0, 2 * math.pi / 3, 4 * math.pi / 3];

        final dots = List.generate(3, (i) {
          // scale: 0.3 → 1.0 (daha belirgin başlangıç)
          final scale = 0.3 + 0.35 * (1 + math.sin(v + phases[i]));
          return Transform.scale(
            scale: scale,
            child: Container(
              width: widget.dotSize,
              height: widget.dotSize,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          );
        });

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dots[0],
            SizedBox(width: widget.gap),
            dots[1],
            SizedBox(width: widget.gap),
            dots[2],
          ],
        );
      },
    );
  }
}