import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_splitter/services/video_downloader.dart';
import 'package:video_splitter/widgets/loading_overlay.dart';
import 'package:video_splitter/widgets/social_share_buttons.dart';

class MergeVideoScreen extends StatefulWidget {
  const MergeVideoScreen({super.key});

  @override
  State<MergeVideoScreen> createState() => _MergeVideoScreenState();
}

class _MergeVideoScreenState extends State<MergeVideoScreen> {
  final _socialDownloader = SocialVideoDownloader();
  final _url1Controller = TextEditingController();
  final _url2Controller = TextEditingController();

  VideoPlayerController? _previewController1;
  VideoPlayerController? _previewController2;
  VideoPlayerController? _outputController;

  bool _isHorizontal = true;
  bool _isLoading = false;
  bool _isUrlInput1 = false;
  bool _isUrlInput2 = false;
  bool _showDownloads = false;

  String? _outputPath;
  String? _errorMessage;

  double _mergeProgress = 0.0;
  List<String> _downloadedVideos = [];
  final Map<String, double> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    _loadDownloadedVideos();
  }

  @override
  void dispose() {
    _url1Controller.dispose();
    _url2Controller.dispose();
    _previewController1?.dispose();
    _previewController2?.dispose();
    _outputController?.dispose();
    super.dispose();
  }

  Future<void> _loadDownloadedVideos() async {
    try {
      final directory = Directory('/storage/emulated/0/Download');
      if (await directory.exists()) {
        final files = await directory
            .list()
            .where((entity) => entity.path.toLowerCase().endsWith('.mp4'))
            .map((e) => e.path)
            .toList();
        setState(() => _downloadedVideos = files);
      }
    } catch (e) {
      debugPrint('Error loading downloaded videos: $e');
    }
  }

  Widget _buildVideoSection(bool isFirstVideo) {
    final controller = isFirstVideo ? _previewController1 : _previewController2;
    final urlController = isFirstVideo ? _url1Controller : _url2Controller;
    final isUrlInput = isFirstVideo ? _isUrlInput1 : _isUrlInput2;

    return Card(
      color: isFirstVideo ? Colors.blue.shade50 : Colors.blue.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSourceToggle(isFirstVideo),
            const SizedBox(height: 16),
            if (controller?.value.isInitialized ?? false)
              _buildVideoPreview(controller!, urlController.text, isFirstVideo)
            else
              _buildVideoInput(isUrlInput, urlController, isFirstVideo),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceToggle(bool isFirstVideo) {
    return Row(
      children: [
        Text('${isFirstVideo ? "First" : "Second"} Video Source:'),
        const Spacer(),
        Switch(
          value: isFirstVideo ? _isUrlInput1 : _isUrlInput2,
          onChanged: (value) => setState(() {
            if (isFirstVideo) {
              _isUrlInput1 = value;
            } else {
              _isUrlInput2 = value;
            }
          }),
        ),
        Text(isFirstVideo
            ? (_isUrlInput1 ? 'URL' : 'File')
            : (_isUrlInput2 ? 'URL' : 'File')),
      ],
    );
  }

  Widget _buildVideoPreview(
      VideoPlayerController controller, String path, bool isFirstVideo) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
            IconButton(
              icon: Icon(
                controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 48,
              ),
              onPressed: () {
                setState(() {
                  controller.value.isPlaying
                      ? controller.pause()
                      : controller.play();
                });
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => _clearVideo(isFirstVideo),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          path.split('/').last,
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () => _downloadMergedVideo(),
              icon: const Icon(Icons.download),
              label: const Text('Save Video'),
            ),
            ElevatedButton.icon(
              onPressed: () => _showSocialUploadOptions(path),
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ],
        ),
      ],
    );
  }

  void _clearVideo(bool isFirstVideo) {
    setState(() {
      if (isFirstVideo) {
        _previewController1?.dispose();
        _previewController1 = null;
        _url1Controller.clear();
      } else {
        _previewController2?.dispose();
        _previewController2 = null;
        _url2Controller.clear();
      }
    });
  }

  Widget _buildVideoInput(
      bool isUrlInput, TextEditingController controller, bool isFirstVideo) {
    if (isUrlInput) {
      return TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: 'Enter video URL',
          hintText: 'YouTube, TikTok, Instagram, or Facebook URL',
          border: const OutlineInputBorder(),
          errorText: _errorMessage,
        ),
        onChanged: (value) => _handleUrlInput(value, isFirstVideo),
      );
    }

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isFirstVideo ? Colors.blue.shade700 : Colors.blue.shade500,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      onPressed: () => _pickVideo(isFirstVideo),
      icon: const Icon(Icons.file_upload),
      label: Text('Select ${isFirstVideo ? "First" : "Second"} Video'),
    );
  }

  Future<void> _downloadMergedVideo() async {
    if (_outputPath == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }

      if (Platform.isAndroid &&
          await Permission.manageExternalStorage.isGranted == false) {
        await Permission.manageExternalStorage.request();
      }

      final directory = Directory('/storage/emulated/0/Download');

      if (!directory.existsSync()) {
        throw Exception('Could not access Downloads directory');
      }

      final fileName =
          'merged_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final savePath = '${directory.path}/$fileName';

      await File(_outputPath!).copy(savePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video saved to Downloads: $savePath')),
        );
      }
      final result = await Process.run('am', [
        'broadcast',
        '-a',
        'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
        '-d',
        'file://$savePath'
      ]);
      print(result.stdout);
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

  Future<void> _handleUrlInput(String url, bool isFirstVideo) async {
    if (url.isEmpty || !_socialDownloader.isSocialMediaUrl(url)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _downloadProgress[isFirstVideo ? 'first' : 'second'] = 0;
    });

    try {
      const savePath = 'simulated_download_path.mp4';
      _outputPath = savePath;
      await _initializePreview(savePath, isFirstVideo);

      await _downloadMergedVideo();
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
        _downloadProgress.remove(isFirstVideo ? 'first' : 'second');
      });
    }
  }

  Future<void> _pickVideo(bool isFirstVideo) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.video);
      if (result != null) {
        final path = result.files.single.path!;
        if (isFirstVideo) {
          _url1Controller.text = path;
        } else {
          _url2Controller.text = path;
        }
        await _initializePreview(path, isFirstVideo);
      }
    } catch (e) {
      _showError('Error picking video: $e');
    }
  }

  Future<void> _initializePreview(String path, bool isFirstVideo) async {
    try {
      final controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      setState(() {
        if (isFirstVideo) {
          _previewController1?.dispose();
          _previewController1 = controller;
        } else {
          _previewController2?.dispose();
          _previewController2 = controller;
        }
      });
    } catch (e) {
      _showError('Error initializing preview: $e');
    }
  }

  Widget _buildMergeControls() {
    return Card(
      color: Colors.blue.shade200,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Merge Direction:'),
                const Spacer(),
                ToggleButtons(
                  isSelected: [_isHorizontal, !_isHorizontal],
                  onPressed: (index) {
                    setState(() => _isHorizontal = index == 0);
                  },
                  children: const [
                    Icon(Icons.horizontal_distribute),
                    Icon(Icons.vertical_distribute),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_mergeProgress > 0 && _mergeProgress < 1)
              LinearProgressIndicator(value: _mergeProgress),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _processMergeVideos,
              child: const Text('Merge Videos'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processMergeVideos() async {
    if (_url1Controller.text.isEmpty || _url2Controller.text.isEmpty) {
      _showError('Please select both videos');
      return;
    }

    setState(() {
      _isLoading = true;
      _mergeProgress = 0.0;
      _errorMessage = null;
    });

    try {
      _outputPath = _outputPath;
      await _initializeOutputPreview(_outputPath!);
      await _downloadMergedVideo();
    } catch (e) {
      _showError('Error merging videos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeOutputPreview(String path) async {
    if (_outputController != null) {
      await _outputController!.dispose();
    }

    try {
      final controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      if (mounted) {
        setState(() => _outputController = controller);
      }
    } catch (e) {
      _showError('Error initializing output preview: $e');
    }
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merge Videos'),
        actions: [
          IconButton(
            icon: Icon(_showDownloads ? Icons.folder_open : Icons.folder),
            onPressed: () {
              setState(() => _showDownloads = !_showDownloads);
            },
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (_showDownloads) _buildDownloadsPanel(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildVideoSection(true),
                    const SizedBox(height: 16),
                    _buildVideoSection(false),
                    const SizedBox(height: 24),
                    _buildMergeControls(),
                    if (_outputController != null) _buildMergedVideoOutput(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadsPanel() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _downloadedVideos.length,
        itemBuilder: (context, index) {
          final fileName = _downloadedVideos[index].split('/').last;
          return ListTile(
            leading: const Icon(Icons.video_file),
            title: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () =>
                      _playDownloadedVideo(_downloadedVideos[index]),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteDownloadedVideo(index),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMergedVideoOutput() {
    if (_outputController == null || !_outputController!.value.isInitialized) {
      return const SizedBox();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        _buildVideoPreview(_outputController!, _outputPath!, false),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            _outputController!.value.isPlaying
                ? _outputController!.pause()
                : _outputController!.play();
          },
          child: Text(
            _outputController!.value.isPlaying ? 'Pause' : 'Play',
          ),
        ),
      ],
    );
  }

  Future<void> _playDownloadedVideo(String path) async {
    try {
      final controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      setState(() {
        if (_outputController != null) {
          _outputController!.dispose();
        }
        _outputController = controller;
        _outputController!.play();
      });
    } catch (e) {
      _showError('Error playing downloaded video: $e');
    }
  }

  Future<void> _deleteDownloadedVideo(int index) async {
    try {
      final file = File(_downloadedVideos[index]);
      await file.delete();
      setState(() {
        _downloadedVideos.removeAt(index);
      });
    } catch (e) {
      _showError('Error deleting video: $e');
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
