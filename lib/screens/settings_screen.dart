import 'package:flutter/material.dart';
import '../services/secure_storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = SecureStorageService();
  final _geminiCtrl = TextEditingController();
  final _claudeCtrl = TextEditingController();
  bool _obscureGemini = true;
  bool _obscureClaude = true;
  AiProvider _provider = AiProvider.gemini;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _geminiCtrl.dispose();
    _claudeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final gemini = await _storage.getGeminiKey();
    final claude = await _storage.getClaudeKey();
    final prov = await _storage.getProvider();
    setState(() {
      _geminiCtrl.text = gemini ?? '';
      _claudeCtrl.text = claude ?? '';
      _provider = prov;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final gemini = _geminiCtrl.text.trim();
    final claude = _claudeCtrl.text.trim();
    if (gemini.isEmpty && claude.isEmpty) {
      _snack('At least one API key is required');
      return;
    }
    if (gemini.isNotEmpty) await _storage.saveGeminiKey(gemini);
    if (claude.isNotEmpty) await _storage.saveClaudeKey(claude);
    await _storage.saveProvider(_provider);
    _snack('Settings saved', color: Colors.green);
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear all keys?', style: TextStyle(color: Colors.white)),
        content: const Text('You will be returned to setup.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm == true) {
      await _storage.deleteAllKeys();
      if (mounted) Navigator.pushReplacementNamed(context, '/setup');
    }
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Active Provider'),
                  const SizedBox(height: 12),
                  Row(children: [
                    _providerTile('Gemini', 'Free tier', Icons.diamond_outlined, AiProvider.gemini),
                    const SizedBox(width: 12),
                    _providerTile('Claude', '~\$5 credits', Icons.psychology_outlined, AiProvider.claude),
                  ]),

                  const SizedBox(height: 28),
                  _sectionTitle('Gemini API Key'),
                  const SizedBox(height: 8),
                  _keyField(_geminiCtrl, _obscureGemini, 'AIza...',
                      () => setState(() => _obscureGemini = !_obscureGemini)),

                  const SizedBox(height: 20),
                  _sectionTitle('Claude API Key'),
                  const SizedBox(height: 8),
                  _keyField(_claudeCtrl, _obscureClaude, 'sk-ant-...',
                      () => setState(() => _obscureClaude = !_obscureClaude)),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: OutlinedButton(
                      onPressed: _clearAll,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Clear All Keys'),
                    ),
                  ),

                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('About', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _aboutLine('Smart AI Sorter v1.0'),
                      _aboutLine('Powered by Gemini 1.5 Flash / Claude Haiku'),
                      _aboutLine('Built by Elsewhere Studios'),
                    ]),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(color: Colors.white70, fontSize: 12,
          fontWeight: FontWeight.w600, letterSpacing: 0.8));

  Widget _aboutLine(String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13)),
  );

  Widget _keyField(TextEditingController ctrl, bool obscure, String hint, VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
              color: Colors.white38, size: 20),
          onPressed: toggle,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _providerTile(String label, String sub, IconData icon, AiProvider value) {
    final selected = _provider == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _provider = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF6C63FF).withOpacity(0.15) : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFF6C63FF) : Colors.white.withOpacity(0.12),
              width: 1.5,
            ),
          ),
          child: Column(children: [
            Icon(icon, color: selected ? const Color(0xFF6C63FF) : Colors.white38, size: 22),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontWeight: FontWeight.w600,
            )),
            Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}
