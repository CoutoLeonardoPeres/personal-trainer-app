import 'dart:convert';
import 'dart:io';

class FreeAiTrainingReportService {
  const FreeAiTrainingReportService._();

  static const _endpoint = String.fromEnvironment(
    'FREE_AI_REPORT_ENDPOINT',
    defaultValue: 'https://text.pollinations.ai/openai',
  );
  static const _model = String.fromEnvironment(
    'FREE_AI_REPORT_MODEL',
    defaultValue: 'openai',
  );
  static const _apiKey = String.fromEnvironment('FREE_AI_REPORT_API_KEY');

  static bool get isConfigured => _endpoint.trim().isNotEmpty;

  static Future<String?> enrichReport({
    required String prompt,
    Duration timeout = const Duration(seconds: 18),
  }) async {
    if (!isConfigured) return null;
    final uri = Uri.tryParse(_endpoint);
    if (uri == null) return null;

    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.postUrl(uri).timeout(timeout);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (_apiKey.trim().isNotEmpty) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_apiKey');
      }
      final body = jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'system',
            'content':
                'Você é um analista de performance em treinamento físico e escreve em português do Brasil.'
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.35,
      });
      req.write(body);
      final res = await req.close().timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final responseText = await utf8.decodeStream(res).timeout(timeout);
      if (responseText.trim().isEmpty) return null;
      final decoded = jsonDecode(responseText);
      final choices = decoded is Map ? decoded['choices'] : null;
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map) {
          final msg = first['message'];
          if (msg is Map && msg['content'] is String) {
            final content = (msg['content'] as String).trim();
            return content.isEmpty ? null : content;
          }
          final text = first['text'];
          if (text is String && text.trim().isNotEmpty) {
            return text.trim();
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
