import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Die drei festen Paletten des Designs „Smaragd Glass". `system` folgt dem
/// Gerät: hell → Salbei, dunkel → Dunkel.
enum AppPalette { system, sage, emerald, dark }

/// Farben, die Material nicht kennt: Glas, Hintergrund-Schein, Einnahmen/
/// Ausgaben. Überall per `AppColors.of(context)` erreichbar.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.card,
    required this.chip,
    required this.hairline,
    required this.income,
    required this.expense,
    required this.brass,
    required this.warning,
    required this.glass,
    required this.glassThick,
    required this.glassEdge,
    required this.glassShadow,
    required this.blobA,
    required this.blobB,
    required this.blobC,
    required this.scrim,
  });

  /// Deckende Grundfläche hinter allem.
  final Color background;

  /// Deckende Inhaltskacheln.
  final Color card;

  /// Getönte Kreise hinter Emojis, Balken-Hintergründe.
  final Color chip;
  final Color hairline;
  final Color income;
  final Color expense;
  final Color brass;

  /// Warnstufe zwischen Einnahmen- und Ausgabenfarbe (Budget fast
  /// ausgeschöpft, Fälligkeit naht); als Text auf Kacheln lesbar.
  final Color warning;

  /// Glas der Bedienebene (Tableiste, Knöpfe) und die dickere Fassung für
  /// große Flächen (Seitenleiste, Sheets).
  final Color glass;
  final Color glassThick;
  final Color glassEdge;
  final Color glassShadow;

  /// Weicher Farbschein im Hintergrund, damit das Glas etwas zu brechen hat.
  final Color blobA;
  final Color blobB;
  final Color blobC;
  final Color scrim;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  /// Farbreihe für Diagramme mit mehreren Kategorien, aus der Palette
  /// abgeleitet (Akzent, Messing, Ausgaben und deren gedämpfte Stufen). Bei
  /// mehr Einträgen als Farben wird von vorn begonnen.
  static List<Color> chartSeries(BuildContext context) {
    final c = of(context);
    final s = Theme.of(context).colorScheme;
    Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
    return [
      s.primary,
      c.brass,
      mix(s.primary, c.card, .5),
      c.expense,
      s.outline,
      mix(c.brass, c.card, .5),
      mix(c.expense, c.card, .5),
      mix(s.primary, s.onSurface, .5),
    ];
  }

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: c(background, other.background),
      card: c(card, other.card),
      chip: c(chip, other.chip),
      hairline: c(hairline, other.hairline),
      income: c(income, other.income),
      expense: c(expense, other.expense),
      brass: c(brass, other.brass),
      warning: c(warning, other.warning),
      glass: c(glass, other.glass),
      glassThick: c(glassThick, other.glassThick),
      glassEdge: c(glassEdge, other.glassEdge),
      glassShadow: c(glassShadow, other.glassShadow),
      blobA: c(blobA, other.blobA),
      blobB: c(blobB, other.blobB),
      blobC: c(blobC, other.blobC),
      scrim: c(scrim, other.scrim),
    );
  }
}

/// Rohwerte einer Palette; daraus entstehen ColorScheme und AppColors.
class _Tokens {
  const _Tokens({
    required this.brightness,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.ink,
    required this.ink2,
    required this.outline,
    required this.outlineSoft,
    required this.colors,
  });

  final Brightness brightness;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color onAccentSoft;
  final Color ink;
  final Color ink2;
  final Color outline;
  final Color outlineSoft;
  final AppColors colors;
}

const _sage = _Tokens(
  brightness: Brightness.light,
  accent: Color(0xFF0B5C43),
  onAccent: Color(0xFFFFFFFF),
  accentSoft: Color(0xFFB8DBCB),
  onAccentSoft: Color(0xFF063D2C),
  ink: Color(0xFF0A1A14),
  ink2: Color(0xFF42554C),
  outline: Color(0xFF7D9086),
  outlineSoft: Color(0xFFC9D6CE),
  colors: AppColors(
    background: Color(0xFFD5E2DA),
    card: Color(0xFFF8FBF9),
    chip: Color(0xFFE3ECE7),
    hairline: Color(0x1A0A1A14),
    income: Color(0xFF0B5C43),
    expense: Color(0xFFB8483A),
    brass: Color(0xFFB8935A),
    warning: Color(0xFF7E5A12),
    glass: Color(0x6BF0F8F4),
    glassThick: Color(0xB3F0F8F4),
    glassEdge: Color(0xB3FFFFFF),
    glassShadow: Color(0x42063224),
    blobA: Color(0xFF2F9C74),
    blobB: Color(0xFFD9C48C),
    blobC: Color(0xFF1F8562),
    scrim: Color(0x4D081812),
  ),
);

const _emerald = _Tokens(
  brightness: Brightness.dark,
  accent: Color(0xFF6FEBBD),
  onAccent: Color(0xFF04271C),
  accentSoft: Color(0xFF075240),
  onAccentSoft: Color(0xFFE6FBF2),
  ink: Color(0xFFF2F8F4),
  ink2: Color(0xFFBEDDCF),
  outline: Color(0xFF5FA58C),
  outlineSoft: Color(0xFF1C6E55),
  colors: AppColors(
    background: Color(0xFF06402F),
    card: Color(0xFF0C5C45),
    chip: Color(0xFF084C39),
    hairline: Color(0x1AFFFFFF),
    income: Color(0xFF7EF0C4),
    expense: Color(0xFFFFB9AB),
    brass: Color(0xFFE0C48A),
    warning: Color(0xFFF0D59A),
    glass: Color(0x21FFFFFF),
    glassThick: Color(0xA309543E),
    glassEdge: Color(0x42FFFFFF),
    glassShadow: Color(0x8000160F),
    blobA: Color(0xFF1FB887),
    blobB: Color(0xFFC4A46A),
    blobC: Color(0xFF12A077),
    scrim: Color(0x8000140E),
  ),
);

const _dark = _Tokens(
  brightness: Brightness.dark,
  accent: Color(0xFF3FBF93),
  onAccent: Color(0xFF06110D),
  accentSoft: Color(0xFF17382C),
  onAccentSoft: Color(0xFFBFEBD9),
  ink: Color(0xFFE9F0EC),
  ink2: Color(0xFF9AAAA2),
  outline: Color(0xFF5D6E66),
  outlineSoft: Color(0xFF26332E),
  colors: AppColors(
    background: Color(0xFF0B1411),
    card: Color(0xFF141F1B),
    chip: Color(0xFF1B2823),
    hairline: Color(0x14FFFFFF),
    income: Color(0xFF5FD3A9),
    expense: Color(0xFFE38A7C),
    brass: Color(0xFFC4A46A),
    warning: Color(0xFFD9B878),
    glass: Color(0x801C2C25),
    glassThick: Color(0xC214201B),
    glassEdge: Color(0x24FFFFFF),
    glassShadow: Color(0x80000000),
    blobA: Color(0xFF0F6B4F),
    blobB: Color(0xFF5C4A22),
    blobC: Color(0xFF124D3B),
    scrim: Color(0x80000000),
  ),
);

/// Zentrales App-Theme. Material 3 als Unterbau, alle Farben und Formen aus
/// den Paletten oben.
class AppTheme {
  const AppTheme._();

  /// Helles Theme für [palette]; bei `system` Salbei.
  static ThemeData themeFor(AppPalette palette) => switch (palette) {
    AppPalette.system || AppPalette.sage => _sageTheme,
    AppPalette.emerald => _emeraldTheme,
    AppPalette.dark => _darkTheme,
  };

  /// Nur bei `system` gebraucht: das Gegenstück für den Dunkelmodus.
  static ThemeData get systemDark => _darkTheme;

  /// Fürs Onboarding, das vor den Einstellungen läuft.
  static ThemeData get fallback => _sageTheme;

  // Einmal gebaut und wiederverwendet: die Paletten ändern sich nie.
  static final ThemeData _sageTheme = _build(_sage);
  static final ThemeData _emeraldTheme = _build(_emerald);
  static final ThemeData _darkTheme = _build(_dark);

  static ThemeData _build(_Tokens t) {
    final c = t.colors;
    final dark = t.brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: t.brightness,
      primary: t.accent,
      onPrimary: t.onAccent,
      primaryContainer: t.accentSoft,
      onPrimaryContainer: t.onAccentSoft,
      secondary: t.ink2,
      onSecondary: c.card,
      secondaryContainer: t.accentSoft,
      onSecondaryContainer: t.onAccentSoft,
      tertiary: c.brass,
      onTertiary: const Color(0xFF241A06),
      tertiaryContainer: Color.alphaBlend(
        c.brass.withValues(alpha: .28),
        c.card,
      ),
      onTertiaryContainer: t.ink,
      error: c.expense,
      onError: dark ? const Color(0xFF2B0A05) : const Color(0xFFFFFFFF),
      errorContainer: Color.alphaBlend(
        c.expense.withValues(alpha: .22),
        c.card,
      ),
      onErrorContainer: t.ink,
      surface: c.background,
      onSurface: t.ink,
      onSurfaceVariant: t.ink2,
      surfaceContainerLowest: c.card,
      surfaceContainerLow: c.card,
      surfaceContainer: c.card,
      surfaceContainerHigh: c.card,
      surfaceContainerHighest: c.chip,
      surfaceTint: Colors.transparent,
      outline: t.outline,
      outlineVariant: t.outlineSoft,
      shadow: const Color(0xFF000000),
      scrim: c.scrim,
      inverseSurface: t.ink,
      onInverseSurface: c.background,
      inversePrimary: dark ? const Color(0xFF0B5C43) : const Color(0xFF6FEBBD),
    );

    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: t.brightness,
      colorScheme: scheme,
    );

    // Große Zahlen und Titel enger, Fließtext unverändert (Apple: Laufweite
    // hängt von der Größe ab). Tabellenziffern, damit Beträge nicht springen.
    const tabular = [FontFeature.tabularFigures()];
    TextStyle? tight(TextStyle? s, double spacing, [FontWeight? w]) =>
        s?.copyWith(
          letterSpacing: spacing,
          fontWeight: w,
          fontFeatures: tabular,
        );
    final tt = base.textTheme;
    final textTheme = tt
        .copyWith(
          displayLarge: tight(tt.displayLarge, -1.6, FontWeight.w600),
          displayMedium: tight(tt.displayMedium, -1.2, FontWeight.w600),
          displaySmall: tight(tt.displaySmall, -0.9, FontWeight.w600),
          headlineLarge: tight(tt.headlineLarge, -0.8, FontWeight.w600),
          headlineMedium: tight(tt.headlineMedium, -0.6, FontWeight.w600),
          headlineSmall: tight(tt.headlineSmall, -0.4, FontWeight.w600),
          titleLarge: tight(tt.titleLarge, -0.3, FontWeight.w600),
          titleMedium: tight(tt.titleMedium, -0.1, FontWeight.w600),
          titleSmall: tight(tt.titleSmall, 0, FontWeight.w600),
          bodyLarge: tight(tt.bodyLarge, 0),
          bodyMedium: tight(tt.bodyMedium, 0),
          bodySmall: tight(tt.bodySmall, 0),
          labelLarge: tight(tt.labelLarge, 0, FontWeight.w600),
        )
        .apply(bodyColor: t.ink, displayColor: t.ink);

    const pill = StadiumBorder();
    final hair = BorderSide(color: c.hairline);
    RoundedRectangleBorder rounded(
      double r, [
      BorderSide side = BorderSide.none,
    ]) => RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(r),
      side: side,
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: hair,
    );

    return base.copyWith(
      extensions: [c],
      textTheme: textTheme,
      // Die Seiten malen ihren Hintergrund selbst (siehe AppBackdrop), damit
      // der Farbschein hinter jedem Scaffold liegt.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: c.card,
      dividerColor: c.hairline,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: BackdropPageTransitions(
            CupertinoPageTransitionsBuilder(),
          ),
          TargetPlatform.macOS: BackdropPageTransitions(
            CupertinoPageTransitionsBuilder(),
          ),
          TargetPlatform.android: BackdropPageTransitions(
            ZoomPageTransitionsBuilder(),
          ),
          TargetPlatform.windows: BackdropPageTransitions(
            ZoomPageTransitionsBuilder(),
          ),
          TargetPlatform.linux: BackdropPageTransitions(
            ZoomPageTransitionsBuilder(),
          ),
          TargetPlatform.fuchsia: BackdropPageTransitions(
            ZoomPageTransitionsBuilder(),
          ),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: t.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 24),
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        // Wie eine Bento-Kachel: bündig mit dem Seitenrand, 12 Abstand.
        margin: const EdgeInsets.symmetric(vertical: 6),
        clipBehavior: Clip.antiAlias,
        shape: rounded(22, hair),
      ),
      dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: t.ink2,
        shape: rounded(16),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: t.ink2),
        // Beträge rechts so kräftig wie in den Bento-Zeilen.
        leadingAndTrailingTextStyle: textTheme.bodyLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: pill,
          minimumSize: const Size(64, 48),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: pill,
          backgroundColor: c.card,
          foregroundColor: t.accent,
          side: hair,
          minimumSize: const Size(64, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: pill,
          side: BorderSide(color: t.outline),
          minimumSize: const Size(64, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: pill),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.accent,
        foregroundColor: t.onAccent,
        elevation: 3,
        focusElevation: 3,
        hoverElevation: 4,
        highlightElevation: 1,
        shape: pill,
        extendedTextStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: t.accent, width: 1.5),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: c.expense),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: c.expense, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: pill,
        side: hair,
        backgroundColor: c.card,
        selectedColor: t.accentSoft,
        checkmarkColor: t.onAccentSoft,
        labelStyle: textTheme.labelLarge?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(pill),
          side: WidgetStatePropertyAll(hair),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? t.accent : c.card,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? t.onAccent : t.ink2,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: rounded(28, hair),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: c.scrim,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: t.ink2.withValues(alpha: .35),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: rounded(18, hair),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.background),
        actionTextColor: dark
            ? const Color(0xFF0B5C43)
            : const Color(0xFF6FEBBD),
        shape: rounded(16),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        linearTrackColor: c.chip,
        circularTrackColor: c.chip,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: t.accent,
        unselectedLabelColor: t.ink2,
        indicatorColor: t.accent,
        dividerColor: c.hairline,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.ink,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: c.background),
      ),
    );
  }
}

/// Deckender Seitenhintergrund: Grundfarbe plus drei weiche Farbflecken.
/// Liegt unter jedem (durchsichtigen) Scaffold, damit Glasflächen etwas zum
/// Weichzeichnen haben. Statisch, daher eigene Repaint-Grenze.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget blob(Alignment at, double radius, Color color) => DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: at,
          radius: radius,
          colors: [color.withValues(alpha: .55), color.withValues(alpha: 0)],
        ),
      ),
      child: const SizedBox.expand(),
    );
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: ColoredBox(
              color: c.background,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  blob(const Alignment(-.9, -1.1), .9, c.blobA),
                  blob(const Alignment(1.2, -.5), .7, c.blobB),
                  blob(const Alignment(-.4, 1.2), .9, c.blobC),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Legt [AppBackdrop] unter jede Seite und reicht den Übergang selbst an den
/// Plattform-Standard weiter. So bleiben Seiten deckend (saubere Übergänge,
/// iOS-Zurückwischen), obwohl die Scaffolds durchsichtig sind.
class BackdropPageTransitions extends PageTransitionsBuilder {
  const BackdropPageTransitions(this.inner);

  final PageTransitionsBuilder inner;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => inner.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    AppBackdrop(child: child),
  );
}
