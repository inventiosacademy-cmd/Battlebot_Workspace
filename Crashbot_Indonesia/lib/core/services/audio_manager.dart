import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages lobby background music and volume levels globally.
class AudioManager with ChangeNotifier {
  static const String _volumePrefsKey = 'lobby_music_volume';
  static const String _musicEnabledPrefsKey = 'lobby_music_enabled';

  final AudioPlayer _audioPlayer = AudioPlayer();
  
  double _volume = 0.5; // Default volume: 50%
  double get volume => _volume;

  bool _isMusicEnabled = true;
  bool get isMusicEnabled => _isMusicEnabled;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool _inLobby = false;

  AudioManager() {
    _loadSettings();
  }

  /// Initial settings loading from SharedPreferences.
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _volume = prefs.getDouble(_volumePrefsKey) ?? 0.5;
      _isMusicEnabled = prefs.getBool(_musicEnabledPrefsKey) ?? true;
      
      await _audioPlayer.setVolume(_volume);
      
      // Configure looping behavior
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      if (_inLobby) {
        startLobbyMusic();
      }
    } catch (e) {
      debugPrint('AudioManager: Failed to load settings — $e');
    }
  }

  /// Start playing lobby background music with loop mode.
  Future<void> startLobbyMusic() async {
    _inLobby = true;
    if (!_isMusicEnabled) return;

    try {
      if (!_isPlaying) {
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer.setVolume(_volume);
        // Play asset from local path using AssetSource
        await _audioPlayer.play(AssetSource('Titan_s_Last_Breath.mp3'));
        _isPlaying = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('AudioManager: Failed to play music — $e');
    }
  }

  /// Temporarily pause background music (e.g., when leaving lobby).
  Future<void> pauseLobbyMusic() async {
    _inLobby = false;
    if (!_isPlaying) return;

    try {
      await _audioPlayer.pause();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('AudioManager: Failed to pause music — $e');
    }
  }

  /// Stop background music.
  Future<void> stopLobbyMusic() async {
    _inLobby = false;
    if (!_isPlaying) return;

    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('AudioManager: Failed to stop music — $e');
    }
  }

  /// Adjust the music volume (0.0 to 1.0) and save to SharedPreferences.
  Future<void> setVolume(double val) async {
    _volume = val.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(_volume);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_volumePrefsKey, _volume);
    } catch (e) {
      debugPrint('AudioManager: Failed to save volume — $e');
    }
  }

  /// Enable or disable lobby music completely.
  Future<void> setMusicEnabled(bool enabled) async {
    _isMusicEnabled = enabled;
    notifyListeners();

    if (enabled) {
      if (_inLobby) {
        await startLobbyMusic();
      }
    } else {
      await stopLobbyMusic();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_musicEnabledPrefsKey, _isMusicEnabled);
    } catch (e) {
      debugPrint('AudioManager: Failed to save music enabled state — $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
