import 'package:flutter/material.dart';

class GameTileWidget extends StatelessWidget {
  final String value;
  final Color color;
  final bool isJoker;
  final bool isFakeOkey;
  final double width;
  final double height;

  const GameTileWidget({
    super.key,
    required this.value,
    required this.color,
    this.isJoker = false,
    this.isFakeOkey = false,
    this.width = 34,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isFakeOkey
        ? Colors.deepPurple
        : isJoker
            ? Colors.purple.shade300
            : Colors.black12;

    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: isFakeOkey ? Colors.purple.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: (isJoker || isFakeOkey) ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: isFakeOkey
            ? Icon(
                Icons.auto_awesome,
                color: Colors.deepPurple.shade400,
                size: 20,
              )
            : Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}
