import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/api_response_model.dart';
import '../models/generation_config.dart';

import '../providers/settings_provider.dart';
import '../providers/update_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/provider_selector.dart';
import '../widgets/update_dialog.dart';
import 'update_diagnostics_screen.dart';

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
            padding: const EdgeInsets.all(8),
            children: [
              // 一级：API 配置
              _buildCategory(
                theme,
                icon: Icons.cloud,
                title: 'API 配置',
                children: [
                  _buildSubSection(
                    theme,
                    title: '商家管理',
                    children: [
                      ...settings.providers
                          .map((p) => _buildProviderCard(theme, settings, p)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _saveAllKeys(settings),
                          icon: const Icon(Icons.save, size: 18),
                          label: const Text('保存所有密钥'),
                        ),
                      ),
                    ],
                  ),
                  _buildSubSection(
                    theme,
                    title: '商家选择模式',
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: const ProviderSelector(),
                        ),
                      ),
                    ],
                  ),
                  _buildSubSection(
                    theme,
                    title: '自动重试次数',
                    children: [
                      _buildRetryCountSection(theme, settings),
                    ],
                  ),
                  _buildSubSection(
                    theme,
                    title: '默认生成参数',
                    children: [
                      _buildDefaultParamsSection(theme, settings),
                    ],
                  ),
                  _buildSubSection(
                    theme,
                    title: '余额查询',
                    children: [
                      _buildBalanceSection(theme, settings),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // 一级：外观与通知
              _buildCategory(
                theme,
                icon: Icons.palette,
                title: '外观与通知',
                children: [
                  _buildSubSection(
                    theme,
                    title: '主题模式',
                    children: [
                      _buildThemeSection(theme, settings),
                    ],
                  ),
                  _buildSubSection(
                    theme,
                    title: '生成状态通知',
                    children: [
                      _buildNotificationSection(theme, settings),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // 一级：数据管理
              _buildCategory(
                theme,
                icon: Icons.storage,
                title: '数据管理',
                children: [
                  _buildSubSection(
                    theme,
                    title: '备份管理',
                    children: [
                      _buildBackupSection(theme),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // 一级：关于与更新
              _buildCategory(
                theme,
                icon: Icons.info,
                title: '关于与更新',
                children: [
                  _buildSubSection(
                    theme,
                    title: '版本信息',
                    children: [
                      _buildAboutSection(theme),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategory(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      children: children,
    );
  }

  Widget _buildSubSection(
    ThemeData theme, {
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ...children,
        ],
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
                  Icon(Icons.check_circle, size: 18, color: Colors.green)
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
                    _obscureKeys ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscureKeys = !_obscureKeys),
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

  // ========== 重试次数 ==========
  Widget _buildRetryCountSection(ThemeData theme, SettingsProvider settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.refresh, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('自动模式每商家重试次数', style: theme.textTheme.bodyMedium),
                  Text(
                    '每个商家最多尝试 ${settings.autoRetryCount} 次后切换到下一个',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
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
                final model = GenerationConfig.availableModels[GenerationConfig
                    .availableModels
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
            return DropdownMenuItem(value: entry.value, child: Text(display));
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ],
    );
  }

  // ========== 余额查询 ==========
  Widget _buildBalanceSection(ThemeData theme, SettingsProvider settings) {
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
                  color:
                      (_balanceSuccess ? Colors.green : theme.colorScheme.error)
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
              children:
                  settings.providers.where((p) => p.isValid).map((provider) {
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
                child:
                    LinearProgressIndicator(color: theme.colorScheme.primary),
              ),
          ],
        ),
      ),
    );
  }

  // ========== 主题 ==========
  Widget _buildThemeSection(ThemeData theme, SettingsProvider settings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.palette, size: 20, color: theme.colorScheme.primary),
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

  Future<void> _exportBackup() async {
    try {
      final storage = context.read<StorageService>();
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/image_history_backup.json');
      await file.writeAsString(await storage.exportBackupJson());
      await Share.shareXFiles([XFile(file.path)], text: 'AI 图片生成器本地备份');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }

  Future<void> _importBackup() async {
    final controller = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入备份'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'JSON 文件完整路径'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (path == null || path.isEmpty) return;
    try {
      final storage = context.read<StorageService>();
      final count =
          await storage.importBackupJson(await File(path).readAsString());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已导入 $count 条历史记录')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    }
  }

  // ========== 关于 ==========
  Widget _buildNotificationSection(ThemeData theme, SettingsProvider settings) {
    return Card(
      child: SwitchListTile(
        secondary: Icon(Icons.notifications_outlined,
            color: theme.colorScheme.primary),
        title: const Text('生成状态通知'),
        subtitle: const Text('仅控制本地生成完成和失败状态提示，不包含远程推送'),
        value: settings.notificationsEnabled,
        onChanged: settings.setNotificationsEnabled,
      ),
    );
  }

  Widget _buildBackupSection(ThemeData theme) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading:
                Icon(Icons.backup_outlined, color: theme.colorScheme.primary),
            title: const Text('导出本地备份'),
            subtitle: const Text('导出历史记录及元数据 JSON，图片路径仅保留本机存在的文件'),
            onTap: _exportBackup,
          ),
          ListTile(
            leading: Icon(Icons.restore, color: theme.colorScheme.primary),
            title: const Text('导入本地备份'),
            subtitle: const Text('输入 JSON 文件路径后导入历史记录'),
            onTap: _importBackup,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading:
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
              title: const Text('AI 图片生成器'),
              subtitle: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data?.version ?? '1.0.0';
                  final build = snapshot.data?.buildNumber ?? '1';
                  return Text('v$version (build $build)');
                },
              ),
            ),
            ListTile(
              leading: Icon(Icons.code, color: theme.colorScheme.primary),
              title: const Text('支持的端点'),
              subtitle: const Text('Images API, Responses, Chat Completions'),
            ),
            const Divider(),
            Consumer<UpdateProvider>(
              builder: (context, updateProvider, _) {
                return ListTile(
                  leading: Icon(
                    Icons.system_update,
                    color: updateProvider.hasUpdate
                        ? Colors.orange
                        : theme.colorScheme.primary,
                  ),
                  title: Text(
                    updateProvider.hasUpdate ? '有新版本可用' : '检查更新',
                  ),
                  subtitle: Text(
                    updateProvider.status == UpdateCheckStatus.checking
                        ? '正在检查...'
                        : updateProvider.hasUpdate
                            ? 'v${updateProvider.newVersion?.versionName ?? ""} ${updateProvider.newVersion?.updateTypeLabel ?? ""}'
                            : updateProvider.status == UpdateCheckStatus.error
                                ? '检查失败，点击重试'
                                : '当前已是最新版本',
                  ),
                  trailing: updateProvider.status == UpdateCheckStatus.checking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (updateProvider.hasUpdate)
                              Icon(Icons.arrow_forward_ios,
                                  size: 16, color: Colors.orange),
                            IconButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UpdateDiagnosticsScreen(
                                    report: updateProvider.checkReport,
                                    errorMessage: updateProvider.errorMessage,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.analytics_outlined),
                              tooltip: '查看检查详情',
                            ),
                          ],
                        ),
                  onTap: () => _handleUpdateCheck(updateProvider),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpdateCheck(UpdateProvider updateProvider) async {
    if (updateProvider.hasUpdate && updateProvider.newVersion != null) {
      // 已有更新，显示更新弹窗
      if (mounted) {
        UpdateDialog.show(context, updateProvider.newVersion!);
      }
    } else {
      // 检查更新
      await updateProvider.checkForUpdate();
      if (mounted &&
          updateProvider.hasUpdate &&
          updateProvider.newVersion != null) {
        UpdateDialog.show(context, updateProvider.newVersion!);
      }
    }
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
