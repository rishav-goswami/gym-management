// A reusable card that makes its children tappable as a group.
import 'package:flutter/material.dart';

class TappableSectionCard extends StatelessWidget {
  final VoidCallback onTap;
  final List<Widget> children;

  const TappableSectionCard({
    super.key,
    required this.onTap,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      clipBehavior: Clip
          .antiAlias, // Ensures the InkWell ripple effect is clipped to the card's shape
      child: InkWell(
        onTap: onTap,
        child: Column(children: children),
      ),
    );
  }
}
