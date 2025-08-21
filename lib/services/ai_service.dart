import 'dart:convert';
import 'package:injectable/injectable.dart';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

@lazySingleton
class AIService {
  final log = Logger('AIService');
  String aiEndpoint = "api/ai";
  String _openAiApiKey = '';
  String _serverApiKey = '';
  String _proxyUrl = '';

  AIService() {
    _openAiApiKey = dotenv.env['OPEN_AI_API_KEY'] ?? '';
    _serverApiKey = dotenv.env['SERVER_API_KEY'] ?? '';
    _proxyUrl = dotenv.env['PROXY_URL'] ?? '';
  }

  String getTextFromResponse(String response) {
    final jsonResponse = jsonDecode(response);
    print('jsonResponse: $jsonResponse');
    final output = jsonResponse['output'];
    final content = output[0]['content'];
    print('content: $content');
    final text = content[0]['text'];
    print('text: $text');
    return text;
  }

  Future<String> getTranslation(String text) async {
    try {
      final url = 'https://api.openai.com/v1/responses';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openAiApiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'input': text,
          'instructions':
              'Translate this Cantonese text into English. Only return the English translation, no other text.',
        }),
      );
      if (response.statusCode == 200) {
        return getTextFromResponse(response.body);
      } else {
        throw Exception('Failed to get translation: ${response.body}');
      }
    } catch (e) {
      print('error: $e');
      throw Exception('Failed to get translation: $e');
    }
  }
}
