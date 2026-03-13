import 'package:flutter/material.dart';

class TableCenterBoard extends StatelessWidget {
  final String tableName;
  final String gameType;
  final int currentPlayers;
  final int maxPlayers;
  final int minBuyIn;
  final String status;

  const TableCenterBoard({
    super.key,
    required this.tableName,
    required this.gameType,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.minBuyIn,
    required this.status,
  });

  String get statusText {
    switch (status.toLowerCase()) {
      case 'waiting':
        return 'Bekliyor';
      case 'playing':
        return 'Oyunda';
      case 'full':
        return 'Dolu';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 260,
        maxWidth: 360,
        minHeight: 180,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade800, Colors.green.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.green.shade900, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tableName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _InfoChip(label: 'Oyun', value: gameType.toUpperCase()),
              _InfoChip(label: 'Oyuncu', value: '$currentPlayers/$maxPlayers'),
              _InfoChip(label: 'Min', value: minBuyIn.toString()),
              _InfoChip(label: 'Durum', value: statusText),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
