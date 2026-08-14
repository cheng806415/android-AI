import 'package:flutter/material.dart';
import '../models/server_prompt.dart';
import '../services/prompt_library_service.dart';

class PromptLibraryScreen extends StatefulWidget {
  const PromptLibraryScreen({super.key});

  @override
  State<PromptLibraryScreen> createState() => _PromptLibraryScreenState();
}

class _PromptLibraryScreenState extends State<PromptLibraryScreen> {
  final PromptLibraryService _service = PromptLibraryService();
  final TextEditingController _searchController = TextEditingController();
  List<ServerPrompt> _items = [];
  List<String> _categories = [];
  String _selectedCategory = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.fetchLibrary(
        keyword: _searchController.text.trim(),
        category: _selectedCategory,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _categories = result.categories;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _search() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _loadLibrary();
  }

  void _showDetail(ServerPrompt item) {
    showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Chip(label: Text(item.category)),
                      ...item.tags.map((tag) => Chip(label: Text(tag))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(item.description),
                  const SizedBox(height: 16),
                  Text('提示词', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  SelectableText(item.prompt),
                  if (item.negativePrompt.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('反向提示词', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    SelectableText(item.negativePrompt),
                  ],
                  if (item.variables.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('可替换变量', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(item.variables
                        .map((variable) => '{{$variable}}')
                        .join('、')),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.input),
                      label: const Text('使用此提示词'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((used) {
      if (used == true && mounted) {
        Navigator.pop(context, item.prompt);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('服务器提示词库')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      hintText: '搜索标题、行业、标签或提示词',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.search),
                  tooltip: '搜索',
                ),
              ],
            ),
          ),
          if (_categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: '行业分类'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('全部分类')),
                  ..._categories.map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _selectedCategory = value ?? '');
                  _loadLibrary();
                },
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError(theme)
                    : _items.isEmpty
                        ? const Center(child: Text('没有找到匹配的提示词'))
                        : RefreshIndicator(
                            onRefresh: _loadLibrary,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, index) =>
                                  _buildItem(theme, _items[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 42, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadLibrary,
              icon: const Icon(Icons.refresh),
              label: const Text('重新加载'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(ThemeData theme, ServerPrompt item) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(item.title, style: theme.textTheme.titleMedium),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.category,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(item.description,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if (item.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: item.tags
                      .take(4)
                      .map((tag) => Chip(label: Text(tag)))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
