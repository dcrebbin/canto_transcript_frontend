import 'package:flutter/material.dart';

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
    return Wrap(
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: List.generate(chinese.length, (index) {
        return Container(
          width: 50,
          color: Colors.black,
          child: Column(
            children: [
              Text(
                romanization[index],
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
              Text(
                chinese[index],
                style: const TextStyle(fontSize: 26, color: Colors.white),
              ),
            ],
          ),
        );
      }),
    );
  }
}
