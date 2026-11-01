import 'package:medicine_app/l10n/app_localization.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:medicine_app/models/reminder.dart';

class ReminderSoundPicker extends StatefulWidget {
  const ReminderSoundPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final ReminderSound selected;
  final ValueChanged<ReminderSound> onChanged;
  @override
  State<ReminderSoundPicker> createState() => _ReminderSoundPickerState();
}

class _ReminderSoundPickerState extends State<ReminderSoundPicker> {
  AudioPlayer? _player;
  StreamSubscription<void>? _completion;
  ReminderSound? _playing;
  bool _starting = false;

  Future<void> _preview(ReminderSound sound) async {
    if (_starting) return;
    _starting = true;
    try {
      if (_player == null) {
        _player = AudioPlayer();
        _completion = _player!.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _playing = null);
        });
      }
      final player = _player!;
      final stopOnly = _playing == sound || sound.resource == null;
      await player.stop();
      if (!mounted) return;
      setState(() => _playing = null);
      if (stopOnly) return;
      await player.play(AssetSource('sounds/${sound.resource}.wav'));
      if (mounted) setState(() => _playing = sound);
    } catch (_) {
      if (!mounted) return;
      setState(() => _playing = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('error_preview'))));
    } finally {
      _starting = false;
    }
  }

  @override
  void dispose() {
    _completion?.cancel();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => localized(
    context,
    () => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text(
            t('sound_preview_hint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        for (final sound in ReminderSound.values)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 4),
            leading: Icon(
              widget.selected == sound
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: widget.selected == sound
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: Text(
              sound.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              sound.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            selected: widget.selected == sound,
            onTap: () {
              if (_starting) return;
              widget.onChanged(sound);
              if (sound.resource != null || _player != null) _preview(sound);
            },
            trailing: sound.resource == null
                ? null
                : TextButton(
                    onPressed: () => _preview(sound),
                    child: Text(_playing == sound ? t('stop') : t('listen')),
                  ),
          ),
      ],
    ),
  );
}
