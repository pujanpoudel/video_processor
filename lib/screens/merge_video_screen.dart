import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_splitter/services/video_processor.dart';
import 'package:video_splitter/widgets/loading_overlay.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_splitter/widgets/social_share_buttons.dart';

class MergeVideoScreen extends StatefulWidget {
  const MergeVideoScreen({super.key});

  @override
  MergeVideoScreenState createState() => MergeVideoScreenState();
}

class MergeVideoScreenState extends State<MergeVideoScreen> {
  final _videoProcessor = VideoProcessor();
  final _url1Controller = TextEditingController();
  final _url2Controller = TextEditingController();
  bool _isHorizontal = true;
  bool _isLoading = false;
  bool _isUrlInput1 = false;
  bool _isUrlInput2 = false;
  String? _outputPath;
  VideoPlayerController? _videoPlayerController;
  double _mergeProgress = 0.0;

  @override
  void dispose() {
    _url1Controller.dispose();
    _url2Controller.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Widget _buildVideoSourceToggle(
    String label,
    bool isUrlInput,
    Function(bool) onChanged,
  ) {
    return Row(
      children: [
        Text(label),
        Switch(
          value: isUrlInput,
          onChanged: onChanged,
        ),
        Text(isUrlInput ? 'URL' : 'Local'),
      ],
    );
  }

  Widget _buildVideoInput(
    bool isUrlInput,
    TextEditingController controller,
    String label,
    VoidCallback onPickVideo,
  ) {
    return isUrlInput
        ? TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: '$label URL',
              hintText: 'Enter $label URL',
              border: const OutlineInputBorder(),
            ),
          )
        : Column(
            children: [
              Text('Selected file: ${controller.text.split('/').last}'),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: onPickVideo,
                icon: const Icon(Icons.file_upload),
                label: Text('Select $label from Device'),
              ),
            ],
          );
  }

  Widget _buildMergeControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Merge Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Direction:'),
                const SizedBox(width: 16),
                ToggleButtons(
                  isSelected: [_isHorizontal, !_isHorizontal],
                  onPressed: (index) {
                    setState(() {
                      _isHorizontal = index == 0;
                    });
                  },
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(Icons.horizontal_distribute),
                          SizedBox(width: 8),
                          Text('Horizontal'),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(Icons.vertical_distribute),
                          SizedBox(width: 8),
                          Text('Vertical'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_mergeProgress > 0 && _mergeProgress < 1)
              Column(
                children: [
                  LinearProgressIndicator(value: _mergeProgress),
                  const SizedBox(height: 8),
                  Text(
                      'Progress: ${(_mergeProgress * 100).toStringAsFixed(1)}%'),
                  const SizedBox(height: 16),
                ],
              ),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _processMergeVideos,
              icon: const Icon(Icons.merge_type),
              label: const Text('Merge Videos'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    if (_outputPath == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Preview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: _videoPlayerController?.value.aspectRatio ?? 16 / 9,
              child: _videoPlayerController != null
                  ? VideoPlayer(_videoPlayerController!)
                  : const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () {
                    if (_videoPlayerController != null) {
                      setState(() {
                        _videoPlayerController!.value.isPlaying
                            ? _videoPlayerController!.pause()
                            : _videoPlayerController!.play();
                      });
                    }
                  },
                  icon: Icon(
                    _videoPlayerController?.value.isPlaying ?? false
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                ),
                IconButton(
                  onPressed: _downloadMergedVideo,
                  icon: const Icon(Icons.download),
                ),
                IconButton(
                  onPressed: () => _showSocialUploadOptions(_outputPath!),
                  icon: const Icon(Icons.share),
                ),
              ],
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
        title: const Text('Merge Videos'),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildVideoSourceToggle(
                          'First Video Source:',
                          _isUrlInput1,
                          (value) => setState(() => _isUrlInput1 = value),
                        ),
                        const SizedBox(height: 16),
                        _buildVideoInput(
                          _isUrlInput1,
                          _url1Controller,
                          'First Video',
                          _pickFirstVideo,
                        ),
                        const SizedBox(height: 24),
                        _buildVideoSourceToggle(
                          'Second Video Source:',
                          _isUrlInput2,
                          (value) => setState(() => _isUrlInput2 = value),
                        ),
                        const SizedBox(height: 16),
                        _buildVideoInput(
                          _isUrlInput2,
                          _url2Controller,
                          'Second Video',
                          _pickSecondVideo,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildMergeControls(),
                const SizedBox(height: 16),
                _buildVideoPreview(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFirstVideo() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null) {
      setState(() {
        _url1Controller.text = result.files.single.path!;
      });
    }
  }

  Future<void> _pickSecondVideo() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null) {
      setState(() {
        _url2Controller.text = result.files.single.path!;
      });
    }
  }

  Future<void> _processMergeVideos() async {
    if (_url1Controller.text.isEmpty || _url2Controller.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both videos')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _mergeProgress = 0.0;
    });

    try {
      final outputPath = await _videoProcessor.mergeVideos(
        [_url1Controller.text, _url2Controller.text],
        _isHorizontal,
        (progress) {
          if (mounted) {
            setState(() {
              _mergeProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _outputPath = outputPath;
        });
        await _initializeVideoPlayer(outputPath);
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

  Future<void> _initializeVideoPlayer(String videoPath) async {
    _videoPlayerController?.dispose();
    _videoPlayerController = VideoPlayerController.file(File(videoPath));

    try {
      await _videoPlayerController!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing video player: $e')),
        );
      }
    }
  }

  Future<void> _downloadMergedVideo() async {
    if (_outputPath == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null)
        throw Exception('Could not access storage directory');

      final fileName =
          'merged_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final savePath = '${directory.path}/$fileName';

      await File(_outputPath!).copy(savePath);

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
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$platform upload not implemented yet')),
    );
  }
}
