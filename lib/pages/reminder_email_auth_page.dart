import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medicine_app/l10n/app_localization.dart';
import 'package:medicine_app/services/auth/auth_service.dart';

class ReminderEmailAuthPage extends StatefulWidget {
  const ReminderEmailAuthPage({super.key, required this.auth});
  final AuthService auth;

  @override
  State<ReminderEmailAuthPage> createState() => _ReminderEmailAuthPageState();
}

class _ReminderEmailAuthPageState extends State<ReminderEmailAuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _register = false, _busy = false, _obscure = true;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_register) {
        await widget.auth.registerEmail(_email.text, _password.text);
      } else {
        await widget.auth.signInEmail(_email.text, _password.text);
      }
      TextInput.finishAutofillContext();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _message = authErrorKey(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!isValidAuthEmail(_email.text)) {
      setState(() => _message = 'auth_enter_email');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.auth.resetPassword(_email.text, context.locale.languageCode);
      if (mounted) setState(() => _message = 'auth_reset_sent');
    } catch (error) {
      if (mounted) setState(() => _message = authErrorKey(error));
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
        appBar: AppBar(
          title: Text(t(_register ? 'auth_create_account' : 'sign_in_email')),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    t('sync_sign_in_description'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  AutofillGroup(
                    child: Form(
                      key: _form,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _email,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: t('auth_email'),
                            ),
                            validator: (value) => isValidAuthEmail(value ?? '')
                                ? null
                                : t('auth_invalid_email'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _password,
                            enabled: !_busy,
                            obscureText: _obscure,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: [
                              _register
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            textInputAction: _register
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!_busy && !_register) _submit();
                            },
                            decoration: InputDecoration(
                              labelText: t('auth_password'),
                              helperText: _register
                                  ? t('auth_password_hint')
                                  : null,
                              suffixIcon: IconButton(
                                tooltip: t(
                                  _obscure
                                      ? 'auth_show_password'
                                      : 'auth_hide_password',
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return t('auth_enter_password');
                              }
                              if (_register && value.length < 8) {
                                return t('auth_weak_password');
                              }
                              return null;
                            },
                          ),
                          if (_register) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmation,
                              enabled: !_busy,
                              obscureText: _obscure,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!_busy) _submit();
                              },
                              decoration: InputDecoration(
                                labelText: t('auth_confirm_password'),
                              ),
                              validator: (value) => value == _password.text
                                  ? null
                                  : t('auth_password_mismatch'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Semantics(liveRegion: true, child: Text(t(_message!))),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            t(_register ? 'auth_create_account' : 'sign_in'),
                          ),
                  ),
                  if (!_register)
                    TextButton(
                      onPressed: _busy ? null : _resetPassword,
                      child: Text(t('auth_forgot_password')),
                    ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            final email = _email.text;
                            _register = !_register;
                            _message = null;
                            _password.clear();
                            _confirmation.clear();
                            _form.currentState?.reset();
                            _email.text = email;
                          }),
                    child: Text(
                      t(_register ? 'auth_have_account' : 'auth_new_account'),
                    ),
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
