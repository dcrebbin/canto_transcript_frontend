import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:canto_transcripts_frontend/services/stream_concatenation_service.dart';
import 'package:logging/logging.dart';

enum SensevoiceState { disconnected, connecting, connected, error }

class SensevoiceEvent {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  SensevoiceEvent({required this.type, required this.data, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}

class SensevoiceService {
  final Logger logger = Logger('SensevoiceService');
  final bool enableAutoReconnect;
  final bool enableConcatenation;

  WebSocket? _socket;
  SensevoiceState _state = SensevoiceState.disconnected;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  Uri _endpoint = Uri.parse('ws://localhost:8000/api/realtime/ws');

  late final StreamConcatenationService _concatenationService;
  final StreamController<SensevoiceEvent> _eventController =
      StreamController<SensevoiceEvent>.broadcast();
  final StreamController<SensevoiceState> _stateController =
      StreamController<SensevoiceState>.broadcast();

  SensevoiceService({
    this.enableAutoReconnect = true,
    this.enableConcatenation = false,
  }) {
    _concatenationService = StreamConcatenationService();
    if (enableConcatenation) {
      _concatenationService.resultStream.listen(_handleConcatenationResult);
    }
  }

  SensevoiceState get state => _state;
  Stream<SensevoiceEvent> get eventStream => _eventController.stream;
  Stream<SensevoiceState> get stateStream => _stateController.stream;
  bool get isConnected => _state == SensevoiceState.connected;

  StreamConcatenationService get concatenationService => _concatenationService;

  void _handleConcatenationResult(ConcatenationResult result) {
    _eventController.add(
      SensevoiceEvent(
        type: 'concatenated_transcript',
        data: <String, dynamic>{
          'currentWord': result.currentWord,
          'newCharacters': result.newCharacters,
          'isFinal': result.isFinal,
          'usedCharacters': result.usedCharacters,
        },
      ),
    );
  }

  Future<void> connect({String? url}) async {
    if (_state == SensevoiceState.connecting ||
        _state == SensevoiceState.connected) {
      logger.warning('Already connecting or connected');
      return;
    }

    if (url != null && url.isNotEmpty) {
      _endpoint = Uri.parse(url);
    }

    _updateState(SensevoiceState.connecting);

    try {
      _socket = await WebSocket.connect(_endpoint.toString());
      _socket!.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleClose,
        cancelOnError: false,
      );
      _reconnectAttempts = 0;
      _updateState(SensevoiceState.connected);
    } catch (e) {
      _emitError(code: 'connect_failed', message: e.toString());
      _updateState(SensevoiceState.error);
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic message) {
    try {
      print('Received message: $message');
      if (message is List<int>) {
        return;
      }
      if (message is String) {
        final Map<String, dynamic> json =
            jsonDecode(message) as Map<String, dynamic>;
        final String type = json['type'] as String? ?? 'unknown';
        if (type == 'TranscriptionResponse') {
          final String rawText = json['data']?['raw_text'] ?? '';
          final bool isFinal = json['is_final'] ?? false;

          _eventController.add(
            SensevoiceEvent(
              type: 'transcript',
              data: <String, dynamic>{
                'id': json['id'],
                'isFinal': isFinal,
                'rawText': rawText,
                'beginAt': json['begin_at'],
                'endAt': json['end_at'],
              },
            ),
          );

          if (enableConcatenation && rawText.isNotEmpty) {
            _concatenationService.processTranscriptionChunk(
              text: rawText,
              isFinal: isFinal,
            );
          }

          return;
        }
        if (type == 'VADEvent') {
          _eventController.add(
            SensevoiceEvent(
              type: 'vad',
              data: <String, dynamic>{'isActive': json['is_active'] ?? false},
            ),
          );
          return;
        }
        _eventController.add(SensevoiceEvent(type: 'raw', data: json));
      }
    } catch (e) {
      _emitError(code: 'parse_error', message: e.toString());
    }
  }

  void _handleError(Object error) {
    _emitError(code: 'socket_error', message: error.toString());
    _updateState(SensevoiceState.error);
    _scheduleReconnect();
  }

  void _handleClose() {
    _updateState(SensevoiceState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!enableAutoReconnect || _reconnectTimer != null) return;
    _reconnectAttempts = _reconnectAttempts + 1;
    final int delayMs = _computeBackoffMs(_reconnectAttempts);
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () async {
      _reconnectTimer = null;
      await connect(url: _endpoint.toString());
    });
  }

  int _computeBackoffMs(int attempt) {
    final int ms = 1000 * (1 << (attempt > 5 ? 5 : attempt));
    return ms > 30000 ? 30000 : ms;
  }

  void sendAudioChunk(Uint8List chunk) {
    if (!isConnected || _socket == null) {
      print('Socket not connected');
      _emitError(code: 'not_connected', message: 'Socket not connected');
      return;
    }
    try {
      print('Sending chunk ${chunk.length} bytes');
      _socket!.add(chunk);
    } catch (e) {
      print('Send failed: $e');
      _emitError(code: 'send_failed', message: e.toString());
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (_socket != null) {
      try {
        await _socket!.close();
      } catch (_) {}
      _socket = null;
    }
    _updateState(SensevoiceState.disconnected);
  }

  void resetConcatenation() {
    _concatenationService.reset();
  }

  void forceCompleteConcatenation() {
    _concatenationService.forceComplete();
  }

  void dispose() {
    disconnect();
    _concatenationService.dispose();
    _eventController.close();
    _stateController.close();
  }

  void _emitError({required String code, required String message}) {
    _eventController.add(
      SensevoiceEvent(
        type: 'error',
        data: <String, dynamic>{'code': code, 'message': message},
      ),
    );
    logger.severe('[$code] $message');
  }

  void _updateState(SensevoiceState newState) {
    if (_state == newState) return;
    _state = newState;
    _stateController.add(newState);
    logger.info('Sensevoice state changed to: $newState');
  }
}
