import 'package:medicine_app/l10n/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:medicine_app/blocs/reminder/reminder_cubit.dart';
import 'package:medicine_app/components/reminder_components.dart';

class ReminderHistoryPage extends StatelessWidget {
  const ReminderHistoryPage({super.key, required this.onError});
  final ValueChanged<String> onError;

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final state = context.watch<ReminderCubit>().state;
    final history = [...state.completions]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
      children: [
        ReminderPageHeader(
          title: t('history_title'),
          description: t('history_description'),
        ),
        ReminderSectionLabel(
          t('completed_count', args: {'count': (history.length).toString()}),
          trailing: history.isEmpty
              ? null
              : TextButton(
                  onPressed: () async {
                    final cubit = context.read<ReminderCubit>();
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialog) => AlertDialog(
                        title: Text(t('clear_history_title')),
                        content: Text(t('clear_history_description')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialog, false),
                            child: Text(t('cancel')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialog, true),
                            child: Text(t('clear')),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      try {
                        await cubit.clearHistory();
                      } catch (_) {
                        onError(t('error_clear_history'));
                      }
                    }
                  },
                  child: Text(t('clear')),
                ),
        ),
        if (history.isEmpty)
          ReminderEmptyState(
            title: t('history_empty'),
            description: t('history_empty_description'),
            icon: Icons.done_all_rounded,
          ),
        for (final completion in history)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ReminderSurface(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          completion.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${completion.category.label} · ${DateFormat('d MMM yyyy, HH:mm', appLocale).format(completion.completedAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
