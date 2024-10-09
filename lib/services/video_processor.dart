import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter/log.dart';
import 'package:ffmpeg_kit_flutter/session.dart';
import 'package:ffmpeg_kit_flutter/statistics.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class VideoProcessor {
  Future<String> downloadVideo(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to download video');
    }

    final directory = await getTemporaryDirectory();
    final filePath =
        '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.mp4';

    await File(filePath).writeAsBytes(response.bodyBytes);
    return filePath;
  }

  Future<String> splitVideo(String url, int parts) async {
    final inputPath = await downloadVideo(url);
    final directory = await getApplicationDocumentsDirectory();

    final mediaInformationSession =
        await FFprobeKit.getMediaInformation(inputPath);
    final information = mediaInformationSession.getMediaInformation();

    if (information == null) {
      throw Exception('Could not get video information');
    }

    final duration = double.parse(information.getDuration() ?? '0');

    if (duration <= 0) {
      throw Exception('Invalid video duration');
    }

    final partDuration = duration / parts;

    for (var i = 0; i < parts; i++) {
      final outputPath = '${directory.path}/part_${i + 1}.mp4';

      final session = await FFmpegKit.execute(
          '-i $inputPath -ss ${i * partDuration} -t $partDuration -c copy $outputPath');

      final returnCode = await session.getReturnCode();

      if (returnCode == null) {
        throw Exception('Split operation failed with unknown error');
      }

      if (returnCode.getValue() != 0) {
        final logs = await session.getLogs();
        throw Exception(
            'Error splitting video at part ${i + 1}: ${logs.last.getMessage()}');
      }
    }
    await File(inputPath).delete();

    return directory.path;
  }

  Future<String> mergeVideos(String url1, String url2, bool isHorizontal,
      Function(double)? onProgress) async {
    final video1Path = await downloadVideo(url1);
    final video2Path = await downloadVideo(url2);
    final directory = await getApplicationDocumentsDirectory();
    final outputPath =
        '${directory.path}/merged_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final filter = isHorizontal ? 'hstack=inputs=2' : 'vstack=inputs=2';

    final command =
        '-i $video1Path -i $video2Path -filter_complex "[0:v][1:v]$filter[v]" -map "[v]" $outputPath';

    if (onProgress != null) {
      await executeWithProgress(command, onProgress);
    } else {
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (returnCode == null || returnCode.getValue() != 0) {
        final logs = await session.getLogs();
        throw Exception('Error merging videos: ${logs.last.getMessage()}');
      }
    }
    await File(video1Path).delete();
    await File(video2Path).delete();

    return outputPath;
  }

  Future<void> executeWithProgress(
      String command, Function(double) onProgress) async {
    await FFmpegKit.executeAsync(command, (Session session) async {
      final returnCode = await session.getReturnCode();
      if (returnCode?.getValue() != 0) {
        final logs = await session.getLogs();
        throw Exception('Operation failed: ${logs.last.getMessage()}');
      }
    }, (Log log) {
      print(log.getMessage());
    }, (Statistics statistics) {
      final progress = statistics.getTime() / statistics.getTime();
      onProgress(progress);
    });
  }
}
