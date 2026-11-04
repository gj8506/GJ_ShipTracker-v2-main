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

  /// Brightness the visible tree was last built with, so a change can trigger
  /// the one-time repaint pass described in [_rebuildAllElements].
  Brightness? _paintedBrightness;

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
    final next = WidgetsBinding.instance.platformDispatcher.platformBrightness;
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
    // sync with the theme below.
    final theme = AppTheme.themeFor(brightness);

    // `AppColors` is a static palette, so widgets that read it directly do not
    // depend on `Theme` and are not marked dirty when only the theme changes.
    // Without help, cards would switch surface colours while their text kept
    // the old palette until each screen was rebuilt by navigation. Repainting
    // every element once after a brightness change applies the new palette to
    // the whole app immediately, without remounting it or restarting.
    final brightnessChanged =
        _paintedBrightness != null && _paintedBrightness != brightness;
    _paintedBrightness = brightness;
    if (brightnessChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rebuildAllElements();
      });
    }

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

  /// Marks every live element dirty so all visible widgets re-read [AppColors]
  /// in the next frame. Widget state, scroll positions and the router location
  /// are preserved; only build methods run again.
  void _rebuildAllElements() {
    void visit(Element element) {
      element.markNeedsBuild();
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
  }
}
