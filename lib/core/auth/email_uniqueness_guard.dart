import '../../data/local/app_database.dart';
import 'supabase_auth_bridge.dart';

/// Garante que um e-mail de login não colida entre `personals` e `students`.
class EmailUniquenessGuard {
  EmailUniquenessGuard._();

  static String normalize(String email) => SupabaseAuthBridge.normEmail(email);

  /// Lança [ArgumentError] se o e-mail já existir noutro perfil ativo.
  static Future<void> assertLoginEmailAvailable(
    AppDatabase db, {
    required String email,
    String? excludePersonalId,
    String? excludeStudentId,
  }) async {
    final norm = normalize(email);
    if (norm.isEmpty) {
      throw ArgumentError('Informe um e-mail válido.');
    }

    for (final p in await db.select(db.personals).get()) {
      if (excludePersonalId != null && p.id == excludePersonalId) continue;
      if (normalize(p.email) == norm) {
        throw ArgumentError(
          'Este e-mail já está em uso por um personal. Use outro e-mail ou '
          'contacte o administrador.',
        );
      }
    }

    for (final s in await (db.select(
      db.students,
    )..where((t) => t.isArchived.equals(false))).get()) {
      if (excludeStudentId != null && s.id == excludeStudentId) continue;
      final em = s.email?.trim();
      if (em == null || em.isEmpty) continue;
      if (normalize(em) == norm) {
        throw ArgumentError(
          'Este e-mail já está em uso por um aluno. Use outro e-mail ou '
          'contacte o administrador.',
        );
      }
    }
  }

  /// Retorna o tipo de perfil que já usa o e-mail, ou null.
  static Future<String?> findProfileKindForEmail(
    AppDatabase db,
    String email, {
    String? excludePersonalId,
    String? excludeStudentId,
  }) async {
    final norm = normalize(email);
    if (norm.isEmpty) return null;

    for (final p in await db.select(db.personals).get()) {
      if (excludePersonalId != null && p.id == excludePersonalId) continue;
      if (normalize(p.email) == norm) return 'personal';
    }
    for (final s in await (db.select(
      db.students,
    )..where((t) => t.isArchived.equals(false))).get()) {
      if (excludeStudentId != null && s.id == excludeStudentId) continue;
      final em = s.email?.trim();
      if (em != null && normalize(em) == norm) return 'student';
    }
    return null;
  }
}
