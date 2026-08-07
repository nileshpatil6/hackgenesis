import 'package:flutter/material.dart';

import '../game/waiting_quiz.dart';
import '../theme/app_theme.dart';

/// Fills the wait for an experiment result with a quick local quiz.
///
/// Every question is hardcoded and picked to match the domains the player just
/// built with, so the wait feels like part of the lab rather than dead time.
/// Nothing here touches the network — the whole point is to add zero load to
/// the request we are waiting on.
class WaitingQuizView extends StatefulWidget {
  const WaitingQuizView({super.key, required this.questions});

  final List<QuizQuestion> questions;

  @override
  State<WaitingQuizView> createState() => _WaitingQuizViewState();
}

class _WaitingQuizViewState extends State<WaitingQuizView> {
  int _index = 0;
  int? _picked;
  int _correct = 0;
  int _answered = 0;

  QuizQuestion get _question =>
      widget.questions[_index % widget.questions.length];

  bool get _isAnswered => _picked != null;

  void _pick(int option) {
    if (_isAnswered) return;
    setState(() {
      _picked = option;
      _answered++;
      if (option == _question.correctIndex) _correct++;
    });
  }

  void _next() {
    setState(() {
      _index++;
      _picked = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = _question;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          Text(
            question.question,
            style: const TextStyle(
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OptionTile(
                label: question.options[i],
                state: _stateFor(i),
                onTap: () => _pick(i),
              ),
            ),
          if (_isAnswered) ...[
            const SizedBox(height: 6),
            _buildFeedback(question),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _next,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Next question'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _OptionState _stateFor(int i) {
    if (!_isAnswered) return _OptionState.idle;
    if (i == _question.correctIndex) return _OptionState.correct;
    if (i == _picked) return _OptionState.wrong;
    return _OptionState.dimmed;
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Running your experiment…',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Answer a few while the lab works.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (_answered > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '$_correct / $_answered',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeedback(QuizQuestion question) {
    final right = _picked == question.correctIndex;
    final tint = right ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            right ? Icons.check_circle_outline : Icons.lightbulb_outline,
            size: 16,
            color: tint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  right ? 'Correct' : 'Not quite',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: tint,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  question.fact,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong, dimmed }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (
      Color border,
      Color fill,
      Color text,
      IconData? icon,
    ) = switch (state) {
      _OptionState.idle => (
        AppColors.border,
        AppColors.surfaceAlt,
        AppColors.textPrimary,
        null,
      ),
      _OptionState.correct => (
        AppColors.success,
        AppColors.success.withValues(alpha: 0.10),
        AppColors.textPrimary,
        Icons.check_circle,
      ),
      _OptionState.wrong => (
        AppColors.danger,
        AppColors.danger.withValues(alpha: 0.08),
        AppColors.textPrimary,
        Icons.cancel_outlined,
      ),
      _OptionState.dimmed => (
        AppColors.border,
        AppColors.surfaceAlt,
        AppColors.textMuted,
        null,
      ),
    };

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: state == _OptionState.idle ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: border,
              width: state == _OptionState.idle || state == _OptionState.dimmed
                  ? 1
                  : 1.6,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: text,
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 10),
                Icon(icon, size: 17, color: border),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
