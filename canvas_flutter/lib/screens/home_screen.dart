import 'dart:convert';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../canvas/canvas_controller.dart';
import '../canvas/canvas_view.dart';
import '../data/example_experiments.dart';
import '../game/achievements.dart';
import '../game/game_state.dart';
import '../game/waiting_quiz.dart';
import '../models/component_data.dart';
import '../models/experiment.dart';
import '../services/openai_service.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import '../widgets/assistant_panel.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/component_library_panel.dart';
import '../widgets/dialogs.dart';
import '../widgets/result_sheet.dart';
import '../widgets/xp_bar.dart';

/// The single screen of the app: component palette, canvas, and assistant.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _wideBreakpoint = 1000.0;

  /// Below this width the app bar's leading drawer button leaves too little
  /// room for the XP bar alongside four separate action icons, so the two
  /// least-used ones (load example, export JSON) collapse into an overflow
  /// menu instead of overflowing the title row.
  static const _compactActionsBreakpoint = 640.0;

  final _controller = CanvasController();
  final _confetti = ConfettiController(duration: const Duration(seconds: 2));
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _canvasKey = GlobalKey();

  /// Node ids already credited to the player, so undo/redo and example loads
  /// do not re-award XP for the same work.
  final _creditedNodeIds = <String>{};
  final _creditedEdgeIds = <String>{};

  final _chat = <ChatMessage>[
    ChatMessage(
      isUser: false,
      content:
          "👋 Hi! I'm your lab assistant! I can help you with hints about "
          'your experiment. What would you like to know?',
      timestamp: DateTime.now(),
    ),
  ];

  bool _assistantOpen = false;
  bool _assistantLoading = false;

  /// Live state of the current experiment run.
  ///
  /// The result sheet is a separate modal route, so a `setState` here would
  /// never reach it — it listens to this notifier instead.
  final _run = ValueNotifier<ExperimentRun>(const ExperimentRun());

  /// Questions shown while the current run is in flight, matched to the
  /// domains the player built with.
  List<QuizQuestion> _quiz = const <QuizQuestion>[];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onCanvasChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowWelcome());
  }

  @override
  void dispose() {
    _controller.removeListener(_onCanvasChanged);
    _controller.dispose();
    _confetti.dispose();
    _run.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- lifecycle

  Future<void> _maybeShowWelcome() async {
    final settings = context.read<SettingsStore>();
    if (settings.hasSeenWelcome) return;
    await WelcomeDialog.show(context);
    await settings.markWelcomeSeen();
  }

  /// Credits XP for genuinely new nodes and edges.
  void _onCanvasChanged() {
    final game = context.read<GameState>();

    final nodeIds = _controller.nodes.map((n) => n.id).toSet();
    final newNodes = _controller.nodes
        .where((n) => !_creditedNodeIds.contains(n.id))
        .toList();
    final edgeIds = _controller.edges.map((e) => e.id).toSet();
    final newEdges = _controller.edges
        .where((e) => !_creditedEdgeIds.contains(e.id))
        .length;

    _creditedNodeIds
      ..retainAll(nodeIds)
      ..addAll(nodeIds);
    _creditedEdgeIds
      ..retainAll(edgeIds)
      ..addAll(edgeIds);

    // Only reward incremental building, not bulk example loads.
    if (newNodes.length == 1) {
      _award(() => game.recordComponentPlaced(newNodes.first.component));
    }
    if (newEdges == 1) {
      _award(game.recordEdgeConnected);
    }
  }

  /// Runs a [GameState] event and surfaces any unlocks it produced.
  Future<void> _award(Future<List<Achievement>> Function() event) async {
    final unlocked = await event();
    if (!mounted) return;

    final game = context.read<GameState>();
    final levelUp = game.takePendingLevelUp();
    if (levelUp != null) {
      _confetti.play();
      await showGameToast(
        context,
        LevelUpToast(level: levelUp, rankTitle: game.rankTitle),
      );
    }
    for (final a in unlocked) {
      if (!mounted) return;
      await showGameToast(context, AchievementToast(achievement: a));
    }
  }

  // ------------------------------------------------------------------ actions

  /// Ensures a key is present, prompting for one when it is not.
  Future<bool> _ensureApiKey() async {
    final settings = context.read<SettingsStore>();
    if (settings.hasApiKey) return true;
    final saved = await ApiKeyDialog.show(context, settings);
    return saved == true;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Drops a component in the middle of the visible canvas.
  void _quickAdd(ComponentData component) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final center = box == null
        ? const Offset(200, 200)
        : _controller.screenToWorld(
            Offset(box.size.width / 2, box.size.height / 2),
          );
    // Nudge each drop so stacked quick-adds stay readable.
    final jitter = Offset(
      (_controller.nodes.length % 5) * 26.0 - 52,
      (_controller.nodes.length % 3) * 26.0 - 26,
    );
    _controller.addComponent(component, center + jitter);
  }

  Future<void> _runExperiment() async {
    if (_controller.isEmpty) {
      _toast('Add some components to your experiment first!');
      return;
    }
    if (!await _ensureApiKey()) return;
    if (!mounted) return;

    final service = context.read<OpenAiService>();
    final experiment = _controller.toExperiment();

    // Quiz the player on the fields they actually built with, so the wait
    // feels like part of the lab. Entirely local — no extra API load.
    _quiz = quizForCategories(
      experiment.nodes.map((n) => n.component.category),
    );

    _run.value = const ExperimentRun(isAnalyzing: true, isRenderingImage: true);
    _showResultSheet();

    // Both requests go out together. The illustration is prompted from the
    // graph itself (see buildExperimentImagePrompt), so it does not have to
    // wait for the verdict — total time is the slower of the two, not the sum.
    // _safeGenerateImage never throws, so this future is safe to leave
    // in flight while we await the analysis.
    final imageFuture = _safeGenerateImage(
      service,
      buildExperimentImagePrompt(experiment),
    );
    final result = await service.analyzeExperiment(experiment);
    final image = await imageFuture;

    if (!mounted) return;

    // Reveal everything in one go: the quiz covers the wait, so there is no
    // reason to show a half-finished result and then shuffle it about.
    _run.value = ExperimentRun(
      result: result,
      imageBytes: image.bytes,
      imageError: image.error,
    );

    if (result.success) _confetti.play();

    await _award(
      () => context.read<GameState>().recordExperimentRun(
        success: result.success,
        nodeCount: experiment.nodes.length,
        edgeCount: experiment.edges.length,
      ),
    );
  }

  /// Renders [prompt] into image bytes, converting every failure into a
  /// message instead of an exception so the caller can start it early and
  /// await it later without risking an unhandled async error.
  Future<({Uint8List? bytes, String? error})> _safeGenerateImage(
    OpenAiService service,
    String prompt,
  ) async {
    try {
      return (bytes: await service.generateImage(prompt), error: null);
    } on OpenAiException catch (e) {
      return (bytes: null, error: e.message);
    } catch (_) {
      return (bytes: null, error: 'The illustration could not be rendered.');
    }
  }

  void _showResultSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (sheetContext) => ResultSheet(
        run: _run,
        questions: _quiz,
        onClose: () => Navigator.of(sheetContext).pop(),
        onRetry: () {
          Navigator.of(sheetContext).pop();
          _runExperiment();
        },
      ),
    );
  }

  Future<void> _sendHint(String question) async {
    if (!await _ensureApiKey()) return;
    if (!mounted) return;

    setState(() {
      _chat.add(
        ChatMessage(isUser: true, content: question, timestamp: DateTime.now()),
      );
      _assistantLoading = true;
    });

    final service = context.read<OpenAiService>();
    String reply;
    try {
      reply = await service.getHint(_controller.toExperiment(), question);
    } on OpenAiException catch (e) {
      reply = '⚠️ ${e.message}';
    } catch (e) {
      reply = '⚠️ Something went wrong reaching the assistant.';
    }

    if (!mounted) return;
    setState(() {
      _chat.add(
        ChatMessage(isUser: false, content: reply, timestamp: DateTime.now()),
      );
      _assistantLoading = false;
    });

    await _award(context.read<GameState>().recordHintAsked);
  }

  Future<void> _loadExample() async {
    final id = await ExamplesDialog.show(context);
    if (id == null || !mounted) return;
    final experiment = buildExample(id);
    if (experiment == null) return;

    _controller.loadExperiment(experiment);
    // Bulk loads are not player-built, so credit them without XP per node.
    _creditedNodeIds.addAll(_controller.nodes.map((n) => n.id));
    _creditedEdgeIds.addAll(_controller.edges.map((e) => e.id));

    await _award(context.read<GameState>().recordExampleLoaded);
  }

  Future<void> _exportJson() async {
    if (_controller.isEmpty) {
      _toast('Nothing to export yet — build something first!');
      return;
    }
    final encoded = const JsonEncoder.withIndent(
      '  ',
    ).convert(_controller.toExperiment().toJson());
    await Clipboard.setData(ClipboardData(text: encoded));
    if (!mounted) return;
    _toast('Experiment JSON copied to clipboard 📋');
    await _award(context.read<GameState>().recordExported);
  }

  Future<void> _clearCanvas() async {
    if (_controller.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear the canvas?'),
        content: const Text(
          'This removes every component and connection. You can still undo it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep building'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) _controller.clear();
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        return Scaffold(
          key: _scaffoldKey,
          appBar: _buildAppBar(isWide, constraints.maxWidth),
          drawer: isWide
              ? null
              : Drawer(
                  width: 300,
                  backgroundColor: AppColors.surface,
                  child: SafeArea(child: _buildLibrary()),
                ),
          endDrawer: isWide
              ? null
              : Drawer(
                  width: 340,
                  backgroundColor: AppColors.surface,
                  child: SafeArea(child: _buildAssistant()),
                ),
          body: CelebrationOverlay(
            controller: _confetti,
            child: Row(
              children: [
                if (isWide) SizedBox(width: 280, child: _buildLibrary()),
                Expanded(child: _buildCanvasArea()),
                if (isWide && _assistantOpen)
                  SizedBox(width: 340, child: _buildAssistant()),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(bool isWide, double width) {
    final game = context.watch<GameState>();
    final bool compactActions = width < _compactActionsBreakpoint;

    return AppBar(
      titleSpacing: isWide ? 20 : 0,
      title: Row(
        children: [
          if (isWide) ...[
            const Icon(
              Icons.science_outlined,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            const Text(
              'AI Experiment Lab',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 20),
          ],
          Flexible(
            child: InkWell(
              onTap: () => ProgressSheet.show(context, game),
              borderRadius: BorderRadius.circular(12),
              child: XpBar(
                level: game.level,
                rankTitle: game.rankTitle,
                progress: game.levelProgress,
                xpIntoLevel: game.xpIntoLevel,
                xpForNextLevel: game.xpForNextLevel,
                dayStreak: game.dayStreak,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (compactActions)
          PopupMenuButton<VoidCallback>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert),
            onSelected: (action) => action(),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _loadExample,
                child: const Row(
                  children: [
                    Icon(Icons.auto_stories_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Load an example'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _exportJson,
                child: const Row(
                  children: [
                    Icon(Icons.ios_share, size: 18),
                    SizedBox(width: 10),
                    Text('Copy experiment JSON'),
                  ],
                ),
              ),
            ],
          )
        else ...[
          IconButton(
            tooltip: 'Load an example',
            icon: const Icon(Icons.auto_stories_outlined),
            onPressed: _loadExample,
          ),
          IconButton(
            tooltip: 'Copy experiment JSON',
            icon: const Icon(Icons.ios_share),
            onPressed: _exportJson,
          ),
        ],
        IconButton(
          tooltip: 'API key',
          icon: Icon(
            Icons.key,
            color: context.watch<SettingsStore>().hasApiKey
                ? AppColors.success
                : AppColors.warning,
          ),
          onPressed: () =>
              ApiKeyDialog.show(context, context.read<SettingsStore>()),
        ),
        IconButton(
          tooltip: 'Lab assistant',
          icon: const Icon(Icons.smart_toy_outlined, size: 20),
          onPressed: () {
            if (MediaQuery.of(context).size.width >= _wideBreakpoint) {
              setState(() => _assistantOpen = !_assistantOpen);
            } else {
              _scaffoldKey.currentState?.openEndDrawer();
            }
          },
        ),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: compactActions
              ? Tooltip(
                  message: 'Run experiment',
                  child: FilledButton(
                    onPressed: _runExperiment,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(10),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, size: 19),
                  ),
                )
              : FilledButton.icon(
                  onPressed: _runExperiment,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 19),
                  label: const Text('Run'),
                ),
        ),
      ],
    );
  }

  Widget _buildLibrary() {
    return ComponentLibraryPanel(
      onQuickAdd: (component) {
        _quickAdd(component);
        if (MediaQuery.of(context).size.width < _wideBreakpoint) {
          Navigator.of(context).maybePop();
        }
      },
    );
  }

  Widget _buildAssistant() {
    return AssistantPanel(
      messages: _chat,
      isLoading: _assistantLoading,
      onSend: _sendHint,
      onClose: () {
        if (MediaQuery.of(context).size.width >= _wideBreakpoint) {
          setState(() => _assistantOpen = false);
        } else {
          Navigator.of(context).maybePop();
        }
      },
    );
  }

  Widget _buildCanvasArea() {
    return Stack(
      children: [
        Positioned.fill(
          child: CanvasView(
            key: _canvasKey,
            controller: _controller,
            onRequestEdgeLabel: (current) =>
                showEdgeLabelDialog(context, current),
          ),
        ),
        Positioned(left: 12, bottom: 12, child: _buildCanvasToolbar()),
      ],
    );
  }

  Widget _buildCanvasToolbar() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toolbarButton(
                icon: Icons.undo,
                tooltip: 'Undo',
                onPressed: _controller.canUndo ? _controller.undo : null,
              ),
              _toolbarButton(
                icon: Icons.redo,
                tooltip: 'Redo',
                onPressed: _controller.canRedo ? _controller.redo : null,
              ),
              _divider(),
              _toolbarButton(
                icon: Icons.zoom_out,
                tooltip: 'Zoom out',
                onPressed: _controller.zoomOut,
              ),
              _toolbarButton(
                icon: Icons.center_focus_strong,
                tooltip: 'Fit to content',
                onPressed: () {
                  final box =
                      _canvasKey.currentContext?.findRenderObject()
                          as RenderBox?;
                  if (box != null) _controller.fitToContent(box.size);
                },
              ),
              _toolbarButton(
                icon: Icons.zoom_in,
                tooltip: 'Zoom in',
                onPressed: _controller.zoomIn,
              ),
              _divider(),
              _toolbarButton(
                icon: Icons.delete_outline,
                tooltip: 'Clear canvas',
                color: AppColors.danger,
                onPressed: _controller.isEmpty ? null : _clearCanvas,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: AppColors.border,
  );

  Widget _toolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      color: color ?? AppColors.textSecondary,
      disabledColor: AppColors.textMuted.withValues(alpha: 0.35),
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}
