import 'package:flutter_test/flutter_test.dart';

import 'package:edtech_app/screens/subjects/voice_tutor_screen.dart';
import 'package:edtech_app/services/realtime_voice_service.dart';

/// The voice screen once showed an error banner and the word "Listening" at
/// the same time: `start()` emitted `listening` unconditionally after the
/// socket had already closed and reported a failure. The service now tears the
/// session down on failure and finishes in [VoiceSessionState.idle], so the
/// screen must read as ended rather than still running.
void main() {
  group('voiceControlLabels', () {
    test('a fresh screen invites the user to start', () {
      final (label, caption) =
          voiceControlLabels(VoiceSessionState.idle, hasError: false);
      expect(label, 'Start session');
      expect(caption, 'Tap to begin');
    });

    test('an idle session that failed offers a retry, not a fresh start', () {
      // The state after _failAndTeardown: error surfaced, hardware released.
      final (label, caption) =
          voiceControlLabels(VoiceSessionState.idle, hasError: true);
      expect(label, 'Try again');
      expect(caption, 'Session ended');
    });

    test('never claims to be listening once something has failed', () {
      for (final state in VoiceSessionState.values) {
        final (_, caption) = voiceControlLabels(state, hasError: true);
        if (state == VoiceSessionState.listening ||
            state == VoiceSessionState.speaking) {
          continue; // a live session that later errors is still live
        }
        expect(
          caption,
          isNot('Listening'),
          reason: '$state reported Listening alongside an error',
        );
      }
    });

    test('a live session offers a way out', () {
      for (final state in [
        VoiceSessionState.listening,
        VoiceSessionState.speaking,
      ]) {
        final (label, _) = voiceControlLabels(state, hasError: false);
        expect(label, 'End session');
      }
    });

    test('every state has a label and a caption', () {
      for (final state in VoiceSessionState.values) {
        for (final hasError in [true, false]) {
          final (label, caption) =
              voiceControlLabels(state, hasError: hasError);
          expect(label, isNotEmpty);
          expect(caption, isNotEmpty);
        }
      }
    });
  });
}
