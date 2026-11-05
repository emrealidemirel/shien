import 'package:shien/l10n/app_localization.dart';
import 'package:shien/components/reminder_form_section.dart';
import 'package:shien/components/reminder_date_time_fields.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shien/blocs/reminder/reminder_cubit.dart';
import 'package:shien/components/reminder_components.dart';
import 'package:shien/components/reminder_sound_picker.dart';
import 'package:shien/models/reminder.dart';
import 'package:shien/models/reminder_template.dart';
import 'package:shien/services/reminder_quick_input.dart';
import 'package:uuid/uuid.dart';

class ReminderFormPage extends StatefulWidget {
  const ReminderFormPage({
    super.key,
    this.reminder,
    this.copyFrom,
    this.template,
    this.onSaved,
    this.onClose,
  });
  final Reminder? reminder;
  final Reminder? copyFrom;
  final ReminderTemplate? template;
  final VoidCallback? onSaved;
  final VoidCallback? onClose;
  @override
  State<ReminderFormPage> createState() => _ReminderFormPageState();
}

class _ReminderFormPageState extends State<ReminderFormPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _note, _tag;
  late DateTime _date;
  late TimeOfDay _time;
  late ReminderRepeat _repeat;
  late ReminderCategory _category;
  late ReminderSound _sound;
  late Set<int> _days;
  late Set<int> _extraTimes;
  late List<String> _tags;
  int _interval = 1, _lead = 0;
  bool _lastDay = false, _saving = false;
  bool _priority = false;
  bool _validated = false;
  String? _locale;
  String? _error;
  ReminderQuickInput? _suggestion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (_locale != null && _locale != language) {
      _error = null;
      if (_validated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _form.currentState?.validate();
        });
      }
    }
    _locale = language;
  }

  @override
  void initState() {
    super.initState();
    final r = widget.reminder ?? widget.copyFrom;
    final t = widget.template;
    var initial = r?.anchorAt ?? DateTime.now().add(const Duration(hours: 1));
    if (widget.copyFrom != null) {
      final now = DateTime.now();
      initial = r!.nextOccurrence(now) ?? now.add(const Duration(hours: 1));
    }
    if (t != null) {
      final now = DateTime.now();
      initial = DateTime(now.year, now.month, now.day, t.hour, t.minute);
      if (!initial.isAfter(now)) {
        initial = DateTime(now.year, now.month, now.day + 1, t.hour, t.minute);
      }
    }
    _title = TextEditingController(text: r?.title ?? t?.title ?? '');
    _note = TextEditingController(text: r?.note ?? '');
    _tag = TextEditingController();
    _date = widget.copyFrom != null ? initial : r?.dueAt ?? initial;
    _time = TimeOfDay.fromDateTime(initial);
    _repeat = r?.repeat ?? t?.repeat ?? ReminderRepeat.once;
    _category = r?.category ?? t?.category ?? ReminderCategory.personal;
    _sound = r?.sound ?? context.read<ReminderCubit>().state.defaultSound;
    _days = r?.weekdays.toSet() ?? {_date.weekday};
    _extraTimes = r?.additionalTimes.toSet() ?? {};
    _tags = [...?r?.tags];
    _priority = r?.isPriority ?? false;
    _interval = r?.interval ?? 1;
    _lastDay = r?.lastDayOfMonth ?? false;
    _lead = r?.leadMinutes ?? t?.leadMinutes ?? 0;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _tag.dispose();
    super.dispose();
  }

  void _addTag(String value) {
    final tag = value
        .trim()
        .replaceFirst(RegExp(r'^#'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .toLowerCase();
    if (tag.isEmpty) return;
    if (tag.length > 24) {
      setState(() => _error = t('error_tag_length'));
      return;
    }
    if (_tags.length >= 5 && !_tags.contains(tag)) {
      setState(() => _error = t('error_tag_count'));
      return;
    }
    setState(() {
      if (!_tags.contains(tag)) _tags.add(tag);
      _tag.clear();
      _error = null;
    });
  }

  void _setTime(DateTime at) => setState(() {
    _date = at;
    _time = TimeOfDay.fromDateTime(at);
    _extraTimes.remove(at.hour * 60 + at.minute);
    _error = null;
  });
  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final at = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(first) ? first : _date,
      firstDate: first,
      lastDate: DateTime(
        _date.year > now.year + 20 ? _date.year : now.year + 20,
        12,
        31,
      ),
      helpText: t('choose_date'),
      cancelText: t('cancel'),
      confirmText: t('select'),
    );
    if (at != null && mounted) {
      _setTime(DateTime(at.year, at.month, at.day, _time.hour, _time.minute));
    }
  }

  Future<void> _chooseTime({bool additional = false}) async {
    final at = await showTimePicker(
      context: context,
      initialTime: _time,
      initialEntryMode: TimePickerEntryMode.input,
      helpText: additional ? t('additional_time') : t('notification_time'),
      cancelText: t('cancel'),
      confirmText: t('select'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (at != null && mounted) {
      setState(() {
        final minutes = at.hour * 60 + at.minute;
        if (additional) {
          if (minutes == _time.hour * 60 + _time.minute ||
              _extraTimes.contains(minutes)) {
            _error = t('error_duplicate_time');
            return;
          }
          _extraTimes.add(minutes);
        } else {
          _time = at;
          _extraTimes.remove(minutes);
        }
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    _validated = true;
    if (!_form.currentState!.validate()) return;
    if (_tag.text.trim().isNotEmpty) {
      _addTag(_tag.text);
      if (_error != null) return;
    }
    if (_repeat == ReminderRepeat.weekly && _days.isEmpty) {
      setState(() => _error = t('error_choose_day'));
      return;
    }
    final now = DateTime.now();
    // Preserve the interval anchor on edit; snoozing or completing must never
    // shift an every-N-days/years schedule.
    final old = widget.reminder;
    final unchangedSchedule =
        old != null &&
        old.repeat == _repeat &&
        old.interval == _interval &&
        old.anchorAt.hour == _time.hour &&
        old.anchorAt.minute == _time.minute &&
        sameDay(old.dueAt, _date) &&
        old.lastDayOfMonth == _lastDay &&
        setEquals(old.weekdays.toSet(), _days) &&
        setEquals(old.additionalTimes.toSet(), _extraTimes);
    final anchor = unchangedSchedule
        ? old.anchorAt
        : DateTime(
            _date.year,
            _date.month,
            _date.day,
            _time.hour,
            _time.minute,
          );
    var r = Reminder(
      id: old?.id ?? const Uuid().v4(),
      title: _title.text.trim(),
      note: _note.text.trim(),
      anchorAt: anchor,
      dueAt: anchor,
      createdAt: old?.createdAt ?? now,
      repeat: _repeat,
      category: _category,
      sound: _sound,
      weekdays: _days.toList()..sort(),
      interval: _interval,
      lastDayOfMonth: _repeat == ReminderRepeat.monthly && _lastDay,
      additionalTimes:
          _repeat == ReminderRepeat.once ||
                    _repeat == ReminderRepeat.afterCompletion
                ? []
                : _extraTimes.toList()
            ..sort(),
      leadMinutes: _lead,
      isPriority: _priority,
      tags: _tags,
      isPaused: old?.isPaused ?? false,
    );
    if (unchangedSchedule) {
      // Editing a note, category or sound must not complete, reopen, postpone
      // or lose the snooze of the occurrence the user is currently tracking.
      r = r.copyWith(
        dueAt: old.dueAt,
        isCompleted: old.isCompleted,
        snoozedUntil: old.snoozedUntil,
      );
    } else if (_repeat == ReminderRepeat.once ||
        _repeat == ReminderRepeat.afterCompletion) {
      if (!anchor.isAfter(now)) {
        setState(() => _error = t('error_future_time'));
        return;
      }
    } else {
      final next = r.nextOccurrence(now);
      if (next == null) {
        setState(() => _error = t('error_repeat_days'));
        return;
      }
      r = r.copyWith(dueAt: next);
    }
    setState(() => _saving = true);
    try {
      await context.read<ReminderCubit>().save(r, expected: old);
      if (!mounted) return;
      if (widget.onSaved != null) {
        widget.onSaved!();
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is StateError
              ? e.message
              : e is ArgumentError
              ? e.message.toString()
              : t('error_save');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: widget.onClose == null
            ? null
            : IconButton(
                tooltip: t('back'),
                onPressed: _saving ? null : widget.onClose,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        title: Text(
          widget.reminder == null ? t('new_reminder') : t('edit_reminder'),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(_error!, style: TextStyle(color: scheme.error)),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 20),
                label: Text(_saving ? t('saving') : t('save_reminder')),
              ),
            ],
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            ReminderSectionLabel(t('reminder_title_label')),
            TextFormField(
              controller: _title,
              maxLength: 100,
              minLines: 1,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) => setState(
                () => _suggestion = ReminderQuickInput.parse(
                  value,
                  DateTime.now(),
                ),
              ),
              decoration: InputDecoration(
                hintText: t('reminder_title_hint'),
                counterText: '',
                helperText: t('quick_input_hint'),
                helperMaxLines: 2,
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? t('error_title_required')
                  : null,
            ),
            if (_suggestion != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text(
                    t(
                      'apply_suggested_time',
                      args: {
                        'date': (DateFormat(
                          'd MMM · HH:mm',
                          appLocale,
                        ).format(_suggestion!.at)).toString(),
                      },
                    ),
                  ),
                  onPressed: () {
                    final suggestion = _suggestion!;
                    _title.text = suggestion.title;
                    _setTime(suggestion.at);
                    setState(() => _suggestion = null);
                  },
                ),
              ),
            ReminderSectionLabel(t('when')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: Text(t('in_30_minutes')),
                  onPressed: () =>
                      _setTime(DateTime.now().add(const Duration(minutes: 30))),
                ),
                ActionChip(
                  label: Text(t('in_one_hour')),
                  onPressed: () =>
                      _setTime(DateTime.now().add(const Duration(hours: 1))),
                ),
                ActionChip(
                  label: Text(t('tomorrow_morning')),
                  onPressed: () {
                    final n = DateTime.now();
                    _setTime(DateTime(n.year, n.month, n.day + 1, 9));
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            ReminderDateTimeFields(
              date: _date,
              time: _time,
              onDate: _chooseDate,
              onTime: () => _chooseTime(),
            ),
            const SizedBox(height: 24),
            ReminderFormSection(
              title: t('repeat'),
              summary: _repeatSummary,
              icon: Icons.repeat_rounded,
              child: _repeatControls(),
            ),
            ReminderFormSection(
              title: t('notification'),
              summary:
                  '${_sound.label} · ${_lead == 0 ? t('at_scheduled_time') : t('early_alert_summary', args: {
                          'value': (_lead == 1440
                              ? t('one_day')
                              : _lead == 60
                              ? t('one_hour')
                              : t('minutes_duration', args: {'count': (_lead).toString()})).toString(),
                        })}',
              icon: Icons.notifications_outlined,
              child: _notificationControls(context),
            ),
            ReminderFormSection(
              title: t('list_and_tags'),
              summary:
                  '${_category.label}${_priority ? t('important_suffix') : ''}${_tags.isEmpty ? '' : t('tags_count_suffix', args: {'count': (_tags.length).toString()})}',
              icon: Icons.label_outline_rounded,
              child: _organizationControls(context),
            ),
            ReminderSectionLabel(t('optional_note')),
            TextFormField(
              controller: _note,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: t('note_hint'),
                counterText: '',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _intervalLabel(int interval) {
    if (_repeat == ReminderRepeat.afterCompletion) {
      return t(
        interval == 1 ? 'after_one_day' : 'after_n_days',
        args: {'count': (interval).toString()},
      );
    }
    if (interval == 1) {
      return switch (_repeat) {
        ReminderRepeat.daily => t('repeat_daily'),
        ReminderRepeat.weekly => t('repeat_weekly'),
        ReminderRepeat.monthly => t('repeat_monthly'),
        ReminderRepeat.yearly => t('repeat_yearly'),
        _ => t('repeat_once'),
      };
    }
    return t(
      switch (_repeat) {
        ReminderRepeat.weekly => 'every_n_weeks',
        ReminderRepeat.monthly => 'every_n_months',
        ReminderRepeat.yearly => 'every_n_years',
        _ => 'every_n_days',
      },
      args: {'count': interval.toString()},
    );
  }

  String get _repeatSummary {
    if (_repeat == ReminderRepeat.once) return t('repeat_once');
    final interval = _intervalLabel(_interval);
    if (_repeat == ReminderRepeat.monthly) {
      return '$interval · ${_lastDay ? t('last_day_short') : t('monthly_day', args: {'count': (_date.day).toString()})}';
    }
    if (_repeat == ReminderRepeat.weekly) {
      return '$interval · ${_days.isEmpty ? t('no_days_selected') : t('selected_days_count', args: {'count': (_days.length).toString()})}';
    }
    return interval;
  }

  Widget _repeatControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final repeat in ReminderRepeat.values)
            ChoiceChip(
              label: Text(repeat.label),
              selected: _repeat == repeat,
              onSelected: (_) => setState(() {
                _repeat = repeat;
                _interval = 1;
                if (repeat != ReminderRepeat.monthly) _lastDay = false;
                if (repeat == ReminderRepeat.daily && _lead == 1440) _lead = 0;
                _error = null;
              }),
            ),
        ],
      ),
      if (_repeat != ReminderRepeat.once) ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey(_repeat),
          initialValue: _interval,
          decoration: InputDecoration(labelText: t('repeat_interval')),
          items: [
            for (var n = 1; n <= 12; n++)
              DropdownMenuItem(value: n, child: Text(_intervalLabel(n))),
          ],
          isExpanded: true,
          onChanged: (n) => setState(() {
            _interval = n!;
            if (_repeat == ReminderRepeat.daily &&
                _interval == 1 &&
                _lead == 1440) {
              _lead = 0;
            }
          }),
        ),
      ],
      if (_repeat == ReminderRepeat.weekly) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ActionChip(
              label: Text(t('weekdays')),
              onPressed: () => setState(() => _days = {1, 2, 3, 4, 5}),
            ),
            for (var day = 1; day <= 7; day++)
              FilterChip(
                label: Text(
                  [
                    t('weekday_mon'),
                    t('weekday_tue'),
                    t('weekday_wed'),
                    t('weekday_thu'),
                    t('weekday_fri'),
                    t('weekday_sat'),
                    t('weekday_sun'),
                  ][day - 1],
                ),
                selected: _days.contains(day),
                onSelected: (v) => setState(() {
                  v ? _days.add(day) : _days.remove(day);
                }),
              ),
          ],
        ),
      ],
      if (_repeat == ReminderRepeat.monthly) ...[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t('last_day_of_month')),
          subtitle: Text(
            _lastDay
                ? t('last_day_description')
                : t(
                    'monthly_day_description',
                    args: {'count': (_date.day).toString()},
                  ),
          ),
          value: _lastDay,
          onChanged: (v) => setState(() => _lastDay = v),
        ),
      ],
      if (_repeat != ReminderRepeat.once &&
          _repeat != ReminderRepeat.afterCompletion) ...[
        ReminderSectionLabel(t('additional_times')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in _extraTimes.toList()..sort())
              InputChip(
                label: Text(
                  '${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}',
                ),
                onDeleted: () => setState(() => _extraTimes.remove(t)),
              ),
            if (_extraTimes.length < 3)
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: Text(t('add_time')),
                onPressed: () => _chooseTime(additional: true),
              ),
          ],
        ),
      ],
    ],
  );

  Widget _notificationControls(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReminderSectionLabel(t('early_alert')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final minutes in [0, 5, 15, 30, 60, 1440])
              ChoiceChip(
                label: Text(
                  minutes == 0
                      ? t('no_early_alert')
                      : minutes == 1440
                      ? t('one_day_before')
                      : minutes == 60
                      ? t('one_hour_before')
                      : t(
                          'minutes_before',
                          args: {'count': (minutes).toString()},
                        ),
                ),
                selected: _lead == minutes,
                onSelected:
                    minutes == 1440 &&
                        _repeat == ReminderRepeat.daily &&
                        _interval == 1
                    ? null
                    : (_) => setState(() => _lead = minutes),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(t('early_alert_description'), style: theme.textTheme.bodySmall),
        ReminderSectionLabel(t('notification_sound')),
        ReminderSoundPicker(
          selected: _sound,
          onChanged: (v) => setState(() => _sound = v),
        ),
        const SizedBox(height: 10),
        Text(
          t('notification_sound_description'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _organizationControls(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReminderSectionLabel(t('list')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in ReminderCategory.values)
              ChoiceChip(
                showCheckmark: false,
                avatar: Icon(category.icon, size: 17, color: scheme.onSurface),
                label: Text(category.label),
                selected: _category == category,
                onSelected: (_) => setState(() => _category = category),
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(
            _priority ? Icons.star_rounded : Icons.star_outline_rounded,
            color: _priority ? scheme.tertiary : scheme.onSurfaceVariant,
          ),
          title: Text(t('mark_important')),
          subtitle: Text(t('important_description')),
          value: _priority,
          onChanged: (value) => setState(() => _priority = value),
        ),
        ReminderSectionLabel(t('tags')),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          children: [
            for (final tag in _tags)
              InputChip(
                label: Text('#$tag'),
                onDeleted: () => setState(() => _tags.remove(tag)),
              ),
          ],
        ),
        if (_tags.length < 5)
          TextField(
            controller: _tag,
            textCapitalization: TextCapitalization.none,
            maxLength: 24,
            decoration: InputDecoration(
              hintText: t('tag_hint'),
              counterText: '',
              prefixText: '#',
              suffixIcon: IconButton(
                tooltip: t('add_tag'),
                onPressed: () => _addTag(_tag.text),
                icon: const Icon(Icons.add_rounded),
              ),
            ),
            onSubmitted: _addTag,
          ),
      ],
    );
  }
}
