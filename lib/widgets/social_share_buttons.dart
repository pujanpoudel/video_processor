import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class SocialShareButtons extends StatelessWidget {
  final String videoPath;

  const SocialShareButtons({
    super.key,
    required this.videoPath,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildShareButton(
          'Instagram',
          Icons.camera_alt,
          Colors.pink,
          () => _shareToSocialMedia('instagram'),
        ),
        _buildShareButton(
          'TikTok',
          Icons.music_note,
          Colors.black,
          () => _shareToSocialMedia('tiktok'),
        ),
        _buildShareButton(
          'Facebook',
          Icons.facebook,
          Colors.blue,
          () => _shareToSocialMedia('facebook'),
        ),
        _buildShareButton(
          'YouTube',
          Icons.play_arrow,
          Colors.red,
          () => _shareToSocialMedia('youtube'),
        ),
      ],
    );
  }

  Widget _buildShareButton(
    String platform,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(platform),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _shareToSocialMedia(String platform) async {
    final file = XFile(videoPath);

    try {
      await Share.shareXFiles(
        [file],
        text: 'Check out this video!',
      );
    } catch (e) {
      debugPrint('Error sharing video: $e');
      //show error to user this
    }
  }
}
