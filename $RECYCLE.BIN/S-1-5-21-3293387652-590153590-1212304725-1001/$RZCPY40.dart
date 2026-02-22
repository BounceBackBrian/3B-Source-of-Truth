import 'package:flutter/foundation.dart';

class TopSong {
  final String title;
  final String artist;
  final String? coverUrl;

  const TopSong({required this.title, required this.artist, this.coverUrl});
}

class FriendPreview {
  final String name;
  final String? photoUrl;

  const FriendPreview({required this.name, this.photoUrl});
}

class ProfileProvider extends ChangeNotifier {
  ProfileProvider();

  String name = 'Avery Stone';
  String handle = '@avstone';
  String? photoUrl;

  String bio =
      'Music-first human. Building playlists, collecting concert memories, and discovering artists before they blow up.';

  bool isPrivate = false;

  final List<String> employmentBadges = const [
    'Verified creator',
    'Community mentor',
  ];

  final List<String> boostBadges = const ['3Boost active', 'Momentum streak'];

  final List<TopSong> topSongs = const [
    TopSong(title: 'Midnight Echoes', artist: 'Luna Gray'),
    TopSong(title: 'Neon Hearts', artist: 'Kite & June'),
    TopSong(title: 'Saturn Drive', artist: 'Atlas Bloom'),
    TopSong(title: 'Afterglow', artist: 'Mira Vale'),
    TopSong(title: 'Oceans Between', artist: 'Northfield'),
    TopSong(title: 'Blurred Polaroid', artist: 'The Vectors'),
  ];

  final List<FriendPreview> topFriends = const [
    FriendPreview(name: 'Sofia'),
    FriendPreview(name: 'Noah'),
    FriendPreview(name: 'Mia'),
    FriendPreview(name: 'Ethan'),
    FriendPreview(name: 'Emma'),
    FriendPreview(name: 'Liam'),
  ];

  void togglePrivacy(bool value) {
    if (isPrivate == value) return;
    isPrivate = value;
    notifyListeners();
  }
}
