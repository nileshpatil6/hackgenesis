import 'package:hive/hive.dart';

part 'quiz.g.dart';

enum QuestionType {
  mcq,
  trueFalse,
  fillInBlank,
  numerical,
}

@HiveType(typeId: 5)
class Quiz extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String subjectId;

  @HiveField(2)
  String lessonId;

  @HiveField(3)
  String title;

  @HiveField(4)
  List<Question> questions;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  bool isCompleted;

  @HiveField(7)
  int? score; // Percentage

  @HiveField(8)
  int totalAttempts;

  @HiveField(9)
  int? bestScore;

  Quiz({
    required this.id,
    required this.subjectId,
    required this.lessonId,
    required this.title,
    required this.questions,
    required this.createdAt,
    this.isCompleted = false,
    this.score,
    this.totalAttempts = 0,
    this.bestScore,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject_id': subjectId,
        'lesson_id': lessonId,
        'title': title,
        'questions': questions.map((q) => q.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'is_completed': isCompleted,
        'score': score,
        'total_attempts': totalAttempts,
        'best_score': bestScore,
      };
  factory Quiz.fromJson(Map<String, dynamic> json) => Quiz(
        id: json['id'],
        subjectId: json['subject_id'],
        lessonId: json['lesson_id'] ?? '',
        title: json['title'],
        questions: (json['questions'] as List)
            .map((q) => Question.fromJson(q))
            .toList(),
        createdAt: DateTime.parse(json['created_at']),
        isCompleted: json['is_completed'] ?? false,
        score: json['score'],
        totalAttempts: json['total_attempts'] ?? 0,
        bestScore: json['best_score'],
      );
}

@HiveType(typeId: 6)
class Question extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  int questionType; // 0: mcq, 1: trueFalse, 2: fillInBlank, 3: numerical

  @HiveField(2)
  String questionText;

  @HiveField(3)
  List<String>? options; // For MCQ

  @HiveField(4)
  String correctAnswer;

  @HiveField(5)
  String? explanation;

  @HiveField(6)
  String? userAnswer;

  @HiveField(7)
  bool? isCorrect;

  @HiveField(8)
  int difficultyLevel; // 1-5

  @HiveField(9)
  int points;

  Question({
    required this.id,
    required this.questionType,
    required this.questionText,
    this.options,
    required this.correctAnswer,
    this.explanation,
    this.userAnswer,
    this.isCorrect,
    this.difficultyLevel = 3,
    this.points = 10,
  });

  QuestionType get type => QuestionType.values[questionType];

  Map<String, dynamic> toJson() => {
        'id': id,
        'question_type': questionType,
        'question_text': questionText,
        'options': options,
        'correct_answer': correctAnswer,
        'explanation': explanation,
        'user_answer': userAnswer,
        'is_correct': isCorrect,
        'difficulty_level': difficultyLevel,
        'points': points,
      };

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: json['id'],
        questionType: json['question_type'],
        questionText: json['question_text'],
        options:
            json['options'] != null ? List<String>.from(json['options']) : null,
        correctAnswer: json['correct_answer'],
        explanation: json['explanation'],
        userAnswer: json['user_answer'],
        isCorrect: json['is_correct'],
        difficultyLevel: json['difficulty_level'] ?? 3,
        points: json['points'] ?? 10,
      );
}
