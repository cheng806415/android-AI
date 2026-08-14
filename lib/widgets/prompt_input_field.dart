import 'package:flutter/material.dart';

/// 提示词输入组件
class PromptInputField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSubmit;
  final VoidCallback? onTemplate;
  final VoidCallback? onPromptLibrary;
  final int maxLines;

  const PromptInputField({
    super.key,
    this.initialValue = '',
    required this.onChanged,
    required this.onSubmit,
    this.onTemplate,
    this.onPromptLibrary,
    this.maxLines = 5,
  });

  @override
  State<PromptInputField> createState() => _PromptInputFieldState();
}

class _PromptInputFieldState extends State<PromptInputField> {
  late TextEditingController _controller;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant PromptInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.initialValue,
        selection: TextSelection.collapsed(offset: widget.initialValue.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 18,
                color: _isFocused
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 8),
              Text(
                '描述你想生成的图片',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: _isFocused
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const Spacer(),
              if (widget.onTemplate != null)
                TextButton.icon(
                  onPressed: widget.onTemplate,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('模板'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (widget.onPromptLibrary != null)
                TextButton.icon(
                  onPressed: widget.onPromptLibrary,
                  icon: const Icon(Icons.cloud_download_outlined, size: 16),
                  label: const Text('服务器库'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              Text(
                '${_controller.text.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            maxLines: widget.maxLines,
            onChanged: widget.onChanged,
            onSubmitted: (_) => widget.onSubmit?.call(),
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: '例如: 一只在上海雨夜骑自行车的橘猫，电影感，霓虹灯，高细节',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
