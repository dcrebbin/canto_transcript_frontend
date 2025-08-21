import 'dart:async';

class ConcatenationResult {
  final String currentWord;
  final String newCharacters;
  final bool isFinal;
  final List<String> usedCharacters;

  const ConcatenationResult({
    required this.currentWord,
    required this.newCharacters,
    required this.isFinal,
    required this.usedCharacters,
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

      _resultController.add(ConcatenationResult(
        currentWord: _currentWord,
        newCharacters: newCharacters,
        isFinal: true,
        usedCharacters: _usedCharacters.toList(),
      ));

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

      _resultController.add(ConcatenationResult(
        currentWord: _currentWord,
        newCharacters: newCharacters,
        isFinal: false,
        usedCharacters: _usedCharacters.toList(),
      ));
    }
  }

  void reset() {
    _currentWord = '';
    _usedCharacters.clear();
    _isBuilding = false;
  }

  void forceComplete() {
    if (_isBuilding && _currentWord.isNotEmpty) {
      _resultController.add(ConcatenationResult(
        currentWord: _currentWord,
        newCharacters: '',
        isFinal: true,
        usedCharacters: _usedCharacters.toList(),
      ));
    }
    reset();
  }

  void dispose() {
    _resultController.close();
  }
}
