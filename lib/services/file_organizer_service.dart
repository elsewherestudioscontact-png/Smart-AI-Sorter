import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'gemini_service.dart';
import 'claude_service.dart';
import 'secure_storage_service.dart';
import 'notification_service.dart';

class FileOrganizerService {
  final GeminiService _gemini = GeminiService();
  final ClaudeService _claude = ClaudeService();
  final SecureStorageService _storage = SecureStorageService();

  static const List<String> _targetFolders = [
    'DCIM', 'Pictures', 'Download', 'Downloads', 'Documents', 'Music', 'Movies'
  ];

  Future<PermissionResult> requestPermissions() async {
    final List<String> denied = [];

    // Android 13+ granular media
    for (final perm in [Permission.photos, Permission.videos, Permission.audio]) {
      if (await perm.isDenied) {
        final s = await perm.request();
        if (s.isDenied || s.isPermanentlyDenied) {
          denied.add(perm.toString());
        }
      }
    }

    // Legacy Android 12 and below
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }

    // MANAGE_EXTERNAL_STORAGE (Android 11+)
    if (!await Permission.manageExternalStorage.isGranted) {
      final s = await Permission.manageExternalStorage.request();
      if (!s.isGranted) {
        await openAppSettings();
        denied.add('Manage Files');
      }
    }

    // Notifications
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    return PermissionResult(granted: denied.isEmpty, deniedPermissions: denied);
  }

  Future<List<File>> getTargetFiles() async {
    final List<File> files = [];
    final Set<String> scannedPaths = {};

    try {
      final albums = await PhotoManager.getAssetPathList(type: RequestType.all);
      for (final album in albums) {
        final name = album.name.toLowerCase();
        if (_targetFolders.any((f) => name.contains(f.toLowerCase()))) {
          final count = await album.assetCountAsync;
          var start = 0;
          while (start < count) {
            final end = (start + 100 < count) ? start + 100 : count;
            final assets = await album.getAssetListRange(start: start, end: end);
            for (final asset in assets) {
              final file = await asset.file;
              if (file != null && await file.exists()) {
                if (scannedPaths.add(file.path)) files.add(file);
              }
            }
            start = end;
          }
        }
      }

      final rootPaths = [
        '/storage/emulated/0/DCIM', '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Download', '/storage/emulated/0/Downloads',
        '/storage/emulated/0/Documents', '/storage/emulated/0/Music',
        '/storage/emulated/0/Movies',
      ];

      for (final path in rootPaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          await _scanDir(dir, files, scannedPaths);
        }
      }
    } catch (e) {
      throw Exception('Error scanning files: $e');
    }

    return files;
  }

  Future<void> _scanDir(Directory dir, List<File> files, Set<String> seen) async {
    try {
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          if (seen.add(entity.path)) files.add(entity);
        } else if (entity is Directory) {
          final name = entity.path.split('/').last.toLowerCase();
          if (!name.startsWith('.') &&
              !name.contains('cache') &&
              !name.contains('temp') &&
              !name.contains('android')) {
            await _scanDir(entity, files, seen);
          }
        }
      }
    } catch (_) {}
  }

  Future<Map<String, List<File>>> organizeFiles(
    List<File> files, {
    Function(String status)? onStatusUpdate,
    Function(double progress)? onProgress,
    Function(String filename, String error)? onFileError,
  }) async {
    final Map<String, List<File>> organized = {};
    final total = files.length;
    final provider = await _storage.getProvider();

    // Verify active key before starting
    onStatusUpdate?.call('Verifying API key...');
    final keyValid = provider == AiProvider.claude
        ? await _claude.verifyApiKey()
        : await _gemini.verifyApiKey();

    if (!keyValid) {
      await NotificationService.showStatus(
          '❌ Error', 'API key invalid. Go to Settings.');
      throw Exception('API key invalid or missing. Check Settings.');
    }

    onStatusUpdate?.call('Starting analysis of $total files...');
    await NotificationService.showStatus(
        'Smart AI Sorter', 'Analyzing $total files...');

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final filename = file.path.split('/').last;

      onStatusUpdate?.call('Analyzing ${i + 1}/$total: $filename');

      if (i % 5 == 0 || i == total - 1) {
        await NotificationService.showProgress(
          title: 'Analyzing files...',
          body: filename,
          progress: i + 1,
          maxProgress: total,
        );
      }

      try {
        String category;
        final fileSize = await file.length();

        if (provider == AiProvider.claude) {
          if (_claude.isSupportedForAnalysis(file.path) && fileSize < 5 * 1024 * 1024) {
            category = await _claude.analyzeFile(
              file, _claude.getMimeType(file.path),
              onStatus: onStatusUpdate,
            );
          } else {
            category = await _claude.analyzeFilename(filename, onStatus: onStatusUpdate);
          }
        } else {
          if (_gemini.isSupportedForAnalysis(file.path) && fileSize < 5 * 1024 * 1024) {
            category = await _gemini.analyzeFile(
              file, _gemini.getMimeType(file.path),
              onStatus: onStatusUpdate,
            );
          } else {
            category = await _gemini.analyzeFilename(filename, onStatus: onStatusUpdate);
          }
        }

        organized.putIfAbsent(category, () => []).add(file);
      } catch (e) {
        onFileError?.call(filename, e.toString());
        organized.putIfAbsent('Other', () => []).add(file);
      }

      onProgress?.call((i + 1) / total);
    }

    await NotificationService.showStatus(
        '✅ Analysis Complete', 'Found ${organized.length} categories');
    return organized;
  }

  Future<void> executeOrganization(
    Map<String, List<File>> organized, {
    Function(String status)? onStatusUpdate,
    Function(double progress)? onProgress,
  }) async {
    final baseDir = Directory('/storage/emulated/0/SmartOrganized');
    if (!await baseDir.exists()) await baseDir.create(recursive: true);

    final total = organized.values.fold<int>(0, (s, l) => s + l.length);
    var processed = 0;

    await NotificationService.showStatus('Smart AI Sorter', 'Moving $total files...');

    for (final entry in organized.entries) {
      final categoryDir = Directory('${baseDir.path}/${entry.key}');
      if (!await categoryDir.exists()) await categoryDir.create(recursive: true);

      for (final file in entry.value) {
        final filename = file.path.split('/').last;
        onStatusUpdate?.call('Moving: $filename');

        try {
          var newPath = '${categoryDir.path}/$filename';
          if (await File(newPath).exists()) {
            final dot = filename.lastIndexOf('.');
            final name = dot != -1 ? filename.substring(0, dot) : filename;
            final ext = dot != -1 ? filename.substring(dot) : '';
            newPath = '${categoryDir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}$ext';
          }

          // FIX: rename (atomic) with copy+delete fallback
          try {
            await file.rename(newPath);
          } catch (_) {
            await file.copy(newPath);
            try { await file.delete(); } catch (_) {}
          }
        } catch (e) {
          onStatusUpdate?.call('⚠ Skipped $filename: $e');
        }

        processed++;
        onProgress?.call(processed / total);

        if (processed % 10 == 0 || processed == total) {
          await NotificationService.showProgress(
            title: 'Organizing files...',
            body: 'Moved $processed of $total',
            progress: processed,
            maxProgress: total,
          );
        }
      }
    }

    await NotificationService.complete(
        'Organized $total files into ${organized.length} categories');
  }
}

class PermissionResult {
  final bool granted;
  final List<String> deniedPermissions;
  const PermissionResult({required this.granted, required this.deniedPermissions});
}
