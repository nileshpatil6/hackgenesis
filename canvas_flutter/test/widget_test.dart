import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:canvas_lab/data/component_library.dart';
import 'package:canvas_lab/game/achievements.dart';
import 'package:canvas_lab/game/game_state.dart';
import 'package:canvas_lab/models/component_data.dart';
import 'package:canvas_lab/canvas/canvas_controller.dart';
import 'package:canvas_lab/widgets/xp_bar.dart';

void main() {
  group('XpBar', () {
    Future<void> pumpAt(WidgetTester tester, double width) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: const XpBar(
                  level: 7,
                  rankTitle: 'Apprentice Tinkerer',
                  progress: 0.42,
                  xpIntoLevel: 84,
                  xpForNextLevel: 200,
                  dayStreak: 5,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Regression coverage for two overflow crashes: the fixed-width level
    // badge alone (38px) not fitting, and the XP text rendering at its
    // natural width instead of ellipsizing within whatever room is left.
    for (final width in [20.0, 40.0, 90.0, 150.0, 420.0, 800.0]) {
      testWidgets('does not overflow at ${width}px wide', (tester) async {
        await pumpAt(tester, width);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('component library', () {
    test('is populated and every component has a known category', () {
      expect(kComponentLibrary, isNotEmpty);
      expect(kCategories.length, 15);

      final categoryIds = kCategories.map((c) => c.id).toSet();
      final orphans = kComponentLibrary
          .where((c) => !categoryIds.contains(c.category))
          .map((c) => '${c.id} -> ${c.category}')
          .toList();
      expect(orphans, isEmpty, reason: 'components in unknown categories');
    });

    test('component ids are unique', () {
      final ids = kComponentLibrary.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('search matches label and respects the category filter', () {
      final all = searchComponents('');
      expect(all.length, kComponentLibrary.length);

      final electronics = searchComponents('', categoryId: 'electronics');
      expect(electronics, isNotEmpty);
      expect(electronics.every((c) => c.category == 'electronics'), isTrue);

      final resistors = searchComponents('resistor');
      expect(resistors, isNotEmpty);
    });

    test('every variation resolves to a known family', () {
      final familyIds = kComponentFamilies.map((f) => f.id).toSet();
      final orphans = kComponentLibrary
          .map((c) => c.id)
          .where((id) => !familyIds.contains(familyIdOf(id)))
          .toList();
      expect(orphans, isEmpty, reason: 'component ids with no owning family');
    });

    test('family variations round-trip back to the flat library', () {
      final totalViaFamilies = kComponentFamilies
          .map((f) => familyVariations(f.id).length)
          .fold<int>(0, (a, b) => a + b);
      expect(totalViaFamilies, kComponentLibrary.length);

      final resistorFamily = kComponentFamilies.firstWhere(
        (f) => f.id == 'resistor',
      );
      final resistorVariations = familyVariations(resistorFamily.id);
      expect(resistorVariations, isNotEmpty);
      expect(
        resistorVariations.every((c) => c.label.startsWith('Resistor ')),
        isTrue,
      );
    });

    test('searchFamilies falls through to variation labels', () {
      // "220" only appears on one resistor variation, not on the family's
      // own label/description, so this only passes if the fallback works.
      final byVariation = searchFamilies('220');
      expect(byVariation.any((f) => f.id == 'resistor'), isTrue);

      final byCategory = searchFamilies('', categoryId: 'electronics');
      expect(byCategory, isNotEmpty);
      expect(byCategory.every((f) => f.category == 'electronics'), isTrue);
    });
  });

  group('canvas controller', () {
    late CanvasController controller;
    final sample = kComponentLibrary.first;

    setUp(() => controller = CanvasController());
    tearDown(() => controller.dispose());

    test('adds nodes and reports emptiness', () {
      expect(controller.isEmpty, isTrue);
      controller.addComponent(sample, const Offset(10, 20));
      expect(controller.isEmpty, isFalse);
      expect(controller.nodes.single.position, const Offset(10, 20));
    });

    test('rejects self-connections and duplicate edges', () {
      final a = controller.addComponent(sample, Offset.zero);
      final b = controller.addComponent(sample, const Offset(200, 0));

      controller.startConnection(a);
      controller.endConnection(a);
      expect(controller.edges, isEmpty, reason: 'self-connection allowed');

      controller.startConnection(a);
      controller.endConnection(b);
      expect(controller.edges.length, 1);

      controller.startConnection(a);
      controller.endConnection(b);
      expect(controller.edges.length, 1, reason: 'duplicate edge allowed');
    });

    test('deleting a node removes its edges', () {
      final a = controller.addComponent(sample, Offset.zero);
      final b = controller.addComponent(sample, const Offset(200, 0));
      controller.startConnection(a);
      controller.endConnection(b);
      expect(controller.edges.length, 1);

      controller.deleteNode(a);
      expect(controller.nodes.length, 1);
      expect(controller.edges, isEmpty);
    });

    test('undo restores the previous graph', () {
      controller.addComponent(sample, Offset.zero);
      expect(controller.nodes.length, 1);
      expect(controller.canUndo, isTrue);

      controller.undo();
      expect(controller.nodes, isEmpty);

      controller.redo();
      expect(controller.nodes.length, 1);
    });

    test('round-trips through ExperimentJson', () {
      final a = controller.addComponent(sample, const Offset(40, 60));
      final b = controller.addComponent(sample, const Offset(300, 60));
      controller.startConnection(a);
      controller.endConnection(b);

      final json = controller.toExperiment(title: 'Test').toJson();
      expect(json['nodes'], hasLength(2));
      expect(json['edges'], hasLength(1));
      expect((json['metadata'] as Map)['title'], 'Test');
    });
  });

  group('game state', () {
    test('level curve is monotonic and starts at level 1', () {
      expect(GameState.xpRequiredForLevel(1), greaterThan(0));
      var previous = 0;
      for (var level = 1; level <= 20; level++) {
        final span = GameState.xpRequiredForLevel(level);
        expect(span, greaterThanOrEqualTo(previous));
        previous = span;
      }
    });

    test('achievement ids are unique and resolvable', () {
      final ids = kAchievements.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final id in ids) {
        expect(achievementById(id), isNotNull);
      }
    });
  });

  test('ComponentData survives a JSON round-trip', () {
    final original = kComponentLibrary.first;
    final restored = ComponentData.fromJson(original.toJson());
    expect(restored.id, original.id);
    expect(restored.label, original.label);
    expect(restored.category, original.category);
    expect(restored.icon, original.icon);
    expect(restored.inputs, original.inputs);
    expect(restored.outputs, original.outputs);
  });
}
