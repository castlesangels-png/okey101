import 'package:flutter/material.dart';
import 'game_tile_widget.dart';

class PlayerRackWidget extends StatelessWidget {
  final String title;
  final bool isActive;
  final bool isBottomPlayer;
  final List<Map<String, dynamic>> tiles;
  final String? selectedTileId;
  final String? highlightedTileId;
  final ValueChanged<String>? onTileTap;

  const PlayerRackWidget({
    super.key,
    required this.title,
    required this.isActive,
    required this.isBottomPlayer,
    required this.tiles,
    this.selectedTileId,
    this.highlightedTileId,
    this.onTileTap,
  });

  Color _parseColor(String raw) {
    switch (raw) {
      case 'red':
        return Colors.red.shade700;
      case 'blue':
        return Colors.blue.shade700;
      case 'black':
        return Colors.black87;
      case 'yellow':
        return Colors.amber.shade800;
      default:
        return Colors.black87;
    }
  }

  List<List<Map<String, dynamic>>> _splitForTwoRows(List<Map<String, dynamic>> source) {
    if (source.length <= 10) {
      return [source, <Map<String, dynamic>>[]];
    }

    final firstRowCount = (source.length / 2).ceil();
    return [
      source.sublist(0, firstRowCount),
      source.sublist(firstRowCount),
    ];
  }

  List<Widget> _buildBottomRow(List<Map<String, dynamic>> rowTiles) {
    final widgets = <Widget>[];

    for (int i = 0; i < rowTiles.length; i++) {
      final tile = rowTiles[i];
      final tileId = (tile['id'] ?? '').toString();
      final selected = selectedTileId == tileId;
      final highlighted = highlightedTileId == tileId;
      final isGap = tile['gap'] == true;

      if (isGap) {
        widgets.add(const SizedBox(width: 28));
        continue;
      }

      final tileWidget = AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.translationValues(0, selected ? -12 : 0, 0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: Colors.green.shade800, width: 2)
                : highlighted
                    ? Border.all(color: Colors.orange.shade600, width: 2)
                    : null,
          ),
          child: GameTileWidget(
            value: tile['value'].toString(),
            color: _parseColor(tile['color'].toString()),
            isJoker: tile['joker'] == true,
            isFakeOkey: tile['fake_okey'] == true,
            width: 38,
            height: 56,
          ),
        ),
      );

      widgets.add(
        LongPressDraggable<String>(
          data: tileId,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.9,
              child: tileWidget,
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.35,
            child: tileWidget,
          ),
          child: GestureDetector(
            onTap: tileId.isEmpty || onTileTap == null
                ? null
                : () => onTileTap!(tileId),
            child: tileWidget,
          ),
        ),
      );
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final split = _splitForTwoRows(tiles);
    final row1 = split[0];
    final row2 = split[1];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.green.shade700 : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isBottomPlayer ? 17 : 14,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.brown.shade400,
              borderRadius: BorderRadius.circular(12),
            ),
            child: isBottomPlayer
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 0,
                        runSpacing: 0,
                        children: _buildBottomRow(row1),
                      ),
                      if (row2.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 0,
                          runSpacing: 0,
                          children: _buildBottomRow(row2),
                        ),
                      ],
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      tiles.length.clamp(5, 8),
                      (index) => Container(
                        width: 13,
                        height: 48,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.black12),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
