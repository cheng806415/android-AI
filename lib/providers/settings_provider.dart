import 'package:flutter/material.dart';
import '../models/api_response_model.dart';
import '../services/settings_service.dart';

/// 设置状态管理
class SettingsProvider extends ChangeNotifier {
  final SettingsService _service;

  SettingsProvider(this._service);

  /// 暴露底层设置服务
  SettingsService get service => _service;

  // ========== 商家列表 ==========
  List<ApiProvider> _providers = [];
  List<ApiProvider> get providers => _providers;

  void loadProviders() {
    _providers = _service.getProviders();
    notifyListeners();
  }

  Future<void> setProviderApiKey(String providerId, String key) async {
    await _service.setProviderApiKey(providerId, key);
    loadProviders();
  }

  Future<void> setProviderBaseUrl(String providerId, String url) async {
    await _service.setProviderBaseUrl(providerId, url);
    loadProviders();
  }

  Future<void> addProvider(ApiProvider provider) async {
    await _service.addProvider(provider);
    loadProviders();
  }

  Future<void> removeProvider(String providerId) async {
    await _service.removeProvider(providerId);
    loadProviders();
  }

  bool hasValidProvider() => _service.hasValidProvider();

  List<ApiProvider> getValidProvidersSorted() =>
      _service.getValidProvidersSorted();

  // ========== 模式选择 ==========
  String get groupMode => _service.groupMode;
  bool get isAutoMode => _service.isAutoMode;

  Future<void> setGroupMode(String mode) async {
    await _service.setGroupMode(mode);
    notifyListeners();
  }

  // ========== 手动选择的商家 ==========
  String get selectedProvider => _service.selectedProvider;

  Future<void> setSelectedProvider(String providerId) async {
    await _service.setSelectedProvider(providerId);
    notifyListeners();
  }

  // ========== 默认生成参数 ==========
  String get defaultModel => _service.defaultModel;
  String get defaultSize => _service.defaultSize;
  String get defaultQuality => _service.defaultQuality;
  int get autoRetryCount => _service.autoRetryCount;

  Future<void> setDefaultModel(String model) async {
    await _service.setDefaultModel(model);
    notifyListeners();
  }

  Future<void> setDefaultSize(String size) async {
    await _service.setDefaultSize(size);
    notifyListeners();
  }

  Future<void> setDefaultQuality(String quality) async {
    await _service.setDefaultQuality(quality);
    notifyListeners();
  }

  Future<void> setAutoRetryCount(int count) async {
    await _service.setAutoRetryCount(count);
    notifyListeners();
  }

  // ========== 主题 ==========
  String get themeMode => _service.themeMode;

  ThemeMode get flutterThemeMode {
    switch (_service.themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(String mode) async {
    await _service.setThemeMode(mode);
    notifyListeners();
  }

  // ========== 初始化 ==========
  Future<void> init() async {
    await _service.init();
    loadProviders();
    notifyListeners();
  }
}
