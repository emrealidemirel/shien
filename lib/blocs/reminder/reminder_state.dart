part of 'reminder_cubit.dart';

class ReminderState {
  const ReminderState({
    this.scope = 'guest',
    this.reminders = const [],
    this.completions = const [],
    this.themeMode = ThemeMode.system,
    this.defaultSound = ReminderSound.soft,
    this.notificationsEnabled = false,
    this.error,
  });
  final String scope;
  final List<Reminder> reminders;
  final List<ReminderCompletion> completions;
  final ThemeMode themeMode;
  final ReminderSound defaultSound;
  final bool notificationsEnabled;
  final String? error;

  ReminderState copyWith({
    String? scope,
    List<Reminder>? reminders,
    List<ReminderCompletion>? completions,
    ThemeMode? themeMode,
    ReminderSound? defaultSound,
    bool? notificationsEnabled,
    String? error,
    bool clearError = false,
  }) => ReminderState(
    scope: scope ?? this.scope,
    reminders: reminders ?? this.reminders,
    completions: completions ?? this.completions,
    themeMode: themeMode ?? this.themeMode,
    defaultSound: defaultSound ?? this.defaultSound,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    error: clearError ? null : error ?? this.error,
  );
}
