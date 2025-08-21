import 'package:canto_transcripts_frontend/utilities/utilities.dart';
import 'package:canto_transcripts_frontend/widgets/transliteration_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/mic_recorder_service.dart';
import '../../services/sensevoice_service.dart';
import 'widgets/concatenated_phrase_display.dart';

class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen>
    with TickerProviderStateMixin {
  late final ScrollController _scrollController = ScrollController();
  late SensevoiceService _sensevoiceService;
  late MicRecorderService _micService;
  final TextEditingController _senseUrlController = TextEditingController(
    text: 'ws://localhost:8000/api/realtime/ws',
  );
  final List<String> _messageLog = [];
  final List<String> _senseLog = [];
  final List<dynamic> _senseConversionLog = [];
  final List<dynamic> _concatenationLog = [];

  SensevoiceState _senseState = SensevoiceState.disconnected;
  bool _vadActive = false;
  final bool _enableConcatenation = true;

  bool _isMp3Recording = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    _sensevoiceService = SensevoiceService(
      enableAutoReconnect: false,
      enableConcatenation: _enableConcatenation,
    );
    _initializeServiceListeners();

    _micService = MicRecorderService();
  }

  void _clearSenseLog() {
    setState(() {
      _senseLog.clear();
      _concatenationLog.clear();
    });
  }

  void _initializeServiceListeners() {
    _sensevoiceService.stateStream.listen((state) {
      setState(() {
        _senseState = state;
      });
    });
    _sensevoiceService.eventStream.listen((event) {
      if (event.type == 'vad') {
        setState(() {
          _vadActive = (event.data['isActive'] as bool?) ?? false;
          _senseLog.add(
            '${event.timestamp.toString().substring(11, 19)} - VAD: ${_vadActive ? 'active' : 'idle'}',
          );
        });
        return;
      }
      setState(() {
        if (event.type == 'transcript') {
          final String id = (event.data['id'] ?? '').toString();
          final bool isFinal = (event.data['isFinal'] as bool?) ?? false;
          final String text = (event.data['rawText'] ?? '').toString();
          final String begin = (event.data['beginAt'] ?? '').toString();
          final String end = (event.data['endAt'] ?? '').toString();

          final isEnglish = RegExp(r'^[a-zA-Z0-9\s]+$').hasMatch(text);

          if (_senseConversionLog.isNotEmpty &&
              text == _senseConversionLog.last['text']) {
            return;
          }

          if (isEnglish) {
            _senseConversionLog.add({'text': text, 'type': 'english'});
          } else {
            _senseConversionLog.add({'text': text, 'type': 'chinese'});
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          });

          _senseLog.add(
            '${event.timestamp.toString().substring(11, 19)} - ${isFinal ? 'final' : 'delta'} [$id] $text ($begin ~ ${isFinal ? end : 'now'})',
          );
        } else if (event.type == 'concatenated_transcript') {
          final String currentWord = (event.data['currentWord'] ?? '')
              .toString();
          final String newCharacters = (event.data['newCharacters'] ?? '')
              .toString();
          final bool isFinal = (event.data['isFinal'] as bool?) ?? false;
          final List<dynamic> usedCharacters =
              event.data['usedCharacters'] ?? [];

          _concatenationLog.add({
            'currentWord': currentWord,
            'newCharacters': newCharacters,
            'isFinal': isFinal,
            'usedCharacters': usedCharacters,
            'timestamp': event.timestamp,
          });

          _senseLog.add(
            '${event.timestamp.toString().substring(11, 19)} - concatenated ${isFinal ? 'final' : 'building'}: "$currentWord" (new: "$newCharacters")',
          );
        } else if (event.type == 'error') {
          _senseLog.add(
            '${event.timestamp.toString().substring(11, 19)} - error: ${event.data}',
          );
        } else {
          _senseLog.add(
            '${event.timestamp.toString().substring(11, 19)} - ${event.type}: ${event.data}',
          );
        }
      });
    });
  }

  void _resetConcatenation() {
    _sensevoiceService.resetConcatenation();
  }

  void _forceCompleteConcatenation() {
    _sensevoiceService.forceCompleteConcatenation();
  }

  void _connectSense() {
    _sensevoiceService.connect(url: 'ws://127.0.0.1:8000/api/realtime/ws');
  }

  void _disconnectSense() {
    _sensevoiceService.disconnect();
  }

  Future<void> _startSenseRecordingMp3() async {
    await _sensevoiceService.connect(url: _senseUrlController.text.trim());

    final bool ok = await _micService.startMp3(
      onChunk: (Uint8List chunk) {
        _sensevoiceService.sendAudioChunk(chunk);
      },
      sampleRate: 16000,
      numChannels: 1,
      bitRateKbps: 64,
    );
    if (ok) {
      setState(() {
        _isMp3Recording = true;
      });
    }
  }

  Future<void> _stopSenseRecordingMp3() async {
    await _sensevoiceService.disconnect();
    await _micService.stopMp3();
    _sensevoiceService.sendAudioChunk(Uint8List(0));
    setState(() {
      _isMp3Recording = false;
    });
  }

  Color _getSenseStateColor() {
    switch (_senseState) {
      case SensevoiceState.connected:
        return Colors.green;
      case SensevoiceState.connecting:
        return Colors.orange;
      case SensevoiceState.error:
        return Colors.red;
      case SensevoiceState.disconnected:
        return Colors.grey;
    }
  }

  String _getSenseStateText() {
    switch (_senseState) {
      case SensevoiceState.connected:
        return 'Connected';
      case SensevoiceState.connecting:
        return 'Connecting...';
      case SensevoiceState.error:
        return 'Error';
      case SensevoiceState.disconnected:
        return 'Disconnected';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 130),
      child: Column(
        children: [
          Expanded(
            child: StreamingConcatenationViewer(
              concatenationStream:
                  _sensevoiceService.concatenationService.resultStream,
              selectedLanguageCode: 'zh_HK',
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(70),
                topRight: Radius.circular(70),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_isMp3Recording) {
                          _stopSenseRecordingMp3();
                        } else {
                          _startSenseRecordingMp3();
                        }
                      },
                      icon: Icon(
                        _isMp3Recording ? Icons.mic_none : Icons.mic,
                        size: 48,
                        color: _isMp3Recording ? Colors.red : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sensevoiceService.dispose();
    _micService.dispose();
    _senseUrlController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
