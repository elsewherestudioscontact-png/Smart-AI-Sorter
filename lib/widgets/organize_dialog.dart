import 'dart:io';
import 'package:flutter/material.dart';
import '../services/file_organizer_service.dart';

class OrganizeDialog extends StatefulWidget {
  final List<File> files;

  const OrganizeDialog({super.key, required this.files});

  @override
  State<OrganizeDialog> createState() => _OrganizeDialogState();
}

class _OrganizeDialogState extends State<OrganizeDialog> {
  bool _isAnalyzing = true;
  bool _isOrganizing = false;
  Map<String, List<String>> _preview = {};
  double _progress = 0.0;
  String _status = 'Starting analysis...';

  @override
  void initState() {
    super.initState();
    _analyzeFiles();
  }

  Future<void> _analyzeFiles() async {
    final organizer = FileOrganizerService();

    try {
      final result = await organizer.organizeFiles(
        widget.files,
        onStatusUpdate: (status) => setState(() => _status = status),
        onProgress: (p) => setState(() => _progress = p),
      );

      final Map<String, List<String>> display = {};
      result.forEach((key, value) {
        display[key] = value.map((f) => f.path.split('/').last).toList();
      });

      setState(() {
        _preview = display;
        _isAnalyzing = false;
        _status = 'Ready to organize';
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _status = 'Error: ' + e.toString();
      });
    }
  }

  Future<void> _executeOrganization() async {
    setState(() {
      _isOrganizing = true;
      _status = 'Moving files...';
    });

    try {
      final organizer = FileOrganizerService();
      final result = await organizer.organizeFiles(widget.files);

      await organizer.executeOrganization(
        result,
        onStatusUpdate: (status) => setState(() => _status = status),
        onProgress: (p) => setState(() => _progress = p),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Done! Check /SmartOrganized folder'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() {
        _isOrganizing = false;
        _status = 'Error: ' + e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('AI Preview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                if (!_isAnalyzing && !_isOrganizing)
                  IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),

          if (_isAnalyzing || _isOrganizing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  LinearProgressIndicator(value: _progress, backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF))),
                  const SizedBox(height: 12),
                  Text(_status, style: TextStyle(color: Colors.white.withOpacity(0.7))),
                  Text('${(_progress * 100).toInt()}%', style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
                ],
              ),
            ),

          Expanded(
            child: _isAnalyzing 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : _buildPreviewList(),
          ),

          if (!_isAnalyzing && !_isOrganizing)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white30)),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _executeOrganization,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white),
                      child: const Text('Confirm Organization'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewList() {
    if (_preview.isEmpty) {
      return const Center(child: Text('Nothing to organize', style: TextStyle(color: Colors.white54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _preview.length,
      itemBuilder: (context, index) {
        final category = _preview.keys.elementAt(index);
        final files = _preview[category]!;

        return Card(
          color: Colors.white.withOpacity(0.05),
          child: ExpansionTile(
            collapsedIconColor: Colors.white70,
            iconColor: const Color(0xFF6C63FF),
            title: Text(category, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('${files.length} files', style: TextStyle(color: Colors.white.withOpacity(0.6))),
            children: files.map((f) => ListTile(
              title: Text(f, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
              dense: true,
            )).toList(),
          ),
        );
      },
    );
  }
}
