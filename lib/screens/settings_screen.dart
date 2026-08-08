import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/api_response_model.dart';
import '../models/generation_config.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../widgets/provider_selector.dart';

/// 设置页面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Map<String, TextEditingController> _keyControllers = {};
  final Map<String, TextEditingController> _urlControllers = {};
  bool _obscureKeys = true;
  bool _isCheckingBalance = false;
  String? _balanceMessage;
  bool _balanceSuccess = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    for (final provider in settings.providers) {
      _keyControllers[provider.id] =
          TextEditingController(text: provider.apiKey);
      _urlControllers[provider.id] =
          TextEditingController(text: provider.baseUrl);
    }
  }

  @override
  void dispose() {
    for (final c in _keyControllers.values) {
      c.dispose();
    }
    for (final c in _urlControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 商家管理
              _buildSectionHeader(theme, 'API 商家管理'),
              const SizedBox(height: 8),
              ...settings.providers.map((p) =>
                  _buildProviderCard(theme, settings, p)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _saveAllKeys(settings),
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('保存所有密钥'),
                ),
              ),
              const SizedBox(height: 24),

              // 商家选择模式
              _buildSectionHeader(theme, '商家选择'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: const ProviderSelector(),
                ),
              ),
              const SizedBox(height: 12),
              _buildRetryCountSection(theme, settings),
              const SizedBox(height: 24),

              // 默认生成参数
              _buildSectionHeader(theme, '默认生成参数'),
              const SizedBox(height: 8),
              _buildDefaultParamsSection(theme, settings),
              const SizedBox(height: 24),

              // 余额查询
              _buildSectionHeader(theme, '余额查询'),
              const SizedBox(height: 8),
              _buildBalanceSection(theme, settings),
              const SizedBox(height: 24),

              // 外观
              _buildSectionHeader(theme, '外观'),
              const SizedBox(height: 8),
              _buildThemeSection(theme, settings),
              const SizedBox(height: 24),

              // 关于
              _buildSectionHeader(theme, '关于'),
              const SizedBox(height: 8),
              _buildAboutSection(theme),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  // ========== 商家卡片 ==========
  Widget _buildProviderCard(
      ThemeData theme, SettingsProvider settings, ApiProvider provider) {
    final keyController = _keyControllers[provider.id]!;
    final urlController = _urlControllers[provider.id]!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    provider.name,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (provider.isValid)
                  Icon(Icons.check_circle,
                      size: 18, color: Colors.green)
                else
                  Icon(Icons.cancel,
                      size: 18,
                      color: theme.colorScheme.error.withOpacity(0.5)),
              ],
            ),
            const SizedBox(height: 12),

            // Base URL
            Row(
              children: [
                Icon(Icons.link,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.5)),
                const SizedBox(width: 4),
                Text('地址', style: theme.textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: theme.textTheme.bodySmall,
              onSubmitted: (val) {
                settings.setProviderBaseUrl(provider.id, val);
              },
            ),
            const SizedBox(height: 12),

            // API Key
            Row(
              children: [
                Icon(Icons.key,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.5)),
                const SizedBox(width: 4),
                Text('API Key', style: theme.textTheme.labelSmall),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _obscureKeys
                        ? Icons.visibility_off
                        : Icons.visibility,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => _obscureKeys = !_obscureKeys),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: keyController,
              obscureText: _obscureKeys,
              decoration: const InputDecoration(
                hintText: 'sk-...',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: theme.textTheme.bodySmall,
              onSubmitted: (val) {
                settings.setProviderApiKey(provider.id, val);
              },
            ),
            const SizedBox(height: 8),

            // 支持的端点
            Wrap(
              spacing: 6,
              children: provider.supportedEndpoints.map((ep) {
                String label;
                switch (ep) {
                  case EndpointType.imagesGenerations:
                    label = 'Images API';
                    break;
                  case EndpointType.responses:
                    label = 'Responses';
                    break;
                  case EndpointType.chatCompletions:
                    label = 'Chat Completions';
                    break;
                }
                return Chip(
                  label: Text(label, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ========== 区块标题 ==========
  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ========== 重试次数 ==========
  Widget _buildRetryCountSection(
      ThemeData theme, SettingsProvider settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.refresh,
                size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('自动模式每商家重试次数',
                      style: theme.textTheme.bodyMedium),
                  Text(
                    '每个商家最多尝试 ${settings.autoRetryCount} 次后切换到下一个',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            DropdownButton<int>(
              value: settings.autoRetryCount,
              isDense: true,
              underline: const SizedBox(),
              items: [1, 2, 3, 4, 5].map((n) {
                return DropdownMenuItem(value: n, child: Text('$n 次'));
              }).toList(),
              onChanged: (val) {
                if (val != null) settings.setAutoRetryCount(val);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ========== 默认参数 ==========
  Widget _buildDefaultParamsSection(
      ThemeData theme, SettingsProvider settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildParamRow(
              theme,
              '默认模型',
              GenerationConfig.modelDisplayName(settings.defaultModel),
              GenerationConfig.availableModels,
              GenerationConfig.availableModels
                  .map(GenerationConfig.modelDisplayName)
                  .toList(),
              (val) {
                final model = GenerationConfig.availableModels[
                    GenerationConfig.availableModels
                        .map(GenerationConfig.modelDisplayName)
                        .toList()
                        .indexOf(val)];
                settings.setDefaultModel(model);
              },
            ),
            Divider(height: 24),
            _buildParamRow(
              theme,
              '默认尺寸',
              settings.defaultSize,
              GenerationConfig.availableSizes,
              null,
              settings.setDefaultSize,
            ),
            Divider(height: 24),
            _buildParamRow(
              theme,
              '默认质量',
              settings.defaultQuality,
              GenerationConfig.availableQualities,
              null,
              settings.setDefaultQuality,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParamRow(
    ThemeData theme,
    String label,
    String currentValue,
    List<String> values,
    List<String>? displayValues,
    ValueChanged<String> onChanged,
  ) {
    return Row(
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        DropdownButton<String>(
          value: currentValue,
          isDense: true,
          underline: const SizedBox(),
          items: values.asMap().entries.map((entry) {
            final display =
                displayValues != null ? displayValues[entry.key] : entry.value;
            return DropdownMenuItem(
                value: entry.value, child: Text(display));
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ],
    );
  }

  // ========== 余额查询 ==========
  Widget _buildBalanceSection(
      ThemeData theme, SettingsProvider settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('查询余额', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            if (_balanceMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: (_balanceSuccess
                          ? Colors.green
                          : theme.colorScheme.error)
                      .withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _balanceMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _balanceSuccess
                        ? Colors.green
                        : theme.colorScheme.error,
                  ),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: settings.providers
                  .where((p) => p.isValid)
                  .map((provider) {
                return ElevatedButton(
                  onPressed: _isCheckingBalance
                      ? null
                      : () => _checkBalance(settings, provider),
                  child: Text(provider.name),
                );
              }).toList(),
            ),
            if (_isCheckingBalance)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(
                    color: theme.colorScheme.primary),
              ),
          ],
        ),
      ),
    );
  }

  // ========== 主题 ==========
  Widget _buildThemeSection(
      ThemeData theme, SettingsProvider settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.palette,
                size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('主题模式', style: theme.textTheme.bodyMedium),
            const Spacer(),
            DropdownButton<String>(
              value: settings.themeMode,
              isDense: true,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'system', child: Text('跟随系统')),
                DropdownMenuItem(value: 'light', child: Text('浅色')),
                DropdownMenuItem(value: 'dark', child: Text('深色')),
              ],
              onChanged: (val) {
                if (val != null) settings.setThemeMode(val);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ========== 关于 ==========
  Widget _buildAboutSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.info_outline,
                  color: theme.colorScheme.primary),
              title: const Text('AI 图片生成器'),
              subtitle: const Text('v1.0.0'),
            ),
            ListTile(
              leading:
                  Icon(Icons.code, color: theme.colorScheme.primary),
              title: const Text('支持的端点'),
              subtitle: const Text(
                  'Images API, Responses, Chat Completions'),
            ),
          ],
        ),
      ),
    );
  }

  // ========== 操作方法 ==========
  void _saveAllKeys(SettingsProvider settings) {
    for (final entry in _keyControllers.entries) {
      settings.setProviderApiKey(entry.key, entry.value.text.trim());
    }
    for (final entry in _urlControllers.entries) {
      settings.setProviderBaseUrl(entry.key, entry.value.text.trim());
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('所有配置已保存')),
    );
  }

  Future<void> _checkBalance(
      SettingsProvider settings, ApiProvider provider) async {
    setState(() {
      _isCheckingBalance = true;
      _balanceMessage = null;
    });

    try {
      final apiService = ApiService(settings.service);
      final balance = await apiService.checkBalance(provider);
      setState(() {
        _balanceMessage =
            '${provider.name}: ${balance.remainingBalance.toStringAsFixed(2)} ${balance.currency}';
        _balanceSuccess = true;
        _isCheckingBalance = false;
      });
    } catch (e) {
      setState(() {
        _balanceMessage = '${provider.name}: ${e.toString()}';
        _balanceSuccess = false;
        _isCheckingBalance = false;
      });
    }
  }
}
