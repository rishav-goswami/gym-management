import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gym_core/gym_core.dart';

class GymBrandMark extends StatelessWidget {
  const GymBrandMark({required this.membership, this.size = 36, super.key});

  final GymMembership membership;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Center(
        child: Text(
          membership.gymName.isEmpty
              ? 'G'
              : membership.gymName.characters.first.toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
            fontSize: size * .42,
          ),
        ),
      ),
    );
    return Semantics(
      image: true,
      label: '${membership.gymName} logo',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .24),
        child: SizedBox.square(
          dimension: size,
          child: membership.logoUrl == null || membership.logoUrl!.isEmpty
              ? fallback
              : CachedNetworkImage(
                  imageUrl: membership.logoUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => fallback,
                  errorWidget: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}
