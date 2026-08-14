import 'package:flutter/material.dart';
import '../models/prompt_template.dart';

/// 提示词模板选择器
class PromptTemplatePicker extends StatelessWidget {
  final ValueChanged<PromptTemplate> onSelected;

  const PromptTemplatePicker({super.key, required this.onSelected});

  static Future<void> show(
      BuildContext context, ValueChanged<PromptTemplate> onSelected) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => PromptTemplatePicker(onSelected: onSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择提示词模板', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('选择后仍可以继续编辑提示词',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.55))),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: PromptTemplate.builtIn.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final item = PromptTemplate.builtIn[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          theme.colorScheme.primary.withOpacity(0.1),
                      child: Icon(_iconFor(item.id),
                          color: theme.colorScheme.primary),
                    ),
                    title: Text(item.name),
                    subtitle: Text(item.description),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      onSelected(item);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String id) {
    switch (id) {
      case 'anime_couple':
        return Icons.favorite;
      case 'avatar':
        return Icons.account_circle;
      case 'wallpaper':
        return Icons.wallpaper;
      case 'poster':
        return Icons.article;
      case 'product':
        return Icons.shopping_bag;
      case 'portrait':
        return Icons.face;
      default:
        return Icons.auto_awesome;
    }
  }
}
