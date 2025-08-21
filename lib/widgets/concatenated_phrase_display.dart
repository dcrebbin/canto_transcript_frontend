import 'package:canto_transcripts_frontend/services/stream_concatenation_service.dart';
import 'package:canto_transcripts_frontend/utilities/utilities.dart';
import 'package:canto_transcripts_frontend/widgets/transliteration_row.dart';
import 'package:flutter/material.dart';

class ConcatenatedPhraseDisplay extends StatelessWidget {
  final ConcatenationResult result;
  final String selectedLanguageCode;

  const ConcatenatedPhraseDisplay({
    super.key,
    required this.result,
    required this.selectedLanguageCode,
  });

  @override
  Widget build(BuildContext context) {
    if (result.currentWord.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: result.isFinal
                ? [Colors.green[100]!, Colors.green[50]!]
                : [Colors.orange[100]!, Colors.orange[50]!],
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      result.isFinal ? Icons.check_circle : Icons.access_time,
                      color: result.isFinal
                          ? Colors.green[700]
                          : Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      result.isFinal ? 'Final Word' : 'Building Word',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: result.isFinal
                            ? Colors.green[700]
                            : Colors.orange[700],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (result.newCharacters.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'New: ${result.newCharacters}',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: TransliterationRow(
                chinese: result.currentWord.split(''),
                romanization: Utilities.retrieveRomanization(
                  result.currentWord,
                  selectedLanguageCode,
                ).split(' '),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StreamingConcatenationViewer extends StatefulWidget {
  final Stream<ConcatenationResult> concatenationStream;
  final String selectedLanguageCode;

  const StreamingConcatenationViewer({
    super.key,
    required this.concatenationStream,
    required this.selectedLanguageCode,
  });

  @override
  State<StreamingConcatenationViewer> createState() =>
      _StreamingConcatenationViewerState();
}

class _StreamingConcatenationViewerState
    extends State<StreamingConcatenationViewer> {
  ConcatenationResult? currentResult;
  final List<ConcatenationResult> history = [];

  @override
  void initState() {
    super.initState();
    widget.concatenationStream.listen((result) {
      setState(() {
        currentResult = result;
        if (result.isFinal) {
          history.add(result);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (currentResult != null && !currentResult!.isFinal)
          ConcatenatedPhraseDisplay(
            result: currentResult!,
            selectedLanguageCode: widget.selectedLanguageCode,
          ),
        if (history.isNotEmpty) ...[
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey[200],
              foregroundColor: Colors.grey[800],
            ),
            onPressed: () {
              setState(() {
                history.clear();
              });
            },
            child: const Text('Clear'),
          ),
          const SizedBox(height: 16),
          ...history.reversed.map(
            (result) => ConcatenatedPhraseDisplay(
              result: result,
              selectedLanguageCode: widget.selectedLanguageCode,
            ),
          ),
        ],
      ],
    );
  }
}
