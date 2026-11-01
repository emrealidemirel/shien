import 'package:medicine_app/components/account_avatar.dart';
import 'package:medicine_app/theme/reminder_theme.dart';
import 'package:medicine_app/l10n/app_localization.dart';
import 'package:medicine_app/pages/reminder_profile_sheet.dart';
import 'package:medicine_app/components/reminder_details_sheet.dart';
import 'package:medicine_app/pages/reminder_history_page.dart';
import 'package:medicine_app/pages/reminder_collection_page.dart';
import 'package:home_widget/home_widget.dart';
import 'package:medicine_app/services/reminder_widget_service.dart';
import 'package:flutter/services.dart';
import 'package:medicine_app/pages/reminder_plan_page.dart';
import 'package:medicine_app/pages/reminder_lists_page.dart';
import 'package:medicine_app/models/reminder_template.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:medicine_app/blocs/reminder/reminder_cubit.dart';
import 'package:medicine_app/components/reminder_components.dart';
import 'package:medicine_app/models/reminder.dart';
import 'package:medicine_app/pages/reminder_form_page.dart';
import 'package:medicine_app/pages/reminder_settings_page.dart';
import 'package:medicine_app/services/notifications/reminder_notification_service.dart';
import 'package:medicine_app/pages/reminder_today_page.dart';

enum _HomeSection { today, plan, lists, completed, collection }

class ReminderHomePage extends StatefulWidget {
  const ReminderHomePage({super.key});
  @override
  State<ReminderHomePage> createState() => _ReminderHomePageState();
}

class _ReminderHomePageState extends State<ReminderHomePage>
    with WidgetsBindingObserver {
  _HomeSection _section = _HomeSection.today;
  bool _editing = false;
  bool _confirmingCompletion = false;
  Widget? _draft;
  ReminderCategory? _category;
  String? _tag;
  bool _priorityOnly = false;
  Timer? _timer;
  StreamSubscription<Uri?>? _widgetLinks;
  late final ReminderNotifications _notifications;

  String? _locale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).languageCode;
    if (_locale == locale) return;
    final changed = _locale != null;
    _locale = locale;
    final cubit = context.read<ReminderCubit>();
    if (changed ||
        cubit.notifications is ReminderNotificationService ||
        cubit.widgets != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) cubit.refresh();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    if (context.read<ReminderCubit>().widgets?.supported ?? false) {
      _widgetLinks = HomeWidget.widgetClicked.listen(_widgetLink);
      HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
        if (mounted) _widgetLink(uri);
      });
    }
    _notifications = context.read<ReminderCubit>().notifications;
    final service = _notifications;
    if (service is ReminderNotificationService) {
      service.onTapped = _openFromNotification;
      service.onAction = context.read<ReminderCubit>().consumePendingActions;
      if (service.launchId != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _openFromNotification(service.launchId!),
        );
      }
    }
  }

  Future<void> _widgetLink(Uri? uri) async {
    if (uri == null || !mounted) return;
    if (uri.host != 'add' &&
        (uri.queryParameters['scope'] ?? 'guest') !=
            context.read<ReminderCubit>().storage.scope) {
      return;
    }
    if (uri.host == 'add') {
      _form();
      return;
    }
    if (uri.host == 'done') {
      await reminderWidgetBackground(uri);
      if (!mounted) return;
      await context.read<ReminderCubit>().consumePendingActions();
      return;
    }
    final id = uri.queryParameters['id'];
    if (id != null) _openFromNotification(id);
  }

  void _openFromNotification(String id) {
    if (!mounted) return;
    final matching = context.read<ReminderCubit>().state.reminders.where(
      (r) => r.id == id,
    );
    if (matching.isEmpty) return;
    _details(matching.first);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final cubit = context.read<ReminderCubit>();
      cubit.consumePendingActions().then((_) => cubit.refresh());
      setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _widgetLinks?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    final service = _notifications;
    if (service is ReminderNotificationService) {
      service.onTapped = null;
      service.onAction = null;
    }
    super.dispose();
  }

  void _form({
    Reminder? reminder,
    ReminderTemplate? template,
    Reminder? copyFrom,
  }) {
    setState(() {
      if (_draft == null ||
          reminder != null ||
          template != null ||
          copyFrom != null) {
        _draft = ReminderFormPage(
          key: UniqueKey(),
          reminder: reminder,
          copyFrom: copyFrom,
          template: template,
          onClose: _hideEditor,
          onSaved: _saved,
        );
      }
      _editing = true;
    });
  }

  void _hideEditor() {
    FocusScope.of(context).unfocus();
    setState(() => _editing = false);
  }

  void _saved() {
    FocusScope.of(context).unfocus();
    setState(() {
      _editing = false;
      _draft = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t('reminder_saved'))));
    final cubit = context.read<ReminderCubit>();
    if (cubit.notifications.supported && !cubit.state.notificationsEnabled) {
      _permissionSheet();
    }
  }

  Future<void> _settings() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (routeContext) => localized(
        routeContext,
        () => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: t('back'),
              onPressed: () => Navigator.pop(routeContext),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: Text(t('settings')),
          ),
          body: const ReminderSettingsPage(),
        ),
      ),
    ),
  );

  Future<void> _profile() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => ReminderProfileSheet(
      onContinueAsGuest: () => Navigator.pop(sheet),
      onHistory: () {
        Navigator.pop(sheet);
        setState(() {
          _editing = false;
          _section = _HomeSection.completed;
        });
      },
      onSettings: () {
        Navigator.pop(sheet);
        _settings();
      },
    ),
  );

  Future<void> _upcoming() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: BlocBuilder<ReminderCubit, ReminderState>(
          builder: (context, state) {
            final now = DateTime.now();
            final items =
                state.reminders
                    .where(
                      (r) =>
                          r.isActive &&
                          r.effectiveAt.isBefore(
                            now.add(const Duration(hours: 24)),
                          ),
                    )
                    .toList()
                  ..sort((a, b) => a.effectiveAt.compareTo(b.effectiveAt));
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: [
                Text(
                  t('upcoming_title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(t('upcoming_description')),
                const SizedBox(height: 20),
                if (items.isEmpty)
                  ReminderEmptyState(
                    title: t('upcoming_empty'),
                    description: t('upcoming_empty_description'),
                    icon: Icons.notifications_none_rounded,
                  ),
                for (final reminder in items)
                  ReminderCard(
                    reminder: reminder,
                    showDate: true,
                    onTap: () {
                      Navigator.pop(sheet);
                      _details(reminder);
                    },
                    onComplete: () => _complete(reminder),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Future<void> _permissionSheet() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.notifications_active_outlined,
              size: 34,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              t('permission_title'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(t('permission_description')),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  unawaited(
                    context.read<ReminderCubit>().enableNotifications(),
                  );
                },
                child: Text(t('enable_notifications')),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(sheet),
                child: Text(t('not_now')),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _complete(Reminder reminder) async {
    if (_confirmingCompletion) return;
    _confirmingCompletion = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(t('complete_title')),
          content: Text(
            '“${reminder.title}”\n${reminder.repeat == ReminderRepeat.once ? t('complete_once_description') : t('complete_repeat_description')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(t('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(t('complete')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final cubit = context.read<ReminderCubit>();
      final completion = await cubit.complete(reminder.id, expected: reminder);
      if (mounted && completion != null) {
        unawaited(HapticFeedback.lightImpact());
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('reminder_completed')),
            action: SnackBarAction(
              label: t('undo'),
              onPressed: () async {
                try {
                  await cubit.undoCompletion(completion);
                } catch (_) {
                  _error(t('error_undo'));
                }
              },
            ),
          ),
        );
      }
    } catch (error) {
      _error(error is StateError ? error.message : t('error_complete'));
    } finally {
      _confirmingCompletion = false;
    }
  }

  void _error(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _details(Reminder reminder) => showReminderDetails(
    context: context,
    reminder: reminder,
    onEdit: (reminder) => _form(reminder: reminder),
    onCopy: (reminder) => _form(copyFrom: reminder),
    onComplete: _complete,
    onError: _error,
  );

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final state = context.watch<ReminderCubit>().state;
    final scheme = Theme.of(context).colorScheme;
    final showAddAction = !_editing && _section != _HomeSection.completed;
    return BlocListener<ReminderCubit, ReminderState>(
      listenWhen: (previous, next) =>
          next.error != null && next.error != previous.error,
      listener: (context, state) => _error(state.error!),
      child: Scaffold(
        appBar: _editing
            ? null
            : AppBar(
                toolbarHeight: 64,
                automaticallyImplyLeading: false,
                centerTitle: false,
                titleSpacing: 24,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/app_icon/brand_mark.png',
                      width: 30,
                      height: 30,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      t('app_brand'),
                      style: TextStyle(
                        fontFamily: 'PatrickHand',
                        fontSize: 24,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    tooltip: t('profile'),
                    onPressed: _profile,
                    icon: const AccountAvatar(size: 30),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: IconButton(
                      tooltip: t('upcoming_tooltip'),
                      onPressed: _upcoming,
                      icon: Badge(
                        isLabelVisible: state.reminders.any(
                          (r) =>
                              r.isActive &&
                              r.effectiveAt.isBefore(
                                DateTime.now().add(const Duration(hours: 24)),
                              ),
                        ),
                        smallSize: 7,
                        backgroundColor: scheme.primary,
                        child: const Icon(
                          Icons.notifications_outlined,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        body: PopScope(
          canPop:
              !_editing &&
              (_section == _HomeSection.today ||
                  _section == _HomeSection.plan ||
                  _section == _HomeSection.lists),
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              if (_editing) {
                _hideEditor();
              } else if (_section == _HomeSection.completed ||
                  _section == _HomeSection.collection) {
                setState(() => _section = _HomeSection.lists);
              }
            }
          },
          child: IndexedStack(
            index: _editing ? 1 : 0,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: switch (_section) {
                    _HomeSection.today => ReminderTodayPage(
                      onDetails: _details,
                      onComplete: _complete,
                      onSettings: _settings,
                      onHistory: () =>
                          setState(() => _section = _HomeSection.completed),
                    ),
                    _HomeSection.plan => ReminderPlanPage(
                      onDetails: _details,
                      onComplete: _complete,
                    ),
                    _HomeSection.lists => ReminderListsPage(
                      onHistory: () =>
                          setState(() => _section = _HomeSection.completed),
                      onAll: () => setState(() {
                        _category = null;
                        _tag = null;
                        _priorityOnly = false;
                        _section = _HomeSection.collection;
                      }),
                      onCategory: (category) => setState(() {
                        _category = category;
                        _tag = null;
                        _priorityOnly = false;
                        _section = _HomeSection.collection;
                      }),
                      onPriority: () => setState(() {
                        _category = null;
                        _tag = null;
                        _priorityOnly = true;
                        _section = _HomeSection.collection;
                      }),
                      onTag: (tag) => setState(() {
                        _category = null;
                        _tag = tag;
                        _priorityOnly = false;
                        _section = _HomeSection.collection;
                      }),
                      onTemplate: (template) => _form(template: template),
                    ),
                    _HomeSection.completed => ReminderHistoryPage(
                      onError: _error,
                    ),
                    _HomeSection.collection => ReminderCollectionPage(
                      category: _category,
                      tag: _tag,
                      priorityOnly: _priorityOnly,
                      onBack: () =>
                          setState(() => _section = _HomeSection.lists),
                      onDetails: _details,
                      onComplete: _complete,
                    ),
                  },
                ),
              ),
              if (_draft != null) _draft! else const SizedBox.shrink(),
            ],
          ),
        ),
        floatingActionButton: showAddAction
            ? FloatingActionButton(
                tooltip: t('add_reminder'),
                onPressed: () => _form(),
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                elevation: 0,
                highlightElevation: 0,
                hoverElevation: 0,
                focusElevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ReminderTheme.controlRadius,
                  ),
                ),
                child: const Icon(Icons.add_rounded, size: 30),
              )
            : null,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(
              top: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: .6),
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: switch (_section) {
              _HomeSection.today => 0,
              _HomeSection.plan => 1,
              _HomeSection.lists || _HomeSection.collection => 2,
              _HomeSection.completed => 3,
            },
            onDestinationSelected: (value) {
              FocusScope.of(context).unfocus();
              setState(() {
                _editing = false;
                _section = _HomeSection.values[value];
              });
            },
            height: 72,
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            indicatorColor: scheme.primaryContainer,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.wb_sunny_outlined),
                selectedIcon: Icon(Icons.wb_sunny_rounded),
                label: t('today'),
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month_rounded),
                label: t('plan'),
              ),
              NavigationDestination(
                icon: Icon(Icons.layers_outlined),
                selectedIcon: Icon(Icons.layers_rounded),
                label: t('lists'),
              ),
              NavigationDestination(
                icon: Icon(Icons.done_all_outlined),
                selectedIcon: Icon(Icons.done_all_rounded),
                label: t('done_tab'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
