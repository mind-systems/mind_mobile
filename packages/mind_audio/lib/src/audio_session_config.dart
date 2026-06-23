import 'package:audio_session/audio_session.dart';

/// Configures the global audio session for continuous background playback.
///
/// Category: playback (survives screen lock).
/// mixWithOthers: never ducks or interrupts the user's own music.
/// Safe to call on Android — the configuration is a no-op on that platform.
Future<void> configureAudioSession() async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.playback,
    avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
  ));
}
