import 'package:flutter/material.dart';
import 'package:toplansin/features/team_fill/presentation/widgets/skeleton_card.dart';

class LoadingList extends StatelessWidget {
  const LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => const SkeletonCard(),
    );
  }
}