import 'package:flutter/material.dart';
import '../../domain/game_table.dart';

class TableCard extends StatelessWidget {
  final GameTable table;
  final VoidCallback? onTap;

  const TableCard({
    super.key,
    required this.table,
    this.onTap,
  });

  String get statusText {
    final value = table.status.toLowerCase();

    switch (value) {
      case 'waiting':
        return 'Bekliyor';
      case 'playing':
        return 'Oyunda';
      case 'full':
        return 'Dolu';
      default:
        return table.status.isEmpty ? 'Bilinmiyor' : table.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.table_restaurant, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      table.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Oyun: ${table.gameType}'),
                    Text('Oyuncu: ${table.currentPlayers}/${table.maxPlayers}'),
                    Text('Min giris: ${table.minBuyIn}'),
                    Text('Durum: $statusText'),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
