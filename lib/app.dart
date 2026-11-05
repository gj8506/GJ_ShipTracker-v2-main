import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  /// the one-time repaint pass described in [_repaintPalette].
  Brightness? _paintedBrightness;

  /// Coalesces rapid theme changes (including system brightness changes) into
  /// a single repaint pass so tapping Light/Dark quickly cannot queue several
  /// full-tree rebuilds.
  bool _paletteRepaintScheduled = false;

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
      _schedulePaletteRepaint();
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

  /// Schedules at most one palette repaint, after the current frame has
  /// finished. Marking elements while Flutter is building (or while a route is
  /// being deactivated) can assert, so the work is always deferred.
  void _schedulePaletteRepaint() {
    if (_paletteRepaintScheduled) return;
    _paletteRepaintScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paletteRepaintScheduled = false;
      if (!mounted) return;

      // If another frame is already being produced, wait for a clean frame.
      final phase = SchedulerBinding.instance.schedulerPhase;
      if (phase == SchedulerPhase.persistentCallbacks ||
          phase == SchedulerPhase.midFrameMicrotasks) {
        _schedulePaletteRepaint();
        return;
      }

      _repaintPalette();
    });
  }

  /// Marks every live element dirty so all visible widgets re-read [AppColors]
  /// in the next frame. Widget state, scroll positions and the router location
  /// are preserved; only build methods run again.
  ///
  /// The walk is iterative to avoid deep recursion, skips elements that were
  /// deactivated while the theme changed, and never lets one unusual element
  /// abort the rest of the repaint.
  void _repaintPalette() {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return;

    final pending = <Element>[];
    root.visitChildren(pending.add);

    while (pending.isNotEmpty) {
      final element = pending.removeLast();
      if (!element.mounted) continue;

      try {
        element.markNeedsBuild();
      } catch (_) {
        // A route may have been removed between the frame and this callback.
        // Its remaining children are no longer part of the visible tree.
        continue;
      }

      element.visitChildren(pending.add);
    }
  }
}
