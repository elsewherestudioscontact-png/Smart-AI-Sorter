import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'secure_storage_service.dart';

class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  // FIX: gemini-2.5-flash doesn't exist — correct ID below
  static const String _model = 'gemini-1.5-flash';

  final Dio _dio = Dio();
  final SecureStorageService _storage = SecureStorageService();

  static const List<String> _validCategories = [
    'Work', 'Personal', 'Finance', 'Education',
    'Entertainment', 'Travel', 'Health', 'Shopping', 'Social', 'Other',
  ];

  Future<bool> verifyApiKey() async {
    try {
      final apiKey = await _storage.getGeminiKey();
      if (apiKey == null || apiKey.isEmpty) return false;

      final response = await _dio.post(
        '$_baseUrl/$_model:generateContent?key=$apiKey',
        data: {
          'contents': [{'parts': [{'text': 'Hi'}]}],
          'generationConfig': {'maxOutputTokens': 1},
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
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
    final apiKey = await _storage.getGeminiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API key not set');
    }

    onStatus?.call('Reading file...');
    final bytes = await file.readAsBytes();
    final base64Data = base64Encode(bytes);

    onStatus?.call('Sending to Gemini...');
    final response = await _dio.post(
      '$_baseUrl/$_model:generateContent?key=$apiKey',
      data: {
        'contents': [
          {
            'parts': [
              {'inlineData': {'mimeType': mimeType, 'data': base64Data}},
              {'text': 'Categorize into ONE word: Work, Personal, Finance, Education, Entertainment, Travel, Health, Shopping, Social, or Other. Reply ONLY the category.'},
            ]
          }
        ],
        'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 10},
      },
      options: Options(
        headers: {'Content-Type': 'application/json'},
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    if (response.statusCode == 200) {
      final text = response.data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (text != null) {
        final category = _sanitizeCategory(text.trim());
        onStatus?.call('Categorized: $category');
        return category;
      }
    }

    throw Exception('Gemini error: ${response.statusCode} ${response.data}');
  }

  Future<String> analyzeFilename(
    String filename, {
    Function(String)? onStatus,
  }) async {
    final apiKey = await _storage.getGeminiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API key not set');
    }

    onStatus?.call('Analyzing filename...');
    final response = await _dio.post(
      '$_baseUrl/$_model:generateContent?key=$apiKey',
      data: {
        'contents': [
          {'parts': [{'text': 'Categorize "$filename" into ONE word: Work, Personal, Finance, Education, Entertainment, Travel, Health, Shopping, Social, or Other. Reply ONLY the category.'}]}
        ],
        'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 10},
      },
      options: Options(
        headers: {'Content-Type': 'application/json'},
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );

    if (response.statusCode == 200) {
      final text = response.data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (text != null) return _sanitizeCategory(text.trim());
    }

    throw Exception('Gemini error: ${response.statusCode}');
  }

  String _sanitizeCategory(String raw) {
    final clean = raw.replaceAll(RegExp(r'[^a-zA-Z\s]'), '').trim();
    for (final v in _validCategories) {
      if (clean.toLowerCase().contains(v.toLowerCase())) return v;
    }
    return 'Other';
  }

  String getMimeType(String path) {
    const types = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
      'gif': 'image/gif', 'webp': 'image/webp', 'pdf': 'application/pdf',
      'mp4': 'video/mp4', 'mp3': 'audio/mpeg', 'txt': 'text/plain',
    };
    return types[path.split('.').last.toLowerCase()] ?? 'application/octet-stream';
  }

  bool isSupportedForAnalysis(String path) {
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'txt']
        .contains(path.split('.').last.toLowerCase());
  }
}
