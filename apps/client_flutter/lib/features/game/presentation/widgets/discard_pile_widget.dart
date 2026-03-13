import 'package:flutter/material.dart';
import 'package:client_flutter/features/game/domain/rack_arranger.dart';
import 'package:client_flutter/features/game/presentation/widgets/game_tile_widget.dart';

class DiscardPileWidget extends StatelessWidget {
  const DiscardPileWidget({
    super.key,
    required this.title,
    required this.tiles,
    this.alignRight = false,
  });

  final String title;
  final List<RackTileVm> tiles;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final recent = tiles.reversed.take(2).toList();

    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 60,
          height: 120,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < recent.length; i++)
                Positioned(
                  top: i * 16,
                  left: 0,
                  child: GameTileWidget(
                    tile: recent[i],
                    width: 50,
                    height: 72,
                    compact: true,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
