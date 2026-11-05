import 'package:shien/l10n/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shien/blocs/reminder/reminder_cubit.dart';
import 'package:shien/components/reminder_components.dart';
import 'package:shien/models/reminder.dart';

Future<void> showReminderDetails({
  required BuildContext context,
  required Reminder reminder,
  required ValueChanged<Reminder> onEdit,
  required ValueChanged<Reminder> onCopy,
  required ValueChanged<Reminder> onComplete,
  required ValueChanged<String> onError,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    reminder.category.icon,
                    color: reminder.category.foreground(context),
                  ),
                  const SizedBox(width: 10),
                  Text(reminder.category.label),
                  if (reminder.isPriority) ...[
                    const SizedBox(width: 10),
                    Icon(
                      Icons.star_rounded,
                      color: Theme.of(context).colorScheme.tertiary,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(t('important')),
                  ],
                  const Spacer(),
                  IconButton(
                    tooltip: t('edit'),
                    onPressed: () {
                      Navigator.pop(sheet);
                      onEdit(reminder);
                    },
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                reminder.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                '${DateFormat('d MMMM yyyy · HH:mm', appLocale).format(reminder.effectiveAt)}\n${reminder.scheduleLabel} · ${reminder.sound.label}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (reminder.tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final tag in reminder.tags)
                      Chip(
                        avatar: const Icon(Icons.tag_rounded, size: 16),
                        label: Text(tag),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
              if (reminder.note.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(reminder.note),
              ],
              const SizedBox(height: 24),
              if (reminder.isActive) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheet);
                      onComplete(reminder);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: Text(t('completed')),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t('snooze'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final minutes in [10, 30, 60])
                      ActionChip(
                        label: Text(
                          minutes == 60
                              ? t('one_hour')
                              : t(
                                  'minutes_duration',
                                  args: {'count': (minutes).toString()},
                                ),
                        ),
                        onPressed: () async {
                          Navigator.pop(sheet);
                          try {
                            await context.read<ReminderCubit>().snooze(
                              reminder.id,
                              Duration(minutes: minutes),
                            );
                          } catch (_) {
                            onError(t('error_snooze'));
                          }
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheet);
                      onCopy(reminder);
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: Text(t('duplicate')),
                  ),
                  if (!reminder.isCompleted)
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheet);
                        try {
                          await context.read<ReminderCubit>().togglePause(
                            reminder.id,
                          );
                        } catch (e) {
                          onError(
                            e is StateError ? e.message : t('error_action'),
                          );
                        }
                      },
                      icon: Icon(
                        reminder.isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                      ),
                      label: Text(reminder.isPaused ? t('resume') : t('pause')),
                    ),
                  TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheet);
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialog) => AlertDialog(
                          title: Text(t('delete_title')),
                          content: Text(t('delete_description')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialog, false),
                              child: Text(t('cancel')),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(dialog, true),
                              child: Text(t('delete')),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        try {
                          await context.read<ReminderCubit>().delete(
                            reminder.id,
                          );
                        } catch (_) {
                          onError(t('error_delete'));
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(t('delete')),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
