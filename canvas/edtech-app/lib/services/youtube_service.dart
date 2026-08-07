import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/playlist.dart';

class YouTubeService {
  // Note: For production, use YouTube Data API v3 with API key
  // For this demo, we'll parse YouTube URLs and create mock data
  // To use real API: Get key from https://console.cloud.google.com/

  /// Extract playlist ID from YouTube URL
  String? extractPlaylistId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // https://www.youtube.com/playlist?list=PLxxxxxxx
    if (uri.queryParameters.containsKey('list')) {
      return uri.queryParameters['list'];
    }

    // https://youtube.com/watch?v=xxx&list=PLxxxxxxx
    if (uri.path.contains('watch') && uri.queryParameters.containsKey('list')) {
      return uri.queryParameters['list'];
    }

    return null;
  }

  /// Extract video ID from YouTube URL
  String? extractVideoId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // https://www.youtube.com/watch?v=xxxxxxx
    if (uri.queryParameters.containsKey('v')) {
      return uri.queryParameters['v'];
    }

    // https://youtu.be/xxxxxxx
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;
    }

    return null;
  }

  /// Fetch playlist details using YouTube Data API v3
  /// Note: Requires API key from Google Cloud Console
  Future<StudyPlaylist?> fetchPlaylistFromUrl({
    required String playlistUrl,
    required String subjectId,
    String? apiKey,
  }) async {
    final playlistId = extractPlaylistId(playlistUrl);
    if (playlistId == null) {
      throw Exception('Invalid YouTube playlist URL');
    }

    if (apiKey != null && apiKey.isNotEmpty) {
      // Use real YouTube API
      return await _fetchPlaylistFromAPI(playlistId, subjectId, apiKey);
    } else {
      // Create mock playlist for demo (when no API key)
      return _createMockPlaylist(playlistId, playlistUrl, subjectId);
    }
  }

  /// Fetch playlist using YouTube Data API v3
  Future<StudyPlaylist> _fetchPlaylistFromAPI(
    String playlistId,
    String subjectId,
    String apiKey,
  ) async {
    final playlistUrl =
        'https://www.googleapis.com/youtube/v3/playlists?part=snippet,contentDetails&id=$playlistId&key=$apiKey';

    final playlistResponse = await http.get(Uri.parse(playlistUrl));

    if (playlistResponse.statusCode != 200) {
      throw Exception('Failed to fetch playlist: ${playlistResponse.body}');
    }

    final playlistData = jsonDecode(playlistResponse.body);
    final items = playlistData['items'] as List;

    if (items.isEmpty) {
      throw Exception('Playlist not found');
    }

    final playlist = items[0];
    final snippet = playlist['snippet'];

    // Fetch playlist items (videos)
    final videosUrl =
        'https://www.googleapis.com/youtube/v3/playlistItems?part=snippet,contentDetails&playlistId=$playlistId&maxResults=50&key=$apiKey';

    final videosResponse = await http.get(Uri.parse(videosUrl));

    if (videosResponse.statusCode != 200) {
      throw Exception('Failed to fetch videos: ${videosResponse.body}');
    }

    final videosData = jsonDecode(videosResponse.body);
    final videoItems = videosData['items'] as List;

    final videos = <PlaylistVideo>[];
    int totalDuration = 0;

    for (var item in videoItems) {
      final videoSnippet = item['snippet'];
      final videoId = item['contentDetails']['videoId'];

      // Fetch video details to get duration
      final videoDetailsUrl =
          'https://www.googleapis.com/youtube/v3/videos?part=contentDetails,snippet&id=$videoId&key=$apiKey';

      final videoDetailsResponse = await http.get(Uri.parse(videoDetailsUrl));

      if (videoDetailsResponse.statusCode == 200) {
        final videoDetailsData = jsonDecode(videoDetailsResponse.body);
        final videoDetailItems = videoDetailsData['items'] as List;

        if (videoDetailItems.isNotEmpty) {
          final videoDetail = videoDetailItems[0];
          final duration = _parseDuration(videoDetail['contentDetails']['duration']);
          final channelName = videoDetail['snippet']['channelTitle'];

          totalDuration += duration;

          videos.add(PlaylistVideo(
            id: const Uuid().v4(),
            title: videoSnippet['title'],
            videoId: videoId,
            thumbnailUrl: videoSnippet['thumbnails']?['high']?['url'] ??
                videoSnippet['thumbnails']?['default']?['url'],
            duration: duration,
            channelName: channelName,
            publishedAt: DateTime.parse(videoSnippet['publishedAt']),
          ));
        }
      }
    }

    return StudyPlaylist(
      id: const Uuid().v4(),
      subjectId: subjectId,
      title: snippet['title'],
      description: snippet['description'],
      videos: videos,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      playlistUrl: 'https://www.youtube.com/playlist?list=$playlistId',
      thumbnailUrl: snippet['thumbnails']?['high']?['url'],
      totalDuration: (totalDuration / 60).round(),
    );
  }

  /// Create mock playlist for demo (when no API key)
  StudyPlaylist _createMockPlaylist(
    String playlistId,
    String playlistUrl,
    String subjectId,
  ) {
    return StudyPlaylist(
      id: const Uuid().v4(),
      subjectId: subjectId,
      title: 'Study Playlist (Demo)',
      description: 'Add your YouTube API key to fetch real playlist data',
      videos: [
        PlaylistVideo(
          id: const Uuid().v4(),
          title: 'Introduction to the Topic',
          videoId: 'demo1',
          thumbnailUrl: 'https://via.placeholder.com/320x180',
          duration: 600, // 10 minutes
          channelName: 'Demo Channel',
        ),
        PlaylistVideo(
          id: const Uuid().v4(),
          title: 'Advanced Concepts',
          videoId: 'demo2',
          thumbnailUrl: 'https://via.placeholder.com/320x180',
          duration: 900, // 15 minutes
          channelName: 'Demo Channel',
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      playlistUrl: playlistUrl,
      totalDuration: 25,
    );
  }

  /// Parse ISO 8601 duration (PT1H2M10S) to seconds
  int _parseDuration(String isoDuration) {
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(isoDuration);

    if (match == null) return 0;

    final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;

    return (hours * 3600) + (minutes * 60) + seconds;
  }

  /// Generate AI summary of video using Gemini
  /// This can be called after fetching the playlist
  Future<String> generateVideoSummary({
    required String videoTitle,
    required String videoId,
    required String geminiApiKey,
  }) async {
    // Use Gemini to generate summary based on video title and transcript
    final prompt = '''
Based on this YouTube video title: "$videoTitle"
Generate a concise 2-3 sentence summary of what the video likely covers.
Focus on the educational content and key learning points.
''';

    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$geminiApiKey';

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'];
    } else {
      return 'Summary not available';
    }
  }

  /// Format duration in seconds to readable string
  String formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }
}
