import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/experiment.dart';
import '../theme/app_theme.dart';

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
    required this.onClose,
    required this.onRetry,
  });

  final ValueListenable<ExperimentRun> run;
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
                    child: state.isAnalyzing
                        ? const _AnalyzingView()
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
    final busy = state.isAnalyzing || state.isRenderingImage;
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

class _AnalyzingView extends StatefulWidget {
  const _AnalyzingView();

  @override
  State<_AnalyzingView> createState() => _AnalyzingViewState();
}

class _AnalyzingViewState extends State<_AnalyzingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  static const _steps = [
    'Reading your build…',
    'Checking the connections…',
    'Simulating the outcome…',
    'Writing up the results…',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final step = (_controller.value * _steps.length).floor().clamp(
            0,
            _steps.length - 1,
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: _controller.value * 6.28318,
                child: const Icon(
                  Icons.science_outlined,
                  size: 44,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Running your experiment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: Text(
                  _steps[step],
                  key: ValueKey(step),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const SizedBox(
                width: 180,
                child: LinearProgressIndicator(
                  minHeight: 5,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
            ],
          );
        },
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
    final accent = ok ? AppColors.success : AppColors.warning;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Icon(
                ok ? Icons.celebration_outlined : Icons.build_outlined,
                size: 22,
                color: accent,
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
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    result.message,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (state.isRenderingImage ||
            state.imageBytes != null ||
            state.imageError != null) ...[
          const SizedBox(height: 20),
          _ImagePanel(state: state),
        ],
        if (result.mistake != null) ...[
          const SizedBox(height: 18),
          _Section(
            icon: Icons.explore_outlined,
            title: 'What to look at',
            body: result.mistake!,
            tint: AppColors.warning,
          ),
        ],
        if (result.explanation.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Section(
            icon: Icons.menu_book_outlined,
            title: 'Explanation',
            body: result.explanation,
            tint: AppColors.primary,
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.body,
    required this.tint,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
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
