import 'package:shien/l10n/app_localization.dart';
import 'package:shien/models/reminder.dart';

class ReminderTemplate {
  const ReminderTemplate(
    this._titleKey,
    this.category,
    this.repeat,
    this.hour, {
    this.minute = 0,
    this.leadMinutes = 0,
  });
  final String _titleKey;
  String get title => t(_titleKey);
  final ReminderCategory category;
  final ReminderRepeat repeat;
  final int hour;
  final int minute;
  final int leadMinutes;
  static const samples = [
    ReminderTemplate(
      'template_episode',
      ReminderCategory.entertainment,
      ReminderRepeat.weekly,
      21,
      leadMinutes: 15,
    ),
    ReminderTemplate(
      'template_bill',
      ReminderCategory.payments,
      ReminderRepeat.monthly,
      10,
      leadMinutes: 60,
    ),
    ReminderTemplate(
      'template_water',
      ReminderCategory.health,
      ReminderRepeat.daily,
      9,
    ),
    ReminderTemplate(
      'template_birthday',
      ReminderCategory.personal,
      ReminderRepeat.yearly,
      9,
    ),
    ReminderTemplate(
      'template_walk',
      ReminderCategory.personal,
      ReminderRepeat.daily,
      18,
    ),
  ];
}
