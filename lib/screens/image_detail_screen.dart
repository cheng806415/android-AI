import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/image_model.dart';
import '../models/generation_config.dart';
import '../providers/history_provider.dart';
import '../services/storage_service.dart';
import 'package:intl/intl.dart';

/// 图片详情页面 - 全屏查看、分享、收藏、再次生成
class ImageDetailScreen extends StatefulWidget {
  final GeneratedImage image;

  const ImageDetailScreen({super.key, required this.image});

  @override
  State<ImageDetailScreen> createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends State<ImageDetailScreen> {
  bool _showInfo = false;
  late GeneratedImage _image;

  @override
  void initState() {
    super.initState();
    _image = widget.image;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(_image.localPath);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 收藏按钮
          IconButton(
            icon: Icon(
              _image.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _image.isFavorite ? Colors.red[300] : null,
            ),
            onPressed: _toggleFavorite,
            tooltip: _image.isFavorite ? '取消收藏' : '收藏',
          ),
          IconButton(
            icon: Icon(_showInfo ? Icons.info : Icons.info_outline),
            onPressed: () => setState(() => _showInfo = !_showInfo),
            tooltip: '图片信息',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editMetadata,
            tooltip: '编辑作品信息',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareImage(file),
            tooltip: '分享',
          ),
          PopupMenuButton<String>(
            color: Colors.grey[900],
            onSelected: (val) => _handleMenuAction(val, file),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.save_alt, size: 20),
                    SizedBox(width: 8),
                    Text('保存到相册'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'regenerate',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 8),
                    Text('使用此配置再次创作'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy_prompt',
                child: Row(
                  children: [
                    Icon(Icons.copy, size: 20),
                    SizedBox(width: 8),
                    Text('复制提示词'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 图片
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: file.existsSync()
                  ? Image.file(
                      file,
                      fit: BoxFit.contain,
                    )
                  : const Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.white54,
                    ),
            ),
          ),

          // 底部操作栏
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(theme),
          ),

          // 信息面板
          if (_showInfo)
            Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 提示词
                      Text(
                        widget.image.prompt,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 12),

                      // 参数信息
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          _buildInfoChip(
                            '模型',
                            GenerationConfig.modelDisplayName(_image.model),
                          ),
                          _buildInfoChip('标题',
                              _image.title.isEmpty ? '未设置' : _image.title),
                          _buildInfoChip(
                              '分类',
                              _image.category.isEmpty
                                  ? '未分类'
                                  : _image.category),
                          if (_image.tags.isNotEmpty)
                            _buildInfoChip('标签', _image.tags.join('、')),
                          if (_image.notes.isNotEmpty)
                            _buildInfoChip('备注', _image.notes),
                          _buildInfoChip('尺寸', widget.image.size),
                          _buildInfoChip('质量', widget.image.quality),
                          if (widget.image.generationTimeMs > 0)
                            _buildInfoChip(
                              '耗时',
                              '${(widget.image.generationTimeMs / 1000).toStringAsFixed(1)}s',
                            ),
                          _buildInfoChip(
                            '时间',
                            DateFormat('yyyy-MM-dd HH:mm')
                                .format(widget.image.createdAt),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 收藏按钮
            TextButton.icon(
              onPressed: _toggleFavorite,
              icon: Icon(
                widget.image.isFavorite
                    ? Icons.favorite
                    : Icons.favorite_border,
                size: 18,
                color: _image.isFavorite ? Colors.red[300] : Colors.white70,
              ),
              label: Text(
                widget.image.isFavorite ? '已收藏' : '收藏',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            const Spacer(),
            // 再次生成按钮
            ElevatedButton.icon(
              onPressed: _regenerate,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('再次生成'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _editMetadata() async {
    final titleController = TextEditingController(text: _image.title);
    final categoryController = TextEditingController(text: _image.category);
    final tagsController = TextEditingController(text: _image.tags.join(', '));
    final notesController = TextEditingController(text: _image.notes);
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑作品信息'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: '标题')),
              TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: '分类')),
              TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(labelText: '标签，用逗号分隔')),
              TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: '备注'),
                  maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'title': titleController.text,
              'category': categoryController.text,
              'tags': tagsController.text,
              'notes': notesController.text,
            }),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    titleController.dispose();
    categoryController.dispose();
    tagsController.dispose();
    notesController.dispose();
    if (result == null || !mounted) return;
    final tags = (result['tags'] ?? '')
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
    await context.read<HistoryProvider>().updateMetadata(
          _image,
          title: result['title'] ?? '',
          category: result['category'] ?? '',
          tags: tags,
          notes: result['notes'] ?? '',
        );
    if (!mounted) return;
    setState(() {
      _image = _image.copyWith(
        title: result['title'],
        category: result['category'],
        tags: tags,
        notes: result['notes'],
      );
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('作品信息已保存')));
  }

  Future<void> _toggleFavorite() async {
    if (!mounted) return;
    await context.read<HistoryProvider>().toggleFavorite(_image.id);
    if (mounted) {
      setState(() => _image = _image.copyWith(isFavorite: !_image.isFavorite));
    }
  }

  /// 返回完整生成配置，让首页恢复本次创作参数。
  void _regenerate() {
    Navigator.pop(context, widget.image.generationConfig);
  }

  Future<void> _shareImage(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: widget.image.prompt,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('分享失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveToAlbum(File file) async {
    try {
      final storageService = context.read<StorageService>();
      final result = await storageService.saveToDcim(file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.isNotEmpty ? '已保存到相册: $result' : '已保存到相册'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存到相册失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleMenuAction(String action, File file) {
    switch (action) {
      case 'save':
        _saveToAlbum(file);
        break;
      case 'regenerate':
        _regenerate();
        break;
      case 'copy_prompt':
        Clipboard.setData(ClipboardData(text: widget.image.prompt));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('提示词已复制到剪贴板'),
              backgroundColor: Colors.green,
            ),
          );
        }
        break;
    }
  }
}
