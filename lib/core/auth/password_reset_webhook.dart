import 'dart:convert';
import 'dart:io';

/// Webhook opcional para envio de e-mail com a senha provisória após «Esqueci minha senha».
///
/// Configure na build: `--dart-define=PASSWORD_RESET_WEBHOOK_URL=https://seu-servidor/reset-mail`
///
/// O app envia `POST` JSON:
/// ```json
/// {
///   "to": "utilizador@dominio.com",
///   "new_password": "abcd1234",
///   "display_name": "Nome",
///   "account_kind": "personal" | "student",
///   "subject": "Personal Gym — nova senha provisória"
/// }
/// ```
///
/// Resposta `2xx` = considerado enviado com sucesso.
abstract final class PasswordResetWebhook {
  static const _url = String.fromEnvironment('PASSWORD_RESET_WEBHOOK_URL');

  static Future<bool> send({
    required String toEmail,
    required String newPassword,
    required String displayName,
    required String accountKind,
  }) async {
    final raw = _url.trim();
    if (raw.isEmpty) return false;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;

    final client = HttpClient();
    try {
      final req = await client.postUrl(uri).timeout(const Duration(seconds: 14));
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
      req.write(
        jsonEncode({
          'to': toEmail,
          'new_password': newPassword,
          'display_name': displayName,
          'account_kind': accountKind,
          'subject': 'Personal Gym — nova senha provisória',
        }),
      );
      final res = await req.close().timeout(const Duration(seconds: 14));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
