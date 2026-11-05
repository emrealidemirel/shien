import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shien/blocs/reminder/reminder_cubit.dart';
import 'package:shien/components/account_avatar.dart';
import 'package:shien/services/auth/account_profile_service.dart';
import 'package:shien/services/sync/cloud_reminder_sync.dart';
import 'package:shien/pages/account_profile_edit_page.dart';
import 'package:shien/l10n/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:shien/components/reminder_components.dart';
import 'package:shien/pages/reminder_email_auth_page.dart';
import 'package:shien/services/auth/auth_service.dart';

class ReminderProfileSheet extends StatefulWidget {
  const ReminderProfileSheet({
    super.key,
    required this.onContinueAsGuest,
    required this.onHistory,
    required this.onSettings,
    this.auth,
  });

  final VoidCallback onContinueAsGuest, onHistory, onSettings;
  final AuthService? auth;

  @override
  State<ReminderProfileSheet> createState() => _ReminderProfileSheetState();
}

class _ReminderProfileSheetState extends State<ReminderProfileSheet> {
  AuthService get _auth => widget.auth ?? AuthService.instance;
  bool _busy = false;
  String? _message;

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) setState(() => _message = success);
    } catch (error) {
      if (mounted) setState(() => _message = authErrorKey(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAccountAction({required bool delete}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(delete ? 'auth_delete_account' : 'auth_sign_out')),
        content: Text(
          t(
            delete
                ? ((_auth.user?.isAnonymous ?? true)
                      ? 'auth_delete_guest_detail'
                      : 'auth_delete_detail')
                : 'auth_sign_out_detail',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t(delete ? 'auth_delete_account' : 'auth_sign_out')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(delete ? _auth.deleteAccount : _auth.signOut);
    }
  }

  Future<void> _importGuest() async {
    final cubit = context.read<ReminderCubit>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('sync_import_guest')),
        content: Text(t('sync_import_detail')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('sync_import_confirm')),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _run(() async {
        await cubit.importGuestRecords();
      }, success: 'sync_import_done');
    }
  }

  List<Widget> _accountOptions(BuildContext context) {
    final profile = AccountProfileService.current;
    final sync = CloudReminderSync.current;
    return [
      if (profile != null)
        TextButton.icon(
          onPressed: _busy
              ? null
              : () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AccountProfileEditPage(profile: profile),
                  ),
                ),
          icon: const Icon(Icons.edit_outlined),
          label: Text(t('profile_edit')),
        ),
      if (sync != null) ...[
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            sync.statusKey == 'sync_ready'
                ? Icons.cloud_done_outlined
                : Icons.cloud_sync_outlined,
          ),
          title: Text(t(sync.statusKey)),
          subtitle: sync.cubit.storage.pending.isNotEmpty
              ? Text(t('sync_changes_waiting'))
              : null,
          trailing: IconButton(
            tooltip: t('retry'),
            onPressed: _busy ? null : () => _run(sync.retry),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        if (sync.cubit.storage.guestReminders.isNotEmpty ||
            sync.cubit.storage.guestCompletions.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _busy ? null : _importGuest,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(t('sync_import_guest')),
          ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) => localized(
    context,
    () => ListenableBuilder(
      listenable: Listenable.merge([
        _auth,
        AccountProfileService.current,
        CloudReminderSync.current,
      ]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final user = _auth.user;
        final guest = user == null || user.isAnonymous;
        final needsVerification =
            !guest &&
            !user.emailVerified &&
            user.providerData.any(
              (provider) => provider.providerId == 'password',
            );
        return PopScope(
          canPop: !_busy,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const AccountAvatar(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              guest
                                  ? t('guest_account')
                                  : (AccountProfileService
                                            .current
                                            ?.displayName ??
                                        AccountProfileService.providerDisplayName(
                                          _auth,
                                        ) ??
                                        t('auth_my_account')),
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              guest
                                  ? t(
                                      user == null
                                          ? 'guest_status'
                                          : 'auth_guest_connected',
                                    )
                                  : (user.email ?? ''),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t(guest ? 'sync_guest' : 'sync_account_description'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (!guest) ..._accountOptions(context),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(t(_message!)),
                      ),
                    ),
                  if (guest) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              // Offline use stays available even if Firebase cannot initialize.
                              if (!_auth.available) {
                                widget.onContinueAsGuest();
                                return;
                              }
                              await _run(() async {
                                await _auth.continueAsGuest();
                                if (mounted) widget.onContinueAsGuest();
                              });
                            },
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(t('continue_as_guest')),
                    ),
                    ReminderSectionLabel(t('sign_in')),
                    if (!_auth.available)
                      Text(
                        t('auth_unavailable'),
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: 12),
                    ReminderSurface(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          if (_auth.appleAvailable) ...[
                            ListTile(
                              enabled: !_busy && _auth.available,
                              leading: const Icon(Icons.apple),
                              title: Text(t('sign_in_apple')),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => _run(_auth.signInApple),
                            ),
                            const Divider(height: 1, indent: 56, endIndent: 16),
                          ],
                          ListTile(
                            enabled: !_busy && _auth.available,
                            leading: const Icon(Icons.account_circle_outlined),
                            title: Text(t('sign_in_google')),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _run(_auth.signInGoogle),
                          ),
                          const Divider(height: 1, indent: 56, endIndent: 16),
                          ListTile(
                            enabled: !_busy && _auth.available,
                            leading: const Icon(Icons.mail_outline_rounded),
                            title: Text(t('sign_in_email')),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ReminderEmailAuthPage(auth: _auth),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (needsVerification) ...[
                    const SizedBox(height: 20),
                    Text(t('auth_verify_description')),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => _auth.sendVerification(
                                context.locale.languageCode,
                              ),
                              success: 'auth_verification_sent',
                            ),
                      child: Text(t('auth_send_verification')),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => _run(_auth.refreshUser),
                      child: Text(t('auth_check_verification')),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: !_busy,
                    leading: const Icon(Icons.done_all_rounded),
                    title: Text(t('history_title')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: widget.onHistory,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: !_busy,
                    leading: const Icon(Icons.tune_rounded),
                    title: Text(t('settings')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: widget.onSettings,
                  ),
                  if (!guest)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      enabled: !_busy,
                      leading: const Icon(Icons.logout_rounded),
                      title: Text(t('auth_sign_out')),
                      onTap: () => _confirmAccountAction(delete: false),
                    ),
                  if (user != null)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _confirmAccountAction(delete: true),
                      child: Text(t('auth_delete_account')),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
