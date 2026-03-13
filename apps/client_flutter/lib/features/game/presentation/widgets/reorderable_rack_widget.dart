import 'package:flutter/material.dart';
import 'package:client_flutter/features/game/domain/rack_arranger.dart';
import 'package:client_flutter/features/game/presentation/widgets/game_tile_widget.dart';

class ReorderableRackWidget extends StatelessWidget {
  const ReorderableRackWidget({
    super.key,
    required this.tiles,
    required this.gapAfterIndexes,
    required this.onMoveTile,
    this.maxTilesPerRow = 15,
  });

  final List<RackTileVm> tiles;
  final Set<int> gapAfterIndexes;
  final void Function(int fromIndex, int toIndex) onMoveTile;
  final int maxTilesPerRow;

  @override
  Widget build(BuildContext context) {
    final firstRowCount = tiles.length > maxTilesPerRow ? maxTilesPerRow : tiles.length;
    final secondRowCount = tiles.length - firstRowCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RackRow(
          tiles: tiles.take(firstRowCount).toList(),
          rowStartIndex: 0,
          gapAfterIndexes: gapAfterIndexes,
          onMoveTile: onMoveTile,
        ),
        const SizedBox(height: 10),
        _RackRow(
          tiles: secondRowCount > 0 ? tiles.skip(firstRowCount).take(secondRowCount).toList() : const [],
          rowStartIndex: firstRowCount,
          gapAfterIndexes: gapAfterIndexes,
          onMoveTile: onMoveTile,
        ),
      ],
    );
  }
}

class _RackRow extends StatelessWidget {
  const _RackRow({
    required this.tiles,
    required this.rowStartIndex,
    required this.gapAfterIndexes,
    required this.onMoveTile,
  });

  final List<RackTileVm> tiles;
  final int rowStartIndex;
  final Set<int> gapAfterIndexes;
  final void Function(int fromIndex, int toIndex) onMoveTile;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) {
      return const SizedBox(height: 76);
    }

    final children = <Widget>[];

    children.add(_DropSlot(
      onAccept: (fromIndex) => onMoveTile(fromIndex, rowStartIndex),
    ));

    for (var i = 0; i < tiles.length; i++) {
      final globalIndex = rowStartIndex + i;
      final tile = tiles[i];

      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: LongPressDraggable<int>(
            data: globalIndex,
            feedback: Material(
              color: Colors.transparent,
              child: GameTileWidget(
                tile: tile,
                width: 54,
                height: 76,
                highlight: true,
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.20,
              child: GameTileWidget(
                tile: tile,
                width: 54,
                height: 76,
              ),
            ),
            child: GameTileWidget(
              tile: tile,
              width: 54,
              height: 76,
            ),
          ),
        ),
      );

      children.add(_DropSlot(
        onAccept: (fromIndex) => onMoveTile(fromIndex, globalIndex + 1),
      ));

      if (gapAfterIndexes.contains(globalIndex)) {
        children.add(const SizedBox(width: 18));
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
    );
  }
}

class _DropSlot extends StatefulWidget {
  const _DropSlot({
    required this.onAccept,
  });

  final void Function(int fromIndex) onAccept;

  @override
  State<_DropSlot> createState() => _DropSlotState();
}

class _DropSlotState extends State<_DropSlot> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (_) {
        setState(() => _hovering = true);
        return true;
      },
      onLeave: (_) {
        if (mounted) {
          setState(() => _hovering = false);
        }
      },
      onAcceptWithDetails: (details) {
        setState(() => _hovering = false);
        widget.onAccept(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: _hovering ? 18 : 12,
          height: 76,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: _hovering ? const Color(0x44FFC107) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovering ? const Color(0xFFFFC107) : Colors.transparent,
              width: 1.4,
            ),
          ),
        );
      },
    );
  }
}
