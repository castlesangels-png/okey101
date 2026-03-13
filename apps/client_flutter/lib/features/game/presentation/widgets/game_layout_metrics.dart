import 'dart:math' as math;
import 'package:flutter/widgets.dart';

class GameLayoutMetrics {
  const GameLayoutMetrics({
    required this.scale,
    required this.isCompact,
    required this.centerWidth,
    required this.sideWidth,
    required this.rackHeight,
    required this.tileWidth,
    required this.tileHeight,
    required this.discardBoxWidth,
    required this.discardBoxHeight,
    required this.badgeWidth,
  });

  final double scale;
  final bool isCompact;
  final double centerWidth;
  final double sideWidth;
  final double rackHeight;
  final double tileWidth;
  final double tileHeight;
  final double discardBoxWidth;
  final double discardBoxHeight;
  final double badgeWidth;

  static GameLayoutMetrics fromBox(BoxConstraints c) {
    final width = c.maxWidth;
    final height = c.maxHeight;

    final baseScaleFromWidth = width / 1600;
    final baseScaleFromHeight = height / 900;
    final scale = math.max(0.72, math.min(1.18, math.min(baseScaleFromWidth, baseScaleFromHeight)));

    final isCompact = width < 1200;

    return GameLayoutMetrics(
      scale: scale,
      isCompact: isCompact,
      centerWidth: isCompact ? width * 0.50 : width * 0.40,
      sideWidth: isCompact ? width * 0.22 : width * 0.20,
      rackHeight: 205 * scale,
      tileWidth: 52 * scale,
      tileHeight: 74 * scale,
      discardBoxWidth: 82 * scale,
      discardBoxHeight: 110 * scale,
      badgeWidth: isCompact ? 180 * scale : 220 * scale,
    );
  }
}
