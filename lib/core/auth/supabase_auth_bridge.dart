import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/local/app_database.dart';
import '../../data/repositories/app_data_repository.dart';
import '../supabase/supabase_bootstrap.dart';
import 'app_session.dart';
import 'email_uniqueness_guard.dart';
import 'server_profile_service.dart';
import '../supabase/supabase_auth_service.dart';

/// Liga Supabase Auth (JWT) ao [AppSession] e aos perfis locais `personals` / `students`.
class SupabaseAuthBridge {
  SupabaseAuthBridge._();

  static String normEmail(String s) => s.trim().toLowerCase();

  static void ensureSupabaseAuthEnabled() {
    if (!supabaseAppEnabled) {
      throw StateError(
        'Supabase Auth não está configurado. Defina SUPABASE_ANON_KEY no build.',
      );
    }
  }

  static SupabaseClient get _client => Supabase.instance.client;

  /// Envia link seguro por e-mail (magic link / OTP). **Nunca gera senha no app.**
  static Future<void> sendSecureAccessLink(String email) async {
    ensureSupabaseAuthEnabled();
    await SupabaseAuthService.signInWithOtp(
      email: normEmail(email),
      redirectTo: SupabaseAuthService.authRedirectUrl,
    );
  }

  /// Recuperação de senha via link tokenizado do Supabase Auth.
  static Future<void> sendPasswordResetEmail(String email) async {
    ensureSupabaseAuthEnabled();
    final redirectTo = kIsWeb
        ? '${Uri.base.origin}/reset-password'
        : '${SupabaseAuthService.authRedirectUrl}?flow=recovery';
    await _client.auth.resetPasswordForEmail(
      normEmail(email),
      redirectTo: redirectTo,
    );
  }

  static Future<void> signInAndBindAppSession({
    required AppDatabase db,
    required AppSession session,
    required String email,
    required String password,
  }) async {
    ensureSupabaseAuthEnabled();
    final authRes = await SupabaseAuthService.signInWithEmail(
      email: email,
      password: password,
    );
    final authUid = authRes.user?.id ?? authRes.session?.user.id;
    if (authUid == null || authUid.isEmpty) {
      throw ArgumentError('Sessão Supabase inválida após login.');
    }
    await _bindAuthUidToAppSession(
      db: db,
      session: session,
      authUserId: authUid,
      email: email,
    );
  }

  static Future<bool> tryHydrateAppSessionFromSupabaseAuth({
    required AppDatabase db,
    required AppSession session,
  }) async {
    if (!supabaseAppEnabled) return false;
    final user = SupabaseAuthService.currentUser;
    final uid = user?.id;
    if (uid == null || uid.isEmpty) return false;
    try {
      await _bindAuthUidToAppSession(
        db: db,
        session: session,
        authUserId: uid,
        email: user?.email ?? '',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _bindAuthUidToAppSession({
    required AppDatabase db,
    required AppSession session,
    required String authUserId,
    required String email,
  }) async {
    final norm = normEmail(email);

    PersonalEntity? personal = await (db.select(
      db.personals,
    )..where((p) => p.authUserId.equals(authUserId))).getSingleOrNull();

    StudentEntity? student;
    if (personal == null) {
      student =
          await (db.select(db.students)..where(
                (s) =>
                    s.authUserId.equals(authUserId) &
                    s.isArchived.equals(false),
              ))
              .getSingleOrNull();
    }

    if (personal == null && student == null && norm.isNotEmpty) {
      for (final p in await db.select(db.personals).get()) {
        if (normEmail(p.email) == norm) {
          personal = p;
          break;
        }
      }
    }
    if (personal == null && student == null && norm.isNotEmpty) {
      for (final s in await (db.select(
        db.students,
      )..where((t) => t.isArchived.equals(false))).get()) {
        final em = s.email?.trim();
        if (em != null && normEmail(em) == norm) {
          student = s;
          break;
        }
      }
    }

    if (personal != null && student != null) {
      throw ArgumentError(
        'Conflito: personal e aluno com o mesmo e-mail no cadastro.',
      );
    }

    final now = DateTime.now();
    if (personal != null) {
      if (personal.authUserId != authUserId) {
        await (db.update(
          db.personals,
        )..where((p) => p.id.equals(personal!.id))).write(
          PersonalsCompanion(
            authUserId: Value(authUserId),
            updatedAt: Value(now),
          ),
        );
      }
      await _completePersonalSession(
        db: db,
        session: session,
        personal: personal,
        authUserId: authUserId,
      );
      return;
    }

    if (student != null) {
      if (student.authUserId != authUserId) {
        await (db.update(
          db.students,
        )..where((s) => s.id.equals(student!.id))).write(
          StudentsCompanion(
            authUserId: Value(authUserId),
            updatedAt: Value(now),
          ),
        );
      }
      await _completeStudentSession(
        db: db,
        session: session,
        student: student,
        authUserId: authUserId,
      );
      return;
    }

    throw ArgumentError(
      'Conta autenticada, mas nenhum personal/aluno está ligado a este e-mail. '
      'Peça ao administrador para cadastrar o perfil.',
    );
  }

  static Future<void> _completePersonalSession({
    required AppDatabase db,
    required AppSession session,
    required PersonalEntity personal,
    required String authUserId,
  }) async {
    final snap = await ServerProfileService.fetchForAuthUser(authUserId);
    if (snap != null && snap.isPersonal) {
      session.applyServerProfile(snap);
      await _syncPersonalFromServer(db, personal.id, snap);
      await session.completeAuthLogin(
        role: snap.isAdmin
            ? SessionRole.adminPersonal
            : SessionRole.personalTrainer,
        personalId: snap.profileId,
        studentId: null,
      );
      return;
    }
    await session.completeAuthLogin(
      role: personal.isAdmin
          ? SessionRole.adminPersonal
          : SessionRole.personalTrainer,
      personalId: personal.id,
      studentId: null,
    );
  }

  static Future<void> _completeStudentSession({
    required AppDatabase db,
    required AppSession session,
    required StudentEntity student,
    required String authUserId,
  }) async {
    final snap = await ServerProfileService.fetchForAuthUser(authUserId);
    if (snap != null && snap.isStudent) {
      session.applyServerProfile(snap);
      await _syncStudentFromServer(db, student.id, snap);
      await session.completeAuthLogin(
        role: SessionRole.student,
        personalId: null,
        studentId: snap.profileId,
      );
      return;
    }
    await session.completeAuthLogin(
      role: SessionRole.student,
      personalId: null,
      studentId: student.id,
    );
  }

  static Future<void> _syncPersonalFromServer(
    AppDatabase db,
    String personalId,
    ServerProfileSnapshot snap,
  ) async {
    await (db.update(
      db.personals,
    )..where((p) => p.id.equals(personalId))).write(
      PersonalsCompanion(
        isAdmin: Value(snap.isAdmin),
        accessTier: Value(snap.accessTier),
        maxStudentsCap: Value(snap.maxStudentsCap),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  static Future<void> _syncStudentFromServer(
    AppDatabase db,
    String studentId,
    ServerProfileSnapshot snap,
  ) async {
    await (db.update(db.students)..where((s) => s.id.equals(studentId))).write(
      StudentsCompanion(
        accessTier: Value(snap.accessTier),
        anamneseCompleted: Value(snap.anamneseCompleted),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  static Future<void> changePasswordForEmail({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    ensureSupabaseAuthEnabled();
    if (newPassword.length < 6) {
      throw ArgumentError('A nova senha deve ter pelo menos 6 caracteres.');
    }
    await SupabaseAuthService.signInWithEmail(
      email: email,
      password: currentPassword,
    );
    await SupabaseAuthService.updatePassword(newPassword);
  }

  static Future<String> emailForSession({
    required AppSession session,
    required AppDataRepository repo,
  }) async {
    if (session.isStudent) {
      final id = session.studentId;
      if (id == null) throw ArgumentError('Sessão de aluno inválida.');
      final row = await repo.getStudentById(id);
      final em = row?.email?.trim();
      if (em == null || em.isEmpty) {
        throw ArgumentError('Aluno sem e-mail de login cadastrado.');
      }
      return em;
    }
    final pid = session.personalId;
    if (pid == null) {
      throw ArgumentError('Sessão de personal inválida.');
    }
    final row = await repo.getPersonalById(pid);
    final em = row?.email.trim();
    if (em == null || em.isEmpty) {
      throw ArgumentError('Personal sem e-mail de login cadastrado.');
    }
    return em;
  }

  /// Valida e-mail único entre personals e students (app + regra espelhada no SQL).
  static Future<void> assertUniqueLoginEmail(
    AppDatabase db,
    String email, {
    String? excludePersonalId,
    String? excludeStudentId,
  }) => EmailUniquenessGuard.assertLoginEmailAvailable(
    db,
    email: email,
    excludePersonalId: excludePersonalId,
    excludeStudentId: excludeStudentId,
  );
}
