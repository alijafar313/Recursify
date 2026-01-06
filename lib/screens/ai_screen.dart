import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  final _apiKeyController = TextEditingController();
  String _result = '';
  bool _isLoading = false;
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('gemini_api_key');
    if (key != null && key.isNotEmpty) {
      _apiKeyController.text = key;
      setState(() => _hasKey = true);
    }
  }

  Future<void> _saveKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', key);
    setState(() => _hasKey = true);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API Key Saved!')),
    );
  }

  Future<void> _analyze() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an API Key first.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final service = AIService(key);
      final analysis = await service.analyzeMoods();
      if (!mounted) return;
      setState(() {
        _result = analysis;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Insights (Gemini)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              setState(() => _hasKey = false);
            },
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (!_hasKey)
                Card(
                  color: Colors.blue.shade50,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Setup Gemini API',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text('Get a free key from aistudio.google.com'),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _apiKeyController,
                          decoration: const InputDecoration(
                            labelText: 'Paste API Key Here',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _saveKey,
                          child: const Text('Save Key'),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_hasKey && _result.isEmpty && !_isLoading)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.psychology, size: 64, color: Colors.indigo),
                        const SizedBox(height: 16),
                        const Text(
                          'Ready to analyze your patterns.',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _analyze,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Analyze My Week'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_isLoading)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Gemini is thinking...'),
                      ],
                    ),
                  ),
                ),

              if (_result.isNotEmpty)
                Expanded(
                  child: Markdown(
                    data: _result,
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
