import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_splitter/services/video_processor.dart';
import 'package:video_splitter/widgets/loading_overlay.dart';
import 'package:video_splitter/widgets/social_share_buttons.dart';

class SplitVideoScreen extends StatefulWidget {
  const SplitVideoScreen({super.key});

  @override
  SplitVideoScreenState createState() => SplitVideoScreenState();
}

class SplitVideoScreenState extends State<SplitVideoScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _urlController = TextEditingController();
  final VideoProcessor _videoProcessor = VideoProcessor();
  bool _isLoading = false;
  int _parts = 2;
  List<String>? _splitFiles;
  VideoPlayerController? _videoPlayerController;
  String _selectedSource = 'device';
  int _currentPlayingIndex = -1;
  double _splitProgress = 0.0;

  @override
  void dispose() {
    _urlController.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Widget _buildSourceSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Video Source',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Center(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'device',
                    icon: Icon(Icons.folder),
                    label: Text('Device'),
                  ),
                  ButtonSegment(
                    value: 'url',
                    icon: Icon(Icons.link),
                    label: Text('URL'),
                  ),
                ],
                selected: {_selectedSource},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _selectedSource = newSelection.first;
                    _urlController.clear();
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedSource == 'device')
              Column(
                children: [
                  if (_urlController.text.isNotEmpty)
                    Text(
                      'Selected: ${_urlController.text.split('/').last}',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _pickVideoFromDevice,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Select Video'),
                  ),
                ],
              )
            else
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Video URL',
                  hintText: 'Enter video URL to split',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter a URL';
                  }
                  return null;
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Split Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.splitscreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Number of parts: $_parts',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            Slider(
              value: _parts.toDouble(),
              min: 2,
              max: 10,
              divisions: 8,
              label: _parts.toString(),
              onChanged: (value) {
                setState(() {
                  _parts = value.round();
                });
              },
            ),
            const SizedBox(height: 16),
            if (_splitProgress > 0 && _splitProgress < 1)
              Column(
                children: [
                  LinearProgressIndicator(value: _splitProgress),
                  const SizedBox(height: 8),
                  Text(
                    'Progress: ${(_splitProgress * 100).toStringAsFixed(1)}%',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _processSplitVideo,
              icon: const Icon(Icons.cut),
              label: const Text('Split Video'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPartsList() {
    if (_splitFiles == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Split Video Parts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _splitFiles!.length,
              itemBuilder: (context, index) {
                final isPlaying = _currentPlayingIndex == index;
                return Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Text(
                              'Part ${index + 1}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (isPlaying &&
                                _videoPlayerController != null) ...[
                              AspectRatio(
                                aspectRatio:
                                    _videoPlayerController!.value.aspectRatio,
                                child: VideoPlayer(_videoPlayerController!),
                              ),
                              VideoProgressIndicator(
                                _videoPlayerController!,
                                allowScrubbing: true,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  onPressed: () => _playVideo(index),
                                  icon: Icon(
                                    isPlaying ? Icons.pause : Icons.play_arrow,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _downloadFile(_splitFiles![index]),
                                  icon: const Icon(Icons.download),
                                ),
                                IconButton(
                                  onPressed: () => _showSocialUploadOptions(
                                      _splitFiles![index]),
                                  icon: const Icon(Icons.share),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

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
                  _buildSourceSelection(),
                  const SizedBox(height: 16),
                  _buildSplitControls(),
                  const SizedBox(height: 16),
                  _buildVideoPartsList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickVideoFromDevice() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null) {
      setState(() {
        _urlController.text = result.files.single.path!;
      });
    }
  }

  Future<void> _processSplitVideo() async {
    if (_urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a video first')),
      );
      return;
    }

    if (!_formKey.currentState!.validate() && _selectedSource == 'url') return;

    setState(() {
      _isLoading = true;
      _splitProgress = 0.0;
    });

    try {
      String videoPath;
      if (_selectedSource == 'url') {
        videoPath = await _videoProcessor.downloadVideo(_urlController.text);
      } else {
        videoPath = _urlController.text;
      }

      final outputDir = await _videoProcessor.splitVideo(videoPath, _parts);

      if (mounted) {
        setState(() {
          _splitFiles = Directory(outputDir)
              .listSync()
              .map((e) => e.path)
              .toList()
            ..sort(); // Sort to ensure correct order
        });
      }

      if (_selectedSource == 'url') {
        await _videoProcessor.deleteFile(videoPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _playVideo(int index) async {
    if (_currentPlayingIndex == index && _videoPlayerController != null) {
      if (_videoPlayerController!.value.isPlaying) {
        await _videoPlayerController!.pause();
      } else {
        await _videoPlayerController!.play();
      }
      setState(() {});
      return;
    }

    _videoPlayerController?.dispose();

    setState(() {
      _currentPlayingIndex = index;
    });

    _videoPlayerController = VideoPlayerController.file(
      File(_splitFiles![index]),
    );

    try {
      await _videoPlayerController!.initialize();
      await _videoPlayerController!.play();
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing video: $e')),
        );
      }
    }
  }

  Future<void> _downloadFile(String filePath) async {
    setState(() => _isLoading = true);

    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null)
        throw Exception('Could not access storage directory');

      final fileName =
          'split_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final savePath = '${directory.path}/$fileName';

      await File(filePath).copy(savePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video saved to: $savePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving video: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSocialUploadOptions(String videoPath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Upload to Social Media'),
          content: SocialShareButtons(
            videoPath: videoPath,
            onUploadToYouTube: () => _uploadToSocialMedia('YouTube', videoPath),
            onUploadToFacebook: () =>
                _uploadToSocialMedia('Facebook', videoPath),
            onUploadToInstagram: () =>
                _uploadToSocialMedia('Instagram', videoPath),
            onUploadToTikTok: () => _uploadToSocialMedia('TikTok', videoPath),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadToSocialMedia(String platform, String videoPath) async {
    Navigator.of(context).pop(); // Close the dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$platform upload not implemented yet')),
    );
  }
}
