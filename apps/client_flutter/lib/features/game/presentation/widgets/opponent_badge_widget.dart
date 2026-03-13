import 'package:flutter/material.dart';

class OpponentBadgeWidget extends StatelessWidget {
  const OpponentBadgeWidget({
    super.key,
    required this.displayName,
    required this.username,
    required this.chips,
    required this.modeText,
    required this.isActiveTurn,
    this.avatarType,
  });

  final String displayName;
  final String username;
  final int chips;
  final String modeText;
  final bool isActiveTurn;
  final String? avatarType;

  @override
  Widget build(BuildContext context) {
    final icon = switch ((avatarType ?? '').toLowerCase()) {
      'male' => Icons.face_4,
      'female' => Icons.face_3,
      _ => Icons.account_circle,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActiveTurn ? const Color(0xFF1B5E20) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActiveTurn ? const Color(0xFF81C784) : const Color(0xFF424242),
          width: isActiveTurn ? 1.6 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '@$username',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$chips chip • $modeText',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (isActiveTurn) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.radio_button_checked,
              color: Color(0xFFFFC107),
              size: 16,
            ),
          ],
        ],
      ),
    );
  }
}
