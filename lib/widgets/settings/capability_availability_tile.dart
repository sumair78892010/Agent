import 'package:flutter/material.dart';

class CapabilityAvailabilityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const CapabilityAvailabilityTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(description),
      trailing: const Chip(label: Text('Existing runtime')),
    );
  }
}
