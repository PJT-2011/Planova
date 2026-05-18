// ============================================================
// app_theme.dart
// Planova Mobile — Design System v2
// Inspired by: EV Map, Travelco, Task Dashboard, Finance App
// Palette: True Black · Pure White · Vivid Blue
// Dual-mode: Dark (primary) + Light (full parity)
// ============================================================
//
// USAGE
//   In main.dart:
//     import 'app_theme.dart';
//
//     MaterialApp(
//       theme:      AppTheme.light,
//       darkTheme:  AppTheme.dark,
//       themeMode:  ThemeMode.system,
//       ...
//     )
//
//   In any widget:
//     AppTheme.colors(context).primary
//     Theme.of(context).colorScheme.primary
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ────────────────────────────────────────────────────────────
// 1. RAW PALETTE  (internal — never use directly in widgets)
// ────────────────────────────────────────────────────────────
class _Palette {
  // ── Vivid Blue Scale (primary accent) ──
  static const blue950 = Color(0xFF020B18);
  static const blue900 = Color(0xFF061428);
  static const blue800 = Color(0xFF0A2244);
  static const blue700 = Color(0xFF0D3366);
  static const blue600 = Color(0xFF1450A8); // deep royal — light mode primary
  static const blue500 = Color(0xFF1A6ADB); // vibrant — main CTA
  static const blue400 = Color(0xFF3B82F6); // bright — dark mode primary
  static const blue300 = Color(0xFF60A5FA); // light accent
  static const blue200 = Color(0xFF93C5FD); // pale accent
  static const blue100 = Color(0xFFBFDBFE); // tint
  static const blue050 = Color(0xFFEFF6FF); // wash

  // ── True Black / Near-Black (dark surfaces) ──
  static const dark900 = Color(0xFF111111); // page bg dark
  static const dark850 = Color(0xFF161616); // scaffold
  static const dark800 = Color(0xFF1C1C1E); // card dark (iOS system dark)
  static const dark750 = Color(0xFF222222); // elevated card
  static const dark700 = Color(0xFF2A2A2A); // input fill dark
  static const dark600 = Color(0xFF363636); // divider / border
  static const dark500 = Color(0xFF484848); // muted icon / tertiary

  // ── White / Light (light surfaces) ──
  static const white = Color(0xFFFFFFFF);
  static const light050 = Color(0xFFF9FAFB); // page bg light
  static const light100 = Color(0xFFF3F4F6); // section bg
  static const light200 = Color(0xFFE5E7EB); // card border light
  static const light300 = Color(0xFFD1D5DB); // divider light
  static const light400 = Color(0xFF9CA3AF); // muted text / hint

  // ── Neutral text ──
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);

  // ── Semantic ──
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
}

// ────────────────────────────────────────────────────────────
// 2. SEMANTIC COLOR TOKENS
// ────────────────────────────────────────────────────────────
class AppColors {
  const AppColors._({
    required this.primary,
    required this.primaryVariant,
    required this.primaryContainer,
    required this.onPrimary,
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
    required this.inputFill,
    required this.inputBorder,
    required this.inputHint,
    required this.chipFill,
    required this.chipText,
    required this.tagFill,
    required this.scrim,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.success,
    required this.warning,
    required this.error,
    required this.navBarBackground,
    required this.navBarBorder,
    required this.statusBarBrightness,
    required this.bottomSheetBackground,
    required this.qrScannerOverlay,
    required this.roomCardBackground,
    required this.roomCardBorder,
    required this.floorPlanBackground,
    required this.pinBackground,
    required this.pinLabel,
    required this.pinLabelText,
    required this.badgeBackground,
    required this.badgeText,
  });

  final Color primary;
  final Color primaryVariant;
  final Color primaryContainer;
  final Color onPrimary;
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

  final Color inputFill;
  final Color inputBorder;
  final Color inputHint;

  final Color chipFill;
  final Color chipText;
  final Color tagFill;

  final Color scrim;
  final Color shimmerBase;
  final Color shimmerHighlight;

  final Color success;
  final Color warning;
  final Color error;

  final Color navBarBackground;
  final Color navBarBorder;
  final Brightness statusBarBrightness;
  final Color bottomSheetBackground;
  final Color qrScannerOverlay;
  final Color roomCardBackground;
  final Color roomCardBorder;
  final Color floorPlanBackground;
  final Color pinBackground;
  final Color pinLabel;
  final Color pinLabelText;
  final Color badgeBackground;
  final Color badgeText;

  // ═══════════════════════════════════════════════════════════
  // DARK THEME
  // Inspired by EV Map (Image 1) + Finance App (Image 4)
  // True black backgrounds, vivid blue accent, white text,
  // dark elevated cards with subtle 8% white borders
  // ═══════════════════════════════════════════════════════════
  static const AppColors dark = AppColors._(
    primary: _Palette.blue400,
    primaryVariant: _Palette.blue500,
    primaryContainer: _Palette.blue800,
    onPrimary: _Palette.white,
    secondary: _Palette.blue200,
    onSecondary: _Palette.blue900,

    background: _Palette.dark900,
    backgroundSecondary: _Palette.dark850,
    surface: _Palette.dark800,
    surfaceElevated: _Palette.dark750,
    surfaceOverlay: _Palette.dark700,

    onBackground: _Palette.white,
    onSurface: Color(0xFFF2F2F2),
    onSurfaceSecondary: Color(0xFFAAAAAA),
    onSurfaceTertiary: Color(0xFF666666),

    divider: Color(0x14FFFFFF),
    border: Color(0x1FFFFFFF),
    borderSubtle: Color(0x0DFFFFFF),

    iconDefault: Color(0xFFF2F2F2),
    iconMuted: Color(0xFF888888),

    tabActive: _Palette.blue400,
    tabInactive: Color(0xFF888888),

    inputFill: _Palette.dark700,
    inputBorder: Color(0x1FFFFFFF),
    inputHint: Color(0xFF666666),

    chipFill: _Palette.dark700,
    chipText: Color(0xFFF2F2F2),
    tagFill: _Palette.blue800,

    scrim: Color(0xB3000000),
    shimmerBase: _Palette.dark750,
    shimmerHighlight: _Palette.dark600,

    success: _Palette.success,
    warning: _Palette.warning,
    error: _Palette.error,

    navBarBackground: _Palette.dark900,
    navBarBorder: Color(0x14FFFFFF),
    statusBarBrightness: Brightness.light,

    bottomSheetBackground: _Palette.dark800,
    qrScannerOverlay: Color(0x99000000),
    roomCardBackground: _Palette.dark800,
    roomCardBorder: Color(0x1FFFFFFF),
    floorPlanBackground: _Palette.white,

    pinBackground: _Palette.blue400,
    pinLabel: _Palette.blue400,
    pinLabelText: _Palette.white,

    badgeBackground: _Palette.blue500,
    badgeText: _Palette.white,
  );

  // ═══════════════════════════════════════════════════════════
  // LIGHT THEME
  // Inspired by Travelco (Image 2) + Task Dashboard (Image 3)
  // True white backgrounds, deep blue accent, black text,
  // white cards with subtle gray borders and soft shadows
  // ═══════════════════════════════════════════════════════════
  static const AppColors light = AppColors._(
    primary: _Palette.blue600,
    primaryVariant: _Palette.blue700,
    primaryContainer: _Palette.blue050,
    onPrimary: _Palette.white,
    secondary: _Palette.blue400,
    onSecondary: _Palette.white,

    background: _Palette.light050,
    backgroundSecondary: _Palette.light100,
    surface: _Palette.white,
    surfaceElevated: _Palette.white,
    surfaceOverlay: _Palette.light100,

    onBackground: _Palette.textPrimary,
    onSurface: _Palette.textPrimary,
    onSurfaceSecondary: _Palette.textSecondary,
    onSurfaceTertiary: _Palette.textTertiary,

    divider: Color(0xFFE5E7EB),
    border: Color(0xFFD1D5DB),
    borderSubtle: Color(0xFFE5E7EB),

    iconDefault: _Palette.textPrimary,
    iconMuted: _Palette.textTertiary,

    tabActive: _Palette.blue600,
    tabInactive: _Palette.textTertiary,

    inputFill: _Palette.light100,
    inputBorder: Color(0xFFD1D5DB),
    inputHint: _Palette.textTertiary,

    chipFill: _Palette.light100,
    chipText: _Palette.textPrimary,
    tagFill: _Palette.blue050,

    scrim: Color(0x80000000),
    shimmerBase: _Palette.light200,
    shimmerHighlight: _Palette.light050,

    success: _Palette.success,
    warning: _Palette.warning,
    error: _Palette.error,

    navBarBackground: _Palette.white,
    navBarBorder: Color(0xFFE5E7EB),
    statusBarBrightness: Brightness.dark,

    bottomSheetBackground: _Palette.white,
    qrScannerOverlay: Color(0x66000000),
    roomCardBackground: _Palette.white,
    roomCardBorder: Color(0xFFE5E7EB),
    floorPlanBackground: _Palette.white,

    pinBackground: _Palette.blue600,
    pinLabel: _Palette.blue600,
    pinLabelText: _Palette.white,

    badgeBackground: _Palette.blue600,
    badgeText: _Palette.white,
  );
}

// ────────────────────────────────────────────────────────────
// 3. TYPOGRAPHY
// Clean, modern, high-contrast — matches all 4 inspirations
// ────────────────────────────────────────────────────────────
class AppTextTheme {
  static TextTheme get _base => const TextTheme(
    // Display — hero numbers, large balances (Finance app style)
    displayLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.0,
      height: 1.15,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.2,
    ),
    displaySmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      height: 1.25,
    ),

    // Headline — screen titles, section headers
    headlineLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.3,
    ),
    headlineMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
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
      height: 1.45,
    ),
    titleSmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      height: 1.45,
    ),

    // Body — list content, descriptions
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.55,
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

  static TextTheme dark(AppColors c) =>
      _base.apply(bodyColor: c.onSurface, displayColor: c.onBackground);

  static TextTheme light(AppColors c) =>
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
    borderRadius: BorderRadius.circular(16),
  );
  static final _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  static final _inputShape = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  );

  // ══════════════════════════════════════════════════════════
  // DARK ThemeData
  // ══════════════════════════════════════════════════════════
  static ThemeData get dark {
    const c = AppColors.dark;
    final tt = AppTextTheme.dark(c);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      colorScheme: ColorScheme.dark(
        primary: c.primary,
        onPrimary: c.onPrimary,
        primaryContainer: c.primaryContainer,
        onPrimaryContainer: c.secondary,
        secondary: c.secondary,
        onSecondary: c.onSecondary,
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
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: _Palette.dark900,
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
        color: c.roomCardBackground,
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
          minimumSize: const Size(double.infinity, 54),
          shape: _buttonShape,
          elevation: 0,
          textStyle: tt.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(double.infinity, 54),
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
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.inputBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.error, width: 1.5),
        ),
        hintStyle: tt.bodyMedium?.copyWith(color: c.inputHint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        prefixIconColor: c.iconMuted,
        suffixIconColor: c.iconMuted,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bottomSheetBackground,
        modalBackgroundColor: c.bottomSheetBackground,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceElevated,
        contentTextStyle: tt.bodyMedium?.copyWith(color: c.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        actionTextColor: c.primary,
        elevation: 4,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceOverlay,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

      splashColor: c.primary.withOpacity(0.08),
      highlightColor: c.primary.withOpacity(0.05),
      splashFactory: InkRipple.splashFactory,
    );
  }

  // ══════════════════════════════════════════════════════════
  // LIGHT ThemeData
  // ══════════════════════════════════════════════════════════
  static ThemeData get light {
    const c = AppColors.light;
    final tt = AppTextTheme.light(c);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      colorScheme: ColorScheme.light(
        primary: c.primary,
        onPrimary: c.onPrimary,
        primaryContainer: c.primaryContainer,
        onPrimaryContainer: c.primaryVariant,
        secondary: c.secondary,
        onSecondary: c.onSecondary,
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
          statusBarBrightness: Brightness.light,
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
        color: c.roomCardBackground,
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
          minimumSize: const Size(double.infinity, 54),
          shape: _buttonShape,
          elevation: 0,
          textStyle: tt.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(double.infinity, 54),
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
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.inputBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.error, width: 1.5),
        ),
        hintStyle: tt.bodyMedium?.copyWith(color: c.inputHint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        prefixIconColor: c.iconMuted,
        suffixIconColor: c.iconMuted,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bottomSheetBackground,
        modalBackgroundColor: c.bottomSheetBackground,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
        side: BorderSide(color: c.border, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.onBackground,
        contentTextStyle: tt.bodyMedium?.copyWith(color: c.background),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        actionTextColor: c.secondary,
        elevation: 4,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        elevation: 2,
        shadowColor: const Color(0x1A000000),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

      splashColor: c.primary.withOpacity(0.06),
      highlightColor: c.primary.withOpacity(0.04),
      splashFactory: InkRipple.splashFactory,
    );
  }
}

// ────────────────────────────────────────────────────────────
// 5. SHARED COMPONENT STYLES
// Use these in widgets directly for consistency
// ────────────────────────────────────────────────────────────

/// Primary blue CTA gradient — Finance app button / hero card style
LinearGradient get primaryGradient => const LinearGradient(
  colors: [_Palette.blue400, _Palette.blue700],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Subtle depth gradient for dark mode cards
LinearGradient get darkCardGradient => const LinearGradient(
  colors: [_Palette.dark800, _Palette.dark750],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Blue tag / badge gradient
LinearGradient get badgeGradient => const LinearGradient(
  colors: [_Palette.blue500, _Palette.blue600],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Ready-made BoxDecoration for dark cards (use in Container)
BoxDecoration darkCardDecoration({double radius = 16, Color? border}) =>
    BoxDecoration(
      color: _Palette.dark800,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border ?? const Color(0x1FFFFFFF), width: 1),
    );

/// Ready-made BoxDecoration for light cards (use in Container)
BoxDecoration lightCardDecoration({double radius = 16, Color? border}) =>
    BoxDecoration(
      color: _Palette.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border ?? _Palette.light200, width: 1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    );

// ────────────────────────────────────────────────────────────
// 6. SPACING SCALE  (4 / 8 dp system)
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

// ────────────────────────────────────────────────────────────
// 7. BORDER RADIUS SCALE
// ────────────────────────────────────────────────────────────
class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double full = 999;
}

// ────────────────────────────────────────────────────────────
// 8. ELEVATION / SHADOW TOKENS
// ────────────────────────────────────────────────────────────
class AppShadows {
  /// Subtle card lift — light mode
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x05000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  /// Modal / bottom sheet elevation
  static const List<BoxShadow> modal = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, -4)),
    BoxShadow(color: Color(0x0D000000), blurRadius: 48, offset: Offset(0, -8)),
  ];

  /// Blue glow for primary buttons/pins in dark mode
  static List<BoxShadow> primaryGlow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.35),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];
}
