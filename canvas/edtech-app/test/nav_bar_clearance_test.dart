import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edtech_app/widgets/app_nav_bar.dart';

/// The host Scaffold sets `extendBody: true`, so each tab's own Scaffold
/// stretches under the floating nav bar and puts its floating action button
/// beneath it. The "New subject" button was completely hidden that way.
///
/// These tests pin the geometry: with [navBarInset] applied, the button must
/// sit clear of the bar on devices with and without a gesture-navigation
/// inset, which is exactly where a fixed offset would fail.
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
  ];

  Future<void> pumpTab(
    WidgetTester tester, {
    required double bottomInset,
    required bool lifted,
  }) async {
    // What HomeScreen computes and passes to the tab.
    final inset =
        lifted ? kNavBarHeight + kNavBarBottomMargin + bottomInset : 0.0;

    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            padding: EdgeInsets.only(bottom: bottomInset),
            viewPadding: EdgeInsets.only(bottom: bottomInset),
          ),
          child: Scaffold(
            extendBody: true,
            bottomNavigationBar: AppNavBar(
              currentIndex: 1,
              destinations: destinations,
              onTap: (_) {},
            ),
            // Mirrors HomeScreen: the inset is read here, above the host
            // Scaffold, and handed to the tab. Reading it inside the tab
            // yields zero, because the Scaffold has consumed it by then.
            body: Builder(
              builder: (hostContext) => Scaffold(
                backgroundColor: Colors.transparent,
                body: const SizedBox.expand(),
                floatingActionButton: Padding(
                  padding: EdgeInsets.only(bottom: inset),
                  child: FloatingActionButton.extended(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('New subject'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('create button clears the nav bar', () {
    // 0 covers button navigation, 34 a typical gesture-navigation inset.
    for (final inset in <double>[0, 24, 34, 48]) {
      testWidgets('with a ${inset}px bottom inset', (tester) async {
        await pumpTab(tester, bottomInset: inset, lifted: true);

        final fab = tester.getRect(find.byType(FloatingActionButton));
        final bar = tester.getRect(find.byType(AppNavBar));

        expect(
          fab.bottom,
          lessThanOrEqualTo(bar.top),
          reason: 'the create button overlaps the navigation bar',
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('and would overlap without the offset', (tester) async {
      // Guards the test itself: if this ever passes, the geometry no longer
      // needs navBarInset and these tests have stopped proving anything.
      await pumpTab(tester, bottomInset: 34, lifted: false);

      final fab = tester.getRect(find.byType(FloatingActionButton));
      final bar = tester.getRect(find.byType(AppNavBar));

      expect(fab.bottom, greaterThan(bar.top));
    });
  });
}
