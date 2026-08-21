import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/aurora_background.dart';
import 'features/profile/profile_controller.dart';

class TakeOffApp extends ConsumerWidget {
  const TakeOffApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentProvider);
    final palette = ref.watch(auroraPaletteProvider);

    return MaterialApp.router(
      title: 'Take Off',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(accent),
      routerConfig: ref.watch(routerProvider),
      // The aurora lives above the router rather than inside each screen, so it
      // persists across navigation and re-colours continuously when the role
      // changes instead of restarting per route.
      builder: (context, child) =>
          AuroraBackground(colors: palette, child: child),
    );
  }
}
