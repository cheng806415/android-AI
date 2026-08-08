import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'services/settings_service.dart';
import 'services/storage_service.dart';
import 'services/api_service.dart';
import 'providers/settings_provider.dart';
import 'providers/generation_provider.dart';
import 'providers/history_provider.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置状态栏样式
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // 初始化服务
  final settingsService = SettingsService();
  await settingsService.init();

  final storageService = StorageService();
  final apiService = ApiService(settingsService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(settingsService)..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => GenerationProvider(apiService, storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => HistoryProvider(storageService),
        ),
      ],
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp(
          title: 'AI 图片生成器',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: settings.flutterThemeMode,
          home: const HomeScreen(),
          routes: {
            '/settings': (context) => const SettingsScreen(),
            '/history': (context) => const HistoryScreen(),
          },
        );
      },
    );
  }
}
