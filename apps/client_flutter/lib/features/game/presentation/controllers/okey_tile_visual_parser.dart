import '../models/okey_tile_visual_spec.dart';

class OkeyTileVisualParser {
  static OkeyTileVisualSpec parse(String rawLabel) {
    final label = rawLabel.trim();
    final lower = label.toLowerCase();

    if (lower.contains('sahte okey')) {
      return const OkeyTileVisualSpec(
        label: 'Sahte Okey',
        numberText: 'S',
        colorKey: 'purple',
        isOkey: false,
        isFakeOkey: true,
      );
    }

    if (lower == 'okey' || lower.contains(' okey')) {
      return const OkeyTileVisualSpec(
        label: 'Okey',
        numberText: 'O',
        colorKey: 'purple',
        isOkey: true,
        isFakeOkey: false,
      );
    }

    final numberMatch = RegExp(r'\d+').firstMatch(lower);
    final numberText = numberMatch?.group(0) ?? '?';

    String colorKey = 'black';
    if (lower.contains('sarı') || lower.contains('yellow')) {
      colorKey = 'yellow';
    } else if (lower.contains('mavi') || lower.contains('blue')) {
      colorKey = 'blue';
    } else if (lower.contains('kırmızı') || lower.contains('red')) {
      colorKey = 'red';
    } else if (lower.contains('siyah') || lower.contains('black')) {
      colorKey = 'black';
    }

    return OkeyTileVisualSpec(
      label: label,
      numberText: numberText,
      colorKey: colorKey,
      isOkey: false,
      isFakeOkey: false,
    );
  }
}
