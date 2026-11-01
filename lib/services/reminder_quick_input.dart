/// Deliberately limited Turkish and English date parsing. The user sees and accepts the
/// result before the original text is changed. No network or AI is involved.
class ReminderQuickInput {
  const ReminderQuickInput(this.title, this.at);
  final String title;
  final DateTime at;

  static ReminderQuickInput? parse(String input, DateTime now) {
    final lower = input.replaceAll('İ', 'i').toLowerCase().replaceAll('ı', 'i');
    final relative =
        RegExp(r'\b(\d{1,3})\s*(dakika|dk|saat)\s+sonra\b').firstMatch(lower) ??
        RegExp(
          r'\bin\s+(\d{1,3})\s*(min(?:ute)?s?|hours?|hrs?)\b',
        ).firstMatch(lower);
    if (relative != null) {
      final value = int.parse(relative.group(1)!);
      if (value < 1) return null;
      final minutes =
          (relative.group(2) == 'saat' || relative.group(2)!.startsWith('h'))
          ? value * 60
          : value;
      final title = _remove(input, [relative]);
      return title.isEmpty
          ? null
          : ReminderQuickInput(title, now.add(Duration(minutes: minutes)));
    }
    final time = RegExp(
      r'(?<!\d)(?:\bat\s+)?([01]?\d|2[0-3])[.:]([0-5]\d)(?:[’\x27]?(?:de|da|te|ta))?(?!\d)',
    ).firstMatch(lower);
    final day = RegExp(
      r'\b(yarin|bugün|bu akşam|tomorrow|today|tonight)\b',
    ).firstMatch(lower);
    if (time == null) return null;
    var date = DateTime(
      now.year,
      now.month,
      now.day +
          ((day?.group(1) == 'yarin' || day?.group(1) == 'tomorrow') ? 1 : 0),
      int.parse(time.group(1)!),
      int.parse(time.group(2)!),
    );
    if (!date.isAfter(now)) {
      if (day != null &&
          day.group(1) != 'yarin' &&
          day.group(1) != 'tomorrow') {
        return null;
      }
      date = DateTime(
        date.year,
        date.month,
        date.day + 1,
        date.hour,
        date.minute,
      );
    }
    final title = _remove(input, [time, if (day != null) day]);
    return title.isEmpty ? null : ReminderQuickInput(title, date);
  }

  static String _remove(String input, List<RegExpMatch> matches) {
    matches.sort((a, b) => b.start.compareTo(a.start));
    var text = input;
    for (final match in matches) {
      text = text.replaceRange(match.start, match.end, '');
    }
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
