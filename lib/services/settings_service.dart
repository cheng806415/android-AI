import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_response_model.dart';

/// 设置管理服务 - 管理多商家 API Key、偏好、主题等
class SettingsService {
  static const String _keyPrefix = 'settings_';
  static const String _keyProviders = 'providers_json';
  static const String _keyGroupMode = 'group_mode';
  static const String _keySelectedProvider = 'selected_provider';
  static const String _keyDefaultModel = 'default_model';
  static const String _keyDefaultSize = 'default_size';
  static const String _keyDefaultQuality = 'default_quality';
  static const String _keyAutoRetryCount = 'auto_retry_count';
  static const String _keyThemeMode = 'theme_mode';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // 首次启动时初始化默认商家
    if (!_prefs.containsKey('$_keyPrefix$_keyProviders')) {
      await _saveProviders(ProviderDefaults.createDefaults());
    }
  }

  // ========== 商家管理 ==========

  List<ApiProvider> getProviders() {
    final jsonStr = _prefs.getString('$_keyPrefix$_keyProviders');
    if (jsonStr == null || jsonStr.isEmpty) {
      return ProviderDefaults.createDefaults();
    }
    try {
      final list = jsonDecode(jsonStr) as List;
      return list
          .map((m) => ApiProvider.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return ProviderDefaults.createDefaults();
    }
  }

  Future<void> _saveProviders(List<ApiProvider> providers) async {
    final jsonStr = jsonEncode(providers.map((p) => p.toMap()).toList());
    await _prefs.setString('$_keyPrefix$_keyProviders', jsonStr);
  }

  /// 更新单个商家的 API Key
  Future<void> setProviderApiKey(String providerId, String key) async {
    final providers = getProviders();
    final index = providers.indexWhere((p) => p.id == providerId);
    if (index >= 0) {
      providers[index] = providers[index].copyWith(apiKey: key.trim());
      await _saveProviders(providers);
    }
  }

  /// 更新单个商家的 Base URL
  Future<void> setProviderBaseUrl(String providerId, String url) async {
    final providers = getProviders();
    final index = providers.indexWhere((p) => p.id == providerId);
    if (index >= 0) {
      providers[index] = providers[index].copyWith(baseUrl: url.trim());
      await _saveProviders(providers);
    }
  }

  /// 添加新商家
  Future<void> addProvider(ApiProvider provider) async {
    final providers = getProviders();
    providers.add(provider);
    await _saveProviders(providers);
  }

  /// 删除商家
  Future<void> removeProvider(String providerId) async {
    final providers = getProviders();
    providers.removeWhere((p) => p.id == providerId);
    await _saveProviders(providers);
  }

  /// 获取指定商家
  ApiProvider? getProvider(String providerId) {
    final providers = getProviders();
    try {
      return providers.firstWhere((p) => p.id == providerId);
    } catch (_) {
      return null;
    }
  }

  /// 检查是否至少配置了一个有效的商家
  bool hasValidProvider() {
    final providers = getProviders();
    return providers.any((p) => p.isValid);
  }

  /// 获取按优先级排序的有效商家列表
  List<ApiProvider> getValidProvidersSorted() {
    final providers = getProviders();
    final valid = providers.where((p) => p.isValid).toList();
    valid.sort((a, b) => a.priority.compareTo(b.priority));
    return valid;
  }

  // ========== 模式选择 ==========

  String get groupMode =>
      _prefs.getString('$_keyPrefix$_keyGroupMode') ?? 'auto';

  bool get isAutoMode => groupMode == 'auto';

  Future<void> setGroupMode(String mode) async {
    await _prefs.setString('$_keyPrefix$_keyGroupMode', mode);
  }

  // ========== 手动选择的商家 ==========

  String get selectedProvider =>
      _prefs.getString('$_keyPrefix$_keySelectedProvider') ??
      ProviderDefaults.metaPremiumId;

  Future<void> setSelectedProvider(String providerId) async {
    await _prefs.setString('$_keyPrefix$_keySelectedProvider', providerId);
  }

  // ========== 默认生成参数 ==========

  String get defaultModel =>
      _prefs.getString('$_keyPrefix$_keyDefaultModel') ?? 'gpt-image-2';

  Future<void> setDefaultModel(String model) async {
    await _prefs.setString('$_keyPrefix$_keyDefaultModel', model);
  }

  String get defaultSize =>
      _prefs.getString('$_keyPrefix$_keyDefaultSize') ?? '1024x1024';

  Future<void> setDefaultSize(String size) async {
    await _prefs.setString('$_keyPrefix$_keyDefaultSize', size);
  }

  String get defaultQuality =>
      _prefs.getString('$_keyPrefix$_keyDefaultQuality') ?? 'high';

  Future<void> setDefaultQuality(String quality) async {
    await _prefs.setString('$_keyPrefix$_keyDefaultQuality', quality);
  }

  // ========== 自动重试次数 ==========

  int get autoRetryCount =>
      _prefs.getInt('$_keyPrefix$_keyAutoRetryCount') ?? 3;

  Future<void> setAutoRetryCount(int count) async {
    await _prefs.setInt('$_keyPrefix$_keyAutoRetryCount', count);
  }

  // ========== 主题 ==========

  String get themeMode =>
      _prefs.getString('$_keyPrefix$_keyThemeMode') ?? 'system';

  Future<void> setThemeMode(String mode) async {
    await _prefs.setString('$_keyPrefix$_keyThemeMode', mode);
  }
}
