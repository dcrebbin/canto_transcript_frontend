import 'dart:math';

import 'package:canto_transcripts_frontend/services/stream_concatenation_service.dart';
import 'package:canto_transcripts_frontend/utilities/utilities.dart';
import 'package:canto_transcripts_frontend/widgets/transliteration_row.dart';
import 'package:canto_transcripts_frontend/widgets/glowing_border.dart';
import 'package:flutter/material.dart';

class ConcatenatedPhraseDisplay extends StatelessWidget {
  final ConcatenationResult result;
  final String selectedLanguageCode;
  final Color color;

  const ConcatenatedPhraseDisplay({
    super.key,
    required this.result,
    required this.selectedLanguageCode,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (result.currentWord.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
        child: GlowingBorder(
          padding: const EdgeInsets.all(8),
          color: color,
          strokeWidth: 2,
          glowSigma: 12,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Cantonese", style: TextStyle(color: Colors.white)),
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
  final List<_HistoryItem> history = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.concatenationStream.listen((result) {
      setState(() {
        currentResult = result;
        if (result.isFinal) {
          history.add(_HistoryItem(result: result, color: determineColor()));
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.minScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    });
  }

  Color determineColor() {
    final randomNumber = Random().nextInt(4);
    switch (randomNumber) {
      case 0:
        return const Color(0xFFFF00FF);
      case 1:
        return const Color(0xFF00FFFF);
      case 2:
        return const Color(0xFF00FF00);
      case 3:
        return const Color(0xFFFF0000);
    }
    return const Color(0xFFFF00FF);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
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
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            itemCount: history.length,
            reverse: false,
            itemBuilder: (context, index) {
              return ConcatenatedPhraseDisplay(
                result: history[index].result,
                selectedLanguageCode: widget.selectedLanguageCode,
                color: history[history.length - index - 1].color,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryItem {
  final ConcatenationResult result;
  final Color color;

  _HistoryItem({required this.result, required this.color});
}
