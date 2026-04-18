import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/app_database.dart';

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

  /// Personal com papel «Personal» na UI mas com [PersonalEntity.isAdmin] no SQLite —
  /// deve ver todos os alunos, catálogo e sync como administrador.
  bool _personalDbIsAdmin = false;

  SessionRole get role => _role;
  String? get personalId => _personalId;
  String? get studentId => _studentId;

  /// Quando true, o arranque deve mostrar a tela de login local em vez do shell.
  bool get requiresLocalRelogin => _requiresLocalRelogin;

  bool get isAdminPersonal => _role == SessionRole.adminPersonal;
  bool get isPersonalTrainer => _role == SessionRole.personalTrainer;
  bool get isStudent => _role == SessionRole.student;

  /// Administrador por papel **ou** personal com flag `is_admin` no cadastro (mesmo com papel «Personal»).
  bool get hasFullOrgAccess =>
      isAdminPersonal || (isPersonalTrainer && _personalDbIsAdmin);

  /// Atualiza [_personalDbIsAdmin] a partir do SQLite (chamar após boot, troca de sessão ou pull de personals).
  Future<void> hydratePersonalAdminFlag(AppDatabase db) async {
    if (_role != SessionRole.personalTrainer) {
      if (_personalDbIsAdmin) {
        _personalDbIsAdmin = false;
        notifyListeners();
      }
      return;
    }
    final pid = _personalId;
    if (pid == null) {
      if (_personalDbIsAdmin) {
        _personalDbIsAdmin = false;
        notifyListeners();
      }
      return;
    }
    final p = await (db.select(db.personals)..where((x) => x.id.equals(pid)))
        .getSingleOrNull();
    final next = p?.isAdmin ?? false;
    if (_personalDbIsAdmin != next) {
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

  Future<void> loadFromPrefs() async {
    final p = await SharedPreferences.getInstance();
    _requiresLocalRelogin = p.getBool(_kRequiresLocalRelogin) ?? false;
    if (_requiresLocalRelogin) {
      _role = SessionRole.adminPersonal;
      _personalId = null;
      _studentId = null;
      _personalDbIsAdmin = false;
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
    notifyListeners();
  }

  /// Após login local bem-sucedido na tela dedicada.
  Future<void> completeLocalLoginAfterPasswordCheck({
    required SessionRole role,
    String? personalId,
    String? studentId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRequiresLocalRelogin, false);
    _requiresLocalRelogin = false;
    await setSession(role: role, personalId: personalId, studentId: studentId);
  }

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

  /// Primeira execução: escolhe um admin ou o primeiro personal.
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
      notifyListeners();
      return;
    }
    if (p.containsKey(_kRole)) {
      await loadFromPrefs();
      return;
    }
    final personals = await (db.select(db.personals)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    if (personals.isEmpty) {
      await setSession(role: SessionRole.adminPersonal, personalId: null);
      return;
    }
    PersonalEntity? admin;
    for (final e in personals) {
      if (e.isAdmin) {
        admin = e;
        break;
      }
    }
    admin ??= personals.first;
    if (admin.isAdmin) {
      await setSession(
        role: SessionRole.adminPersonal,
        personalId: admin.id,
      );
    } else {
      await setSession(
        role: SessionRole.personalTrainer,
        personalId: admin.id,
      );
    }
  }

  /// Corrige prefs incoerentes que deixam a UI “vazia” sem apagar o SQLite:
  /// ex. papel `personalTrainer` sem [personalId] → [canAccessStudent] falha para todos
  /// e os streams do calendário/planejamento ficam permanentemente em erro (cache).
  Future<void> repairSessionIfInconsistent(AppDatabase db) async {
    if (_requiresLocalRelogin) return;
    if (_role == SessionRole.personalTrainer && _personalId == null) {
      final personals = await (db.select(db.personals)
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();
      if (personals.isEmpty) {
        await setSession(
          role: SessionRole.adminPersonal,
          personalId: null,
          studentId: _studentId,
        );
        return;
      }
      PersonalEntity? admin;
      for (final e in personals) {
        if (e.isAdmin) {
          admin = e;
          break;
        }
      }
      admin ??= personals.first;
      if (admin.isAdmin) {
        await setSession(
          role: SessionRole.adminPersonal,
          personalId: admin.id,
          studentId: _studentId,
        );
      } else {
        await setSession(
          role: SessionRole.personalTrainer,
          personalId: admin.id,
          studentId: _studentId,
        );
      }
      return;
    }
    if (_role == SessionRole.student && _studentId == null) {
      await setSession(
        role: SessionRole.adminPersonal,
        personalId: _personalId,
        studentId: null,
      );
    }
  }
}
