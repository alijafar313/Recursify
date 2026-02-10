import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/ai_service.dart';

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  String _result = '';
  bool _isLoading = false;

  Future<void> _analyze() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final service = AIService();
      final analysis = await service.analyzeData();
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
        title: const Text('AI Analysis'),
        backgroundColor: Colors.transparent, // Modern look
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_result.isEmpty && !_isLoading)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.psychology_alt, size: 80, color: Colors.indigoAccent),
                        const SizedBox(height: 24),
                        const Text(
                          'Unlock Your Insights',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                         const SizedBox(height: 8),
                        const Text(
                          'Analyze your mood, sleep, and habits\nto find hidden patterns.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 40),
                        ElevatedButton.icon(
                          onPressed: _analyze,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Generate Report'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            textStyle: const TextStyle(fontSize: 18),
                            backgroundColor: Colors.indigoAccent,
                            foregroundColor: Colors.white,
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
                        CircularProgressIndicator(color: Colors.indigoAccent),
                        SizedBox(height: 24),
                        Text('Analyzing your data...', style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ),

              if (_result.isNotEmpty)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Markdown(
                      data: _result,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),

              if (_result.isNotEmpty && !_isLoading)
                 Padding(
                   padding: const EdgeInsets.only(top: 16),
                   child: TextButton.icon(
                      onPressed: _analyze,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Regenerate Analysis'),
                   ),
                 ),
            ],
          ),
        ),
      ),
    );
  }
}
