import 'package:flutter/material.dart';
import 'package:toplansin/features/team_fill/domain/entities/fill_request.dart';

class RequestCard extends StatelessWidget {
  const RequestCard({required this.item});
  final FillRequest item;

  @override
  Widget build(BuildContext context) {
    final remaining = (item.neededCount - item.acceptedCount).clamp(0, item.neededCount);
    final dateStr = _formatLocalDateTime(item.matchTime);

    return InkWell(
      onTap: () {
        // TODO: Detay sayfasına navigate; item.id gönder
        // Navigator.pushNamed(context, '/team-fill/detail', arguments: item.id);
      },
      child: Card(
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Sol blok (içerik)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: -6,
                      children: [
                        _Chip(text: item.city),
                        if (item.level != null && item.level!.trim().isNotEmpty)
                          _Chip(text: item.level!.trim()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dateStr,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kalan: $remaining / Toplam: ${item.neededCount}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    if (item.positions != null && item.positions!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Pozisyonlar: ${_shortPositions(item.positions!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (item.note != null && item.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.note!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  static String _shortPositions(List<String> positions, {int max = 3}) {
    if (positions.length <= max) return positions.join(', ');
    final head = positions.take(max).join(', ');
    final rest = positions.length - max;
    return '$head +$rest';
  }

  /// Basit TR format: "27 Ağu Çar • 21:30"
  static String _formatLocalDateTime(DateTime utc) {
    final dt = utc.toLocal();
    const months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    const weekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final m = months[dt.month - 1];
    final w = weekdays[(dt.weekday % 7)]; // 1=Pzt…7=Paz
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} $m $w • $hh:$mm';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}