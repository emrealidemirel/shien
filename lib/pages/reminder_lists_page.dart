import 'package:shien/l10n/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shien/blocs/reminder/reminder_cubit.dart';
import 'package:shien/components/reminder_components.dart';
import 'package:shien/models/reminder.dart';
import 'package:shien/models/reminder_template.dart';

class ReminderListsPage extends StatelessWidget {
  const ReminderListsPage({
    super.key,
    required this.onCategory,
    required this.onAll,
    required this.onTemplate,
    required this.onPriority,
    required this.onTag,
    required this.onHistory,
  });
  final ValueChanged<ReminderCategory> onCategory;
  final VoidCallback onAll, onHistory;
  final ValueChanged<ReminderTemplate> onTemplate;
  final VoidCallback onPriority;
  final ValueChanged<String> onTag;
  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final state = context.watch<ReminderCubit>().state;
    final tags = state.reminders.expand((r) => r.tags).toSet().toList()..sort();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      children: [
        ReminderPageHeader(
          title: t('lists_title'),
          description: t('lists_description'),
        ),
        const SizedBox(height: 20),
        ReminderSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: Text(t('all_reminders')),
                subtitle: Text(
                  t(
                    'all_count',
                    args: {'count': (state.reminders.length).toString()},
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: onAll,
              ),
              const Divider(height: 1, indent: 56, endIndent: 16),
              ListTile(
                leading: Icon(
                  Icons.star_outline_rounded,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                title: Text(t('important_list')),
                subtitle: Text(
                  t(
                    'important_count',
                    args: {
                      'count':
                          (state.reminders
                                  .where((r) => r.isPriority && r.isActive)
                                  .length)
                              .toString(),
                    },
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: onPriority,
              ),
              const Divider(height: 1, indent: 56, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.done_all_rounded),
                title: Text(t('history_title')),
                subtitle: Text(
                  t(
                    'history_count',
                    args: {'count': (state.completions.length).toString()},
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: onHistory,
              ),
              for (final category in ReminderCategory.values) ...[
                const Divider(height: 1, indent: 56, endIndent: 16),
                ListTile(
                  leading: Icon(
                    category.icon,
                    color: category.foreground(context),
                  ),
                  title: Text(category.label),
                  subtitle: Text(
                    t(
                      'active_count',
                      args: {
                        'count':
                            (state.reminders
                                    .where(
                                      (r) =>
                                          r.category == category && r.isActive,
                                    )
                                    .length)
                                .toString(),
                      },
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => onCategory(category),
                ),
              ],
            ],
          ),
        ),
        if (tags.isNotEmpty) ...[
          ReminderSectionLabel(t('tags')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in tags)
                ActionChip(
                  avatar: const Icon(Icons.tag_rounded, size: 17),
                  label: Text(tag),
                  onPressed: () => onTag(tag),
                ),
            ],
          ),
        ],
        ReminderSectionLabel(t('templates')),
        Text(
          t('templates_description'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final template in ReminderTemplate.samples)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ReminderSurface(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(
                  template.category.icon,
                  color: template.category.foreground(context),
                ),
                title: Text(template.title),
                subtitle: Text(template.repeat.label),
                trailing: const Icon(Icons.add_rounded),
                onTap: () => onTemplate(template),
              ),
            ),
          ),
      ],
    );
  }
}
