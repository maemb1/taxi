import 'package:flutter/material.dart';
import 'package:taxi_app/core/theme/app_theme.dart';
import 'package:taxi_app/shared/models/app_user.dart';

class DriverStatusChip extends StatelessWidget {
  final AppUser driver;
  const DriverStatusChip({super.key, required this.driver});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (driver.status) {
      DriverStatus.available => (AppTheme.success, Icons.circle),
      DriverStatus.busy => (AppTheme.accent, Icons.directions_car),
      DriverStatus.offline => (Colors.grey, Icons.circle_outlined),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(driver.name,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              if (driver.currentZone != null &&
                  driver.status == DriverStatus.available)
                Text(driver.currentZone!,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }
}
