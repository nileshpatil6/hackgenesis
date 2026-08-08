import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Height of the floating navigation bar, excluding its outer margin.
///
/// Exposed so tabs can reserve the right amount of bottom padding instead of
/// guessing at a magic number.
const double kNavBarHeight = 62;

/// Space a scrollable tab should leave at the bottom to clear the nav bar.
const double kNavBarClearance = kNavBarHeight + 28;

/// Outer margin below the bar, matching [AppNavBar]'s own margin.
const double kNavBarBottomMargin = 14;

/// Height the floating nav bar actually occupies at the bottom of the screen,
/// including its margin and the device's bottom inset.
///
/// The host Scaffold sets `extendBody: true`, so each tab's own Scaffold
/// stretches to the very bottom of the window and places its floating action
/// button underneath the bar. Offsetting by this much lifts it clear on both
/// button-navigation and gesture-navigation devices, where the inset differs.
/// Space the floating bar occupies at the bottom of the screen, including
/// its margin and the device's bottom inset.
///
/// Call this from a context **above** the host Scaffold, such as
/// `HomeScreen.build`, and pass the result down. Inside a tab the value is
/// always wrong: the host Scaffold consumes the bottom padding (and view
/// padding) to lay out its bottomNavigationBar, so the ambient MediaQuery
/// reports zero there and a button offset by it lands back under the bar on
/// gesture-navigation devices.
double navBarInset(BuildContext context) =>
    kNavBarHeight +
    kNavBarBottomMargin +
    MediaQuery.viewPaddingOf(context).bottom;

/// One entry in [AppNavBar].
@immutable
class NavDestination {
  const NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Compact floating navigation bar.
///
/// Replaces [BottomNavigationBar], whose fixed 56px body plus an oversized
/// active icon made the bar unnecessarily tall and made icons jump on
/// selection. Here the selected item slides into a pill that reveals its
/// label, so the bar keeps one constant height.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.onTap,
  });

  final int currentIndex;
  final List<NavDestination> destinations;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        height: kNavBarHeight,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.inkSurface.withValues(alpha: 0.96)
              : Colors.white,
          borderRadius: BorderRadius.circular(kNavBarHeight / 2),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.4)
                  : AppTheme.brand500.withValues(alpha: 0.13),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              // The selected item needs room for its label, so it claims a
              // larger share of the row. An equal split caps every item at a
              // quarter of the bar, which is narrower than icon + label.
              Expanded(
                flex: i == currentIndex ? 2 : 1,
                child: _NavItem(
                  destination: destinations[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactive = isDark ? Colors.white54 : AppTheme.ink300;

    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            height: 42,
            padding: EdgeInsets.symmetric(horizontal: selected ? 12 : 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primaryAccent.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(21),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? destination.activeIcon : destination.icon,
                  size: 22,
                  color: selected ? AppTheme.primaryAccent : inactive,
                ),
                // Flexible + ClipRect: the label collapses to zero width when
                // unselected and can always shrink to whatever room is left,
                // so it can never force the pill wider than its slot.
                Flexible(
                  child: ClipRect(
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerLeft,
                      widthFactor: selected ? 1 : 0,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          destination.label,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
