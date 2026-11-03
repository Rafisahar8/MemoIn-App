import 'package:flutter/material.dart';

/// Token desain & tema global MemoIn.
///
/// Prinsip: permukaan datar, garis tipis, palet biru desain utama, dua bobot huruf
/// (Regular & Semibold) dan satu keluarga font untuk seluruh aplikasi.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------- font
  /// Satu-satunya keluarga font aplikasi. Ganti di sini bila ingin memakai font bundel
  /// (daftarkan di pubspec.yaml lalu ubah nilai ini); seluruh widget ikut berubah.
  static const font = 'Segoe UI';
  static const fontFallback = ['Inter', 'Roboto', 'Arial'];

  // ---------------------------------------------------------------- warna merek
  // Palet mengikuti desain utama MemoIn.
  static const primary = Color(0xFF0B3D91);
  static const primaryDark = Color(0xFF0B2A6F);
  static const navy = Color(0xFF0B1F4B);
  static const accent = Color(0xFF2563EB);
  static const accentSoft = Color(0xFFEAF1FF);
  static const yellow = Color(0xFFFACC15);

  /// Sidebar, header dialog, dan panel merek.
  static const sidebar = Color(0xFF003A8C);
  static const sidebarActive = Color(0xFF1A5BC4);
  static const sidebarText = Color(0xFFC3D6F4);
  static const sidebarMuted = Color(0xFF8FB0E8);

  // ---------------------------------------------------------------- netral
  static const background = Color(0xFFF0F4F8);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF8FAFC); // kepala tabel
  static const fieldFill = Color(0xFFF8FAFD); // isi input
  static const fieldLocked = Color(0xFFF1F5F9); // kotak baca-saja
  static const ink = Color(0xFF0F1B33);
  static const body = Color(0xFF334155);
  static const label = Color(0xFF475569); // label field & judul kolom
  static const muted = Color(0xFF64748B);
  static const faint = Color(0xFF94A3B8);
  static const border = Color(0xFFE5EAF2);
  static const borderStrong = Color(0xFFCBD5E1);

  // ---------------------------------------------------------------- semantik
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFEA580C);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF0EA5E9);
  static const violet = Color(0xFF7C3AED);
  static const emerald = Color(0xFF10B981); // tombol Export

  // ---------------------------------------------------------------- bentuk
  static const radius = 12.0; // kartu
  static const radiusControl = 10.0; // input, tombol
  static const radiusSmall = 8.0; // item nav, tombol ikon
  static const radiusDialog = 16.0;
  static const controlHeight = 44.0;

  static final light = _build();

  static TextStyle _ts(double size, FontWeight weight, Color color, {double? height, double? spacing}) => TextStyle(
        fontFamily: font,
        fontFamilyFallback: fontFallback,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: spacing,
      );

  static ThemeData _build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      surface: surface,
      onSurface: ink,
      outline: borderStrong,
      outlineVariant: border,
      error: danger,
    );

    OutlineInputBorder outline(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: BorderSide(color: c, width: w),
        );
    final btnShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusControl));
    const btnPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 12);
    const btnSize = Size(0, controlHeight);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: font,
      fontFamilyFallback: fontFallback,
      dividerColor: border,
      // Tanpa riak Material; umpan balik lewat warna hover yang halus (aplikasi desktop).
      splashFactory: NoSplash.splashFactory,
      hoverColor: const Color(0x0A0F1B33),
      highlightColor: const Color(0x0F0F1B33),
      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: const Color(0x330F1B33),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusDialog),
          side: const BorderSide(color: border),
        ),
        titleTextStyle: _ts(17, FontWeight.w600, ink),
        contentTextStyle: _ts(14, FontWeight.w400, muted, height: 1.45),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        labelStyle: _ts(13, FontWeight.w400, muted),
        floatingLabelStyle: _ts(13, FontWeight.w400, accent),
        hintStyle: _ts(14, FontWeight.w400, faint),
        errorStyle: _ts(12, FontWeight.w400, danger),
        prefixIconColor: faint,
        suffixIconColor: muted,
        border: outline(borderStrong),
        enabledBorder: outline(borderStrong),
        disabledBorder: outline(border),
        focusedBorder: outline(accent, 1.6),
        errorBorder: outline(danger),
        focusedErrorBorder: outline(danger, 1.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: btnSize,
          padding: btnPadding,
          shape: btnShape,
          textStyle: _ts(13.5, FontWeight.w600, Colors.white),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: btnSize,
          padding: btnPadding,
          shape: btnShape,
          textStyle: _ts(13.5, FontWeight.w600, Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: ink,
          minimumSize: btnSize,
          padding: btnPadding,
          shape: btnShape,
          side: const BorderSide(color: borderStrong),
          textStyle: _ts(13.5, FontWeight.w600, ink),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: btnShape,
          textStyle: _ts(13.5, FontWeight.w600, primary),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: muted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusControl)),
        contentTextStyle: _ts(13.5, FontWeight.w400, Colors.white),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 350),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(6)),
        textStyle: _ts(12, FontWeight.w400, Colors.white),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x330F1B33),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          side: const BorderSide(color: border),
        ),
        textStyle: _ts(13.5, FontWeight.w400, ink),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusDialog)),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6.0),
        radius: const Radius.circular(4),
        thumbColor: const WidgetStatePropertyAll(borderStrong),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: Color(0x330B3D91),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accentSoft,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => _ts(
            11.5,
            s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
            s.contains(WidgetState.selected) ? primary : muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 22, color: s.contains(WidgetState.selected) ? primary : muted),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(surfaceMuted),
        headingTextStyle: _ts(12.5, FontWeight.w600, body),
        dataTextStyle: _ts(13.5, FontWeight.w400, ink),
        dataRowMinHeight: 52,
        dataRowMaxHeight: 56,
        headingRowHeight: 42,
        dividerThickness: 1,
        horizontalMargin: 16,
        columnSpacing: 28,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: accentSoft,
      ),
    );
  }
}
