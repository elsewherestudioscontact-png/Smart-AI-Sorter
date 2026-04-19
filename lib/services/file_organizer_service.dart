import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'gemini_service.dart';

class FileOrganizerService {
  final GeminiService _gemini = GeminiService();

  // Target base folders - will scan these AND all subfolders
  static const List<String> _targetFolders = [
    'DCIM', 'Pictures', 'Download', 'Downloads', 'Documents', 'Music', 'Movies'
  ];

  Future<bool> requestPermissions() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
    return true;
  }

  Future<List<File>> getTargetFiles() async {
    final List<File> files = [];
    final Set<String> scannedPaths = {}; // Prevent duplicates

    try {
      // Method 1: Get files from Photo Manager (Gallery)
      final albums = await PhotoManager.getAssetPathList(type: RequestType.all);

      for (final album in albums) {
        final name = album.name.toLowerCase();
        if (_targetFolders.any((f) => name.contains(f.toLowerCase()))) {
          final count = await album.assetCountAsync;
          var start = 0;
          const batchSize = 100;

          while (start < count) {
            final end = (start + batchSize < count) ? start + batchSize : count;
            final assets = await album.getAssetListRange(start: start, end: end);

            for (final asset in assets) {
              final file = await asset.file;
              if (file != null && await file.exists()) {
                final path = file.path;
                if (!scannedPaths.contains(path)) {
                  scannedPaths.add(path);
                  files.add(file);
                }
              }
            }
            start = end;
          }
        }
      }

      // Method 2: Recursive filesystem scan for ALL files in target directories
      final rootPaths = [
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Movies',
      ];

      for (final rootPath in rootPaths) {
        final dir = Directory(rootPath);
        if (await dir.exists()) {
          await _scanDirectoryRecursively(dir, files, scannedPaths);
        }
      }

    } catch (e) {
      print('Error scanning files: ' + e.toString());
    }

    return files;
  }

  /// Recursively scan a directory and all subdirectories
  Future<void> _scanDirectoryRecursively(
    Directory dir, 
    List<File> files, 
    Set<String> scannedPaths
  ) async {
    try {
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          final path = entity.path;
          if (!scannedPaths.contains(path)) {
            scannedPaths.add(path);
            files.add(entity);
          }
        } else if (entity is Directory) {
          final dirName = entity.path.split('/').last.toLowerCase();
          // Skip system folders
          if (!dirName.startsWith('.') && 
              !dirName.contains('cache') && 
              !dirName.contains('temp') &&
              !dirName.contains('android')) {
            await _scanDirectoryRecursively(entity, files, scannedPaths);
          }
        }
      }
    } catch (e) {
      print('Cannot access ' + dir.path + ': ' + e.toString());
    }
  }

  Future<Map<String, List<File>>> organizeFiles(
    List<File> files, {
    Function(String status)? onStatusUpdate,
    Function(double progress)? onProgress,
  }) async {
    final Map<String, List<File>> organized = {};
    final total = files.length;

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final filename = file.path.split('/').last;

      onStatusUpdate?.call('Analyzing ' + (i + 1).toString() + '/' + total.toString() + ': ' + filename);

      try {
        String category;
        final mimeType = _gemini.getMimeType(file.path);
        final fileSize = await file.length();

        // Only analyze content for small supported files
        if (_gemini.isSupportedForAnalysis(file.path) && fileSize < 5 * 1024 * 1024) {
          category = await _gemini.analyzeFile(file, mimeType);
        } else {
          category = await _gemini.analyzeFilename(filename);
        }

        organized.putIfAbsent(category, () => []);
        (organized[category] ??= []).add(file);

      } catch (e) {
        print('Analysis error for ' + filename + ': ' + e.toString());
        organized.putIfAbsent('Other', () => []);
        organized['Other']!.add(file);
      }

      onProgress?.call((i + 1) / total);
    }

    return organized;
  }

  Future<void> executeOrganization(
    Map<String, List<File>> organized, {
    Function(String status)? onStatusUpdate,
    Function(double progress)? onProgress,
  }) async {
    final baseDir = Directory('/storage/emulated/0/SmartOrganized');
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    final total = organized.values.fold<int>(0, (sum, list) => sum + list.length);
    var processed = 0;

    for (final entry in organized.entries) {
      final category = entry.key;
      final files = entry.value;

      final categoryDir = Directory(baseDir.path + '/' + category);
      if (!await categoryDir.exists()) {
        await categoryDir.create(recursive: true);
      }

      for (final file in files) {
        final filename = file.path.split('/').last;
        onStatusUpdate?.call('Moving: ' + filename);

        try {
          final newPath = categoryDir.path + '/' + filename;

          if (await File(newPath).exists()) {
            final name = filename.contains('.') 
                ? filename.substring(0, filename.lastIndexOf('.')) 
                : filename;
            final ext = filename.contains('.') ? filename.substring(filename.lastIndexOf('.')) : '';
            final uniquePath = categoryDir.path + '/' + name + '_' + DateTime.now().millisecondsSinceEpoch.toString() + ext;
            await file.copy(uniquePath);
          } else {
            await file.copy(newPath);
          }

          try { await file.delete(); } catch (_) {}

        } catch (e) {
          print('Move error: ' + e.toString());
        }

        processed++;
        onProgress?.call(processed / total);
      }
    }
  }
}
