import 'dart:async';

import 'web_note_audio_player_base.dart';

WebNoteAudioPlayer createWebNoteAudioPlayer() => _StubWebNoteAudioPlayer();

class _StubWebNoteAudioPlayer implements WebNoteAudioPlayer {
  final StreamController<List<double>> _frequencyController =
      StreamController<List<double>>.broadcast();

  @override
  bool get isReady => true;

  @override
  Stream<List<double>> get frequencyBands => _frequencyController.stream;

  @override
  Future<void> prepare(Iterable<String> assets) async {}

  @override
  Future<void> activateByUserGesture() async {}

  @override
  Future<void> playAsset(String asset, {double volume = 1}) async {
    _frequencyController.add(const <double>[]);
  }

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> dispose() async {
    await _frequencyController.close();
  }
}
