import 'package:shien/l10n/app_localization.dart';
import 'package:shien/components/reminder_date_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shien/blocs/reminder/reminder_cubit.dart';
import 'package:shien/components/reminder_components.dart';
import 'package:shien/models/reminder.dart';

class ReminderTodayPage extends StatelessWidget {
  const ReminderTodayPage({
    super.key,
    required this.onDetails,
    required this.onComplete,
    required this.onSettings,
    required this.onHistory,
  });
  final VoidCallback onSettings, onHistory;
  final ValueChanged<Reminder> onDetails, onComplete;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final state = context.watch<ReminderCubit>().state;
    final now = DateTime.now();
    final theme = Theme.of(context);
    final headerForeground = theme.colorScheme.onSurface;
    final active = state.reminders.where((r) => r.isActive).toList()
      ..sort((a, b) => a.effectiveAt.compareTo(b.effectiveAt));
    final overdue = active.where((r) => r.effectiveAt.isBefore(now)).toList();
    final today = active
        .where(
          (r) => sameDay(r.effectiveAt, now) && !r.effectiveAt.isBefore(now),
        )
        .toList();
    final daytime = today.where((r) => r.effectiveAt.hour < 18).toList();
    final evening = today.where((r) => r.effectiveAt.hour >= 18).toList();
    final next = active.where((r) => !r.effectiveAt.isBefore(now)).firstOrNull;
    final done = state.completions
        .where((c) => sameDay(c.completedAt, now))
        .length;
    Widget card(Reminder r, {bool date = false}) => ReminderCard(
      reminder: r,
      onTap: () => onDetails(r),
      onComplete: () => onComplete(r),
      showDate: date,
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE · yyyy', appLocale).format(now),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              MediaQuery.sizeOf(context).width < 360 ||
                                      MediaQuery.textScalerOf(
                                            context,
                                          ).scale(16) >
                                          20
                                  ? t('today')
                                  : t('today_plan'),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: headerForeground,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ReminderDateBadge(date: now),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Wrap(
                      spacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            t(
                              'pending_count',
                              args: {
                                'count': (overdue.length + today.length)
                                    .toString(),
                              },
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: onHistory,
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                          ),
                          label: Text(
                            t(
                              'completed_count',
                              args: {'count': done.toString()},
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (next != null)
                ReminderSurface(
                  color: theme.colorScheme.surfaceContainer,
                  padding: const EdgeInsets.all(18),
                  child: InkWell(
                    onTap: () => onDetails(next),
                    child: Row(
                      children: [
                        Icon(
                          Icons.upcoming_outlined,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('next_up'),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  letterSpacing: 1.5,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                next.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${reminderDate(next.effectiveAt)} · ${DateFormat.Hm().format(next.effectiveAt)} · ${_remaining(next.effectiveAt, now)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              if (state.error != null || !state.notificationsEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: TextButton.icon(
                    onPressed: onSettings,
                    icon: const Icon(Icons.notifications_outlined, size: 18),
                    label: Text(
                      state.error != null
                          ? t('check_notifications')
                          : t('enable_notifications_hint'),
                    ),
                  ),
                ),
              if (overdue.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: next != null ? 24 : 0),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t('overdue'),
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: .08,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${overdue.length}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final r in overdue)
                        card(r, date: !sameDay(r.effectiveAt, now)),
                    ],
                  ),
                ),
              if (daytime.isNotEmpty) ...[
                ReminderSectionLabel(t('daytime')),
                for (final r in daytime) card(r),
              ],
              if (evening.isNotEmpty) ...[
                ReminderSectionLabel(t('this_evening')),
                for (final r in evening) card(r),
              ],
              if (today.isEmpty && overdue.isEmpty)
                ReminderEmptyState(
                  title: t('today_empty'),
                  description: t('today_empty_description'),
                  icon: Icons.wb_sunny_outlined,
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _remaining(DateTime at, DateTime now) {
    final d = at.difference(now);
    if (d.inMinutes < 1) return t('due_soon');
    if (d.inHours < 1) {
      return t('minutes_remaining', args: {'count': (d.inMinutes).toString()});
    }
    if (d.inDays < 1) {
      return t('hours_remaining', args: {'count': (d.inHours).toString()});
    }
    return t(
      d.inDays == 1 ? 'one_day_remaining' : 'days_remaining',
      args: {'count': (d.inDays).toString()},
    );
  }
}
