import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Compact progression HUD meant to sit in the app bar.
///
/// Shows the level badge, the rank title, an animated progress fill, the
/// `xpIntoLevel / xpForNextLevel` readout and a flame chip once the player has
/// a multi-day streak going.
///
/// Stays under 56 logical pixels tall and drops the rank title on narrow
/// layouts so it never overflows.
///
/// ```dart
/// XpBar(
///   level: game.level,
///   rankTitle: game.rankTitle,
///   progress: game.levelProgress,
///   xpIntoLevel: game.xpIntoLevel,
///   xpForNextLevel: game.xpForNextLevel,
///   dayStreak: game.dayStreak,
/// )
/// ```
class XpBar extends StatelessWidget {
  /// Creates an XP HUD strip.
  const XpBar({
    super.key,
    required this.level,
    required this.rankTitle,
    required this.progress,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    this.dayStreak = 0,
  });

  /// Current level, shown in the badge.
  final int level;

  /// Flavour title for [level]. Hidden when the bar is narrower than 420px.
  final String rankTitle;

  /// Fill fraction of the current level, `0..1`. Values outside are clamped.
  final double progress;

  /// XP earned inside the current level.
  final int xpIntoLevel;

  /// Total XP span of the current level.
  final int xpForNextLevel;

  /// Consecutive days played. The flame chip appears when this exceeds 1.
  final int dayStreak;

  /// Width below which the rank title is dropped.
  static const double compactBreakpoint = 420;

  /// Fixed height of the strip.
  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showRank =
            constraints.maxWidth.isFinite &&
            constraints.maxWidth >= compactBreakpoint;
        final showStreak = dayStreak > 1;

        return Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: <Widget>[
              _LevelBadge(level: level),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        if (showRank)
                          Expanded(
                            child: Text(
                              rankTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        const SizedBox(width: 8),
                        Text(
                          '$xpIntoLevel / $xpForNextLevel XP',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFeatures: <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    _ProgressTrack(value: clamped),
                  ],
                ),
              ),
              if (showStreak) ...<Widget>[
                const SizedBox(width: 10),
                _StreakChip(days: dayStreak),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Rounded square badge holding the level number.
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.accent, AppColors.primaryDeep],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 12,
            spreadRadius: -2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text(
            'LV',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 7,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              height: 1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '$level',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// The animated fill track.
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 7,
        color: AppColors.background,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (context, animated, _) {
            return Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: animated.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: <Color>[AppColors.primary, AppColors.accent],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Flame pill showing the day streak.
class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$days day streak',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('🔥', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              '$days',
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
