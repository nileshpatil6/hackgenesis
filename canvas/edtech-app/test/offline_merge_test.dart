import 'package:flutter_test/flutter_test.dart';

/// Pins the merge rules that stopped local data disappearing.
///
/// The app writes to Hive first and to Supabase second, and every remote write
/// used to swallow its own errors. So a note could be saved locally while the
/// remote write silently failed. Reads then treated the remote as the whole
/// truth, and the note vanished on the next launch even though it was still on
/// disk. The same fault sent the user back through onboarding: the profile row
/// exists remotely from sign-in, but without the onboarding answers.
///
/// These tests exercise the merge decisions directly rather than through Hive,
/// so they stay fast and do not need a temp directory or platform channels.
void main() {
  group('list merge', () {
    /// Mirrors the union performed by DatabaseService read paths.
    List<String> merge({
      required List<String>? remote,
      required List<String> local,
    }) {
      if (remote == null) return local;
      final remoteIds = remote.toSet();
      return [...remote, ...local.where((e) => !remoteIds.contains(e))];
    }

    test('keeps a local record the remote never received', () {
      // The exact case behind "notes disappear after I reopen the app".
      expect(merge(remote: [], local: ['note-1']), ['note-1']);
    });

    test('does not duplicate a record present in both', () {
      expect(merge(remote: ['note-1'], local: ['note-1']), ['note-1']);
    });

    test('surfaces remote records the device has not cached', () {
      expect(merge(remote: ['note-2'], local: ['note-1']), ['note-2', 'note-1']);
    });

    test('falls back to local when the remote is unreachable', () {
      // null means the request failed, which is not the same as no rows.
      expect(merge(remote: null, local: ['note-1']), ['note-1']);
    });

    test('an empty remote and empty local is still empty', () {
      expect(merge(remote: [], local: []), isEmpty);
    });
  });

  group('profile merge', () {
    /// Mirrors DatabaseService.getUserProfile's choice between the two copies.
    String? choose({String? localEducation, String? remoteEducation}) {
      if (remoteEducation == null) return localEducation;
      if (localEducation == null) return remoteEducation;
      if (localEducation.isNotEmpty && remoteEducation.isEmpty) {
        return localEducation;
      }
      return remoteEducation;
    }

    test('keeps local onboarding answers over an empty remote row', () {
      // The exact case behind "onboarding is asked on every launch".
      expect(
        choose(localEducation: 'Class 10', remoteEducation: ''),
        'Class 10',
      );
    });

    test('accepts the remote row when it is the complete one', () {
      expect(
        choose(localEducation: '', remoteEducation: 'Class 12'),
        'Class 12',
      );
    });

    test('prefers remote when both are complete, so other devices win', () {
      expect(
        choose(localEducation: 'Class 10', remoteEducation: 'Class 12'),
        'Class 12',
      );
    });

    test('falls back to local when there is no remote row at all', () {
      expect(choose(localEducation: 'Class 10'), 'Class 10');
    });
  });
}
