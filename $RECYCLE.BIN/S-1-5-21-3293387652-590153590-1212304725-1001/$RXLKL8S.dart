import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/profile_provider.dart';
import '../widgets/action_buttons.dart';
import '../widgets/badge_row.dart';
import '../widgets/bio_card.dart';
import '../widgets/privacy_toggle.dart';
import '../widgets/profile_header.dart';
import '../widgets/top_friends_carousel.dart';
import '../widgets/top_songs_grid.dart';

class UserProfileScreen extends ConsumerWidget {
  static const String routePattern = '/profile/:userId';

  static String locationFor(String userId) => '/profile/$userId';

  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(profileControllerProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(profileControllerProvider(userId)),
        ),
        data: (viewState) => _ProfileContent(
          userId: userId,
          viewState: viewState,
          onSetPrivate: (isPrivate) {
            final privacy = isPrivate ? Privacy.private : Privacy.public;
            ref
                .read(profileControllerProvider(userId).notifier)
                .setOverallPrivacy(userId: userId, privacy: privacy);
          },
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final String userId;
  final ProfileViewState viewState;
  final ValueChanged<bool> onSetPrivate;

  const _ProfileContent({
    required this.userId,
    required this.viewState,
    required this.onSetPrivate,
  });

  @override
  Widget build(BuildContext context) {
    final profile = viewState.profile;

    if (viewState.isPrivateGate) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('This profile is private.'),
        ),
      );
    }

    if (profile == null) {
      return const Center(child: Text('Profile unavailable.'));
    }

    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 980
        ? 3
        : width >= 680
        ? 2
        : 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileHeader(
                heroTag: 'profile-${profile.userId}',
                name: profile.name,
                handle: profile.handle,
                photoUrl: profile.photoUrl,
              ),
              const SizedBox(height: 14),
              BioCard(bio: profile.bio),
              const SizedBox(height: 12),
              if (profile.location != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    profile.location!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              if (viewState.isOwner)
                PrivacyToggle(
                  isPrivate: profile.overallPrivacy == Privacy.private,
                  onChanged: onSetPrivate,
                ),
              if (viewState.isOwner) const SizedBox(height: 12),
              ActionButtons(
                onEdit: () {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Edit profile coming soon.'),
                      ),
                    );
                },
                onShare: () {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Share profile coming soon.'),
                      ),
                    );
                },
              ),
              const SizedBox(height: 18),
              BadgeRow(employment: profile.employment, boosts: profile.boosts),
              const SizedBox(height: 18),
              TopSongsGrid(songs: profile.topSongs, columns: columns),
              const SizedBox(height: 18),
              TopFriendsCarousel(friends: profile.topFriends),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Could not load profile',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
