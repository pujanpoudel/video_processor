import 'package:html/parser.dart' as parser;
import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class SocialVideoDownloader {
  final _yt = YoutubeExplode();
  final _dio = Dio();

  bool isSocialMediaUrl(String url) {
    return url.contains('youtube.com') ||
        url.contains('youtu.be') ||
        url.contains('tiktok.com') ||
        url.contains('instagram.com') ||
        url.contains('facebook.com');
  }

  Future<String> getDirectVideoUrl(String url) async {
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return await _getYoutubeVideoUrl(url);
    } else if (url.contains('tiktok.com')) {
      return await _getTikTokVideoUrl(url);
    } else if (url.contains('instagram.com')) {
      return await _getInstagramVideoUrl(url);
    } else if (url.contains('facebook.com')) {
      return await _getFacebookVideoUrl(url);
    } else {
      return url;
    }
  }

  Future<String> _getYoutubeVideoUrl(String url) async {
    try {
      final video = await _yt.videos.get(url);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);
      final streamInfo = manifest.muxed.withHighestBitrate();
      return streamInfo.url.toString();
    } catch (e) {
      throw Exception('Failed to extract YouTube video: $e');
    }
  }

  Future<String> _getTikTokVideoUrl(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
          },
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );

      final document = parser.parse(response.data);
      final videoElement = document.querySelector('video[src]');
      if (videoElement != null) {
        final videoUrl = videoElement.attributes['src'];
        if (videoUrl != null) return videoUrl;
      }

      throw Exception('Could not extract TikTok video URL');
    } catch (e) {
      throw Exception('Failed to extract TikTok video: $e');
    }
  }

  Future<String> _getInstagramVideoUrl(String url) async {
    try {
      final apiUrl =
          url.replaceAll('instagram.com', 'i.instagram.com/api/v1/media');

      final response = await _dio.get(
        apiUrl,
        options: Options(
          headers: {
            'User-Agent': 'Instagram 219.0.0.12.117 Android',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.data['video_versions'] != null) {
        return response.data['video_versions'][0]['url'];
      }

      throw Exception('No video URL found in Instagram response');
    } catch (e) {
      throw Exception('Failed to extract Instagram video: $e');
    }
  }

  Future<String> _getFacebookVideoUrl(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
          },
        ),
      );

      final hdPattern = RegExp(r'hd_src:"([^"]+)"');
      final hdMatch = hdPattern.firstMatch(response.data.toString());
      if (hdMatch != null) {
        return hdMatch.group(1)!;
      }

      final sdPattern = RegExp(r'sd_src:"([^"]+)"');
      final sdMatch = sdPattern.firstMatch(response.data.toString());
      if (sdMatch != null) {
        return sdMatch.group(1)!;
      }

      throw Exception('No video URL found in Facebook response');
    } catch (e) {
      throw Exception('Failed to extract Facebook video: $e');
    }
  }
}
