import 'package:flutter/material.dart';
import 'game_tile_widget.dart';

class MeldAreaWidget extends StatelessWidget {
  final List<List<Map<String, dynamic>>> groups;

  const MeldAreaWidget({
    super.key,
    required this.groups,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade700,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade900, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: groups.isEmpty
          ? const Center(
              child: Text(
                'Yere acilan taslar burada gorunecek',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : SingleChildScrollView(
              child: Wrap(
                spacing: 18,
                runSpacing: 14,
                children: groups.map((group) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: group
                          .map(
                            (tile) => GameTileWidget(
                              value: tile['value'].toString(),
                              color: _parseColor(tile['color'].toString()),
                              isJoker: tile['joker'] == true,
                            ),
                          )
                          .toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}
