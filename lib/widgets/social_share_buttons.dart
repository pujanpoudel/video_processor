import 'package:flutter/material.dart';

class SocialShareButtons extends StatelessWidget {
  final String videoPath;
  final VoidCallback onUploadToYouTube;
  final VoidCallback onUploadToFacebook;
  final VoidCallback onUploadToInstagram;
  final VoidCallback onUploadToTikTok;

  const SocialShareButtons({
    super.key,
    required this.videoPath,
    required this.onUploadToYouTube,
    required this.onUploadToFacebook,
    required this.onUploadToInstagram,
    required this.onUploadToTikTok,
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
          onUploadToInstagram,
        ),
        _buildShareButton(
          'TikTok',
          Icons.music_note,
          Colors.black,
          onUploadToTikTok,
        ),
        _buildShareButton(
          'Facebook',
          Icons.facebook,
          Colors.blue,
          onUploadToFacebook,
        ),
        _buildShareButton(
          'YouTube',
          Icons.play_arrow,
          Colors.red,
          onUploadToYouTube,
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
}
