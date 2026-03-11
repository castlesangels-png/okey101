import 'package:flutter/material.dart';

class MessageBox extends StatelessWidget {
  final String message;
  final bool isError;

  const MessageBox({
    super.key,
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isError ? Colors.red.withOpacity(0.10) : Colors.green.withOpacity(0.10);
    final textColor = isError ? Colors.red : Colors.green;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: TextStyle(color: textColor),
      ),
    );
  }
}
