import 'package:flutter/material.dart';
import 'package:client_flutter/features/game/domain/rack_arranger.dart';
import 'package:client_flutter/features/game/presentation/widgets/game_tile_widget.dart';

class DiscardDropZoneWidget extends StatelessWidget {
  const DiscardDropZoneWidget({
    super.key,
    required this.tiles,
    required this.width,
    required this.height,
    this.onAcceptTile,
    this.showFrame = true,
  });

  final List<RackTileVm> tiles;
  final double width;
  final double height;
  final void Function(int fromIndex)? onAcceptTile;
  final bool showFrame;

  @override
  Widget build(BuildContext context) {
    final lastTile = tiles.isNotEmpty ? tiles.last : null;

    return DragTarget<int>(
      onAcceptWithDetails: onAcceptTile == null
          ? null
          : (details) {
              onAcceptTile!(details.data);
            },
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: showFrame
              ? BoxDecoration(
                  color: active ? const Color(0x20FFC107) : const Color(0x10000000),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? const Color(0xFFFFC107) : const Color(0x33FFFFFF),
                    width: active ? 1.5 : 1.0,
                  ),
                )
              : null,
          child: lastTile == null
              ? const SizedBox.shrink()
              : GameTileWidget(
                  tile: lastTile,
                  width: 52,
                  height: 74,
                  compact: true,
                ),
        );
      },
    );
  }
}
