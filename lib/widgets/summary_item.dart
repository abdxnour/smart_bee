import 'package:flutter/material.dart';

class SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const SummaryItem({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("$label: ", style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
