import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/user_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../onboarding/onboarding_screen.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  AuthService? _authService;
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  AuthService get authService {
    _authService ??= AuthService();
    return _authService!;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _skipLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // Persist a guest session so it survives an app restart instead of
      // always bouncing back to this screen / a blank onboarding form.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', AuthService.guestUserId);

      if (!mounted) return;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.init();

      if (!mounted) return;
      final user = userProvider.currentUser;
      final hasCompletedOnboarding =
          user != null && user.educationLevel.isNotEmpty;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => hasCompletedOnboarding
              ? const HomeScreen()
              : const OnboardingScreen(),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final userProfile = await authService.signInWithGoogle();

      if (!mounted) return;

      if (userProfile != null) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.init();

        if (userProfile.educationLevel.isEmpty) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign in failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: Stack(
        children: [
          // Background Elements
          if (!isDark)
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryAccent.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryAccent.withOpacity(0.2),
                      blurRadius: 100,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
          if (!isDark)
            Positioned(
              top: size.height * 0.4,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.secondaryAccent.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.secondaryAccent.withOpacity(0.2),
                      blurRadius: 80,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
            ),

          SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(height: 20),

                    // Hero Image Section
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        height: size.height * 0.35,
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Glow behind image
                            Container(
                              width: 250,
                              height: 250,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppTheme.primaryAccent.withOpacity(0.2),
                                    blurRadius: 60,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                            // The Image
                            Hero(
                              tag: 'login_hero',
                              child: Image.asset(
                                'assets/images/login_hero_v2.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Bottom Sheet Section
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white.withOpacity(0.8),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(40),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 30,
                                offset: const Offset(0, -10),
                              ),
                            ],
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.white,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Title
                              Text(
                                'Unlock Your\nPotential',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1D2E),
                                  letterSpacing: -1,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Subtitle
                              Text(
                                'Your personal AI tutor that adapts to your unique learning style.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey[600],
                                  height: 1.5,
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Features Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildFeatureIcon(
                                      Icons.auto_awesome, Colors.amber),
                                  const SizedBox(width: 24),
                                  _buildFeatureIcon(
                                      Icons.psychology, AppTheme.primaryAccent),
                                  const SizedBox(width: 24),
                                  _buildFeatureIcon(Icons.rocket_launch,
                                      AppTheme.secondaryAccent),
                                ],
                              ),

                              const SizedBox(height: 40),

                              // Google Button
                              _isLoading
                                  ? const CircularProgressIndicator()
                                  : SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: _signInWithGoogle,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDark
                                              ? Colors.white
                                              : const Color(0xFF1A1D2E),
                                          foregroundColor: isDark
                                              ? Colors.black
                                              : Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Image.asset(
                                              'assets/images/google_logo.png',
                                              height: 24,
                                              width: 24,
                                              errorBuilder: (context, error,
                                                      stackTrace) =>
                                                  Icon(
                                                Icons.login_rounded,
                                                size: 24,
                                                color: isDark
                                                    ? Colors.black
                                                    : Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Text(
                                              'Continue with Google',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                              const SizedBox(height: 16),

                              // Skip Button
                              TextButton(
                                onPressed: _isLoading ? null : _skipLogin,
                                child: Text(
                                  'Skip for now',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.grey[500],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }
}
