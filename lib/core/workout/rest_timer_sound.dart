import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../preferences/rest_timer_prefs.dart';

/// Sinal sonoro (e háptico) ao fim do descanso entre séries.
abstract final class RestTimerSound {
  RestTimerSound._();

  static AudioPlayer? _player;
  static var _contextReady = false;

  static const _assetPath = 'sounds/rest_timer_beep.wav';

  /// Pré-carrega o bip para tocar sem atraso ao zerar o timer.
  static Future<void> preload() async {
    try {
      await _ensureAudioContext();
      await AudioCache.instance.load(_assetPath);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('RestTimerSound.preload: $e\n$st');
      }
    }
  }

  static Future<void> _ensureAudioContext() async {
    if (_contextReady) return;
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ),
    );
    _contextReady = true;
  }

  static AudioPlayer _playerInstance() {
    final p = _player ??= AudioPlayer();
    unawaited(p.setReleaseMode(ReleaseMode.stop));
    return p;
  }

  static Future<void> playEndIfEnabled() async {
    if (!await RestTimerPrefs.isSoundEnabled()) return;
    await HapticFeedback.heavyImpact();
    try {
      await _ensureAudioContext();
      final player = _playerInstance();
      await player.setVolume(1);
      for (var i = 0; i < 2; i++) {
        if (i > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 130));
        }
        await player.stop();
        await player.play(AssetSource(_assetPath));
        try {
          await player.onPlayerComplete.first.timeout(
            const Duration(seconds: 2),
          );
        } on TimeoutException {
          // segue para o segundo bip
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('RestTimerSound.playEndIfEnabled: $e\n$st');
      }
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }
}
