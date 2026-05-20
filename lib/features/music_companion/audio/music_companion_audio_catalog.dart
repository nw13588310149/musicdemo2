enum MusicCompanionMetronomeCue {
  tone1Accent,
  tone1Regular,
  tone2Accent,
  tone2Regular,
  tone2Special,
  tone3Beat1,
  tone3Beat2,
  tone3Beat3,
  tone3Beat4,
  tone3Beat5,
  tone3Beat6,
  tone3Beat7,
  tone3Beat8,
  tone3Beat9,
  tone3Beat10,
  tone3Beat11,
  tone3Beat12,
}

const Map<String, String> kMusicCompanionPianoAssetByNote = <String, String>{
  'C2': 'assets/audio/smart_dictation/piano/a49.wav',
  'C#2': 'assets/audio/smart_dictation/piano/b49.wav',
  'D2': 'assets/audio/smart_dictation/piano/a50.wav',
  'D#2': 'assets/audio/smart_dictation/piano/b50.wav',
  'E2': 'assets/audio/smart_dictation/piano/a51.wav',
  'F2': 'assets/audio/smart_dictation/piano/a52.wav',
  'F#2': 'assets/audio/smart_dictation/piano/b52.wav',
  'G2': 'assets/audio/smart_dictation/piano/a53.wav',
  'G#2': 'assets/audio/smart_dictation/piano/b53.wav',
  'A2': 'assets/audio/smart_dictation/piano/a54.wav',
  'A#2': 'assets/audio/smart_dictation/piano/b54.wav',
  'B2': 'assets/audio/smart_dictation/piano/a55.wav',
  'C3': 'assets/audio/smart_dictation/piano/a56.wav',
  'C#3': 'assets/audio/smart_dictation/piano/b56.wav',
  'D3': 'assets/audio/smart_dictation/piano/a57.wav',
  'D#3': 'assets/audio/smart_dictation/piano/b57.wav',
  'E3': 'assets/audio/smart_dictation/piano/a48.wav',
  'F3': 'assets/audio/smart_dictation/piano/a81.wav',
  'F#3': 'assets/audio/smart_dictation/piano/b81.wav',
  'G3': 'assets/audio/smart_dictation/piano/a87.wav',
  'G#3': 'assets/audio/smart_dictation/piano/b87.wav',
  'A3': 'assets/audio/smart_dictation/piano/a69.wav',
  'A#3': 'assets/audio/smart_dictation/piano/b69.wav',
  'B3': 'assets/audio/smart_dictation/piano/a82.wav',
  'C4': 'assets/audio/smart_dictation/piano/a84.wav',
  'C#4': 'assets/audio/smart_dictation/piano/b84.wav',
  'D4': 'assets/audio/smart_dictation/piano/a89.wav',
  'D#4': 'assets/audio/smart_dictation/piano/b89.wav',
  'E4': 'assets/audio/smart_dictation/piano/a85.wav',
  'F4': 'assets/audio/smart_dictation/piano/a73.wav',
  'F#4': 'assets/audio/smart_dictation/piano/b73.wav',
  'G4': 'assets/audio/smart_dictation/piano/a79.wav',
  'G#4': 'assets/audio/smart_dictation/piano/b79.wav',
  'A4': 'assets/audio/smart_dictation/piano/a80.wav',
  'A#4': 'assets/audio/smart_dictation/piano/b80.wav',
  'B4': 'assets/audio/smart_dictation/piano/a65.wav',
  'C5': 'assets/audio/smart_dictation/piano/a83.wav',
  'C#5': 'assets/audio/smart_dictation/piano/b83.wav',
  'D5': 'assets/audio/smart_dictation/piano/a68.wav',
  'D#5': 'assets/audio/smart_dictation/piano/b68.wav',
  'E5': 'assets/audio/smart_dictation/piano/a70.wav',
  'F5': 'assets/audio/smart_dictation/piano/a71.wav',
  'F#5': 'assets/audio/smart_dictation/piano/b71.wav',
  'G5': 'assets/audio/smart_dictation/piano/a72.wav',
  'G#5': 'assets/audio/smart_dictation/piano/b72.wav',
  'A5': 'assets/audio/smart_dictation/piano/a74.wav',
  'A#5': 'assets/audio/smart_dictation/piano/b74.wav',
  'B5': 'assets/audio/smart_dictation/piano/a75.wav',
  'C6': 'assets/audio/smart_dictation/piano/a76.wav',
  'C#6': 'assets/audio/smart_dictation/piano/b76.wav',
  'D6': 'assets/audio/smart_dictation/piano/a90.wav',
  'D#6': 'assets/audio/smart_dictation/piano/b90.wav',
  'E6': 'assets/audio/smart_dictation/piano/a88.wav',
  'F6': 'assets/audio/smart_dictation/piano/a67.wav',
  'F#6': 'assets/audio/smart_dictation/piano/b67.wav',
  'G6': 'assets/audio/smart_dictation/piano/a86.wav',
  'G#6': 'assets/audio/smart_dictation/piano/b86.wav',
  'A6': 'assets/audio/smart_dictation/piano/a66.wav',
  'A#6': 'assets/audio/smart_dictation/piano/b66.wav',
  'B6': 'assets/audio/smart_dictation/piano/a78.wav',
  'C7': 'assets/audio/smart_dictation/piano/a77.wav',
};

const Map<MusicCompanionMetronomeCue, String>
kMusicCompanionMetronomeAssetByCue = <MusicCompanionMetronomeCue, String>{
  MusicCompanionMetronomeCue.tone1Accent:
      'assets/audio/music_companion/metronome/beat0/audio1.mp3',
  MusicCompanionMetronomeCue.tone1Regular:
      'assets/audio/music_companion/metronome/beat0/audio2.mp3',
  MusicCompanionMetronomeCue.tone2Accent:
      'assets/audio/music_companion/metronome/beat2/2.mp3',
  MusicCompanionMetronomeCue.tone2Regular:
      'assets/audio/music_companion/metronome/beat2/3.mp3',
  MusicCompanionMetronomeCue.tone2Special:
      'assets/audio/music_companion/metronome/beat2/4.mp3',
  MusicCompanionMetronomeCue.tone3Beat1:
      'assets/audio/music_companion/metronome/beat3/1.mp3',
  MusicCompanionMetronomeCue.tone3Beat2:
      'assets/audio/music_companion/metronome/beat3/2.mp3',
  MusicCompanionMetronomeCue.tone3Beat3:
      'assets/audio/music_companion/metronome/beat3/3.mp3',
  MusicCompanionMetronomeCue.tone3Beat4:
      'assets/audio/music_companion/metronome/beat3/4.mp3',
  MusicCompanionMetronomeCue.tone3Beat5:
      'assets/audio/music_companion/metronome/beat3/5.mp3',
  MusicCompanionMetronomeCue.tone3Beat6:
      'assets/audio/music_companion/metronome/beat3/6.mp3',
  MusicCompanionMetronomeCue.tone3Beat7:
      'assets/audio/music_companion/metronome/beat3/7.mp3',
  MusicCompanionMetronomeCue.tone3Beat8:
      'assets/audio/music_companion/metronome/beat3/8.mp3',
  MusicCompanionMetronomeCue.tone3Beat9:
      'assets/audio/music_companion/metronome/beat3/9.mp3',
  MusicCompanionMetronomeCue.tone3Beat10:
      'assets/audio/music_companion/metronome/beat3/10.mp3',
  MusicCompanionMetronomeCue.tone3Beat11:
      'assets/audio/music_companion/metronome/beat3/11.mp3',
  MusicCompanionMetronomeCue.tone3Beat12:
      'assets/audio/music_companion/metronome/beat3/12.mp3',
};
