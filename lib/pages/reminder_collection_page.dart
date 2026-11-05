import 'package:shien/l10n/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shien/blocs/reminder/reminder_cubit.dart';
import 'package:shien/components/reminder_components.dart';
import 'package:shien/models/reminder.dart';
import 'package:shien/services/reminder_collection.dart';

class ReminderCollectionPage extends StatefulWidget {
  const ReminderCollectionPage({
    super.key,
    this.category,
    this.tag,
    this.priorityOnly = false,
    required this.onBack,
    required this.onDetails,
    required this.onComplete,
  });
  final ReminderCategory? category;
  final String? tag;
  final bool priorityOnly;
  final VoidCallback onBack;
  final ValueChanged<Reminder> onDetails, onComplete;

  @override
  State<ReminderCollectionPage> createState() => _ReminderCollectionPageState();
}

class _ReminderCollectionPageState extends State<ReminderCollectionPage> {
  late ReminderCategory? _category = widget.category;
  late String? _tag = widget.tag;
  late bool _priorityOnly = widget.priorityOnly;
  String _query = '';
  ReminderStatus _status = ReminderStatus.active;
  ReminderSort _sort = ReminderSort.scheduled;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final state = context.watch<ReminderCubit>().state;
    final heading = _tag != null
        ? '#$_tag'
        : _priorityOnly
        ? t('important_list')
        : _category == null
        ? t('all_reminders')
        : _category!.label;
    final items = collectReminders(
      state.reminders,
      query: _query,
      category: _category,
      tag: _tag,
      priorityOnly: _priorityOnly,
      status: _status,
      sort: _sort,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      children: [
        ReminderPageHeader(
          title: heading,
          description: t('collection_description'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(t('lists')),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: t('search_reminders'),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: t('clear_search'),
                    onPressed: () => setState(() {
                      _query = '';
                      _search.clear();
                    }),
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(t('all')),
                  selected: _category == null && _tag == null && !_priorityOnly,
                  onSelected: (_) => setState(() {
                    _category = null;
                    _tag = null;
                    _priorityOnly = false;
                  }),
                ),
              ),
              for (final category in ReminderCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category.label),
                    selected: _category == category,
                    onSelected: (_) => setState(() {
                      _category = category;
                      _tag = null;
                      _priorityOnly = false;
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          children: [
            for (final status in ReminderStatus.values)
              ChoiceChip(
                label: Text(status.label),
                selected: _status == status,
                onSelected: (_) => setState(() => _status = status),
              ),
          ],
        ),
        ReminderSectionLabel(
          t('reminder_count', args: {'count': (items.length).toString()}),
          trailing: PopupMenuButton<ReminderSort>(
            tooltip: t('sort'),
            initialValue: _sort,
            onSelected: (sort) => setState(() => _sort = sort),
            icon: const Icon(Icons.sort_rounded),
            itemBuilder: (_) => [
              for (final sort in ReminderSort.values)
                CheckedPopupMenuItem(
                  value: sort,
                  checked: _sort == sort,
                  child: Text(sort.label),
                ),
            ],
          ),
        ),
        Text(_sort.label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        if (items.isEmpty)
          ReminderEmptyState(
            title: _query.isNotEmpty
                ? t('search_empty')
                : t('collection_empty'),
            description: _query.isNotEmpty
                ? t('search_empty_description')
                : t('collection_empty_description'),
            icon: Icons.layers_outlined,
          ),
        for (final reminder in items)
          ReminderCard(
            reminder: reminder,
            showDate: true,
            onTap: () => widget.onDetails(reminder),
            onComplete: () => widget.onComplete(reminder),
          ),
      ],
    );
  }
}
