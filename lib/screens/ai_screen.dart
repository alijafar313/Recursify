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
  // TODO: For production, move this to a backend (Firebase Functions)!
  static const _hardcodedKey = 'AIzaSyBJc-uNFyifPYUrqG-vg0hKLjDuHMG8gXQ';
  
  final _apiKeyController = TextEditingController();
  String _result = '';
  bool _isLoading = false;
  bool _hasKey = true; // Default to true since we have a hardcoded key

  @override
  void initState() {
    super.initState();
    // We don't need to load from prefs for this prototype anymore
  }

  Future<void> _analyze() async {
    // Use hardcoded key
    const key = _hardcodedKey;

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
              // Toggle key input visibility logic could go here
              // For now we just show it at top
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
              // Input card removed for MVP since key is hardcoded.
              
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
