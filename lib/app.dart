import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';

class ShipTrackerApp extends ConsumerStatefulWidget {
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  const ShipTrackerApp({
    super.key,
    required this.scaffoldMessengerKey,
  });

  @override
  ConsumerState<ShipTrackerApp> createState() => _ShipTrackerAppState();
}

class _ShipTrackerAppState extends ConsumerState<ShipTrackerApp>
    with WidgetsBindingObserver {
  /// Last known device brightness, used when the preference is
  /// [ThemeMode.system].
  late Brightness _platformBrightness;

  @override
  void initState() {
    super.initState();
    _platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    final next =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (next != _platformBrightness) {
      setState(() => _platformBrightness = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final mode = ref.watch(themeModeProvider);

    final brightness = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => _platformBrightness,
    };

    // Selecting the palette here keeps every widget-level `AppColors` lookup in
    // sync with the theme below. Rebuilding the app makes the navigator refresh
    // its routes, so already-built screens repaint with the new palette.
    final theme = AppTheme.themeFor(brightness);

    return MaterialApp.router(
      title: AppConstants.appName,
      scaffoldMessengerKey: widget.scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: theme,
      // The palette is resolved above, so the switch must be instant: animating
      // it would briefly show `Theme` colours that disagree with `AppColors`.
      themeAnimationDuration: Duration.zero,
      routerConfig: router,
    );
  }
}
