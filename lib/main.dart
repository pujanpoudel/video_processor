import 'package:flutter/material.dart';
import 'package:video_splitter/screens/home_screen.dart';

void main() {
  runApp(const VideoSplitter());
}

class VideoSplitter extends StatelessWidget {
  const VideoSplitter({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Video Processor',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
