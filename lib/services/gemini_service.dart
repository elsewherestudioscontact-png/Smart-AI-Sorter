import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'secure_storage_service.dart';

class GeminiService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  static const String _model = 'gemini-2.5-flash';

  final Dio _dio = Dio();
  final SecureStorageService _storage = SecureStorageService();

  Future<String> analyzeFile(File file, String mimeType) async {
    try {
      final apiKey = await _storage.getApiKey();
      if (apiKey == null) throw Exception('API key not found');

      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);

      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                'inlineData': {
                  'mimeType': mimeType,
                  'data': base64Data,
                }
              },
              {
                'text': 'Analyze this file and categorize it into ONE word: Work, Personal, Finance, Education, Entertainment, Travel, Health, Shopping, Social, or Other. Reply with ONLY the category name.'
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': 10,
        }
      };

      final response = await _dio.post(
        _baseUrl + '/' + _model + ':generateContent?key=' + apiKey,
        data: requestBody,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200) {
        final candidates = response.data['candidates'];
        if (candidates != null && candidates.isNotEmpty) {
          final text = candidates[0]['content']['parts'][0]['text'];
          if (text != null) {
            return _sanitizeCategory(text.trim());
          }
        }
      }

      return 'Other';
    } catch (e) {
      print('Gemini API error: ' + e.toString());
      return 'Other';
    }
  }

  Future<String> analyzeFilename(String filename) async {
    try {
      final apiKey = await _storage.getApiKey();
      if (apiKey == null) throw Exception('API key not found');

      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                'text': 'Categorize filename "' + filename + '" into ONE word: Work, Personal, Finance, Education, Entertainment, Travel, Health, Shopping, Social, or Other. Reply ONLY the category.'
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': 10,
        }
      };

      final response = await _dio.post(
        _baseUrl + '/' + _model + ':generateContent?key=' + apiKey,
        data: requestBody,
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final candidates = response.data['candidates'];
        if (candidates != null && candidates.isNotEmpty) {
          final text = candidates[0]['content']['parts'][0]['text'];
          if (text != null) {
            return _sanitizeCategory(text.trim());
          }
        }
      }

      return 'Other';
    } catch (e) {
      return 'Other';
    }
  }

  String _sanitizeCategory(String category) {
    final validCategories = [
      'Work', 'Personal', 'Finance', 'Education', 
      'Entertainment', 'Travel', 'Health', 'Shopping', 'Social', 'Other'
    ];

    final clean = category.replaceAll(RegExp(r'[^a-zA-Z\s]'), '').trim();

    for (final valid in validCategories) {
      if (clean.toLowerCase().contains(valid.toLowerCase())) {
        return valid;
      }
    }

    return 'Other';
  }

  String getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    final mimeTypes = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
      'gif': 'image/gif', 'webp': 'image/webp', 'pdf': 'application/pdf',
      'mp4': 'video/mp4', 'mp3': 'audio/mpeg', 'txt': 'text/plain',
    };
    return mimeTypes[ext] ?? 'application/octet-stream';
  }

  bool isSupportedForAnalysis(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'txt'].contains(ext);
  }
}
