import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/file_organizer_service.dart';
import 'services/secure_storage_service.dart';

final fileOrganizerProvider = Provider((ref) => FileOrganizerService());
final secureStorageProvider = Provider((ref) => SecureStorageService());
