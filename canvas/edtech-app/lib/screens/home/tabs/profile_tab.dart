import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/user_profile.dart';
import '../../../providers/user_provider.dart';
import '../../../services/notification_service.dart';
import '../../auth/login_screen.dart';
import '../../settings/openai_api_key_screen.dart';
import '../../../utils/app_theme.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Consumer<UserProvider>(
                builder: (context, userProvider, child) {
                  final user = userProvider.currentUser;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Profile Header
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryAccent.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor:
                                Theme.of(context).scaffoldBackgroundColor,
                            backgroundImage: user?.photoUrl != null
                                ? NetworkImage(user!.photoUrl!)
                                : null,
                            child: user?.photoUrl == null
                                ? Text(
                                    (user?.name.isNotEmpty ?? false)
                                        ? user!.name[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryAccent,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user?.name ?? 'User',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Stats Cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                context,
                                'XP Points',
                                '${user?.xpPoints ?? 0}',
                                Icons.stars_rounded,
                                AppTheme.brand500,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                context,
                                'Streak',
                                '${user?.dailyStreak ?? 0} days',
                                Icons.local_fire_department_rounded,
                                AppTheme.secondaryAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Menu Sections
                        _buildSectionHeader(context, 'Account'),
                        const SizedBox(height: 16),
                        _buildMenuCard(
                          context,
                          children: [
                            _buildMenuItem(
                              context,
                              icon: Icons.school_rounded,
                              title: 'Education Level',
                              subtitle: user?.educationLevel ?? 'Not set',
                            ),
                            _buildDivider(context),
                            _buildMenuItem(
                              context,
                              icon: Icons.category_rounded,
                              title: 'Stream',
                              subtitle: user?.stream ?? 'Not set',
                            ),
                            _buildDivider(context),
                            _buildMenuItem(
                              context,
                              icon: Icons.speed_rounded,
                              title: 'Learning Pace',
                              subtitle: user?.learningPace ?? 'Normal',
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        _buildSectionHeader(context, 'Settings'),
                        const SizedBox(height: 16),
                        _buildMenuCard(
                          context,
                          children: [
                            _buildMenuItem(
                              context,
                              icon: Icons.vpn_key_rounded,
                              title: 'OpenAI API Key',
                              subtitle:
                                  'Required for AI chat, quiz & flashcards',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const OpenAIApiKeyScreen()),
                              ),
                            ),
                            _buildDivider(context),
                            _buildMenuItem(
                              context,
                              icon: Icons.notifications_rounded,
                              title: 'Notifications',
                              onTap: () => _showNotificationsDialog(context),
                            ),
                            _buildDivider(context),
                            _buildMenuItem(
                              context,
                              icon: Icons.edit_rounded,
                              title: 'Edit Profile',
                              onTap: () =>
                                  _showEditProfileDialog(context, userProvider),
                            ),
                            _buildDivider(context),
                            _buildMenuItem(
                              context,
                              icon: Icons.help_rounded,
                              title: 'Help & Support',
                              onTap: () => _showHelpDialog(context),
                            ),
                            _buildDivider(context),
                            _buildMenuItem(
                              context,
                              icon: Icons.info_rounded,
                              title: 'About',
                              onTap: () => _showAboutDialog(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Logout Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await _logout(context, userProvider);
                            },
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Logout'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuCard(BuildContext context,
      {required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.grey.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Theme.of(context).iconTheme.color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.6),
                fontSize: 12,
              ),
            )
          : null,
      trailing: onTap != null
          ? Icon(Icons.chevron_right_rounded,
              color: Theme.of(context).iconTheme.color?.withOpacity(0.5))
          : null,
      onTap: onTap,
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).dividerColor.withOpacity(0.1),
      indent: 20,
      endIndent: 20,
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value,
      IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.grey.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context, UserProvider userProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Logout',
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to logout?',
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await userProvider.signOut();

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _showNotificationsDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    bool enabled = prefs.getBool('dailyReminderEnabled') ?? false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(dialogContext).cardTheme.color,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Notifications',
              style: TextStyle(
                  color: Theme.of(dialogContext).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold)),
          content: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Daily study reminder'),
            subtitle: const Text('Get a nudge every evening at 7:00 PM'),
            value: enabled,
            onChanged: (value) async {
              setDialogState(() => enabled = value);
              await prefs.setBool('dailyReminderEnabled', value);
              if (value) {
                await NotificationService.scheduleDailyReminder(
                  id: 999,
                  title: '📚 Time to study!',
                  body: 'Keep your streak going — jump back into a subject.',
                  hour: 19,
                  minute: 0,
                );
              } else {
                await NotificationService.cancelNotification(999);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog(
      BuildContext context, UserProvider userProvider) async {
    final user = userProvider.currentUser;
    if (user == null) return;

    final nameController = TextEditingController(text: user.name);
    final streamController = TextEditingController(text: user.stream);
    String educationLevel = user.educationLevel;
    String learningPace = user.learningPace;

    const educationLevels = [
      'Class 1-5',
      'Class 6-8',
      'Class 9-10',
      'Class 11-12',
      'Undergraduate',
      'Postgraduate',
      'Professional',
    ];
    const paces = ['slow', 'normal', 'fast'];

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(dialogContext).cardTheme.color,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Edit Profile',
              style: TextStyle(
                  color: Theme.of(dialogContext).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: educationLevels.contains(educationLevel)
                      ? educationLevel
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Education Level',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: educationLevels
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (value) => setDialogState(
                      () => educationLevel = value ?? educationLevel),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: streamController,
                  decoration: InputDecoration(
                    labelText: 'Stream',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue:
                      paces.contains(learningPace) ? learningPace : 'normal',
                  decoration: InputDecoration(
                    labelText: 'Learning Pace',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: paces
                      .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p[0].toUpperCase() + p.substring(1))))
                      .toList(),
                  onChanged: (value) => setDialogState(
                      () => learningPace = value ?? learningPace),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedUser = UserProfile(
                  id: user.id,
                  name: nameController.text.trim().isEmpty
                      ? user.name
                      : nameController.text.trim(),
                  email: user.email,
                  age: user.age,
                  educationLevel: educationLevel,
                  stream: streamController.text.trim(),
                  learningPreferences: user.learningPreferences,
                  learningPace: learningPace,
                  interests: user.interests,
                  aiPersonality: user.aiPersonality,
                  xpPoints: user.xpPoints,
                  badges: user.badges,
                  dailyStreak: user.dailyStreak,
                  lastActiveDate: user.lastActiveDate,
                  photoUrl: user.photoUrl,
                );
                await userProvider.updateProfile(updatedUser);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Help & Support',
            style: TextStyle(
                color: Theme.of(dialogContext).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Getting Started',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(dialogContext).textTheme.bodyLarge?.color),
              ),
              const SizedBox(height: 6),
              Text(
                '• Create a subject from the Subjects tab\n'
                '• Upload PDF notes to a subject to unlock AI chat, quizzes and flashcards\n'
                '• Use Quick Actions on the Dashboard to jump straight into a task',
                style: TextStyle(
                    color: Theme.of(dialogContext)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.8)),
              ),
              const SizedBox(height: 16),
              Text(
                'Need more help?',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(dialogContext).textTheme.bodyLarge?.color),
              ),
              const SizedBox(height: 6),
              Text(
                'Reach us at support@eduai.app and we\'ll get back to you.',
                style: TextStyle(
                    color: Theme.of(dialogContext)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.8)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'EduAI',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2025 EduAI. All rights reserved.',
      children: [
        const SizedBox(height: 16),
        const Text(
          'Your personalized AI-powered learning companion. '
          'Learn smarter, not harder with adaptive content, '
          'interactive quizzes, and gamified experiences.',
        ),
      ],
    );
  }
}
