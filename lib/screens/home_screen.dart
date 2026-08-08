import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/generation_config.dart';
import '../providers/generation_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/prompt_input_field.dart';
import '../widgets/loading_overlay.dart';
import 'image_detail_screen.dart';

/// 主页 - 图片生成
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _prompt = '';
  String _selectedModel = 'gpt-image-2';
  String _selectedSize = '1024x1024';
  String _selectedQuality = 'high';
  Uint8List? _referenceImage;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      _selectedModel = settings.defaultModel;
      _selectedSize = settings.defaultSize;
      _selectedQuality = settings.defaultQuality;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer2<GenerationProvider, SettingsProvider>(
      builder: (context, genProvider, settingsProvider, _) {
        return LoadingOverlay(
          isLoading: genProvider.isGenerating,
          message: genProvider.isGenerating ? '正在生成图片...' : '',
          subMessage: genProvider.progressMessage,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('AI 图片生成器'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/history'),
                  tooltip: '历史记录',
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/settings'),
                  tooltip: '设置',
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 当前商家指示
                  _buildProviderIndicator(theme, settingsProvider),
                  const SizedBox(height: 12),

                  // 提示词输入
                  PromptInputField(
                    onChanged: (value) => _prompt = value,
                    onSubmit: _canGenerate ? _generate : null,
                  ),
                  const SizedBox(height: 20),

                  // 参考图片
                  if (_referenceImage != null)
                    _buildReferenceImageSection(theme),

                  // 参数配置
                  _buildParameterSection(theme),
                  const SizedBox(height: 20),

                  // 操作按钮
                  _buildActionButtons(theme, genProvider),

                  // 生成结果
                  if (genProvider.status == GenerationStatus.success &&
                      genProvider.lastGeneratedImage != null) ...[
                    const SizedBox(height: 24),
                    _buildResultSection(theme, genProvider),
                  ],

                  // 错误信息
                  if (genProvider.status == GenerationStatus.error) ...[
                    const SizedBox(height: 16),
                    _buildErrorSection(theme, genProvider),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool get _canGenerate => _prompt.trim().isNotEmpty;

  // ========== 商家指示器 ==========
  Widget _buildProviderIndicator(
      ThemeData theme, SettingsProvider settings) {
    final isValid = settings.hasValidProvider();

    if (!isValid) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.error.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: theme.colorScheme.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '请先在设置中配置至少一个 API Key',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              child: const Text('去设置'),
            ),
          ],
        ),
      );
    }

    if (settings.isAutoMode) {
      final validProviders = settings.getValidProvidersSorted();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_mode, size: 18,
                color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('自动模式',
                style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${validProviders.length} 个商家可用: ${validProviders.map((p) => p.name).join(' > ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // 手动模式
    final selected = settings.providers
        .where((p) => p.id == settings.selectedProvider)
        .toList();
    if (selected.isEmpty) return const SizedBox();
    final provider = selected.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: provider.isValid
            ? Colors.green.withOpacity(0.06)
            : theme.colorScheme.error.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            provider.isValid ? Icons.cloud_done : Icons.cloud_off,
            size: 18,
            color: provider.isValid
                ? Colors.green
                : theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Text(provider.name,
              style: theme.textTheme.labelMedium?.copyWith(
                  color: provider.isValid
                      ? Colors.green
                      : theme.colorScheme.error)),
          const SizedBox(width: 6),
          Text(provider.baseUrl,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              )),
        ],
      ),
    );
  }

  // ========== 参考图片区域 ==========
  Widget _buildReferenceImageSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(_referenceImage!,
                width: 60, height: 60, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('参考图片', style: theme.textTheme.labelMedium),
                Text('将基于此图片进行编辑',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withOpacity(0.5),
                    )),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: theme.colorScheme.error),
            onPressed: () =>
                setState(() => _referenceImage = null),
          ),
        ],
      ),
    );
  }

  // ========== 参数配置区域 ==========
  Widget _buildParameterSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('生成参数', style: theme.textTheme.titleSmall),
            const SizedBox(height: 16),
            _buildDropdown(
              theme,
              label: '模型',
              icon: Icons.model_training,
              value: _selectedModel,
              items: GenerationConfig.availableModels,
              displayNames: GenerationConfig.availableModels
                  .map(GenerationConfig.modelDisplayName)
                  .toList(),
              onChanged: (val) =>
                  setState(() => _selectedModel = val),
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              theme,
              label: '尺寸',
              icon: Icons.aspect_ratio,
              value: _selectedSize,
              items: GenerationConfig.availableSizes,
              onChanged: (val) =>
                  setState(() => _selectedSize = val),
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              theme,
              label: '质量',
              icon: Icons.high_quality,
              value: _selectedQuality,
              items: GenerationConfig.availableQualities,
              onChanged: (val) =>
                  setState(() => _selectedQuality = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
    ThemeData theme, {
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    List<String>? displayNames,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        DropdownButton<String>(
          value: value,
          isDense: true,
          underline: const SizedBox(),
          items: items.asMap().entries.map((entry) {
            final displayName = displayNames != null
                ? displayNames[entry.key]
                : entry.value;
            return DropdownMenuItem(
              value: entry.value,
              child: Text(displayName,
                  style: theme.textTheme.bodyMedium),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ],
    );
  }

  // ========== 操作按钮 ==========
  Widget _buildActionButtons(
      ThemeData theme, GenerationProvider provider) {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed:
              provider.isGenerating ? null : _pickReferenceImage,
          icon: const Icon(Icons.add_photo_alternate_outlined,
              size: 20),
          label: const Text('参考图'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed:
                _canGenerate && !provider.isGenerating
                    ? _generate
                    : null,
            icon: const Icon(Icons.auto_awesome, size: 20),
            label: Text(
                provider.isGenerating ? '生成中...' : '生成图片'),
          ),
        ),
      ],
    );
  }

  // ========== 结果区域 ==========
  Widget _buildResultSection(
      ThemeData theme, GenerationProvider provider) {
    final image = provider.lastGeneratedImage!;
    final file = File(image.localPath);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (file.existsSync())
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ImageDetailScreen(image: image),
                ),
              ),
              child: Image.file(file, fit: BoxFit.contain),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('生成成功',
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.green)),
                const SizedBox(height: 4),
                Text(
                  '耗时 ${(provider.generationTimeMs / 1000).toStringAsFixed(1)} 秒',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _shareImage(file),
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('分享'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ImageDetailScreen(
                                image: image),
                          ),
                        ),
                        icon: const Icon(Icons.fullscreen,
                            size: 18),
                        label: const Text('查看'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== 错误区域 ==========
  Widget _buildErrorSection(
      ThemeData theme, GenerationProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline,
                  color: theme.colorScheme.error, size: 20),
              const SizedBox(width: 8),
              Text('生成失败',
                  style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.error)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            provider.errorMessage ?? '未知错误',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              provider.reset();
              _generate();
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  // ========== 操作方法 ==========
  void _generate() {
    final config = GenerationConfig(
      prompt: _prompt.trim(),
      model: _selectedModel,
      size: _selectedSize,
      quality: _selectedQuality,
    );

    final provider = context.read<GenerationProvider>();

    if (_referenceImage != null) {
      provider.editImage(config, _referenceImage!);
    } else {
      provider.generateImage(config);
    }
  }

  Future<void> _pickReferenceImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() => _referenceImage = bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _shareImage(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'AI 生成的图片',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: ${e.toString()}')),
        );
      }
    }
  }
}
