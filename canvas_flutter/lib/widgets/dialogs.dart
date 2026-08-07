import 'package:flutter/material.dart';

import '../data/example_experiments.dart';
import '../game/achievements.dart';
import '../game/game_state.dart';
import '../game/quests.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';

/// Prompts for the user's OpenAI API key.
///
/// The key is supplied by the player at runtime and stored on-device — it is
/// never baked into the build.
class ApiKeyDialog extends StatefulWidget {
  const ApiKeyDialog({super.key, required this.settings});

  final SettingsStore settings;

  static Future<bool?> show(BuildContext context, SettingsStore settings) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ApiKeyDialog(settings: settings),
    );
  }

  @override
  State<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<ApiKeyDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.settings.apiKey ?? '',
  );
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(
        () => _error = 'Enter a key, or cancel to keep playing offline.',
      );
      return;
    }
    if (!SettingsStore.looksLikeApiKey(value)) {
      setState(
        () => _error = 'That does not look like an OpenAI key (starts "sk-").',
      );
      return;
    }
    await widget.settings.setApiKey(value);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.vpn_key_outlined, size: 20, color: AppColors.primary),
          SizedBox(width: 10),
          Text('OpenAI API Key'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your key is stored only on this device and is sent straight to '
              'OpenAI when you run an experiment or ask for a hint.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              autofocus: true,
              onSubmitted: (_) => _save(),
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'sk-…',
                errorText: _error,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  color: AppColors.textMuted,
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Get one at platform.openai.com/api-keys',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.settings.hasApiKey)
          TextButton(
            onPressed: () async {
              await widget.settings.clearApiKey();
              if (!context.mounted) return;
              Navigator.of(context).pop(false);
            },
            child: const Text(
              'Remove key',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save key')),
      ],
    );
  }
}

/// First-run explainer.
class WelcomeDialog extends StatelessWidget {
  const WelcomeDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const WelcomeDialog(),
    );
  }

  static const _steps = <(IconData, String, String)>[
    (
      Icons.widgets_outlined,
      'Tap components in',
      'Pick from 300+ parts on the left.',
    ),
    (
      Icons.timeline,
      'Wire them together',
      'Drag from a node\'s right dot to another.',
    ),
    (
      Icons.play_arrow_rounded,
      'Run the experiment',
      'The AI simulates it and scores your build.',
    ),
    (
      Icons.military_tech_outlined,
      'Level up',
      'Earn XP, unlock achievements, keep your streak.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.science_outlined, size: 22, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(child: Text('Welcome to the Lab')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Build any experiment you can imagine, then let the AI tell you '
              'what would actually happen.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            for (final (icon, title, body) in _steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            body,
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.4,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Start building'),
        ),
      ],
    );
  }
}

/// Picker for the bundled starter experiments.
class ExamplesDialog extends StatelessWidget {
  const ExamplesDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const ExamplesDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.auto_stories_outlined, size: 20, color: AppColors.primary),
          SizedBox(width: 10),
          Text('Load an example'),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'This replaces whatever is on the canvas.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 14),
            for (final ex in kExampleExperiments)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(ex.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ex.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ex.category,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Asks for a label to put on a connection.
Future<String?> showEdgeLabelDialog(BuildContext context, String? current) {
  final controller = TextEditingController(text: current ?? '');
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Label this connection'),
      content: TextField(
        controller: controller,
        autofocus: true,
        onSubmitted: (v) => Navigator.of(context).pop(v),
        decoration: const InputDecoration(
          hintText: 'e.g. +5V, 22.7mA, if true',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Apply'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// Progress hub: level, quests and the achievement wall.
class ProgressSheet extends StatelessWidget {
  const ProgressSheet({super.key, required this.game});

  final GameState game;

  static Future<void> show(BuildContext context, GameState game) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ProgressSheet(game: game),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: ListenableBuilder(
            listenable: game,
            builder: (context, _) => ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildLevelHeader(),
                const SizedBox(height: 24),
                _buildSectionTitle(Icons.flag_outlined, 'Today\'s quests'),
                const SizedBox(height: 10),
                for (final q in game.todaysQuests) _buildQuest(q),
                const SizedBox(height: 22),
                _buildSectionTitle(Icons.insights_outlined, 'Stats'),
                const SizedBox(height: 10),
                _buildStats(),
                const SizedBox(height: 22),
                _buildSectionTitle(
                  Icons.military_tech_outlined,
                  'Achievements  '
                  '${game.unlocked.length}/${kAchievements.length}',
                ),
                const SizedBox(height: 10),
                _buildAchievementGrid(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 15, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: AppColors.textPrimary,
        ),
      ),
    ],
  );

  Widget _buildLevelHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${game.level}',
                  style: const TextStyle(
                    fontSize: 21,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Text(
                  'LVL',
                  style: TextStyle(
                    fontSize: 8,
                    letterSpacing: 1,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.rankTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: game.levelProgress,
                    minHeight: 8,
                    backgroundColor: AppColors.background,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${game.xpIntoLevel} / ${game.xpForNextLevel} XP'
                  '${game.dayStreak > 1 ? '   •   🔥 ${game.dayStreak}-day streak' : ''}',
                  style: const TextStyle(
                    fontSize: 11.5,
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

  Widget _buildQuest(Quest quest) {
    final progress = game.questProgress(quest);
    final done = game.isQuestComplete(quest);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done ? AppColors.success : AppColors.border,
          width: done ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Text(done ? '✅' : quest.emoji, style: const TextStyle(fontSize: 17)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest.title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: done ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  quest.description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (progress / quest.targetCount).clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: AppColors.background,
                    color: done ? AppColors.success : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Text(
                '$progress/${quest.targetCount}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '+${quest.xpReward}',
                style: const TextStyle(fontSize: 10, color: AppColors.warning),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final stats = <(IconData, String, String)>[
      (Icons.science_outlined, 'Experiments', '${game.experimentsRun}'),
      (Icons.check_circle_outline, 'Successes', '${game.successCount}'),
      (Icons.widgets_outlined, 'Components', '${game.componentsPlaced}'),
      (Icons.timeline, 'Connections', '${game.edgesConnected}'),
      (Icons.bolt_outlined, 'Best streak', '${game.bestSuccessStreak}'),
      (Icons.category_outlined, 'Fields used', '${game.categoriesUsed.length}'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (icon, label, value) in stats)
          Container(
            width: 108,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAchievementGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in kAchievements)
          _AchievementBadge(achievement: a, unlocked: game.isUnlocked(a.id)),
      ],
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  const _AchievementBadge({required this.achievement, required this.unlocked});

  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final tint = achievement.tier.color;
    return Tooltip(
      message: unlocked
          ? '${achievement.title}\n${achievement.description}'
          : 'Locked — ${achievement.description}',
      child: Container(
        width: 104,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: unlocked
              ? tint.withValues(alpha: 0.14)
              : AppColors.surfaceAlt.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: unlocked ? tint.withValues(alpha: 0.6) : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Opacity(
              opacity: unlocked ? 1 : 0.25,
              child: Text(
                achievement.emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              achievement.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: unlocked ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
