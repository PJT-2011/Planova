// ============================================================
// app_theme.dart — Planova Design System v3
// Inspired by: BrainByte E-Learning Figma (NAM Design Studio)
// Palette: Vivid Blue (your brand) · Near-Black · Lavender Surface
// Typography: Urbanist (headings) · Inter (body)
// Dual-mode: Light (primary) + Dark (full parity)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ────────────────────────────────────────────────────────────
// 1. RAW PALETTE
// ────────────────────────────────────────────────────────────
class _Palette {
  // ── Vivid Blue Scale (your brand, maps to BrainByte's purple) ──
  static const blue600 = Color(0xFF1450A8); // deep — light mode primary
  static const blue500 = Color(0xFF1A6ADB); // vibrant — main CTA
  static const blue400 = Color(0xFF3B82F6); // bright — dark mode primary
  static const blue300 = Color(0xFF60A5FA); // light accent
  static const blue100 = Color(0xFFBFDBFE); // tint
  static const blue050 = Color(0xFFEFF6FF); // wash

  // ── BrainByte-inspired indigo-blue gradient tones ──
  // (their #6D57FC → your brand blue mapping)
  static const indigoBlue700 = Color(0xFF0D3366); // gradient deep end
  static const indigoBlue500 = Color(0xFF1A6ADB); // gradient mid
  static const indigoBlue400 = Color(0xFF3B82F6); // gradient bright end

  // ── Lavender Surface (BrainByte's #F0EEFF → blue-tinted equivalent) ──
  static const lavender100 = Color(0xFFEEF4FF); // page bg light (was #F0EEFF)
  static const lavender200 = Color(0xFFDCEAFF); // section bg
  static const lavenderTag = Color(0xFFE0EDFF); // tag / chip fill

  // ── Near-Black / Dark (BrainByte's #0C0A1C mapped to blue-dark) ──
  static const dark950 = Color(0xFF0A1628); // page bg dark
  static const dark900 = Color(0xFF0D1E36); // scaffold dark
  static const dark850 = Color(0xFF1C2942); // card dark  ← main card
  static const dark800 = Color(0xFF243450); // elevated card
  static const dark700 = Color(0xFF1C2942); // input fill dark
  static const dark600 = Color(0xFF243450); // divider / border dark
  static const dark500 = Color(0xFF304263); // muted icon

  // ── White / Light ──
  static const white = Color(0xFFFFFFFF);
  static const offWhite = Color(0xFFFDFDFF); // BrainByte's #FDFDFF
  static const light200 = Color(0xFFE5EBF5);
  static const light300 = Color(0xFFCDD8EE);
  static const light400 = Color(0xFF8FA3C8); // muted text light

  // ── Semantic ──
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  // ── Text ──
  static const textPrimary = Color(0xFF0C1A30); // near-black (blue-tinted)
  static const textSecondary = Color(0xFF4A6080);
  static const textTertiary = Color(0xFF8FA3C8);
}

// ────────────────────────────────────────────────────────────
// 2. SEMANTIC COLOR TOKENS
// ────────────────────────────────────────────────────────────
class AppColors {
  const AppColors._({
    required this.primary,
    required this.primaryVariant,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.background,
    required this.backgroundSecondary,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceOverlay,
    required this.onBackground,
    required this.onSurface,
    required this.onSurfaceSecondary,
    required this.onSurfaceTertiary,
    required this.divider,
    required this.border,
    required this.borderSubtle,
    required this.iconDefault,
    required this.iconMuted,
    required this.tabActive,
    required this.tabInactive,
    required this.navBarBackground,
    required this.navBarBorder,
    required this.inputFill,
    required this.inputBorder,
    required this.inputHint,
    required this.chipFill,
    required this.chipText,
    required this.tagFill,
    required this.tagText,
    required this.scrim,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.success,
    required this.warning,
    required this.error,
    required this.bottomSheetBackground,
    required this.heroGradientStart,
    required this.heroGradientEnd,
    required this.cardBackground,
    required this.cardBorder,
    required this.roomCardBackground,
    required this.floorPlanBackground,
    required this.pinLabel,
    required this.pinLabelText,
    required this.statusBarBrightness,
  });

  final Color primary;
  final Color primaryVariant;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;

  final Color background;
  final Color backgroundSecondary;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceOverlay;

  final Color onBackground;
  final Color onSurface;
  final Color onSurfaceSecondary;
  final Color onSurfaceTertiary;

  final Color divider;
  final Color border;
  final Color borderSubtle;

  final Color iconDefault;
  final Color iconMuted;

  final Color tabActive;
  final Color tabInactive;
  final Color navBarBackground;
  final Color navBarBorder;

  final Color inputFill;
  final Color inputBorder;
  final Color inputHint;

  final Color chipFill;
  final Color chipText;
  final Color tagFill;
  final Color tagText;

  final Color scrim;
  final Color shimmerBase;
  final Color shimmerHighlight;

  final Color success;
  final Color warning;
  final Color error;

  final Color bottomSheetBackground;

  /// Hero gradient — top of login, splash, onboarding header
  final Color heroGradientStart;
  final Color heroGradientEnd;

  final Color cardBackground;
  final Color cardBorder;

  /// Kept for backwards-compat with room_mapping_screen, navigation_screen, etc.
  final Color roomCardBackground;
  final Color floorPlanBackground;
  final Color pinLabel;
  final Color pinLabelText;

  final Brightness statusBarBrightness;

  // ═══════════════════════════════════════════════════════════
  // LIGHT THEME
  // Lavender-tinted white bg · deep blue text · vivid blue CTA
  // ═══════════════════════════════════════════════════════════
  static const AppColors light = AppColors._(
    primary: _Palette.blue500,
    primaryVariant: _Palette.blue600,
    onPrimary: _Palette.white,
    primaryContainer: _Palette.lavender100,
    onPrimaryContainer: _Palette.blue600,

    background: _Palette.lavender100, // #EEF4FF — BrainByte surface tint
    backgroundSecondary: _Palette.lavender200,
    surface: _Palette.offWhite, // #FDFDFF — cards
    surfaceElevated: _Palette.white,

    onBackground: _Palette.textPrimary,
    onSurface: _Palette.textPrimary,
    onSurfaceSecondary: _Palette.textSecondary,
    onSurfaceTertiary: _Palette.textTertiary,

    divider: Color(0xFFDDE5F5),
    border: Color(0xFFCDD8EE),
    borderSubtle: Color(0xFFE5EDF8),

    iconDefault: _Palette.textPrimary,
    iconMuted: _Palette.textTertiary,

    tabActive: _Palette.blue500,
    tabInactive: _Palette.textTertiary,
    navBarBackground: _Palette.white,
    navBarBorder: Color(0xFFE5EDF8),

    inputFill: _Palette.offWhite,
    inputBorder: Color(0xFFCDD8EE),
    inputHint: _Palette.textTertiary,

    chipFill: _Palette.lavenderTag,
    chipText: _Palette.blue600,
    tagFill: _Palette.lavenderTag,
    tagText: _Palette.blue600,

    scrim: Color(0x80081020),
    shimmerBase: Color(0xFFE5EDF8),
    shimmerHighlight: _Palette.lavender100,

    success: _Palette.success,
    warning: _Palette.warning,
    error: _Palette.error,

    bottomSheetBackground: _Palette.white,

    heroGradientStart: _Palette.indigoBlue700, // deep blue
    heroGradientEnd: _Palette.indigoBlue400, // bright blue

    cardBackground: _Palette.offWhite,
    cardBorder: Color(0xFFDDE5F5),

    // Backwards-compat tokens (used by room_mapping_screen, navigation_screen, etc.)
    secondary: _Palette.blue400,
    onSecondary: _Palette.white,
    surfaceOverlay: _Palette.lavender200,
    roomCardBackground: _Palette.offWhite,
    floorPlanBackground: _Palette.white,
    pinLabel: _Palette.blue500,
    pinLabelText: _Palette.white,

    statusBarBrightness: Brightness.dark,
  );

  // ═══════════════════════════════════════════════════════════
  // DARK THEME
  // Near-black blue bg · white text · vivid blue CTA
  // ═══════════════════════════════════════════════════════════
  static const AppColors dark = AppColors._(
    primary: _Palette.blue400,
    primaryVariant: _Palette.blue500,
    onPrimary: _Palette.white,
    primaryContainer: _Palette.dark800,
    onPrimaryContainer: _Palette.blue300,

    background: _Palette.dark950,
    backgroundSecondary: _Palette.dark900,
    surface: _Palette.dark850,
    surfaceElevated: _Palette.dark800,

    onBackground: _Palette.white,
    onSurface: Color(0xFFF0F4FF),
    onSurfaceSecondary: Color(0xFF8FA3C8),
    onSurfaceTertiary: Color(0xFF4A6080),

    divider: Color(0x1AFFFFFF),
    border: Color(0x26FFFFFF),
    borderSubtle: Color(0x0FFFFFFF),

    iconDefault: Color(0xFFF0F4FF),
    iconMuted: Color(0xFF4A6080),

    tabActive: _Palette.blue400,
    tabInactive: Color(0xFF4A6080),
    navBarBackground: _Palette.dark850,
    navBarBorder: Color(0x1AFFFFFF),

    inputFill: _Palette.dark800,
    inputBorder: Color(0x26FFFFFF),
    inputHint: Color(0xFF4A6080),

    chipFill: _Palette.dark800,
    chipText: Color(0xFFB0CDFF),
    tagFill: _Palette.dark700,
    tagText: _Palette.blue300,

    scrim: Color(0xCC000D1A),
    shimmerBase: _Palette.dark800,
    shimmerHighlight: _Palette.dark600,

    success: _Palette.success,
    warning: _Palette.warning,
    error: _Palette.error,

    bottomSheetBackground: _Palette.dark850,

    heroGradientStart: _Palette.indigoBlue700,
    heroGradientEnd: _Palette.indigoBlue500,

    cardBackground: _Palette.dark850,
    cardBorder: Color(0x26FFFFFF),

    // Backwards-compat tokens
    secondary: _Palette.blue300,
    onSecondary: _Palette.dark950,
    surfaceOverlay: _Palette.dark700,
    roomCardBackground: _Palette.dark850,
    floorPlanBackground: _Palette.white,
    pinLabel: _Palette.blue400,
    pinLabelText: _Palette.white,

    statusBarBrightness: Brightness.light,
  );
}

// ────────────────────────────────────────────────────────────
// 3. TYPOGRAPHY  (Urbanist headings · Inter body — BrainByte style)
// ────────────────────────────────────────────────────────────
class AppTextTheme {
  // Base scale — colour applied per-theme via .apply()
  static TextTheme get _base => const TextTheme(
    // Display — hero numbers, splash title (Urbanist feel via bold weight)
    displayLarge: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
      height: 1.12,
    ),
    displayMedium: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
      height: 1.18,
    ),
    displaySmall: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.22,
    ),

    // Headline — screen titles, card hero text
    headlineLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      height: 1.3,
    ),
    headlineMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.35,
    ),
    headlineSmall: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),

    // Title — card titles, nav bar, greeting
    titleLarge: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    titleMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.45,
    ),
    titleSmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.45,
    ),

    // Body — descriptions, list content (Inter feel)
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.6,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.55,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),

    // Label — buttons, chips, badges, tab labels
    labelLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
    ),
  );

  static TextTheme forColors(AppColors c) =>
      _base.apply(bodyColor: c.onSurface, displayColor: c.onBackground);
}

// ────────────────────────────────────────────────────────────
// 4. MAIN ThemeData FACTORY
// ────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  /// Retrieve semantic tokens anywhere in the widget tree.
  static AppColors colors(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;

  // ── Shared shape helpers ──
  static final _cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
  );
  static final _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  static final _inputShape = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide.none,
  );

  // ══════════════════════════════════════════════════════════
  // LIGHT ThemeData
  // ══════════════════════════════════════════════════════════
  static ThemeData get light {
    const c = AppColors.light;
    final tt = AppTextTheme.forColors(c);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      colorScheme: ColorScheme.light(
        primary: c.primary,
        onPrimary: c.onPrimary,
        primaryContainer: c.primaryContainer,
        onPrimaryContainer: c.onPrimaryContainer,
        secondary: c.primaryVariant,
        onSecondary: c.onPrimary,
        surface: c.surface,
        onSurface: c.onSurface,
        surfaceContainerHighest: c.surfaceElevated,
        error: c.error,
        onError: _Palette.white,
        outline: c.border,
        outlineVariant: c.borderSubtle,
      ),

      scaffoldBackgroundColor: c.background,
      textTheme: tt,

      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.onBackground,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: c.border,
        centerTitle: false,
        titleTextStyle: tt.titleLarge?.copyWith(color: c.onBackground),
        iconTheme: IconThemeData(color: c.iconDefault, size: 24),
        actionsIconTheme: IconThemeData(color: c.iconDefault, size: 24),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: _Palette.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.navBarBackground,
        selectedItemColor: c.tabActive,
        unselectedItemColor: c.tabInactive,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: tt.labelSmall?.copyWith(
          color: c.tabActive,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: tt.labelSmall?.copyWith(color: c.tabInactive),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: c.tabActive,
        unselectedLabelColor: c.tabInactive,
        indicatorColor: c.tabActive,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: c.divider,
        labelStyle: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: tt.titleSmall,
      ),

      cardTheme: CardThemeData(
        color: c.cardBackground,
        elevation: 0,
        shape: _cardShape,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x14000000),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          minimumSize: const Size(double.infinity, 56),
          shape: _buttonShape,
          elevation: 0,
          textStyle: tt.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(double.infinity, 56),
          shape: _buttonShape,
          side: BorderSide(color: c.primary, width: 1.5),
          textStyle: tt.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          textStyle: tt.labelLarge,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: _buttonShape,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.inputFill,
        border: _inputShape,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.inputBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.error, width: 1.5),
        ),
        hintStyle: tt.bodyMedium?.copyWith(color: c.inputHint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        prefixIconColor: c.iconMuted,
        suffixIconColor: c.iconMuted,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bottomSheetBackground,
        modalBackgroundColor: c.bottomSheetBackground,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        elevation: 2,
        modalBarrierColor: c.scrim,
        dragHandleColor: c.border,
        dragHandleSize: const Size(40, 4),
        showDragHandle: true,
      ),

      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),

      chipTheme: ChipThemeData(
        backgroundColor: c.chipFill,
        labelStyle: tt.labelMedium?.copyWith(color: c.chipText),
        side: BorderSide(color: c.borderSubtle, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.onBackground,
        contentTextStyle: tt.bodyMedium?.copyWith(color: c.background),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
        actionTextColor: c.primary,
        elevation: 4,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        elevation: 2,
        shadowColor: const Color(0x1A000000),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: tt.headlineSmall?.copyWith(color: c.onSurface),
        contentTextStyle: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
      ),

      iconTheme: IconThemeData(color: c.iconDefault, size: 24),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceElevated,
        circularTrackColor: Colors.transparent,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? c.onPrimary
              : c.onSurfaceTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? c.primary : c.surfaceElevated,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? Colors.transparent : c.border,
        ),
      ),

      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: c.iconDefault,
        textColor: c.onSurface,
        subtitleTextStyle: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
        minVerticalPadding: 12,
      ),

      splashColor: c.primary.withValues(alpha: 0.06),
      highlightColor: c.primary.withValues(alpha: 0.04),
      splashFactory: InkRipple.splashFactory,
    );
  }

  // ══════════════════════════════════════════════════════════
  // DARK ThemeData
  // ══════════════════════════════════════════════════════════
  static ThemeData get dark {
    const c = AppColors.dark;
    final tt = AppTextTheme.forColors(c);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      colorScheme: ColorScheme.dark(
        primary: c.primary,
        onPrimary: c.onPrimary,
        primaryContainer: c.primaryContainer,
        onPrimaryContainer: c.onPrimaryContainer,
        secondary: c.primaryVariant,
        onSecondary: c.onPrimary,
        surface: c.surface,
        onSurface: c.onSurface,
        surfaceContainerHighest: c.surfaceElevated,
        error: c.error,
        onError: _Palette.white,
        outline: c.border,
        outlineVariant: c.borderSubtle,
      ),

      scaffoldBackgroundColor: c.background,
      textTheme: tt,

      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.onBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: tt.titleLarge?.copyWith(color: c.onBackground),
        iconTheme: IconThemeData(color: c.iconDefault, size: 24),
        actionsIconTheme: IconThemeData(color: c.iconDefault, size: 24),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: _Palette.dark950,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.navBarBackground,
        selectedItemColor: c.tabActive,
        unselectedItemColor: c.tabInactive,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: tt.labelSmall?.copyWith(
          color: c.tabActive,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: tt.labelSmall?.copyWith(color: c.tabInactive),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: c.tabActive,
        unselectedLabelColor: c.tabInactive,
        indicatorColor: c.tabActive,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: c.divider,
        labelStyle: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: tt.titleSmall,
      ),

      cardTheme: CardThemeData(
        color: c.cardBackground,
        elevation: 0,
        shape: _cardShape,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          minimumSize: const Size(double.infinity, 56),
          shape: _buttonShape,
          elevation: 0,
          textStyle: tt.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(double.infinity, 56),
          shape: _buttonShape,
          side: BorderSide(color: c.primary, width: 1.5),
          textStyle: tt.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          textStyle: tt.labelLarge,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: _buttonShape,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.inputFill,
        border: _inputShape,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.inputBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.error, width: 1.5),
        ),
        hintStyle: tt.bodyMedium?.copyWith(color: c.inputHint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        prefixIconColor: c.iconMuted,
        suffixIconColor: c.iconMuted,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bottomSheetBackground,
        modalBackgroundColor: c.bottomSheetBackground,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        elevation: 0,
        modalBarrierColor: c.scrim,
        dragHandleColor: c.border,
        dragHandleSize: const Size(40, 4),
        showDragHandle: true,
      ),

      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),

      chipTheme: ChipThemeData(
        backgroundColor: c.chipFill,
        labelStyle: tt.labelMedium?.copyWith(color: c.chipText),
        side: BorderSide(color: c.border, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceElevated,
        contentTextStyle: tt.bodyMedium?.copyWith(color: c.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
        actionTextColor: c.primary,
        elevation: 4,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceElevated,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: tt.headlineSmall?.copyWith(color: c.onSurface),
        contentTextStyle: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
      ),

      iconTheme: IconThemeData(color: c.iconDefault, size: 24),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surface,
        circularTrackColor: Colors.transparent,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? c.onPrimary
              : c.onSurfaceTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.surface,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? Colors.transparent : c.border,
        ),
      ),

      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: c.iconDefault,
        textColor: c.onSurface,
        subtitleTextStyle: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
        minVerticalPadding: 12,
      ),

      splashColor: c.primary.withValues(alpha: 0.08),
      highlightColor: c.primary.withValues(alpha: 0.05),
      splashFactory: InkRipple.splashFactory,
    );
  }
}

// ────────────────────────────────────────────────────────────
// 5. GRADIENT HELPERS
// ────────────────────────────────────────────────────────────

/// Hero gradient — used in login header, onboarding, splash
/// Deep blue → vivid blue (BrainByte-inspired, your blue palette)
LinearGradient heroGradient({
  AlignmentGeometry begin = Alignment.topLeft,
  AlignmentGeometry end = Alignment.bottomRight,
}) => LinearGradient(
  colors: const [_Palette.indigoBlue700, _Palette.indigoBlue400],
  begin: begin,
  end: end,
);

/// Soft card accent gradient — used on featured cards
LinearGradient cardAccentGradient() => const LinearGradient(
  colors: [Color(0xFF1A6ADB), Color(0xFF3B82F6)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Dark overlay gradient for image cards (text readability)
LinearGradient imageDarkOverlay() => const LinearGradient(
  colors: [Colors.transparent, Color(0xCC081020)],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

// ────────────────────────────────────────────────────────────
// 6. CARD DECORATIONS
// ────────────────────────────────────────────────────────────

BoxDecoration lightCardDecoration({
  double radius = 20,
  Color? border,
}) => BoxDecoration(
  color: _Palette.offWhite,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: border ?? const Color(0xFFDDE5F5), width: 1),
  boxShadow: const [
    BoxShadow(color: Color(0x0A0C1A30), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x050C1A30), blurRadius: 24, offset: Offset(0, 8)),
  ],
);

// Dark card: #1C2942 is visibly lighter than the #080E1A scaffold,
// giving clear card separation without being too bright.
BoxDecoration darkCardDecoration({double radius = 20, Color? border}) =>
    BoxDecoration(
      color: const Color(0xFF1C2942),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border ?? const Color(0x1AFFFFFF), width: 1),
    );

BoxDecoration heroCardDecoration({double radius = 20}) => BoxDecoration(
  borderRadius: BorderRadius.circular(radius),
  gradient: cardAccentGradient(),
  boxShadow: [
    BoxShadow(
      color: _Palette.blue500.withValues(alpha: 0.30),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ],
);

// ────────────────────────────────────────────────────────────
// 7. SPACING & RADIUS SCALES
// ────────────────────────────────────────────────────────────
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20; // BrainByte card default
  static const double xl = 24;
  static const double xxl = 28;
  static const double full = 999;
}

// ────────────────────────────────────────────────────────────
// 8. SHADOW TOKENS
// ────────────────────────────────────────────────────────────
class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A0C1A30), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x050C1A30), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> modal = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 32, offset: Offset(0, -6)),
  ];

  static List<BoxShadow> primaryGlow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.30),
      blurRadius: 20,
      spreadRadius: 0,
      offset: const Offset(0, 6),
    ),
  ];
}
