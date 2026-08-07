import 'package:hive_flutter/hive_flutter.dart';
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
import 'supabase_service.dart';

class DatabaseService {
  static const String userProfileBox = 'userProfiles';
  static const String subjectsBox = 'subjects';
  static const String notesBox = 'notes';
  static const String lessonsBox = 'lessons';
  static const String quizzesBox = 'quizzes';
  static const String flashcardsBox = 'flashcards';
  static const String achievementsBox = 'achievements';
  static const String studyPlansBox = 'studyPlans';
  static const String streakBox = 'streak';
  static const String playlistsBox = 'playlists';
  static const String calendarEventsBox = 'calendarEvents';
  static const String chatMessagesBox = 'chatMessages';

  // Initialize Hive
  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(UserProfileAdapter());
    Hive.registerAdapter(SubjectAdapter());
    Hive.registerAdapter(NoteAdapter());
    Hive.registerAdapter(LessonAdapter());
    Hive.registerAdapter(SlideAdapter()); // For Lesson slides
    Hive.registerAdapter(QuizAdapter());
    Hive.registerAdapter(QuestionAdapter()); // For Quiz questions
    Hive.registerAdapter(FlashcardDeckAdapter());
    Hive.registerAdapter(FlashcardAdapter()); // For Flashcard cards
    Hive.registerAdapter(AchievementAdapter());
    Hive.registerAdapter(DailyStreakAdapter());
    Hive.registerAdapter(StudyPlanAdapter());
    Hive.registerAdapter(StudyTaskAdapter()); // For StudyPlan tasks
    Hive.registerAdapter(StudyPlaylistAdapter());
    Hive.registerAdapter(PlaylistVideoAdapter()); // For Playlist videos
    Hive.registerAdapter(CalendarEventAdapter());
    Hive.registerAdapter(ChatMessageAdapter());

    // Open boxes
    await Hive.openBox<UserProfile>(userProfileBox);
    await Hive.openBox<Subject>(subjectsBox);
    await Hive.openBox<Note>(notesBox);
    await Hive.openBox<Lesson>(lessonsBox);
    await Hive.openBox<Quiz>(quizzesBox);
    await Hive.openBox<FlashcardDeck>(flashcardsBox);
    await Hive.openBox<Achievement>(achievementsBox);
    await Hive.openBox<StudyPlan>(studyPlansBox);
    await Hive.openBox<DailyStreak>(streakBox);
    await Hive.openBox<StudyPlaylist>(playlistsBox);
    await Hive.openBox<CalendarEvent>(calendarEventsBox);
    await Hive.openBox<ChatMessage>(chatMessagesBox);

    // Initialize Supabase (Use placeholders or environment variables)
    // You must replace these with your actual Supabase URL and Key
    try {
      await SupabaseService.init(
        url: 'https://eqmemqtcwxdjvpniescf.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVxbWVtcXRjd3hkanZwbmllc2NmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ4MzY3MjIsImV4cCI6MjA4MDQxMjcyMn0.HGo8_gdKLHlJsi5BI65-GNNBnU_gLG4YeF9QOGyAeBY',
      );
      print('✅ Supabase initialized');

      // Test connection
      await SupabaseService.testConnection();

      // Log auth status
      print('🔐 Is authenticated: ${SupabaseService.isAuthenticated}');
      print('👤 Current user ID: ${SupabaseService.currentUserId}');
    } catch (e) {
      print('⚠️ Supabase initialization failed: $e');
    }
  }

  // ============= USER PROFILE =============

  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final profile = await SupabaseService.getUserProfile(userId);
      if (profile != null) {
        final box = Hive.box<UserProfile>(userProfileBox);
        await box.put(profile.id, profile);
        return profile;
      }
    } catch (e) {
      print('Error fetching user profile from Supabase: $e');
    }
    // Fallback
    final box = Hive.box<UserProfile>(userProfileBox);
    return box.get(userId);
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final box = Hive.box<UserProfile>(userProfileBox);
    await box.put(profile.id, profile);
    await SupabaseService.saveUserProfile(profile);
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    await saveUserProfile(profile);
  }

  Future<void> deleteUserData(String userId) async {
    final box = Hive.box<UserProfile>(userProfileBox);
    await box.delete(userId);
    await SupabaseService.deleteUserProfile(userId);
    // Also delete all related data
    await deleteAllSubjects(userId);
  }

  // ============= SUBJECTS =============

  Future<List<Subject>> getSubjects(String userId) async {
    try {
      final subjects = await SupabaseService.getSubjects(userId);
      // A null result means the remote was unreachable, which is not the
      // same as it having no rows. Returning the empty list here would
      // wipe locally-saved subjects from the UI while offline.
      if (subjects == null) {
        final box = Hive.box<Subject>(subjectsBox);
        return box.values.toList();
      }
      final box = Hive.box<Subject>(subjectsBox);

      // Update local cache
      for (var subject in subjects) {
        await box.put(subject.id, subject);
      }
      return subjects;
    } catch (e) {
      print('Error fetching subjects from Supabase: $e');
      final box = Hive.box<Subject>(subjectsBox);
      // Filter by userId if possible, but Hive values don't enforce schema relation easily
      // Assuming all subjects in box belong to current user for single-user offline logic
      // But better to verify if 'Subject' model has userId? It doesn't in Hive model (Step 411 - no userId field!)
      // Wait, Subject model doesn't have userId?
      // Step 411: Subject has id, name... NO user_id.
      // But Supabase schema has user_id.
      // So retrieving locally from Hive means retrieving ALL subjects.
      // This is okay for single-user local logic.
      return box.values.toList();
    }
  }

  Future<Subject?> getSubject(String subjectId) async {
    final box = Hive.box<Subject>(subjectsBox);
    return box.get(subjectId);
  }

  Future<void> saveSubject(Subject subject) async {
    final box = Hive.box<Subject>(subjectsBox);
    await box.put(subject.id, subject);
    await SupabaseService.saveSubject(subject);
  }

  Future<void> updateSubject(Subject subject) async {
    subject.updatedAt = DateTime.now();
    await saveSubject(subject);
  }

  Future<void> deleteSubject(String subjectId) async {
    final box = Hive.box<Subject>(subjectsBox);
    await box.delete(subjectId);
    await SupabaseService.deleteSubject(subjectId);
    // Delete all notes for this subject
    await deleteNotesForSubject(subjectId);
  }

  Future<void> deleteAllSubjects(String userId) async {
    final box = Hive.box<Subject>(subjectsBox);
    await box.clear();
  }

  // ============= NOTES =============

  Future<List<Note>> getNotesForSubject(String subjectId) async {
    // Fetch from Supabase first
    try {
      final notes = await SupabaseService.getNotesForSubject(subjectId);
      // A null result means the remote was unreachable, which is not the
      // same as it having no rows. Returning the empty list here would
      // wipe locally-saved notes from the UI while offline.
      if (notes == null) {
        final box = Hive.box<Note>(notesBox);
        return box.values.where((note) => note.subjectId == subjectId).toList();
      }
      final box = Hive.box<Note>(notesBox);

      // Update local cache
      for (var note in notes) {
        await box.put(note.id, note);
      }

      return notes;
    } catch (e) {
      print('Error fetching notes from Supabase: $e');
      // Fallback to local
      final box = Hive.box<Note>(notesBox);
      return box.values.where((note) => note.subjectId == subjectId).toList();
    }
  }

  Future<Note?> getNote(String noteId) async {
    final box = Hive.box<Note>(notesBox);
    return box.get(noteId);
  }

  Future<void> saveNote(Note note) async {
    final box = Hive.box<Note>(notesBox);
    await box.put(note.id, note);
    await SupabaseService.saveNote(note);
  }

  /// Save a note with file upload to Supabase Storage
  /// This uploads the file first, then saves the note metadata with the storage URL
  Future<Note?> saveNoteWithFile({
    required Note note,
    required String localFilePath,
  }) async {
    try {
      // Extract filename from path
      final fileName = localFilePath.split('/').last.split('\\').last;

      // Upload file to Supabase Storage
      final storageUrl = await SupabaseService.uploadNoteFile(
        filePath: localFilePath,
        fileName: fileName,
        subjectId: note.subjectId,
      );

      if (storageUrl == null) {
        print('❌ Failed to upload file, saving note with local path only');
        // Still save the note but with local path
      } else {
        // Update note with storage URL
        note.filePath = storageUrl;
        print('✅ File uploaded, URL: $storageUrl');
      }

      // Save note metadata
      await saveNote(note);
      return note;
    } catch (e) {
      print('❌ Error saving note with file: $e');
      // Try to save just the metadata
      await saveNote(note);
      return note;
    }
  }

  Future<void> updateNote(Note note) async {
    note.updatedAt = DateTime.now();
    await saveNote(note);
  }

  Future<void> deleteNote(String noteId) async {
    final box = Hive.box<Note>(notesBox);

    // Get the note to check if we need to delete a file
    final note = box.get(noteId);
    if (note != null && note.filePath.startsWith('http')) {
      // It's a storage URL, delete the file
      await SupabaseService.deleteNoteFile(note.filePath);
    }

    await box.delete(noteId);
    await SupabaseService.deleteNote(noteId);
  }

  Future<void> deleteNotesForSubject(String subjectId) async {
    final box = Hive.box<Note>(notesBox);
    final notesToDelete =
        box.values.where((note) => note.subjectId == subjectId).toList();
    for (var note in notesToDelete) {
      if (note.filePath.startsWith('http')) {
        await SupabaseService.deleteNoteFile(note.filePath);
      }
      await box.delete(note.id);
    }
  }

  // ============= LESSONS =============

  Future<List<Lesson>> getLessonsForSubject(String subjectId) async {
    // Fetch from Supabase first
    try {
      final lessons = await SupabaseService.getLessonsForSubject(subjectId);
      // A null result means the remote was unreachable, which is not the
      // same as it having no rows. Returning the empty list here would
      // wipe locally-saved lessons from the UI while offline.
      if (lessons == null) {
        final box = Hive.box<Lesson>(lessonsBox);
        return box.values
            .where((lesson) => lesson.subjectId == subjectId)
            .toList();
      }
      final box = Hive.box<Lesson>(lessonsBox);

      // Update local cache
      for (var lesson in lessons) {
        await box.put(lesson.id, lesson);
      }

      return lessons;
    } catch (e) {
      print('Error fetching lessons from Supabase: $e');
      // Fallback to local
      final box = Hive.box<Lesson>(lessonsBox);
      return box.values
          .where((lesson) => lesson.subjectId == subjectId)
          .toList();
    }
  }

  Future<Lesson?> getLesson(String lessonId) async {
    final box = Hive.box<Lesson>(lessonsBox);
    return box.get(lessonId);
  }

  Future<void> saveLesson(Lesson lesson) async {
    final box = Hive.box<Lesson>(lessonsBox);
    await box.put(lesson.id, lesson);
    await SupabaseService.saveLesson(lesson);
  }

  Future<void> updateLesson(Lesson lesson) async {
    await saveLesson(lesson);
  }

  Future<void> deleteLesson(String lessonId) async {
    final box = Hive.box<Lesson>(lessonsBox);
    await box.delete(lessonId);
    await SupabaseService.deleteLesson(lessonId);
  }

  // ============= QUIZZES =============

  Future<List<Quiz>> getQuizzesForSubject(String subjectId) async {
    // Fetch from Supabase first
    try {
      final quizzes = await SupabaseService.getQuizzesForSubject(subjectId);
      // A null result means the remote was unreachable, which is not the
      // same as it having no rows. Returning the empty list here would
      // wipe locally-saved quizzes from the UI while offline.
      if (quizzes == null) {
        final box = Hive.box<Quiz>(quizzesBox);
        return box.values.where((quiz) => quiz.subjectId == subjectId).toList();
      }
      final box = Hive.box<Quiz>(quizzesBox);

      // Update local cache
      for (var quiz in quizzes) {
        await box.put(quiz.id, quiz);
      }

      return quizzes;
    } catch (e) {
      print('Error fetching quizzes from Supabase: $e');
      // Fallback to local
      final box = Hive.box<Quiz>(quizzesBox);
      return box.values.where((quiz) => quiz.subjectId == subjectId).toList();
    }
  }

  Future<Quiz?> getQuiz(String quizId) async {
    final box = Hive.box<Quiz>(quizzesBox);
    return box.get(quizId);
  }

  Future<void> saveQuiz(Quiz quiz) async {
    final box = Hive.box<Quiz>(quizzesBox);
    await box.put(quiz.id, quiz);
    await SupabaseService.saveQuiz(quiz);
  }

  Future<void> updateQuiz(Quiz quiz) async {
    await saveQuiz(quiz);
  }

  Future<void> deleteQuiz(String quizId) async {
    final box = Hive.box<Quiz>(quizzesBox);
    await box.delete(quizId);
    await SupabaseService.deleteQuiz(quizId);
  }

  // ============= FLASHCARDS =============

  Future<List<FlashcardDeck>> getFlashcardsForSubject(String subjectId) async {
    // Fetch from Supabase first
    try {
      final decks =
          await SupabaseService.getFlashcardDecksForSubject(subjectId);
      // A null result means the remote was unreachable, which is not the
      // same as it having no rows. Returning the empty list here would
      // wipe locally-saved decks from the UI while offline.
      if (decks == null) {
        final box = Hive.box<FlashcardDeck>(flashcardsBox);
        return box.values.where((deck) => deck.subjectId == subjectId).toList();
      }
      final box = Hive.box<FlashcardDeck>(flashcardsBox);

      // Update local cache
      for (var deck in decks) {
        await box.put(deck.id, deck);
      }

      return decks;
    } catch (e) {
      print('Error fetching flashcards from Supabase: $e');
      // Fallback to local
      final box = Hive.box<FlashcardDeck>(flashcardsBox);
      return box.values.where((deck) => deck.subjectId == subjectId).toList();
    }
  }

  Future<FlashcardDeck?> getFlashcardDeck(String deckId) async {
    final box = Hive.box<FlashcardDeck>(flashcardsBox);
    return box.get(deckId);
  }

  Future<void> saveFlashcardDeck(FlashcardDeck deck) async {
    final box = Hive.box<FlashcardDeck>(flashcardsBox);
    await box.put(deck.id, deck);
    await SupabaseService.saveFlashcardDeck(deck);
  }

  Future<void> updateFlashcardDeck(FlashcardDeck deck) async {
    await saveFlashcardDeck(deck);
  }

  Future<void> deleteFlashcardDeck(String deckId) async {
    final box = Hive.box<FlashcardDeck>(flashcardsBox);
    await box.delete(deckId);
    await SupabaseService.deleteFlashcardDeck(deckId);
  }

  // ============= GAMIFICATION =============

  Future<List<Achievement>> getAchievements() async {
    final box = Hive.box<Achievement>(achievementsBox);
    return box.values.toList();
  }

  Future<void> unlockAchievement(String achievementId) async {
    final box = Hive.box<Achievement>(achievementsBox);
    final achievement = box.get(achievementId);
    if (achievement != null && !achievement.isUnlocked) {
      achievement.isUnlocked = true;
      achievement.unlockedAt = DateTime.now();
      await box.put(achievementId, achievement);
      await SupabaseService.saveAchievement(achievement);
    }
  }

  Future<void> saveAchievement(Achievement achievement) async {
    final box = Hive.box<Achievement>(achievementsBox);
    await box.put(achievement.id, achievement);
    await SupabaseService.saveAchievement(achievement);
  }

  Future<DailyStreak?> getStreak() async {
    final box = Hive.box<DailyStreak>(streakBox);
    return box.get('current_streak');
  }

  Future<void> updateStreak(DailyStreak streak) async {
    final box = Hive.box<DailyStreak>(streakBox);
    await box.put('current_streak', streak);
  }

  // ============= STUDY PLANS =============

  Future<List<StudyPlan>> getStudyPlans(String subjectId) async {
    final box = Hive.box<StudyPlan>(studyPlansBox);
    return box.values.where((plan) => plan.subjectId == subjectId).toList();
  }

  Future<StudyPlan?> getStudyPlan(String planId) async {
    final box = Hive.box<StudyPlan>(studyPlansBox);
    return box.get(planId);
  }

  Future<void> saveStudyPlan(StudyPlan plan) async {
    final box = Hive.box<StudyPlan>(studyPlansBox);
    await box.put(plan.id, plan);
    await SupabaseService.saveStudyPlan(plan);
  }

  Future<void> updateStudyPlan(StudyPlan plan) async {
    await saveStudyPlan(plan);
  }

  Future<void> deleteStudyPlan(String planId) async {
    final box = Hive.box<StudyPlan>(studyPlansBox);
    await box.delete(planId);
    await SupabaseService.deleteStudyPlan(planId);
  }

  // ============= STATISTICS =============

  Future<Map<String, dynamic>> getUserStatistics(String userId) async {
    final subjects = await getSubjects(userId);
    final allQuizzes = Hive.box<Quiz>(quizzesBox).values.toList();
    final achievements = await getAchievements();
    final streak = await getStreak();

    int totalQuizzes = allQuizzes.length;
    int completedQuizzes = allQuizzes.where((q) => q.isCompleted).length;
    double avgScore = allQuizzes.where((q) => q.score != null).isEmpty
        ? 0.0
        : allQuizzes
                .where((q) => q.score != null)
                .map((q) => q.score!)
                .reduce((a, b) => a + b) /
            allQuizzes.where((q) => q.score != null).length;

    return {
      'totalSubjects': subjects.length,
      'totalQuizzes': totalQuizzes,
      'completedQuizzes': completedQuizzes,
      'averageScore': avgScore,
      'unlockedAchievements': achievements.where((a) => a.isUnlocked).length,
      'totalAchievements': achievements.length,
      'currentStreak': streak?.currentStreak ?? 0,
      'longestStreak': streak?.longestStreak ?? 0,
    };
  }

  // ============= PLAYLISTS =============

  Future<List<StudyPlaylist>> getAllPlaylists() async {
    final box = Hive.box<StudyPlaylist>(playlistsBox);
    return box.values.toList();
  }

  Future<List<StudyPlaylist>> getPlaylistsForSubject(String subjectId) async {
    final box = Hive.box<StudyPlaylist>(playlistsBox);
    return box.values
        .where((playlist) => playlist.subjectId == subjectId)
        .toList();
  }

  Future<StudyPlaylist?> getPlaylist(String playlistId) async {
    final box = Hive.box<StudyPlaylist>(playlistsBox);
    return box.get(playlistId);
  }

  Future<void> savePlaylist(StudyPlaylist playlist) async {
    final box = Hive.box<StudyPlaylist>(playlistsBox);
    await box.put(playlist.id, playlist);
    await SupabaseService.savePlaylist(playlist);
  }

  Future<void> updatePlaylist(StudyPlaylist playlist) async {
    playlist.updatedAt = DateTime.now();
    await savePlaylist(playlist);
  }

  Future<void> deletePlaylist(String playlistId) async {
    final box = Hive.box<StudyPlaylist>(playlistsBox);
    await box.delete(playlistId);
    await SupabaseService.deletePlaylist(playlistId);
  }

  // ============= CALENDAR EVENTS =============

  Future<List<CalendarEvent>> getAllCalendarEvents() async {
    final box = Hive.box<CalendarEvent>(calendarEventsBox);
    return box.values.toList();
  }

  Future<List<CalendarEvent>> getEventsForDate(DateTime date) async {
    final box = Hive.box<CalendarEvent>(calendarEventsBox);
    final targetDate = DateTime(date.year, date.month, date.day);
    return box.values.where((event) {
      final eventDate =
          DateTime(event.date.year, event.date.month, event.date.day);
      return eventDate == targetDate;
    }).toList();
  }

  Future<List<CalendarEvent>> getUpcomingEvents({int days = 7}) async {
    final box = Hive.box<CalendarEvent>(calendarEventsBox);
    final now = DateTime.now();
    final future = now.add(Duration(days: days));

    return box.values.where((event) {
      return event.date.isAfter(now) &&
          event.date.isBefore(future) &&
          !event.isCompleted;
    }).toList();
  }

  Future<CalendarEvent?> getCalendarEvent(String eventId) async {
    final box = Hive.box<CalendarEvent>(calendarEventsBox);
    return box.get(eventId);
  }

  Future<void> saveCalendarEvent(CalendarEvent event) async {
    final box = Hive.box<CalendarEvent>(calendarEventsBox);
    await box.put(event.id, event);
    await SupabaseService.saveCalendarEvent(event);
  }

  Future<void> updateCalendarEvent(CalendarEvent event) async {
    event.updatedAt = DateTime.now();
    await saveCalendarEvent(event);
  }

  Future<void> deleteCalendarEvent(String eventId) async {
    final box = Hive.box<CalendarEvent>(calendarEventsBox);
    await box.delete(eventId);
    await SupabaseService.deleteCalendarEvent(eventId);
  }

  // ============= CHAT MESSAGES =============

  Future<List<ChatMessage>> getChatMessagesForSubject(String subjectId) async {
    try {
      // Fetch from Supabase first
      final messages =
          await SupabaseService.getChatMessagesForSubject(subjectId);
      // A null result means the remote was unreachable, which is not the
      // same as it having no rows. Returning the empty list here would
      // wipe locally-saved messages from the UI while offline.
      if (messages == null) {
        final box = Hive.box<ChatMessage>(chatMessagesBox);
        return box.values.where((msg) => msg.subjectId == subjectId).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      final box = Hive.box<ChatMessage>(chatMessagesBox);

      // Update local cache
      for (var message in messages) {
        await box.put(message.id, message);
      }

      return messages;
    } catch (e) {
      print('Error fetching chat messages from Supabase: $e');
      // Fallback to local
      final box = Hive.box<ChatMessage>(chatMessagesBox);
      return box.values.where((msg) => msg.subjectId == subjectId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
  }

  Future<void> saveChatMessage(ChatMessage message) async {
    final box = Hive.box<ChatMessage>(chatMessagesBox);
    await box.put(message.id, message);
    await SupabaseService.saveChatMessage(message);
  }

  Future<void> deleteChatMessagesForSubject(String subjectId) async {
    final box = Hive.box<ChatMessage>(chatMessagesBox);
    final messagesToDelete =
        box.values.where((msg) => msg.subjectId == subjectId).toList();
    for (var message in messagesToDelete) {
      await box.delete(message.id);
    }
    await SupabaseService.deleteChatMessagesForSubject(subjectId);
  }

  Future<void> deleteAllChatMessages() async {
    final box = Hive.box<ChatMessage>(chatMessagesBox);
    await box.clear();
    await SupabaseService.deleteAllChatMessagesForUser();
  }
}
