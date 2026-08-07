import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../models/subject.dart';
import '../models/note.dart';
import '../models/lesson.dart';
import '../models/quiz.dart';
import '../models/flashcard.dart';
import '../models/gamification.dart';
import '../models/playlist.dart';
import '../models/calendar.dart';
import '../models/chat_message.dart';

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

  // Tables
  static const String usersTable = 'profiles';
  static const String subjectsTable = 'subjects';
  static const String notesTable = 'notes';
  static const String lessonsTable = 'lessons';
  static const String quizzesTable = 'quizzes';
  static const String flashcardsTable =
      'flashcard_decks'; // Changed to store Decks
  static const String achievementsTable = 'achievements';
  static const String studyPlansTable = 'study_plans';
  static const String playlistsTable =
      'study_playlists'; // Changed to match schema
  static const String calendarEventsTable = 'calendar_events';
  static const String chatMessagesTable = 'chat_messages';

  static Future<void> init(
      {required String url, required String anonKey}) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  // Store Firebase user ID (since we use Firebase Auth, not Supabase Auth)
  static String? _firebaseUserId;

  static void setFirebaseUserId(String? userId) {
    _firebaseUserId = userId;
    print('📱 Firebase User ID set in SupabaseService: $userId');
  }

  static String? get firebaseUserId => _firebaseUserId;

  // Debug method to test connection
  static Future<bool> testConnection() async {
    try {
      // Try a simple query
      final response = await client.from('profiles').select().limit(1);
      print('✅ Supabase connection test passed: $response');
      return true;
    } catch (e) {
      print('❌ Supabase connection test failed: $e');
      return false;
    }
  }

  // Get current user ID (prefer Firebase, fallback to Supabase)
  static String? get currentUserId =>
      _firebaseUserId ?? client.auth.currentUser?.id;

  // Check if user is authenticated
  static bool get isAuthenticated =>
      _firebaseUserId != null || client.auth.currentUser != null;

  // ============= USER PROFILE =============

  static Future<void> saveUserProfile(UserProfile profile) async {
    try {
      await client.from(usersTable).upsert(profile.toJson());
      print('✅ User profile saved: ${profile.id}');
    } catch (e) {
      print('❌ Error saving user profile to Supabase: $e');
    }
  }

  static Future<void> deleteUserProfile(String userId) async {
    try {
      await client.from(usersTable).delete().eq('id', userId);
    } catch (e) {
      print('Error deleting user profile from Supabase: $e');
    }
  }

  // ============= SUBJECTS =============

  static Future<void> saveSubject(Subject subject) async {
    try {
      final data = subject.toJson();
      // Use Firebase user ID, not Supabase auth
      data['user_id'] = _firebaseUserId;
      if (data['user_id'] == null) {
        print('⚠️ Warning: No user ID available when saving subject!');
      }
      await client.from(subjectsTable).upsert(data);
      print('✅ Subject saved: ${subject.name}');
    } catch (e) {
      print('❌ Error saving subject to Supabase: $e');
    }
  }

  static Future<void> deleteSubject(String subjectId) async {
    try {
      await client.from(subjectsTable).delete().eq('id', subjectId);
    } catch (e) {
      print('Error deleting subject from Supabase: $e');
    }
  }

  // ============= NOTES =============

  // Storage bucket name for notes/documents
  static const String notesBucket = 'notes';

  /// Upload a file to Supabase Storage
  /// Returns the public URL of the uploaded file
  static Future<String?> uploadNoteFile({
    required String filePath,
    required String fileName,
    required String subjectId,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ File does not exist: $filePath');
        return null;
      }

      final bytes = await file.readAsBytes();
      final userId = _firebaseUserId ?? 'anonymous';

      // Create a unique path: userId/subjectId/timestamp_filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = '$userId/$subjectId/${timestamp}_$fileName';

      // Upload to storage
      await client.storage.from(notesBucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _getContentType(fileName),
              upsert: true,
            ),
          );

      // Get public URL
      final publicUrl =
          client.storage.from(notesBucket).getPublicUrl(storagePath);
      print('✅ File uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Error uploading file to Supabase Storage: $e');
      return null;
    }
  }

  /// Delete a file from Supabase Storage
  static Future<bool> deleteNoteFile(String fileUrl) async {
    try {
      // Extract the path from the URL
      final uri = Uri.parse(fileUrl);
      final pathSegments = uri.pathSegments;
      // Find 'notes' bucket and get everything after it
      final bucketIndex = pathSegments.indexOf('notes');
      if (bucketIndex == -1 || bucketIndex >= pathSegments.length - 1) {
        print('❌ Invalid file URL format');
        return false;
      }
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

      await client.storage.from(notesBucket).remove([filePath]);
      print('✅ File deleted successfully');
      return true;
    } catch (e) {
      print('❌ Error deleting file from Supabase Storage: $e');
      return false;
    }
  }

  /// Get content type based on file extension
  static String _getContentType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'txt':
        return 'text/plain';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  static Future<void> saveNote(Note note) async {
    try {
      final data = note.toJson();
      data['user_id'] = _firebaseUserId;
      await client.from(notesTable).upsert(data);
      print('✅ Note saved: ${note.title}');
    } catch (e) {
      print('❌ Error saving note to Supabase: $e');
    }
  }

  static Future<void> deleteNote(String noteId) async {
    try {
      await client.from(notesTable).delete().eq('id', noteId);
    } catch (e) {
      print('Error deleting note from Supabase: $e');
    }
  }

  // ============= LESSONS =============

  static Future<void> saveLesson(Lesson lesson) async {
    try {
      await client.from(lessonsTable).upsert(lesson.toJson());
    } catch (e) {
      print('Error saving lesson to Supabase: $e');
    }
  }

  static Future<void> deleteLesson(String lessonId) async {
    try {
      await client.from(lessonsTable).delete().eq('id', lessonId);
    } catch (e) {
      print('Error deleting lesson from Supabase: $e');
    }
  }

  // ============= QUIZZES =============

  static Future<void> saveQuiz(Quiz quiz) async {
    try {
      await client.from(quizzesTable).upsert(quiz.toJson());
    } catch (e) {
      print('Error saving quiz to Supabase: $e');
    }
  }

  static Future<void> deleteQuiz(String quizId) async {
    try {
      await client.from(quizzesTable).delete().eq('id', quizId);
    } catch (e) {
      print('Error deleting quiz from Supabase: $e');
    }
  }

  // ============= INTERACTIVE =============

  static Future<void> saveFlashcardDeck(FlashcardDeck deck) async {
    try {
      await client.from(flashcardsTable).upsert(deck.toJson());
    } catch (e) {
      print('Error saving flashcard deck to Supabase: $e');
    }
  }

  static Future<void> deleteFlashcardDeck(String deckId) async {
    try {
      await client.from(flashcardsTable).delete().eq('id', deckId);
    } catch (e) {
      print('Error deleting flashcard deck from Supabase: $e');
    }
  }

  static Future<void> saveAchievement(Achievement achievement) async {
    try {
      final data = achievement.toJson();
      data['user_id'] = _firebaseUserId;
      await client.from(achievementsTable).upsert(data);
    } catch (e) {
      print('Error saving achievement to Supabase: $e');
    }
  }

  static Future<void> saveStudyPlan(StudyPlan plan) async {
    try {
      await client.from(studyPlansTable).upsert(plan.toJson());
    } catch (e) {
      print('Error saving study plan to Supabase: $e');
    }
  }

  static Future<void> deleteStudyPlan(String planId) async {
    try {
      await client.from(studyPlansTable).delete().eq('id', planId);
    } catch (e) {
      print('Error deleting study plan from Supabase: $e');
    }
  }

  static Future<void> savePlaylist(StudyPlaylist playlist) async {
    try {
      await client.from(playlistsTable).upsert(playlist.toJson());
    } catch (e) {
      print('Error saving playlist to Supabase: $e');
    }
  }

  static Future<void> deletePlaylist(String playlistId) async {
    try {
      await client.from(playlistsTable).delete().eq('id', playlistId);
    } catch (e) {
      print('Error deleting playlist from Supabase: $e');
    }
  }

  static Future<void> saveCalendarEvent(CalendarEvent event) async {
    try {
      final data = event.toJson();
      data['user_id'] = client.auth.currentUser?.id;
      await client.from(calendarEventsTable).upsert(data);
    } catch (e) {
      print('Error saving calendar event to Supabase: $e');
    }
  }

  static Future<void> deleteCalendarEvent(String eventId) async {
    try {
      await client.from(calendarEventsTable).delete().eq('id', eventId);
    } catch (e) {
      print('Error deleting calendar event from Supabase: $e');
    }
  }

  // ============= GET METHODS =============

  static Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response =
          await client.from(usersTable).select().eq('id', userId).maybeSingle();
      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error getting user profile from Supabase: $e');
      return null;
    }
  }

  static Future<List<Subject>> getSubjects(String userId) async {
    try {
      final response =
          await client.from(subjectsTable).select().eq('user_id', userId);
      return (response as List).map((json) => Subject.fromJson(json)).toList();
    } catch (e) {
      print('Error getting subjects from Supabase: $e');
      return [];
    }
  }

  static Future<List<Note>> getNotesForSubject(String subjectId) async {
    try {
      final response =
          await client.from(notesTable).select().eq('subject_id', subjectId);
      return (response as List).map((json) => Note.fromJson(json)).toList();
    } catch (e) {
      print('Error getting notes from Supabase: $e');
      return [];
    }
  }

  static Future<List<Lesson>> getLessonsForSubject(String subjectId) async {
    try {
      final response =
          await client.from(lessonsTable).select().eq('subject_id', subjectId);
      return (response as List).map((json) => Lesson.fromJson(json)).toList();
    } catch (e) {
      print('Error getting lessons from Supabase: $e');
      return [];
    }
  }

  static Future<List<Quiz>> getQuizzesForSubject(String subjectId) async {
    try {
      final response =
          await client.from(quizzesTable).select().eq('subject_id', subjectId);
      return (response as List).map((json) => Quiz.fromJson(json)).toList();
    } catch (e) {
      print('Error getting quizzes from Supabase: $e');
      return [];
    }
  }

  static Future<List<FlashcardDeck>> getFlashcardDecksForSubject(
      String subjectId) async {
    try {
      final response = await client
          .from(flashcardsTable)
          .select()
          .eq('subject_id', subjectId);
      return (response as List)
          .map((json) => FlashcardDeck.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting flashcard decks from Supabase: $e');
      return [];
    }
  }

  static Future<List<Achievement>> getAchievements() async {
    try {
      final response = await client.from(achievementsTable).select();
      return (response as List)
          .map((json) => Achievement.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting achievements from Supabase: $e');
      return [];
    }
  }

  static Future<List<StudyPlan>> getStudyPlansForSubject(
      String subjectId) async {
    try {
      final response = await client
          .from(studyPlansTable)
          .select()
          .eq('subject_id', subjectId);
      return (response as List)
          .map((json) => StudyPlan.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting study plans from Supabase: $e');
      return [];
    }
  }

  static Future<List<StudyPlaylist>> getPlaylistsForSubject(
      String subjectId) async {
    try {
      final response = await client
          .from(playlistsTable)
          .select()
          .eq('subject_id', subjectId);
      return (response as List)
          .map((json) => StudyPlaylist.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting playlists from Supabase: $e');
      return [];
    }
  }

  static Future<List<CalendarEvent>> getCalendarEvents() async {
    try {
      final response = await client.from(calendarEventsTable).select();
      return (response as List)
          .map((json) => CalendarEvent.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting calendar events from Supabase: $e');
      return [];
    }
  }
// ============= CHAT MESSAGES =============

  static Future<List<ChatMessage>> getChatMessagesForSubject(
      String subjectId) async {
    try {
      final response = await client
          .from(chatMessagesTable)
          .select()
          .eq('subject_id', subjectId)
          .order('created_at', ascending: true);
      return (response as List)
          .map((json) => ChatMessage.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting chat messages from Supabase: $e');
      return [];
    }
  }

  static Future<void> saveChatMessage(ChatMessage message) async {
    try {
      final data = message.toJson();
      // Ensure user_id is set
      // If message.userId is 'anonymous', replace with actual user ID if available?
      // But message.userId is usually passed from caller.
      // Just in case, ensure consistent user_id logic if needed.
      // But local message object should strictly be saved.
      await client.from(chatMessagesTable).upsert(data);
    } catch (e) {
      print('Error saving chat message to Supabase: $e');
    }
  }

  static Future<void> deleteChatMessagesForSubject(String subjectId) async {
    try {
      await client.from(chatMessagesTable).delete().eq('subject_id', subjectId);
    } catch (e) {
      print('Error deleting chat messages from Supabase: $e');
    }
  }

  static Future<void> deleteAllChatMessagesForUser() async {
    try {
      final userId = currentUserId;
      if (userId != null) {
        await client.from(chatMessagesTable).delete().eq('user_id', userId);
      }
    } catch (e) {
      print('Error deleting all chat messages from Supabase: $e');
    }
  }
}
