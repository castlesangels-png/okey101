import 'package:flutter/material.dart';
import 'package:client_flutter/features/game/domain/rack_arranger.dart';
import 'package:client_flutter/features/game/presentation/widgets/reorderable_rack_widget.dart';
import 'package:client_flutter/features/game/presentation/widgets/two_tier_rack_widget.dart';

class PlayerRackWidget extends StatelessWidget {
  const PlayerRackWidget({
    super.key,
    required this.tiles,
    required this.gapAfterIndexes,
    required this.onMoveTile,
    required this.rackHeight,
  });

  final List<RackTileVm> tiles;
  final Set<int> gapAfterIndexes;
  final void Function(int fromIndex, int toIndex) onMoveTile;
  final double rackHeight;

  @override
  Widget build(BuildContext context) {
    return TwoTierRackWidget(
      height: rackHeight,
      child: ReorderableRackWidget(
        tiles: tiles,
        gapAfterIndexes: gapAfterIndexes,
        onMoveTile: onMoveTile,
      ),
    );
  }
}
