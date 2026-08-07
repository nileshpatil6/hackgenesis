import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class DeepgramService {
  final String apiKey;
  static const String baseUrl = 'https://api.deepgram.com/v1';

  DeepgramService({required this.apiKey});

  /// Generate audio from text using Deepgram TTS
  /// Returns the local file path where audio is saved
  Future<String> textToSpeech({
    required String text,
    String model = 'aura-asteria-en', // Natural female voice
    String? fileName,
  }) async {
    final url = '$baseUrl/speak?model=$model';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Token $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'text': text}),
    );

    if (response.statusCode == 200) {
      // Save audio file locally
      final directory = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${directory.path}/audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final filePath =
          '${audioDir.path}/${fileName ?? DateTime.now().millisecondsSinceEpoch}.mp3';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      return filePath;
    } else {
      throw Exception('Failed to generate audio: ${response.body}');
    }
  }

  /// Generate audio for multiple slides
  Future<List<String>> generateSlideAudios(
      List<Map<String, String>> slides) async {
    final audioPaths = <String>[];

    for (var i = 0; i < slides.length; i++) {
      final slide = slides[i];
      final text = '''
${slide['title']}.
${slide['content']}
''';

      final audioPath = await textToSpeech(
        text: text,
        fileName: 'slide_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );

      audioPaths.add(audioPath);
    }

    return audioPaths;
  }

  /// Available voice models
  static const List<Map<String, String>> voiceModels = [
    {
      'id': 'aura-asteria-en',
      'name': 'Asteria (Female)',
      'language': 'English'
    },
    {'id': 'aura-luna-en', 'name': 'Luna (Female)', 'language': 'English'},
    {'id': 'aura-stella-en', 'name': 'Stella (Female)', 'language': 'English'},
    {'id': 'aura-athena-en', 'name': 'Athena (Female)', 'language': 'English'},
    {'id': 'aura-hera-en', 'name': 'Hera (Female)', 'language': 'English'},
    {'id': 'aura-orion-en', 'name': 'Orion (Male)', 'language': 'English'},
    {'id': 'aura-arcas-en', 'name': 'Arcas (Male)', 'language': 'English'},
    {'id': 'aura-perseus-en', 'name': 'Perseus (Male)', 'language': 'English'},
    {'id': 'aura-angus-en', 'name': 'Angus (Male)', 'language': 'English'},
    {'id': 'aura-orpheus-en', 'name': 'Orpheus (Male)', 'language': 'English'},
  ];

  /// Get voice model based on AI personality
  String getVoiceForPersonality(String personality) {
    switch (personality.toLowerCase()) {
      case 'robot':
      case 'sci-fi robot':
        return 'aura-arcas-en'; // Robotic male
      case 'professor':
      case 'friendly professor':
        return 'aura-athena-en'; // Professional female
      case 'detective':
      case 'detective mentor':
        return 'aura-orion-en'; // Serious male
      case 'anime':
      case 'anime sensei':
        return 'aura-luna-en'; // Young female
      case 'coach':
      case 'fitness coach':
        return 'aura-perseus-en'; // Energetic male
      default:
        return 'aura-asteria-en'; // Default pleasant female
    }
  }

  /// Transcribe audio to text (for voice input)
  /// Note: This uses Deepgram's STT API
  Future<String> speechToText(String audioFilePath) async {
    const url = '$baseUrl/listen';

    final audioFile = File(audioFilePath);
    final audioBytes = await audioFile.readAsBytes();

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Token $apiKey',
        'Content-Type': 'audio/wav',
      },
      body: audioBytes,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final transcript =
          data['results']['channels'][0]['alternatives'][0]['transcript'];
      return transcript;
    } else {
      throw Exception('Failed to transcribe audio: ${response.body}');
    }
  }

  /// Real-time streaming transcription (for voice conversations)
  /// This would use WebSocket connection in a real implementation
  Stream<String> streamingSpeechToText() async* {
    // Placeholder for WebSocket implementation
    // In production, this would:
    // 1. Open WebSocket to wss://api.deepgram.com/v1/listen
    // 2. Stream audio chunks
    // 3. Yield transcription results as they arrive
    yield 'Streaming not implemented in this demo';
  }
}
