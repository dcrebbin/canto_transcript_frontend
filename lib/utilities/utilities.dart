import 'dart:convert';
import 'package:canto_transcripts_frontend/utilities/service_locator.dart';
import 'package:jyutping/jyutping.dart';

class Utilities {
  static String? safeDecodeUtf8(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException catch (e) {
      sl.logging.logError(
        "Invalid UTF-8 in ChineseCharacters: $e",
        StackTrace.current,
      );
      return null;
    }
  }

  static String transformTone(String romanization) {
    final numberRegex = RegExp(r'\d');
    if (!numberRegex.hasMatch(romanization)) {
      return romanization;
    }
    final pureRomanization = romanization
        .replaceAll(" ", "")
        .replaceAll(".", "")
        .replaceAll(",", "")
        .replaceAll("!", "")
        .replaceAll("?", "");
    var safeRomanization = safeDecodeUtf8(pureRomanization.codeUnits);

    if (safeRomanization == null) {
      return "Invalid";
    }

    final match = numberRegex.firstMatch(romanization);
    if (match == null) {
      return romanization;
    }

    final tone = match.group(0)!;
    final List<String> romanizationParts = romanization.split(tone);

    if (romanizationParts.isEmpty) {
      return "";
    }

    switch (tone) {
      case "1":
        return "${romanizationParts[0]}⎺$tone";
      case "2":
        return "${romanizationParts[0]}/$tone";
      case "3":
        return "${romanizationParts[0]}-$tone";
      case "4":
        return "${romanizationParts[0]}_$tone";
      case "5":
        return "${romanizationParts[0]}/$tone";
      case "6":
        return "${romanizationParts[0]}_$tone";
    }
    return "";
  }

  static Map<String, String> latinToChineseMap(
    List<String> splitPhrases,
    List<String> splitPinyinPhrases,
  ) {
    final latinToChineseMap = <String, String>{};
    for (var i = 0; i < splitPhrases.length; i++) {
      for (var j = 0; j < splitPhrases[i].length; j++) {
        latinToChineseMap[splitPhrases[i][j]] = splitPinyinPhrases[i][j];
      }
    }
    return latinToChineseMap;
  }

  static String retrieveInvalidCharacters(String phrase) {
    List<String> invalidCharacters = [];
    for (var i = 0; i < phrase.length; i++) {
      if (!Utilities.isChinese(phrase[i])) {
        invalidCharacters.add(phrase[i]);
      }
    }
    return invalidCharacters.join(", ");
  }

  static String determineRomanization(
    String phrase,
    String selectedLanguageCode, {
    bool returnMultiple = false,
  }) {
    String sanitizedPhrase = phrase
        .trim()
        .replaceAll(" ", "")
        .replaceAll(".", "")
        .replaceAll(",", "")
        .replaceAll("!", "")
        .replaceAll("?", "");

    var chinese = RegExp(r'[\u4E00-\u9FFF]');
    switch (selectedLanguageCode) {
      case "zh_HK":
        if (!chinese.hasMatch(sanitizedPhrase)) {
          return retrieveInvalidCharacters(sanitizedPhrase);
        }
        return retrieveJyutping(
          sanitizedPhrase,
          returnMultiple: returnMultiple,
        ).toList().join(" ");
      default:
        return "NOT SUPPORTED";
    }
  }

  static List<String> appendFinalParts(
    List<String> parts,
    String chinese,
    String english,
  ) {
    if (chinese != "") {
      parts.add(chinese);
    }
    if (english != "") {
      parts.add(english);
    }
    return parts;
  }

  static List<String> prependParts(
    List<String> parts,
    String chinese,
    String english,
  ) {
    if (chinese != "") {
      chinese = "";
      parts.add(chinese);
    }
    if (english != "") {
      english = "";
      parts.add(english);
    }
    return parts;
  }

  static List<String> retrieveJyutping(
    String phrase, {
    bool returnMultiple = false,
  }) {
    List<String> parts = [];
    final latinToChineseMap = <String, String>{};
    String chinesePart = "";
    String englishPart = "";

    for (var i = 0; i < phrase.length; i++) {
      String currentCharacter = phrase[i];
      parts = prependParts(parts, chinesePart, englishPart);

      if (isChinese(currentCharacter)) {
        chinesePart += currentCharacter;
      } else {
        englishPart += currentCharacter;
      }
    }

    parts = appendFinalParts(parts, chinesePart, englishPart);

    List<List<String>> combinedParts = [];

    for (var i = 0; i < parts.length; i++) {
      if (!isChinese(parts[i])) {
        List<String> englishList = parts[i].split("");
        combinedParts.add(englishList);
        continue;
      }
      var chinese = parts[i];
      var convertedJyutping = JyutpingHelper.getWholeJyutpingPhrase(
        chinese,
        returnMultiple,
      );

      final splitWord = chinese.split("");

      for (var i = 0; i < splitWord.length; i++) {
        latinToChineseMap[convertedJyutping[i]] = splitWord[i];
      }
      combinedParts.add(convertedJyutping);
    }

    List<String> mergedParts = mergeParts(combinedParts);
    return mergedParts;
  }

  static List<String> processPinyinPhrase(
    String phrase,
    String selectedLanguageCode,
    int charactersPerRow,
  ) {
    final romanization = determineRomanization(phrase, selectedLanguageCode);
    List<String> phraseArray = romanization.split(' ');
    List<String> splitPhrases = [];
    final chunkSize = charactersPerRow - 1;
    for (var i = 0; i < phraseArray.length; i += chunkSize) {
      final chunk = phraseArray.sublist(
        i,
        i + chunkSize > phraseArray.length ? phraseArray.length : i + chunkSize,
      );
      splitPhrases.add(chunk.join(' '));
    }
    return splitPhrases;
  }

  static List<String> mergeParts(List<List<String>> combinedParts) {
    List<String> mergedParts = [];
    for (var i = 0; i < combinedParts.length; i++) {
      for (var j = 0; j < combinedParts[i].length; j++) {
        mergedParts.add(combinedParts[i][j]);
      }
    }
    return mergedParts;
  }

  static List<String> processLongPhrase(String phrase, int charactersPerRow) {
    List<String> splitPhrases = [];
    final sanitizedPhrase = phrase
        .trim()
        .replaceAll(" ", "")
        .replaceAll(".", "")
        .replaceAll(",", "")
        .replaceAll("!", "")
        .replaceAll("?", "");
    for (var i = 0; i < sanitizedPhrase.length;) {
      var subString = sanitizedPhrase.substring(i).length >= charactersPerRow
          ? sanitizedPhrase.substring(i, i + charactersPerRow - 1)
          : phrase.substring(i);
      splitPhrases.add(subString);
      i += charactersPerRow - 1;
    }
    return splitPhrases;
  }

  static bool isChinese(String character) {
    return RegExp(r'[\u4E00-\u9FFF]').hasMatch(character);
  }

  static String retrieveRomanization(
    String phrase,
    String languageCode, {
    bool showNumber = false,
    bool returnMultiple = false,
  }) {
    switch (languageCode) {
      case "zh_HK":
        return Utilities.retrieveJyutping(
          phrase,
          returnMultiple: returnMultiple,
        ).join(" ");
    }
    return "?";
  }

  /// Returns a list of romanization tokens aligned 1:1 with the input phrase's
  /// characters. For Chinese characters, this yields the jyutping for that
  /// character. For non-Chinese characters, the character itself is returned.
  static List<String> retrieveRomanizationTokensAligned(
    String phrase,
    String languageCode, {
    bool returnMultiple = false,
  }) {
    switch (languageCode) {
      case "zh_HK":
        final List<String> tokens = [];
        for (int i = 0; i < phrase.length; i++) {
          final String ch = phrase[i];
          if (isChinese(ch)) {
            final List<String> jyut = JyutpingHelper.getWholeJyutpingPhrase(
              ch,
              returnMultiple,
            );
            tokens.add(jyut.isNotEmpty ? jyut.first : "");
          } else {
            // For non-Chinese, keep alignment with an empty romanization token.
            tokens.add("");
          }
        }
        return tokens;
      default:
        return List<String>.generate(phrase.length, (index) => "?");
    }
  }
}
