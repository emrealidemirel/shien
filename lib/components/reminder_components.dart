import 'package:medicine_app/l10n/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:medicine_app/theme/reminder_theme.dart';
import 'package:intl/intl.dart';
import 'package:medicine_app/models/reminder.dart';

extension ReminderCategoryStyle on ReminderCategory {
  IconData get icon => switch (this) {
    ReminderCategory.personal => Icons.wb_sunny_outlined,
    ReminderCategory.work => Icons.work_outline_rounded,
    ReminderCategory.health => Icons.favorite_border_rounded,
    ReminderCategory.entertainment => Icons.play_circle_outline_rounded,
    ReminderCategory.payments => Icons.account_balance_wallet_outlined,
  };
  Color get color => switch (this) {
    ReminderCategory.personal => const Color(0xFF8C704D),
    ReminderCategory.work => const Color(0xFF77718A),
    ReminderCategory.health => const Color(0xFF667C64),
    ReminderCategory.entertainment => const Color(0xFF936E5B),
    ReminderCategory.payments => const Color(0xFF597985),
  };
  Color foreground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Color.lerp(color, Colors.white, .4)!
      : color;

  Color tint(BuildContext context) => color.withValues(
    alpha: Theme.of(context).brightness == Brightness.dark ? .20 : .08,
  );
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String reminderDate(DateTime date) {
  final now = DateTime.now();
  if (sameDay(date, now)) return t('today');
  if (sameDay(date, DateTime(now.year, now.month, now.day + 1))) {
    return t('tomorrow');
  }
  return DateFormat('d MMM', appLocale).format(date);
}

class ReminderSurface extends StatelessWidget {
  const ReminderSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => localized(
    context,
    () => Material(
      color: color ?? Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ReminderTheme.surfaceRadius),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: .65),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class ReminderEmptyState extends StatelessWidget {
  const ReminderEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.action,
    this.icon = Icons.check_rounded,
  });
  final String title;
  final String description;
  final Widget? action;
  final IconData icon;
  @override
  Widget build(BuildContext context) => localized(
    context,
    () => Padding(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 18),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.secondary.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(
              icon,
              size: 34,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onTap,
    required this.onComplete,
    this.showDate = false,
    this.allowComplete = true,
    this.occurrenceAt,
  });
  final Reminder reminder;
  final VoidCallback onTap;
  final VoidCallback onComplete;
  final bool showDate;
  final bool allowComplete;
  final DateTime? occurrenceAt;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final at = occurrenceAt ?? reminder.effectiveAt;
    final overdue = reminder.isActive && at.isBefore(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ReminderTheme.surfaceRadius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .7)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 36,
                  decoration: BoxDecoration(
                    color: reminder.category.tint(context),
                    borderRadius: BorderRadius.circular(
                      ReminderTheme.compactRadius,
                    ),
                  ),
                  child: Icon(
                    reminder.category.icon,
                    color: reminder.category.foreground(context),
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              reminder.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    decoration: reminder.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                            ),
                          ),
                          if (reminder.isPriority) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.star_rounded,
                              color: scheme.tertiary,
                              size: 17,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            reminder.snoozedUntil != null &&
                                    at == reminder.effectiveAt
                                ? Icons.snooze_rounded
                                : Icons.schedule_rounded,
                            size: 13,
                            color: overdue
                                ? scheme.error
                                : scheme.onSurfaceVariant,
                          ),
                          Text(
                            '${showDate ? '${reminderDate(at)} · ' : ''}${DateFormat.Hm().format(at)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: overdue
                                      ? scheme.error
                                      : scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            '· ${reminder.isPaused ? t('paused') : reminder.scheduleLabel}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          for (final tag in reminder.tags.take(2))
                            Text(
                              '#$tag',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.tertiary),
                            ),
                          if (reminder.tags.length > 2)
                            Text(
                              '+${reminder.tags.length - 2}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: reminder.isCompleted
                      ? t('completed')
                      : !allowComplete
                      ? t('future_occurrence')
                      : t('complete'),
                  onPressed: reminder.isActive && allowComplete
                      ? onComplete
                      : null,
                  icon: Icon(
                    reminder.isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: reminder.isCompleted
                        ? scheme.secondary
                        : scheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared heading for the main content pages; parent supplies page margins.
class ReminderPageHeader extends StatelessWidget {
  const ReminderPageHeader({
    super.key,
    required this.title,
    required this.description,
  });
  final String title, description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ),
      const SizedBox(height: 8),
      Text(description, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class ReminderSectionLabel extends StatelessWidget {
  const ReminderSectionLabel(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => localized(
    context,
    () => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ?trailing,
        ],
      ),
    ),
  );
}
