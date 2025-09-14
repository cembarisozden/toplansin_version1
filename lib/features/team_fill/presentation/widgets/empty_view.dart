import 'package:flutter/material.dart';

class EmptyView extends StatelessWidget {
  const EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox, size: 40),
            const SizedBox(height: 8),
            const Text('Bu ölçütlerde açık ilan yok.'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                // TODO: ilan açma sayfası
              },
              icon: const Icon(Icons.add),
              label: const Text('İlan Aç'),
            ),
          ],
        ),
      ),
    );
  }
}