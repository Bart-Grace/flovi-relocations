import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The same brand blue the dispatcher uses, so the two apps read as one product
/// when they sit side by side on screen.
const Color kSeed = Color(0xFF2563EB);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: kSeed, brightness: brightness);
  final base = ThemeData(brightness: brightness);

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      color: scheme.surfaceContainerLow,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(GoogleFonts.inter(fontSize: 12)),
    ),
  );
}

/// Status colours match the dispatcher's pills exactly — the two screens are shown
/// side by side in the demo, and a colour that disagrees across apps reads as a bug.
({Color fg, Color bg, String label}) statusStyle(String status, ColorScheme scheme) {
  switch (status) {
    case 'open':
      return (fg: const Color(0xFFFBBF24), bg: const Color(0x22FBBF24), label: 'Open');
    case 'booked':
      return (fg: const Color(0xFF60A5FA), bg: const Color(0x2260A5FA), label: 'Booked');
    case 'in_transit':
      return (fg: const Color(0xFF818CF8), bg: const Color(0x22818CF8), label: 'In transit');
    case 'completed':
      return (fg: const Color(0xFF34D399), bg: const Color(0x2234D399), label: 'Completed');
    default:
      return (fg: const Color(0xFFA1A1AA), bg: const Color(0x22A1A1AA), label: 'Cancelled');
  }
}
