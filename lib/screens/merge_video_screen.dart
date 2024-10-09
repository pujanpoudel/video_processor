import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_splitter/services/video_processor.dart';
import 'package:video_splitter/widgets/social_share_buttons.dart';
import '../widgets/loading_overlay.dart';

class MergeVideoScreen extends StatefulWidget {
  const MergeVideoScreen({super.key});

  @override
  MergeVideoScreenState createState() => MergeVideoScreenState();
}

class MergeVideoScreenState extends State<MergeVideoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _url1Controller = TextEditingController();
  final _url2Controller = TextEditingController();
  bool _isHorizontal = true;
  bool _isLoading = false;
  String? _outputPath;
  VideoPlayerController? _videoPlayerController;

  @override
  void dispose() {
    _url1Controller.dispose();
    _url2Controller.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _url1Controller,
                    decoration: const InputDecoration(
                      labelText: 'First Video URL',
                      hintText: 'Enter URL of first video',
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Please enter a URL';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _url2Controller,
                    decoration: const InputDecoration(
                      labelText: 'Second Video URL',
                      hintText: 'Enter URL of second video',
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
                      const Text('Merge:'),
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
                            child: Text('Horizontally'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Vertically'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _processMergeVideos,
                    child: const Text('Merge Videos'),
                  ),
                  if (_outputPath != null) ...[
                    const SizedBox(height: 24),
                    const Text('Share on:'),
                    const SizedBox(height: 8),
                    SocialShareButtons(videoPath: _outputPath!),
                    const SizedBox(height: 24),
                    const Text('Merged Video:'),
                    const SizedBox(height: 8),
                    _videoPlayerController != null &&
                            _videoPlayerController!.value.isInitialized
                        ? AspectRatio(
                            aspectRatio:
                                _videoPlayerController!.value.aspectRatio,
                            child: VideoPlayer(_videoPlayerController!),
                          )
                        : const Text('Loading video...'),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        if (_videoPlayerController != null) {
                          setState(() {
                            _videoPlayerController!.value.isPlaying
                                ? _videoPlayerController!.pause()
                                : _videoPlayerController!.play();
                          });
                        }
                      },
                      child: Text(_videoPlayerController != null &&
                              _videoPlayerController!.value.isPlaying
                          ? 'Pause'
                          : 'Play'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _processMergeVideos() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final outputPath = await VideoProcessor().mergeVideos(
        _url1Controller.text,
        _url2Controller.text,
        _isHorizontal,
        (progress) {
          if (mounted) {
            setState(() {});
          }
        },
      );

      if (mounted) {
        setState(() {
          _outputPath = outputPath;
        });
        _initializeVideoPlayer(outputPath);
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
    _videoPlayerController = VideoPlayerController.file(File(videoPath))
      ..initialize().then((_) {
        setState(() {});
      });
  }
}
