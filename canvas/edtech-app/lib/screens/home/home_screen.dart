import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/subject_provider.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/subjects_tab.dart';
import 'tabs/progress_tab.dart';
import 'tabs/profile_tab.dart';
import '../../utils/app_theme.dart';

/// Height of the floating navigation bar, excluding its outer margin.
///
/// Exposed so tabs can reserve the right amount of bottom padding instead of
/// guessing at a magic number.
const double kNavBarHeight = 62;

/// Space a scrollable tab should leave at the bottom to clear the nav bar.
const double kNavBarClearance = kNavBarHeight + 28;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  static const _destinations = <_NavDestination>[
    _NavDestination(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Home',
    ),
    _NavDestination(
      icon: Icons.auto_stories_outlined,
      activeIcon: Icons.auto_stories_rounded,
      label: 'Subjects',
    ),
    _NavDestination(
      icon: Icons.trending_up_outlined,
      activeIcon: Icons.trending_up_rounded,
      label: 'Progress',
    ),
    _NavDestination(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final subjectProvider = Provider.of<SubjectProvider>(context, listen: false);

    if (userProvider.currentUser != null) {
      await subjectProvider.loadSubjects(userProvider.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // IndexedStack keeps each tab's scroll position and state alive, so
      // switching tabs no longer rebuilds (and re-fetches) from scratch.
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardTab(onNavigateToTab: _navigateToTab),
          const SubjectsTab(),
          const ProgressTab(),
          const ProfileTab(),
        ],
      ),
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: _currentIndex,
        destinations: _destinations,
        onTap: _navigateToTab,
      ),
      extendBody: true,
    );
  }
}

class _NavDestination {
  const _NavDestination({
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
/// selection. Here the selected item slides into a pill that grows to fit its
/// label, so the bar keeps one constant height.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.currentIndex,
    required this.destinations,
    required this.onTap,
  });

  final int currentIndex;
  final List<_NavDestination> destinations;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        height: kNavBarHeight,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF151A23).withValues(alpha: 0.96)
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
                  : const Color(0xFF6366F1).withValues(alpha: 0.13),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
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

  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactive = isDark ? Colors.white54 : const Color(0xFF94A3B8);

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
            padding: EdgeInsets.symmetric(horizontal: selected ? 14 : 10),
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
                // The label only exists while selected; ClipRect keeps the
                // reveal from overflowing mid-animation on narrow screens.
                ClipRect(
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerLeft,
                    widthFactor: selected ? 1 : 0,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryAccent,
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
