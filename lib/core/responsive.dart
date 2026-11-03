import 'package:flutter/widgets.dart';

/// Breakpoint tunggal supaya semua layar berperilaku konsisten.
///
/// - mobile  : < 720   -> navigasi bawah, tabel menjadi daftar kartu
/// - tablet  : 720-1099 -> navigasi rail ringkas
/// - desktop : >= 1100 -> sidebar penuh
class Responsive {
  static const double mobileMax = 720;
  static const double desktopMin = 1100;

  static bool isMobile(BuildContext c) => MediaQuery.sizeOf(c).width < mobileMax;
  static bool isDesktop(BuildContext c) => MediaQuery.sizeOf(c).width >= desktopMin;

  /// Padding halaman mengikuti lebar layar.
  static double pagePadding(double width) {
    if (width < 480) return 14;
    if (width < mobileMax) return 18;
    if (width < desktopMin) return 22;
    return 28;
  }
}
