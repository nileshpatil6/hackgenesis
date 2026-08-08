import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/subject.dart';
import '../../services/openai_config_service.dart';
import '../../services/realtime_voice_service.dart';
import '../../utils/app_theme.dart';

/// A spoken conversation with the AI tutor about one subject.
///
/// Turn taking is handled by the model's voice activity detection, so there is
/// no button to hold: the student talks, stops, and the tutor answers.
class VoiceTutorScreen extends StatefulWidget {
  const VoiceTutorScreen({super.key, required this.subject});

  final Subject subject;

  @override
  State<VoiceTutorScreen> createState() => _VoiceTutorScreenState();
}

class _VoiceTutorScreenState extends State<VoiceTutorScreen> {
  RealtimeVoiceService? _service;
  final _subs = <StreamSubscription>[];
  final _turns = <_Turn>[];

  VoiceSessionState _state = VoiceSessionState.idle;
  String? _error;
  String _pendingReply = '';

  bool get _isLive =>
      _state == VoiceSessionState.listening ||
      _state == VoiceSessionState.speaking;

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _service?.dispose();
    super.dispose();
  }

  Future<void> _toggleSession() async {
    if (_isLive || _state == VoiceSessionState.connecting) {
      await _endSession();
      return;
    }

    final key = await OpenAIConfigService.getApiKey();
    if (!mounted) return;
    if (key == null || key.trim().isEmpty) {
      setState(() => _error =
          'Add your OpenAI API key in Settings to use the voice tutor.');
      return;
    }

    final service = RealtimeVoiceService(apiKey: key);
    _service = service;
    setState(() {
      _error = null;
      _turns.clear();
      _pendingReply = '';
    });

    _subs
      ..add(service.state.listen((s) {
        if (mounted) setState(() => _state = s);
      }))
      ..add(service.errors.listen((e) {
        if (mounted) setState(() => _error = e);
      }))
      ..add(service.userTranscript.listen((text) {
        if (!mounted) return;
        setState(() => _turns.add(_Turn(text: text, fromUser: true)));
      }))
      ..add(service.replyTranscript.listen((delta) {
        if (!mounted) return;
        setState(() => _pendingReply += delta);
      }));

    await service.start(
      instructions:
          'You are a warm, encouraging voice tutor helping a student study '
          '"${widget.subject.name}". Keep answers short and conversational, '
          'usually two or three sentences, because they are being spoken '
          'aloud. Ask a follow-up question to check understanding. Guide the '
          'student towards the answer rather than simply stating it.',
    );
  }

  Future<void> _endSession() async {
    // Flush whatever the tutor was mid-way through saying.
    if (_pendingReply.trim().isNotEmpty) {
      _turns.add(_Turn(text: _pendingReply.trim(), fromUser: false));
      _pendingReply = '';
    }
    await _service?.stop();
    if (mounted) setState(() => _state = VoiceSessionState.idle);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.textTheme.bodyLarge?.color,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Voice Tutor',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.subject.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_error != null) _buildError(),
            Expanded(child: _buildTranscript(isDark)),
            _buildControls(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFFB91C1C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscript(bool isDark) {
    if (_turns.isEmpty && _pendingReply.isEmpty) {
      return _buildIdlePrompt(isDark);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      itemCount: _turns.length + (_pendingReply.isEmpty ? 0 : 1),
      itemBuilder: (context, i) {
        if (i >= _turns.length) {
          return _TurnBubble(
            turn: _Turn(text: _pendingReply, fromUser: false),
            isDark: isDark,
          );
        }
        return _TurnBubble(turn: _turns[i], isDark: isDark);
      },
    );
  }

  Widget _buildIdlePrompt(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.graphic_eq_rounded,
              size: 56,
              color: AppTheme.primaryAccent.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 20),
            Text(
              _isLive ? 'Listening' : 'Talk through your notes',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isLive
                  ? 'Just start speaking. Pause when you are done and the '
                      'tutor will answer.'
                  : 'Start a session and ask anything about '
                      '${widget.subject.name}. No button to hold.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(bool isDark) {
    final (label, caption) = switch (_state) {
      VoiceSessionState.idle => ('Start session', 'Tap to begin'),
      VoiceSessionState.connecting => ('Connecting', 'Opening the line'),
      VoiceSessionState.listening => ('End session', 'Listening'),
      VoiceSessionState.speaking => ('End session', 'Tutor is speaking'),
      VoiceSessionState.error => ('Try again', 'Something went wrong'),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MicOrb(state: _state),
          const SizedBox(height: 14),
          Text(
            caption,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _state == VoiceSessionState.connecting
                  ? null
                  : _toggleSession,
              style: FilledButton.styleFrom(
                backgroundColor:
                    _isLive ? const Color(0xFFDC2626) : AppTheme.primaryAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class _Turn {
  const _Turn({required this.text, required this.fromUser});

  final String text;
  final bool fromUser;
}

class _TurnBubble extends StatelessWidget {
  const _TurnBubble({required this.turn, required this.isDark});

  final _Turn turn;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final mine = turn.fromUser;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: mine
              ? AppTheme.primaryAccent
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
        ),
        child: Text(
          turn.text,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: mine
                ? Colors.white
                : (isDark ? Colors.white : const Color(0xFF1A1D2E)),
          ),
        ),
      ),
    );
  }
}

/// Pulsing microphone indicator that reflects the session state.
class _MicOrb extends StatefulWidget {
  const _MicOrb({required this.state});

  final VoiceSessionState state;

  @override
  State<_MicOrb> createState() => _MicOrbState();
}

class _MicOrbState extends State<_MicOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.state == VoiceSessionState.listening ||
        widget.state == VoiceSessionState.speaking;
    final colour = switch (widget.state) {
      VoiceSessionState.speaking => AppTheme.tertiaryAccent,
      VoiceSessionState.error => const Color(0xFFDC2626),
      _ => AppTheme.primaryAccent,
    };

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = active ? _pulse.value : 0.0;
        return Container(
          width: 78 + 14 * t,
          height: 78 + 14 * t,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colour.withValues(alpha: 0.12 + 0.10 * t),
            border: Border.all(
              color: colour.withValues(alpha: 0.35 + 0.35 * t),
              width: 2,
            ),
          ),
          child: Icon(
            widget.state == VoiceSessionState.speaking
                ? Icons.volume_up_rounded
                : Icons.mic_rounded,
            size: 32,
            color: colour,
          ),
        );
      },
    );
  }
}
