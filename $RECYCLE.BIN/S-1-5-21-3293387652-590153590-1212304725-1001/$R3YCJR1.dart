import 'package:flutter/material.dart';

class PrivacyToggle extends StatelessWidget {
  final bool isPrivate;
  final ValueChanged<bool> onChanged;

  const PrivacyToggle({
    super.key,
    required this.isPrivate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Private profile',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Switch(value: isPrivate, onChanged: onChanged),
        ],
      ),
    );
  }
}
