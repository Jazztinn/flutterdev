import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum XmbSound { opening, navigation, confirm, startGame, back }

typedef XmbSoundPlayer = void Function(XmbSound sound);

/// load sound players before they are needed
class XmbAudio {
  static const _navigationVoiceCount = 8;

  static const assets = {
    XmbSound.opening: 'audio/opening.mp3',
    XmbSound.navigation: 'audio/cursor.mp3',
    XmbSound.confirm: 'audio/confirm.mp3',
    XmbSound.startGame: 'audio/start-game.mp3',
    XmbSound.back: 'audio/cancel.mp3',
  };

  final _players = <XmbSound, List<AudioPlayer>>{};
  final _ready = <XmbSound>{};
  final _requests = <XmbSound, int>{};
  int _navigationVoice = 0;
  bool _disposed = false;

  void initialize() {
    // prepare every sound in the background
    for (final entry in assets.entries) {
      final count = entry.key == XmbSound.navigation
          ? _navigationVoiceCount
          : 1;
      unawaited(_prepare(entry.key, entry.value, count));
    }
  }

  Future<void> _prepare(XmbSound sound, String asset, int count) async {
    // create one or more players for this sound
    try {
      final players = <AudioPlayer>[];
      for (var index = 0; index < count; index++) {
        final player = AudioPlayer();
        players.add(player);
        await player.setReleaseMode(ReleaseMode.stop);
        if (_disposed) return;
        await player.setSource(AssetSource(asset));
        if (_disposed) return;
      }
      _players[sound] = players;
      _ready.add(sound);
      // play opening sound on native platforms
      if (sound == XmbSound.opening && !kIsWeb) play(sound);
    } catch (error) {
      debugPrint('PSP audio preload: $error');
    }
  }

  void play(XmbSound sound) {
    // play one sound without blocking the menu
    if (_disposed) return;
    if (sound == XmbSound.back) {
      unawaited(_stop(XmbSound.confirm));
      unawaited(_stop(XmbSound.startGame));
    }
    if (!_ready.contains(sound)) return;
    if (sound == XmbSound.navigation) {
      // use another voice so fast moves can overlap
      final players = _players[sound]!;
      final player = players[_navigationVoice];
      _navigationVoice = (_navigationVoice + 1) % players.length;
      unawaited(_playVoice(player));
      return;
    }
    final request = (_requests[sound] ?? 0) + 1;
    _requests[sound] = request;
    unawaited(_play(sound, request));
  }

  Future<void> _play(XmbSound sound, int request) async {
    // play one normal sound.
    try {
      final player = _players[sound]!.single;
      await player.stop();
      if (_disposed || _requests[sound] != request) return;
      await player.resume();
    } catch (error) {
      debugPrint('PSP audio playback: $error');
    }
  }

  Future<void> _playVoice(AudioPlayer player) async {
    // restart one navigation voice.
    try {
      await player.stop();
      if (_disposed) return;
      await player.resume();
    } catch (error) {
      debugPrint('PSP navigation playback: $error');
    }
  }

  Future<void> _stop(XmbSound sound) async {
    // stop every player for this sound.
    _requests[sound] = (_requests[sound] ?? 0) + 1;
    try {
      for (final player in _players[sound] ?? const <AudioPlayer>[]) {
        await player.stop();
      }
    } catch (error) {
      debugPrint('PSP audio stop: $error');
    }
  }

  void dispose() {
    // release audio resources.
    _disposed = true;
    for (final players in _players.values) {
      for (final player in players) {
        unawaited(
          player.dispose().catchError((Object error) {
            debugPrint('PSP audio disposal: $error');
          }),
        );
      }
    }
    _players.clear();
    _ready.clear();
  }
}
