import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import '../../utils/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // User data
  String name = '';
  int age = 0;
  String educationLevel = '';
  String stream = '';
  List<String> learningPreferences = [];
  String learningPace = 'normal';
  List<String> interests = [];
  String aiPersonality = 'Professor';

  final List<String> educationLevels = [
    'Class 1-5', 'Class 6-8', 'Class 9-10', 'Class 11-12',
    'Undergraduate', 'Postgraduate', 'Professional',
  ];

  final List<String> streams = [
    'Engineering', 'Medical', 'Commerce', 'Arts & Humanities',
    'Law', 'Competitive Exams', 'Skill-based', 'Other',
  ];

  final List<Map<String, dynamic>> learningStyleOptions = [
    {'title': 'Visual', 'icon': Icons.visibility_rounded, 'value': 'Visual', 'desc': 'I learn by seeing'},
    {'title': 'Auditory', 'icon': Icons.headphones_rounded, 'value': 'Audio', 'desc': 'I learn by listening'},
    {'title': 'Practical', 'icon': Icons.build_rounded, 'value': 'Examples', 'desc': 'I learn by doing'},
    {'title': 'Reading', 'icon': Icons.menu_book_rounded, 'value': 'Reading', 'desc': 'I learn by reading'},
  ];

  final List<String> interestOptions = [
    'Sports', 'Gaming', 'Tech', 'Arts', 'Music',
    'Movies', 'Science', 'History', 'Travel', 'Coding'
  ];

  final List<Map<String, String>> aiPersonalities = [
    {'name': 'Professor', 'icon': '👨‍🏫', 'value': 'Professor', 'desc': 'Wise & Detailed'},
    {'name': 'Buddy', 'icon': '🤖', 'value': 'Robot', 'desc': 'Fun & Casual'},
    {'name': 'Detective', 'icon': '🕵️', 'value': 'Detective', 'desc': 'Curious & Analytical'},
    {'name': 'Coach', 'icon': '💪', 'value': 'Coach', 'desc': 'Motivating & Direct'},
  ];

  void _nextPage() {
    if (_currentPage < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    var currentUser = userProvider.currentUser;

    final newUser = UserProfile(
      id: currentUser?.id ?? AuthService.guestUserId,
      name: name.isNotEmpty ? name : 'Guest',
      email: currentUser?.email ?? 'guest@example.com',
      age: age,
      educationLevel: educationLevel,
      stream: stream,
      learningPreferences: learningPreferences,
      learningPace: learningPace,
      interests: interests,
      aiPersonality: aiPersonality,
      xpPoints: currentUser?.xpPoints ?? 0,
      badges: currentUser?.badges ?? [],
      dailyStreak: currentUser?.dailyStreak ?? 0,
      lastActiveDate: DateTime.now(),
      photoUrl: currentUser?.photoUrl,
    );

    await userProvider.updateProfile(newUser);
    await userProvider.unlockAchievement('first_login');

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Stack(
        children: [
          // Premium Bluish-Cream Background
          Container(
            decoration: BoxDecoration(
              gradient: isDark 
                  ? const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [
                        Color(0xFFF0F4FF), // Soft Blue-White
                        Color(0xFFFFF8F0), // Warm Cream
                        Color(0xFFF5F0FF), // Lavender Tint
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Header with Progress
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      if (_currentPage > 0)
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: isDark ? Colors.white : Colors.black87),
                            onPressed: _previousPage,
                          ),
                        ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (_currentPage + 1) / 6,
                              backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.15),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryAccent),
                              minHeight: 6,
                            ),
                          ),
                        ),
                      ),
                      if (_currentPage < 5)
                        TextButton(
                          onPressed: _completeOnboarding,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentPage + 1}/6',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    children: [
                      _buildWelcomePage(isDark),
                      _buildSelectionPage(
                        isDark: isDark,
                        title: 'Education Level',
                        subtitle: 'Where are you in your journey?',
                        imagePath: 'assets/images/onboarding_learning.png',
                        child: _buildChipGrid(educationLevels, educationLevel, (val) => setState(() => educationLevel = val), isDark),
                      ),
                      _buildSelectionPage(
                        isDark: isDark,
                        title: 'Field of Study',
                        subtitle: 'What is your main focus?',
                        imagePath: 'assets/images/onboarding_learning.png',
                        child: _buildChipGrid(streams, stream, (val) => setState(() => stream = val), isDark),
                      ),
                      _buildLearningStylePage(isDark),
                      _buildSelectionPage(
                        isDark: isDark,
                        title: 'Your Interests',
                        subtitle: 'Pick what you love!',
                        imagePath: 'assets/images/onboarding_welcome.png',
                        child: _buildMultiSelectGrid(interestOptions, interests, isDark),
                      ),
                      _buildAIPersonalityPage(isDark),
                    ],
                  ),
                ),

                // Bottom Action Area
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: _canProceed() ? AppTheme.primaryGradient : null,
                      boxShadow: _canProceed() ? [
                        BoxShadow(
                          color: AppTheme.primaryAccent.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ] : null,
                    ),
                    child: ElevatedButton(
                      onPressed: _canProceed() ? _nextPage : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _currentPage == 5 ? 'Start Learning' : 'Continue',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomePage(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          // Image with subtle shadow for depth
          Container(
            padding: const EdgeInsets.all(20),
            child: Image.asset(
              'assets/images/onboarding_welcome.png',
              height: 260,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Let\'s Get Started!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1D2E),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us a bit about yourself to personalize\nyour learning experience.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 40),
          _buildTextField('Your Name', Icons.person_outline_rounded, (val) => setState(() => name = val), isDark),
          const SizedBox(height: 16),
          _buildTextField('Your Age', Icons.cake_outlined, (val) => setState(() => age = int.tryParse(val) ?? 0), isDark, isNumber: true),
        ],
      ),
    );
  }

  Widget _buildSelectionPage({required bool isDark, required String title, required String subtitle, required String imagePath, required Widget child}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1D2E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }

  Widget _buildLearningStylePage(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            child: Image.asset('assets/images/onboarding_learning.png', height: 200),
          ),
          const SizedBox(height: 24),
          Text(
            'How do you learn best?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1D2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select all that apply',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 32),
          ...learningStyleOptions.map((option) {
            final isSelected = learningPreferences.contains(option['value']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      learningPreferences.remove(option['value']);
                    } else {
                      learningPreferences.add(option['value']);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppTheme.primaryAccent.withOpacity(0.15)
                        : isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryAccent : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryAccent : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[100]),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(option['icon'], color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey[600])),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option['title'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              option['desc'],
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.primaryAccent),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAIPersonalityPage(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            child: Image.asset('assets/images/onboarding_ai.png', height: 220),
          ),
          const SizedBox(height: 24),
          Text(
            'Choose your AI Tutor',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A1D2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Who would you like to learn with?',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 32),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: aiPersonalities.length,
            itemBuilder: (context, index) {
              final personality = aiPersonalities[index];
              final isSelected = aiPersonality == personality['value'];
              return InkWell(
                onTap: () => setState(() => aiPersonality = personality['value']!),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppTheme.primaryGradient : null,
                    color: isSelected ? null : (isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7)),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected ? AppTheme.primaryAccent.withOpacity(0.3) : Colors.black.withOpacity(0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(personality['icon']!, style: const TextStyle(fontSize: 48)),
                      const SizedBox(height: 16),
                      Text(
                        personality['name']!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        personality['desc']!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white.withOpacity(0.9) : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, Function(String) onChanged, bool isDark, {bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        onChanged: onChanged,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
          prefixIcon: Icon(icon, color: AppTheme.primaryAccent),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildChipGrid(List<String> options, String selectedValue, Function(String) onSelect, bool isDark) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: options.map((option) {
        final isSelected = selectedValue == option;
        return ChoiceChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (selected) => onSelect(selected ? option : ''),
          selectedColor: AppTheme.primaryAccent,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: isSelected ? Colors.transparent : Colors.transparent),
          ),
          elevation: isSelected ? 4 : 0,
        );
      }).toList(),
    );
  }

  Widget _buildMultiSelectGrid(List<String> options, List<String> selectedValues, bool isDark) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: options.map((option) {
        final isSelected = selectedValues.contains(option);
        return FilterChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                selectedValues.add(option);
              } else {
                selectedValues.remove(option);
              }
            });
          },
          selectedColor: AppTheme.primaryAccent,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: isSelected ? Colors.transparent : Colors.transparent),
          ),
          elevation: isSelected ? 4 : 0,
          showCheckmark: false,
        );
      }).toList(),
    );
  }

  bool _canProceed() {
    switch (_currentPage) {
      case 0: return name.isNotEmpty && age > 0;
      case 1: return educationLevel.isNotEmpty;
      case 2: return stream.isNotEmpty;
      case 3: return learningPreferences.isNotEmpty;
      case 4: return interests.isNotEmpty;
      case 5: return aiPersonality.isNotEmpty;
      default: return false;
    }
  }
}
