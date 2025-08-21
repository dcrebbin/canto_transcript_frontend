import 'dart:async';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:record/record.dart';

class MicRecorderService {
  final Logger logger = Logger('MicRecorderService');
  final AudioRecorder recorder = AudioRecorder();
  StreamSubscription<Uint8List>? subscription;

  Future<bool> startPcm({
    required void Function(Uint8List chunk) onChunk,
    int sampleRate = 16000,
    int numChannels = 1,
  }) async {
    try {
      final bool hasPermission = await recorder.hasPermission();
      if (!hasPermission) {
        return false;
      }
      if (await recorder.isRecording()) {
        await stop();
      }
      final RecordConfig config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: numChannels,
        bitRate: 128000,
      );
      final Stream<Uint8List> stream = await recorder.startStream(config);
      subscription = stream.listen(onChunk, onError: (Object error) {
        logger.severe('Mic stream error: $error');
      });
      return true;
    } catch (e) {
      logger.severe('Failed to start pcm mic: $e');
      return false;
    }
  }

  Future<void> stopPcm() async {
    try {
      await subscription?.cancel();
      subscription = null;
      await recorder.stop();
    } catch (e) {
      logger.severe('Failed to stop pcm mic: $e');
    }
  }

  Future<bool> startMp3({
    required void Function(Uint8List chunk) onChunk,
    int sampleRate = 16000,
    int numChannels = 1,
    int bitRateKbps = 128,
  }) async {
    try {
      final bool hasPermission = await recorder.hasPermission();
      if (!hasPermission) {
        return false;
      }
      if (await recorder.isRecording()) {
        await stop();
      }
      final RecordConfig config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: numChannels,
        bitRate: bitRateKbps * 1000,
      );
      final Stream<Uint8List> stream = await recorder.startStream(config);
      subscription = stream.listen(onChunk, onError: (Object error) {
        logger.severe('MP3 stream error: $error');
      });
      return true;
    } catch (e) {
      logger.severe('Failed to start mp3 recorder: $e');
      return false;
    }
  }

  Future<void> stopMp3() async {
    try {
      await subscription?.cancel();
      subscription = null;
      await recorder.stop();
    } catch (e) {
      logger.severe('Failed to stop mp3 recorder: $e');
    }
  }

  Future<void> stop() async {
    await subscription?.cancel();
    subscription = null;
    await recorder.stop();
  }

  Future<void> dispose() async {
    await stop();
    await recorder.dispose();
  }
}
