import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/api_response_model.dart';
import '../providers/settings_provider.dart';

/// 商家选择器组件
class ProviderSelector extends StatelessWidget {
  const ProviderSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final theme = Theme.of(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 模式切换
            Row(
              children: [
                Text('商家模式', style: theme.textTheme.labelLarge),
                const Spacer(),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'auto', label: Text('自动')),
                    ButtonSegment(value: 'manual', label: Text('手动')),
                  ],
                  selected: {settings.groupMode},
                  onSelectionChanged: (selected) {
                    settings.setGroupMode(selected.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 自动模式提示
            if (settings.isAutoMode)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_mode,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '自动模式: 按优先级依次尝试各商家，失败后自动切换下一个',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 手动模式商家选择
            if (!settings.isAutoMode) ...[
              ...settings.providers.map((provider) {
                final isSelected = settings.selectedProvider == provider.id;
                final isValid = provider.isValid;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => settings.setSelectedProvider(provider.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline.withOpacity(0.3),
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected
                            ? theme.colorScheme.primary.withOpacity(0.05)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.4),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.name,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      isValid ? '已配置' : '未配置',
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: isValid
                                            ? Colors.green
                                            : theme.colorScheme.error
                                                .withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      provider.baseUrl,
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.4),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  children: provider.supportedEndpoints
                                      .map((ep) => _buildEndpointTag(
                                          theme, ep))
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                          if (!isValid)
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: theme.colorScheme.error.withOpacity(0.5),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEndpointTag(ThemeData theme, EndpointType endpoint) {
    String label;
    switch (endpoint) {
      case EndpointType.imagesGenerations:
        label = 'Images API';
        break;
      case EndpointType.responses:
        label = 'Responses';
        break;
      case EndpointType.chatCompletions:
        label = 'Chat';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.secondary,
          fontSize: 10,
        ),
      ),
    );
  }
}
