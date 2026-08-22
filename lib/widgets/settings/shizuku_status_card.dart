import 'package:flutter/material.dart';
import '../../services/shizuku_service.dart';

class ShizukuStatusCard extends StatelessWidget {
  final ShizukuService shizukuService;
  final VoidCallback? onCheckAgain;
  final VoidCallback? onRequestPermission;

  const ShizukuStatusCard({
    super.key,
    required this.shizukuService,
    this.onCheckAgain,
    this.onRequestPermission,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = shizukuService.isAvailable;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAvailable ? Icons.link : Icons.link_off,
                  color: isAvailable ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  isAvailable
                      ? 'Shizuku is running'
                      : 'Shizuku not detected',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isAvailable ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!isAvailable) ...[
              const Text(
                '1. Install Shizuku from Play Store\n'
                '2. Open Shizuku and start it via Wireless Debugging\n'
                '3. Come back here and tap "Check Again"',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onCheckAgain,
                child: const Text('Check Again'),
              ),
            ] else if (!shizukuService.hasPermission) ...[
              OutlinedButton(
                onPressed: onRequestPermission,
                child: const Text('Grant Shizuku Permission'),
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Permission granted — ADB commands available',
                    style: TextStyle(color: Colors.green[700], fontSize: 13),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
