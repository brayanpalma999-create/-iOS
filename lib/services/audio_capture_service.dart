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

  Stream<Uint8List> get chunks => _streamController.stream;
  Object? get lastStartError => _lastStartError;
  bool get captureSupported => Platform.isAndroid || Platform.isIOS;
  int get sampleRate => _activeSampleRate;

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
      final sampleRates = <int>[16000, 24000, 44100];
      final bufferSizes = <int>[1024, 2048, 4096];
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
      bufferSize: 2048,
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
    }
  }

  void listener(dynamic data) {
    if (data is List<double>) {
      final bytes = Uint8List.fromList(
        data.map((e) => ((e * 127) + 128).clamp(0, 255).toInt()).toList(),
      );
      _streamController.add(bytes);
    }
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
