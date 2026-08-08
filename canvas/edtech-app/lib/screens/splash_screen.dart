import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';
import 'onboarding/onboarding_screen.dart';

/// Launch screen shown while auth state is resolved.
///
/// The mark is drawn in code rather than loaded from a Lottie file: the
/// bundled `education_loading.json` is a single-layer placeholder that renders
/// as a small rectangle, which looked broken sitting inside a 200px circle.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0, 0.7, curve: Curves.easeOut),
  );

  // Settles slightly past its final size, so the mark lands rather than
  // simply appearing.
  late final Animation<double> _scale = Tween<double>(
    begin: 0.86,
    end: 1,
  ).animate(
    CurvedAnimation(parent: _intro, curve: Curves.easeOutBack),
  );

  late final Animation<double> _rise = Tween<double>(
    begin: 18,
    end: 0,
  ).animate(
    CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.2, 1, curve: Curves.easeOutCubic),
    ),
  );

  @override
  void initState() {
    super.initState();
    _intro.forward();
    _checkAuthStatus();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    try {
      await Future.delayed(const Duration(milliseconds: 2200));

      if (!mounted) return;

      final authService = AuthService();
      bool isLoggedIn = false;

      try {
        isLoggedIn = await authService.isLoggedIn();
      } catch (e) {
        debugPrint('Auth check failed: $e');
        isLoggedIn = false;
      }

      if (!mounted) return;

      if (isLoggedIn) {
        try {
          final userProvider =
              Provider.of<UserProvider>(context, listen: false);
          await userProvider.init();

          if (!mounted) return;
          final user = userProvider.currentUser;

          if (user != null && user.educationLevel.isEmpty) {
            _go(const OnboardingScreen());
          } else {
            _go(const HomeScreen());
          }
        } catch (e) {
          debugPrint('User initialization failed: $e');
          _go(const LoginScreen());
        }
      } else {
        _go(const LoginScreen());
      }
    } catch (e) {
      debugPrint('Splash screen error: $e');
      _go(const LoginScreen());
    }
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        // A plain cross-fade: the default zoom transition briefly renders the
        // outgoing page inset from the edge, which reads as a misaligned
        // splash in a screenshot.
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // SizedBox.expand guarantees the gradient covers the whole window, so
      // no strip of scaffold background can show along an edge.
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.inkBackground,
                      Color(0xFF17172A),
                      Color(0xFF1E1838),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF4F2FE),
                      Color(0xFFFDF7F2),
                      Color(0xFFF2F5FB),
                    ],
                  ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // True centre, independent of the footer below.
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: AnimatedBuilder(
                      animation: _intro,
                      builder: (context, child) => Opacity(
                        opacity: _fade.value,
                        child: Transform.translate(
                          offset: Offset(0, _rise.value),
                          child: child,
                        ),
                      ),
                      child: _buildBrand(isDark),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 40,
                  child: FadeTransition(
                    opacity: _fade,
                    child: _buildFooter(isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrand(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(scale: _scale, child: const _LogoMark()),
        const SizedBox(height: 30),
        ShaderMask(
          shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
          child: const Text(
            'EduAI',
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              fontSize: 44,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              // Painted over by the shader; must be opaque white.
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your personalised learning companion',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
            color: isDark ? Colors.white70 : AppTheme.ink500,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 128,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : AppTheme.brand500.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryAccent),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Getting things ready',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            color: isDark ? Colors.white38 : AppTheme.ink300,
          ),
        ),
      ],
    );
  }
}

/// The app mark: a gradient squircle with a graduation cap.
///
/// Drawn with framework widgets so it renders identically everywhere and
/// cannot fail to load.
class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryAccent.withValues(alpha: 0.34),
            blurRadius: 32,
            spreadRadius: -4,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.school_rounded,
          size: 52,
          color: Colors.white,
        ),
      ),
    );
  }
}
