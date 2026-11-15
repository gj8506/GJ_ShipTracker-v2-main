import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/app.dart';
import 'package:gjandasher_shiptracker/core/constants/app_constants.dart';
import 'package:gjandasher_shiptracker/core/router/app_router.dart';
import 'package:gjandasher_shiptracker/core/theme/app_colors.dart';
import 'package:gjandasher_shiptracker/core/theme/theme_mode_provider.dart';
import 'package:gjandasher_shiptracker/features/admin/presentation/staff_approval_providers.dart';
import 'package:gjandasher_shiptracker/features/auth/domain/user_profile_model.dart';
import 'package:gjandasher_shiptracker/features/auth/presentation/auth_providers.dart';
import 'package:gjandasher_shiptracker/features/profile/presentation/profile_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads the static palette directly, exactly like the real screens do, so a
/// stale colour only refreshes when the widget tree is rebuilt.
class _PaletteProbe extends StatelessWidget {
  const _PaletteProbe();

  @override
  Widget build(BuildContext context) {
    final background = AppColors.backgroundLight;
    final text = AppColors.textPrimary;

    return Scaffold(
      backgroundColor: background,
      body: Container(
        color: background,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppColors.isDark ? 'dark' : 'light',
              style: TextStyle(color: text, fontSize: 18),
            ),
            const TextField(
              decoration: InputDecoration(hintText: 'stack check'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteProbe extends StatelessWidget {
  const _RouteProbe(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: AppColors.textPrimary)),
            Text(
              AppColors.isDark ? 'dark' : 'light',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

double _contrastRatio(Color foreground, Color background) {
  final fg = foreground.computeLuminance();
  final bg = background.computeLuminance();
  final lighter = fg > bg ? fg : bg;
  final darker = fg > bg ? bg : fg;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppColors.applyBrightness(Brightness.light);
  });

  testWidgets('switching theme restyles the tree without a restart',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        appRouterProvider.overrideWithValue(
          GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const _PaletteProbe(),
              ),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ShipTrackerApp(
          scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('light'), findsOneWidget,
        reason: 'starts on the light palette');

    await tester.enterText(find.byType(TextField), 'typed before switching');
    await tester.pump();

    await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(find.text('dark'), findsOneWidget,
        reason: 'the already-built probe repaints as dark immediately');
    expect(find.text('typed before switching'), findsOneWidget,
        reason: 'the screen is repainted in place, not restarted');

    final darkText = tester.widget<Text>(find.text('dark')).style!.color!;
    expect(darkText, AppColors.textPrimary);
    expect(
      _contrastRatio(darkText, AppColors.backgroundLight),
      greaterThan(4.5),
      reason: 'dark-mode body text must stay readable',
    );

    await container.read(themeModeProvider.notifier).setMode(ThemeMode.light);
    await tester.pumpAndSettle();

    expect(find.text('light'), findsOneWidget,
        reason:
            'switching back restores the light palette in the same session');

    final lightText = tester.widget<Text>(find.text('light')).style!.color!;
    expect(lightText, AppColors.textPrimary);
    expect(
      _contrastRatio(lightText, AppColors.backgroundLight),
      greaterThan(4.5),
      reason: 'light-mode body text must stay readable',
    );
  });

  testWidgets('rapid switches during a route transition never throw',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const _RouteProbe('route one'),
        ),
        GoRoute(
          path: '/next',
          builder: (context, state) => const _RouteProbe('route two'),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [appRouterProvider.overrideWithValue(router)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ShipTrackerApp(
          scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Start a route transition, then change the palette while it is still
    // animating. The repaint pass must not mark a route that is mid-transition.
    router.push('/next');
    await tester.pump(const Duration(milliseconds: 40));

    await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    await tester.pump();

    await container.read(themeModeProvider.notifier).setMode(ThemeMode.light);
    await tester.pump();

    await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('route two'), findsOneWidget);
    expect(find.text('dark'), findsWidgets,
        reason: 'the visible route still receives the final palette');
  });

  testWidgets('switching themes with a dialog open keeps every route usable',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(
                        AppColors.isDark ? 'dialog dark' : 'dialog light',
                      ),
                      content: const Text('approve staff?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('cancel'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('open dialog'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [appRouterProvider.overrideWithValue(router)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ShipTrackerApp(
          scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('dialog light'), findsOneWidget);

    // Rapid switches while the dialog route is mounted must repaint the dialog
    // in place, not tear it down or throw during its transition.
    await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    await tester.pump();
    await container.read(themeModeProvider.notifier).setMode(ThemeMode.light);
    await tester.pump();
    await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('dialog dark'), findsOneWidget);
    expect(find.text('approve staff?'), findsOneWidget);

    final dialogButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'open dialog'),
    );
    expect(dialogButton.enabled, isTrue,
        reason: 'the underlying screen must remain interactive');
  });

  testWidgets('the real Profile screen survives rapid theme toggles',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        appRouterProvider.overrideWithValue(router),
        userProfileProvider.overrideWith(
          (ref) => Stream.value(
            const UserProfileModel(
              uid: 'admin-1',
              email: 'owner@example.com',
              fullName: 'Owner One',
              role: AppConstants.roleAdmin,
              status: AppConstants.accountStatusActive,
            ),
          ),
        ),
        pendingStaffProvider.overrideWith(
          (ref) => Stream.value(const <UserProfileModel>[]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ShipTrackerApp(
          scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The Appearance card sits below the fold of the 800x600 test viewport.
    await tester.scrollUntilVisible(
      find.text('Theme'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);

    // Same sequence a presenter would tap through on the Appearance control.
    for (final mode in [
      ThemeMode.dark,
      ThemeMode.light,
      ThemeMode.dark,
      ThemeMode.light,
      ThemeMode.dark,
    ]) {
      await container.read(themeModeProvider.notifier).setMode(mode);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Appearance'), findsOneWidget,
        reason: 'the screen stays mounted through every repaint');

    final themeLabel = tester.widget<Text>(find.text('Theme'));
    final themeLabelColor = themeLabel.style!.color!;
    expect(themeLabelColor, AppColors.textPrimary);
    expect(
      _contrastRatio(themeLabelColor, AppColors.surfaceWhite),
      greaterThan(4.5),
      reason: 'dark-mode labels must stay readable on cards',
    );
  });
}
