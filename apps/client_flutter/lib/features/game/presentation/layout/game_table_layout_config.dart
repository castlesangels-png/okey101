import 'package:flutter/material.dart';

class GameTableLayoutConfig {
  static const double headerRadius = 16;
  static const double rackRadius = 18;
  static const double feltRadius = 24;

  static const double discardBoxWidth = 54;
  static const double discardBoxHeight = 72;
  static const double discardTileOffset = 8;

  static const double topRackMaxWidth = 560;
  static const double sideRackNarrowWidth = 86;
  static const double sideRackWideWidth = 98;
  static const double topRackNarrowHeight = 98;
  static const double topRackWideHeight = 108;
  static const double bottomRackNarrowHeight = 188;
  static const double bottomRackWideHeight = 202;

  static const double centerDrawAreaWidth = 168;
  static const double centerDrawAreaHeight = 84;

  static double tileWidth(double screenWidth) {
    if (screenWidth <= 740) return 32;
    if (screenWidth <= 980) return 36;
    if (screenWidth <= 1280) return 40;
    return 44;
  }

  static double tileHeight(double screenWidth) {
    if (screenWidth <= 740) return 48;
    if (screenWidth <= 980) return 54;
    if (screenWidth <= 1280) return 60;
    return 66;
  }

  static double smallTileWidth(double screenWidth) {
    if (screenWidth <= 740) return 26;
    if (screenWidth <= 980) return 28;
    if (screenWidth <= 1280) return 32;
    return 34;
  }

  static double smallTileHeight(double screenWidth) {
    if (screenWidth <= 740) return 40;
    if (screenWidth <= 980) return 44;
    if (screenWidth <= 1280) return 48;
    return 52;
  }

  static double actionButtonFont(double screenWidth) {
    if (screenWidth <= 740) return 12;
    if (screenWidth <= 980) return 13;
    return 14;
  }

  static double titleFont(double screenWidth) {
    if (screenWidth <= 740) return 13;
    if (screenWidth <= 980) return 14;
    return 15;
  }

  static double subtitleFont(double screenWidth) {
    if (screenWidth <= 740) return 10;
    if (screenWidth <= 980) return 11;
    return 12;
  }

  static Size desktopWindowLikeSize() {
    return const Size(1280, 720);
  }
}
