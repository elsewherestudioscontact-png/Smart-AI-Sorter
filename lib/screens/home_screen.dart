import 'dart:io';
import 'package:flutter/material.dart';
import '../services/file_organizer_service.dart';
import '../services/secure_storage_service.dart';
import '../widgets/organize_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _organizer = FileOrganizerService();
  final _storage = SecureStorageService();
  int _fileCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _countFiles();
  }

  Future<void> _countFiles() async {
    setState(() => _isLoading = true);
    try {
      final files = await _organizer.getTargetFiles();
      setState(() => _fileCount = files.length);
    } catch (e) {
      print('Count error: ' + e.toString());
    }
    setState(() => _isLoading = false);
  }

  Future<void> _startOrganization() async {
    setState(() => _isLoading = true);

    try {
      await _organizer.requestPermissions();
      final files = await _organizer.getTargetFiles();

      if (files.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No files found')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => OrganizeDialog(files: files),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ' + e.toString())),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: const Text('Smart AI Sorter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9D4EDD)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.folder_open, color: Colors.white, size: 40),
                      SizedBox(width: 12),
                      Icon(Icons.subdirectory_arrow_right, color: Colors.white54, size: 24),
                      Text('Recursive Scan', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _fileCount.toString(),
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Text('Files Found (including subfolders)', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Categories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCategoryChip('Work', Icons.work, Color(0xFF6C63FF)),
                _buildCategoryChip('Personal', Icons.person, Color(0xFF00B4D8)),
                _buildCategoryChip('Finance', Icons.account_balance_wallet, Color(0xFF2ECC71)),
                _buildCategoryChip('Education', Icons.school, Color(0xFFF39C12)),
                _buildCategoryChip('Entertainment', Icons.movie, Color(0xFFE74C3C)),
                _buildCategoryChip('Travel', Icons.flight, Color(0xFF9B59B6)),
                _buildCategoryChip('Health', Icons.favorite, Color(0xFF1ABC9C)),
                _buildCategoryChip('Shopping', Icons.shopping_bag, Color(0xFFFF6B6B)),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _startOrganization,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome),
                          SizedBox(width: 8),
                          Text('Organize with AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _countFiles,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Refresh File Count'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, IconData icon, Color color) {
    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color.withOpacity(0.2),
      side: BorderSide(color: color.withOpacity(0.3)),
    );
  }
}
