import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edtech_app/widgets/app_nav_bar.dart';

/// Regression coverage for the nav bar's layout.
///
/// The first version split the row evenly with `Expanded`, which capped every
/// item at a quarter of the bar — narrower than icon + label — so the selected
/// pill overflowed by 15px. These tests pin the bar down across the screen
/// widths and text scales where that would resurface.
void main() {
  const destinations = <NavDestination>[
    NavDestination(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Home',
    ),
    NavDestination(
      icon: Icons.auto_stories_outlined,
      activeIcon: Icons.auto_stories_rounded,
      label: 'Subjects',
    ),
    NavDestination(
      icon: Icons.trending_up_outlined,
      activeIcon: Icons.trending_up_rounded,
      label: 'Progress',
    ),
    NavDestination(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  Future<void> pumpBar(
    WidgetTester tester, {
    required double width,
    required int index,
    double textScale = 1.0,
    Brightness brightness = Brightness.light,
  }) async {
    // The surface size is what actually constrains the bar. Wrapping it in a
    // SizedBox does nothing, because Scaffold hands bottomNavigationBar tight
    // full-width constraints — an earlier version of this test did exactly
    // that and passed even with the overflow bug present.
    await tester.binding.setSurfaceSize(Size(width, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: const SizedBox.shrink(),
            bottomNavigationBar: AppNavBar(
              currentIndex: index,
              destinations: destinations,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    // Settle the selection animation so the label is at full width.
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('AppNavBar layout', () {
    // 320 covers small phones; 360 is the reported device (1080px / 3.0).
    for (final width in <double>[300, 320, 360, 411, 480]) {
      for (var index = 0; index < destinations.length; index++) {
        testWidgets(
          'no overflow at ${width}px with item $index selected',
          (tester) async {
            await pumpBar(tester, width: width, index: index);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('survives a large system font scale', (tester) async {
      // The longest label ("Subjects") at 1.3x is where a fixed-width pill
      // would blow out first.
      await pumpBar(tester, width: 320, index: 1, textScale: 1.3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stays within its declared height', (tester) async {
      await pumpBar(tester, width: 360, index: 0);
      final size = tester.getSize(find.byType(AppNavBar));
      // Height is the bar plus its bottom margin; the point is that it is far
      // below the ~76px the old BottomNavigationBar occupied.
      expect(size.height, lessThanOrEqualTo(kNavBarHeight + 14));
    });

    testWidgets('reports the tapped index', (tester) async {
      var tapped = -1;
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppNavBar(
              currentIndex: 0,
              destinations: destinations,
              onTap: (i) => tapped = i,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byIcon(Icons.person_outline_rounded));
      expect(tapped, 3);
    });

    testWidgets('only the selected item shows its label', (tester) async {
      await pumpBar(tester, width: 360, index: 1);
      // Unselected labels still exist in the tree but are collapsed to zero
      // width, so assert on the icons instead: exactly one active icon.
      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
      expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget);
      expect(find.byIcon(Icons.dashboard_rounded), findsNothing);
    });
  });
}
