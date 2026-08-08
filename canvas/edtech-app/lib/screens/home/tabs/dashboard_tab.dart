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
import '../../../widgets/app_nav_bar.dart' show kNavBarClearance;

class DashboardTab extends StatelessWidget {
  final void Function(int index)? onNavigateToTab;

  const DashboardTab({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildStreakCard(context),
              const SizedBox(height: 28),
              _buildQuickActions(context),
              const SizedBox(height: 28),
              _buildRecentSubjects(context),
              const SizedBox(height: 28),
              _buildDailyGoal(context),
              // Derived from the nav bar's own height rather than a guess, so
              // the last card always clears it.
              const SizedBox(height: kNavBarClearance),
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
            // Expanded + ellipsis: a long display name used to push the
            // avatar off the right edge of the row.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    greeting,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.name ?? 'User',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
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
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
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
              height: 186,
              width: double.infinity,
              decoration: BoxDecoration(
                // User Requested: Blue -> Purple -> Cream (Low accent, pastel)
                gradient: isDark
                    ? AppTheme.streakGradientDark
                    : AppTheme.streakGradientLight,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.3)
                        : AppTheme.brand500
                            .withOpacity(0.1), // Soft indigo shadow
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
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.white.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.white.withOpacity(0.6),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                        Icons.local_fire_department_rounded,
                                        color: AppTheme.secondaryAccent,
                                        size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Daily Streak',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : AppTheme.ink900,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_outward_rounded,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.5)
                                      : AppTheme.ink900.withOpacity(0.3)),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$currentStreak',
                                style: TextStyle(
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  color:
                                      isDark ? Colors.white : AppTheme.ink900,
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
                                    color: isDark
                                        ? Colors.white70
                                        : AppTheme.ink500,
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
                              color: isDark
                                  ? Colors.white.withOpacity(0.6)
                                  : AppTheme.ink500,
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
                    colors: [
                      Color(0xFFF5A93F),
                      AppTheme.ember,
                      Color(0xFFDE6E4B),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcIn,
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  size: 146,
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          // Slightly taller than wide. At 1.1 the cell was 3.5px shorter than
          // the card's content, which overflowed on every build.
          childAspectRatio: 1.02,
          children: [
            _buildActionCard(
              context,
              title: 'New Subject',
              subtitle: 'Create & Organize',
              icon: Icons.add_circle_outline_rounded,
              color: AppTheme.brand500,
              onTap: () => onNavigateToTab?.call(1),
            ),
            _buildActionCard(
              context,
              title: 'Upload Notes',
              subtitle: 'Scan or Import',
              icon: Icons.upload_file_rounded,
              color: AppTheme.tertiaryAccent,
              onTap: () =>
                  _navigateToSubjectAction(context, initialTabIndex: 0),
            ),
            _buildActionCard(
              context,
              title: 'Learn AI',
              subtitle: 'Ask & Explore',
              icon: Icons.auto_awesome_rounded,
              color: AppTheme.secondaryAccent,
              onTap: () =>
                  _navigateToSubjectAction(context, initialTabIndex: 1),
            ),
            _buildActionCard(
              context,
              title: 'Take Quiz',
              subtitle: 'Test Knowledge',
              icon: Icons.quiz_rounded,
              color: AppTheme.warning,
              onTap: () =>
                  _navigateToSubjectAction(context, initialTabIndex: 2),
            ),
            _buildActionCard(
              context,
              title: 'Calendar',
              subtitle: 'Plan Schedule',
              icon: Icons.calendar_month_rounded,
              color: AppTheme.info,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const CalendarScreen()),
                );
              },
            ),
            _buildActionCard(
              context,
              title: 'Playlists',
              subtitle: 'Study Lists',
              icon: Icons.playlist_play_rounded,
              color: AppTheme.brand400,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PlaylistsScreen()),
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

    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withOpacity(0.12),
        highlightColor: color.withOpacity(0.06),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.04),
            ),
          ),
          padding: const EdgeInsets.all(16),
          // Every child is either fixed-height or free to shrink, so the card
          // cannot overflow when the grid cell is short or the user has a
          // larger system font size.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.2,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                    fontSize: 18,
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
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                clipBehavior: Clip.none,
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  return Container(
                    width: 138,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Color(int.parse(
                                '0xFF${subject.color.replaceAll('#', '')}'))
                            .withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Color(int.parse(
                                    '0xFF${subject.color.replaceAll('#', '')}'))
                                .withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.auto_stories_rounded,
                            size: 20,
                            color: Color(int.parse(
                                '0xFF${subject.color.replaceAll('#', '')}')),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Flexible so a two-line subject name can shrink
                        // instead of pushing the progress bar out of the card.
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  subject.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: subject.progressPercentage / 100,
                                      minHeight: 5,
                                      backgroundColor:
                                          Colors.grey.withOpacity(0.15),
                                      valueColor: AlwaysStoppedAnimation(
                                        Color(int.parse(
                                            '0xFF${subject.color.replaceAll('#', '')}')),
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${subject.progressPercentage.round()}%',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.6),
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
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.6,
        size.width * 0.5, size.height * 0.8);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 1.0, size.width, size.height * 0.7);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(isDark ? 0.05 : 0.1)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
        Offset(size.width * 0.8, size.height * 0.2), 40, circlePaint);
    canvas.drawCircle(
        Offset(size.width * 0.2, size.height * 0.8), 20, circlePaint);
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
                color:
                    isDark ? Colors.white.withOpacity(0.2) : Colors.grey[300],
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
