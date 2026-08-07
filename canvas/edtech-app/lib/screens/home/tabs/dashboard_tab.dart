import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/subject.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/subject_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../utils/app_theme.dart';
import '../../calendar/calendar_screen.dart';
import '../../playlists/playlists_screen.dart';
import '../../subjects/subject_detail_screen.dart';

class DashboardTab extends StatelessWidget {
  final void Function(int index)? onNavigateToTab;

  const DashboardTab({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 32),
              _buildStreakCard(context),
              const SizedBox(height: 32),
              _buildQuickActions(context),
              const SizedBox(height: 32),
              _buildRecentSubjects(context),
              const SizedBox(height: 32),
              _buildDailyGoal(context),
              const SizedBox(height: 100), // Bottom padding for nav bar
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Consumer2<UserProvider, ThemeProvider>(
      builder: (context, userProvider, themeProvider, child) {
        final user = userProvider.currentUser;
        final greeting = _getGreeting();
        final isDark = themeProvider.isDarkMode;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.name ?? 'User',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                // Theme Toggle
                GestureDetector(
                  onTap: () => themeProvider.toggleTheme(!isDark),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: AppTheme.primaryAccent,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Profile Image
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    backgroundImage: user?.photoUrl != null
                        ? NetworkImage(user!.photoUrl!)
                        : null,
                    child: user?.photoUrl == null
                        ? Text(
                            (user?.name.isNotEmpty ?? false)
                                ? user!.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryAccent,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStreakCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final streak = userProvider.streak;
        final currentStreak = streak?.currentStreak ?? 0;

        return Stack(
          children: [
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                // User Requested: Blue -> Purple -> Cream (Low accent, pastel)
                gradient: isDark 
                    ? const LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [
                          Color(0xFFE0F2FE), // Soft Blue
                          Color(0xFFF3E8FF), // Soft Purple
                          Color(0xFFFFF7ED), // Soft Cream
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: isDark 
                        ? Colors.black.withOpacity(0.3) 
                        : const Color(0xFF6366F1).withOpacity(0.1), // Soft indigo shadow
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Stack(
                  children: [
                    // Enhanced Background Pattern
                    CustomPaint(
                      painter: _BackgroundPatternPainter(isDark: isDark),
                      size: Size.infinite,
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.6),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF6B6B), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Daily Streak',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF2D3436),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_outward_rounded, 
                                color: isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF2D3436).withOpacity(0.3)
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$currentStreak',
                                style: TextStyle(
                                  fontSize: 64,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF2D3436),
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'days',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: isDark ? Colors.white70 : const Color(0xFF636E72),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Keep the flame alive!',
                            style: TextStyle(
                              color: isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF636E72),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Vibrant 3D Fire Element
            Positioned(
              right: -20,
              bottom: -30,
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    colors: [Color(0xFFFF512F), Color(0xFFDD2476), Color(0xFFFF9068)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcIn,
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  size: 180,
                  color: Colors.white, // Color is ignored due to ShaderMask
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            _buildActionCard(
              context,
              title: 'New Subject',
              subtitle: 'Create & Organize',
              icon: Icons.add_circle_outline_rounded,
              color: const Color(0xFF6C63FF),
              onTap: () => onNavigateToTab?.call(1),
            ),
            _buildActionCard(
              context,
              title: 'Upload Notes',
              subtitle: 'Scan or Import',
              icon: Icons.upload_file_rounded,
              color: const Color(0xFF4ECDC4),
              onTap: () => _navigateToSubjectAction(context, initialTabIndex: 0),
            ),
            _buildActionCard(
              context,
              title: 'Learn AI',
              subtitle: 'Ask & Explore',
              icon: Icons.auto_awesome_rounded,
              color: const Color(0xFFFF6B6B),
              onTap: () => _navigateToSubjectAction(context, initialTabIndex: 1),
            ),
            _buildActionCard(
              context,
              title: 'Take Quiz',
              subtitle: 'Test Knowledge',
              icon: Icons.quiz_rounded,
              color: const Color(0xFFFFE66D),
              onTap: () => _navigateToSubjectAction(context, initialTabIndex: 2),
            ),
            _buildActionCard(
              context,
              title: 'Calendar',
              subtitle: 'Plan Schedule',
              icon: Icons.calendar_month_rounded,
              color: const Color(0xFF3B82F6),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CalendarScreen()),
                );
              },
            ),
            _buildActionCard(
              context,
              title: 'Playlists',
              subtitle: 'Study Lists',
              icon: Icons.playlist_play_rounded,
              color: const Color(0xFF8B5CF6),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PlaylistsScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSubjects(BuildContext context) {
    return Consumer<SubjectProvider>(
      builder: (context, subjectProvider, child) {
        final subjects = subjectProvider.subjects.take(3).toList();

        if (subjects.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Subjects',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                TextButton(
                  onPressed: () => onNavigateToTab?.call(1),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  return Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Color(int.parse('0xFF${subject.color.replaceAll('#', '')}')).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Color(int.parse('0xFF${subject.color.replaceAll('#', '')}')).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.book_rounded,
                            color: Color(int.parse('0xFF${subject.color.replaceAll('#', '')}')),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: subject.progressPercentage / 100,
                              backgroundColor: Colors.grey.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation(
                                Color(int.parse('0xFF${subject.color.replaceAll('#', '')}')),
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDailyGoal(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircularProgressIndicator(
            value: 0.6,
            strokeWidth: 8,
            backgroundColor: Colors.grey.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation(AppTheme.primaryAccent),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Goal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '30/50 mins completed',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  Future<void> _navigateToSubjectAction(
    BuildContext context, {
    required int initialTabIndex,
  }) async {
    final subjects =
        Provider.of<SubjectProvider>(context, listen: false).subjects;

    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a subject first to use this feature.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      onNavigateToTab?.call(1);
      return;
    }

    if (subjects.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubjectDetailScreen(
            subject: subjects.first,
            initialTabIndex: initialTabIndex,
          ),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<Subject>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SubjectPickerSheet(subjects: subjects),
    );

    if (selected != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubjectDetailScreen(
            subject: selected,
            initialTabIndex: initialTabIndex,
          ),
        ),
      );
    }
  }
  }


// Custom Painter for Background Pattern
class _BackgroundPatternPainter extends CustomPainter {
  final bool isDark;
  
  _BackgroundPatternPainter({this.isDark = true});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(isDark ? 0.05 : 0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.6, size.width * 0.5, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.75, size.height * 1.0, size.width, size.height * 0.7);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(isDark ? 0.05 : 0.1)
      ..style = PaintingStyle.fill;
      
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.2), 40, circlePaint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.8), 20, circlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Bottom sheet for picking a subject when more than one exists
class _SubjectPickerSheet extends StatelessWidget {
  final List<Subject> subjects;

  const _SubjectPickerSheet({required this.subjects});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Choose a Subject',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  final color = Color(
                      int.parse('0xFF${subject.color.replaceAll('#', '')}'));
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.book_rounded, color: color),
                    ),
                    title: Text(
                      subject.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, subject),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
