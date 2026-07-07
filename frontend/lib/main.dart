import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/m3e_theme.dart';
import 'router.dart';
import 'providers/providers.dart';

void main() {
  runApp(const ProviderScope(child: ClassFormApp()));
}

class ClassFormApp extends ConsumerStatefulWidget {
  const ClassFormApp({super.key});
  static const _defaultSeedColor = Color(0xFF6750A4); // 品牌紫

  @override
  ConsumerState<ClassFormApp> createState() => _ClassFormAppState();
}

class _ClassFormAppState extends ConsumerState<ClassFormApp> {
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = ref.read(authProvider.notifier).init();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: ClassFormApp._defaultSeedColor,
                ),
              ),
            ),
          );
        }
        return const _AppShell(seedColor: ClassFormApp._defaultSeedColor);
      },
    );
  }
}

class _AppShell extends ConsumerWidget {
  final Color seedColor;
  const _AppShell({required this.seedColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 使用 ColorScheme.fromSeed 作为种子色（Web 端无动态壁纸色彩时的降级方案）
    final lightScheme = ColorScheme.fromSeed(seedColor: seedColor);
    final darkScheme = ColorScheme.fromSeed(
        seedColor: seedColor, brightness: Brightness.dark);

    // 通过 Provider 获取唯一 GoRouter 实例，避免每次 build 重建路由
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: '班级信息收集系统',
      debugShowCheckedModeBanner: false,
      // 使用 m3e_design 提供的 withM3ETheme 注入 Tokens
      theme: withM3ETheme(ThemeData(colorScheme: lightScheme, useMaterial3: true)),
      darkTheme: withM3ETheme(ThemeData(
          colorScheme: darkScheme,
          useMaterial3: true,
          brightness: Brightness.dark)),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
