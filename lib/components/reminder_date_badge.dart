import 'package:medicine_app/l10n/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A calendar leaf that keeps the day legible without repeating the full date.
class ReminderDateBadge extends StatelessWidget {
  const ReminderDateBadge({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: DateFormat('d MMMM yyyy', appLocale).format(date),
      child: ExcludeSemantics(
        child: Container(
          width: 68,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5),
                color: scheme.primaryContainer,
                child: Text(
                  DateFormat('MMM', appLocale)
                      .format(date)
                      .replaceAll('i', appLocale == 'tr' ? 'İ' : 'I')
                      .toUpperCase(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text(
                  '${date.day}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
