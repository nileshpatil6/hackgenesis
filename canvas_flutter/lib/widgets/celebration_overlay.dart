import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../game/achievements.dart';
import '../theme/app_theme.dart';

/// Wraps [child] and rains confetti from the top of the screen whenever
/// [controller] is played.
///
/// The controller is owned by the caller — create it in a `State`, call
/// `play()` on a win, and dispose it yourself.
///
/// ```dart
/// CelebrationOverlay(
///   controller: _confetti,
///   child: Scaffold(...),
/// )
/// ```
class CelebrationOverlay extends StatelessWidget {
  /// Creates a confetti-capable wrapper around [child].
  const CelebrationOverlay({
    super.key,
    required this.controller,
    required this.child,
  });

  /// Drives the confetti burst. Not disposed by this widget.
  final ConfettiController controller;

  /// The content the confetti falls over.
  final Widget child;

  /// Palette used for the confetti particles.
  static const List<Color> confettiColors = <Color>[
    AppColors.primary,
    AppColors.success,
    AppColors.warning,
    AppColors.accent,
    AppColors.purple,
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: controller,
                blastDirectionality: BlastDirectionality.explosive,
                blastDirection: math.pi / 2,
                emissionFrequency: 0.06,
                numberOfParticles: 18,
                minBlastForce: 8,
                maxBlastForce: 26,
                gravity: 0.28,
                particleDrag: 0.05,
                shouldLoop: false,
                colors: confettiColors,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A transient card announcing that an achievement just unlocked.
///
/// Pass it straight to [showGameToast], or embed it anywhere a card fits.
class AchievementToast extends StatelessWidget {
  /// Creates a toast for [achievement].
  const AchievementToast({
    super.key,
    required this.achievement,
    this.onDismiss,
  });

  /// The achievement that unlocked.
  final Achievement achievement;

  /// Called when the card is tapped. Optional.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final tint = achievement.tier.color;
    return _ToastCard(
      tint: tint,
      onDismiss: onDismiss,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _GlyphBadge(tint: tint, glyph: achievement.emoji),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${achievement.tier.label.toUpperCase()} UNLOCKED',
                  style: TextStyle(
                    color: tint,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  achievement.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _XpChip(amount: achievement.xpReward, tint: tint),
        ],
      ),
    );
  }
}

/// A transient card announcing that the player reached a new level.
class LevelUpToast extends StatelessWidget {
  /// Creates a level-up toast for [level] and its [rankTitle].
  const LevelUpToast({
    super.key,
    required this.level,
    required this.rankTitle,
    this.onDismiss,
  });

  /// The level just reached.
  final int level;

  /// Flavour title that comes with the new level.
  final String rankTitle;

  /// Called when the card is tapped. Optional.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    const tint = AppColors.purple;
    return _ToastCard(
      tint: tint,
      onDismiss: onDismiss,
      child: Row(
        children: <Widget>[
          _GlyphBadge(tint: tint, glyph: '$level', isNumeric: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'LEVEL UP',
                  style: TextStyle(
                    color: tint,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Level $level reached',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You are now a $rankTitle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Text('🎉', style: TextStyle(fontSize: 26)),
        ],
      ),
    );
  }
}

/// Shows [toast] as an auto-dismissing overlay entry near the top of the
/// screen, sliding and fading in and back out.
///
/// The returned future completes once the toast has fully left the screen, so
/// several toasts can be queued with `await`:
///
/// ```dart
/// for (final a in unlocked) {
///   await showGameToast(context, AchievementToast(achievement: a));
/// }
/// ```
///
/// Resolves immediately when [context] has no [Overlay].
Future<void> showGameToast(BuildContext context, Widget toast) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return Future<void>.value();

  final completer = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ToastHost(
      onFinished: () {
        entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
      child: toast,
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

/// How long a toast stays fully visible before it starts leaving.
const Duration _kToastHold = Duration(milliseconds: 3500);
const Duration _kToastIn = Duration(milliseconds: 420);
const Duration _kToastOut = Duration(milliseconds: 260);

class _ToastHost extends StatefulWidget {
  const _ToastHost({required this.child, required this.onFinished});

  final Widget child;
  final VoidCallback onFinished;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _kToastIn,
    reverseDuration: _kToastOut,
  );
  Timer? _holdTimer;
  bool _finished = false;

  late final CurvedAnimation _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  late final CurvedAnimation _pop = CurvedAnimation(
    parent: _controller,
    curve: Curves.elasticOut,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _holdTimer = Timer(_kToastHold, _dismiss);
  }

  Future<void> _dismiss() async {
    _holdTimer?.cancel();
    if (_finished) return;
    _finished = true;
    if (mounted) await _controller.reverse();
    widget.onFinished();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _fade.dispose();
    _pop.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = _pop.value;
                  return Opacity(
                    opacity: _fade.value.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, -46 * (1 - _fade.value)),
                      child: Transform.scale(
                        scale: 0.92 + 0.08 * t,
                        alignment: Alignment.topCenter,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Material(
                  type: MaterialType.transparency,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared chrome for both toast kinds: dark card, tinted border and glow.
class _ToastCard extends StatelessWidget {
  const _ToastCard({required this.child, required this.tint, this.onDismiss});

  final Widget child;
  final Color tint;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tint.withValues(alpha: 0.55), width: 1.5),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color.alphaBlend(tint.withValues(alpha: 0.16), AppColors.surface),
              AppColors.surfaceAlt,
            ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: tint.withValues(alpha: 0.32),
              blurRadius: 26,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
            const BoxShadow(
              color: Color(0x66000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Circular emoji (or number) badge with a tinted ring.
class _GlyphBadge extends StatelessWidget {
  const _GlyphBadge({
    required this.tint,
    required this.glyph,
    this.isNumeric = false,
  });

  final Color tint;
  final String glyph;
  final bool isNumeric;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tint.withValues(alpha: 0.18),
        border: Border.all(color: tint.withValues(alpha: 0.7), width: 2),
      ),
      child: Text(
        glyph,
        style: TextStyle(
          fontSize: isNumeric ? 19 : 22,
          fontWeight: FontWeight.w800,
          color: isNumeric ? AppColors.textPrimary : null,
        ),
      ),
    );
  }
}

/// Small `+NN XP` pill.
class _XpChip extends StatelessWidget {
  const _XpChip({required this.amount, required this.tint});

  final int amount;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: 0.45)),
      ),
      child: Text(
        '+$amount XP',
        style: TextStyle(
          color: tint,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
