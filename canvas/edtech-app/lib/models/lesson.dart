import 'package:hive/hive.dart';

part 'lesson.g.dart';

@HiveType(typeId: 3)
class Lesson extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String subjectId;

  @HiveField(2)
  String title;

  @HiveField(3)
  String? description;

  @HiveField(4)
  List<Slide> slides;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  bool isCompleted;

  @HiveField(7)
  int currentSlideIndex;

  @HiveField(8)
  String? audioUrl; // URL to generated audio

  Lesson({
    required this.id,
    required this.subjectId,
    required this.title,
    this.description,
    required this.slides,
    required this.createdAt,
    this.isCompleted = false,
    this.currentSlideIndex = 0,
    this.audioUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject_id': subjectId,
        'title': title,
        'description': description,
        'slides': slides.map((e) => e.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'is_completed': isCompleted,
        'current_slide_index': currentSlideIndex,
        'audio_url': audioUrl,
      };
  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
        id: json['id'],
        subjectId: json['subject_id'],
        title: json['title'],
        description: json['description'],
        slides: (json['slides'] as List).map((e) => Slide.fromJson(e)).toList(),
        createdAt: DateTime.parse(json['created_at']),
        isCompleted: json['is_completed'] ?? false,
        currentSlideIndex: json['current_slide_index'] ?? 0,
        audioUrl: json['audio_url'],
      );
}

@HiveType(typeId: 4)
class Slide extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String content;

  @HiveField(3)
  List<String>? imageUrls;

  @HiveField(4)
  List<String>? bulletPoints;

  @HiveField(5)
  String? audioUrl; // Individual slide audio

  @HiveField(6)
  String? diagramData; // JSON for diagrams

  @HiveField(7)
  int order;

  Slide({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrls,
    this.bulletPoints,
    this.audioUrl,
    this.diagramData,
    required this.order,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'image_urls': imageUrls,
        'bullet_points': bulletPoints,
        'audio_url': audioUrl,
        'diagram_data': diagramData,
        'order': order,
      };

  factory Slide.fromJson(Map<String, dynamic> json) => Slide(
        id: json['id'],
        title: json['title'],
        content: json['content'],
        imageUrls: json['image_urls'] != null
            ? List<String>.from(json['image_urls'])
            : null,
        bulletPoints: json['bullet_points'] != null
            ? List<String>.from(json['bullet_points'])
            : null,
        audioUrl: json['audio_url'],
        diagramData: json['diagram_data'],
        order: json['order'],
      );
}
