import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'game/game_state.dart';
import 'screens/home_screen.dart';
import 'services/openai_service.dart';
import 'services/settings_store.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsStore();
  final game = GameState();
  await Future.wait([settings.load(), game.load()]);

  runApp(CanvasLabApp(settings: settings, game: game));
}

/// Root of the AI Experiment Lab.
class CanvasLabApp extends StatelessWidget {
  const CanvasLabApp({super.key, required this.settings, required this.game});

  final SettingsStore settings;
  final GameState game;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: game),
        Provider<OpenAiService>(
          create: (_) => OpenAiService(settings),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: MaterialApp(
        title: 'AI Experiment Lab',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const HomeScreen(),
      ),
    );
  }
}
