import 'dart:convert';

import 'package:http/http.dart' as http;

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

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (_apiKey.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer $_apiKey';
      }
      final body = jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'system',
            'content':
                'Você é um analista de performance em treinamento físico e escreve em português do Brasil. '
                'Quando o relatório incluir anamnese (secções 7a, 7b, 7c), integre essas respostas de forma explícita na análise de adesão e no plano de ação.',
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.35,
      });
      final res = await http
          .post(uri, headers: headers, body: body)
          .timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final responseText = res.body;
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
    }
  }
}
