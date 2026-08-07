import 'package:flutter/foundation.dart';

/// The kind of activity a [Quest] tracks.
///
/// Each value maps to one daily counter inside `GameState`.
enum QuestType {
  /// Components dropped onto the canvas today.
  placeComponents,

  /// Edges wired between components today.
  connectEdges,

  /// Experiments submitted for analysis today.
  runExperiments,

  /// Experiments that came back successful today.
  succeedExperiments,

  /// Distinct component categories used today.
  useCategories,

  /// Questions asked of the lab assistant today.
  askHints,
}

/// Short, countable objective that gives a session direction.
///
/// Quests are pure data. Progress lives in `GameState`, which resets the
/// daily counters at midnight and awards [xpReward] once per completion.
@immutable
class Quest {
  /// Creates a quest definition.
  const Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.targetCount,
    required this.xpReward,
    required this.type,
  });

  /// Stable identifier persisted with the day's claim record.
  final String id;

  /// Short headline shown in the quest list.
  final String title;

  /// One-line explanation of what to do.
  final String description;

  /// Single glyph shown beside the title.
  final String emoji;

  /// How many [type] events complete the quest.
  final int targetCount;

  /// XP granted the first time the quest completes on a given day.
  final int xpReward;

  /// Which daily counter this quest reads.
  final QuestType type;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Quest && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Every quest the daily rotation can draw from.
const List<Quest> kQuestPool = <Quest>[
  Quest(
    id: 'q_place_5',
    title: 'Stock the Bench',
    description: 'Place 5 components on the canvas.',
    emoji: '🧰',
    targetCount: 5,
    xpReward: 40,
    type: QuestType.placeComponents,
  ),
  Quest(
    id: 'q_place_12',
    title: 'Build It Big',
    description: 'Place 12 components on the canvas.',
    emoji: '🏗️',
    targetCount: 12,
    xpReward: 90,
    type: QuestType.placeComponents,
  ),
  Quest(
    id: 'q_edges_4',
    title: 'Close the Circuit',
    description: 'Connect 4 components together.',
    emoji: '🔗',
    targetCount: 4,
    xpReward: 45,
    type: QuestType.connectEdges,
  ),
  Quest(
    id: 'q_edges_10',
    title: 'Tangled Web',
    description: 'Wire up 10 connections.',
    emoji: '🕸️',
    targetCount: 10,
    xpReward: 95,
    type: QuestType.connectEdges,
  ),
  Quest(
    id: 'q_run_2',
    title: 'Warm Up',
    description: 'Run 2 experiments.',
    emoji: '🔌',
    targetCount: 2,
    xpReward: 50,
    type: QuestType.runExperiments,
  ),
  Quest(
    id: 'q_run_5',
    title: 'Full Shift',
    description: 'Run 5 experiments.',
    emoji: '⏱️',
    targetCount: 5,
    xpReward: 110,
    type: QuestType.runExperiments,
  ),
  Quest(
    id: 'q_success_1',
    title: 'Make It Work',
    description: 'Get one experiment to succeed.',
    emoji: '✅',
    targetCount: 1,
    xpReward: 60,
    type: QuestType.succeedExperiments,
  ),
  Quest(
    id: 'q_success_3',
    title: 'Triple Threat',
    description: 'Land 3 successful experiments.',
    emoji: '🎯',
    targetCount: 3,
    xpReward: 140,
    type: QuestType.succeedExperiments,
  ),
  Quest(
    id: 'q_categories_3',
    title: 'Mix It Up',
    description: 'Use 3 different component categories.',
    emoji: '🌈',
    targetCount: 3,
    xpReward: 70,
    type: QuestType.useCategories,
  ),
  Quest(
    id: 'q_categories_5',
    title: 'Interdisciplinary',
    description: 'Use 5 different component categories.',
    emoji: '🌐',
    targetCount: 5,
    xpReward: 130,
    type: QuestType.useCategories,
  ),
  Quest(
    id: 'q_hints_1',
    title: 'Second Opinion',
    description: 'Ask the lab assistant for a hint.',
    emoji: '🤖',
    targetCount: 1,
    xpReward: 35,
    type: QuestType.askHints,
  ),
  Quest(
    id: 'q_hints_3',
    title: 'Pick Its Brain',
    description: 'Ask the assistant 3 questions.',
    emoji: '💡',
    targetCount: 3,
    xpReward: 80,
    type: QuestType.askHints,
  ),
];

/// Picks the quests for [day] — the same calendar date always yields the same
/// list, on every device, with no persistence needed.
///
/// At most one quest per [QuestType] is chosen so the set stays varied. If
/// [count] exceeds the number of distinct types, the extra slots are filled
/// with the remaining quests in deterministic order.
List<Quest> questsForDay(DateTime day, {int count = 3}) {
  if (count <= 0 || kQuestPool.isEmpty) return const <Quest>[];

  final seed = day.year * 10000 + day.month * 100 + day.day;
  final order = _shuffledIndices(kQuestPool.length, seed);

  final picked = <Quest>[];
  final usedTypes = <QuestType>{};

  for (final i in order) {
    if (picked.length >= count) break;
    final quest = kQuestPool[i];
    if (usedTypes.add(quest.type)) picked.add(quest);
  }

  // Backfill when the pool has fewer distinct types than requested.
  for (final i in order) {
    if (picked.length >= count) break;
    final quest = kQuestPool[i];
    if (!picked.contains(quest)) picked.add(quest);
  }

  return List<Quest>.unmodifiable(picked);
}

/// Deterministic Fisher-Yates over `0..length-1` driven by a tiny LCG.
List<int> _shuffledIndices(int length, int seed) {
  final indices = List<int>.generate(length, (i) => i);
  var state = (seed * 1664525 + 1013904223) & 0x7FFFFFFF;
  for (var i = length - 1; i > 0; i--) {
    state = (state * 1664525 + 1013904223) & 0x7FFFFFFF;
    final j = state % (i + 1);
    final tmp = indices[i];
    indices[i] = indices[j];
    indices[j] = tmp;
  }
  return indices;
}
