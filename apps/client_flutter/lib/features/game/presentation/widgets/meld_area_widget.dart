import 'package:flutter/material.dart';
import 'package:client_flutter/features/game/domain/rack_arranger.dart';
import 'package:client_flutter/features/game/presentation/widgets/game_tile_widget.dart';

class MeldAreaWidget extends StatelessWidget {
  const MeldAreaWidget({
    super.key,
    required this.melds,
    this.title = 'Yere Açılanlar',
  });

  final List<List<RackTileVm>> melds;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0x33FFFFFF),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (melds.isEmpty)
            Container(
              height: 84,
              alignment: Alignment.centerLeft,
              child: const Text(
                'Henüz açılan taş yok',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            Wrap(
              spacing: 14,
              runSpacing: 12,
              children: melds.map((group) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0x14000000),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0x22FFFFFF),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: group
                        .map(
                          (tile) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: GameTileWidget(
                              tile: tile,
                              width: 42,
                              height: 60,
                              compact: true,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
