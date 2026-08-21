import 'package:flutter/material.dart';

class ModeSelector extends StatelessWidget {
  final String currentMode;
  final ValueChanged<String> onModeChanged;
  final bool isDark;

  const ModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: activeBg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeButton(
              modeId: 'chat',
              label: 'Chat',
              icon: Icons.chat_bubble_outline_rounded,
              isSelected: currentMode == 'chat',
              isDark: isDark,
              onTap: () => onModeChanged('chat'),
            ),
            _ModeButton(
              modeId: 'agent',
              label: 'Agent',
              icon: Icons.smart_toy_outlined,
              isSelected: currentMode == 'agent',
              isDark: isDark,
              onTap: () => onModeChanged('agent'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String modeId;
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ModeButton({
    required this.modeId,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569)),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569)),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
