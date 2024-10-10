import 'dart:io';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter/log.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:ffmpeg_kit_flutter/session.dart';
import 'package:ffmpeg_kit_flutter/statistics.dart';
import 'package:path_provider/path_provider.dart';

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

  Future<String> mergeVideos(
    List<String> videoPaths,
    bool isHorizontal,
    Function(double)? onProgress,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final outputPath =
          '${directory.path}/merged_${DateTime.now().millisecondsSinceEpoch}.mp4';
      List<String> processedPaths = [];

      for (var path in videoPaths) {
        final session = await FFprobeKit.getMediaInformation(path);
        final info = session.getMediaInformation();
        if (info == null) {
          throw Exception('Could not get media information');
        }
        final streams = info.getStreams();
        if (streams.isEmpty) {
          throw Exception('Invalid video format');
        }

        final processedPath =
            '${directory.path}/processed_${DateTime.now().millisecondsSinceEpoch}_${processedPaths.length}.mp4';
        const padFilter = 'pad=iw:ih:(ow-iw)/2:(oh-ih)/2:color=black';

        final processCommand = '-i "$path" -vf "$padFilter" "$processedPath"';
        final processSession = await FFmpegKit.execute(processCommand);
        final processReturnCode = await processSession.getReturnCode();

        if (processReturnCode == null ||
            !ReturnCode.isSuccess(processReturnCode)) {
          throw Exception('Error processing video');
        }

        processedPaths.add(processedPath);
      }

      final filter = isHorizontal
          ? 'hstack=inputs=${processedPaths.length}'
          : 'vstack=inputs=${processedPaths.length}';

      final inputParams = processedPaths.map((path) => '-i "$path"').join(' ');
      final command =
          '$inputParams -filter_complex "$filter" -c:a copy "$outputPath"';

      if (onProgress != null) {
        await executeWithProgress(command, (mergeProgress) {
          final overallProgress = 0.5 + (mergeProgress * 0.5);
          onProgress(overallProgress);
        });
      } else {
        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();
        if (returnCode == null || !ReturnCode.isSuccess(returnCode)) {
          throw Exception('Error merging videos');
        }
      }

      for (var path in processedPaths) {
        await File(path).delete();
      }

      return outputPath;
    } catch (e) {
      rethrow;
    }
  }
}
