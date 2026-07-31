import 'package:flutter/material.dart';

/// Extension pada BuildContext sebagai Single Source of Truth penentuan jenis layar/perangkat.
extension ResponsiveContext on BuildContext {
  /// Mendapatkan ukuran layar saat ini
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Satu-satunya sumber keputusan apakah perangkat adalah Mobile (smartphone)
  /// Menggunakan konvensi standar Flutter: shortestSide < 600
  bool get isMobile => screenSize.shortestSide < 600;

  /// True jika perangkat adalah Tablet / Desktop
  bool get isTablet => !isMobile;

  /// Cek orientasi layar
  bool get isLandscape => MediaQuery.orientationOf(this) == Orientation.landscape;
  bool get isPortrait => MediaQuery.orientationOf(this) == Orientation.portrait;
}
