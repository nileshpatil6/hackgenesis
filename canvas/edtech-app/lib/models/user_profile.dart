import 'package:hive/hive.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 0)
class UserProfile extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String email;

  @HiveField(3)
  int age;

  @HiveField(4)
  String educationLevel; // Class 1-12, UG, PG, Professional

  @HiveField(5)
  String stream; // Engineering, Medical, Commerce, Arts, Law, etc.

  @HiveField(6)
  List<String> learningPreferences; // Visual, Audio, Examples, Analogies

  @HiveField(7)
  String learningPace; // fast, normal, slow

  @HiveField(8)
  List<String> interests; // Sports, gaming, technology, arts, etc.

  @HiveField(9)
  String aiPersonality; // Robot, Professor, Detective, Anime, Coach

  @HiveField(10)
  int xpPoints;

  @HiveField(11)
  List<String> badges;

  @HiveField(12)
  int dailyStreak;

  @HiveField(13)
  DateTime lastActiveDate;

  @HiveField(14)
  String? photoUrl;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.age = 0,
    this.educationLevel = '',
    this.stream = '',
    this.learningPreferences = const [],
    this.learningPace = 'normal',
    this.interests = const [],
    this.aiPersonality = 'Professor',
    this.xpPoints = 0,
    this.badges = const [],
    this.dailyStreak = 0,
    required this.lastActiveDate,
    this.photoUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'age': age,
        'education_level': educationLevel,
        'stream': stream,
        'learning_preferences': learningPreferences,
        'learning_pace': learningPace,
        'interests': interests,
        'ai_personality': aiPersonality,
        'xp_points': xpPoints,
        'badges': badges,
        'daily_streak': dailyStreak,
        'last_active_date': lastActiveDate.toIso8601String(),
        'photo_url': photoUrl,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        age: json['age'] ?? 0,
        educationLevel: json['education_level'] ?? '',
        stream: json['stream'] ?? '',
        learningPreferences:
            List<String>.from(json['learning_preferences'] ?? []),
        learningPace: json['learning_pace'] ?? 'normal',
        interests: List<String>.from(json['interests'] ?? []),
        aiPersonality: json['ai_personality'] ?? 'Professor',
        xpPoints: json['xp_points'] ?? 0,
        badges: List<String>.from(json['badges'] ?? []),
        dailyStreak: json['daily_streak'] ?? 0,
        lastActiveDate: DateTime.parse(json['last_active_date']),
        photoUrl: json['photo_url'],
      );
}
