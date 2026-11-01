import 'package:medicine_app/l10n/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medicine_app/components/reminder_components.dart';

class ReminderDateTimeFields extends StatelessWidget {
  const ReminderDateTimeFields({
    super.key,
    required this.date,
    required this.time,
    required this.onDate,
    required this.onTime,
  });
  final DateTime date;
  final TimeOfDay time;
  final VoidCallback onDate, onTime;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final theme = Theme.of(context);
    return ReminderSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            key: const ValueKey('reminder-date-field'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(
              DateFormat('d MMMM yyyy', appLocale).format(date),
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'Manrope',
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(DateFormat('EEEE', appLocale).format(date)),
            trailing: const Icon(Icons.expand_more_rounded),
            onTap: onDate,
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          ListTile(
            key: const ValueKey('reminder-time-field'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            leading: const Icon(Icons.schedule_rounded),
            title: Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontFamily: 'Manrope',
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(t('notification_time')),
            trailing: const Icon(Icons.edit_outlined, size: 20),
            onTap: onTime,
          ),
        ],
      ),
    );
  }
}
