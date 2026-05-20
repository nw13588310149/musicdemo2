import 'package:flutter/foundation.dart';

@immutable
class PianoKeySpec {
  const PianoKeySpec({
    required this.token,
    required this.label,
    required this.isBlack,
    required this.solfege,
    required this.octaveDots,
    this.isCenterC = false,
    this.afterWhiteIndex = -1,
  });

  /// 例如 "C4", "F#3"，与音频引擎保持一致。
  final String token;

  /// 例如 "C4" / "F#"，调试用 / 标签兜底。
  final String label;

  final bool isBlack;

  /// 1..7 表示简谱 do re mi 等；黑键为 0。
  final int solfege;

  /// 八度提示点：负数表示在简谱数字下方画几个点（低八度），
  /// 正数表示上方（高八度），0 为无点（中央 C 所在的 C4 区域）。
  /// 与中国简谱标准一致：低八度加下点，高八度加上点。
  final int octaveDots;

  /// 中央 C（C4）特殊高亮。
  final bool isCenterC;

  /// 仅黑键使用：所属白键在 [kPianoFullWhiteKeys] 中的下标，
  /// 黑键水平定位 = (afterWhiteIndex + 1) * whiteKeyWidth - blackKeyWidth/2。
  final int afterWhiteIndex;
}

/// 35 个白键（C2 → B6），与 Vue 端 `pages/common/config/notes.js` 一致。
const List<PianoKeySpec> kPianoFullWhiteKeys = <PianoKeySpec>[
  // 大字组 C2-B2，简谱上方两点
  PianoKeySpec(
    token: 'C2',
    label: 'C2',
    isBlack: false,
    solfege: 1,
    octaveDots: -2,
  ),
  PianoKeySpec(
    token: 'D2',
    label: 'D2',
    isBlack: false,
    solfege: 2,
    octaveDots: -2,
  ),
  PianoKeySpec(
    token: 'E2',
    label: 'E2',
    isBlack: false,
    solfege: 3,
    octaveDots: -2,
  ),
  PianoKeySpec(
    token: 'F2',
    label: 'F2',
    isBlack: false,
    solfege: 4,
    octaveDots: -2,
  ),
  PianoKeySpec(
    token: 'G2',
    label: 'G2',
    isBlack: false,
    solfege: 5,
    octaveDots: -2,
  ),
  PianoKeySpec(
    token: 'A2',
    label: 'A2',
    isBlack: false,
    solfege: 6,
    octaveDots: -2,
  ),
  PianoKeySpec(
    token: 'B2',
    label: 'B2',
    isBlack: false,
    solfege: 7,
    octaveDots: -2,
  ),
  // 小字组 C3-B3，上方一点
  PianoKeySpec(
    token: 'C3',
    label: 'C3',
    isBlack: false,
    solfege: 1,
    octaveDots: -1,
  ),
  PianoKeySpec(
    token: 'D3',
    label: 'D3',
    isBlack: false,
    solfege: 2,
    octaveDots: -1,
  ),
  PianoKeySpec(
    token: 'E3',
    label: 'E3',
    isBlack: false,
    solfege: 3,
    octaveDots: -1,
  ),
  PianoKeySpec(
    token: 'F3',
    label: 'F3',
    isBlack: false,
    solfege: 4,
    octaveDots: -1,
  ),
  PianoKeySpec(
    token: 'G3',
    label: 'G3',
    isBlack: false,
    solfege: 5,
    octaveDots: -1,
  ),
  PianoKeySpec(
    token: 'A3',
    label: 'A3',
    isBlack: false,
    solfege: 6,
    octaveDots: -1,
  ),
  PianoKeySpec(
    token: 'B3',
    label: 'B3',
    isBlack: false,
    solfege: 7,
    octaveDots: -1,
  ),
  // 中央 C 所在组 C4-B4，无点
  PianoKeySpec(
    token: 'C4',
    label: 'C4',
    isBlack: false,
    solfege: 1,
    octaveDots: 0,
    isCenterC: true,
  ),
  PianoKeySpec(
    token: 'D4',
    label: 'D4',
    isBlack: false,
    solfege: 2,
    octaveDots: 0,
  ),
  PianoKeySpec(
    token: 'E4',
    label: 'E4',
    isBlack: false,
    solfege: 3,
    octaveDots: 0,
  ),
  PianoKeySpec(
    token: 'F4',
    label: 'F4',
    isBlack: false,
    solfege: 4,
    octaveDots: 0,
  ),
  PianoKeySpec(
    token: 'G4',
    label: 'G4',
    isBlack: false,
    solfege: 5,
    octaveDots: 0,
  ),
  PianoKeySpec(
    token: 'A4',
    label: 'A4',
    isBlack: false,
    solfege: 6,
    octaveDots: 0,
  ),
  PianoKeySpec(
    token: 'B4',
    label: 'B4',
    isBlack: false,
    solfege: 7,
    octaveDots: 0,
  ),
  // 高音组 C5-B5，下方一点
  PianoKeySpec(
    token: 'C5',
    label: 'C5',
    isBlack: false,
    solfege: 1,
    octaveDots: 1,
  ),
  PianoKeySpec(
    token: 'D5',
    label: 'D5',
    isBlack: false,
    solfege: 2,
    octaveDots: 1,
  ),
  PianoKeySpec(
    token: 'E5',
    label: 'E5',
    isBlack: false,
    solfege: 3,
    octaveDots: 1,
  ),
  PianoKeySpec(
    token: 'F5',
    label: 'F5',
    isBlack: false,
    solfege: 4,
    octaveDots: 1,
  ),
  PianoKeySpec(
    token: 'G5',
    label: 'G5',
    isBlack: false,
    solfege: 5,
    octaveDots: 1,
  ),
  PianoKeySpec(
    token: 'A5',
    label: 'A5',
    isBlack: false,
    solfege: 6,
    octaveDots: 1,
  ),
  PianoKeySpec(
    token: 'B5',
    label: 'B5',
    isBlack: false,
    solfege: 7,
    octaveDots: 1,
  ),
  // 超高音组 C6-B6，下方两点
  PianoKeySpec(
    token: 'C6',
    label: 'C6',
    isBlack: false,
    solfege: 1,
    octaveDots: 2,
  ),
  PianoKeySpec(
    token: 'D6',
    label: 'D6',
    isBlack: false,
    solfege: 2,
    octaveDots: 2,
  ),
  PianoKeySpec(
    token: 'E6',
    label: 'E6',
    isBlack: false,
    solfege: 3,
    octaveDots: 2,
  ),
  PianoKeySpec(
    token: 'F6',
    label: 'F6',
    isBlack: false,
    solfege: 4,
    octaveDots: 2,
  ),
  PianoKeySpec(
    token: 'G6',
    label: 'G6',
    isBlack: false,
    solfege: 5,
    octaveDots: 2,
  ),
  PianoKeySpec(
    token: 'A6',
    label: 'A6',
    isBlack: false,
    solfege: 6,
    octaveDots: 2,
  ),
  PianoKeySpec(
    token: 'B6',
    label: 'B6',
    isBlack: false,
    solfege: 7,
    octaveDots: 2,
  ),
];

/// 25 个黑键（C#2 → A#6），按 [afterWhiteIndex] 在白键之间排布。
const List<PianoKeySpec> kPianoFullBlackKeys = <PianoKeySpec>[
  PianoKeySpec(
    token: 'C#2',
    label: 'C#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 0,
  ),
  PianoKeySpec(
    token: 'D#2',
    label: 'D#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 1,
  ),
  PianoKeySpec(
    token: 'F#2',
    label: 'F#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 3,
  ),
  PianoKeySpec(
    token: 'G#2',
    label: 'G#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 4,
  ),
  PianoKeySpec(
    token: 'A#2',
    label: 'A#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 5,
  ),
  PianoKeySpec(
    token: 'C#3',
    label: 'C#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 7,
  ),
  PianoKeySpec(
    token: 'D#3',
    label: 'D#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 8,
  ),
  PianoKeySpec(
    token: 'F#3',
    label: 'F#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 10,
  ),
  PianoKeySpec(
    token: 'G#3',
    label: 'G#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 11,
  ),
  PianoKeySpec(
    token: 'A#3',
    label: 'A#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 12,
  ),
  PianoKeySpec(
    token: 'C#4',
    label: 'C#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 14,
  ),
  PianoKeySpec(
    token: 'D#4',
    label: 'D#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 15,
  ),
  PianoKeySpec(
    token: 'F#4',
    label: 'F#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 17,
  ),
  PianoKeySpec(
    token: 'G#4',
    label: 'G#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 18,
  ),
  PianoKeySpec(
    token: 'A#4',
    label: 'A#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 19,
  ),
  PianoKeySpec(
    token: 'C#5',
    label: 'C#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 21,
  ),
  PianoKeySpec(
    token: 'D#5',
    label: 'D#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 22,
  ),
  PianoKeySpec(
    token: 'F#5',
    label: 'F#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 24,
  ),
  PianoKeySpec(
    token: 'G#5',
    label: 'G#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 25,
  ),
  PianoKeySpec(
    token: 'A#5',
    label: 'A#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 26,
  ),
  PianoKeySpec(
    token: 'C#6',
    label: 'C#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 28,
  ),
  PianoKeySpec(
    token: 'D#6',
    label: 'D#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 29,
  ),
  PianoKeySpec(
    token: 'F#6',
    label: 'F#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 31,
  ),
  PianoKeySpec(
    token: 'G#6',
    label: 'G#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 32,
  ),
  PianoKeySpec(
    token: 'A#6',
    label: 'A#',
    isBlack: true,
    solfege: 0,
    octaveDots: 0,
    afterWhiteIndex: 33,
  ),
];

/// 中央 C 在 [kPianoFullWhiteKeys] 中的下标，用于初始 scroll 位置。
const int kPianoCenterCWhiteIndex = 14;
