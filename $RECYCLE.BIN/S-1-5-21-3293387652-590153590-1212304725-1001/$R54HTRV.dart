import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:postgrest/postgrest.dart';

import '../providers/profile_provider.dart';

class ProfileEditState {
  final bool loading;
  final bool saving;
  final String initialName;
  final String initialHandle;
  final String initialBio;
  final String initialLocation;
  final Privacy initialOverallPrivacy;
  final String name;
  final String handle;
  final String bio;
  final String location;
  final Privacy overallPrivacy;
  final String? error;
  final String? fieldHandleError;

  const ProfileEditState({
    required this.loading,
    required this.saving,
    required this.initialName,
    required this.initialHandle,
    required this.initialBio,
    required this.initialLocation,
    required this.initialOverallPrivacy,
    required this.name,
    required this.handle,
    required this.bio,
    required this.location,
    required this.overallPrivacy,
    this.error,
    this.fieldHandleError,
  });

  static const empty = ProfileEditState(
    loading: true,
    saving: false,
    initialName: '',
    initialHandle: '',
    initialBio: '',
    initialLocation: '',
    initialOverallPrivacy: Privacy.public,
    name: '',
    handle: '',
    bio: '',
    location: '',
    overallPrivacy: Privacy.public,
  );

  bool get dirty =>
      name != initialName ||
      handle != initialHandle ||
      bio != initialBio ||
      location != initialLocation ||
      overallPrivacy != initialOverallPrivacy;

  String normalizeHandle(String raw) {
    return raw.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');
  }

  String? validateHandle(String raw) {
    final h = normalizeHandle(raw);
    if (h.isEmpty) return 'Handle is required.';
    if (h.length < 3) return 'Handle must be at least 3 characters.';
    if (h.length > 20) return 'Handle must be 20 characters or less.';
    if (h.contains(' ')) return 'No spaces allowed.';
    final ok = RegExp(r'^[a-z0-9._]+$').hasMatch(h);
    if (!ok) return 'Only letters, numbers, dot, underscore.';
    return null;
  );

  ProfileEditState copyWith({
    bool? loading,
    bool? saving,
    String? initialName,
    String? initialHandle,
    String? initialBio,
    String? initialLocation,
    Privacy? initialOverallPrivacy,
    String? name,
    String? handle,
    String? bio,
    String? location,
    Privacy? overallPrivacy,
    String? error,
    String? fieldHandleError,
  }) {
    return ProfileEditState(
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      initialName: initialName ?? this.initialName,
      initialHandle: initialHandle ?? this.initialHandle,
      initialBio: initialBio ?? this.initialBio,
      initialLocation: initialLocation ?? this.initialLocation,
      initialOverallPrivacy:
          initialOverallPrivacy ?? this.initialOverallPrivacy,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      overallPrivacy: overallPrivacy ?? this.overallPrivacy,
      error: error,
      fieldHandleError: fieldHandleError,
    );
  }
}

final profileEditControllerProvider =
    AutoDisposeNotifierProvider<ProfileEditController, ProfileEditState>(
  ProfileEditController.new,
);

class ProfileEditController extends AutoDisposeNotifier<ProfileEditState> {
  late final ProfileRepository _repo = ref.read(profileRepositoryProvider);
  bool _hydrated = false;
  String? _hydratedForUser;

  @override
  ProfileEditState build() {
    final authedId = ref.watch(authUserIdProvider);
    if (authedId == null) {
      return ProfileEditState.empty.copyWith(error: 'Not authenticated');
    }

    final profileAsync = ref.watch(profileControllerProvider(authedId));

    return profileAsync.when(
      loading: () => _hydrated
          ? state.copyWith(loading: true)
          : ProfileEditState.empty.copyWith(loading: true),
      error: (e, _) => ProfileEditState.empty.copyWith(error: e.toString()),
      data: (view) {
        final p = view.profile;
        if (p == null) {
          return ProfileEditState.empty
              .copyWith(error: 'Profile not available');
        }

        if (!_hydrated || _hydratedForUser != authedId) {
          _hydrated = true;
          _hydratedForUser = authedId;
          return ProfileEditState(
            loading: false,
            name: p.name,
            handle: (p.handle ?? '').replaceFirst(RegExp(r'^@+'), ''),
            bio: p.bio ?? '',
            location: p.location ?? '',
            overallPrivacy: p.overallPrivacy,
            dirty: false,
          );
        }

        return state.copyWith(loading: false);
      },
    );
  }

  void setName(String v) =>
      state = state.copyWith(name: v, error: null);

    void setHandle(String v) {
    final err = state.validateHandle(v);
    state = state.copyWith(handle: v, fieldHandleError: err, error: null);
    }

  void setBio(String v) =>
      state = state.copyWith(bio: v, error: null);

  void setLocation(String v) =>
      state = state.copyWith(location: v, error: null);

  void setOverallPrivacy(Privacy v) =>
      state = state.copyWith(overallPrivacy: v, error: null);

  Future<bool> save() async {
    final authedId = ref.read(authUserIdProvider);
    if (authedId == null) {
      state = state.copyWith(error: 'Not authenticated');
      return false;
    }

    if (!state.dirty) {
      return true;
    }

    final normalizedHandle = state.normalizeHandle(state.handle);
    final handleErr = state.validateHandle(state.handle);
    if (handleErr != null) {
      state = state.copyWith(fieldHandleError: handleErr);
      return false;
    }

    state = state.copyWith(saving: true, error: null);

    try {
      final changed = <String>[];
      if (state.name != state.initialName) changed.add('name');
      if (normalizedHandle != state.initialHandle) changed.add('handle');
      if (state.bio.trim() != state.initialBio) changed.add('bio');
      if (state.location.trim() != state.initialLocation) {
        changed.add('location');
      }
      if (state.overallPrivacy != state.initialOverallPrivacy) {
        changed.add('overall_privacy');
      }

      await _repo.updateProfile(
        userId: authedId,
        name: state.name,
        handle: normalizedHandle,
        bio: state.bio,
        location: state.location,
        overallPrivacy: state.overallPrivacy,
      );

      await _repo.auditProfileUpdate(
        viewerUserId: authedId,
        targetUserId: authedId,
        fieldsChanged: changed,
      );

      ref.invalidate(profileControllerProvider(authedId));

      state = state.copyWith(
        loading: false,
        saving: false,
        initialName: state.name,
        initialHandle: normalizedHandle,
        initialBio: state.bio.trim(),
        initialLocation: state.location.trim(),
        initialOverallPrivacy: state.overallPrivacy,
        handle: normalizedHandle,
        fieldHandleError: null,
      );
      return true;
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (e.code == '23505' || msg.contains('duplicate') || msg.contains('unique')) {
        state = state.copyWith(
          saving: false,
          fieldHandleError: 'That handle is already taken.',
        );
        return false;
      }
      state = state.copyWith(saving: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(saving: false, error: e.toString());
      return false;
    }
  }
}
