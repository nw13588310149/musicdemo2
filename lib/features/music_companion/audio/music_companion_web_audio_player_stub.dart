import 'music_companion_web_audio_player_base.dart';

MusicCompanionWebAudioPlayer createMusicCompanionWebAudioPlayer() {
  return _UnsupportedMusicCompanionWebAudioPlayer();
}

class _UnsupportedMusicCompanionWebAudioPlayer
    implements MusicCompanionWebAudioPlayer {
  @override
  bool get isReady => false;

  @override
  Future<void> activateByUserGesture() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playAsset(String asset, {double volume = 1}) async {}

  @override
  Future<void> prepare(Iterable<String> assets) async {}

  @override
  Future<void> stopAll() async {}
}
