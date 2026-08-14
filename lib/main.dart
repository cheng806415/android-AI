import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'services/settings_service.dart';
import 'services/storage_service.dart';
import 'services/api_service.dart';
import 'services/update_service.dart';
import 'providers/settings_provider.dart';
import 'providers/generation_provider.dart';
import 'providers/history_provider.dart';
import 'providers/log_provider.dart';
import 'providers/task_queue_provider.dart';
import 'providers/update_provider.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/history_screen.dart';
import 'screens/logs_screen.dart';
import 'services/log_service.dart';
import 'models/update_info.dart';
import 'widgets/update_dialog.dart';

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
  final logService = LogService(storageService);
  final apiService = ApiService(settingsService);
  final updateService = UpdateService();

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        Provider<UpdateService>.value(value: updateService),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(settingsService)..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => LogProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              GenerationProvider(apiService, storageService, logService),
        ),
        ChangeNotifierProxyProvider<GenerationProvider, TaskQueueProvider>(
          create: (context) => TaskQueueProvider(
            storageService,
            context.read<GenerationProvider>(),
            logService,
          ),
          update: (_, generation, queue) =>
              queue ??
              TaskQueueProvider(
                storageService,
                generation,
                logService,
              ),
        ),
        ChangeNotifierProvider(
          create: (_) => HistoryProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => UpdateProvider(updateService),
        ),
      ],
      child: const App(),
    ),
  );
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool _updateChecked = false;

  @override
  void initState() {
    super.initState();
    // 启动后延迟检查更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
    });
  }

  Future<void> _checkForUpdate() async {
    if (_updateChecked) return;
    _updateChecked = true;

    final updateProvider = context.read<UpdateProvider>();
    await updateProvider.checkForUpdate();

    if (!mounted) return;

    if (updateProvider.hasUpdate && updateProvider.newVersion != null) {
      _showUpdateDialog(updateProvider.newVersion!);
    }
  }

  void _showUpdateDialog(VersionInfo version) {
    showDialog<bool>(
      context: context,
      barrierDismissible:
          version.updateType != UpdateType.major && !version.isForced,
      builder: (_) => UpdateDialog(versionInfo: version),
    ).then((_) {
      // 大版本强制更新：用户关闭弹窗（通过系统返回键等）后再次弹出
      if ((version.updateType == UpdateType.major || version.isForced) &&
          mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _showUpdateDialog(version);
        });
      }
    });
  }

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
            '/logs': (context) => const LogsScreen(),
          },
        );
      },
    );
  }
}
