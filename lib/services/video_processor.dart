import 'dart:io';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:ffmpeg_kit_flutter/statistics.dart';
import 'package:ffmpeg_kit_flutter/session.dart';
import 'package:ffmpeg_kit_flutter/log.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

class VideoProcessor {
  Future<String> splitVideo(String videoPath, int parts) async {
    final directory = await getApplicationDocumentsDirectory();
    final outputDir = await Directory('${directory.path}/split_videos')
        .create(recursive: true);

    final mediaInformationSession =
        await FFprobeKit.getMediaInformation(videoPath);
    final information = mediaInformationSession.getMediaInformation();
    if (information == null) {
      throw Exception('Could not get video information');
    }

    final duration = double.parse(information.getDuration() ?? '0');
    if (duration <= 0) {
      throw Exception('Invalid video duration');
    }

    final partDuration = duration / parts;
    final splitFiles = <String>[];

    for (var i = 0; i < parts; i++) {
      final outputPath = '${outputDir.path}/part_${i + 1}.mp4';
      final command =
          '-i "$videoPath" -ss ${i * partDuration} -t $partDuration -c copy "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        splitFiles.add(outputPath);
      } else {
        final logs = await session.getLogs();
        throw Exception(
            'Error splitting video at part ${i + 1}: ${logs.last.getMessage()}');
      }
    }

    return outputDir.path;
  }

  Future<List<String>> downloadVideos(List<String> urls) async {
    final directory = await getApplicationDocumentsDirectory();
    final downloadedPaths = <String>[];
    final dio = Dio();

    try {
      for (var i = 0; i < urls.length; i++) {
        final fileName =
            'downloaded_video_${DateTime.now().millisecondsSinceEpoch}_$i.mp4';
        final filePath = '${directory.path}/$fileName';

        await dio.download(urls[i], filePath,
            onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            print(
                'Download progress for video $i: ${(progress * 100).toStringAsFixed(2)}%');
          }
        });

        downloadedPaths.add(filePath);
      }
      return downloadedPaths;
    } catch (e) {
      for (var path in downloadedPaths) {
        await deleteFile(path);
      }
      throw Exception('Error downloading videos: $e');
    }
  }

  Future<String> downloadVideo(String url) async {
    final directory = await getApplicationDocumentsDirectory();
    final dio = Dio();

    try {
      final fileName =
          'downloaded_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = '${directory.path}/$fileName';

      await dio.download(url, filePath, onReceiveProgress: (received, total) {
        if (total != -1) {
          final progress = received / total;
          print('Download progress: ${(progress * 100).toStringAsFixed(2)}%');
        }
      });

      return filePath;
    } catch (e) {
      throw Exception('Error downloading video: $e');
    }
  }

  Future<String> mergeVideos(List<String> videoUrls, bool isHorizontal,
      Function(double)? onProgress) async {
    try {
      final videoPaths = await downloadVideos(videoUrls);
      final directory = await getApplicationDocumentsDirectory();
      final outputPath =
          '${directory.path}/merged_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filter = isHorizontal
          ? 'hstack=inputs=${videoPaths.length}'
          : 'vstack=inputs=${videoPaths.length}';
      final inputParams = videoPaths.map((path) => '-i "$path"').join(' ');
      final command =
          '$inputParams -filter_complex "[0:v][1:v]$filter[v]" -map "[v]" "$outputPath"';
      if (onProgress != null) {
        await executeWithProgress(command, onProgress);
      } else {
        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();
        if (returnCode == null || !ReturnCode.isSuccess(returnCode)) {
          final logs = await session.getLogs();
          throw Exception('Error merging videos: ${logs.last.getMessage()}');
        }
      }

      for (var path in videoPaths) {
        await deleteFile(path);
      }

      return outputPath;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> executeWithProgress(
      String command, Function(double) onProgress) async {
    await FFmpegKit.executeAsync(
      command,
      (Session session) async {
        final returnCode = await session.getReturnCode();
        if (!ReturnCode.isSuccess(returnCode)) {
          final logs = await session.getLogs();
          throw Exception('Operation failed: ${logs.last.getMessage()}');
        }
      },
      (Log log) {
        print(log.getMessage());
      },
      (Statistics statistics) {
        final time = statistics.getTime();
        if (time > 0) {
          final progress = statistics.getTime() / time;
          onProgress(progress);
        }
      },
    );
  }

  Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting file: $e');
    }
  }
}
