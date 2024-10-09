import 'package:flutter/material.dart';
import 'package:video_splitter/merge_video_screen.dart';
import 'package:video_splitter/screens/split_video_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Processor'),
      ),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 600,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildFeatureCard(
                      context,
                      'Split Video',
                      'Split a video into multiple parts',
                      Icons.call_split,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SplitVideoScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureCard(
                      context,
                      'Merge Videos',
                      'Merge two videos horizontally or vertically',
                      Icons.merge,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MergeVideoScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title,
      String description, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 48),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
