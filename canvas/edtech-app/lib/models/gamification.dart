import 'package:hive/hive.dart';

part 'gamification.g.dart';

@HiveType(typeId: 9)
class Achievement extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  String iconName;

  @HiveField(4)
  int xpReward;

  @HiveField(5)
  bool isUnlocked;

  @HiveField(6)
  DateTime? unlockedAt;

  @HiveField(7)
  String category; // quiz, flashcard, streak, learning

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.xpReward,
    this.isUnlocked = false,
    this.unlockedAt,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'icon_name': iconName,
        'xp_reward': xpReward,
        'is_unlocked': isUnlocked,
        'unlocked_at': unlockedAt?.toIso8601String(),
        'category': category,
      };
  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        iconName: json['icon_name'],
        xpReward: json['xp_reward'],
        isUnlocked: json['is_unlocked'] ?? false,
        unlockedAt: json['unlocked_at'] != null
            ? DateTime.parse(json['unlocked_at'])
            : null,
        category: json['category'],
      );
}

@HiveType(typeId: 10)
class DailyStreak extends HiveObject {
  @HiveField(0)
  int currentStreak;

  @HiveField(1)
  int longestStreak;

  @HiveField(2)
  DateTime lastActiveDate;

  @HiveField(3)
  List<DateTime> activityDates;

  DailyStreak({
    this.currentStreak = 0,
    this.longestStreak = 0,
    required this.lastActiveDate,
    this.activityDates = const [],
  });
}

@HiveType(typeId: 11)
class StudyPlan extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String subjectId;

  @HiveField(2)
  String title;

  @HiveField(3)
  DateTime startDate;

  @HiveField(4)
  DateTime endDate;

  @HiveField(5)
  List<StudyTask> tasks;

  @HiveField(6)
  bool isActive;

  @HiveField(7)
  int completedTasks;

  StudyPlan({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.tasks,
    this.isActive = true,
    this.completedTasks = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject_id': subjectId,
        'title': title,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'is_active': isActive,
        'completed_tasks': completedTasks,
      };

  factory StudyPlan.fromJson(Map<String, dynamic> json) => StudyPlan(
        id: json['id'],
        subjectId: json['subject_id'],
        title: json['title'],
        startDate: DateTime.parse(json['start_date']),
        endDate: DateTime.parse(json['end_date']),
        tasks:
            (json['tasks'] as List).map((t) => StudyTask.fromJson(t)).toList(),
        isActive: json['is_active'] ?? true,
        completedTasks: json['completed_tasks'] ?? 0,
      );
}

@HiveType(typeId: 12)
class StudyTask extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  DateTime dueDate;

  @HiveField(4)
  bool isCompleted;

  @HiveField(5)
  int estimatedMinutes;

  @HiveField(6)
  String priority; // high, medium, low

  @HiveField(7)
  String? linkedLessonId;

  StudyTask({
    required this.id,
    required this.title,
    this.description,
    required this.dueDate,
    this.isCompleted = false,
    this.estimatedMinutes = 30,
    this.priority = 'medium',
    this.linkedLessonId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'due_date': dueDate.toIso8601String(),
        'is_completed': isCompleted,
        'estimated_minutes': estimatedMinutes,
        'priority': priority,
        'linked_lesson_id': linkedLessonId,
      };

  factory StudyTask.fromJson(Map<String, dynamic> json) => StudyTask(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        dueDate: DateTime.parse(json['due_date']),
        isCompleted: json['is_completed'] ?? false,
        estimatedMinutes: json['estimated_minutes'] ?? 30,
        priority: json['priority'] ?? 'medium',
        linkedLessonId: json['linked_lesson_id'],
      );
}
