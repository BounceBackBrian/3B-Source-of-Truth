import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum Privacy { public, vibospace, private }

@immutable
class TopSong {
  final String id;
  final String title;
  final String artist;
  final String? coverUrl;

  const TopSong({
    required this.id,
    required this.title,
    required this.artist,
    this.coverUrl,
  });
}

@immutable
class TopFriend {
  final String userId;
  final String name;
  final String? handle;
  final String? photoUrl;

  const TopFriend({
    required this.userId,
    required this.name,
    this.handle,
    this.photoUrl,
  });
}

@immutable
class VibeProfile {
  final String userId;
  final String? businessId;
  final String name;
  final String? handle;
  final String? bio;
  final String? photoUrl;
  final String? location;
  final List<String> employment;
  final List<String> education;
  final List<String> boosts;
  final List<TopSong> topSongs;
  final List<TopFriend> topFriends;
  final String? bizCardUrl;
  final Map<String, Privacy> privacy;
  final Privacy overallPrivacy;

  const VibeProfile({
    required this.userId,
    required this.businessId,
    required this.name,
    required this.handle,
    required this.bio,
    required this.photoUrl,
    required this.location,
    required this.employment,
    required this.education,
    required this.boosts,
    required this.topSongs,
    required this.topFriends,
    required this.bizCardUrl,
    required this.privacy,
    required this.overallPrivacy,
  });

  VibeProfile copyWith({
    String? name,
    String? handle,
    String? bio,
    String? photoUrl,
    String? location,
    List<String>? employment,
    List<String>? education,
    List<String>? boosts,
    List<TopSong>? topSongs,
    List<TopFriend>? topFriends,
    String? bizCardUrl,
    Map<String, Privacy>? privacy,
    Privacy? overallPrivacy,
  }) {
    return VibeProfile(
      userId: userId,
      businessId: businessId,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      location: location ?? this.location,
      employment: employment ?? this.employment,
      education: education ?? this.education,
      boosts: boosts ?? this.boosts,
      topSongs: topSongs ?? this.topSongs,
      topFriends: topFriends ?? this.topFriends,
      bizCardUrl: bizCardUrl ?? this.bizCardUrl,
      privacy: privacy ?? this.privacy,
      overallPrivacy: overallPrivacy ?? this.overallPrivacy,
    );
  }
}

@immutable
class ProfileViewState {
  final VibeProfile? profile;
  final bool isOwner;
  final bool isPrivateGate;
  final bool useMock;

  const ProfileViewState({
    required this.profile,
    required this.isOwner,
    required this.isPrivateGate,
    required this.useMock,
  });
}

const bool kUseMockProfileData = true;

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

abstract class ProfileRepository {
  Future<VibeProfile> fetchProfile(String userId);

  Future<void> auditProfileLoad({
    required String viewerUserId,
    required String targetUserId,
    required String? businessId,
    required bool isOwner,
  });

  Future<void> updateOverallPrivacy({
    required String userId,
    required Privacy overallPrivacy,
  });
}

class SupabaseProfileRepository implements ProfileRepository {
  final SupabaseClient _client;

  SupabaseProfileRepository(this._client);

  @override
  Future<VibeProfile> fetchProfile(String userId) async {
    final profileRow = await _client
        .from('vibe_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (profileRow == null) {
      throw StateError('Profile not found');
    }

    final songsRows = await _client
        .from('vibe_top_songs')
        .select()
        .eq('user_id', userId)
        .order('rank', ascending: true)
        .limit(3);

    final friendsRows = await _client
        .from('vibe_top_friends')
        .select()
        .eq('user_id', userId)
        .order('rank', ascending: true)
        .limit(4);

    final Map<String, dynamic> privacyRaw =
        (profileRow['privacy'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};

    Privacy parsePrivacy(dynamic v) {
      final s = (v ?? '').toString().toLowerCase();
      return switch (s) {
        'public' => Privacy.public,
        'vibospace' => Privacy.vibospace,
        'private' => Privacy.private,
        _ => Privacy.public,
      };
    }

    final privacy = <String, Privacy>{
      for (final e in privacyRaw.entries) e.key: parsePrivacy(e.value),
    };

    final overallPrivacy = parsePrivacy(profileRow['overall_privacy']);

    return VibeProfile(
      userId: profileRow['user_id'] as String,
      businessId: profileRow['business_id'] as String?,
      name: (profileRow['name'] as String?) ?? 'Unknown',
      handle: profileRow['handle'] as String?,
      bio: profileRow['bio'] as String?,
      photoUrl: profileRow['photo_url'] as String?,
      location: profileRow['location'] as String?,
      employment: ((profileRow['employment'] as List?) ?? const <dynamic>[])
          .cast<String>(),
      education: ((profileRow['education'] as List?) ?? const <dynamic>[])
          .cast<String>(),
      boosts:
          ((profileRow['boosts'] as List?) ?? const <dynamic>[]).cast<String>(),
      topSongs: songsRows
          .map<TopSong>(
            (r) => TopSong(
              id: r['song_id'].toString(),
              title: (r['title'] as String?) ?? 'Untitled',
              artist: (r['artist'] as String?) ?? 'Unknown',
              coverUrl: r['cover_url'] as String?,
            ),
          )
          .toList(growable: false),
      topFriends: friendsRows
          .map<TopFriend>(
            (r) => TopFriend(
              userId: r['friend_user_id'] as String,
              name: (r['name'] as String?) ?? 'Friend',
              handle: r['handle'] as String?,
              photoUrl: r['photo_url'] as String?,
            ),
          )
          .toList(growable: false),
      bizCardUrl: profileRow['biz_card_url'] as String?,
      privacy: privacy,
      overallPrivacy: overallPrivacy,
    );
  }

  @override
  Future<void> auditProfileLoad({
    required String viewerUserId,
    required String targetUserId,
    required String? businessId,
    required bool isOwner,
  }) async {
    await _client.from('audit_events').insert(<String, dynamic>{
      'event_type': 'profile_load',
      'viewer_user_id': viewerUserId,
      'target_user_id': targetUserId,
      'business_id': businessId,
      'is_owner': isOwner,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> updateOverallPrivacy({
    required String userId,
    required Privacy overallPrivacy,
  }) async {
    await _client
        .from('vibe_profiles')
        .update(<String, dynamic>{'overall_privacy': overallPrivacy.name}).eq(
            'user_id', userId);
  }
}

class MockProfileRepository implements ProfileRepository {
  @override
  Future<VibeProfile> fetchProfile(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final overallPrivacy =
        userId == 'mock_blocked_user' ? Privacy.private : Privacy.public;

    return VibeProfile(
      userId: userId,
      businessId: 'biz_123',
      name: userId == 'mock_public_user' ? 'Jordan Park' : 'Avery Chen',
      handle: userId == 'mock_public_user' ? '@jordan' : '@avery',
      bio:
          'Building VibeSpace — music, friends, and boosts.\nCatch me at live shows.',
      photoUrl:
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=600&auto=format&fit=crop&q=60',
      location: 'Los Angeles, CA',
      employment: const <String>['VibeSpace (Verified)'],
      education: const <String>['USC'],
      boosts: userId == 'mock_public_user'
          ? const <String>[]
          : const <String>['3Boost Active', 'Creator Boost'],
      topSongs: const <TopSong>[
        TopSong(
          id: 's1',
          title: 'Midnight City',
          artist: 'M83',
          coverUrl:
              'https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=600&auto=format&fit=crop&q=60',
        ),
        TopSong(
          id: 's2',
          title: 'Blinding Lights',
          artist: 'The Weeknd',
          coverUrl:
              'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=600&auto=format&fit=crop&q=60',
        ),
        TopSong(
          id: 's3',
          title: 'Nikes',
          artist: 'Frank Ocean',
          coverUrl:
              'https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=600&auto=format&fit=crop&q=60',
        ),
      ],
      topFriends: const <TopFriend>[
        TopFriend(
          userId: 'u_f1',
          name: 'Kai',
          handle: '@kai',
          photoUrl:
              'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=600&auto=format&fit=crop&q=60',
        ),
        TopFriend(
          userId: 'u_f2',
          name: 'Mina',
          handle: '@mina',
          photoUrl:
              'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=600&auto=format&fit=crop&q=60',
        ),
        TopFriend(
          userId: 'u_f3',
          name: 'Noah',
          handle: '@noah',
          photoUrl:
              'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?w=600&auto=format&fit=crop&q=60',
        ),
        TopFriend(
          userId: 'u_f4',
          name: 'Zoe',
          handle: '@zoe',
          photoUrl:
              'https://images.unsplash.com/photo-1524502397800-2eeaad7c3fe5?w=600&auto=format&fit=crop&q=60',
        ),
      ],
      bizCardUrl: 'https://example.com/bizcard/$userId',
      privacy: const <String, Privacy>{
        'bio': Privacy.public,
        'location': Privacy.vibospace,
        'employment': Privacy.public,
        'education': Privacy.vibospace,
        'topSongs': Privacy.public,
        'topFriends': Privacy.public,
        'bizCard': Privacy.public,
        'currentEmployer': Privacy.public,
      },
      overallPrivacy: overallPrivacy,
    );
  }

  @override
  Future<void> auditProfileLoad({
    required String viewerUserId,
    required String targetUserId,
    required String? businessId,
    required bool isOwner,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  @override
  Future<void> updateOverallPrivacy({
    required String userId,
    required Privacy overallPrivacy,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (kUseMockProfileData) {
    return MockProfileRepository();
  }

  final client = ref.watch(supabaseClientProvider);
  return SupabaseProfileRepository(client);
});

final authUserIdProvider = Provider<String?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.currentUser?.id;
});

final viewerBusinessIdProvider = Provider<String?>((ref) {
  if (kUseMockProfileData) {
    return 'biz_123';
  }

  final client = ref.watch(supabaseClientProvider);
  final meta = client.auth.currentUser?.userMetadata ?? <String, dynamic>{};
  return meta['business_id'] as String?;
});

Privacy _fieldPrivacy(VibeProfile profile, String key) {
  return profile.privacy[key] ?? Privacy.public;
}

bool _canViewField({
  required bool isOwner,
  required bool isAuthed,
  required Privacy privacy,
}) {
  if (isOwner) {
    return true;
  }

  return switch (privacy) {
    Privacy.public => true,
    Privacy.vibospace => isAuthed,
    Privacy.private => false,
  };
}

VibeProfile _applyPrivacy({
  required VibeProfile profile,
  required bool isOwner,
  required bool isAuthed,
  required bool isPublicView,
}) {
  if (isOwner) {
    return profile;
  }

  String? maybe(String? value, String key) {
    return _canViewField(
      isOwner: isOwner,
      isAuthed: isAuthed,
      privacy: _fieldPrivacy(profile, key),
    )
        ? value
        : null;
  }

  List<String> maybeList(List<String> value, String key) {
    return _canViewField(
      isOwner: isOwner,
      isAuthed: isAuthed,
      privacy: _fieldPrivacy(profile, key),
    )
        ? value
        : const <String>[];
  }

  List<TopSong> maybeSongs(List<TopSong> value) {
    return _canViewField(
      isOwner: isOwner,
      isAuthed: isAuthed,
      privacy: _fieldPrivacy(profile, 'topSongs'),
    )
        ? value
        : const <TopSong>[];
  }

  List<TopFriend> maybeFriends(List<TopFriend> value) {
    return _canViewField(
      isOwner: isOwner,
      isAuthed: isAuthed,
      privacy: _fieldPrivacy(profile, 'topFriends'),
    )
        ? value
        : const <TopFriend>[];
  }

  final filteredEmployment = maybeList(profile.employment, 'employment');
  final currentEmployer =
      filteredEmployment.isNotEmpty ? filteredEmployment.first : null;

  return profile
      .copyWith(
        bio: maybe(profile.bio, 'bio'),
        location: maybe(profile.location, 'location'),
        education: maybeList(profile.education, 'education'),
        employment: filteredEmployment,
        topSongs: maybeSongs(profile.topSongs),
        topFriends: maybeFriends(profile.topFriends),
        bizCardUrl: maybe(profile.bizCardUrl, 'bizCard'),
      )
      .copyWith(
        employment: isPublicView
            ? (currentEmployer == null
                ? const <String>[]
                : <String>[currentEmployer])
            : filteredEmployment,
      );
}

class ProfileController
    extends AutoDisposeFamilyAsyncNotifier<ProfileViewState, String> {
  late final ProfileRepository _repo = ref.read(profileRepositoryProvider);

  @override
  Future<ProfileViewState> build(String userId) {
    return _load(userId);
  }

  Future<ProfileViewState> _load(String userId) async {
    final viewerUserId = ref.read(authUserIdProvider);
    final isAuthed = viewerUserId != null;
    final isOwner = viewerUserId != null && viewerUserId == userId;

    final profile = await _repo.fetchProfile(userId);
    final isPrivateGate =
        (profile.overallPrivacy == Privacy.private) && !isOwner;

    await _repo.auditProfileLoad(
      viewerUserId: viewerUserId ?? 'anonymous',
      targetUserId: userId,
      businessId: profile.businessId,
      isOwner: isOwner,
    );

    if (isPrivateGate) {
      return ProfileViewState(
        profile: null,
        isOwner: isOwner,
        isPrivateGate: true,
        useMock: kUseMockProfileData,
      );
    }

    final filtered = _applyPrivacy(
      profile: profile,
      isOwner: isOwner,
      isAuthed: isAuthed,
      isPublicView: !isOwner,
    );

    return ProfileViewState(
      profile: filtered,
      isOwner: isOwner,
      isPrivateGate: false,
      useMock: kUseMockProfileData,
    );
  }

  Future<void> setOverallPrivacy({
    required String userId,
    required Privacy privacy,
  }) async {
    final previous = state.valueOrNull;
    state = const AsyncLoading<ProfileViewState>();

    try {
      await _repo.updateOverallPrivacy(userId: userId, overallPrivacy: privacy);
      state = AsyncData(await _load(userId));
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError<ProfileViewState>(error, stackTrace);
      }
    }
  }
}

final profileControllerProvider = AutoDisposeAsyncNotifierProviderFamily<
    ProfileController, ProfileViewState, String>(ProfileController.new);
