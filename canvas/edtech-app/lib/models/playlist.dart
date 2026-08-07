import 'package:hive/hive.dart';

part 'playlist.g.dart';

@HiveType(typeId: 13)
class StudyPlaylist extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String subjectId;

  @HiveField(2)
  String title;

  @HiveField(3)
  String? description;

  @HiveField(4)
  List<PlaylistVideo> videos;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  @HiveField(7)
  String? playlistUrl; // YouTube playlist URL

  @HiveField(8)
  String? thumbnailUrl;

  @HiveField(9)
  int totalDuration; // in minutes

  @HiveField(10)
  int watchedVideos;

  StudyPlaylist({
    required this.id,
    required this.subjectId,
    required this.title,
    this.description,
    required this.videos,
    required this.createdAt,
    required this.updatedAt,
    this.playlistUrl,
    this.thumbnailUrl,
    this.totalDuration = 0,
    this.watchedVideos = 0,
  });

  double get progressPercentage {
    if (videos.isEmpty) return 0.0;
    return (watchedVideos / videos.length) * 100;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject_id': subjectId,
        'title': title,
        'description': description,
        'videos': videos.map((v) => v.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'playlist_url': playlistUrl,
        'thumbnail_url': thumbnailUrl,
        'total_duration': totalDuration,
        'watched_videos': watchedVideos,
      };

  factory StudyPlaylist.fromJson(Map<String, dynamic> json) => StudyPlaylist(
        id: json['id'],
        subjectId: json['subject_id'],
        title: json['title'],
        description: json['description'],
        videos: (json['videos'] as List)
            .map((v) => PlaylistVideo.fromJson(v))
            .toList(),
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
        playlistUrl: json['playlist_url'],
        thumbnailUrl: json['thumbnail_url'],
        totalDuration: json['total_duration'] ?? 0,
        watchedVideos: json['watched_videos'] ?? 0,
      );
}

@HiveType(typeId: 14)
class PlaylistVideo extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String videoId; // YouTube video ID

  @HiveField(3)
  String? thumbnailUrl;

  @HiveField(4)
  int duration; // in seconds

  @HiveField(5)
  bool isWatched;

  @HiveField(6)
  int watchProgress; // percentage watched

  @HiveField(7)
  String? channelName;

  @HiveField(8)
  DateTime? publishedAt;

  @HiveField(9)
  List<String>? tags;

  @HiveField(10)
  String? aiSummary; // AI-generated summary of the video

  PlaylistVideo({
    required this.id,
    required this.title,
    required this.videoId,
    this.thumbnailUrl,
    this.duration = 0,
    this.isWatched = false,
    this.watchProgress = 0,
    this.channelName,
    this.publishedAt,
    this.tags,
    this.aiSummary,
  });

  String get videoUrl => 'https://www.youtube.com/watch?v=$videoId';

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'video_id': videoId,
        'thumbnail_url': thumbnailUrl,
        'duration': duration,
        'is_watched': isWatched,
        'watch_progress': watchProgress,
        'channel_name': channelName,
        'published_at': publishedAt?.toIso8601String(),
        'tags': tags,
        'ai_summary': aiSummary,
      };

  factory PlaylistVideo.fromJson(Map<String, dynamic> json) => PlaylistVideo(
        id: json['id'],
        title: json['title'],
        videoId: json['video_id'],
        thumbnailUrl: json['thumbnail_url'],
        duration: json['duration'] ?? 0,
        isWatched: json['is_watched'] ?? false,
        watchProgress: json['watch_progress'] ?? 0,
        channelName: json['channel_name'],
        publishedAt: json['published_at'] != null
            ? DateTime.parse(json['published_at'])
            : null,
        tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
        aiSummary: json['ai_summary'],
      );
}
