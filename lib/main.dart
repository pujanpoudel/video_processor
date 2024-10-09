import 'package:flutter/material.dart';
import 'package:video_splitter/home_screen.dart';

void main() {
  runApp(const VideoSplitter());
}

class VideoSplitter extends StatelessWidget {
  const VideoSplitter({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Processor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}
