import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/experiment.dart';
import '../theme/app_theme.dart';

/// Displays the AI's verdict on an experiment run.
///
/// Success and failure are deliberately styled very differently — winning
/// should feel like winning, and a failure should read as a nudge rather than
/// a dead end (the model is prompted never to hand over the solution).
class ResultSheet extends StatelessWidget {
  const ResultSheet({
    super.key,
    required this.isAnalyzing,
    required this.result,
    required this.onClose,
    required this.onRetry,
  });

  final bool isAnalyzing;
  final AnalysisResult? result;
  final VoidCallback onClose;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.92,
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
          child: Column(
            children: [
              _buildGrabber(),
              Expanded(
                child: isAnalyzing
                    ? const _AnalyzingView()
                    : result == null
                    ? const SizedBox.shrink()
                    : _ResultView(
                        result: result!,
                        scrollController: scrollController,
                      ),
              ),
              _buildActions(context),
            ],
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

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isAnalyzing ? null : onRetry,
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
    'Reading your circuit…',
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
              SizedBox(
                width: 180,
                child: LinearProgressIndicator(
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: AppColors.surfaceAlt,
                  color: AppColors.primary,
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
  const _ResultView({required this.result, required this.scrollController});

  final AnalysisResult result;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
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
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.5)),
              ),
              child: Text(
                ok ? '🎉' : '🔧',
                style: const TextStyle(fontSize: 22),
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
        if (result.svg != null) ...[
          const SizedBox(height: 20),
          _SvgPanel(svg: result.svg!),
        ],
        if (result.mistake != null) ...[
          const SizedBox(height: 18),
          _Section(
            emoji: '🧭',
            title: 'What to look at',
            body: result.mistake!,
            tint: AppColors.warning,
          ),
        ],
        if (result.explanation.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Section(
            emoji: '📖',
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
    required this.emoji,
    required this.title,
    required this.body,
    required this.tint,
  });

  final String emoji;
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
        border: Border.all(color: tint.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
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

/// Renders the AI-produced SVG, falling back gracefully when the markup is
/// malformed — a generated diagram is a bonus, never a hard requirement.
class _SvgPanel extends StatelessWidget {
  const _SvgPanel({required this.svg});

  final String svg;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: SvgPicture.string(
        svg,
        fit: BoxFit.contain,
        placeholderBuilder: (_) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: 24,
                color: Colors.black38,
              ),
              SizedBox(height: 6),
              Text(
                'Diagram could not be rendered',
                style: TextStyle(fontSize: 11.5, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
