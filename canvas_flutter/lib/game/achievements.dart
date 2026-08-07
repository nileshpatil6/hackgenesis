import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rarity band of an [Achievement]. Drives badge colour and XP scale.
enum AchievementTier {
  /// Entry-level "you tried it once" milestones.
  bronze,

  /// Mid-game milestones that take a few sessions.
  silver,

  /// Serious commitment milestones.
  gold,

  /// The long-haul trophies.
  legendary,
}

/// Badge colours for each [AchievementTier], pulled from [AppColors].
extension AchievementTierColor on AchievementTier {
  /// The accent colour used for this tier's badge, glow and border.
  Color get color {
    switch (this) {
      case AchievementTier.bronze:
        return AppColors.warning;
      case AchievementTier.silver:
        return AppColors.textSecondary;
      case AchievementTier.gold:
        return AppColors.accent;
      case AchievementTier.legendary:
        return AppColors.purple;
    }
  }

  /// Human-readable tier name, e.g. `Legendary`.
  String get label {
    switch (this) {
      case AchievementTier.bronze:
        return 'Bronze';
      case AchievementTier.silver:
        return 'Silver';
      case AchievementTier.gold:
        return 'Gold';
      case AchievementTier.legendary:
        return 'Legendary';
    }
  }
}

/// A one-off milestone the player can unlock exactly once.
///
/// Achievements are pure data — the unlock rules live in `GameState`, which
/// evaluates them after every recorded event and awards [xpReward] on unlock.
@immutable
class Achievement {
  /// Creates an achievement definition.
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.xpReward,
    required this.tier,
  });

  /// Stable identifier persisted in shared_preferences. Never reuse an id.
  final String id;

  /// Short headline shown in the unlock toast.
  final String title;

  /// One-line explanation of how it was earned.
  final String description;

  /// Single glyph shown on the badge.
  final String emoji;

  /// XP granted the moment this unlocks.
  final int xpReward;

  /// Rarity band, used for colour and sorting.
  final AchievementTier tier;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Achievement && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// How many distinct component categories count as "every category".
///
/// Kept here so the category-sweep achievements and `GameState` agree without
/// either of them importing the component catalogue.
const int kCategorySweepTarget = 8;

/// Every achievement in the game, ordered roughly by the path a player walks.
const List<Achievement> kAchievements = <Achievement>[
  // ---------------------------------------------------------------- bronze
  Achievement(
    id: 'first_component',
    title: 'First Contact',
    description: 'Place your very first component on the canvas.',
    emoji: '🧩',
    xpReward: 25,
    tier: AchievementTier.bronze,
  ),
  Achievement(
    id: 'first_edge',
    title: 'Making Connections',
    description: 'Wire two components together.',
    emoji: '🔗',
    xpReward: 25,
    tier: AchievementTier.bronze,
  ),
  Achievement(
    id: 'first_run',
    title: 'Power On',
    description: 'Run your first experiment.',
    emoji: '🔌',
    xpReward: 30,
    tier: AchievementTier.bronze,
  ),
  Achievement(
    id: 'first_success',
    title: 'It Works!',
    description: 'Get your first successful result.',
    emoji: '✅',
    xpReward: 60,
    tier: AchievementTier.bronze,
  ),
  Achievement(
    id: 'first_failure',
    title: 'Fail Forward',
    description: 'Break something. Every scientist does.',
    emoji: '💥',
    xpReward: 30,
    tier: AchievementTier.bronze,
  ),
  Achievement(
    id: 'first_hint',
    title: 'Ask the Robot',
    description: 'Ask the lab assistant for a hint.',
    emoji: '🤖',
    xpReward: 20,
    tier: AchievementTier.bronze,
  ),
  Achievement(
    id: 'first_example',
    title: 'Standing on Shoulders',
    description: 'Load a ready-made example experiment.',
    emoji: '📚',
    xpReward: 20,
    tier: AchievementTier.bronze,
  ),
  Achievement(
    id: 'first_export',
    title: 'Published',
    description: 'Export an experiment out of the lab.',
    emoji: '📤',
    xpReward: 25,
    tier: AchievementTier.bronze,
  ),

  // ---------------------------------------------------------------- silver
  Achievement(
    id: 'success_5',
    title: 'Lab Regular',
    description: 'Land 5 successful experiments.',
    emoji: '🧪',
    xpReward: 120,
    tier: AchievementTier.silver,
  ),
  Achievement(
    id: 'components_50',
    title: 'Well Stocked',
    description: 'Place 50 components in total.',
    emoji: '📦',
    xpReward: 130,
    tier: AchievementTier.silver,
  ),
  Achievement(
    id: 'edges_15',
    title: 'Wire Wizard',
    description: 'Connect 15 edges across your builds.',
    emoji: '🕸️',
    xpReward: 160,
    tier: AchievementTier.silver,
  ),
  Achievement(
    id: 'graph_10_nodes',
    title: 'Big Build',
    description: 'Run an experiment with 10 or more components.',
    emoji: '🏗️',
    xpReward: 150,
    tier: AchievementTier.silver,
  ),
  Achievement(
    id: 'categories_5',
    title: 'Cross Discipline',
    description: 'Use components from 5 different categories.',
    emoji: '🌐',
    xpReward: 140,
    tier: AchievementTier.silver,
  ),
  Achievement(
    id: 'streak_3',
    title: 'Hat Trick',
    description: 'Succeed three experiments in a row.',
    emoji: '🔥',
    xpReward: 180,
    tier: AchievementTier.silver,
  ),
  Achievement(
    id: 'hints_10',
    title: 'Curious Mind',
    description: 'Ask the assistant 10 questions.',
    emoji: '❓',
    xpReward: 110,
    tier: AchievementTier.silver,
  ),
  Achievement(
    id: 'level_5',
    title: 'Apprentice Ascended',
    description: 'Reach level 5.',
    emoji: '⭐',
    xpReward: 200,
    tier: AchievementTier.silver,
  ),

  // ------------------------------------------------------------------ gold
  Achievement(
    id: 'success_25',
    title: 'Method Master',
    description: 'Land 25 successful experiments.',
    emoji: '⚗️',
    xpReward: 400,
    tier: AchievementTier.gold,
  ),
  Achievement(
    id: 'runs_50',
    title: 'Marathon Mind',
    description: 'Run 50 experiments.',
    emoji: '🚀',
    xpReward: 350,
    tier: AchievementTier.gold,
  ),
  Achievement(
    id: 'categories_all',
    title: 'Polymath',
    description: 'Use components from $kCategorySweepTarget different fields.',
    emoji: '🧠',
    xpReward: 450,
    tier: AchievementTier.gold,
  ),
  Achievement(
    id: 'day_streak_7',
    title: 'Dedicated Scientist',
    description: 'Show up in the lab 7 days running.',
    emoji: '📅',
    xpReward: 500,
    tier: AchievementTier.gold,
  ),
  Achievement(
    id: 'level_10',
    title: 'Seasoned Researcher',
    description: 'Reach level 10.',
    emoji: '🌟',
    xpReward: 500,
    tier: AchievementTier.gold,
  ),

  // ------------------------------------------------------------- legendary
  Achievement(
    id: 'success_100',
    title: 'Nobel Material',
    description: 'Land 100 successful experiments.',
    emoji: '🏆',
    xpReward: 1200,
    tier: AchievementTier.legendary,
  ),
  Achievement(
    id: 'streak_10',
    title: 'Untouchable',
    description: 'Succeed ten experiments in a row.',
    emoji: '⚡',
    xpReward: 900,
    tier: AchievementTier.legendary,
  ),
  Achievement(
    id: 'level_20',
    title: 'Legend of the Lab',
    description: 'Reach level 20.',
    emoji: '💫',
    xpReward: 1500,
    tier: AchievementTier.legendary,
  ),
];

/// Looks up an achievement by [id], or returns `null` when unknown.
///
/// Unknown ids are expected — persisted saves may reference achievements that
/// were renamed or removed in a later build.
Achievement? achievementById(String id) {
  for (final a in kAchievements) {
    if (a.id == id) return a;
  }
  return null;
}
