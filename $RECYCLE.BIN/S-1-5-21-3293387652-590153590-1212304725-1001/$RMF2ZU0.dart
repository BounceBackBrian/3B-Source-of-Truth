import 'package:flutter/material.dart';
import 'package:source_of_truth/features/profile/providers/profile_provider.dart';

class TopFriendsCarousel extends StatelessWidget {
  final List<FriendPreview> friends;

  const TopFriendsCarousel({super.key, required this.friends});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: friends.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final friend = friends[index];
          return SizedBox(
            width: 82,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: cs.primary.withOpacity(0.12),
                  child: Text(
                    friend.name.characters.first.toUpperCase(),
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  friend.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
