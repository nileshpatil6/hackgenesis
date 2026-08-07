import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/subject.dart';
import '../models/note.dart';
import '../models/lesson.dart';
import '../models/quiz.dart';
import '../models/flashcard.dart';
import '../services/database_service.dart';

class SubjectProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  List<Subject> _subjects = [];
  Subject? _currentSubject;
  bool _isLoading = false;

  List<Subject> get subjects => _subjects;
  Subject? get currentSubject => _currentSubject;
  bool get isLoading => _isLoading;

  // Load all subjects
  Future<void> loadSubjects(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _subjects = await _dbService.getSubjects(userId);
    } catch (e) {
      print('Error loading subjects: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create new subject
  Future<Subject> createSubject({
    required String name,
    String? description,
    required String color,
    String? iconName,
  }) async {
    final subject = Subject(
      id: const Uuid().v4(),
      name: name,
      description: description,
      color: color,
      iconName: iconName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Note: the AI vector store for this subject is created lazily the
    // first time SubjectDetailScreen opens (see OpenAIRagService), once an
    // API key is available.
    await _dbService.saveSubject(subject);
    _subjects.add(subject);
    notifyListeners();

    return subject;
  }

  // Update subject
  Future<void> updateSubject(Subject subject) async {
    await _dbService.updateSubject(subject);

    final index = _subjects.indexWhere((s) => s.id == subject.id);
    if (index != -1) {
      _subjects[index] = subject;
      if (_currentSubject?.id == subject.id) {
        _currentSubject = subject;
      }
      notifyListeners();
    }
  }

  // Delete subject
  Future<void> deleteSubject(String subjectId) async {
    await _dbService.deleteSubject(subjectId);

    _subjects.removeWhere((s) => s.id == subjectId);
    if (_currentSubject?.id == subjectId) {
      _currentSubject = null;
    }
    notifyListeners();
  }

  // Set current subject
  void setCurrentSubject(Subject subject) {
    _currentSubject = subject;
    notifyListeners();
  }

  // Get notes for subject
  Future<List<Note>> getNotesForSubject(String subjectId) async {
    return await _dbService.getNotesForSubject(subjectId);
  }

  // Add note to subject
  Future<Note> addNote({
    required String subjectId,
    required String title,
    String? description,
    required NoteType noteType,
    required String filePath,
    Map<String, dynamic>? metadata,
  }) async {
    final note = Note(
      id: const Uuid().v4(),
      subjectId: subjectId,
      title: title,
      description: description,
      noteType: noteType.index,
      filePath: filePath,
      uploadedAt: DateTime.now(),
      updatedAt: DateTime.now(),
      metadata: metadata,
    );

    await _dbService.saveNote(note);

    // Update subject note count
    final subject = _subjects.firstWhere((s) => s.id == subjectId);
    subject.totalNotes++;
    await updateSubject(subject);

    return note;
  }

  // Get lessons for subject
  Future<List<Lesson>> getLessonsForSubject(String subjectId) async {
    return await _dbService.getLessonsForSubject(subjectId);
  }

  // Get quizzes for subject
  Future<List<Quiz>> getQuizzesForSubject(String subjectId) async {
    return await _dbService.getQuizzesForSubject(subjectId);
  }

  // Get flashcards for subject
  Future<List<FlashcardDeck>> getFlashcardsForSubject(String subjectId) async {
    return await _dbService.getFlashcardsForSubject(subjectId);
  }

  // Update subject progress
  Future<void> updateProgress(
      String subjectId, int completedTopics, int totalTopics) async {
    final subject = _subjects.firstWhere((s) => s.id == subjectId);
    subject.completedTopics = completedTopics;
    subject.totalTopics = totalTopics;
    subject.progressPercentage =
        totalTopics > 0 ? (completedTopics / totalTopics) * 100 : 0;

    await updateSubject(subject);
  }
}
