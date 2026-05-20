import 'package:flutter/material.dart';

enum MusicCompanionTab { piano, metronome, tuner }

@immutable
class MusicCompanionSignature {
  const MusicCompanionSignature({
    required this.numerator,
    required this.denominator,
    required this.visualBeatCount,
  });

  final int numerator;
  final int denominator;
  final int visualBeatCount;

  String get label => '$numerator/$denominator';
}

@immutable
class MusicCompanionToneOption {
  const MusicCompanionToneOption({
    required this.label,
    required this.legacyToneIndex,
  });

  final String label;
  final int legacyToneIndex;
}

const List<MusicCompanionSignature> kMusicCompanionSignatures =
    <MusicCompanionSignature>[
      MusicCompanionSignature(numerator: 1, denominator: 4, visualBeatCount: 1),
      MusicCompanionSignature(numerator: 5, denominator: 4, visualBeatCount: 5),
      MusicCompanionSignature(
        numerator: 12,
        denominator: 8,
        visualBeatCount: 6,
      ),
      MusicCompanionSignature(numerator: 2, denominator: 4, visualBeatCount: 2),
      MusicCompanionSignature(numerator: 3, denominator: 8, visualBeatCount: 3),
      MusicCompanionSignature(numerator: 2, denominator: 2, visualBeatCount: 2),
      MusicCompanionSignature(numerator: 3, denominator: 4, visualBeatCount: 3),
      MusicCompanionSignature(numerator: 6, denominator: 8, visualBeatCount: 6),
      MusicCompanionSignature(numerator: 3, denominator: 2, visualBeatCount: 3),
      MusicCompanionSignature(numerator: 4, denominator: 4, visualBeatCount: 4),
      MusicCompanionSignature(numerator: 9, denominator: 8, visualBeatCount: 6),
      MusicCompanionSignature(numerator: 6, denominator: 2, visualBeatCount: 6),
    ];

const List<MusicCompanionToneOption> kMusicCompanionToneOptions =
    <MusicCompanionToneOption>[
      MusicCompanionToneOption(label: '音色1', legacyToneIndex: 1),
      MusicCompanionToneOption(label: '音色2', legacyToneIndex: 2),
      MusicCompanionToneOption(label: '音色3', legacyToneIndex: 3),
    ];

@immutable
class MusicCompanionState {
  const MusicCompanionState({
    required this.activeTab,
    required this.audioReady,
    required this.activePianoNotes,
    required this.pianoLabelsVisible,
    required this.pianoHeight,
    required this.metronomePlaying,
    required this.metronomeBpm,
    required this.metronomeToneIndex,
    required this.metronomeSignatureIndex,
    required this.metronomeActiveBeat,
    required this.tunerListening,
    required this.tunerPermissionGranted,
    required this.tunerNote,
    required this.tunerDetectedFrequency,
    required this.tunerReferenceFrequency,
    required this.tunerCents,
    required this.errorMessage,
  });

  factory MusicCompanionState.initial() {
    return const MusicCompanionState(
      activeTab: MusicCompanionTab.piano,
      audioReady: false,
      activePianoNotes: <String>{},
      pianoLabelsVisible: false,
      pianoHeight: 216,
      metronomePlaying: false,
      metronomeBpm: 40,
      metronomeToneIndex: 2,
      metronomeSignatureIndex: 2,
      metronomeActiveBeat: -1,
      tunerListening: false,
      tunerPermissionGranted: true,
      tunerNote: 'G#',
      tunerDetectedFrequency: 440,
      tunerReferenceFrequency: 440,
      tunerCents: 12,
      errorMessage: null,
    );
  }

  final MusicCompanionTab activeTab;
  final bool audioReady;
  final Set<String> activePianoNotes;
  final bool pianoLabelsVisible;
  final double pianoHeight;
  final bool metronomePlaying;
  final int metronomeBpm;
  final int metronomeToneIndex;
  final int metronomeSignatureIndex;
  final int metronomeActiveBeat;
  final bool tunerListening;
  final bool tunerPermissionGranted;
  final String tunerNote;
  final double tunerDetectedFrequency;
  final int tunerReferenceFrequency;
  final double tunerCents;
  final String? errorMessage;

  MusicCompanionSignature get activeSignature =>
      kMusicCompanionSignatures[metronomeSignatureIndex];

  MusicCompanionToneOption get activeTone =>
      kMusicCompanionToneOptions[metronomeToneIndex];

  MusicCompanionState copyWith({
    MusicCompanionTab? activeTab,
    bool? audioReady,
    Set<String>? activePianoNotes,
    bool? pianoLabelsVisible,
    double? pianoHeight,
    bool? metronomePlaying,
    int? metronomeBpm,
    int? metronomeToneIndex,
    int? metronomeSignatureIndex,
    int? metronomeActiveBeat,
    bool? tunerListening,
    bool? tunerPermissionGranted,
    String? tunerNote,
    double? tunerDetectedFrequency,
    int? tunerReferenceFrequency,
    double? tunerCents,
    Object? errorMessage = _sentinel,
  }) {
    return MusicCompanionState(
      activeTab: activeTab ?? this.activeTab,
      audioReady: audioReady ?? this.audioReady,
      activePianoNotes: activePianoNotes ?? this.activePianoNotes,
      pianoLabelsVisible: pianoLabelsVisible ?? this.pianoLabelsVisible,
      pianoHeight: pianoHeight ?? this.pianoHeight,
      metronomePlaying: metronomePlaying ?? this.metronomePlaying,
      metronomeBpm: metronomeBpm ?? this.metronomeBpm,
      metronomeToneIndex: metronomeToneIndex ?? this.metronomeToneIndex,
      metronomeSignatureIndex:
          metronomeSignatureIndex ?? this.metronomeSignatureIndex,
      metronomeActiveBeat: metronomeActiveBeat ?? this.metronomeActiveBeat,
      tunerListening: tunerListening ?? this.tunerListening,
      tunerPermissionGranted:
          tunerPermissionGranted ?? this.tunerPermissionGranted,
      tunerNote: tunerNote ?? this.tunerNote,
      tunerDetectedFrequency:
          tunerDetectedFrequency ?? this.tunerDetectedFrequency,
      tunerReferenceFrequency:
          tunerReferenceFrequency ?? this.tunerReferenceFrequency,
      tunerCents: tunerCents ?? this.tunerCents,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  static const Object _sentinel = Object();
}
