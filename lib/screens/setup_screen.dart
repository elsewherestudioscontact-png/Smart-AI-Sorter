import 'package:flutter/material.dart';
import '../services/secure_storage_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _geminiController = TextEditingController();
  final _claudeController = TextEditingController();
  bool _obscureGemini = true;
  bool _obscureClaude = true;
  AiProvider _provider = AiProvider.gemini;
  bool _saving = false;

  @override
  void dispose() {
    _geminiController.dispose();
    _claudeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final gemini = _geminiController.text.trim();
    final claude = _claudeController.text.trim();

    if (gemini.isEmpty && claude.isEmpty) {
      _snack('Enter at least one API key');
      return;
    }
    if (_provider == AiProvider.gemini && gemini.isEmpty) {
      _snack('Enter your Gemini key to use Gemini');
      return;
    }
    if (_provider == AiProvider.claude && claude.isEmpty) {
      _snack('Enter your Claude key to use Claude');
      return;
    }

    setState(() => _saving = true);
    final storage = SecureStorageService();
    if (gemini.isNotEmpty) await storage.saveGeminiKey(gemini);
    if (claude.isNotEmpty) await storage.saveClaudeKey(claude);
    await storage.saveProvider(_provider);

    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF9D4EDD)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.auto_awesome, size: 36, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text('Smart AI Sorter',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 6),
              Text('Add your AI key to get started',
                  style: TextStyle(color: Colors.white.withOpacity(0.55))),
              const SizedBox(height: 36),

              _label(Icons.diamond_outlined, 'Gemini API Key', 'Free tier — aistudio.google.com'),
              const SizedBox(height: 8),
              _keyField(_geminiController, _obscureGemini, 'AIza...',
                  () => setState(() => _obscureGemini = !_obscureGemini)),

              const SizedBox(height: 24),
              _label(Icons.psychology_outlined, 'Claude API Key',
                  '~\$5 free credits — console.anthropic.com'),
              const SizedBox(height: 8),
              _keyField(_claudeController, _obscureClaude, 'sk-ant-...',
                  () => setState(() => _obscureClaude = !_obscureClaude)),

              const SizedBox(height: 28),
              Text('Active provider',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(children: [
                _chip('Gemini', Icons.diamond_outlined, AiProvider.gemini),
                const SizedBox(width: 12),
                _chip('Claude', Icons.psychology_outlined, AiProvider.claude),
              ]),

              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Get Started',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(IconData icon, String title, String sub) => Row(children: [
    Icon(icon, color: const Color(0xFF6C63FF), size: 18),
    const SizedBox(width: 8),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
    ]),
  ]);

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

  Widget _chip(String label, IconData icon, AiProvider value) {
    final selected = _provider == value;
    return GestureDetector(
      onTap: () => setState(() => _provider = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6C63FF).withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF6C63FF) : Colors.white.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: selected ? const Color(0xFF6C63FF) : Colors.white54),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          )),
        ]),
      ),
    );
  }
}
