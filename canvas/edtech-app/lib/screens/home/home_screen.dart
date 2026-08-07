import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/subject_provider.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/subjects_tab.dart';
import 'tabs/progress_tab.dart';
import 'tabs/profile_tab.dart';
import '../../utils/app_theme.dart';

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

  List<Widget> get _tabs => [
        DashboardTab(onNavigateToTab: _navigateToTab),
        const SubjectsTab(),
        const ProgressTab(),
        const ProfileTab(),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _tabs[_currentIndex],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            selectedItemColor: AppTheme.primaryAccent,
            unselectedItemColor: isDark ? Colors.white38 : Colors.grey[400],
            showSelectedLabels: false,
            showUnselectedLabels: false,
            elevation: 0,
            items: [
              _buildNavItem(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard'),
              _buildNavItem(Icons.book_outlined, Icons.book_rounded, 'Subjects'),
              _buildNavItem(Icons.trending_up_outlined, Icons.trending_up_rounded, 'Progress'),
              _buildNavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
      extendBody: true, // Allows body to go behind the floating nav bar
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData icon, IconData activeIcon, String label) {
    return BottomNavigationBarItem(
      icon: Icon(icon, size: 24),
      activeIcon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primaryAccent.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(activeIcon, size: 24, color: AppTheme.primaryAccent),
      ),
      label: label,
    );
  }
}
