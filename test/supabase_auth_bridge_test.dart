import 'package:flutter_test/flutter_test.dart';
import 'package:app_personal/core/auth/supabase_auth_bridge.dart';

void main() {
  group('SupabaseAuthBridge.normEmail', () {
    test('trim e lowercase', () {
      expect(
        SupabaseAuthBridge.normEmail('  User@Mail.COM  '),
        'user@mail.com',
      );
    });

    test('preserva e-mail já normalizado', () {
      expect(
        SupabaseAuthBridge.normEmail('aluno@teste.com'),
        'aluno@teste.com',
      );
    });
  });
}
