import 'package:flutter/material.dart';
import 'package:canto_transcripts_frontend/utilities/utilities.dart';
import 'package:pinyin/pinyin.dart';

class TransliterationRow extends StatelessWidget {
  const TransliterationRow({
    super.key,
    required this.chinese,
    required this.romanization,
  });
  final List<String> chinese;
  final List<String> romanization;

  @override
  Widget build(BuildContext context) {
    final List<Widget> cells = [];

    for (int i = 0; i < chinese.length;) {
      final String ch = chinese[i];
      final String traditionalChar =
          ChineseHelper.convertCharToTraditionalChinese(ch);
      final bool isChineseChar = Utilities.isChinese(ch);

      if (isChineseChar) {
        cells.add(
          Container(
            width: 50,
            color: Colors.black,
            child: Column(
              children: [
                Text(
                  i < romanization.length ? romanization[i] : '',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
                Text(
                  traditionalChar,
                  style: const TextStyle(fontSize: 26, color: Colors.white),
                ),
              ],
            ),
          ),
        );
        i += 1;
        continue;
      }

      int j = i;
      final StringBuffer englishChars = StringBuffer();
      final StringBuffer englishRoman = StringBuffer();
      while (j < chinese.length && !Utilities.isChinese(chinese[j])) {
        englishChars.write(chinese[j]);
        if (j < romanization.length) {
          englishRoman.write(romanization[j]);
        }
        j += 1;
      }

      cells.add(
        Container(
          height: 54,
          color: Colors.black,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                englishChars.toString(),
                style: const TextStyle(fontSize: 26, color: Colors.white),
              ),
            ],
          ),
        ),
      );
      i = j;
    }

    return Wrap(
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: cells,
    );
  }
}
