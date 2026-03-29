import "package:flutter/material.dart";

import "../../models/driver_model.dart";
import "../../utils/constants.dart";

class DriverCard extends StatelessWidget {
  const DriverCard({
    super.key,
    required this.driver,
    this.onTap,
    this.selected = false,
  });

  final DriverModel driver;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: selected ? 42 : 40,
                height: selected ? 42 : 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F0F),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? Colors.white : const Color(0x2BFFFFFF),
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: driver.isOnline
                          ? AppConstants.accent
                          : Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      driver.status,
                      style: const TextStyle(color: AppConstants.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? Colors.white : const Color(0x80FFFFFF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
