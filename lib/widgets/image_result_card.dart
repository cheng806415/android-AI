import 'dart:io';
import 'package:flutter/material.dart';
import '../models/image_model.dart';
import '../models/generation_config.dart';
import 'package:intl/intl.dart';

/// 图片结果卡片组件
class ImageResultCard extends StatelessWidget {
  final GeneratedImage image;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ImageResultCard({
    super.key,
    required this.image,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(image.localPath);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片预览
            AspectRatio(
              aspectRatio: 1,
              child: file.existsSync()
                  ? Image.file(
                      file,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.broken_image,
                          size: 48,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                      ),
                    )
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                    ),
            ),
            // 信息区域
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    image.prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildTag(theme, GenerationConfig.modelDisplayName(image.model)),
                      const SizedBox(width: 6),
                      _buildTag(theme, image.size),
                      if (image.generationTimeMs > 0) ...[
                        const SizedBox(width: 6),
                        _buildTag(
                            theme, '${(image.generationTimeMs / 1000).toStringAsFixed(1)}s'),
                      ],
                      const Spacer(),
                      if (onDelete != null)
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: theme.colorScheme.error.withOpacity(0.7),
                          ),
                          onPressed: onDelete,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(image.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(ThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontSize: 11,
        ),
      ),
    );
  }
}
