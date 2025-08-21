import 'dart:async';
import 'package:canto_transcripts_frontend/utilities/service_locator.dart';

class ConcatenationResult {
  final String currentWord;
  final String newCharacters;
  final bool isFinal;
  final List<String> usedCharacters;
  final String translation;

  const ConcatenationResult({
    required this.currentWord,
    required this.newCharacters,
    required this.isFinal,
    required this.usedCharacters,
    required this.translation,
  });
}

class StreamConcatenationService {
  String _currentWord = '';
  final Set<String> _usedCharacters = <String>{};
  bool _isBuilding = false;

  final StreamController<ConcatenationResult> _resultController =
      StreamController<ConcatenationResult>.broadcast();

  Stream<ConcatenationResult> get resultStream => _resultController.stream;

  String get currentWord => _currentWord;
  List<String> get usedCharacters => _usedCharacters.toList();
  bool get isBuilding => _isBuilding;

  void processTranscriptionChunk({
    required String text,
    required bool isFinal,
  }) {
    if (text.isEmpty) {
      return;
    }

    String newCharacters = '';
    String updatedWord = _currentWord;

    if (isFinal) {
      final List<String> finalCharacters = text.split('');

      for (final String character in finalCharacters) {
        if (!_usedCharacters.contains(character)) {
          newCharacters += character;
          updatedWord += character;
          _usedCharacters.add(character);
        }
      }

      _currentWord = updatedWord;
      _isBuilding = false;

      // Capture values before reset for later translation update
      final String wordForTranslation = _currentWord;
      final List<String> usedCharsForTranslation = _usedCharacters.toList();

      _resultController.add(
        ConcatenationResult(
          currentWord: _currentWord,
          newCharacters: newCharacters,
          isFinal: true,
          usedCharacters: usedCharsForTranslation,
          translation: '',
        ),
      );

      // Kick off translation asynchronously and emit an update when ready
      // We intentionally do not await this to keep the stream responsive
      _emitTranslationUpdate(
        word: wordForTranslation,
        usedCharacters: usedCharsForTranslation,
      );

      reset();
    } else {
      _isBuilding = true;
      final List<String> characters = text.split('');

      for (final String character in characters) {
        if (!_usedCharacters.contains(character)) {
          newCharacters += character;
          updatedWord += character;
          _usedCharacters.add(character);
        }
      }

      _currentWord = updatedWord;

      _resultController.add(
        ConcatenationResult(
          currentWord: _currentWord,
          newCharacters: newCharacters,
          isFinal: false,
          usedCharacters: _usedCharacters.toList(),
          translation: '',
        ),
      );
    }
  }

  Future<void> _emitTranslationUpdate({
    required String word,
    required List<String> usedCharacters,
  }) async {
    try {
      if (word.isEmpty) return;
      final String translation = await sl.ai.getTranslation(word);
      if (_resultController.isClosed) return;
      _resultController.add(
        ConcatenationResult(
          currentWord: word,
          newCharacters: '',
          isFinal: true,
          usedCharacters: usedCharacters,
          translation: translation,
        ),
      );
    } catch (_) {
      // Swallow translation errors to avoid breaking stream; UI can keep spinner
    }
  }

  void reset() {
    _currentWord = '';
    _usedCharacters.clear();
    _isBuilding = false;
  }

  void forceComplete() {
    if (_isBuilding && _currentWord.isNotEmpty) {
      _resultController.add(
        ConcatenationResult(
          currentWord: _currentWord,
          newCharacters: '',
          isFinal: true,
          usedCharacters: _usedCharacters.toList(),
          translation: '',
        ),
      );
    }
    reset();
  }

  void dispose() {
    _resultController.close();
  }
}
