import 'package:flutter/material.dart';

class BioCard extends StatefulWidget {
  final String? bio;
  const BioCard({super.key, required this.bio});

  @override
  State<BioCard> createState() => _BioCardState();
}

class _BioCardState extends State<BioCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bio = widget.bio?.trim();

    if (bio == null || bio.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Text(
          'No bio yet.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.notes_outlined, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                bio,
                maxLines: _expanded ? 10 : 2,
                overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.25),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
