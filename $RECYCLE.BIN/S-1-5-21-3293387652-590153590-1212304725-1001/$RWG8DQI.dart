import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final String heroTag;
  final String name;
  final String? handle;
  final String? photoUrl;

  const ProfileHeader({
    super.key,
    required this.heroTag,
    required this.name,
    required this.handle,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                cs.primary.withOpacity(0.20),
                cs.tertiary.withOpacity(0.12),
                cs.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: cs.outlineVariant),
          ),
        ),
        Positioned(
          left: 18,
          top: 24,
          child: Hero(
            tag: heroTag,
            child: _Avatar(photoUrl: photoUrl),
          ),
        ),
        Positioned(
          left: 18 + 120 + 14,
          top: 44,
          right: 18,
          child: _NameHandleOverlay(
            name: name,
            handle: handle,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  const _Avatar({required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cs.surface, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: photoUrl == null || photoUrl!.trim().isEmpty
            ? Container(
                color: cs.surfaceContainerHighest,
                child: Icon(Icons.person_outline, size: 54, color: cs.onSurfaceVariant),
              )
            : CachedNetworkImage(
                imageUrl: photoUrl!,
                fit: BoxFit.cover,
                placeholder: (context, _) => Container(
                  color: cs.surfaceContainerHighest,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: cs.primary),
                    ),
                  ),
                ),
                errorWidget: (context, _, __) => Container(
                  color: cs.surfaceContainerHighest,
                  child: Icon(Icons.person_outline, size: 54, color: cs.onSurfaceVariant),
                ),
              ),
      ),
    );
  }
}

class _NameHandleOverlay extends StatelessWidget {
  final String name;
  final String? handle;
  const _NameHandleOverlay({required this.name, required this.handle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            (handle == null || handle!.isEmpty) ? '@unknown' : handle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final String heroTag;
  final String name;
  final String? handle;
  final String? photoUrl;

  const ProfileHeader({
    super.key,
    required this.heroTag,
    required this.name,
    required this.handle,
    required this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                cs.primary.withOpacity(0.20),
                cs.tertiary.withOpacity(0.12),
                cs.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: cs.outlineVariant),
          ),
        ),
        Positioned(
          left: 18,
          top: 24,
          child: Hero(
            tag: heroTag,
            child: _Avatar(photoUrl: photoUrl),
          ),
        ),
        Positioned(
          left: 18 + 120 + 14,
          top: 44,
          right: 18,
          child: _NameHandleOverlay(name: name, handle: handle),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  const _Avatar({required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cs.surface, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: photoUrl == null || photoUrl!.trim().isEmpty
            ? Container(
                color: cs.surfaceContainerHighest,
                child: Icon(
                  Icons.person_outline,
                  size: 54,
                  color: cs.onSurfaceVariant,
                ),
              )
            : CachedNetworkImage(
                imageUrl: photoUrl!,
                fit: BoxFit.cover,
                placeholder: (context, _) => Container(
                  color: cs.surfaceContainerHighest,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, _, __) => Container(
                  color: cs.surfaceContainerHighest,
                  child: Icon(
                    Icons.person_outline,
                    size: 54,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
      ),
    );
  }
}

class _NameHandleOverlay extends StatelessWidget {
  final String name;
  final String? handle;
  const _NameHandleOverlay({required this.name, required this.handle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            (handle == null || handle!.isEmpty) ? '@unknown' : handle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
