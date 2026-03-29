import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:flutter_audio_capture/flutter_audio_capture.dart";

class AudioCaptureService {
  final FlutterAudioCapture _audioCapture = FlutterAudioCapture();
  final StreamController<Uint8List> _streamController =
      StreamController<Uint8List>.broadcast();
  bool _initialized = false;
  bool _started = false;
  Object? _lastStartError;
  int _activeSampleRate = 16000;
  double _warmFilter = 0;
  static const int _bitDepth = 16;

  Stream<Uint8List> get chunks => _streamController.stream;
  Object? get lastStartError => _lastStartError;
  bool get captureSupported => Platform.isAndroid || Platform.isIOS;
  int get sampleRate => _activeSampleRate;
  int get bitDepth => _bitDepth;

  Future<void> start() async {
    if (_started) return;
    if (!captureSupported) {
      throw UnsupportedError(
        "Captura de audio disponible solo en Android e iOS",
      );
    }
    await _ensureInitialized();

    _lastStartError = null;
    if (Platform.isAndroid) {
      // Android devices differ a lot in supported sources.
      final sources = <int>[
        ANDROID_AUDIOSRC_VOICECOMMUNICATION,
        ANDROID_AUDIOSRC_VOICERECOGNITION,
        ANDROID_AUDIOSRC_MIC,
        ANDROID_AUDIOSRC_DEFAULT,
      ];
      final sampleRates = <int>[16000];
      final bufferSizes = <int>[2048, 4096];
      Object? lastError;
      for (final source in sources) {
        for (final rate in sampleRates) {
          for (final size in bufferSizes) {
            try {
              await _audioCapture.start(
                listener,
                onError,
                sampleRate: rate,
                bufferSize: size,
                androidAudioSource: source,
                waitForFirstDataOnAndroid: false,
                waitForFirstDataOnIOS: false,
              );
              _activeSampleRate = rate;
              _started = true;
              return;
            } catch (e) {
              lastError = e;
              _lastStartError = e;
              try {
                await _audioCapture.stop();
              } catch (_) {}
            }
          }
        }
      }
      throw Exception("Audio capture start failed on Android: $lastError");
    }

    await _audioCapture.start(
      listener,
      onError,
      sampleRate: 16000,
      bufferSize: 4096,
      waitForFirstDataOnAndroid: false,
      waitForFirstDataOnIOS: false,
    );
    _activeSampleRate = 16000;
    _started = true;
  }

  Future<void> stop() async {
    if (!_started) return;
    try {
      await _audioCapture.stop();
    } finally {
      _started = false;
      _warmFilter = 0;
    }
  }

  void listener(dynamic data) {
    if (data is! List) return;

    final sampleCount = data.length;
    if (sampleCount == 0) return;

    final bytes = Uint8List(sampleCount * 2);
    final byteData = ByteData.view(bytes.buffer);

    for (var i = 0; i < sampleCount; i++) {
      final raw = data[i];
      if (raw is! num) {
        byteData.setInt16(i * 2, 0, Endian.little);
        continue;
      }

      var x = raw.toDouble();
      if (!x.isFinite) x = 0;
      if (x > 1 || x < -1) {
        x = x / 32768.0;
      }
      x = x.clamp(-1.0, 1.0);

      // Light gate + preamp + soft clip for stronger voice with gentle warmth.
      if (x.abs() < 0.008) x = 0;
      x *= 1.58;
      x = x / (1 + (0.36 * x.abs()));
      _warmFilter += (x - _warmFilter) * 0.18;
      x = (x * 0.84) + (_warmFilter * 0.16);

      final i16 = (x * 32767).round().clamp(-32768, 32767);
      byteData.setInt16(i * 2, i16, Endian.little);
    }

    _streamController.add(bytes);
  }

  void onError(Object error) {
    _lastStartError = error;
    if (!_streamController.isClosed) {
      _streamController.addError(error);
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final ok = await _audioCapture.init();
    if (ok != true) {
      throw Exception("FlutterAudioCapture init failed");
    }
    _initialized = true;
  }

  void dispose() {
    unawaited(stop());
    _streamController.close();
  }
}
