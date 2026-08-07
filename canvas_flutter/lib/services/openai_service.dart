import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/experiment.dart';
import 'settings_store.dart';

/// Base URL of the OpenAI REST API.
const String _openAiBaseUrl = 'https://api.openai.com/v1';

// Model tiers picked per task, not one-size-fits-all:
// - Luna: cheap + fast, used for short conversational hints
// - Terra: balanced, used for code generation
// - Sol: frontier reasoning, used for structured experiment analysis
const String _modelFast = 'gpt-5.6-luna';
const String _modelBalanced = 'gpt-5.6-terra';
const String _modelReasoning = 'gpt-5.6-sol';

/// Model that renders the result illustration.
const String _modelImage = 'gpt-image-2';

/// Wall-clock budget for a single Responses API call.
const Duration _requestTimeout = Duration(seconds: 90);

/// Image rendering is slower than text, so it gets its own, longer budget.
const Duration _imageTimeout = Duration(seconds: 180);

/// Maximum number of characters of an HTTP error body kept in a message.
const int _maxErrorBodyChars = 300;

/// Strict JSON schema mirroring [AnalysisResult].
const Map<String, Object?> _analysisResultSchema = <String, Object?>{
  'type': 'object',
  'properties': <String, Object?>{
    'success': <String, Object?>{'type': 'boolean'},
    'title': <String, Object?>{'type': 'string'},
    'message': <String, Object?>{'type': 'string'},
    'mistake': <String, Object?>{
      'type': <String>['string', 'null'],
    },
    'explanation': <String, Object?>{'type': 'string'},
    'imagePrompt': <String, Object?>{
      'type': <String>['string', 'null'],
    },
  },
  'required': <String>[
    'success',
    'title',
    'message',
    'mistake',
    'explanation',
    'imagePrompt',
  ],
  'additionalProperties': false,
};

const JsonEncoder _prettyJson = JsonEncoder.withIndent('  ');

/// Reasoning effort accepted by the Responses API.
enum _ReasoningEffort {
  low,
  medium,
  high;

  String get wireValue => name;
}

/// An error raised while talking to the OpenAI API.
///
/// Never carries the API key — only the HTTP status and a truncated copy of
/// the server's error body.
class OpenAiException implements Exception {
  /// Creates an exception with a human-readable [message].
  OpenAiException(this.message, {this.statusCode});

  /// Message safe to surface directly in the UI.
  final String message;

  /// HTTP status code when the failure came from a response, else `null`.
  final int? statusCode;

  /// Whether the key was rejected (401) or lacks access (403).
  bool get isAuthError => statusCode == 401 || statusCode == 403;

  /// Whether the request was rate limited (429).
  bool get isRateLimit => statusCode == 429;

  @override
  String toString() =>
      statusCode == null ? message : 'OpenAI error $statusCode: $message';
}

/// Talks to the OpenAI Responses API on behalf of the lab canvas.
///
/// The API key is read from [SettingsStore] at the moment of each call and is
/// never cached, logged, or included in any thrown message.
class OpenAiService {
  /// Creates a service backed by [_settings] for key lookup.
  OpenAiService(this._settings);

  final SettingsStore _settings;
  final http.Client _client = http.Client();

  /// Asks the lab-assistant robot for a nudge instead of an answer.
  ///
  /// Throws [OpenAiException] when no key is set or the request fails.
  Future<String> getHint(ExperimentJson experiment, String userQuestion) async {
    // Fail fast with the exact "no key" message, unwrapped by the catch below.
    _requireApiKey();

    final nodeCount = experiment.nodes.length;
    final edgeCount = experiment.edges.length;
    final categories = experiment.nodes
        .map((n) => n.component.category)
        .toSet()
        .toList();
    final componentLabels = experiment.nodes
        .map((n) => n.displayLabel)
        .join(', ');

    // Leading newline kept so the prompt matches the React template literal.
    final prompt =
        '\n'
        '''
You are a friendly lab assistant robot 🤖 helping a student with their experiment.

CURRENT EXPERIMENT CONTEXT:
- Total Components: $nodeCount
- Total Connections: $edgeCount
- Categories Used: ${categories.join(', ')}
- Components on Canvas: $componentLabels

DETAILED EXPERIMENT STRUCTURE:
${_prettyJson.convert(experiment.toJson())}

STUDENT'S QUESTION: "$userQuestion"

INSTRUCTIONS:
Analyze the current experiment setup and the student's question. Provide a helpful hint to guide them in the right direction.

DO NOT:
- Give the direct solution or complete answer
- Tell them exactly what to add or how to fix it
- Provide step-by-step instructions

DO:
- Ask guiding questions about their current components
- Point out relationships they might have missed
- Suggest what to think about regarding specific components they already have
- Encourage exploration of connections between existing components
- Reference specific components they've added by name
- Help them think critically about what's missing or incorrect

Keep your response conversational, encouraging, friendly, and under 120 words. Use emojis occasionally! 🔬✨
''';

    try {
      return await _callOpenAi(
        model: _modelFast,
        effort: _ReasoningEffort.low,
        input: prompt,
      );
    } on OpenAiException catch (e) {
      throw OpenAiException(
        'Failed to get hint: ${e.message}',
        statusCode: e.statusCode,
      );
    }
  }

  /// Runs the frontier-reasoning analysis and returns a structured verdict.
  ///
  /// Never throws: any failure comes back as [AnalysisResult.error] so the UI
  /// can render it like a normal (failed) result.
  Future<AnalysisResult> analyzeExperiment(ExperimentJson experiment) async {
    // Leading newline kept so the prompt matches the React template literal.
    final prompt =
        '\n'
        '''
You are an expert science and engineering simulation AI. Analyze the following experiment setup and predict the outcome.

The experiment is represented as a node-based graph where:
- Each node represents a component (electronic, chemical, physical, or code block)
- Edges represent connections and flow between components
- Conditions on edges determine when connections are active

Experiment JSON:
${_prettyJson.convert(experiment.toJson())}

Analyze this experiment and determine:
- Whether it is valid and produces a result (success), or fails / is incomplete
- A short title: "Experiment Success!" or "Experiment Failed"
- A concise 1-2 sentence summary message
- If failed, a clear description of the mistake WITHOUT giving away the solution (null if success)
- A detailed explanation of what happened and why
- If success, an "imagePrompt": a vivid one-paragraph description of a single
  illustration that shows the outcome of THIS experiment (the apparatus, the
  reaction, the measured result). Describe subject, composition, labels and
  style — a clean modern scientific diagram on a white background. Do not
  mention SVG, code, or file formats. Null if failed.
''';

    try {
      final text = await _callOpenAi(
        model: _modelReasoning,
        effort: _ReasoningEffort.high,
        input: prompt,
        schemaName: 'experiment_analysis',
        schema: _analysisResultSchema,
      );

      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw OpenAiException('The AI returned an unexpected response shape.');
      }
      return AnalysisResult.fromJson(Map<String, dynamic>.from(decoded));
    } on OpenAiException catch (e) {
      return AnalysisResult.error(
        'Failed to analyze the experiment.',
        'Error details: ${e.message}',
      );
    } on FormatException catch (e) {
      return AnalysisResult.error(
        'Failed to analyze the experiment.',
        'Error details: could not parse the AI response (${e.message}).',
      );
    } catch (e) {
      return AnalysisResult.error(
        'Failed to analyze the experiment.',
        'Error details: $e',
      );
    }
  }

  /// Renders [prompt] into a PNG using the image model.
  ///
  /// Returns the raw image bytes, ready for `Image.memory`. Throws
  /// [OpenAiException] when no key is set or the request fails.
  Future<Uint8List> generateImage(String prompt) async {
    final String key = _requireApiKey();

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_openAiBaseUrl/images/generations'),
            headers: <String, String>{
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, Object?>{
              'model': _modelImage,
              'prompt': prompt,
              'size': '1024x1024',
              'n': 1,
            }),
          )
          .timeout(_imageTimeout);
    } on TimeoutException {
      throw OpenAiException(
        'The image took longer than ${_imageTimeout.inSeconds}s to render.',
      );
    } catch (e) {
      throw OpenAiException('Could not reach the image service: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenAiException(
        'Image generation failed: ${_truncate(response.body)}',
        statusCode: response.statusCode,
      );
    }

    final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw OpenAiException('The image service returned an unexpected shape.');
    }
    final Object? data = decoded['data'];
    if (data is! List || data.isEmpty || data.first is! Map) {
      throw OpenAiException('The image service returned no image.');
    }

    final Map<Object?, Object?> first = data.first as Map<Object?, Object?>;
    final Object? b64 = first['b64_json'];
    if (b64 is String && b64.isNotEmpty) {
      try {
        return base64Decode(b64);
      } on FormatException {
        throw OpenAiException('The generated image could not be decoded.');
      }
    }

    // Some deployments hand back a URL instead of inline base64.
    final Object? url = first['url'];
    if (url is String && url.isNotEmpty) {
      try {
        final http.Response image = await _client
            .get(Uri.parse(url))
            .timeout(_imageTimeout);
        if (image.statusCode == 200) return image.bodyBytes;
        throw OpenAiException(
          'Could not download the generated image.',
          statusCode: image.statusCode,
        );
      } on TimeoutException {
        throw OpenAiException('Downloading the generated image timed out.');
      }
    }

    throw OpenAiException('The image service returned no image data.');
  }

  /// Generates runnable Python/matplotlib code visualising the experiment.
  ///
  /// Throws [OpenAiException] when no key is set or the request fails.
  Future<String> generateVisualization(ExperimentJson experiment) async {
    // Fail fast with the exact "no key" message, unwrapped by the catch below.
    _requireApiKey();

    // Leading newline kept so the prompt matches the React template literal.
    final prompt =
        '\n'
        '''
Based on this experiment setup, generate Python code using matplotlib or similar libraries to visualize the expected output.

Experiment JSON:
${_prettyJson.convert(experiment.toJson())}

Generate complete, runnable Python code that creates a visualization of the experiment results.
Only return the code, no explanations.
''';

    try {
      return await _callOpenAi(
        model: _modelBalanced,
        effort: _ReasoningEffort.medium,
        input: prompt,
      );
    } on OpenAiException catch (e) {
      throw OpenAiException(
        'Failed to generate visualization: ${e.message}',
        statusCode: e.statusCode,
      );
    }
  }

  /// Releases the underlying HTTP client. Call when the owner is disposed.
  void dispose() => _client.close();

  /// Reads the key straight from [SettingsStore]; it is never stored on `this`.
  String _requireApiKey() {
    final key = _settings.apiKey?.trim();
    if (key == null || key.isEmpty) {
      throw OpenAiException(
        'No API key set. Add your OpenAI API key in Settings.',
      );
    }
    return key;
  }

  Future<String> _callOpenAi({
    required String model,
    required _ReasoningEffort effort,
    required String input,
    String? schemaName,
    Map<String, Object?>? schema,
  }) async {
    final apiKey = _requireApiKey();

    final body = <String, Object?>{
      'model': model,
      'reasoning': <String, Object?>{'effort': effort.wireValue},
      'input': <Map<String, Object?>>[
        <String, Object?>{'role': 'user', 'content': input},
      ],
      if (schemaName != null && schema != null)
        'text': <String, Object?>{
          'format': <String, Object?>{
            'type': 'json_schema',
            'name': schemaName,
            'strict': true,
            'schema': schema,
          },
        },
    };

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_openAiBaseUrl/responses'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              // Read fresh from SettingsStore on every call; never cached.
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw OpenAiException(
        'The request timed out after ${_requestTimeout.inSeconds} seconds. '
        'Check your connection and try again.',
      );
    } on http.ClientException catch (e) {
      throw OpenAiException('Network error: ${e.message}');
    } catch (_) {
      throw OpenAiException(
        'Could not reach the OpenAI API. Check your connection and try again.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenAiException(
        _truncate(_decodeBody(response)),
        statusCode: response.statusCode,
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(_decodeBody(response));
    } on FormatException {
      throw OpenAiException('The API returned a malformed JSON response.');
    }
    if (decoded is! Map) {
      throw OpenAiException('The API returned an unexpected response shape.');
    }

    final text = _extractOutputText(decoded);
    if (text == null || text.isEmpty) {
      throw OpenAiException('OpenAI API returned no output text');
    }
    return text;
  }

  /// Pulls the assistant text out of a Responses API payload.
  static String? _extractOutputText(Map<Object?, Object?> data) {
    final direct = data['output_text'];
    if (direct is String && direct.isNotEmpty) return direct;

    final output = data['output'];
    if (output is! List) return null;

    for (final item in output) {
      if (item is! Map) continue;
      if (item['type'] != 'message') continue;
      final content = item['content'];
      if (content is! List) continue;
      for (final part in content) {
        if (part is! Map) continue;
        if (part['type'] != 'output_text') continue;
        final text = part['text'];
        if (text is String && text.isNotEmpty) return text;
      }
    }
    return null;
  }

  /// Decodes as UTF-8 so emoji in prompts and answers survive the round trip.
  static String _decodeBody(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } on FormatException {
      return response.body;
    }
  }

  static String _truncate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'The API returned an empty error response.';
    if (trimmed.length <= _maxErrorBodyChars) return trimmed;
    return '${trimmed.substring(0, _maxErrorBodyChars)}…';
  }
}
