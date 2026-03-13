import 'package:flutter/material.dart';

class PlayerSeatCard extends StatelessWidget {
  final int seatNo;
  final String title;
  final String subtitle;
  final bool isOccupied;
  final bool isYou;
  final Axis rackDirection;

  const PlayerSeatCard({
    super.key,
    required this.seatNo,
    required this.title,
    required this.subtitle,
    required this.isOccupied,
    this.isYou = false,
    required this.rackDirection,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isYou
        ? Colors.green.shade700
        : isOccupied
        ? Colors.green.shade300
        : Colors.grey.shade300;

    final bgColor = isYou
        ? Colors.green.shade50
        : isOccupied
        ? Colors.white
        : Colors.grey.shade100;

    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isYou ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isOccupied
                    ? Colors.green.shade700
                    : Colors.grey.shade400,
                child: Text(
                  seatNo.toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _RackPlaceholder(direction: rackDirection, active: isOccupied),
          if (isYou) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Sen',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RackPlaceholder extends StatelessWidget {
  final Axis direction;
  final bool active;

  const _RackPlaceholder({required this.direction, required this.active});

  @override
  Widget build(BuildContext context) {
    final tileColor = active ? Colors.amber.shade200 : Colors.grey.shade300;
    final rackColor = active ? Colors.brown.shade400 : Colors.grey.shade400;

    if (direction == Axis.horizontal) {
      return Container(
        height: 18,
        width: 132,
        decoration: BoxDecoration(
          color: rackColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            6,
            (index) => Container(
              width: 14,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.black12),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 86,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 18,
            decoration: BoxDecoration(
              color: rackColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (index) => Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: tileColor,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.black12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
