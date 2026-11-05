import 'package:shien/l10n/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shien/blocs/reminder/reminder_cubit.dart';
import 'package:shien/components/reminder_components.dart';
import 'package:shien/models/reminder.dart';

class ReminderPlanPage extends StatefulWidget {
  const ReminderPlanPage({
    super.key,
    required this.onDetails,
    required this.onComplete,
  });
  final ValueChanged<Reminder> onDetails, onComplete;
  @override
  State<ReminderPlanPage> createState() => _ReminderPlanPageState();
}

class _ReminderPlanPageState extends State<ReminderPlanPage> {
  int _days = 7;
  DateTime? _selectedDay;
  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final state = context.watch<ReminderCubit>().state;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day + _days);
    final entries = <(Reminder, DateTime)>[];
    for (final r in state.reminders.where((r) => r.isActive)) {
      var at = r.effectiveAt;
      // Display overdue reminders separately on Today, and project each future
      // occurrence without changing the stored next completion target.
      if (at.isBefore(start)) {
        final next = r.nextOccurrence(
          start.subtract(const Duration(microseconds: 1)),
        );
        if (next == null) continue;
        at = next;
      }
      for (var i = 0; i < 150 && at.isBefore(end); i++) {
        entries.add((r, at));
        final next = r.nextOccurrence(at);
        if (next == null) break;
        at = next;
      }
    }
    entries.sort((a, b) => a.$2.compareTo(b.$2));
    // Reset a selected date after midnight or when switching the range.
    final selected = _selectedDay;
    final selectedInRange =
        selected != null && !selected.isBefore(start) && selected.isBefore(end);
    final visible = selectedInRange
        ? entries.where((entry) => sameDay(entry.$2, selected)).toList()
        : entries;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      children: [
        ReminderPageHeader(
          title: t('plan_title'),
          description: t('plan_description'),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          children: [
            for (final days in [7, 30])
              ChoiceChip(
                label: Text(
                  t('next_n_days', args: {'count': (days).toString()}),
                ),
                selected: _days == days,
                onSelected: (_) => setState(() {
                  _days = days;
                  _selectedDay = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(t('all_days')),
                  selected: !selectedInRange,
                  onSelected: (_) => setState(() => _selectedDay = null),
                ),
              ),
              for (var day = 0; day < _days; day++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      DateFormat(
                        'd MMM · E',
                        appLocale,
                      ).format(DateTime(now.year, now.month, now.day + day)),
                    ),
                    selected:
                        selectedInRange &&
                        sameDay(
                          selected,
                          DateTime(now.year, now.month, now.day + day),
                        ),
                    onSelected: (_) => setState(
                      () => _selectedDay = DateTime(
                        now.year,
                        now.month,
                        now.day + day,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (visible.isEmpty)
          ReminderEmptyState(
            title: t('plan_empty'),
            description: t('plan_empty_description'),
            icon: Icons.event_note_outlined,
          ),
        for (var index = 0; index < visible.length; index++) ...[
          if (index == 0 || !sameDay(visible[index - 1].$2, visible[index].$2))
            ReminderSectionLabel(
              sameDay(visible[index].$2, now)
                  ? t('today')
                  : DateFormat(
                      'd MMMM · EEEE',
                      appLocale,
                    ).format(visible[index].$2),
            ),
          ReminderCard(
            reminder: visible[index].$1,
            occurrenceAt: visible[index].$2,
            onTap: () => _openOccurrence(visible[index].$1, visible[index].$2),
            onComplete: () => widget.onComplete(visible[index].$1),
            allowComplete: visible[index].$2.isAtSameMomentAs(
              visible[index].$1.effectiveAt,
            ),
          ),
        ],
      ],
    );
  }

  void _openOccurrence(Reminder reminder, DateTime at) {
    if (at.isAtSameMomentAs(reminder.effectiveAt)) {
      widget.onDetails(reminder);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t('occurrence_preview'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 12),
              Text(
                reminder.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(DateFormat('d MMMM yyyy · HH:mm', appLocale).format(at)),
              const SizedBox(height: 8),
              Text(
                t(
                  'occurrence_description',
                  args: {'value': (reminder.scheduleLabel).toString()},
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  widget.onDetails(reminder);
                },
                child: Text(t('open_next_occurrence')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
