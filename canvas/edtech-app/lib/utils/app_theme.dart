import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The app's colour system.
///
/// Everything lives here as a named token. Screens previously hardcoded 126
/// literal colours between them, which is why three different indigos
/// (`6366F1`, `6C63FF`, `8B5CF6`), four unrelated dark surfaces and four grey
/// ramps were all in use at once. Add a token here rather than a literal in a
/// widget, so the palette can only drift in one place.
///
/// Structure:
///  * [brand] carries identity. One hue, several steps.
///  * [ink] and [paper] are the neutral ramp, all from one slightly cool
///    family so greys never clash.
///  * The semantic colours state meaning, not decoration.
///  * [subjectPalette] is a deliberately harmonised set for user-coloured
///    content, replacing the assorted bright hues that were scattered around.
class AppTheme {
  // ---------------------------------------------------------------- brand

  /// Palest brand wash, for tinted surfaces behind brand content.
  static const Color brand50 = Color(0xFFF1EFFE);
  static const Color brand100 = Color(0xFFE3DEFD);
  static const Color brand200 = Color(0xFFC7BDFB);

  /// Brand at rest. Use for icons and text on light surfaces.
  static const Color brand400 = Color(0xFF8F7DF2);

  /// The primary brand colour. Buttons, active states, focus.
  static const Color brand500 = Color(0xFF6C5AE0);

  /// Pressed and hovered states, and text that must hold contrast on
  /// [brand50].
  static const Color brand600 = Color(0xFF5A46CC);
  static const Color brand700 = Color(0xFF4736A8);

  // ------------------------------------------------------------- neutrals

  /// Page backgrounds and card fills, lightest first.
  static const Color paper = Color(0xFFFFFFFF);
  static const Color paperSunken = Color(0xFFF7F7FB);
  static const Color paperMuted = Color(0xFFEFEFF6);

  /// Hairlines and dividers on light surfaces.
  static const Color line = Color(0xFFE4E4EF);

  /// Text and icons, lightest first. `ink900` is the strongest.
  static const Color ink300 = Color(0xFFA6A6BA);
  static const Color ink500 = Color(0xFF6E6E85);
  static const Color ink700 = Color(0xFF3D3D52);
  static const Color ink900 = Color(0xFF1B1B2A);

  /// Dark-theme equivalents, same family so the two themes agree.
  static const Color inkBackground = Color(0xFF0F0F17);
  static const Color inkSurface = Color(0xFF191927);
  static const Color inkSurfaceRaised = Color(0xFF232336);
  static const Color inkLine = Color(0xFF2C2C40);

  // ------------------------------------------------------------- semantic

  static const Color success = Color(0xFF19A974);
  static const Color warning = Color(0xFFE08A1E);
  static const Color danger = Color(0xFFD64550);
  static const Color info = Color(0xFF3B82C4);

  /// Streaks and rewards. Warm, and deliberately the only hot colour in the
  /// palette so it always reads as "achievement".
  static const Color ember = Color(0xFFF08A3C);

  // ------------------------------------------------- backwards-compatible

  /// Retained so existing call sites keep working. Prefer the tokens above.
  static const Color primaryAccent = brand500;
  static const Color secondaryAccent = Color(0xFFCB6BA5);
  static const Color tertiaryAccent = Color(0xFF3FA9A0);
  static const Color darkBackground = inkBackground;
  static const Color lightBackground = paperSunken;
  static const Color darkSurface = inkSurface;
  static const Color lightSurface = paper;

  // ------------------------------------------------------------- subjects

  /// Harmonised set for user-created content (subjects, quick actions).
  ///
  /// Chosen at a common lightness and saturation so no single card shouts
  /// over its neighbours, which the previous mix of neon red, mint and
  /// yellow did.
  static const List<Color> subjectPalette = <Color>[
    brand500,
    Color(0xFF3FA9A0), // teal
    Color(0xFFCB6BA5), // rose
    Color(0xFFE0A020), // amber
    Color(0xFF4A8FD4), // sky
    Color(0xFF7BA23F), // moss
    Color(0xFFB4664A), // clay
    Color(0xFF7C6BC4), // iris
  ];

  // ------------------------------------------------------------ gradients

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [brand500, Color(0xFF9A6BE0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Warm gradient for streak and reward surfaces.
  static const LinearGradient fireGradient = LinearGradient(
    colors: [Color(0xFFF5A93F), ember],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient glassGradient = LinearGradient(
    colors: [
      Colors.white.withValues(alpha: 0.08),
      Colors.white.withValues(alpha: 0.02),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkSurfaceGradient = LinearGradient(
    colors: [inkSurface, Color(0xFF232336)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Soft light-theme page wash, used behind hero areas.
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF4F2FE), // brand tint
      Color(0xFFFDF7F2), // warm cream
      Color(0xFFF2F5FB), // cool tint
    ],
  );

  /// The pastel wash behind the streak card in light mode.
  static const LinearGradient streakGradientLight = LinearGradient(
    colors: [
      Color(0xFFEDE9FE), // brand wash
      Color(0xFFF6ECFB), // soft rose
      Color(0xFFFEF3E6), // warm cream
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient streakGradientDark = LinearGradient(
    colors: [Color(0xFF232336), Color(0xFF16161F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --------------------------------------------------------------- themes

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: paperSunken,
      primaryColor: brand500,
      dividerColor: line,
      colorScheme: const ColorScheme.light(
        primary: brand500,
        secondary: tertiaryAccent,
        surface: paper,
        onSurface: ink900,
        error: danger,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: ink900,
        displayColor: ink900,
      ),
      cardTheme: CardThemeData(
        color: paper,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: ink900),
        titleTextStyle: TextStyle(
          color: ink900,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink900,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: inkBackground,
      primaryColor: brand500,
      dividerColor: inkLine,
      colorScheme: const ColorScheme.dark(
        primary: brand400,
        secondary: tertiaryAccent,
        surface: inkSurface,
        onSurface: Colors.white,
        error: danger,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: inkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: inkSurface,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
