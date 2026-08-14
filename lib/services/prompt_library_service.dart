import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/server_prompt.dart';

class PromptLibraryService {
  static const String defaultApiUrl =
      'http://103.236.70.249:8766/api/prompts.php';

  final String apiUrl;
  final http.Client _client;

  PromptLibraryService({
    this.apiUrl = defaultApiUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<PromptLibraryResult> fetchLibrary({
    String keyword = '',
    String category = '',
  }) async {
    final listUri = Uri.parse(apiUrl).replace(
      queryParameters: {
        'action': 'list',
        if (keyword.isNotEmpty) 'q': keyword,
        if (category.isNotEmpty) 'category': category,
      },
    );
    final categoriesUri = Uri.parse(apiUrl).replace(
      queryParameters: const {'action': 'categories'},
    );

    final responses = await Future.wait([
      _getJson(listUri),
      _getJson(categoriesUri),
    ]);
    final listData = _readData(responses[0]);
    final categoriesData = _readData(responses[1]);
    final rawItems = listData['items'];

    if (rawItems is! List) {
      throw const FormatException('提示词库列表格式不正确');
    }

    return PromptLibraryResult(
      items: rawItems
          .whereType<Map>()
          .map((item) => ServerPrompt.fromMap(Map<String, dynamic>.from(item)))
          .toList(growable: false),
      categories: _stringList(categoriesData['categories']),
      libraryVersion: listData['libraryVersion'] as String? ?? '',
      updatedAt: listData['updatedAt'] as String? ?? '',
    );
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'AI-Image-Generator-Prompt-Library',
      },
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('提示词库请求失败，HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('提示词库响应格式不正确');
    }
    if (decoded['code'] != 0) {
      throw Exception(decoded['msg'] as String? ?? '提示词库不可用');
    }
    return decoded;
  }

  Map<String, dynamic> _readData(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map) {
      throw const FormatException('提示词库数据格式不正确');
    }
    return Map<String, dynamic>.from(data);
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }

  void dispose() {
    _client.close();
  }
}
