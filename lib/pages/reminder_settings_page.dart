import 'package:shien/l10n/app_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shien/services/backup/reminder_backup.dart';
import 'package:shien/services/notifications/reminder_schedule.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shien/blocs/reminder/reminder_cubit.dart';
import 'package:shien/components/reminder_components.dart';
import 'package:shien/models/reminder.dart';
import 'package:intl/intl.dart';
import 'package:shien/components/reminder_sound_picker.dart';
import 'package:shien/services/notifications/reminder_notification_service.dart';

class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key});
  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  bool _changingLanguage = false;

  Future<void> _setLanguage(String language) async {
    if (_changingLanguage || context.locale.languageCode == language) return;
    setState(() => _changingLanguage = true);
    try {
      await context.setLocale(Locale(language));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t('error_language'))));
      }
    } finally {
      if (mounted) setState(() => _changingLanguage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final cubit = context.read<ReminderCubit>();
    final state = context.watch<ReminderCubit>().state;
    final service = cubit.notifications;
    List<ReminderNotificationPlan> plans = const [];
    var capacityExceeded = false;
    try {
      plans = buildReminderPlans(state.reminders, DateTime.now());
    } on StateError {
      // Other devices may contribute more reminders than this device can
      // schedule. Keep settings accessible so the user can resolve the limit.
      capacityExceeded = true;
    }
    final customPlans = plans.where(
      (p) =>
          !hasPersistentSchedule(p.reminder) &&
          p.reminder.repeat != ReminderRepeat.once &&
          p.reminder.repeat != ReminderRepeat.afterCompletion,
    );
    final coverage = <String, DateTime>{};
    for (final p in customPlans) {
      if (!p.early) coverage[p.reminder.id] = p.at;
    }
    final coverageDates = coverage.values.toList()..sort();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      children: [
        const SizedBox(height: 8),
        Text(
          t('settings_description'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        ReminderSectionLabel(t('language')),
        ReminderSurface(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final language in const {
                'tr': 'Türkçe',
                'en': 'English',
              }.entries)
                ChoiceChip(
                  label: Text(language.value),
                  selected: context.locale.languageCode == language.key,
                  onSelected: _changingLanguage
                      ? null
                      : (_) => _setLanguage(language.key),
                ),
            ],
          ),
        ),
        ReminderSectionLabel(t('appearance')),
        ReminderSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('theme'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in ThemeMode.values)
                    ChoiceChip(
                      label: Text(switch (mode) {
                        ThemeMode.system => t('theme_system'),
                        ThemeMode.light => t('theme_light'),
                        ThemeMode.dark => t('theme_dark'),
                      }),
                      selected: state.themeMode == mode,
                      onSelected: (_) => cubit.setTheme(mode),
                    ),
                ],
              ),
            ],
          ),
        ),
        ReminderSectionLabel(t('notifications')),
        ReminderSurface(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    state.notificationsEnabled
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      service.supported
                          ? state.notificationsEnabled
                                ? t('notifications_enabled')
                                : t('notification_permission_required')
                          : t('notifications_unsupported'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                t('notifications_offline'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (service.supported) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: cubit.enableNotifications,
                      child: Text(t('check_permission')),
                    ),
                    TextButton(
                      onPressed: () => openAppSettings(),
                      child: Text(t('device_settings')),
                    ),
                  ],
                ),
              ],
              if (!kIsWeb &&
                  defaultTargetPlatform == TargetPlatform.android &&
                  service is ReminderNotificationService) ...[
                const Divider(),
                Text(
                  t('exact_timing'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  t('exact_timing_description'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextButton(
                  onPressed: () async {
                    await service.requestExactTiming();
                    await cubit.refresh();
                  },
                  child: Text(t('enable_exact_timing')),
                ),
              ],
              if (capacityExceeded) ...[
                const SizedBox(height: 8),
                Text(
                  t('error_schedule_capacity'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (state.error != null && !capacityExceeded) ...[
                const SizedBox(height: 8),
                Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                TextButton(onPressed: cubit.refresh, child: Text(t('retry'))),
              ],
            ],
          ),
        ),
        if (coverageDates.isNotEmpty) ...[
          ReminderSectionLabel(t('schedule_coverage')),
          ReminderSurface(
            child: Text(
              t(
                'coverage_description',
                args: {
                  'date': (DateFormat(
                    'd MMMM yyyy',
                    appLocale,
                  ).format(coverageDates.first)).toString(),
                },
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
        ReminderSectionLabel(t('default_sound')),
        ReminderSurface(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ReminderSoundPicker(
            selected: state.defaultSound,
            onChanged: cubit.setDefaultSound,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          t('default_sound_description'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        ReminderSectionLabel(t('backup')),
        ReminderSurface(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: Text(t('export_backup')),
                subtitle: Text(t('backup_contents')),
                onTap: () => _export(context),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.restore_rounded),
                title: Text(t('import_backup')),
                subtitle: Text(t('backup_preserved')),
                onTap: () => _import(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(t('backup_privacy'), style: Theme.of(context).textTheme.bodySmall),
        ReminderSectionLabel(t('privacy')),
        ReminderSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 12),
              Text(
                t('local_data_title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${t('local_data_description')}${t('uninstall_data_warning')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(t('privacy_policy')),
                    content: SingleChildScrollView(
                      child: Text(t('privacy_policy_body')),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(t('close')),
                      ),
                    ],
                  ),
                ),
                child: Text(t('privacy_policy')),
              ),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(t('open_source_licenses')),
          onTap: () =>
              showLicensePage(context: context, applicationName: t('app_name')),
        ),
        const SizedBox(height: 26),
        Center(
          child: Text(
            t('app_version'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context) async {
    final state = context.read<ReminderCubit>().state;
    try {
      final result = await FilePicker.saveFile(
        fileName:
            'hatirlatici-yedek-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json',
        bytes: ReminderBackup(state.reminders, state.completions).encode(),
        mimeType: 'application/json',
      );
      if (result != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t('backup_saved'))));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t('error_export'))));
      }
    }
  }

  Future<void> _import(BuildContext context) async {
    final cubit = context.read<ReminderCubit>();
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) return;
      if (await file.xFile.length() > 5 * 1024 * 1024) {
        throw FormatException(t('error_backup_size'));
      }
      final backup = ReminderBackup.decode(await file.xFile.readAsBytes());
      if (!context.mounted) return;
      final existing = cubit.state.reminders.map((r) => r.id).toSet();
      final count = backup.reminders
          .where((r) => !existing.contains(r.id))
          .length;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(t('import_title')),
          content: Text(
            t('import_description', args: {'count': (count).toString()}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(t('import')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final added = await cubit.mergeBackup(
        backup.reminders,
        backup.completions,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('import_result', args: {'count': (added).toString()}),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is FormatException
                  ? e.message
                  : e is StateError
                  ? e.message
                  : t('error_import'),
            ),
          ),
        );
      }
    }
  }
}
