import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../providers/profile_provider.dart';

class TopFriendsCarousel extends StatelessWidget {
  final List<TopFriend> friends;

  const TopFriendsCarousel({super.key, required this.friends});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (friends.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Text(
          'No top friends shared.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    return SizedBox(
      height: 122,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: friends.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final friend = friends[index];
          return SizedBox(
            width: 88,
            child: Column(
              children: [
                _FriendAvatar(friend: friend),
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
                if ((friend.handle ?? '').isNotEmpty)
                  Text(
                    friend.handle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FriendAvatar extends StatelessWidget {
  final TopFriend friend;

  const _FriendAvatar({required this.friend});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipOval(
      child: SizedBox(
        width: 58,
        height: 58,
        child: friend.photoUrl == null || friend.photoUrl!.isEmpty
            ? Container(
                color: cs.primary.withOpacity(0.12),
                child: Center(
                  child: Text(
                    friend.name.characters.first.toUpperCase(),
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              )
            : CachedNetworkImage(
                imageUrl: friend.photoUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: cs.surfaceContainerHighest,
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: cs.primary.withOpacity(0.12),
                  child: Center(
                    child: Text(
                      friend.name.characters.first.toUpperCase(),
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
