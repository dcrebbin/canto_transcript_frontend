import 'package:canto_transcripts_frontend/utilities/utilities.dart';
import 'package:canto_transcripts_frontend/widgets/transliteration_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/mic_recorder_service.dart';
import '../../../services/sensevoice_service.dart';
import '../widgets/concatenated_phrase_display.dart';

class WebSocketTestScreen extends StatefulWidget {
  const WebSocketTestScreen({super.key});

  @override
  State<WebSocketTestScreen> createState() => _WebSocketTestScreenState();
}

class _WebSocketTestScreenState extends State<WebSocketTestScreen>
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
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getSenseStateColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Status: ${_getSenseStateText()}  VAD: ${_vadActive ? 'active' : 'idle'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: !_isMp3Recording
                            ? _startSenseRecordingMp3
                            : null,
                        child: const Text('Start MP3 Recording'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _senseState == SensevoiceState.connected &&
                                _isMp3Recording
                            ? _stopSenseRecordingMp3
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Stop MP3 Recording'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: StreamingConcatenationViewer(
            concatenationStream:
                _sensevoiceService.concatenationService.resultStream,
            selectedLanguageCode: 'zh_HK',
          ),
        ),
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.mic_none, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Start recording to see concatenated words',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        // SenseVoiceConversion(context),
        // SenseVoiceLogViewer(context),
      ],
    );
  }

  Widget SenseVoiceConversion(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SenseVoice Log',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _senseConversionLog.clear();
                      });
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _senseConversionLog.isEmpty
                      ? const Center(
                          child: Text(
                            'No events yet...',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      : Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _senseConversionLog.length,
                            itemBuilder: (context, index) {
                              final text = _senseConversionLog[index]['text'];
                              final type = _senseConversionLog[index]['type'];

                              if (type == 'chinese') {
                                final romanisation =
                                    Utilities.retrieveRomanization(
                                      _senseConversionLog[index]['text'],
                                      'zh_HK',
                                    ).split(" ");
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: TransliterationRow(
                                      chinese:
                                          _senseConversionLog[index]['text']
                                              .split(''),
                                      romanization: romanisation,
                                    ),
                                  ),
                                );
                              }
                              return Text(text);
                            },
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Expanded SenseVoiceLogViewer(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SenseVoice Log',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton(
                    onPressed: _clearSenseLog,
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _senseLog.isEmpty
                      ? const Center(
                          child: Text(
                            'No events yet...',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _senseLog.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                _senseLog[index],
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget ConcatenationLogViewer(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Concatenation Log',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _concatenationLog.clear();
                      });
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _concatenationLog.isEmpty
                      ? const Center(
                          child: Text(
                            'No concatenation events yet...',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _concatenationLog.length,
                          itemBuilder: (context, index) {
                            final entry = _concatenationLog[index];
                            final timestamp = (entry['timestamp'] as DateTime)
                                .toString()
                                .substring(11, 19);
                            final currentWord = entry['currentWord'] as String;
                            final newCharacters =
                                entry['newCharacters'] as String;
                            final isFinal = entry['isFinal'] as bool;
                            final usedChars =
                                (entry['usedCharacters'] as List<dynamic>).join(
                                  ' ',
                                );

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          timestamp,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isFinal
                                                ? Colors.green
                                                : Colors.orange,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            isFinal ? 'FINAL' : 'BUILDING',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Current Word: "$currentWord"',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (newCharacters.isNotEmpty)
                                      Text(
                                        'New Characters: "$newCharacters"',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontSize: 12,
                                        ),
                                      ),
                                    Text(
                                      'Used Characters: $usedChars',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
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
