import "package:just_audio/just_audio.dart";

import "../utils/constants.dart";

class BeepService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> playPttOn() => _play(AppConstants.pttOnAsset);
  Future<void> playPttOff() => _play(AppConstants.pttOffAsset);
  Future<void> playPrivateBeep() => _play(AppConstants.privateBeepAsset);
  Future<void> playBusyBeep() => _play(AppConstants.busyBeepAsset);

  Future<void> _play(String assetPath) async {
    try {
      await _player.stop();
      await _player.setAsset(assetPath);
      await _player.play();
    } catch (_) {
      // Keep UX resilient if asset decode fails on certain devices.
    }
  }

  Future<void> dispose() => _player.dispose();
}
