import 'package:flutter/material.dart';

class SplitVideoScreen extends StatefulWidget {
  const SplitVideoScreen({Key? key}) : super(key: key);

  @override
  _SplitVideoScreenState createState() => _SplitVideoScreenState();
}

class _SplitVideoScreenState extends State<SplitVideoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  int _parts = 2;
  bool _isLoading = false;
  String? _outputPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Video'),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Video URL',
                      hintText: 'Enter video URL to split',
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Please enter a URL';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Number of parts: $_parts'),
                      ),
                      Slider(
                        value: _parts.toDouble(),
                        min: 2,
                        max: 10,
                        divisions: 8,
                        onChanged: (value) {
                          setState(() {
                            _parts = value.round();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _processSplitVideo,
                    child: const Text('Split Video'),
                  ),
                  if (_outputPath != null) ...[
                    const SizedBox(height: 24),
                    const Text('Share on:'),
                    const SizedBox(height: 8),
                    SocialShareButtons(videoPath: _outputPath!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _processSplitVideo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final outputPath = await VideoProcessor().splitVideo(
        _urlController.text,
        _parts,
      );

      setState(() {
        _outputPath = outputPath;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
