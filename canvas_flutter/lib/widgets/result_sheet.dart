import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/waiting_quiz.dart';
import '../models/experiment.dart';
import '../theme/app_theme.dart';
import 'waiting_quiz_view.dart';

/// Everything the result sheet needs to know about the current run.
///
/// Held in a [ValueNotifier] by the host: the sheet lives in its own modal
/// route, so a `setState` on the host would never reach it. Listening to a
/// notifier is what keeps the sheet in step with the run.
@immutable
class ExperimentRun {
  const ExperimentRun({
    this.isAnalyzing = false,
    this.result,
    this.isRenderingImage = false,
    this.imageBytes,
    this.imageError,
  });

  final bool isAnalyzing;
  final AnalysisResult? result;

  /// True while the illustration is being rendered by the image model.
  final bool isRenderingImage;
  final Uint8List? imageBytes;
  final String? imageError;

  /// Whether anything is still in flight.
  ///
  /// The sheet holds the quiz until this clears, so the verdict, the
  /// explanation and the picture all arrive together as one reveal.
  bool get isBusy => isAnalyzing || isRenderingImage;
}

/// Displays the AI's verdict on an experiment run.
///
/// Success and failure are styled very differently — winning should feel like
/// winning, and a failure should read as a nudge rather than a dead end (the
/// model is prompted never to hand over the solution).
class ResultSheet extends StatelessWidget {
  const ResultSheet({
    super.key,
    required this.run,
    required this.questions,
    required this.onClose,
    required this.onRetry,
  });

  final ValueListenable<ExperimentRun> run;

  /// Local quiz shown while the run is still in flight.
  final List<QuizQuestion> questions;
  final VoidCallback onClose;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            border: Border(
              top: BorderSide(color: AppColors.border),
              left: BorderSide(color: AppColors.border),
              right: BorderSide(color: AppColors.border),
            ),
          ),
          child: ValueListenableBuilder<ExperimentRun>(
            valueListenable: run,
            builder: (context, state, _) {
              return Column(
                children: [
                  _buildGrabber(),
                  Expanded(
                    child: state.isBusy
                        ? WaitingQuizView(questions: questions)
                        : state.result == null
                        ? const SizedBox.shrink()
                        : _ResultView(
                            state: state,
                            scrollController: scrollController,
                          ),
                  ),
                  _buildActions(state),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildGrabber() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildActions(ExperimentRun state) {
    final busy = state.isBusy;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: busy ? null : onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Run again'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Back to lab'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.state, required this.scrollController});

  final ExperimentRun state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final result = state.result!;
    final ok = result.success;
    // Failure leans on a deep red so a bad run is unmistakable at a glance.
    final accent = ok ? AppColors.success : AppColors.dangerDeep;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        _buildHeader(result, ok, accent),

        // Words first: the explanation is the substance, the picture is
        // the garnish, so reading order runs top-down from verdict to image.
        if (result.mistake != null) ...[
          const SizedBox(height: 18),
          _Section(
            icon: Icons.error_outline,
            title: 'What went wrong',
            body: result.mistake!,
            tint: AppColors.dangerDeep,
            fill: AppColors.dangerSoft,
          ),
        ],
        if (result.explanation.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Section(
            icon: Icons.menu_book_outlined,
            title: 'Explanation',
            body: result.explanation,
            tint: ok ? AppColors.primary : AppColors.dangerDeep,
          ),
        ],
        if (state.imageBytes != null || state.imageError != null) ...[
          const SizedBox(height: 18),
          _ImagePanel(state: state),
        ],
      ],
    );
  }

  Widget _buildHeader(AnalysisResult result, bool ok, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ok
            ? AppColors.success.withValues(alpha: 0.07)
            : AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: ok ? 0.3 : 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              ok ? Icons.check_rounded : Icons.priority_high_rounded,
              size: 24,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.message,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: ok
                        ? AppColors.textSecondary
                        : AppColors.dangerDeep.withValues(alpha: 0.85),
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

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.body,
    required this.tint,
    this.fill,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color tint;

  /// Background wash; defaults to the neutral inset colour.
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fill ?? AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: tint),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: tint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          SelectableText(
            body,
            style: const TextStyle(
              fontSize: 13,
              height: 1.55,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the AI-rendered illustration of the outcome.
///
/// The picture is a bonus, never a requirement — a render failure degrades to
/// a quiet note rather than taking the whole result down with it.
class _ImagePanel extends StatelessWidget {
  const _ImagePanel({required this.state});

  final ExperimentRun state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    final bytes = state.imageBytes;
    if (bytes != null) {
      return InteractiveViewer(
        maxScale: 4,
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) => const _ImageNote(
            text: 'The illustration could not be displayed.',
          ),
        ),
      );
    }

    if (state.isRenderingImage) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(height: 14),
            Text(
              'Painting your result…',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'This can take up to a minute.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return _ImageNote(text: state.imageError ?? 'No illustration available.');
  }
}

class _ImageNote extends StatelessWidget {
  const _ImageNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.image_not_supported_outlined,
              size: 24,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
