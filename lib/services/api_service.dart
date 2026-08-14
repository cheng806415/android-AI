import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/api_response_model.dart';
import '../models/generation_config.dart';
import 'settings_service.dart';

/// API 服务 - 处理所有与图片生成 API 的交互
/// 支持多商家、多端点、自动重试
class ApiService {
  final SettingsService settings;
  http.Client _client = http.Client();
  bool _cancelRequested = false;

  ApiService(this.settings);

  static const int _timeoutSeconds = 120;
  static const int _streamTimeoutSeconds = 180;

  bool get isCancelRequested => _cancelRequested;

  /// 取消当前所有网络请求，并为下一次生成创建新的客户端。
  void cancelCurrentRequests() {
    _cancelRequested = true;
    _client.close();
    _client = http.Client();
  }

  void _prepareForNewRequest() {
    _cancelRequested = false;
  }

  // ========== 核心生成方法 ==========

  /// 生成图片 - 自动处理商家优先级和重试逻辑
  Future<ImageGenerationResult> generateImage(GenerationConfig config,
      {Function(String)? onProgress}) async {
    _prepareForNewRequest();
    if (settings.isAutoMode) {
      return _generateWithAutoRetry(config, onProgress: onProgress);
    } else {
      final providerId = settings.selectedProvider;
      final provider = settings.getProvider(providerId);
      if (provider == null || !provider.isValid) {
        return ImageGenerationResult.fromError(
          '商家未配置或 API Key 无效',
          providerName: provider?.name,
        );
      }
      return _generateWithProvider(config, provider, onProgress: onProgress);
    }
  }

  /// 自动模式：按优先级尝试各商家
  Future<ImageGenerationResult> _generateWithAutoRetry(GenerationConfig config,
      {Function(String)? onProgress}) async {
    final providers = settings.getValidProvidersSorted();

    if (providers.isEmpty) {
      return ImageGenerationResult.fromError('没有配置任何有效的 API Key');
    }

    // 多图：每张图独立走自动重试流程
    if (config.count > 1) {
      final singleConfig = config.copyWith(count: 1);
      final futures = List<Future<ImageGenerationResult>>.generate(
        config.count,
        (i) {
          if (_cancelRequested) {
            return Future.value(ImageGenerationResult.fromError('用户已取消生成'));
          }
          onProgress?.call('正在生成第 ${i + 1}/${config.count} 张...');
          return _autoRetrySingle(singleConfig, providers,
              onProgress: onProgress);
        },
      );
      final results = await Future.wait(futures);
      return _mergeResults(results, 'auto');
    }

    return _autoRetrySingle(config, providers, onProgress: onProgress);
  }

  /// 自动模式单次调用
  Future<ImageGenerationResult> _autoRetrySingle(
      GenerationConfig config, List<ApiProvider> providers,
      {Function(String)? onProgress}) async {
    final retryCount = settings.autoRetryCount;
    final errors = <String>[];

    for (final provider in providers) {
      for (int attempt = 1; attempt <= retryCount; attempt++) {
        if (_cancelRequested) {
          return ImageGenerationResult.fromError('用户已取消生成');
        }

        onProgress
            ?.call('正在使用 ${provider.name} 生成 (第 $attempt/$retryCount 次)...');

        final result =
            await _generateSingleCall(config, provider, onProgress: onProgress);
        if (result.isSuccess) {
          return result;
        }

        if (result.error != null) {
          final name = result.providerName ?? provider.name;
          errors.add('$name: ${result.error}');

          if (_isNonRetryableError(result.error!)) {
            break;
          }
        }
      }
    }

    return ImageGenerationResult.fromError('所有商家均失败:\n${errors.join('\n')}');
  }

  /// 使用指定商家生成图片（支持多图并行请求）
  Future<ImageGenerationResult> _generateWithProvider(
      GenerationConfig config, ApiProvider provider,
      {Function(String)? onProgress}) async {
    // 多图生成：并行发起多次请求，每次生成 1 张
    if (config.count > 1) {
      final singleConfig = config.copyWith(count: 1);
      final futures = List<Future<ImageGenerationResult>>.generate(
        config.count,
        (i) {
          if (_cancelRequested) {
            return Future.value(ImageGenerationResult.fromError('用户已取消生成'));
          }
          onProgress?.call('正在生成第 ${i + 1}/${config.count} 张...');
          return _generateSingleCall(singleConfig, provider);
        },
      );
      final results = await Future.wait(futures);
      return _mergeResults(results, provider.name);
    }

    return _generateSingleCall(config, provider, onProgress: onProgress);
  }

  /// 单次生成调用（count=1）
  Future<ImageGenerationResult> _generateSingleCall(
      GenerationConfig config, ApiProvider provider,
      {Function(String)? onProgress}) async {
    // 图片编辑：优先使用 /v1/images/edits
    if (config.hasReferenceImage) {
      if (provider.supportedEndpoints
          .contains(EndpointType.imagesGenerations)) {
        return _generateViaImagesEditApi(config, provider,
            onProgress: onProgress);
      }
      if (provider.supportedEndpoints.contains(EndpointType.responses)) {
        return _generateViaResponses(config, provider, onProgress: onProgress);
      }
    }

    // 按端点优先级尝试（非编辑模式）
    for (final endpoint in provider.supportedEndpoints) {
      switch (endpoint) {
        case EndpointType.imagesGenerations:
          if (!config.hasReferenceImage) {
            return _generateViaImagesApi(config, provider,
                onProgress: onProgress);
          }
          break;
        case EndpointType.responses:
          if (!config.hasReferenceImage) {
            return _generateViaResponses(config, provider,
                onProgress: onProgress);
          }
          break;
        case EndpointType.chatCompletions:
          if (!config.hasReferenceImage) {
            return _generateViaChatCompletions(config, provider,
                onProgress: onProgress);
          }
          break;
      }
    }

    return ImageGenerationResult.fromError(
      '该商家不支持当前操作',
      providerName: provider.name,
    );
  }

  /// 合并多个生成结果
  ImageGenerationResult _mergeResults(
      List<ImageGenerationResult> results, String providerName) {
    final allUrls = <String>[];
    final allB64s = <String>[];
    String? revisedPrompt;
    final errors = <String>[];

    for (int i = 0; i < results.length; i++) {
      final r = results[i];
      revisedPrompt ??= r.revisedPrompt;
      if (r.isSuccess) {
        allUrls.addAll(r.allImageUrls);
        allB64s.addAll(r.allBase64Datas);
      } else {
        errors.add('第${i + 1}张: ${r.error ?? "未知错误"}');
      }
    }

    if (allUrls.isEmpty && allB64s.isEmpty) {
      return ImageGenerationResult.fromError(
        errors.isNotEmpty ? errors.join('; ') : '所有请求均失败',
        providerName: providerName,
      );
    }

    return ImageGenerationResult(
      imageUrl: allUrls.isNotEmpty ? allUrls.first : null,
      base64Data: allB64s.isNotEmpty ? allB64s.first : null,
      imageUrls: allUrls.length > 1 ? allUrls.sublist(1) : const [],
      base64Datas: allB64s.length > 1 ? allB64s.sublist(1) : const [],
      revisedPrompt: revisedPrompt,
      providerName: providerName,
    );
  }

  // ========== 端点实现 ==========

  /// 通过 /v1/images/edits 端点编辑图片（支持多图）
  Future<ImageGenerationResult> _generateViaImagesEditApi(
      GenerationConfig config, ApiProvider provider,
      {Function(String)? onProgress}) async {
    final url = '${provider.baseUrl}/v1/images/edits';

    try {
      final imageCount = config.referenceImageCount;
      onProgress?.call(
          imageCount > 1 ? '正在编辑图片 (${imageCount}张参考图)...' : '正在编辑图片...');

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer ${provider.apiKey}';

      // 添加第一张参考图片（字段名 image）
      if (config.referenceImagePath != null) {
        final file = File(config.referenceImagePath!);
        if (await file.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'image',
              file.path,
              contentType: MediaType('image', 'png'),
            ),
          );
        }
      }

      // 添加额外参考图片（字段名 image_1, image_2, ...）
      for (int i = 0; i < config.referenceImagePaths.length; i++) {
        final path = config.referenceImagePaths[i];
        final file = File(path);
        if (await file.exists()) {
          final fieldName = config.referenceImagePath != null
              ? 'image_${i + 1}'
              : (i == 0 ? 'image' : 'image_$i');
          request.files.add(
            await http.MultipartFile.fromPath(
              fieldName,
              file.path,
              contentType: MediaType('image', 'png'),
            ),
          );
        }
      }

      // 添加文本字段
      request.fields['model'] = config.model;
      request.fields['prompt'] = config.prompt;
      request.fields['size'] = config.size;
      request.fields['n'] = config.count.toString();

      final streamedResponse =
          await request.send().timeout(Duration(seconds: _timeoutSeconds));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = _parseImagesApiResponse(response.body);
        return ImageGenerationResult(
          imageUrl: result.imageUrl,
          base64Data: result.base64Data,
          revisedPrompt: result.revisedPrompt,
          imageUrls: result.imageUrls,
          base64Datas: result.base64Datas,
          providerName: provider.name,
        );
      } else {
        final errorBody = _parseErrorResponse(response.body);
        return ImageGenerationResult.fromError(
          'HTTP ${response.statusCode}: $errorBody',
          providerName: provider.name,
        );
      }
    } catch (e) {
      return ImageGenerationResult.fromError(
        '请求异常: ${e.toString()}',
        providerName: provider.name,
      );
    }
  }

  /// 通过 /v1/images/generations 端点生成
  Future<ImageGenerationResult> _generateViaImagesApi(
      GenerationConfig config, ApiProvider provider,
      {Function(String)? onProgress}) async {
    final url = '${provider.baseUrl}/v1/images/generations';

    final body = {
      'model': config.model,
      'prompt': config.prompt,
      'size': config.size,
      'quality': config.quality,
      'n': config.count,
    };

    try {
      onProgress?.call('正在请求 ${provider.name}...');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer ${provider.apiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        final result = _parseImagesApiResponse(response.body);
        return ImageGenerationResult(
          imageUrl: result.imageUrl,
          base64Data: result.base64Data,
          revisedPrompt: result.revisedPrompt,
          imageUrls: result.imageUrls,
          base64Datas: result.base64Datas,
          providerName: provider.name,
        );
      } else {
        final errorBody = _parseErrorResponse(response.body);
        return ImageGenerationResult.fromError(
          'HTTP ${response.statusCode}: $errorBody',
          providerName: provider.name,
        );
      }
    } catch (e) {
      return ImageGenerationResult.fromError(
        '请求异常: ${e.toString()}',
        providerName: provider.name,
      );
    }
  }

  /// 通过 /v1/chat/completions 端点生成 (LinksAPI 等)
  Future<ImageGenerationResult> _generateViaChatCompletions(
      GenerationConfig config, ApiProvider provider,
      {Function(String)? onProgress}) async {
    final url = '${provider.baseUrl}/v1/chat/completions';

    final body = {
      'model': config.model,
      'messages': [
        {
          'role': 'user',
          'content': config.prompt,
        }
      ],
      'size': config.size,
      'quality': config.quality,
      'n': config.count,
    };

    try {
      onProgress?.call('正在通过 Chat 端点请求 ${provider.name}...');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer ${provider.apiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        return _parseChatCompletionsImageResponse(response.body, provider.name);
      } else {
        final errorBody = _parseErrorResponse(response.body);
        return ImageGenerationResult.fromError(
          'HTTP ${response.statusCode}: $errorBody',
          providerName: provider.name,
        );
      }
    } catch (e) {
      return ImageGenerationResult.fromError(
        '请求异常: ${e.toString()}',
        providerName: provider.name,
      );
    }
  }

  /// 通过 /v1/responses 端点生成（支持流式）
  Future<ImageGenerationResult> _generateViaResponses(
      GenerationConfig config, ApiProvider provider,
      {Function(String)? onProgress}) async {
    final url = '${provider.baseUrl}/v1/responses';

    Map<String, dynamic> body;

    if (config.hasReferenceImage) {
      body = await _buildResponsesEditBody(config);
    } else if (config.model == 'grok-imagine-image') {
      body = {
        'model': config.model,
        'input': config.prompt,
      };
    } else {
      body = {
        'model': config.model,
        'input': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'input_text',
                'text': config.prompt,
              }
            ]
          }
        ],
        'tools': [
          {
            'type': 'image_generation',
            'size': config.size,
            'quality': config.quality,
            'output_format': config.outputFormat,
          }
        ],
        'tool_choice': {'type': 'image_generation'},
        'stream': true,
      };
    }

    try {
      onProgress?.call('正在通过 Responses 端点请求...');

      final client = http.Client();
      final request = http.Request('POST', Uri.parse(url));
      request.headers.addAll({
        'Authorization': 'Bearer ${provider.apiKey}',
        'Content-Type': 'application/json',
      });
      request.body = jsonEncode(body);

      final streamed = await client
          .send(request)
          .timeout(Duration(seconds: _streamTimeoutSeconds));

      if (streamed.statusCode != 200) {
        final responseBody = await streamed.stream.bytesToString();
        final errorBody = _parseErrorResponse(responseBody);
        client.close();
        return ImageGenerationResult.fromError(
          'HTTP ${streamed.statusCode}: $errorBody',
          providerName: provider.name,
        );
      }

      final result = await _handleStreamResponse(streamed, onProgress);
      client.close();
      return ImageGenerationResult(
        imageUrl: result.imageUrl,
        base64Data: result.base64Data,
        revisedPrompt: result.revisedPrompt,
        imageUrls: result.imageUrls,
        base64Datas: result.base64Datas,
        providerName: provider.name,
      );
    } catch (e) {
      return ImageGenerationResult.fromError(
        '请求异常: ${e.toString()}',
        providerName: provider.name,
      );
    }
  }

  /// 处理流式 SSE 响应
  Future<ImageGenerationResult> _handleStreamResponse(
      http.StreamedResponse response, Function(String)? onProgress) async {
    final lineStream =
        response.stream.transform(utf8.decoder).transform(const LineSplitter());

    String? finalImageBase64;
    String? lastPartialBase64;
    String? revisedPrompt;

    await for (final line in lineStream) {
      if (line.isEmpty) continue;

      if (line.startsWith('data: ')) {
        final dataStr = line.substring(6).trim();
        if (dataStr == '[DONE]') break;

        try {
          final data = jsonDecode(dataStr) as Map<String, dynamic>;
          final type = data['type'] as String?;

          switch (type) {
            case 'image_generation_call':
              final result = data['result'] as String?;
              if (result != null) finalImageBase64 = result;
              final prompt = data['revised_prompt'] as String?;
              if (prompt != null) revisedPrompt = prompt;
              break;
            case 'partial_image_b64':
              final partial = data['partial_image_b64'] as String?;
              if (partial != null) lastPartialBase64 = partial;
              onProgress?.call('正在接收图片数据...');
              break;
            case 'response.output_item.done':
              final item = data['item'] as Map<String, dynamic>?;
              if (item != null) {
                final result = item['result'] as String?;
                if (result != null) finalImageBase64 = result;
              }
              break;
          }
        } catch (_) {
          // 忽略无法解析的行
        }
      }
    }

    final imageBase64 = finalImageBase64 ?? lastPartialBase64;

    if (imageBase64 != null && imageBase64.isNotEmpty) {
      return ImageGenerationResult(
        base64Data: imageBase64,
        revisedPrompt: revisedPrompt,
      );
    }

    return ImageGenerationResult.fromError('流式响应结束但未获取到图片数据');
  }

  // ========== 余额查询 ==========

  Future<BalanceInfo> checkBalance(ApiProvider provider) async {
    if (!provider.isValid) {
      throw Exception('${provider.name} 的 API Key 未配置');
    }

    final baseUrl = provider.baseUrl.replaceFirst(RegExp(r'/$'), '');
    final endpoints = <String>[
      // OpenAI Dashboard 余额接口 (MetaAPI 等兼容)
      '$baseUrl/v1/dashboard/billing/subscription',
      '$baseUrl/v1/dashboard/billing/usage',
      // LinksAPI / New-API 兼容余额接口
      '$baseUrl/v1/billing/usage?type=token&unit=usd',
      '$baseUrl/v1/billing/usage',
      // 其他常见中转站接口
      '$baseUrl/v1/balance',
      '$baseUrl/v1/credits',
    ];

    final errors = <String>[];
    double? subscriptionLimit;
    double? totalUsage;

    for (final url in endpoints) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer ${provider.apiKey}',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final path = Uri.parse(url).path;

          // 处理 dashboard/billing/subscription 响应
          if (path.contains('subscription')) {
            try {
              final json = jsonDecode(response.body) as Map<String, dynamic>;
              final softLimit = json['soft_limit_usd'];
              if (softLimit is num) {
                subscriptionLimit = softLimit.toDouble();
              }
            } catch (_) {}
          }

          // 处理 dashboard/billing/usage 响应
          if (path.contains('/usage')) {
            try {
              final json = jsonDecode(response.body) as Map<String, dynamic>;
              final usage = json['total_usage'];
              if (usage is num) {
                totalUsage = usage.toDouble() / 100.0; // 美分转美元
              }
            } catch (_) {}
          }

          // 尝试解析标准余额格式
          final balance = _parseBalanceResponse(response.body);
          if (!balance.isEmpty) return balance;
        } else {
          errors.add('${Uri.parse(url).path}: HTTP ${response.statusCode}');
        }
      } catch (e) {
        errors.add('${Uri.parse(url).path}: ${e.toString()}');
      }
    }

    // 如果通过 dashboard 端点获取到了订阅和用量信息
    if (subscriptionLimit != null) {
      final usage = totalUsage ?? 0.0;
      return BalanceInfo(
        totalBalance: subscriptionLimit,
        usedBalance: usage,
        remainingBalance: subscriptionLimit - usage,
        currency: 'USD',
      );
    }

    // 如果所有端点都返回了 404，说明该商家不支持余额查询
    if (errors.every((e) => e.contains('HTTP 404'))) {
      throw Exception(
          '${provider.name} 不支持余额查询接口。\nAPI Key 已验证有效，请前往商家网站查看余额。');
    }

    throw Exception(
        '无法获取 ${provider.name} 余额。请确认 Base URL、API Key 和商家余额接口；\n${errors.take(3).join('\n')}');
  }

  // ========== 响应解析 ==========

  /// 解析 /v1/images/generations 响应
  ImageGenerationResult _parseImagesApiResponse(String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final dataList = json['data'] as List?;

      if (dataList == null || dataList.isEmpty) {
        return ImageGenerationResult.fromError('响应中没有图片数据');
      }

      final urls = <String>[];
      final b64s = <String>[];
      String? revisedPrompt;

      for (final item in dataList) {
        final image = item as Map<String, dynamic>;
        final url = image['url'] as String?;
        final b64 = image['b64_json'] as String?;
        revisedPrompt ??= image['revised_prompt'] as String?;

        if (url != null && url.isNotEmpty) {
          urls.add(url);
        }
        if (b64 != null && b64.isNotEmpty) {
          b64s.add(b64);
        }
      }

      if (urls.isEmpty && b64s.isEmpty) {
        return ImageGenerationResult.fromError('响应中既无 URL 也无 Base64 数据');
      }

      if (urls.length == 1 && b64s.isEmpty) {
        return ImageGenerationResult(
            imageUrl: urls.first, revisedPrompt: revisedPrompt);
      }
      if (b64s.length == 1 && urls.isEmpty) {
        return ImageGenerationResult(
            base64Data: b64s.first, revisedPrompt: revisedPrompt);
      }

      return ImageGenerationResult(
        imageUrl: urls.isNotEmpty ? urls.first : null,
        base64Data: b64s.isNotEmpty ? b64s.first : null,
        imageUrls: urls.length > 1
            ? urls.sublist(1)
            : (urls.length == 1 && b64s.isNotEmpty ? urls : const []),
        base64Datas: b64s.length > 1
            ? b64s.sublist(1)
            : (b64s.length == 1 && urls.isNotEmpty ? b64s : const []),
        revisedPrompt: revisedPrompt,
      );
    } catch (e) {
      return ImageGenerationResult.fromError('解析响应失败: ${e.toString()}');
    }
  }

  /// 解析 /v1/chat/completions 图片响应
  /// 兼容两种格式:
  /// 1. choices[0].message.content 中包含图片 URL 或 b64
  /// 2. 类似 images/generations 的 data 数组格式
  ImageGenerationResult _parseChatCompletionsImageResponse(
      String responseBody, String providerName) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      // 格式1: 尝试 data 数组 (类似 images API)
      final dataList = json['data'] as List?;
      if (dataList != null && dataList.isNotEmpty) {
        final urls = <String>[];
        final b64s = <String>[];

        for (final item in dataList) {
          final image = item as Map<String, dynamic>;
          final url = image['url'] as String?;
          final b64 = image['b64_json'] as String?;

          if (url != null && url.isNotEmpty) urls.add(url);
          if (b64 != null && b64.isNotEmpty) b64s.add(b64);
        }

        if (urls.isEmpty && b64s.isEmpty) {
          return ImageGenerationResult.fromError(
            'Chat 响应 data 数组中无图片数据',
            providerName: providerName,
          );
        }

        return ImageGenerationResult(
          imageUrl: urls.isNotEmpty ? urls.first : null,
          base64Data: b64s.isNotEmpty ? b64s.first : null,
          imageUrls: urls.length > 1 ? urls.sublist(1) : const [],
          base64Datas: b64s.length > 1 ? b64s.sublist(1) : const [],
          providerName: providerName,
        );
      }

      // 格式2: 从 choices 中提取
      final choices = json['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final message = choices[0]['message'] as Map<String, dynamic>?;
        if (message != null) {
          final content = message['content'];

          // content 可能是字符串
          if (content is String) {
            // 检查是否是 URL
            if (content.startsWith('http') &&
                (content.contains('.png') ||
                    content.contains('.jpg') ||
                    content.contains('.jpeg') ||
                    content.contains('.webp'))) {
              return ImageGenerationResult(
                  imageUrl: content.trim(), providerName: providerName);
            }
            // 检查是否是 base64 data URL
            if (content.startsWith('data:image/')) {
              return ImageGenerationResult(
                  base64Data: content, providerName: providerName);
            }
          }

          // content 可能是数组 (多模态返回)
          if (content is List) {
            for (final item in content) {
              if (item is Map<String, dynamic>) {
                final type = item['type'] as String?;
                if (type == 'image_url') {
                  final urlData = item['image_url'] as Map<String, dynamic>?;
                  final url = urlData?['url'] as String?;
                  if (url != null && url.isNotEmpty) {
                    return ImageGenerationResult(
                        imageUrl: url, providerName: providerName);
                  }
                }
                if (type == 'image') {
                  final b64 = item['data'] as String?;
                  if (b64 != null && b64.isNotEmpty) {
                    return ImageGenerationResult(
                        base64Data: b64, providerName: providerName);
                  }
                }
              }
            }
          }
        }
      }

      return ImageGenerationResult.fromError(
        '无法从 Chat 响应中提取图片',
        providerName: providerName,
      );
    } catch (e) {
      return ImageGenerationResult.fromError(
        '解析 Chat 响应失败: ${e.toString()}',
        providerName: providerName,
      );
    }
  }

  // ========== 辅助方法 ==========

  bool _isNonRetryableError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('invalid') ||
        lower.contains('unsupported') ||
        lower.contains('bad request') ||
        lower.contains('400');
  }

  Future<Map<String, dynamic>> _buildResponsesEditBody(
      GenerationConfig config) async {
    final imageContents = <Map<String, dynamic>>[];

    // 第一张参考图片
    if (config.referenceImagePath != null) {
      final file = File(config.referenceImagePath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final base64Str = base64Encode(bytes);
        imageContents.add({
          'type': 'input_image',
          'image_url': 'data:image/png;base64,$base64Str',
        });
      }
    }

    // 额外参考图片
    for (final path in config.referenceImagePaths) {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final base64Str = base64Encode(bytes);
        imageContents.add({
          'type': 'input_image',
          'image_url': 'data:image/png;base64,$base64Str',
        });
      }
    }

    return {
      'model': config.model,
      'input': [
        {
          'role': 'user',
          'content': [
            {'type': 'input_text', 'text': config.prompt},
            ...imageContents,
          ]
        }
      ],
      'tools': [
        {
          'type': 'image_generation',
          'size': config.size,
          'quality': config.quality,
          'output_format': config.outputFormat,
        }
      ],
      'tool_choice': {'type': 'image_generation'},
      'stream': true,
    };
  }

  String _parseErrorResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      if (error != null) {
        return error['message'] as String? ?? body;
      }
      return body;
    } catch (_) {
      return body;
    }
  }

  BalanceInfo _parseBalanceResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;

      dynamic value(dynamic input) {
        if (input is num) return input.toDouble();
        if (input is String) return double.tryParse(input);
        return null;
      }

      final rawData = json['data'];
      final data =
          rawData is Map<String, dynamic> ? rawData : <String, dynamic>{};
      final rawUser = data['user'];
      final user =
          rawUser is Map<String, dynamic> ? rawUser : <String, dynamic>{};

      final total = value(data['balance']) ??
          value(data['total_balance']) ??
          value(data['quota']) ??
          value(user['quota']) ??
          value(json['balance']) ??
          value(json['remaining']);
      final used = value(data['used']) ??
          value(data['used_balance']) ??
          value(data['used_quota']) ??
          value(user['used_quota']) ??
          value(json['used']) ??
          0.0;

      if (total != null) {
        final remaining = value(data['remaining']) ?? (total - used);
        return BalanceInfo(
          totalBalance: total,
          usedBalance: used,
          remainingBalance: remaining,
          currency: (data['currency'] ?? json['currency'] ?? 'USD').toString(),
        );
      }

      return BalanceInfo.empty();
    } catch (e) {
      return BalanceInfo.empty();
    }
  }

  /// 将 base64 字符串解码为 Uint8List
  static Uint8List decodeBase64Image(String base64Str) {
    String cleanBase64 = base64Str;
    if (cleanBase64.contains(',')) {
      cleanBase64 = cleanBase64.split(',').last;
    }
    return base64Decode(cleanBase64);
  }

  /// 下载网络图片
  Future<Uint8List> downloadImage(String url) async {
    final response =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception('下载图片失败: HTTP ${response.statusCode}');
  }
}
