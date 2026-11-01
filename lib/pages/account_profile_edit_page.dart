import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medicine_app/components/account_avatar.dart';
import 'package:medicine_app/l10n/app_localization.dart';
import 'package:medicine_app/services/auth/account_profile_service.dart';

class AccountProfileEditPage extends StatefulWidget {
  const AccountProfileEditPage({super.key, required this.profile});
  final AccountProfileService profile;
  @override
  State<AccountProfileEditPage> createState() => _AccountProfileEditPageState();
}

class _AccountProfileEditPageState extends State<AccountProfileEditPage> {
  late final _name = TextEditingController(
    text: widget.profile.displayName ?? '',
  );
  final _form = GlobalKey<FormState>();
  Uint8List? _photo;
  bool _remove = false, _busy = false;
  String? _message;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 384,
        maxHeight: 384,
        imageQuality: 75,
        requestFullMetadata: false,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 128 * 1024) {
        setState(() => _message = 'profile_photo_large');
      } else {
        setState(() {
          _photo = bytes;
          _remove = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'profile_photo_error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.profile.save(
        displayName: _name.text,
        photo: _photo,
        removePhoto: _remove,
      );
      if (mounted) Navigator.pop(context);
    } on TimeoutException {
      if (mounted) setState(() => _message = 'profile_save_pending');
    } catch (_) {
      if (mounted) setState(() => _message = 'profile_save_error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => localized(
    context,
    () => PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(t('profile_edit'))),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: _photo != null
                        ? ClipOval(
                            child: Image.memory(
                              _photo!,
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                            ),
                          )
                        : _remove
                        ? const CircleAvatar(
                            radius: 48,
                            child: Icon(Icons.person_outline_rounded, size: 40),
                          )
                        : const AccountAvatar(size: 96),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _busy ? null : _pick,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(t('profile_choose_photo')),
                  ),
                  if (!_remove &&
                      (_photo != null ||
                          widget.profile.photoBytes != null ||
                          widget.profile.photoUrl != null))
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _photo = null;
                              _remove = true;
                            }),
                      child: Text(t('profile_remove_photo')),
                    ),
                  const SizedBox(height: 24),
                  Form(
                    key: _form,
                    child: TextFormField(
                      controller: _name,
                      enabled: !_busy,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      decoration: InputDecoration(
                        labelText: t('profile_full_name'),
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? t('profile_name_invalid')
                          : null,
                    ),
                  ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(t(_message!)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(t('save')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
