import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _secureApiKeyPrefix = 'api_key_';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  late SharedPreferences _prefs;
  List<ApiProvider> _providersCache = [];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (!_prefs.containsKey('$_keyPrefix$_keyProviders')) {
      _providersCache = ProviderDefaults.createDefaults();
      await _saveProviders(_providersCache);
    } else {
      await _loadProviders();
      await _migrateProviderSettings();
    }
  }

  /// 加载商家配置，并从安全存储恢复 API Key。
  Future<void> _loadProviders() async {
    final jsonStr = _prefs.getString('$_keyPrefix$_keyProviders');
    List<ApiProvider> providers;
    try {
      final list = jsonStr == null || jsonStr.isEmpty
          ? <dynamic>[]
          : jsonDecode(jsonStr) as List<dynamic>;
      providers = list
          .map((m) => ApiProvider.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (_) {
      providers = ProviderDefaults.createDefaults();
    }

    final restored = <ApiProvider>[];
    for (final provider in providers) {
      final secureKey = await _secureStorage.read(
        key: '$_secureApiKeyPrefix${provider.id}',
      );
      // 兼容旧版本：首次升级时从旧 JSON 读取明文并立即迁移到安全存储。
      final key = secureKey ?? provider.apiKey;
      restored.add(provider.copyWith(apiKey: key));
      if (secureKey == null && provider.apiKey.isNotEmpty) {
        await _secureStorage.write(
          key: '$_secureApiKeyPrefix${provider.id}',
          value: provider.apiKey,
        );
      }
    }
    _providersCache = restored;
    await _saveProviders(_providersCache);
  }

  /// 迁移旧版本商家配置，确保 LinksAPI 优先使用图片生成端点。
  Future<void> _migrateProviderSettings() async {
    final providers = getProviders();
    var changed = false;
    final migrated = providers.map((provider) {
      final isLinksApi = provider.id == ProviderDefaults.linksId ||
          provider.baseUrl.contains('linksapi.cn');
      if (!isLinksApi ||
          provider.supportedEndpoints
              .contains(EndpointType.imagesGenerations)) {
        return provider;
      }
      changed = true;
      return provider.copyWith(
        supportedEndpoints: [
          EndpointType.imagesGenerations,
          ...provider.supportedEndpoints,
        ],
      );
    }).toList();

    if (changed) await _saveProviders(migrated);
  }

  // ========== 商家管理 ==========

  List<ApiProvider> getProviders() => List.unmodifiable(_providersCache);

  Future<void> _saveProviders(List<ApiProvider> providers) async {
    _providersCache = List<ApiProvider>.from(providers);
    // API Key 永不再写入普通偏好设置，只保存商家基础配置。
    final safeMaps = providers.map((provider) {
      final map = provider.toMap();
      map['apiKey'] = '';
      return map;
    }).toList();
    await _prefs.setString('$_keyPrefix$_keyProviders', jsonEncode(safeMaps));
  }

  /// 更新单个商家的 API Key，并写入 Android Keystore 支持的安全存储。
  Future<void> setProviderApiKey(String providerId, String key) async {
    final normalized = key.trim();
    final providers = List<ApiProvider>.from(_providersCache);
    final index = providers.indexWhere((p) => p.id == providerId);
    if (index >= 0) {
      if (normalized.isEmpty) {
        await _secureStorage.delete(key: '$_secureApiKeyPrefix$providerId');
      } else {
        await _secureStorage.write(
          key: '$_secureApiKeyPrefix$providerId',
          value: normalized,
        );
      }
      providers[index] = providers[index].copyWith(apiKey: normalized);
      await _saveProviders(providers);
    }
  }

  Future<void> setProviderBaseUrl(String providerId, String url) async {
    final providers = List<ApiProvider>.from(_providersCache);
    final index = providers.indexWhere((p) => p.id == providerId);
    if (index >= 0) {
      providers[index] = providers[index].copyWith(baseUrl: url.trim());
      await _saveProviders(providers);
    }
  }

  Future<void> addProvider(ApiProvider provider) async {
    final providers = List<ApiProvider>.from(_providersCache)..add(provider);
    await _saveProviders(providers);
    if (provider.apiKey.isNotEmpty) {
      await _secureStorage.write(
        key: '$_secureApiKeyPrefix${provider.id}',
        value: provider.apiKey,
      );
    }
  }

  Future<void> removeProvider(String providerId) async {
    final providers = List<ApiProvider>.from(_providersCache)
      ..removeWhere((p) => p.id == providerId);
    await _secureStorage.delete(key: '$_secureApiKeyPrefix$providerId');
    await _saveProviders(providers);
  }

  ApiProvider? getProvider(String providerId) {
    for (final provider in _providersCache) {
      if (provider.id == providerId) return provider;
    }
    return null;
  }

  bool hasValidProvider() => _providersCache.any((p) => p.isValid);

  List<ApiProvider> getValidProvidersSorted() {
    final valid = _providersCache.where((p) => p.isValid).toList();
    valid.sort((a, b) => a.priority.compareTo(b.priority));
    return valid;
  }

  String get groupMode =>
      _prefs.getString('$_keyPrefix$_keyGroupMode') ?? 'auto';
  bool get isAutoMode => groupMode == 'auto';
  Future<void> setGroupMode(String mode) async =>
      _prefs.setString('$_keyPrefix$_keyGroupMode', mode);

  String get selectedProvider =>
      _prefs.getString('$_keyPrefix$_keySelectedProvider') ??
      ProviderDefaults.metaPremiumId;
  Future<void> setSelectedProvider(String providerId) async =>
      _prefs.setString('$_keyPrefix$_keySelectedProvider', providerId);

  String get defaultModel =>
      _prefs.getString('$_keyPrefix$_keyDefaultModel') ?? 'gpt-image-2';
  Future<void> setDefaultModel(String model) async =>
      _prefs.setString('$_keyPrefix$_keyDefaultModel', model);

  String get defaultSize =>
      _prefs.getString('$_keyPrefix$_keyDefaultSize') ?? '1024x1024';
  Future<void> setDefaultSize(String size) async =>
      _prefs.setString('$_keyPrefix$_keyDefaultSize', size);

  String get defaultQuality =>
      _prefs.getString('$_keyPrefix$_keyDefaultQuality') ?? 'high';
  Future<void> setDefaultQuality(String quality) async =>
      _prefs.setString('$_keyPrefix$_keyDefaultQuality', quality);

  int get autoRetryCount =>
      _prefs.getInt('$_keyPrefix$_keyAutoRetryCount') ?? 3;
  Future<void> setAutoRetryCount(int count) async =>
      _prefs.setInt('$_keyPrefix$_keyAutoRetryCount', count);

  String get themeMode =>
      _prefs.getString('$_keyPrefix$_keyThemeMode') ?? 'system';
  Future<void> setThemeMode(String mode) async =>
      _prefs.setString('$_keyPrefix$_keyThemeMode', mode);

  bool get notificationsEnabled =>
      _prefs.getBool('$_keyPrefix$_keyNotificationsEnabled') ?? true;
  Future<void> setNotificationsEnabled(bool enabled) async =>
      _prefs.setBool('$_keyPrefix$_keyNotificationsEnabled', enabled);
}
