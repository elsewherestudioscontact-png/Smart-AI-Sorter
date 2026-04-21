import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'secure_storage_service.dart';

class ClaudeService {
  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-haiku-4-5-20251001';
  static const String _version = '2023-06-01';

  final Dio _dio = Dio();
  final SecureStorageService _storage = SecureStorageService();

  static const List<String> _validCategories = [
    'Work', 'Personal', 'Finance', 'Education',
    'Entertainment', 'Travel', 'Health', 'Shopping', 'Social', 'Other',
  ];

  Future<bool> verifyApiKey() async {
    try {
      final apiKey = await _storage.getClaudeKey();
      if (apiKey == null || apiKey.isEmpty) return false;

      final response = await _dio.post(
        _baseUrl,
        data: {
          'model': _model,
          'max_tokens': 1,
          'messages': [{'role': 'user', 'content': 'Hi'}],
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': _version,
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> analyzeFile(
    File file,
    String mimeType, {
    Function(String)? onStatus,
  }) async {
    // Claude only supports images via base64 in messages API
    final isImage = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'].contains(mimeType);
    if (!isImage) {
      return analyzeFilename(file.path.split('/').last, onStatus: onStatus);
    }

    final apiKey = await _storage.getClaudeKey();
    if (apiKey == null || apiKey.isEmpty) throw Exception('Claude API key not set');

    onStatus?.call('Reading file...');
    final bytes = await file.readAsBytes();
    final base64Data = base64Encode(bytes);

    onStatus?.call('Sending to Claude...');
    final response = await _dio.post(
      _baseUrl,
      data: {
        'model': _model,
        'max_tokens': 10,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'image', 'source': {'type': 'base64', 'media_type': mimeType, 'data': base64Data}},
              {'type': 'text', 'text': 'Categorize into ONE word: Work, Personal, Finance, Education, Entertainment, Travel, Health, Shopping, Social, or Other. Reply ONLY the category.'},
            ],
          }
        ],
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': _version,
        },
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    if (response.statusCode == 200) {
      final text = (response.data['content'] as List?)?.firstWhere(
        (c) => c['type'] == 'text', orElse: () => null)?['text'];
      if (text != null) {
        final category = _sanitizeCategory(text.trim());
        onStatus?.call('Categorized: $category');
        return category;
      }
    }

    throw Exception('Claude error: ${response.statusCode} ${response.data}');
  }

  Future<String> analyzeFilename(
    String filename, {
    Function(String)? onStatus,
  }) async {
    final apiKey = await _storage.getClaudeKey();
    if (apiKey == null || apiKey.isEmpty) throw Exception('Claude API key not set');

    onStatus?.call('Analyzing filename...');
    final response = await _dio.post(
      _baseUrl,
      data: {
        'model': _model,
        'max_tokens': 10,
        'messages': [
          {
            'role': 'user',
            'content': 'Categorize "$filename" into ONE word: Work, Personal, Finance, Education, Entertainment, Travel, Health, Shopping, Social, or Other. Reply ONLY the category.',
          }
        ],
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': _version,
        },
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    if (response.statusCode == 200) {
      final text = (response.data['content'] as List?)?.firstWhere(
        (c) => c['type'] == 'text', orElse: () => null)?['text'];
      if (text != null) return _sanitizeCategory(text.trim());
    }

    throw Exception('Claude error: ${response.statusCode}');
  }

  String _sanitizeCategory(String raw) {
    final clean = raw.replaceAll(RegExp(r'[^a-zA-Z\s]'), '').trim();
    for (final v in _validCategories) {
      if (clean.toLowerCase().contains(v.toLowerCase())) return v;
    }
    return 'Other';
  }

  bool isSupportedForAnalysis(String path) {
    return ['jpg', 'jpeg', 'png', 'gif', 'webp']
        .contains(path.split('.').last.toLowerCase());
  }

  String getMimeType(String path) {
    const types = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
      'gif': 'image/gif', 'webp': 'image/webp',
    };
    return types[path.split('.').last.toLowerCase()] ?? 'application/octet-stream';
  }
}
