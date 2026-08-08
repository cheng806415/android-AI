import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/image_model.dart';
import '../models/generation_config.dart';
import 'package:intl/intl.dart';

/// 图片详情页面 - 全屏查看、分享、查看参数
class ImageDetailScreen extends StatefulWidget {
  final GeneratedImage image;

  const ImageDetailScreen({super.key, required this.image});

  @override
  State<ImageDetailScreen> createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends State<ImageDetailScreen> {
  bool _showInfo = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(widget.image.localPath);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showInfo ? Icons.info : Icons.info_outline),
            onPressed: () => setState(() => _showInfo = !_showInfo),
            tooltip: '图片信息',
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

          // 信息面板
          if (_showInfo)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
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
                            GenerationConfig.modelDisplayName(
                                widget.image.model),
                          ),
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

  void _handleMenuAction(String action, File file) {
    switch (action) {
      case 'save':
        // 图片已经在本地，可以提示用户已保存
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('图片已保存在应用目录中'),
            backgroundColor: Colors.green,
          ),
        );
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
