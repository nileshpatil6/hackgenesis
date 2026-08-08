import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/subject_provider.dart';
import '../../widgets/app_nav_bar.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/subjects_tab.dart';
import 'tabs/progress_tab.dart';
import 'tabs/profile_tab.dart';

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

  static const _destinations = <NavDestination>[
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final subjectProvider =
        Provider.of<SubjectProvider>(context, listen: false);

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
      bottomNavigationBar: AppNavBar(
        currentIndex: _currentIndex,
        destinations: _destinations,
        onTap: _navigateToTab,
      ),
      extendBody: true,
    );
  }
}
