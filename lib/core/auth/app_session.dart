import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/app_database.dart';
import 'server_profile_service.dart';

/// Quem está usando o app localmente (até haver login real).
enum SessionRole {
  /// Personal marcado como administrador — vê todos os alunos e registros.
  adminPersonal,

  /// Personal comum — só alunos que ele cadastrou ([StudentEntity.createdByPersonalId]).
  personalTrainer,

  /// Aluno — só o próprio cadastro e treinos.
  student,
}

/// Sessão persistida em [SharedPreferences] para filtrar dados por perfil.
class AppSession extends ChangeNotifier {
  static const _kRole = 'app_session_role';
  static const _kPersonalId = 'app_session_personal_id';
  static const _kStudentId = 'app_session_student_id';

  /// Após «Sair da conta»: o app exige login (e-mail + senha) antes do [MainShell].
  static const _kRequiresLocalRelogin = 'app_requires_local_relogin';

  SessionRole _role = SessionRole.adminPersonal;
  String? _personalId;
  String? _studentId;
  var _bootstrapped = false;
  var _requiresLocalRelogin = false;

  /// Personal com flag admin validada pelo servidor (não só SQLite local).
  bool _personalDbIsAdmin = false;

  /// Privilégios obtidos do Postgres com JWT (fonte autoritativa quando presente).
  ServerProfileSnapshot? _serverProfile;

  SessionRole get role => _role;
  String? get personalId => _personalId;
  String? get studentId => _studentId;

  ServerProfileSnapshot? get serverProfile => _serverProfile;

  /// Tier comercial do aluno: servidor > local.
  String? get authoritativeStudentAccessTier {
    if (!isStudent) return null;
    if (_serverProfile?.isStudent == true) return _serverProfile!.accessTier;
    return null;
  }

  /// Tier comercial do personal: servidor > local.
  String? get authoritativePersonalAccessTier {
    if (!isPersonalTrainer && !isAdminPersonal) return null;
    if (_serverProfile?.isPersonal == true) return _serverProfile!.accessTier;
    return null;
  }

  int? get authoritativePersonalMaxStudentsCap {
    if (_serverProfile?.isPersonal == true) {
      return _serverProfile!.maxStudentsCap;
    }
    return null;
  }

  bool get authoritativeAnamneseCompleted {
    if (_serverProfile?.isStudent == true) {
      return _serverProfile!.anamneseCompleted;
    }
    return true;
  }

  /// Quando true, o arranque deve mostrar a tela de login local em vez do shell.
  bool get requiresLocalRelogin => _requiresLocalRelogin;

  bool get isAdminPersonal => _role == SessionRole.adminPersonal;
  bool get isPersonalTrainer => _role == SessionRole.personalTrainer;
  bool get isStudent => _role == SessionRole.student;

  /// Administrador: papel explícito **ou** flag admin validada pelo servidor.
  bool get hasFullOrgAccess =>
      isAdminPersonal ||
      (isPersonalTrainer &&
          (_serverProfile?.isAdmin == true || _personalDbIsAdmin));

  void applyServerProfile(ServerProfileSnapshot? snapshot) {
    _serverProfile = snapshot;
    if (snapshot != null && snapshot.isPersonal) {
      _personalDbIsAdmin = snapshot.isAdmin;
    } else if (_role != SessionRole.personalTrainer) {
      _personalDbIsAdmin = false;
    }
    notifyListeners();
  }

  void clearServerProfile() {
    _serverProfile = null;
    if (_role != SessionRole.personalTrainer) {
      _personalDbIsAdmin = false;
    }
    notifyListeners();
  }

  /// Atualiza privilégios a partir do Postgres (JWT); SQLite só como fallback offline.
  Future<void> hydratePersonalAdminFlag(AppDatabase db) async {
    if (_role != SessionRole.personalTrainer) {
      if (_personalDbIsAdmin || _serverProfile != null) {
        _personalDbIsAdmin = false;
        _serverProfile = null;
        notifyListeners();
      }
      return;
    }
    final pid = _personalId;
    if (pid == null) {
      clearServerProfile();
      return;
    }

    final row = await (db.select(
      db.personals,
    )..where((x) => x.id.equals(pid))).getSingleOrNull();
    final authId = row?.authUserId?.trim();
    if (authId != null && authId.isNotEmpty) {
      final snap = await ServerProfileService.fetchForAuthUser(authId);
      if (snap != null && snap.profileId == pid) {
        applyServerProfile(snap);
        return;
      }
    }

    final next = row?.isAdmin ?? false;
    if (_personalDbIsAdmin != next || _serverProfile != null) {
      _serverProfile = null;
      _personalDbIsAdmin = next;
      notifyListeners();
    }
  }

  /// Aluno visto por admin, pelo personal que cadastrou ou pelo próprio aluno.
  bool canAccessStudent(StudentEntity student) {
    if (hasFullOrgAccess) return true;
    if (_role == SessionRole.personalTrainer) {
      final pid = _personalId;
      if (pid == null) return false;
      return student.createdByPersonalId == pid;
    }
    if (_role == SessionRole.student) {
      return student.id == _studentId;
    }
    return false;
  }

  /// Grupo visto por admin, pelo personal dono ou por compartilhamento explícito.
  bool canAccessWorkoutGroup(WorkoutGroupEntity group) {
    if (hasFullOrgAccess) return true;
    if (group.isShared) return true;
    if (_role == SessionRole.personalTrainer) {
      final pid = _personalId;
      if (pid == null) return false;
      return group.createdByPersonalId == null ||
          group.createdByPersonalId == pid;
    }
    return false;
  }

  Future<void> loadFromPrefs() async {
    final p = await SharedPreferences.getInstance();
    _requiresLocalRelogin = p.getBool(_kRequiresLocalRelogin) ?? false;
    if (_requiresLocalRelogin) {
      _role = SessionRole.adminPersonal;
      _personalId = null;
      _studentId = null;
      _personalDbIsAdmin = false;
      _serverProfile = null;
      notifyListeners();
      return;
    }
    final r = p.getInt(_kRole);
    if (r != null && r >= 0 && r < SessionRole.values.length) {
      _role = SessionRole.values[r];
    }
    _personalId = p.getString(_kPersonalId);
    _studentId = p.getString(_kStudentId);
    notifyListeners();
  }

  /// Encerra sessão local e marca que o próximo arranque exige login (e-mail + senha).
  Future<void> markLoggedOutRequiresRelogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRequiresLocalRelogin, true);
    await prefs.remove(_kRole);
    await prefs.remove(_kPersonalId);
    await prefs.remove(_kStudentId);
    _requiresLocalRelogin = true;
    _role = SessionRole.adminPersonal;
    _personalId = null;
    _studentId = null;
    _personalDbIsAdmin = false;
    _serverProfile = null;
    notifyListeners();
  }

  /// Após login com Supabase Auth e ligação ao perfil local.
  Future<void> completeAuthLogin({
    required SessionRole role,
    String? personalId,
    String? studentId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRequiresLocalRelogin, false);
    _requiresLocalRelogin = false;
    await setSession(role: role, personalId: personalId, studentId: studentId);
  }

  /// Legado: redireciona para [completeAuthLogin].
  @Deprecated('Use completeAuthLogin após Supabase Auth.')
  Future<void> completeLocalLoginAfterPasswordCheck({
    required SessionRole role,
    String? personalId,
    String? studentId,
  }) => completeAuthLogin(
    role: role,
    personalId: personalId,
    studentId: studentId,
  );

  Future<void> setSession({
    required SessionRole role,
    String? personalId,
    String? studentId,
  }) async {
    _role = role;
    _personalId = personalId;
    _studentId = studentId;
    if (role != SessionRole.personalTrainer && _personalDbIsAdmin) {
      _personalDbIsAdmin = false;
    }
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kRole, role.index);
    if (personalId != null) {
      await p.setString(_kPersonalId, personalId);
    } else {
      await p.remove(_kPersonalId);
    }
    if (studentId != null) {
      await p.setString(_kStudentId, studentId);
    } else {
      await p.remove(_kStudentId);
    }
    notifyListeners();
  }

  /// Primeira execução: exige login via Supabase Auth (sem auto-entrar como admin).
  Future<void> bootstrapIfNeeded(AppDatabase db) async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_kRequiresLocalRelogin) == true) {
      _requiresLocalRelogin = true;
      _role = SessionRole.adminPersonal;
      _personalId = null;
      _studentId = null;
      _personalDbIsAdmin = false;
      _serverProfile = null;
      notifyListeners();
      return;
    }
    if (p.containsKey(_kRole)) {
      await loadFromPrefs();
      return;
    }
    await markLoggedOutRequiresRelogin();
  }
}
