import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  const AppLogo({super.key, this.size = 32, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.hive, color: AppColors.primary, size: size),
        if (showText) ...[
          const SizedBox(width: 6),
          Text(
            "Smart Bee",
            style: TextStyle(
              fontWeight: FontWeight.w900, // أرفع قليلاً لتكون أوضح
              fontSize: size * 0.55, // تقليل حجم الخط نسبة للأيقونة
              letterSpacing: 0.5,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
            ),
          ),
        ]
      ],
    );
  }
}
