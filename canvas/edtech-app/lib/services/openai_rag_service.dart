import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io';
import 'supabase_service.dart';
import 'database_service.dart';
import '../models/note.dart';

/// RAG (retrieval-augmented generation) service backed by OpenAI's
/// Vector Store + File Search tool. One vector store is created per subject
/// (named `eduai-<subjectId>`), PDFs are uploaded and attached to it, and
/// chat/quiz/flashcard generation all use the Responses API with the
/// `file_search` tool pointed at that store.
class OpenAIRagService {
  final String _apiKey;
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _model = 'gpt-4o-mini';

  // subjectId -> OpenAI vector store id
  final Map<String, String> _subjectStores = {};

  final DatabaseService _dbService = DatabaseService();

  /// Human-readable reason the last operation failed, if any. The UI can
  /// surface this instead of leaving the user stuck on a spinner.
  String? lastError;

  OpenAIRagService(this._apiKey);

  Map<String, String> get _jsonHeaders => {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      };

  Map<String, String> get _vectorStoreHeaders => {
        ..._jsonHeaders,
        'OpenAI-Beta': 'assistants=v2',
      };

  void setStoreForSubject(String subjectId, String storeId) {
    _subjectStores[subjectId] = storeId;
  }

  /// Checks an API key against OpenAI directly. Returns null if it's valid,
  /// or a human-readable error message if not.
  static Future<String?> validateKey(String apiKey) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) return null;

      try {
        final data = json.decode(response.body);
        final message = data['error']?['message'];
        if (message != null) return message.toString();
      } catch (_) {
        // Body wasn't JSON; fall through to the generic message below.
      }
      return 'Invalid API key (HTTP ${response.statusCode})';
    } catch (e) {
      return 'Could not verify key: $e';
    }
  }

  /// Initialize (find-or-create) a vector store for a specific subject.
  Future<String?> initializeSubjectStore(
      String subjectId, String subjectName) async {
    lastError = null;
    try {
      if (_subjectStores.containsKey(subjectId)) {
        return _subjectStores[subjectId];
      }

      final displayName = 'eduai-$subjectId';

      // Look for an existing store for this subject
      final listUrl = Uri.parse('$_baseUrl/vector_stores?limit=100');
      final listResponse = await http.get(listUrl, headers: _vectorStoreHeaders);

      if (listResponse.statusCode == 200) {
        final listData = json.decode(listResponse.body);
        final stores = listData['data'] as List?;
        if (stores != null) {
          for (var store in stores) {
            if (store['name'] == displayName) {
              final storeId = store['id'] as String;
              _subjectStores[subjectId] = storeId;
              return storeId;
            }
          }
        }
      } else {
        lastError = _extractError(listResponse);
      }

      // Create a new store
      final createUrl = Uri.parse('$_baseUrl/vector_stores');
      final createResponse = await http.post(
        createUrl,
        headers: _vectorStoreHeaders,
        body: json.encode({'name': displayName}),
      );

      if (createResponse.statusCode == 200 || createResponse.statusCode == 201) {
        final data = json.decode(createResponse.body);
        final storeId = data['id'] as String;
        _subjectStores[subjectId] = storeId;
        lastError = null;
        return storeId;
      } else {
        lastError = _extractError(createResponse);
        return null;
      }
    } catch (e) {
      lastError = 'Network error: $e';
      return null;
    }
  }

  /// Upload PDF to the subject's vector store AND Supabase Storage (backup).
  Future<bool> uploadPdfToSubject(String subjectId, File pdfFile) async {
    lastError = null;
    final storeId = _subjectStores[subjectId];
    if (storeId == null) {
      lastError = 'No vector store found for this subject';
      return false;
    }

    try {
      final fileName = pdfFile.path.split('/').last.split('\\').last;

      // Step 1: Back up to Supabase Storage (best-effort, non-fatal)
      String? supabaseUrl;
      try {
        supabaseUrl = await SupabaseService.uploadNoteFile(
          filePath: pdfFile.path,
          fileName: fileName,
          subjectId: subjectId,
        );
      } catch (e) {
        print('⚠️ Supabase backup failed (continuing with OpenAI): $e');
      }

      // Step 2: Upload the file to OpenAI
      final uploadUri = Uri.parse('$_baseUrl/files');
      final request = http.MultipartRequest('POST', uploadUri)
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..fields['purpose'] = 'assistants'
        ..files.add(await http.MultipartFile.fromPath('file', pdfFile.path,
            filename: fileName));

      final streamedResponse = await request.send();
      final uploadResponse = await http.Response.fromStream(streamedResponse);

      if (uploadResponse.statusCode != 200 && uploadResponse.statusCode != 201) {
        lastError = _extractError(uploadResponse);
        return false;
      }

      final fileId = json.decode(uploadResponse.body)['id'] as String;

      // Step 3: Attach the file to the vector store
      final attachUrl = Uri.parse('$_baseUrl/vector_stores/$storeId/files');
      final attachResponse = await http.post(
        attachUrl,
        headers: _vectorStoreHeaders,
        body: json.encode({'file_id': fileId}),
      );

      if (attachResponse.statusCode != 200 && attachResponse.statusCode != 201) {
        lastError = _extractError(attachResponse);
        return false;
      }

      // Step 4: Wait for indexing to finish
      final indexed = await _waitForFileIndexing(storeId, fileId);
      if (!indexed) {
        lastError ??= 'File indexing did not complete in time';
        return false;
      }

      // Step 5: Save a Note record
      try {
        final note = Note(
          id: const Uuid().v4(),
          subjectId: subjectId,
          title: fileName.replaceAll('.pdf', ''),
          description: 'Uploaded PDF document',
          noteType: 0, // PDF type
          filePath: supabaseUrl ?? pdfFile.path,
          geminiFileId: fileId,
          uploadedAt: DateTime.now(),
          updatedAt: DateTime.now(),
          fileSize: await pdfFile.length(),
          isProcessed: true,
        );
        await _dbService.saveNote(note);
        print('✅ Note record saved to database');
      } catch (e) {
        print('⚠️ Failed to save note record: $e');
      }

      print('✅ PDF uploaded and indexed successfully!');
      return true;
    } catch (e) {
      lastError = 'Upload failed: $e';
      return false;
    }
  }

  Future<bool> _waitForFileIndexing(String storeId, String fileId) async {
    const maxPolls = 30;
    for (var i = 0; i < maxPolls; i++) {
      await Future.delayed(const Duration(seconds: 3));

      final statusUrl = Uri.parse('$_baseUrl/vector_stores/$storeId/files/$fileId');
      final response = await http.get(statusUrl, headers: _vectorStoreHeaders);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'];
        if (status == 'completed') return true;
        if (status == 'failed' || status == 'cancelled') {
          lastError = 'File indexing failed';
          return false;
        }
      }
    }
    return false;
  }

  /// Chat with AI about the subject's PDFs
  Future<String> chatWithSubject({
    required String subjectId,
    required String userMessage,
    List<Map<String, String>>? conversationHistory,
  }) async {
    if (!_subjectStores.containsKey(subjectId)) {
      await _getExistingStore(subjectId);
    }

    final storeId = _subjectStores[subjectId];
    if (storeId == null) {
      return 'Please upload some study materials first.';
    }

    final prompt = _buildChatPrompt(userMessage, conversationHistory);
    final result = await _callResponses(prompt, storeId);

    if (result == null) {
      return 'Sorry, I encountered an error${lastError != null ? ': $lastError' : ''}. Please try again.';
    }
    return result;
  }

  /// Get existing store for a subject (used when the caller didn't cache it)
  Future<void> _getExistingStore(String subjectId) async {
    try {
      final displayName = 'eduai-$subjectId';
      final listUrl = Uri.parse('$_baseUrl/vector_stores?limit=100');
      final listResponse = await http.get(listUrl, headers: _vectorStoreHeaders);

      if (listResponse.statusCode == 200) {
        final listData = json.decode(listResponse.body);
        final stores = listData['data'] as List?;
        if (stores != null) {
          for (var store in stores) {
            if (store['name'] == displayName) {
              _subjectStores[subjectId] = store['id'];
              return;
            }
          }
        }
      }
    } catch (e) {
      print('Error getting existing store: $e');
    }
  }

  /// Generate quiz from PDFs
  Future<Map<String, dynamic>> generateQuiz({
    required String subjectId,
    required int numberOfQuestions,
    required String difficulty,
  }) async {
    if (!_subjectStores.containsKey(subjectId)) {
      await _getExistingStore(subjectId);
    }

    final storeId = _subjectStores[subjectId];
    if (storeId == null) {
      return {'error': 'No study materials found'};
    }

    final prompt = '''
Based on the uploaded study materials, generate a quiz with $numberOfQuestions questions.
Difficulty level: $difficulty

Respond with ONLY valid JSON (no markdown fences) in this exact format:
{
  "questions": [
    {
      "question": "Question text",
      "options": ["A", "B", "C", "D"],
      "correctAnswer": 0,
      "explanation": "Why this is correct"
    }
  ]
}

Make questions challenging and based on key concepts from the materials.
''';

    return _makeRagJsonRequest(prompt, storeId);
  }

  /// Generate flashcards from PDFs
  Future<Map<String, dynamic>> generateFlashcards({
    required String subjectId,
    required int numberOfCards,
  }) async {
    if (!_subjectStores.containsKey(subjectId)) {
      await _getExistingStore(subjectId);
    }

    final storeId = _subjectStores[subjectId];
    if (storeId == null) {
      return {'error': 'No study materials found'};
    }

    final prompt = '''
Generate $numberOfCards flashcards from the study materials.

Respond with ONLY valid JSON (no markdown fences) in this exact format:
{
  "flashcards": [
    {
      "front": "Question or concept",
      "back": "Answer or explanation"
    }
  ]
}

Focus on key concepts and definitions.
''';

    return _makeRagJsonRequest(prompt, storeId);
  }

  /// Calls the Responses API with the file_search tool pointed at [storeId]
  /// and returns the assistant's text output, or null on failure (see
  /// [lastError]).
  Future<String?> _callResponses(String prompt, String storeId) async {
    try {
      final url = Uri.parse('$_baseUrl/responses');
      final body = {
        'model': _model,
        'input': prompt,
        'tools': [
          {
            'type': 'file_search',
            'vector_store_ids': [storeId],
          }
        ],
      };

      final response =
          await http.post(url, headers: _jsonHeaders, body: json.encode(body));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = _extractOutputText(data);
        if (text == null) {
          lastError = 'Empty response from AI';
        }
        return text;
      } else {
        lastError = _extractError(response);
        return null;
      }
    } catch (e) {
      lastError = 'Request failed: $e';
      return null;
    }
  }

  String? _extractOutputText(Map<String, dynamic> data) {
    final output = data['output'] as List?;
    if (output == null) return null;

    for (final item in output) {
      if (item['type'] == 'message') {
        final content = item['content'] as List?;
        if (content != null) {
          for (final part in content) {
            if (part['type'] == 'output_text' && part['text'] != null) {
              return part['text'] as String;
            }
          }
        }
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _makeRagJsonRequest(
      String prompt, String storeId) async {
    final text = await _callResponses(prompt, storeId);
    if (text == null) {
      return {'error': lastError ?? 'Request failed'};
    }

    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (jsonMatch == null) {
      return {'error': 'Invalid response format from AI'};
    }

    try {
      return json.decode(jsonMatch.group(0)!);
    } catch (e) {
      return {'error': 'Could not parse AI response: $e'};
    }
  }

  String _buildChatPrompt(
      String userMessage, List<Map<String, String>>? history) {
    final historyText =
        history?.map((msg) => '${msg['role']}: ${msg['content']}').join('\n') ??
            '';

    return '''
You are a helpful AI tutor. Answer the student's question based on the uploaded study materials.

Previous conversation:
$historyText

Student: $userMessage

Provide a clear, educational response with examples from the materials.
''';
  }

  String _extractError(http.Response response) {
    try {
      final data = json.decode(response.body);
      final message = data['error']?['message'];
      if (message != null) return message.toString();
    } catch (_) {
      // Body wasn't JSON; fall through to generic message below.
    }
    return 'Request failed (HTTP ${response.statusCode})';
  }
}
