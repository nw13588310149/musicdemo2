import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'recording_capture.dart';

RecordingCapture createPlatformRecordingCapture() => _BrowserRecordingCapture();

class _BrowserRecordingCapture implements RecordingCapture {
  final StreamController<double> _amplitudes =
      StreamController<double>.broadcast();

  web.MediaStream? _stream;
  web.MediaRecorder? _recorder;
  web.AudioContext? _audioContext;
  web.MediaStreamAudioSourceNode? _sourceNode;
  web.AnalyserNode? _analyser;
  Timer? _amplitudeTimer;
  Completer<String?>? _stopCompleter;
  String? _objectUrl;
  bool _paused = false;

  @override
  Stream<double> get amplitudes => _amplitudes.stream;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start({required String path}) async {
    await _cleanup(revokeUrl: false);

    final stream = await web.window.navigator.mediaDevices
        .getUserMedia(
          web.MediaStreamConstraints(audio: true.toJS, video: false.toJS),
        )
        .toDart;
    _stream = stream;

    final mimeType = _preferredMimeType();
    final recorder = mimeType.isEmpty
        ? web.MediaRecorder(stream)
        : web.MediaRecorder(
            stream,
            web.MediaRecorderOptions(
              mimeType: mimeType,
              audioBitsPerSecond: 128000,
            ),
          );
    _recorder = recorder;
    _paused = false;

    web.Blob? recordedBlob;
    recorder.addEventListener(
      'dataavailable',
      ((web.Event event) {
        final blob = (event as web.BlobEvent).data;
        if (blob.size > 0) {
          recordedBlob = blob;
        }
      }).toJS,
    );
    recorder.addEventListener(
      'stop',
      ((web.Event _) {
        final blob = recordedBlob;
        final completer = _stopCompleter;
        _stopCompleter = null;
        if (blob == null || blob.size <= 0) {
          completer?.complete(null);
          return;
        }
        final previous = _objectUrl;
        if (previous != null) {
          web.URL.revokeObjectURL(previous);
        }
        final url = web.URL.createObjectURL(blob);
        _objectUrl = url;
        completer?.complete(url);
      }).toJS,
    );
    recorder.addEventListener(
      'error',
      ((web.Event event) {
        final completer = _stopCompleter;
        _stopCompleter = null;
        if (completer != null && !completer.isCompleted) {
          completer.completeError(StateError('MediaRecorder error: ${event.type}'));
        }
      }).toJS,
    );

    _startAnalyzer(stream);
    recorder.start();
  }

  @override
  Future<void> pause() async {
    final recorder = _recorder;
    if (recorder == null || recorder.state != 'recording') return;
    recorder.pause();
    _paused = true;
    _stopAmplitudeTimer();
  }

  @override
  Future<void> resume() async {
    final recorder = _recorder;
    final stream = _stream;
    if (recorder == null || stream == null || recorder.state != 'paused') return;
    recorder.resume();
    _paused = false;
    _startAmplitudeTimer();
  }

  @override
  Future<String?> stop() async {
    final recorder = _recorder;
    if (recorder == null) return null;
    if (recorder.state == 'inactive') {
      final url = _objectUrl;
      await _cleanup(revokeUrl: false);
      return url;
    }

    _stopCompleter = Completer<String?>();
    _stopAmplitudeTimer();
    recorder.stop();
    final url = await _stopCompleter!.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => null,
    );
    await _cleanup(revokeUrl: false);
    return url;
  }

  @override
  Future<void> cancel() async {
    final recorder = _recorder;
    _stopAmplitudeTimer();
    if (recorder != null && recorder.state != 'inactive') {
      try {
        recorder.stop();
      } catch (_) {}
    }
    await _cleanup(revokeUrl: true);
  }

  @override
  Future<bool> isRecording() async => _recorder?.state == 'recording';

  @override
  Future<bool> isPaused() async => _paused || _recorder?.state == 'paused';

  @override
  Future<void> dispose() async {
    await cancel();
    await _amplitudes.close();
  }

  String _preferredMimeType() {
    const candidates = <String>[
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/mp4',
      'audio/ogg;codecs=opus',
    ];
    for (final type in candidates) {
      if (web.MediaRecorder.isTypeSupported(type)) return type;
    }
    return '';
  }

  void _startAnalyzer(web.MediaStream stream) {
    final context = web.AudioContext(
      web.AudioContextOptions(latencyHint: 'interactive'.toJS),
    );
    final analyser = context.createAnalyser()
      ..fftSize = 512
      ..smoothingTimeConstant = 0.72;
    final source = context.createMediaStreamSource(stream);
    source.connect(analyser);

    _audioContext = context;
    _sourceNode = source;
    _analyser = analyser;
    _startAmplitudeTimer();
  }

  void _startAmplitudeTimer() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      final analyser = _analyser;
      if (analyser == null || _paused) return;

      final data = Uint8List(analyser.frequencyBinCount);
      analyser.getByteTimeDomainData(data.toJS);

      var peak = 0.0;
      for (final value in data) {
        peak = math.max(peak, (value - 128).abs() / 128.0);
      }
      if (!_amplitudes.isClosed) {
        _amplitudes.add(math.pow(peak.clamp(0.0, 1.0), 0.72).toDouble());
      }
    });
  }

  void _stopAmplitudeTimer() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
  }

  Future<void> _cleanup({required bool revokeUrl}) async {
    _stopAmplitudeTimer();

    final source = _sourceNode;
    _sourceNode = null;
    if (source != null) {
      try {
        source.disconnect();
      } catch (_) {}
    }

    final context = _audioContext;
    _audioContext = null;
    _analyser = null;
    if (context != null && context.state != 'closed') {
      try {
        await context.close().toDart;
      } catch (_) {}
    }

    final stream = _stream;
    _stream = null;
    if (stream != null) {
      final tracks = stream.getTracks().toDart;
      for (final track in tracks) {
        track.stop();
      }
    }

    _recorder = null;
    _paused = false;

    if (revokeUrl) {
      final url = _objectUrl;
      _objectUrl = null;
      if (url != null) {
        web.URL.revokeObjectURL(url);
      }
    }
  }
}
