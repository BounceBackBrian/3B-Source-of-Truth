import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/profile_edit_controller.dart';
import '../providers/profile_provider.dart';

class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(profileEditControllerProvider);
    final c = ref.read(profileEditControllerProvider.notifier);
    final authedId = ref.read(authUserIdProvider);

    if (authedId == null) {
      return const Scaffold(
        body: Center(
          child: Text('You must be signed in to edit your profile.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: (s.loading || !s.dirty)
                ? null
                : () async {
                    final ok = await c.save();
                    if (!context.mounted) return;

                    final currentError =
                        ref.read(profileEditControllerProvider).error;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            ok ? 'Saved' : (currentError ?? 'Save failed')),
                      ),
                    );

                    if (ok) {
                      Navigator.of(context).maybePop();
                    }
                  },
            child: const Text('Save'),
          ),
        ],
      ),
      body: s.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (s.error != null) ...[
                  Text(
                    s.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  initialValue: s.name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  textInputAction: TextInputAction.next,
                  onChanged: c.setName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: s.handle.replaceFirst(RegExp(r'^@+'), ''),
                  decoration: const InputDecoration(
                    labelText: 'Handle',
                    prefixText: '@',
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: c.setHandle,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: s.location,
                  decoration: const InputDecoration(labelText: 'Location'),
                  textInputAction: TextInputAction.next,
                  onChanged: c.setLocation,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: s.bio,
                  decoration: const InputDecoration(labelText: 'Bio'),
                  minLines: 3,
                  maxLines: 6,
                  onChanged: c.setBio,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Overall Privacy',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: [
                    ChoiceChip(
                      label: const Text('Public'),
                      selected: s.overallPrivacy == Privacy.public,
                      onSelected: (_) => c.setOverallPrivacy(Privacy.public),
                    ),
                    ChoiceChip(
                      label: const Text('VibeSpace'),
                      selected: s.overallPrivacy == Privacy.vibespace,
                      onSelected: (_) => c.setOverallPrivacy(Privacy.vibespace),
                    ),
                    ChoiceChip(
                      label: const Text('Private'),
                      selected: s.overallPrivacy == Privacy.private,
                      onSelected: (_) => c.setOverallPrivacy(Privacy.private),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Note: Boost visibility is enforced separately by the Boost policy engine.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}
