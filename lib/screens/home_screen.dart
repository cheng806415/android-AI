import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/generation_config.dart';
import '../models/prompt_template.dart';
import '../providers/generation_provider.dart';
import '../providers/task_queue_provider.dart';
import '../providers/settings_provider.dart';
import '../services/storage_service.dart';
import '../utils/error_classifier.dart';
import '../widgets/prompt_input_field.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/prompt_template_picker.dart';
import 'prompt_library_screen.dart';
import 'image_detail_screen.dart';
import 'task_queue_screen.dart';

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
  String _selectedRatio = '1:1';
  int _selectedCount = 1;
  Uint8List? _referenceImage;
  final List<Uint8List> _referenceImages = [];
  bool _isSavingToDcim = false;
  final _picker = ImagePicker();

  // 自定义尺寸
  final _customWidthController = TextEditingController(text: '1024');
  final _customHeightController = TextEditingController(text: '1024');
  String _customWidth = '1024';
  String _customHeight = '1024';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      _selectedModel = settings.defaultModel;
      _selectedSize = settings.defaultSize;
      _selectedQuality = settings.defaultQuality;
      _selectedRatio = GenerationConfig.ratioForSize(_selectedSize);
    });
  }

  @override
  void dispose() {
    _customWidthController.dispose();
    _customHeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer2<GenerationProvider, SettingsProvider>(
      builder: (context, genProvider, settingsProvider, _) {
        return LoadingOverlay(
          isLoading: false,
          message: '',
          subMessage: '',
          onCancel: null,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('AI 图片生成器'),
              actions: [
                Consumer<TaskQueueProvider>(
                  builder: (context, queue, _) => IconButton(
                    icon: Badge.count(
                      isLabelVisible: queue.pendingCount > 0,
                      count: queue.pendingCount,
                      child: const Icon(Icons.queue_outlined),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TaskQueueScreen(),
                      ),
                    ),
                    tooltip: '任务队列',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: () => _openHistory(),
                  tooltip: '历史记录',
                ),
                IconButton(
                  icon: const Icon(Icons.bug_report_outlined),
                  onPressed: () => Navigator.pushNamed(context, '/logs'),
                  tooltip: '运行日志',
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                  tooltip: '设置',
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProviderIndicator(theme, settingsProvider),
                  const SizedBox(height: 12),
                  PromptInputField(
                    initialValue: _prompt,
                    onChanged: (value) => setState(() => _prompt = value),
                    onTemplate: _pickPromptTemplate,
                    onPromptLibrary: _pickServerPrompt,
                    onSubmit: _canGenerate ? _generate : null,
                  ),
                  const SizedBox(height: 20),
                  if (_referenceImage != null || _referenceImages.isNotEmpty)
                    _buildReferenceImageSection(theme),
                  _buildParameterSection(theme),
                  const SizedBox(height: 20),
                  _buildActionButtons(theme, genProvider),
                  if (genProvider.status == GenerationStatus.success &&
                      genProvider.lastGeneratedImages.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildResultSection(theme, genProvider),
                  ],
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

  Future<void> _pickPromptTemplate() async {
    await PromptTemplatePicker.show(context, (PromptTemplate template) {
      setState(() => _prompt = template.prompt);
    });
  }

  Future<void> _pickServerPrompt() async {
    final selectedPrompt = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PromptLibraryScreen()),
    );
    if (selectedPrompt != null && mounted) {
      setState(() => _prompt = selectedPrompt);
    }
  }

  // ========== 商家指示器 ==========
  Widget _buildProviderIndicator(ThemeData theme, SettingsProvider settings) {
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
            Icon(Icons.auto_mode, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('自动模式',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.primary)),
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
            color: provider.isValid ? Colors.green : theme.colorScheme.error,
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
    final allImages = <Uint8List>[];
    if (_referenceImage != null) allImages.add(_referenceImage!);
    allImages.addAll(_referenceImages);
    final count = allImages.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('参考图片 ($count/3)', style: theme.textTheme.labelMedium),
              const Spacer(),
              Text(
                count > 1 ? '请在提示词中引用图片编号：图片1、图片2...' : '将基于此图片进行编辑',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allImages.asMap().entries.map((entry) {
              final index = entry.key;
              final image = entry.value;
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(image,
                        width: 72, height: 72, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () => _removeReferenceImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ========== 参数配置区域 ==========
  Widget _buildParameterSection(ThemeData theme) {
    final ratioSizes = GenerationConfig.sizesByRatio[_selectedRatio] ??
        GenerationConfig.availableSizes;
    final displaySizes = ratioSizes.toList();

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
              onChanged: (val) => setState(() => _selectedModel = val),
            ),
            const SizedBox(height: 16),
            _buildRatioChips(theme),
            const SizedBox(height: 12),
            // 尺寸选择：自动 / 自定义 / 预设
            if (_selectedRatio == 'auto')
              _buildAutoSizeHint(theme)
            else if (_selectedRatio == 'custom')
              _buildCustomSizeInputs(theme)
            else
              _buildDropdown(
                theme,
                label: '尺寸',
                icon: Icons.aspect_ratio,
                value: _selectedSize,
                items: displaySizes,
                displayNames:
                    displaySizes.map(GenerationConfig.sizeDisplayName).toList(),
                onChanged: (val) => setState(() => _selectedSize = val),
              ),
            const SizedBox(height: 12),
            _buildDropdown(
              theme,
              label: '质量',
              icon: Icons.high_quality,
              value: _selectedQuality,
              items: GenerationConfig.availableQualities,
              displayNames: GenerationConfig.availableQualities
                  .map(GenerationConfig.qualityDisplayName)
                  .toList(),
              onChanged: (val) => setState(() => _selectedQuality = val),
            ),
            const SizedBox(height: 12),
            _buildCountSelector(theme),
          ],
        ),
      ),
    );
  }

  /// 生成数量选择器
  Widget _buildCountSelector(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.filter_none, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text('生成数量', style: theme.textTheme.bodyMedium),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 22),
          onPressed: _selectedCount > 1
              ? () => setState(() => _selectedCount--)
              : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            border:
                Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$_selectedCount',
            style: theme.textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 22),
          onPressed: _selectedCount < 4
              ? () => setState(() => _selectedCount++)
              : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  /// 宽高比快速选择芯片
  Widget _buildRatioChips(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.crop, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('宽高比', style: theme.textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: GenerationConfig.aspectRatios.map((ratio) {
            final isSelected = _selectedRatio == ratio;
            String label;
            IconData icon;
            switch (ratio) {
              case 'auto':
                label = '自动';
                icon = Icons.auto_fix_high;
                break;
              case 'custom':
                label = '自定义';
                icon = Icons.edit;
                break;
              case '1:1':
                label = '1:1 方形';
                icon = Icons.crop_square;
                break;
              case '3:2':
                label = '3:2 横版';
                icon = Icons.crop_landscape;
                break;
              case '2:3':
                label = '2:3 竖版';
                icon = Icons.crop_portrait;
                break;
              case '16:9':
                label = '16:9 宽屏';
                icon = Icons.crop_16_9;
                break;
              case '9:16':
                label = '9:16 竖屏';
                icon = Icons.stay_current_portrait;
                break;
              default:
                label = ratio;
                icon = Icons.crop_square;
            }
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16),
                  const SizedBox(width: 4),
                  Text(label),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedRatio = ratio;
                    _selectedSize = GenerationConfig.defaultSizeForRatio(ratio);
                  });
                }
              },
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 自动尺寸提示
  Widget _buildAutoSizeHint(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.auto_fix_high, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text('尺寸', style: theme.textTheme.bodyMedium),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '由 AI 自动决定',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  /// 自定义尺寸输入
  Widget _buildCustomSizeInputs(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.aspect_ratio, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text('尺寸', style: theme.textTheme.bodyMedium),
        const Spacer(),
        SizedBox(
          width: 72,
          child: TextField(
            controller: _customWidthController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              border: OutlineInputBorder(),
              hintText: '宽',
            ),
            onChanged: (v) {
              _customWidth = v;
              _updateCustomSize();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('x', style: theme.textTheme.bodyMedium),
        ),
        SizedBox(
          width: 72,
          child: TextField(
            controller: _customHeightController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              border: OutlineInputBorder(),
              hintText: '高',
            ),
            onChanged: (v) {
              _customHeight = v;
              _updateCustomSize();
            },
          ),
        ),
      ],
    );
  }

  void _updateCustomSize() {
    final w = int.tryParse(_customWidth);
    final h = int.tryParse(_customHeight);
    if (w != null && h != null && w > 0 && h > 0) {
      _selectedSize = '${w}x$h';
    }
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
            final displayName =
                displayNames != null ? displayNames[entry.key] : entry.value;
            return DropdownMenuItem(
              value: entry.value,
              child: Text(displayName, style: theme.textTheme.bodyMedium),
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
  Widget _buildActionButtons(ThemeData theme, GenerationProvider provider) {
    final totalImages =
        (_referenceImage != null ? 1 : 0) + _referenceImages.length;
    final canAddMore = totalImages < 3;

    return Row(
      children: [
        OutlinedButton.icon(
          onPressed:
              provider.isGenerating || !canAddMore ? null : _pickReferenceImage,
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
          label: Text(totalImages > 0 ? '参考图($totalImages/3)' : '参考图'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed:
                _canGenerate && !provider.isGenerating ? _generate : null,
            icon: const Icon(Icons.auto_awesome, size: 20),
            label: Text(provider.isGenerating ? '生成中...' : '生成图片'),
          ),
        ),
      ],
    );
  }

  // ========== 结果区域 ==========
  Widget _buildResultSection(ThemeData theme, GenerationProvider provider) {
    final images = provider.lastGeneratedImages;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 多图网格展示
          if (images.length > 1)
            _buildMultiImageGrid(theme, images, provider)
          else if (images.isNotEmpty)
            _buildSingleImage(theme, images.first, provider),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('生成成功',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: Colors.green)),
                const SizedBox(height: 4),
                Text(
                  '${images.length} 张图片，耗时 ${(provider.generationTimeMs / 1000).toStringAsFixed(1)} 秒',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 12),
                // 多图时显示全部保存按钮
                if (images.length > 1) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          _isSavingToDcim ? null : () => _saveAllToDcim(images),
                      icon: _isSavingToDcim
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download, size: 18),
                      label: Text(_isSavingToDcim ? '保存中...' : '全部保存到相册'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _shareImage(File(images.first.localPath)),
                        icon: const Icon(Icons.share, size: 18),
                        label: Text(images.length > 1 ? '分享第1张' : '分享'),
                      ),
                    ),
                    if (images.length == 1) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSavingToDcim
                              ? null
                              : () => _saveToDcim(File(images.first.localPath)),
                          icon: _isSavingToDcim
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download, size: 18),
                          label: Text(_isSavingToDcim ? '保存中...' : '保存'),
                        ),
                      ),
                    ],
                    if (images.length == 1) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openImageDetail(images.first),
                          icon: const Icon(Icons.fullscreen, size: 18),
                          label: const Text('查看'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleImage(
      ThemeData theme, dynamic image, GenerationProvider provider) {
    final file = File(image.localPath);
    if (!file.existsSync()) return const SizedBox();
    return InkWell(
      onTap: () => _openImageDetail(image),
      child: Image.file(file, fit: BoxFit.contain),
    );
  }

  Widget _buildMultiImageGrid(
      ThemeData theme, List<dynamic> images, GenerationProvider provider) {
    final crossAxisCount = images.length <= 2 ? 2 : 2;
    final screenWidth = MediaQuery.of(context).size.width - 32;
    final itemWidth = (screenWidth - 8) / crossAxisCount;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: images.asMap().entries.map((entry) {
          final index = entry.key;
          final image = entry.value;
          final file = File(image.localPath);
          return GestureDetector(
            onTap: () => _openImageDetail(image),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: file.existsSync()
                      ? Image.file(
                          file,
                          width: itemWidth,
                          height: itemWidth,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: itemWidth,
                          height: itemWidth,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image),
                        ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ========== 错误区域 ==========
  Widget _buildErrorSection(ThemeData theme, GenerationProvider provider) {
    final classified = ErrorClassifier.classify(provider.errorMessage);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: classified.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: classified.color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(classified.icon, color: classified.color, size: 20),
              const SizedBox(width: 8),
              Text(classified.title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: classified.color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            classified.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: classified.color,
            ),
          ),
          if (classified.suggestion != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: classified.color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline,
                      size: 16, color: classified.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      classified.suggestion!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: classified.color.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  provider.reset();
                  _generate();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重试'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/logs'),
                icon: const Icon(Icons.bug_report_outlined, size: 16),
                label: const Text('查看日志'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========== 操作方法 ==========
  Future<void> _generate() async {
    final storage = context.read<StorageService>();
    final queue = context.read<TaskQueueProvider>();
    final referencePaths = <String>[];
    final allImages = <Uint8List>[];
    if (_referenceImage != null) allImages.add(_referenceImage!);
    allImages.addAll(_referenceImages);

    for (final image in allImages) {
      referencePaths
          .add(await storage.saveImageLocally(image, extension: 'png'));
    }

    final config = GenerationConfig(
      prompt: _prompt.trim(),
      model: _selectedModel,
      size: _selectedSize,
      quality: _selectedQuality,
      count: _selectedCount,
      referenceImagePath: referencePaths.isEmpty ? null : referencePaths.first,
      referenceImagePaths:
          referencePaths.length > 1 ? referencePaths.sublist(1) : const [],
    );
    await queue.enqueue(config);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('任务已加入生成队列')),
      );
    }
  }

  Future<void> _pickReferenceImage() async {
    try {
      final totalImages =
          (_referenceImage != null ? 1 : 0) + _referenceImages.length;
      if (totalImages >= 3) return;

      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          if (_referenceImage == null) {
            _referenceImage = bytes;
          } else {
            _referenceImages.add(bytes);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: ${e.toString()}')),
        );
      }
    }
  }

  void _removeReferenceImage(int index) {
    setState(() {
      if (index == 0 && _referenceImage != null) {
        // 删除第一张，将第二张提升为第一张
        if (_referenceImages.isNotEmpty) {
          _referenceImage = _referenceImages.removeAt(0);
        } else {
          _referenceImage = null;
        }
      } else if (_referenceImage != null) {
        _referenceImages.removeAt(index - 1);
      } else {
        _referenceImages.removeAt(index);
      }
    });
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

  Future<void> _saveToDcim(File file) async {
    setState(() => _isSavingToDcim = true);
    try {
      final storageService = context.read<StorageService>();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await storageService.saveToDcim(
        file.path,
        fileName: 'AI_${timestamp}.png',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已保存到 DCIM/AI_Images 目录'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingToDcim = false);
    }
  }

  Future<void> _saveAllToDcim(List<dynamic> images) async {
    setState(() {
      _isSavingToDcim = true;
    });
    try {
      final storageService = context.read<StorageService>();
      int saved = 0;
      for (int i = 0; i < images.length; i++) {
        final file = File(images[i].localPath);
        if (file.existsSync()) {
          await storageService.saveToDcim(
            file.path,
            fileName: 'AI_${DateTime.now().millisecondsSinceEpoch}_$i.png',
          );
          saved++;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已保存 $saved 张图片到 DCIM/AI_Images 目录'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingToDcim = false);
    }
  }

  // ========== 导航方法 ==========

  /// 打开历史记录页面，并处理“再次创作”配置回填。
  Future<void> _openHistory() async {
    final result = await Navigator.pushNamed(context, '/history');
    await _handleRegenerateResult(result);
  }

  /// 打开图片详情页，并处理“再次创作”配置回填。
  Future<void> _openImageDetail(dynamic image) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageDetailScreen(image: image),
      ),
    );
    await _handleRegenerateResult(result);
  }

  /// 使用历史配置还原表单，并恢复仍保存在本地的参考图片。
  Future<void> _handleRegenerateResult(dynamic result) async {
    if (result is String && mounted) {
      setState(() => _prompt = result);
      return;
    }
    if (result is! GenerationConfig) return;

    final paths = <String>[];
    if (result.referenceImagePath?.isNotEmpty ?? false) {
      paths.add(result.referenceImagePath!);
    }
    paths.addAll(result.referenceImagePaths);

    final images = <Uint8List>[];
    var missingCount = 0;
    for (final path in paths) {
      final file = File(path);
      if (!await file.exists()) {
        missingCount++;
        continue;
      }
      try {
        images.add(await file.readAsBytes());
      } catch (_) {
        missingCount++;
      }
    }
    if (!mounted) return;
    setState(() {
      _prompt = result.prompt;
      _selectedModel = result.model;
      _selectedSize = result.size;
      _selectedQuality = result.quality;
      _selectedCount = result.count;
      _selectedRatio = GenerationConfig.ratioForSize(result.size);
      _referenceImage = images.isEmpty ? null : images.first;
      _referenceImages
        ..clear()
        ..addAll(images.skip(1));
    });
    if (missingCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$missingCount 张历史参考图已不存在，已仅恢复其余配置')),
      );
    }
  }
}
