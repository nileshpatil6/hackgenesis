import 'package:hive/hive.dart';

part 'subject.g.dart';

@HiveType(typeId: 1)
class Subject extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  String color; // Hex color code

  @HiveField(4)
  String? iconName;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  @HiveField(7)
  int totalNotes;

  @HiveField(8)
  int completedTopics;

  @HiveField(9)
  int totalTopics;

  @HiveField(10)
  double progressPercentage;

  @HiveField(11)
  String?
      fileSearchStoreId; // AI vector store ID for this subject (unused; store id is cached in-memory per session instead)

  Subject({
    required this.id,
    required this.name,
    this.description,
    required this.color,
    this.iconName,
    required this.createdAt,
    required this.updatedAt,
    this.totalNotes = 0,
    this.completedTopics = 0,
    this.totalTopics = 0,
    this.progressPercentage = 0.0,
    this.fileSearchStoreId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'color': color,
        'icon_name': iconName,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'total_notes': totalNotes,
        'completed_topics': completedTopics,
        'total_topics': totalTopics,
        'progress_percentage': progressPercentage,
        'file_search_store_id': fileSearchStoreId,
      };

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        color: json['color'],
        iconName: json['icon_name'],
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
        totalNotes: json['total_notes'] ?? 0,
        completedTopics: json['completed_topics'] ?? 0,
        totalTopics: json['total_topics'] ?? 0,
        progressPercentage:
            (json['progress_percentage'] as num?)?.toDouble() ?? 0.0,
        fileSearchStoreId: json['file_search_store_id'],
      );
}
