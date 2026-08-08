import 'package:flutter_test/flutter_test.dart';

import 'package:edtech_app/services/supabase_service.dart';

/// Notes were saved to Hive but never reached Supabase, because the app adds a
/// `user_id` to the payload and the notes table has no such column. PostgREST
/// rejected the whole insert with PGRST204, the error was swallowed, and the
/// note quietly stayed local.
///
/// The writer now reads the offending column out of the error and retries
/// without it, so these strings are load-bearing.
void main() {
  group('unknownColumnOf', () {
    test('reads the column out of a real PGRST204 message', () {
      // Verbatim from the device log.
      const message =
          "PostgrestException(message: Could not find the 'user_id' column "
          "of 'notes' in the schema cache, code: PGRST204, details: Bad "
          "Request, hint: null)";
      expect(SupabaseService.unknownColumnOf(message), 'user_id');
    });

    test('handles a different column name', () {
      const message =
          "Could not find the 'subject_id' column of 'quizzes' in the schema "
          'cache';
      expect(SupabaseService.unknownColumnOf(message), 'subject_id');
    });

    test('returns null for unrelated failures, so they are not retried', () {
      expect(
          SupabaseService.unknownColumnOf('SocketException: no route'), isNull);
      expect(
        SupabaseService.unknownColumnOf(
          'new row violates row-level security policy',
        ),
        isNull,
      );
    });
  });
}
