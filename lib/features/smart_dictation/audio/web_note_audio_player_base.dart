import 'dart:async';

abstract class WebNoteAudioPlayer {
  bool get isReady;

  Stream<List<double>> get frequencyBands;

  Future<void> prepare(Iterable<String> assets);

  Future<void> activateByUserGesture();

  Future<void> playAsset(String asset, {double volume = 1});

  Future<void> stopAll();

  Future<void> dispose();
}
