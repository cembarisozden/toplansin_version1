import 'package:flutter/material.dart';

class SkeletonCard extends StatelessWidget {
  const SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final base = Theme
        .of(context)
        .colorScheme
        .onSurface
        .withOpacity(0.08);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                _box(width: 60, height: 20, color: base),
                const SizedBox(width: 8),
                _box(width: 40, height: 20, color: base),
              ],
            ),
            const SizedBox(height: 8),
            _box(width: double.infinity, height: 18, color: base),
            const SizedBox(height: 6),
            _box(width: 180, height: 14, color: base),
          ],
        ),
      ),
    );
  }

  Widget _box(
      {required double width, required double height, required Color color}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(6)),
    );
  }
}