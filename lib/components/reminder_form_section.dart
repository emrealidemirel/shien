import 'package:flutter/material.dart';
import 'package:shien/components/reminder_components.dart';

class ReminderFormSection extends StatelessWidget {
  const ReminderFormSection({
    super.key,
    required this.title,
    required this.summary,
    required this.icon,
    required this.child,
  });
  final String title, summary;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: ReminderSurface(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        maintainState: true,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(icon, size: 22),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(summary, style: Theme.of(context).textTheme.bodySmall),
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
        children: [child],
      ),
    ),
  );
}
