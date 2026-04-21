import 'dart:io';
import 'package:flutter/material.dart';
import '../services/file_organizer_service.dart';
import '../services/gemini_service.dart';
import '../services/claude_service.dart';
import '../services/secure_storage_service.dart';

class OrganizeDialog extends StatefulWidget {
  final List<File> files;

  const OrganizeDialog({super.key, required this.files});

  @override
  State<OrganizeDialog> createState() => _OrganizeDialogState();
}

class _OrganizeDialogState extends State<OrganizeDialog> {
  bool _isAnalyzing = true;
  bool _isOrganizing = false;
  // Store the result so executeOrganization reuses it (not re-analyzed)
  Map<String, List<File>> _organizedFiles = {};
  Map<String, List<String>> _preview = {};
  double _progress = 0.0;
  String _status = 'Checking API key...';
  bool _apiKeyValid = false;
  final List<String> _errors = [];
  int _errorCount = 0;

  @override
  void initState() {
    super.initState();
    _checkAndAnalyze();
  }

  Future<void> _checkAndAnalyze() async {
    final storage = SecureStorageService();
    final provider = await storage.getProvider();

    bool valid;
    if (provider == AiProvider.claude) {
      valid = await ClaudeService().verifyApiKey();
    } else {
      valid = await GeminiService().verifyApiKey();
    }

    setState(() => _apiKeyValid = valid);

    if (!valid) {
      setState(() {
        _isAnalyzing = false;
        _status = '❌ API key invalid. Go to Settings to update.';
      });
      return;
    }

    setState(() => _status = '✅ Key valid. Starting analysis...');
    await _analyzeFiles();
  }

  Future<void> _analyzeFiles() async {
    final organizer = FileOrganizerService();
    try {
      final result = await organizer.organizeFiles(
        widget.files,
        onStatusUpdate: (s) => setState(() => _status = s),
        onProgress: (p) => setState(() => _progress = p),
        onFileError: (filename, error) {
          setState(() {
            _errorCount++;
            if (_errors.length < 5) _errors.add('$filename: $error');
          });
        },
      );

      final display = <String, List<String>>{};
      result.forEach((k, v) {
        display[k] = v.map((f) => f.path.split('/').last).toList();
      });

      setState(() {
        _organizedFiles = result;
        _preview = display;
        _isAnalyzing = false;
        _status = _errorCount > 0
            ? '⚠ Done — $_errorCount file(s) failed analysis (bucketed to Other)'
            : '✅ Analysis complete. Ready to organize.';
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _status = '❌ Error: $e';
      });
    }
  }

  Future<void> _executeOrganization() async {
    setState(() {
      _isOrganizing = true;
      _status = 'Moving files...';
      _progress = 0;
    });

    try {
      final organizer = FileOrganizerService();
      // FIX: reuse already-analyzed result, don't re-analyze
      await organizer.executeOrganization(
        _organizedFiles,
        onStatusUpdate: (s) => setState(() => _status = s),
        onProgress: (p) => setState(() => _progress = p),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Done! Check /SmartOrganized folder'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isOrganizing = false;
        _status = '❌ Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('AI Preview',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                if (!_isAnalyzing && !_isOrganizing)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
          ),

          // Invalid key banner
          if (!_apiKeyValid && !_isAnalyzing)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('API Key Invalid',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('Go to Settings and enter a valid API key',
                        style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12)),
                  ])),
                ]),
              ),
            ),

          // Progress bar
          if (_isAnalyzing || _isOrganizing)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(_status,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                Text('${(_progress * 100).toInt()}%',
                    style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
              ]),
            ),

          // Error summary
          if (!_isAnalyzing && _errorCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text('$_errorCount file(s) failed — bucketed to Other',
                        style: const TextStyle(color: Colors.orange, fontSize: 12))),
                  ]),
                  ..._errors.map((e) => Text('• $e',
                      style: TextStyle(color: Colors.orange.withOpacity(0.7), fontSize: 11))),
                  if (_errorCount > 5)
                    Text('... and ${_errorCount - 5} more',
                        style: TextStyle(color: Colors.orange.withOpacity(0.5), fontSize: 11)),
                ]),
              ),
            ),

          Expanded(
            child: _isAnalyzing
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const CircularProgressIndicator(color: Color(0xFF6C63FF)),
                    const SizedBox(height: 16),
                    Text(_status, style: TextStyle(color: Colors.white.withOpacity(0.7))),
                  ]))
                : _buildPreviewList(),
          ),

          if (!_isAnalyzing && !_isOrganizing && _apiKeyValid)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(flex: 2,
                  child: ElevatedButton(
                    onPressed: _preview.isEmpty ? null : _executeOrganization,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewList() {
    if (_preview.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.folder_open, size: 48, color: Colors.white.withOpacity(0.3)),
        const SizedBox(height: 16),
        Text('No files to organize', style: TextStyle(color: Colors.white.withOpacity(0.5))),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _preview.length,
      itemBuilder: (context, index) {
        final category = _preview.keys.elementAt(index);
        final files = _preview[category]!;
        return Card(
          color: Colors.white.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            collapsedIconColor: Colors.white70,
            iconColor: const Color(0xFF6C63FF),
            title: Text(category,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('${files.length} file${files.length == 1 ? '' : 's'}',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            children: files.map((f) => ListTile(
              dense: true,
              title: Text(f,
                  style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12)),
            )).toList(),
          ),
        );
      },
    );
  }
}
