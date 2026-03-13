import 'package:flutter/material.dart';
import 'package:client_flutter/features/game/domain/rack_arranger.dart';
import 'package:client_flutter/features/game/presentation/widgets/game_tile_widget.dart';

class DrawPileWidget extends StatelessWidget {
  const DrawPileWidget({
    super.key,
    required this.indicatorTile,
    required this.drawCount,
    this.onDrawDragStarted,
  });

  final RackTileVm? indicatorTile;
  final int drawCount;
  final VoidCallback? onDrawDragStarted;

  @override
  Widget build(BuildContext context) {
    final stackTile = Container(
      width: 52,
      height: 74,
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCFD8DC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$drawCount',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Color(0xFF263238),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'X 101 Salonu',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (indicatorTile != null)
              GameTileWidget(
                tile: indicatorTile!,
                width: 52,
                height: 74,
              ),
            const SizedBox(width: 14),
            LongPressDraggable<String>(
              data: 'draw-pile',
              onDragStarted: onDrawDragStarted,
              feedback: Material(
                color: Colors.transparent,
                child: stackTile,
              ),
              child: stackTile,
            ),
          ],
        ),
      ],
    );
  }
}
