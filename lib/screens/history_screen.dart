import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/history_provider.dart';
import '../widgets/image_result_card.dart';
import 'image_detail_screen.dart';

/// 历史记录页面
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  bool _showFavoritesOnly = false;
  String? _selectedCategory;
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().loadHistory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索提示词...',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (val) {
                  context.read<HistoryProvider>().search(val);
                },
              )
            : Text(_showFavoritesOnly ? '我的收藏' : '历史记录'),
        actions: [
          // 收藏筛选切换
          IconButton(
            icon: Icon(
              _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
              color: _showFavoritesOnly ? Colors.red[300] : null,
            ),
            tooltip: '收藏筛选',
            onPressed: _toggleFavoritesFilter,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: '分类和标签筛选',
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _reloadData();
                }
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (val) => _handleMenuAction(val),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'refresh', child: Text('刷新')),
              if (_showFavoritesOnly)
                const PopupMenuItem(value: 'show_all', child: Text('显示全部'))
              else
                const PopupMenuItem(
                    value: 'show_favorites', child: Text('仅显示收藏')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'clear', child: Text('清空所有')),
            ],
          ),
        ],
      ),
      body: Consumer<HistoryProvider>(
        builder: (context, history, _) {
          if (history.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (history.records.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showFavoritesOnly
                        ? Icons.favorite_border
                        : Icons.photo_library_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showFavoritesOnly ? '暂无收藏' : '暂无生成记录',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _showFavoritesOnly ? '点击收藏按钮将喜欢的图片添加到收藏' : '生成的图片会保存在这里',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // 统计信息
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                child: Row(
                  children: [
                    Text(
                      '共 ${history.totalCount} 张图片',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const Spacer(),
                    if (!_showFavoritesOnly)
                      Text(
                        '占用 ${history.storageSizeDisplay}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                  ],
                ),
              ),
              // 图片列表
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: history.records.length,
                  itemBuilder: (context, index) {
                    final image = history.records[index];
                    return ImageResultCard(
                      image: image,
                      onTap: () => _openDetail(image),
                      onDelete: () => _confirmDelete(image.id),
                      onFavorite: () => _toggleFavorite(image.id),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _toggleFavoritesFilter() {
    setState(() {
      _showFavoritesOnly = !_showFavoritesOnly;
      _isSearching = false;
      _searchController.clear();
      if (_showFavoritesOnly) {
        context.read<HistoryProvider>().loadFavorites();
      } else {
        context.read<HistoryProvider>().loadHistory();
      }
    });
  }

  void _reloadData() {
    if (_showFavoritesOnly) {
      context.read<HistoryProvider>().loadFavorites();
    } else {
      context.read<HistoryProvider>().loadHistory();
    }
  }

  Future<void> _showFilterDialog() async {
    final history = context.read<HistoryProvider>();
    var category = _selectedCategory;
    var tag = _selectedTag;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('筛选作品'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: '分类'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('全部分类')),
                  ...history.categories.map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  ),
                ],
                onChanged: (value) => setState(() => category = value),
              ),
              DropdownButtonFormField<String>(
                value: tag,
                decoration: const InputDecoration(labelText: '标签'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('全部标签')),
                  ...history.tags.map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  ),
                ],
                onChanged: (value) => setState(() => tag = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _selectedCategory = null;
                _selectedTag = null;
                history.loadHistory();
              },
              child: const Text('清除'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _selectedCategory = category?.isEmpty == true ? null : category;
                _selectedTag = tag?.isEmpty == true ? null : tag;
                history.applyFilters(
                  category: _selectedCategory,
                  tag: _selectedTag,
                );
              },
              child: const Text('应用'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(dynamic image) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageDetailScreen(image: image),
      ),
    );
    // 返回完整配置时，由首页执行参数回填。
    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  Future<void> _toggleFavorite(String id) async {
    await context.read<HistoryProvider>().toggleFavorite(id);
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'refresh':
        _reloadData();
        break;
      case 'show_all':
        _toggleFavoritesFilter();
        break;
      case 'show_favorites':
        _toggleFavoritesFilter();
        break;
      case 'clear':
        _confirmClearAll();
        break;
    }
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除图片'),
        content: const Text('确定要删除这张图片吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<HistoryProvider>().deleteRecord(id);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空所有记录'),
        content: const Text('确定要清空所有历史记录吗？所有本地图片也会被删除，此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<HistoryProvider>().clearAll();
            },
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
