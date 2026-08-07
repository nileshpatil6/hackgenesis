import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/component_data.dart';
import 'achievements.dart';
import 'quests.dart';

/// The player's progression: XP, levels, streaks, achievements and quests.
///
/// Register once near the root of the widget tree and call [load] at startup:
///
/// ```dart
/// final game = GameState();
/// await game.load();
/// runApp(ChangeNotifierProvider.value(value: game, child: const App()));
/// ```
///
/// Every `record*` hook returns the achievements that unlocked because of that
/// event so the caller can play one celebration per unlock. Call
/// [takePendingLevelUp] afterwards to find out whether the same event also
/// pushed the player into a new level.
class GameState extends ChangeNotifier {
  /// Creates an unloaded state. Values are defaults until [load] completes.
  GameState();

  // ------------------------------------------------------------ XP economy

  /// XP for dropping a component onto the canvas.
  static const int xpPerComponent = 5;

  /// XP for wiring two components together.
  static const int xpPerEdge = 8;

  /// XP for submitting an experiment for analysis, pass or fail.
  static const int xpPerRun = 15;

  /// Bonus XP when an experiment comes back successful.
  static const int xpPerSuccess = 60;

  /// XP for asking the lab assistant a question.
  static const int xpPerHint = 3;

  /// XP for loading a ready-made example.
  static const int xpPerExample = 10;

  /// XP for exporting an experiment.
  static const int xpPerExport = 12;

  /// Highest reachable level. XP keeps accruing past it; the bar stays full.
  static const int maxLevel = 99;

  // ---------------------------------------------------------- preference keys

  static const String _kXp = 'game_xp';
  static const String _kRuns = 'game_runs';
  static const String _kSuccess = 'game_success';
  static const String _kFail = 'game_fail';
  static const String _kComponents = 'game_components';
  static const String _kEdges = 'game_edges';
  static const String _kHints = 'game_hints';
  static const String _kExamples = 'game_examples';
  static const String _kExports = 'game_exports';
  static const String _kStreakCurrent = 'game_streak_current';
  static const String _kStreakBest = 'game_streak_best';
  static const String _kDayStreak = 'game_day_streak';
  static const String _kLastPlayed = 'game_last_played';
  static const String _kCategories = 'game_categories';
  static const String _kUnlocked = 'game_unlocked';
  static const String _kBestNodes = 'game_best_nodes';
  static const String _kBestEdges = 'game_best_edges';
  static const String _kQuestDay = 'game_quest_day';
  static const String _kDailyPlaced = 'game_daily_placed';
  static const String _kDailyEdges = 'game_daily_edges';
  static const String _kDailyRuns = 'game_daily_runs';
  static const String _kDailySuccess = 'game_daily_success';
  static const String _kDailyHints = 'game_daily_hints';
  static const String _kDailyCategories = 'game_daily_categories';
  static const String _kQuestsClaimed = 'game_quests_claimed';

  static const List<String> _allKeys = <String>[
    _kXp,
    _kRuns,
    _kSuccess,
    _kFail,
    _kComponents,
    _kEdges,
    _kHints,
    _kExamples,
    _kExports,
    _kStreakCurrent,
    _kStreakBest,
    _kDayStreak,
    _kLastPlayed,
    _kCategories,
    _kUnlocked,
    _kBestNodes,
    _kBestEdges,
    _kQuestDay,
    _kDailyPlaced,
    _kDailyEdges,
    _kDailyRuns,
    _kDailySuccess,
    _kDailyHints,
    _kDailyCategories,
    _kQuestsClaimed,
  ];

  // ------------------------------------------------------------------ state

  SharedPreferences? _prefs;
  bool _isLoaded = false;

  int _xp = 0;
  int _level = 1;
  int _xpIntoLevel = 0;

  int _experimentsRun = 0;
  int _successCount = 0;
  int _failCount = 0;
  int _componentsPlaced = 0;
  int _edgesConnected = 0;
  int _hintsAsked = 0;
  int _examplesLoaded = 0;
  int _exportsDone = 0;

  int _currentSuccessStreak = 0;
  int _bestSuccessStreak = 0;
  int _dayStreak = 0;

  int _largestGraphNodes = 0;
  int _largestGraphEdges = 0;

  final Set<String> _categoriesUsed = <String>{};
  final Set<String> _unlockedIds = <String>{};

  DateTime? _lastPlayed;
  DateTime? _currentDay;
  List<Quest> _todaysQuests = const <Quest>[];
  final Set<String> _claimedQuestIds = <String>{};

  int _dailyPlaced = 0;
  int _dailyEdges = 0;
  int _dailyRuns = 0;
  int _dailySuccess = 0;
  int _dailyHints = 0;
  final Set<String> _dailyCategories = <String>{};

  int? _pendingLevelUp;

  // ---------------------------------------------------------------- getters

  /// Lifetime XP earned across every session.
  int get xp => _xp;

  /// Current level, derived from [xp]. Starts at 1, capped at [maxLevel].
  int get level => _level;

  /// XP earned inside the current level.
  int get xpIntoLevel => _xpIntoLevel;

  /// Total XP span of the current level.
  int get xpForNextLevel => xpRequiredForLevel(_level);

  /// Progress through the current level, clamped to `0..1`.
  double get levelProgress {
    final span = xpForNextLevel;
    if (span <= 0) return 1;
    return (_xpIntoLevel / span).clamp(0.0, 1.0);
  }

  /// Flavour title for the current level, e.g. `Apprentice`.
  String get rankTitle => rankTitleForLevel(_level);

  /// Experiments submitted for analysis, pass or fail.
  int get experimentsRun => _experimentsRun;

  /// Experiments that came back successful.
  int get successCount => _successCount;

  /// Experiments that came back unsuccessful.
  int get failCount => _failCount;

  /// Components dropped onto the canvas, lifetime.
  int get componentsPlaced => _componentsPlaced;

  /// Edges wired between components, lifetime.
  int get edgesConnected => _edgesConnected;

  /// Questions asked of the lab assistant, lifetime.
  int get hintsAsked => _hintsAsked;

  /// Ready-made examples loaded, lifetime.
  int get examplesLoaded => _examplesLoaded;

  /// Experiments exported, lifetime.
  int get exportsDone => _exportsDone;

  /// Consecutive successful experiments right now. Any failure resets it.
  int get currentSuccessStreak => _currentSuccessStreak;

  /// Longest run of consecutive successes ever achieved.
  int get bestSuccessStreak => _bestSuccessStreak;

  /// Consecutive calendar days the player has opened the lab.
  int get dayStreak => _dayStreak;

  /// Node count of the largest graph ever submitted.
  int get largestGraphNodes => _largestGraphNodes;

  /// Edge count of the largest graph ever submitted.
  int get largestGraphEdges => _largestGraphEdges;

  /// Distinct [ComponentData.category] ids the player has ever placed.
  Set<String> get categoriesUsed =>
      UnmodifiableSetView<String>(_categoriesUsed);

  /// Unlocked achievements, resolved and kept in [kAchievements] order.
  List<Achievement> get unlocked => List<Achievement>.unmodifiable(
    kAchievements.where((a) => _unlockedIds.contains(a.id)),
  );

  /// Whether the achievement with [achievementId] has been unlocked.
  bool isUnlocked(String achievementId) => _unlockedIds.contains(achievementId);

  /// The three quests offered today. Empty until [load] completes.
  List<Quest> get todaysQuests => _todaysQuests;

  /// Progress toward [quest]'s target using today's counters.
  int questProgress(Quest quest) {
    switch (quest.type) {
      case QuestType.placeComponents:
        return math.min(_dailyPlaced, quest.targetCount);
      case QuestType.connectEdges:
        return math.min(_dailyEdges, quest.targetCount);
      case QuestType.runExperiments:
        return math.min(_dailyRuns, quest.targetCount);
      case QuestType.succeedExperiments:
        return math.min(_dailySuccess, quest.targetCount);
      case QuestType.useCategories:
        return math.min(_dailyCategories.length, quest.targetCount);
      case QuestType.askHints:
        return math.min(_dailyHints, quest.targetCount);
    }
  }

  /// Whether [quest] has hit its target today.
  bool isQuestComplete(Quest quest) =>
      questProgress(quest) >= quest.targetCount;

  /// Whether [load] has completed.
  bool get isLoaded => _isLoaded;

  // ------------------------------------------------------------ level curve

  /// XP span of [level] — how much XP it takes to go from [level] to the next.
  ///
  /// Grows as `100 * level^1.35`, so early levels arrive fast and later ones
  /// take real work. Returns `0` for levels below 1.
  static int xpRequiredForLevel(int level) {
    if (level < 1) return 0;
    return (100 * math.pow(level, 1.35)).round();
  }

  /// Total lifetime XP needed to *reach* [level] from zero.
  static int totalXpForLevel(int level) {
    var total = 0;
    for (var i = 1; i < level; i++) {
      total += xpRequiredForLevel(i);
    }
    return total;
  }

  /// Flavour title for [level].
  static String rankTitleForLevel(int level) {
    if (level >= 65) return 'Grand Theorist';
    if (level >= 45) return 'Luminary';
    if (level >= 30) return 'Professor';
    if (level >= 20) return 'Lead Investigator';
    if (level >= 15) return 'Senior Scientist';
    if (level >= 11) return 'Scientist';
    if (level >= 8) return 'Researcher';
    if (level >= 5) return 'Technician';
    if (level >= 3) return 'Apprentice';
    return 'Novice';
  }

  // --------------------------------------------------------------- lifecycle

  /// Reads persisted progression, then rolls the day streak and daily quests.
  ///
  /// Safe to call more than once. Achievements that became true while the app
  /// was closed (a day streak, for instance) unlock silently here.
  Future<void> load() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();

    _xp = prefs.getInt(_kXp) ?? 0;
    _experimentsRun = prefs.getInt(_kRuns) ?? 0;
    _successCount = prefs.getInt(_kSuccess) ?? 0;
    _failCount = prefs.getInt(_kFail) ?? 0;
    _componentsPlaced = prefs.getInt(_kComponents) ?? 0;
    _edgesConnected = prefs.getInt(_kEdges) ?? 0;
    _hintsAsked = prefs.getInt(_kHints) ?? 0;
    _examplesLoaded = prefs.getInt(_kExamples) ?? 0;
    _exportsDone = prefs.getInt(_kExports) ?? 0;
    _currentSuccessStreak = prefs.getInt(_kStreakCurrent) ?? 0;
    _bestSuccessStreak = prefs.getInt(_kStreakBest) ?? 0;
    _dayStreak = prefs.getInt(_kDayStreak) ?? 0;
    _largestGraphNodes = prefs.getInt(_kBestNodes) ?? 0;
    _largestGraphEdges = prefs.getInt(_kBestEdges) ?? 0;

    _categoriesUsed
      ..clear()
      ..addAll(prefs.getStringList(_kCategories) ?? const <String>[]);
    _unlockedIds
      ..clear()
      ..addAll(prefs.getStringList(_kUnlocked) ?? const <String>[]);

    _lastPlayed = _parseDay(prefs.getString(_kLastPlayed));
    _currentDay = _parseDay(prefs.getString(_kQuestDay));

    _dailyPlaced = prefs.getInt(_kDailyPlaced) ?? 0;
    _dailyEdges = prefs.getInt(_kDailyEdges) ?? 0;
    _dailyRuns = prefs.getInt(_kDailyRuns) ?? 0;
    _dailySuccess = prefs.getInt(_kDailySuccess) ?? 0;
    _dailyHints = prefs.getInt(_kDailyHints) ?? 0;
    _dailyCategories
      ..clear()
      ..addAll(prefs.getStringList(_kDailyCategories) ?? const <String>[]);
    _claimedQuestIds
      ..clear()
      ..addAll(prefs.getStringList(_kQuestsClaimed) ?? const <String>[]);

    _recomputeLevel();
    _rollDayIfNeeded();

    _isLoaded = true;
    await _commit(0);
  }

  /// Wipes every `game_` key and returns the player to level 1.
  Future<void> reset() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    for (final key in _allKeys) {
      await prefs.remove(key);
    }

    _xp = 0;
    _experimentsRun = 0;
    _successCount = 0;
    _failCount = 0;
    _componentsPlaced = 0;
    _edgesConnected = 0;
    _hintsAsked = 0;
    _examplesLoaded = 0;
    _exportsDone = 0;
    _currentSuccessStreak = 0;
    _bestSuccessStreak = 0;
    _dayStreak = 0;
    _largestGraphNodes = 0;
    _largestGraphEdges = 0;
    _categoriesUsed.clear();
    _unlockedIds.clear();
    _claimedQuestIds.clear();
    _dailyPlaced = 0;
    _dailyEdges = 0;
    _dailyRuns = 0;
    _dailySuccess = 0;
    _dailyHints = 0;
    _dailyCategories.clear();
    _lastPlayed = null;
    _currentDay = null;
    _pendingLevelUp = null;

    _recomputeLevel();
    _rollDayIfNeeded();
    await _persist();
    notifyListeners();
  }

  // ------------------------------------------------------------ event hooks

  /// Records a component drop and returns any achievements it unlocked.
  Future<List<Achievement>> recordComponentPlaced(ComponentData component) {
    _rollDayIfNeeded();
    _componentsPlaced++;
    _dailyPlaced++;
    final category = component.category.trim();
    if (category.isNotEmpty) {
      _categoriesUsed.add(category);
      _dailyCategories.add(category);
    }
    return _commit(xpPerComponent);
  }

  /// Records a new connection between two components.
  Future<List<Achievement>> recordEdgeConnected() {
    _rollDayIfNeeded();
    _edgesConnected++;
    _dailyEdges++;
    return _commit(xpPerEdge);
  }

  /// Records a question asked of the lab assistant.
  Future<List<Achievement>> recordHintAsked() {
    _rollDayIfNeeded();
    _hintsAsked++;
    _dailyHints++;
    return _commit(xpPerHint);
  }

  /// Records loading a ready-made example experiment.
  Future<List<Achievement>> recordExampleLoaded() {
    _rollDayIfNeeded();
    _examplesLoaded++;
    return _commit(xpPerExample);
  }

  /// Records exporting an experiment out of the app.
  Future<List<Achievement>> recordExported() {
    _rollDayIfNeeded();
    _exportsDone++;
    return _commit(xpPerExport);
  }

  /// Records an analysed experiment.
  ///
  /// [nodeCount] and [edgeCount] describe the submitted graph and feed the
  /// "big build" achievements; they are not added to the lifetime placement
  /// counters, which only move on real place/connect events.
  Future<List<Achievement>> recordExperimentRun({
    required bool success,
    required int nodeCount,
    required int edgeCount,
  }) {
    _rollDayIfNeeded();
    _experimentsRun++;
    _dailyRuns++;
    if (success) {
      _successCount++;
      _dailySuccess++;
      _currentSuccessStreak++;
      if (_currentSuccessStreak > _bestSuccessStreak) {
        _bestSuccessStreak = _currentSuccessStreak;
      }
    } else {
      _failCount++;
      _currentSuccessStreak = 0;
    }
    if (nodeCount > _largestGraphNodes) _largestGraphNodes = nodeCount;
    if (edgeCount > _largestGraphEdges) _largestGraphEdges = edgeCount;

    return _commit(xpPerRun + (success ? xpPerSuccess : 0));
  }

  /// Returns the level reached by the most recent XP award, clearing it.
  ///
  /// Returns `null` when the last award did not cross a level boundary.
  int? takePendingLevelUp() {
    final pending = _pendingLevelUp;
    _pendingLevelUp = null;
    return pending;
  }

  // --------------------------------------------------------------- internals

  /// Applies [baseXp], settles quest and achievement rewards, then persists.
  Future<List<Achievement>> _commit(int baseXp) async {
    final levelBefore = _level;

    if (baseXp > 0) _addXp(baseXp);
    _addXp(_claimCompletedQuests());

    final newly = <Achievement>[];
    // Achievement XP can trigger a level achievement, which grants more XP;
    // settle in a bounded loop rather than recursing.
    for (var pass = 0; pass < 8; pass++) {
      final ids = _newlySatisfiedIds();
      if (ids.isEmpty) break;
      for (final id in ids) {
        _unlockedIds.add(id);
        final achievement = achievementById(id);
        if (achievement == null) continue;
        newly.add(achievement);
        _addXp(achievement.xpReward);
      }
    }

    if (_level > levelBefore) _pendingLevelUp = _level;

    await _persist();
    notifyListeners();
    return newly;
  }

  void _addXp(int amount) {
    if (amount <= 0) return;
    _xp += amount;
    _recomputeLevel();
  }

  void _recomputeLevel() {
    var level = 1;
    var remaining = _xp;
    while (level < maxLevel) {
      final need = xpRequiredForLevel(level);
      if (remaining < need) break;
      remaining -= need;
      level++;
    }
    _level = level;
    _xpIntoLevel = level >= maxLevel ? xpRequiredForLevel(maxLevel) : remaining;
  }

  /// Awards XP for quests that finished today and have not been paid out yet.
  int _claimCompletedQuests() {
    var reward = 0;
    for (final quest in _todaysQuests) {
      if (_claimedQuestIds.contains(quest.id)) continue;
      if (!isQuestComplete(quest)) continue;
      _claimedQuestIds.add(quest.id);
      reward += quest.xpReward;
    }
    return reward;
  }

  /// Ids of achievements whose condition now holds but are still locked.
  List<String> _newlySatisfiedIds() {
    final ids = <String>[];
    for (final achievement in kAchievements) {
      if (_unlockedIds.contains(achievement.id)) continue;
      if (_isSatisfied(achievement.id)) ids.add(achievement.id);
    }
    return ids;
  }

  bool _isSatisfied(String id) {
    switch (id) {
      case 'first_component':
        return _componentsPlaced >= 1;
      case 'first_edge':
        return _edgesConnected >= 1;
      case 'first_run':
        return _experimentsRun >= 1;
      case 'first_success':
        return _successCount >= 1;
      case 'first_failure':
        return _failCount >= 1;
      case 'first_hint':
        return _hintsAsked >= 1;
      case 'first_example':
        return _examplesLoaded >= 1;
      case 'first_export':
        return _exportsDone >= 1;
      case 'success_5':
        return _successCount >= 5;
      case 'success_25':
        return _successCount >= 25;
      case 'success_100':
        return _successCount >= 100;
      case 'components_50':
        return _componentsPlaced >= 50;
      case 'edges_15':
        return _edgesConnected >= 15;
      case 'graph_10_nodes':
        return _largestGraphNodes >= 10;
      case 'categories_5':
        return _categoriesUsed.length >= 5;
      case 'categories_all':
        return _categoriesUsed.length >= kCategorySweepTarget;
      case 'streak_3':
        return _bestSuccessStreak >= 3;
      case 'streak_10':
        return _bestSuccessStreak >= 10;
      case 'hints_10':
        return _hintsAsked >= 10;
      case 'runs_50':
        return _experimentsRun >= 50;
      case 'day_streak_7':
        return _dayStreak >= 7;
      case 'level_5':
        return _level >= 5;
      case 'level_10':
        return _level >= 10;
      case 'level_20':
        return _level >= 20;
      default:
        return false;
    }
  }

  /// Advances the day streak and clears the daily counters when the calendar
  /// date has changed. Always refreshes [todaysQuests].
  ///
  /// Returns `true` when a new day was rolled.
  bool _rollDayIfNeeded() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rolled = _currentDay != today;

    if (rolled) {
      final last = _lastPlayed;
      if (last == null) {
        _dayStreak = 1;
      } else {
        final gap = today.difference(last).inDays;
        if (gap == 1) {
          _dayStreak += 1;
        } else if (gap != 0) {
          _dayStreak = 1;
        }
      }
      if (_dayStreak < 1) _dayStreak = 1;

      _lastPlayed = today;
      _currentDay = today;
      _dailyPlaced = 0;
      _dailyEdges = 0;
      _dailyRuns = 0;
      _dailySuccess = 0;
      _dailyHints = 0;
      _dailyCategories.clear();
      _claimedQuestIds.clear();
    }

    _todaysQuests = questsForDay(today);
    return rolled;
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;

    await prefs.setInt(_kXp, _xp);
    await prefs.setInt(_kRuns, _experimentsRun);
    await prefs.setInt(_kSuccess, _successCount);
    await prefs.setInt(_kFail, _failCount);
    await prefs.setInt(_kComponents, _componentsPlaced);
    await prefs.setInt(_kEdges, _edgesConnected);
    await prefs.setInt(_kHints, _hintsAsked);
    await prefs.setInt(_kExamples, _examplesLoaded);
    await prefs.setInt(_kExports, _exportsDone);
    await prefs.setInt(_kStreakCurrent, _currentSuccessStreak);
    await prefs.setInt(_kStreakBest, _bestSuccessStreak);
    await prefs.setInt(_kDayStreak, _dayStreak);
    await prefs.setInt(_kBestNodes, _largestGraphNodes);
    await prefs.setInt(_kBestEdges, _largestGraphEdges);
    await prefs.setStringList(_kCategories, _categoriesUsed.toList());
    await prefs.setStringList(_kUnlocked, _unlockedIds.toList());

    final last = _lastPlayed;
    if (last != null) await prefs.setString(_kLastPlayed, _formatDay(last));
    final day = _currentDay;
    if (day != null) await prefs.setString(_kQuestDay, _formatDay(day));

    await prefs.setInt(_kDailyPlaced, _dailyPlaced);
    await prefs.setInt(_kDailyEdges, _dailyEdges);
    await prefs.setInt(_kDailyRuns, _dailyRuns);
    await prefs.setInt(_kDailySuccess, _dailySuccess);
    await prefs.setInt(_kDailyHints, _dailyHints);
    await prefs.setStringList(_kDailyCategories, _dailyCategories.toList());
    await prefs.setStringList(_kQuestsClaimed, _claimedQuestIds.toList());
  }

  static String _formatDay(DateTime day) {
    final month = day.month.toString().padLeft(2, '0');
    final dayOfMonth = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$dayOfMonth';
  }

  static DateTime? _parseDay(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
}
