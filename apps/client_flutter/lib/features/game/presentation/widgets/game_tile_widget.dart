import 'package:flutter/material.dart';
import 'package:client_flutter/features/game/domain/rack_arranger.dart';

class GameTileWidget extends StatelessWidget {
  const GameTileWidget({
    super.key,
    required this.tile,
    this.width = 50,
    this.height = 72,
    this.highlight = false,
    this.compact = false,
  });

  final RackTileVm tile;
  final double width;
  final double height;
  final bool highlight;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dotColor = _dotColor(tile.color);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        border: Border.all(
          color: highlight ? const Color(0xFFFFC107) : const Color(0xFFDDDDDD),
          width: highlight ? 2.2 : 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: tile.isJoker
          ? Center(
              child: Text(
                'J',
                style: TextStyle(
                  fontSize: compact ? 18 : 22,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF111111),
                ),
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${tile.number}',
                  style: TextStyle(
                    fontSize: compact ? 18 : 24,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF111111),
                    height: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: compact ? 11 : 14,
                  height: compact ? 11 : 14,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
    );
  }

  Color _dotColor(RackTileColor color) {
    switch (color) {
      case RackTileColor.red:
        return const Color(0xFFE53935);
      case RackTileColor.blue:
        return const Color(0xFF1E88E5);
      case RackTileColor.yellow:
        return const Color(0xFFFBC02D);
      case RackTileColor.black:
        return const Color(0xFF212121);
      case RackTileColor.unknown:
        return const Color(0xFF9E9E9E);
    }
  }
}
