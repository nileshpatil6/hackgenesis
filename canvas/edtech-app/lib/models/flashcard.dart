import 'package:hive/hive.dart';

part 'flashcard.g.dart';

@HiveType(typeId: 7)
class FlashcardDeck extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String subjectId;

  @HiveField(2)
  String title;

  @HiveField(3)
  List<Flashcard> cards;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime lastReviewedAt;

  @HiveField(6)
  int totalReviews;

  @HiveField(7)
  double masteryPercentage;

  FlashcardDeck({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.cards,
    required this.createdAt,
    required this.lastReviewedAt,
    this.totalReviews = 0,
    this.masteryPercentage = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject_id': subjectId,
        'title': title,
        'cards': cards.map((c) => c.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'last_reviewed_at': lastReviewedAt.toIso8601String(),
        'total_reviews': totalReviews,
        'mastery_percentage': masteryPercentage,
      };
  factory FlashcardDeck.fromJson(Map<String, dynamic> json) => FlashcardDeck(
        id: json['id'],
        subjectId: json['subject_id'],
        title: json['title'],
        cards:
            (json['cards'] as List).map((c) => Flashcard.fromJson(c)).toList(),
        createdAt: DateTime.parse(json['created_at']),
        lastReviewedAt: DateTime.parse(json['last_reviewed_at']),
        totalReviews: json['total_reviews'] ?? 0,
        masteryPercentage:
            (json['mastery_percentage'] as num?)?.toDouble() ?? 0.0,
      );
}

@HiveType(typeId: 8)
class Flashcard extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String front;

  @HiveField(2)
  String back;

  @HiveField(3)
  String? imageUrl;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime nextReviewDate;

  @HiveField(6)
  int reviewCount;

  @HiveField(7)
  int easinessFactor; // For spaced repetition (SM-2 algorithm)

  @HiveField(8)
  int interval; // Days until next review

  @HiveField(9)
  bool isMastered;

  Flashcard({
    required this.id,
    required this.front,
    required this.back,
    this.imageUrl,
    required this.createdAt,
    required this.nextReviewDate,
    this.reviewCount = 0,
    this.easinessFactor = 250, // Default 2.5 * 100
    this.interval = 1,
    this.isMastered = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'front': front,
        'back': back,
        'image_url': imageUrl,
        'created_at': createdAt.toIso8601String(),
        'next_review_date': nextReviewDate.toIso8601String(),
        'review_count': reviewCount,
        'easiness_factor': easinessFactor,
        'interval': interval,
        'is_mastered': isMastered,
      };

  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
        id: json['id'],
        front: json['front'],
        back: json['back'],
        imageUrl: json['image_url'],
        createdAt: DateTime.parse(json['created_at']),
        nextReviewDate: DateTime.parse(json['next_review_date']),
        reviewCount: json['review_count'] ?? 0,
        easinessFactor: json['easiness_factor'] ?? 250,
        interval: json['interval'] ?? 1,
        isMastered: json['is_mastered'] ?? false,
      );
}
