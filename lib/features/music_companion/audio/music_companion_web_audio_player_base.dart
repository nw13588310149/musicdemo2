abstract class MusicCompanionWebAudioPlayer {
  bool get isReady;

  Future<void> prepare(Iterable<String> assets);

  Future<void> activateByUserGesture();

  Future<void> playAsset(String asset, {double volume = 1});

  Future<void> stopAll();

  Future<void> dispose();
}
