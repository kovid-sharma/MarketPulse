import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';

class ManualEntryScreen extends ConsumerStatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  ConsumerState<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends ConsumerState<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _headlineCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _sourceCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _headlineCtrl.dispose();
    _contentCtrl.dispose();
    _sourceCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(apiClientProvider).submitManualArticle(
            headline: _headlineCtrl.text.trim(),
            content: _contentCtrl.text.trim().isEmpty
                ? null
                : _contentCtrl.text.trim(),
            source:
                _sourceCtrl.text.trim().isEmpty ? null : _sourceCtrl.text.trim(),
            url: _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
          );
      if (mounted) {
        _headlineCtrl.clear();
        _contentCtrl.clear();
        _sourceCtrl.clear();
        _urlCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '✓ Article submitted and queued for AI processing'),
            backgroundColor: Color(0xFF00C851),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed: $e'),
              backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0D1A),
        elevation: 0,
        title: const Text('Manual Article Entry',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Submitted articles will go through the full AI pipeline '
                        '(finance filter → classifier → impact → enrichment).',
                        style: TextStyle(
                            color: Color(0xFF10B981), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _FieldLabel('Headline *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _headlineCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: _inputDecoration('Enter article headline...'),
                validator: (v) =>
                    v != null && v.trim().isNotEmpty ? null : 'Required',
              ),
              const SizedBox(height: 20),
              _FieldLabel('Content / Summary'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 6,
                decoration: _inputDecoration('Paste article body or summary...'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel('Source'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _sourceCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('e.g. Economic Times'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _FieldLabel('Article URL'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _urlCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.url,
                decoration: _inputDecoration('https://...'),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isSubmitting ? 'Submitting...' : 'Submit to Pipeline',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF4B5563)),
      filled: true,
      fillColor: const Color(0xFF1A1D2E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2A2D3E)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2A2D3E)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFB0B3C6),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
