import 'package:hive/hive.dart';

part 'calendar.g.dart';

@HiveType(typeId: 15)
class CalendarEvent extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  DateTime date;

  @HiveField(4)
  DateTime? startTime;

  @HiveField(5)
  DateTime? endTime;

  @HiveField(6)
  String eventType; // study, exam, assignment, class, reminder, other

  @HiveField(7)
  String? subjectId; // Link to subject if applicable

  @HiveField(8)
  String color; // Hex color code

  @HiveField(9)
  bool isCompleted;

  @HiveField(10)
  int priority; // 1=Low, 2=Medium, 3=High

  @HiveField(11)
  bool hasReminder;

  @HiveField(12)
  List<int>?
      reminderMinutesBefore; // e.g., [15, 60] for 15 mins and 1 hour before

  @HiveField(13)
  String? location;

  @HiveField(14)
  List<String>? attachments; // File paths

  @HiveField(15)
  String? notes;

  @HiveField(16)
  bool isRecurring;

  @HiveField(17)
  String? recurringPattern; // daily, weekly, monthly

  @HiveField(18)
  DateTime? recurringEndDate;

  @HiveField(19)
  DateTime createdAt;

  @HiveField(20)
  DateTime updatedAt;

  CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.date,
    this.startTime,
    this.endTime,
    this.eventType = 'other',
    this.subjectId,
    this.color = '#6C63FF',
    this.isCompleted = false,
    this.priority = 2,
    this.hasReminder = false,
    this.reminderMinutesBefore,
    this.location,
    this.attachments,
    this.notes,
    this.isRecurring = false,
    this.recurringPattern,
    this.recurringEndDate,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAllDay => startTime == null && endTime == null;

  bool get isPast => date.isBefore(DateTime.now());

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }

  String get priorityText {
    switch (priority) {
      case 1:
        return 'Low';
      case 2:
        return 'Medium';
      case 3:
        return 'High';
      default:
        return 'Medium';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date.toIso8601String(),
        'start_time': startTime?.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'event_type': eventType,
        'subject_id': subjectId,
        'color': color,
        'is_completed': isCompleted,
        'priority': priority,
        'has_reminder': hasReminder,
        'reminder_minutes_before': reminderMinutesBefore,
        'location': location,
        'attachments': attachments,
        'notes': notes,
        'is_recurring': isRecurring,
        'recurring_pattern': recurringPattern,
        'recurring_end_date': recurringEndDate?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        date: DateTime.parse(json['date']),
        startTime: json['start_time'] != null
            ? DateTime.parse(json['start_time'])
            : null,
        endTime:
            json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
        eventType: json['event_type'] ?? 'other',
        subjectId: json['subject_id'],
        color: json['color'] ?? '#6C63FF',
        isCompleted: json['is_completed'] ?? false,
        priority: json['priority'] ?? 2,
        hasReminder: json['has_reminder'] ?? false,
        reminderMinutesBefore: json['reminder_minutes_before'] != null
            ? List<int>.from(json['reminder_minutes_before'])
            : null,
        location: json['location'],
        attachments: json['attachments'] != null
            ? List<String>.from(json['attachments'])
            : null,
        notes: json['notes'],
        isRecurring: json['is_recurring'] ?? false,
        recurringPattern: json['recurring_pattern'],
        recurringEndDate: json['recurring_end_date'] != null
            ? DateTime.parse(json['recurring_end_date'])
            : null,
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );
}

// Event types constants
class EventType {
  static const String study = 'study';
  static const String exam = 'exam';
  static const String assignment = 'assignment';
  static const String classSession = 'class';
  static const String reminder = 'reminder';
  static const String other = 'other';

  static List<String> get all =>
      [study, exam, assignment, classSession, reminder, other];

  static String getDisplayName(String type) {
    switch (type) {
      case study:
        return 'Study Session';
      case exam:
        return 'Exam';
      case assignment:
        return 'Assignment';
      case classSession:
        return 'Class';
      case reminder:
        return 'Reminder';
      case other:
        return 'Other';
      default:
        return 'Event';
    }
  }

  static String getEmoji(String type) {
    switch (type) {
      case study:
        return '📚';
      case exam:
        return '📝';
      case assignment:
        return '✍️';
      case classSession:
        return '🏫';
      case reminder:
        return '⏰';
      case other:
        return '📌';
      default:
        return '📅';
    }
  }
}
