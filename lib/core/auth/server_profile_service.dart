import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_bootstrap.dart';

/// Snapshot de privilégios vindos do Postgres (RLS + JWT) — fonte autoritativa.
class ServerProfileSnapshot {
  const ServerProfileSnapshot({
    required this.profileKind,
    required this.profileId,
    required this.isAdmin,
    required this.accessTier,
    this.name,
    this.email,
    this.maxStudentsCap,
    this.anamneseCompleted = true,
    this.authUserId,
  });

  final String profileKind;
  final String profileId;
  final bool isAdmin;
  final String accessTier;
  final String? name;
  final String? email;
  final int? maxStudentsCap;
  final bool anamneseCompleted;
  final String? authUserId;

  bool get isPersonal => profileKind == 'personal';
  bool get isStudent => profileKind == 'student';
}

/// Busca perfil comercial/privilegios no servidor (não confia no SQLite local).
class ServerProfileService {
  ServerProfileService._();

  static SupabaseClient? get _client =>
      supabaseAppEnabled ? Supabase.instance.client : null;

  static Future<ServerProfileSnapshot?> fetchForAuthUser(
    String authUserId,
  ) async {
    final c = _client;
    if (c == null || authUserId.trim().isEmpty) return null;

    try {
      final personalRes = await c
          .from('personals')
          .select(
            'id, name, email, is_admin, access_tier, max_students_cap, auth_user_id',
          )
          .eq('auth_user_id', authUserId)
          .maybeSingle();
      if (personalRes != null) {
        final m = Map<String, dynamic>.from(personalRes as Map);
        return ServerProfileSnapshot(
          profileKind: 'personal',
          profileId: m['id'] as String,
          name: m['name'] as String?,
          email: m['email'] as String?,
          isAdmin: m['is_admin'] == true,
          accessTier: (m['access_tier'] as String?)?.trim().isNotEmpty == true
              ? m['access_tier'] as String
              : 'legacy',
          maxStudentsCap: m['max_students_cap'] == null
              ? null
              : (m['max_students_cap'] as num).toInt(),
          authUserId: m['auth_user_id'] as String?,
        );
      }

      final studentRes = await c
          .from('students')
          .select(
            'id, access_tier, anamnese_completed, auth_user_id, is_archived',
          )
          .eq('auth_user_id', authUserId)
          .maybeSingle();
      if (studentRes != null) {
        final m = Map<String, dynamic>.from(studentRes as Map);
        if (m['is_archived'] == true) return null;
        return ServerProfileSnapshot(
          profileKind: 'student',
          profileId: m['id'] as String,
          name: m['name'] as String?,
          email: m['email'] as String?,
          isAdmin: false,
          accessTier: (m['access_tier'] as String?)?.trim().isNotEmpty == true
              ? m['access_tier'] as String
              : 'legacy',
          anamneseCompleted: m['anamnese_completed'] != false,
          authUserId: m['auth_user_id'] as String?,
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
