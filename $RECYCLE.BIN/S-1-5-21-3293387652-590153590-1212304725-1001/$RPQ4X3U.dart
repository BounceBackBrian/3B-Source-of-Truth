import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_header.dart';
import '../widgets/bio_card.dart';
import '../widgets/badge_row.dart';
import '../widgets/top_songs_grid.dart';
import '../widgets/top_friends_carousel.dart';
import '../widgets/action_buttons.dart';
import '../widgets/privacy_toggle.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(profileControllerProvider(widget.userId).notifier).load(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(profileControllerProvider(widget.userId));

    return Scaffold(
      body: SafeArea(
        child: asyncState.when(
          loading: () => const _ProfileLoading(),
          error: (e, _) => _ProfileError(
            message: 'Could not load profile.',
            details: e.toString(),
            onRetry: () async {
              await ref.read(profileControllerProvider(widget.userId).notifier).load(widget.userId);
            },
          ),
          data: (view) {
            if (view.isPrivateGate) {
              return const _PrivateGate();
            }
            final p = view.profile;
            if (p == null) {
              return const _ProfileError(message: 'Profile unavailable.');
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final isPhone = w < 600;
                final isTablet = w >= 600 && w < 1024;

                final columns = isPhone ? 1 : (isTablet ? 2 : 3);

                final padding = EdgeInsets.symmetric(
                  horizontal: isPhone ? 16 : (isTablet ? 24 : 32),
                  vertical: 16,
                );

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: padding,
                        child: ProfileHeader(
                          heroTag: 'profile_photo_${p.userId}',
                          name: p.name,
                          handle: p.handle,
                          photoUrl: p.photoUrl,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: padding.copyWith(top: 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BioCard(bio: p.bio),
                            const SizedBox(height: 12),
                            BadgeRow(
                              employment: p.employment,
                              boosts: p.boosts,
                            ),
                            const SizedBox(height: 16),
                            if (columns == 1) ...[
                              TopSongsGrid(
                                songs: p.topSongs,
                                columns: 3,
                              ),
                              const SizedBox(height: 16),
                              TopFriendsCarousel(
                                friends: p.topFriends,
                              ),
                            ] else ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: columns == 2 ? 1 : 2,
                                    child: TopSongsGrid(
                                      songs: p.topSongs,
                                      columns: columns == 2 ? 2 : 3,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 1,
                                    child: TopFriendsCarousel(
                                      friends: p.topFriends,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            ActionButtons(
                              isOwner: view.isOwner,
                              bizCardUrl: p.bizCardUrl,
                              onEditProfile: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Edit Profile (wire to /edit-profile in V1).')),
                                );
                              },
                              onOpenBizCard: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Open Biz Card: ${p.bizCardUrl ?? "N/A"}')),
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: padding.copyWith(top: 0),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: PrivacyToggle(
                            enabled: view.isOwner,
                            value: p.overallPrivacy == Privacy.private ? Privacy.private : Privacy.public,
                            onChanged: (v) async {
                              await ref
                                  .read(profileControllerProvider(widget.userId).notifier)
                                  .setOverallPrivacy(userId: widget.userId, privacy: v);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: cs.primary),
          const SizedBox(height: 12),
          const Text('Loading profile…'),
        ],
      ),
    );
  }
}

class _PrivateGate extends StatelessWidget {
  const _PrivateGate();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 44, color: cs.primary),
              const SizedBox(height: 10),
              Text(
                'Profile private',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'This profile is not visible right now.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  final String message;
  final String? details;
  final VoidCallback? onRetry;

  const _ProfileError({required this.message, this.details, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cs.errorContainer.withOpacity(0.35),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.error.withOpacity(0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 44, color: cs.error),
              const SizedBox(height: 10),
              Text(
                message,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              if (details != null) ...[
                const SizedBox(height: 8),
                Text(
                  details!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 12),
              if (onRetry != null)
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
