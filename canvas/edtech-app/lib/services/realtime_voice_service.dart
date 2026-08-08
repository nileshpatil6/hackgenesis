import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/io.dart';
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
  RealtimeVoiceService({
    required this.apiKey,
    this.model = _defaultModel,
    this.voice = 'marin',
  });

  static const String _defaultModel = 'gpt-realtime-2.1';

  /// Mandated by the Realtime API. Do not change without changing both the
  /// recorder config and the player setup.
  static const int sampleRate = 24000;

  final String apiKey;
  final String model;

  /// Realtime voice name. Not all voices exist on every model.
  final String voice;

  /// Completes when the server confirms the session is open.
  Completer<void> _sessionCreated = Completer<void>();

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
  final _warningController = StreamController<String>.broadcast();

  /// Connection and turn state, for driving the UI.
  Stream<VoiceSessionState> get state => _stateController.stream;

  /// Transcript of what the user said, emitted once per turn.
  Stream<String> get userTranscript => _userTranscriptController.stream;

  /// The model's spoken reply, streamed in as it is generated.
  Stream<String> get replyTranscript => _replyTranscriptController.stream;

  /// Failures that ended the session.
  Stream<String> get errors => _errorController.stream;

  /// Problems the session survived, such as a rejected configuration. Worth
  /// showing quietly, but not worth stopping a conversation that still works.
  Stream<String> get warnings => _warningController.stream;

  /// Opens the session and starts streaming the microphone.
  ///
  /// [instructions] becomes the system prompt, so callers can ground the tutor
  /// in the subject the student is studying.
  Future<void> start({required String instructions}) async {
    if (_channel != null) return;
    _closed = false;
    _sessionCreated = Completer<void>();
    _emit(VoiceSessionState.connecting);

    if (!await _recorder.hasPermission()) {
      _fail('Microphone permission is required for the voice tutor.');
      return;
    }

    try {
      final uri = Uri.parse('wss://api.openai.com/v1/realtime?model=$model');
      // Real headers, not the subprotocol trick. Passing the key as a
      // WebSocket subprotocol is a browser-only workaround, because the web
      // WebSocket API cannot set headers. On mobile it authenticates nothing
      // and the handshake is rejected, which is why the session never opened.
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: <String, dynamic>{
          'Authorization': 'Bearer $apiKey',
          // No OpenAI-Beta header. Sending it selects the beta wire format,
          // which the server now refuses outright with beta_api_shape_disabled.
        },
        pingInterval: const Duration(seconds: 20),
      );
      await _channel!.ready;
    } catch (e) {
      _fail(_readableConnectError(e));
      return;
    }

    _socketSub = _channel!.stream.listen(
      _onServerEvent,
      onError: (e) => _failAndTeardown('Voice connection error: $e'),
      onDone: _onSocketClosed,
    );

    // Wait for the server to open the session before configuring it. Sending
    // session.update immediately is a race: if it lands first, or carries a
    // field this API version rejects, the server simply closes the socket,
    // which is what "connection closed unexpectedly" was.
    try {
      await _sessionCreated.future.timeout(const Duration(seconds: 12));
    } on TimeoutException {
      await _failAndTeardown('The voice service did not start a session.');
      return;
    } catch (e) {
      await _failAndTeardown('The voice service refused the session: $e');
      return;
    }
    if (_closed || _channel == null) return;

    // GA session shape. The beta form put the audio settings at the top of
    // `session`; the GA form nests them under `audio.input` / `audio.output`
    // and requires the explicit session type.
    _send({
      'type': 'session.update',
      'session': {
        'type': 'realtime',
        'instructions': instructions,
        'audio': {
          'input': {
            'format': {'type': 'audio/pcm', 'rate': sampleRate},
            // Semantic VAD decides when the student has actually finished a
            // thought rather than just paused, so there is no button to hold.
            'turn_detection': {'type': 'semantic_vad'},
            'transcription': {'model': 'whisper-1'},
          },
          'output': {
            // rate is required here too, not just on the input. The docs show
            // it only on the input side, but the server rejects the session
            // with missing_required_parameter without it, and then silently
            // falls back to defaults, so the instructions and voice below
            // were never actually applied.
            'format': {'type': 'audio/pcm', 'rate': sampleRate},
            'voice': voice,
          },
        },
      },
    });

    await _startPlayback();
    await _startMicrophone();

    // Only now, and only if the socket survived the round trip. Emitting
    // unconditionally is what left the UI reading "Listening" underneath an
    // error banner.
    if (!_closed && _channel != null) {
      _emit(VoiceSessionState.listening);
    }
  }

  /// Reports why the socket went away, then releases the hardware.
  ///
  /// The close code carries the reason the handshake or session was refused,
  /// and without it every failure looked identical from the UI.
  void _onSocketClosed() {
    if (_closed) return;
    final code = _channel?.closeCode;
    final reason = (_channel?.closeReason ?? '').trim();

    final detail = switch (code) {
      1000 || null => reason.isEmpty ? '' : ' ($reason)',
      1008 => ' (rejected: ${reason.isEmpty ? "policy violation" : reason})',
      _ => ' (code $code${reason.isEmpty ? '' : ': $reason'})',
    };
    _failAndTeardown('The voice session ended$detail.');
  }

  /// Surfaces [message] and stops the microphone and speaker.
  ///
  /// Without the teardown the recorder kept running after a failed session,
  /// holding the mic open and the recording indicator lit.
  Future<void> _failAndTeardown(String message) async {
    _fail(message);
    await stop();
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

      case 'session.created':
      case 'session.updated':
        if (!_sessionCreated.isCompleted) _sessionCreated.complete();

      case 'input_audio_buffer.speech_started':
        _emit(VoiceSessionState.listening);

      case 'response.done':
        _emit(VoiceSessionState.listening);

      case 'error':
        final err = event['error'] as Map?;
        final message = err?['message'] as String?;
        debugPrint('Realtime error event: $err');

        if (!_sessionCreated.isCompleted) {
          // Still opening: this is fatal, and unblocking start() lets it
          // report the real reason rather than timing out.
          _sessionCreated.completeError(
            StateError(message ?? 'session rejected'),
          );
          return;
        }

        // The session is already live. A rejected session.update leaves the
        // model running on defaults, so tearing everything down or flashing a
        // red banner over a working conversation is worse than carrying on.
        _warningController.add(
          message ?? 'The voice service reported a problem.',
        );
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

  /// Turns a handshake failure into something a user can act on.
  String _readableConnectError(Object e) {
    final text = e.toString();
    if (text.contains('401') || text.contains('403')) {
      return 'OpenAI rejected the API key. Check it in Settings, and that '
          'your account has Realtime API access.';
    }
    if (text.contains('404')) {
      return 'The voice model "$model" is not available on this account.';
    }
    if (text.contains('SocketException') || text.contains('Failed host')) {
      return 'No internet connection.';
    }
    return 'Could not start the voice session: $text';
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
    await _warningController.close();
  }
}
