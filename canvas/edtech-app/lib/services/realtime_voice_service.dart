import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Connection state of a live voice session.
enum VoiceSessionState {
  idle,
  connecting,
  listening,

  /// The model is talking back.
  speaking,
  error,
}

/// A live, spoken conversation with the OpenAI Realtime API.
///
/// Audio runs in both directions over a single WebSocket: microphone PCM is
/// streamed up as it is captured, and the model's reply is played back from
/// the audio deltas it streams down. Turn taking is handled server side by
/// voice activity detection, so the user can simply talk and stop.
///
/// The Realtime API only accepts 24 kHz mono signed 16-bit PCM, which is why
/// both the recorder and the player are pinned to [sampleRate] below.
class RealtimeVoiceService {
  RealtimeVoiceService({required this.apiKey, this.model = _defaultModel});

  static const String _defaultModel = 'gpt-realtime-2.1';

  /// Mandated by the Realtime API. Do not change without changing both the
  /// recorder config and the player setup.
  static const int sampleRate = 24000;

  final String apiKey;
  final String model;

  final _recorder = AudioRecorder();
  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _micSub;
  StreamSubscription? _socketSub;
  bool _playerReady = false;
  bool _closed = false;

  final _stateController = StreamController<VoiceSessionState>.broadcast();
  final _userTranscriptController = StreamController<String>.broadcast();
  final _replyTranscriptController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// Connection and turn state, for driving the UI.
  Stream<VoiceSessionState> get state => _stateController.stream;

  /// Transcript of what the user said, emitted once per turn.
  Stream<String> get userTranscript => _userTranscriptController.stream;

  /// The model's spoken reply, streamed in as it is generated.
  Stream<String> get replyTranscript => _replyTranscriptController.stream;

  /// Human-readable failures worth surfacing.
  Stream<String> get errors => _errorController.stream;

  /// Opens the session and starts streaming the microphone.
  ///
  /// [instructions] becomes the system prompt, so callers can ground the tutor
  /// in the subject the student is studying.
  Future<void> start({required String instructions}) async {
    if (_channel != null) return;
    _closed = false;
    _emit(VoiceSessionState.connecting);

    if (!await _recorder.hasPermission()) {
      _fail('Microphone permission is required for the voice tutor.');
      return;
    }

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('wss://api.openai.com/v1/realtime?model=$model'),
        // The Realtime API authenticates with the same key as the REST API.
        protocols: [
          'realtime',
          'openai-insecure-api-key.$apiKey',
          'openai-beta.realtime-v1',
        ],
      );
      await _channel!.ready;
    } catch (e) {
      _fail('Could not reach the voice service: $e');
      return;
    }

    _socketSub = _channel!.stream.listen(
      _onServerEvent,
      onError: (e) => _fail('Voice connection error: $e'),
      onDone: () {
        if (!_closed) _fail('The voice connection closed unexpectedly.');
      },
    );

    _send({
      'type': 'session.update',
      'session': {
        'modalities': ['audio', 'text'],
        'instructions': instructions,
        'voice': 'cedar',
        'input_audio_format': 'pcm16',
        'output_audio_format': 'pcm16',
        'input_audio_transcription': {'model': 'whisper-1'},
        // Server-side VAD means the model decides when the user has finished
        // speaking, so there is no push-to-talk button to hold.
        'turn_detection': {
          'type': 'server_vad',
          'threshold': 0.5,
          'silence_duration_ms': 600,
          'prefix_padding_ms': 300,
        },
      },
    });

    await _startPlayback();
    await _startMicrophone();
    _emit(VoiceSessionState.listening);
  }

  Future<void> _startPlayback() async {
    if (_playerReady) return;
    await FlutterPcmSound.setup(sampleRate: sampleRate, channelCount: 1);
    await FlutterPcmSound.setFeedThreshold(sampleRate ~/ 10);
    _playerReady = true;
  }

  Future<void> _startMicrophone() async {
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );

    _micSub = stream.listen((chunk) {
      if (_channel == null || chunk.isEmpty) return;
      _send({
        'type': 'input_audio_buffer.append',
        'audio': base64Encode(chunk),
      });
    });
  }

  void _onServerEvent(dynamic raw) {
    final Map<String, dynamic> event;
    try {
      event = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (event['type'] as String? ?? '') {
      // Both spellings appear across API versions; accept either rather than
      // silently playing nothing if the account is on the other one.
      case 'response.output_audio.delta':
      case 'response.audio.delta':
        _playChunk(event['delta'] as String?);
        _emit(VoiceSessionState.speaking);

      case 'response.output_audio_transcript.delta':
      case 'response.audio_transcript.delta':
        final delta = event['delta'] as String?;
        if (delta != null && delta.isNotEmpty) {
          _replyTranscriptController.add(delta);
        }

      case 'conversation.item.input_audio_transcription.completed':
        final text = event['transcript'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          _userTranscriptController.add(text.trim());
        }

      case 'input_audio_buffer.speech_started':
        _emit(VoiceSessionState.listening);

      case 'response.done':
        _emit(VoiceSessionState.listening);

      case 'error':
        final message = (event['error'] as Map?)?['message'] as String?;
        _fail(message ?? 'The voice service reported an error.');
    }
  }

  void _playChunk(String? base64Audio) {
    if (base64Audio == null || base64Audio.isEmpty || !_playerReady) return;
    try {
      final bytes = base64Decode(base64Audio);
      FlutterPcmSound.feed(
        PcmArrayInt16(bytes: ByteData.sublistView(bytes)),
      );
    } catch (e) {
      debugPrint('Voice playback failed: $e');
    }
  }

  void _send(Map<String, dynamic> event) {
    try {
      _channel?.sink.add(jsonEncode(event));
    } catch (e) {
      debugPrint('Voice send failed: $e');
    }
  }

  void _emit(VoiceSessionState value) {
    if (!_stateController.isClosed) _stateController.add(value);
  }

  void _fail(String message) {
    if (!_errorController.isClosed) _errorController.add(message);
    _emit(VoiceSessionState.error);
  }

  /// Ends the session and releases the microphone and speaker.
  Future<void> stop() async {
    _closed = true;
    await _micSub?.cancel();
    _micSub = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await _socketSub?.cancel();
    _socketSub = null;
    await _channel?.sink.close();
    _channel = null;
    if (_playerReady) {
      await FlutterPcmSound.release();
      _playerReady = false;
    }
    _emit(VoiceSessionState.idle);
  }

  /// Releases everything. The instance cannot be reused afterwards.
  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
    await _stateController.close();
    await _userTranscriptController.close();
    await _replyTranscriptController.close();
    await _errorController.close();
  }
}
