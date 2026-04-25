import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/access/access_tiers.dart';
import '../../core/access/permission_service.dart';
import '../../core/auth/app_session.dart';
import '../../core/auth/password_reset_webhook.dart';
import '../../core/sync/sync_device_identity.dart';
import '../../core/utils/calendar_day_utils.dart';
import '../../core/utils/student_archive_display_utils.dart';
import '../../core/utils/muscle_group_utils.dart';
import '../../core/utils/reps_text_utils.dart';
import '../../domain/scoring.dart' as scoring;
import '../exercise_name_similarity.dart';
import '../local/app_database.dart';
import '../models/day_workout_performed_set.dart';
import '../models/exercise_session_comparison.dart';
import '../models/programmable_bundle.dart';
import '../models/week_schedule_row.dart';
import '../sync/remote_sync_service.dart';

const _uuid = Uuid();

void _syncTrace(String message) {
  developer.log(message, name: 'sync.trace');
}

String _generateProvisionalLocalPassword() {
  const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
  final rnd = Random.secure();
  return List.generate(10, (_) => chars[rnd.nextInt(chars.length)]).join();
}

/// Score de uma linha: séries feitas (soma carga×reps÷10) ou prescrito ou coluna gravada.
double _exerciseLineScoreFromRow(DayWorkoutExerciseEntity e) {
  final performed = DayWorkoutPerformedSetCodec.decode(e.performedSetsJson);
  if (performed.isNotEmpty) {
    return DayWorkoutPerformedSetCodec.totalExerciseScore(performed);
  }
  if (e.exerciseScore != null) return e.exerciseScore!;
  return scoring.prescribedExerciseLineScore(
    sets: e.sets,
    loadKg: e.loadKg ?? 0,
    reps: e.reps,
  );
}

bool _isDayWorkoutExerciseLineCompleted(DayWorkoutExerciseEntity e) {
  if (e.sets <= 0) return false;
  final performed = DayWorkoutPerformedSetCodec.decode(e.performedSetsJson);
  return performed.length >= e.sets;
}

/// Soma dos scores e quantidade de linhas **concluídas** (séries registadas conforme planejado).
({double sumScores, int completedCount}) _completedExerciseScoreAgg(
  List<DayWorkoutExerciseEntity> exercises,
) {
  var sum = 0.0;
  var n = 0;
  for (final e in exercises) {
    if (!_isDayWorkoutExerciseLineCompleted(e)) continue;
    n++;
    sum += _exerciseLineScoreFromRow(e);
  }
  return (sumScores: sum, completedCount: n);
}

/// Rendimento do treino concluído: usa [DayWorkoutEntity.workoutScore] gravado;
/// senão fórmula atual (só exercícios concluídos × nº concluídos × 10 ÷ min).
double _rendimentoPorMinuto({
  required DayWorkoutEntity w,
  required List<DayWorkoutExerciseEntity> exercises,
}) {
  final stored = w.workoutScore;
  if (stored != null) return stored;
  final agg = _completedExerciseScoreAgg(exercises);
  final sec = w.activeDurationSeconds > 0 ? w.activeDurationSeconds : 1;
  return scoring.workoutFinalScoreFromExerciseScores(
    exerciseScoresSum: agg.sumScores,
    activeDurationSeconds: sec,
    completedExerciseCount: agg.completedCount,
  );
}

/// Converte repetições do grupo (texto «12-15» ou legado inteiro) para o campo inteiro do planejamento/calendário.
int _repsIntFromWorkoutGroupLine(WorkoutGroupExerciseEntity line) {
  if (line.lastReps != null && line.lastReps! > 0) return line.lastReps!;
  final t = line.lastRepsText?.trim();
  if (t == null || t.isEmpty) return 0;
  final single = int.tryParse(t);
  if (single != null) return single;
  final range = RegExp(r'^(\d+)\s*[-–]\s*(\d+)\s*$').firstMatch(t);
  if (range != null) return int.parse(range.group(1)!);
  final m = RegExp(r'\d+').firstMatch(t);
  if (m != null) return int.parse(m.group(0)!);
  return 0;
}

String? _repsTextFromWorkoutGroupLine(WorkoutGroupExerciseEntity line) {
  final t = line.lastRepsText?.trim();
  if (t != null && t.isNotEmpty) return t;
  if (line.lastReps != null && line.lastReps! > 0) return '${line.lastReps}';
  return null;
}

Expression<bool> _dayWorkoutNotCancelled($DayWorkoutsTable t) =>
    t.status.equals('cancelled').not();

/// Treinos em execução ou já concluídos: não alinhar ao modelo do grupo em
/// [AppDataRepository.syncWorkoutGroupTemplateToScheduledFromDate].
/// `scheduled` e `programmed` são atualizados; `cancelled` também fica de fora.
Expression<bool> _dayWorkoutSubjectToGroupTemplateSync($DayWorkoutsTable w) =>
    w.status.equals('completed').not() &
    w.status.equals('cancelled').not() &
    w.status.equals('started').not();

List<WeekScheduleItemEntity> _weekScheduleItemsInTemplateMultisetOrder(
  List<WeekScheduleItemEntity> groupItemsSortedBySortOrder,
  List<WorkoutGroupExerciseEntity> templateLines,
) {
  final queues = <String, List<WeekScheduleItemEntity>>{};
  for (final it in groupItemsSortedBySortOrder) {
    queues.putIfAbsent(it.exerciseId, () => []).add(it);
  }
  final out = <WeekScheduleItemEntity>[];
  for (final line in templateLines) {
    final q = queues[line.exerciseId];
    if (q == null || q.isEmpty) return const [];
    out.add(q.removeAt(0));
  }
  for (final q in queues.values) {
    if (q.isNotEmpty) return const [];
  }
  return out;
}

List<DayWorkoutExerciseEntity> _dayWorkoutExercisesInTemplateMultisetOrder(
  List<DayWorkoutExerciseEntity> sortedLines,
  List<WorkoutGroupExerciseEntity> templateLines,
) {
  final queues = <String, List<DayWorkoutExerciseEntity>>{};
  for (final e in sortedLines) {
    queues.putIfAbsent(e.exerciseId, () => []).add(e);
  }
  final out = <DayWorkoutExerciseEntity>[];
  for (final line in templateLines) {
    final q = queues[line.exerciseId];
    if (q == null || q.isEmpty) return const [];
    out.add(q.removeAt(0));
  }
  for (final q in queues.values) {
    if (q.isNotEmpty) return const [];
  }
  return out;
}

/// Repositório central: toda mutação relevante grava primeiro no SQLite e em seguida
/// regista em [audit_logs] + [RemoteSyncService.enqueueAudit], que dispara o envio
/// incremental ao Supabase em segundo plano ([SupabaseRemoteSyncService]).
class AppDataRepository {
  AppDataRepository(this._db, this._session, {RemoteSyncService? remoteSync})
    : _remote = remoteSync ?? const NoOpRemoteSyncService() {
    _session.addListener(_clearReactiveStreamCaches);
  }

  final AppDatabase _db;
  final AppSession _session;
  bool _catalogRefreshInFlight = false;
  final RemoteSyncService _remote;

  /// Enquanto ativo, [refreshDayWorkoutFromCloud] não corre (evita pull a competir
  /// com gravação de séries e a repor JSON antigo da nuvem por cima do local).
  DateTime? _dayWorkoutCloudPullMutedUntil;

  /// Pausa pulls pontuais do treino na nuvem (ex.: com modal de série aberto).
  void muteDayWorkoutCloudPullFor(Duration duration) {
    final until = DateTime.now().add(duration);
    final cur = _dayWorkoutCloudPullMutedUntil;
    if (cur == null || until.isAfter(cur)) {
      _dayWorkoutCloudPullMutedUntil = until;
    }
  }

  /// O Drift reaproveita o mesmo [Stream] quando a query é idêntica ([StreamKey]).
  /// Usamos [asBroadcastStream] + último snapshot + [Stream.multi] para que cada
  /// novo ouvinte receba o estado atual (broadcast puro não reenvia o último evento).
  Stream<List<StudentEntity>>? _studentsRawBroadcast;
  List<StudentEntity>? _lastStudentsRaw;

  Stream<List<ExerciseEntity>>? _exercisesRawBroadcast;
  List<ExerciseEntity>? _lastExercisesRaw;

  Stream<List<WorkoutGroupEntity>>? _workoutGroupsInnerBroadcast;
  List<WorkoutGroupEntity>? _lastWorkoutGroups;

  Stream<List<({WorkoutGroupEntity group, int exerciseCount})>>?
  _workoutGroupsSchedulableInnerBroadcast;
  List<({WorkoutGroupEntity group, int exerciseCount})>? _lastSchedulable;

  /// [watch] por aluno+semana: broadcast por chave + último snapshot (replay para novos ouvintes).
  final Map<String, Stream<List<WeekScheduleRow>>> _weekScheduleInnerByKey = {};
  final Map<String, List<WeekScheduleRow>> _weekScheduleLastByKey = {};

  final Map<String, Stream<List<DayWorkoutEntity>>>
  _studentWeekWorkoutsInnerByKey = {};
  final Map<String, List<DayWorkoutEntity>> _studentWeekWorkoutsLastByKey = {};

  AppDatabase get db => _db;
  AppSession get session => _session;

  /// Ao mudar perfil (admin / personal / aluno), os streams em cache devem ser recriados;
  /// senão o primeiro erro de [requireStudentAccess] ou snapshot antigo fica preso para sempre.
  void _clearReactiveStreamCaches() {
    _weekScheduleInnerByKey.clear();
    _weekScheduleLastByKey.clear();
    _studentWeekWorkoutsInnerByKey.clear();
    _studentWeekWorkoutsLastByKey.clear();
    _studentsRawBroadcast = null;
    _lastStudentsRaw = null;
    _exercisesRawBroadcast = null;
    _lastExercisesRaw = null;
    _workoutGroupsInnerBroadcast = null;
    _lastWorkoutGroups = null;
    _workoutGroupsSchedulableInnerBroadcast = null;
    _lastSchedulable = null;
  }

  /// Remover o listener de [AppSession] antes de descartar o repositório.
  void dispose() {
    _session.removeListener(_clearReactiveStreamCaches);
  }

  Future<StudentEntity?> getStudentById(String id) {
    return (_db.select(
      _db.students,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  Future<PersonalEntity?> getPersonalById(String id) {
    return (_db.select(
      _db.personals,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  Stream<StudentEntity?> watchStudentById(String id) {
    return (_db.select(
      _db.students,
    )..where((s) => s.id.equals(id))).watch().map((rows) => rows.singleOrNull);
  }

  Stream<PersonalEntity?> watchPersonalById(String id) {
    return (_db.select(
      _db.personals,
    )..where((p) => p.id.equals(id))).watch().map((rows) => rows.singleOrNull);
  }

  Future<int> _countStudentsForPersonal(String personalId) async {
    final q = await (_db.select(
      _db.students,
    )..where((s) => s.createdByPersonalId.equals(personalId))).get();
    return q.length;
  }

  /// Só administrador: ajustar plano do aluno (RBAC).
  Future<void> adminSetStudentAccessTier({
    required String studentId,
    required String accessTier,
    DateTime? premiumPlanExpiresAt,
  }) async {
    if (!_session.hasFullOrgAccess) {
      throw ArgumentError(
        'Apenas administradores podem alterar o perfil de acesso.',
      );
    }
    await requireStudentAccess(studentId);
    final cur = await getStudentById(studentId);
    DateTime? expiry = premiumPlanExpiresAt;
    if (accessTier == AccessTiers.studentPremium) {
      expiry ??= cur?.premiumPlanExpiresAt;
    } else {
      expiry = null;
    }
    await (_db.update(
      _db.students,
    )..where((s) => s.id.equals(studentId))).write(
      StudentsCompanion(
        accessTier: Value(accessTier),
        premiumPlanExpiresAt: Value(expiry),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _audit(
      'admin_set_tier',
      'student',
      entityId: studentId,
      payload: {
        'access_tier': accessTier,
        'premium_plan_expires_at': expiry?.toIso8601String(),
      },
    );
  }

  /// Só administrador: ajustar plano do personal (RBAC).
  Future<void> adminSetPersonalAccessTier({
    required String personalId,
    required String accessTier,
    int? maxStudentsCap,
  }) async {
    if (!_session.hasFullOrgAccess) {
      throw ArgumentError(
        'Apenas administradores podem alterar o perfil de acesso.',
      );
    }
    await (_db.update(
      _db.personals,
    )..where((p) => p.id.equals(personalId))).write(
      PersonalsCompanion(
        accessTier: Value(accessTier),
        maxStudentsCap: Value(maxStudentsCap),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _audit(
      'admin_set_tier',
      'personal',
      entityId: personalId,
      payload: {'access_tier': accessTier, 'max_students_cap': maxStudentsCap},
    );
  }

  /// Downgrade automático: premium com data passada → [AccessTiers.studentStandard].
  Future<int> applyPremiumTierExpiryDowngrades() async {
    final now = DateTime.now();
    final rows = await (_db.select(
      _db.students,
    )..where((s) => s.accessTier.equals(AccessTiers.studentPremium))).get();
    var n = 0;
    for (final s in rows) {
      final exp = s.premiumPlanExpiresAt;
      if (exp == null || exp.isAfter(now)) continue;
      await (_db.update(_db.students)..where((x) => x.id.equals(s.id))).write(
        StudentsCompanion(
          accessTier: const Value(AccessTiers.studentStandard),
          premiumPlanExpiresAt: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _audit(
        'premium_expired_downgrade',
        'student',
        entityId: s.id,
        payload: {'from': AccessTiers.studentPremium},
      );
      n++;
    }
    return n;
  }

  /// Troca senha local (SQLite) para o perfil da sessão; limpa [mustChangePassword].
  Future<void> changePasswordForCurrentSession({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.length < 4) {
      throw ArgumentError('A nova senha deve ter pelo menos 4 caracteres.');
    }
    if (_session.isStudent) {
      final id = _session.studentId;
      if (id == null) throw ArgumentError('Sessão de aluno inválida.');
      final row = await getStudentById(id);
      if (row == null) throw ArgumentError('Aluno não encontrado.');
      final stored = row.passwordHash;
      if (stored != null && stored.isNotEmpty && stored != currentPassword) {
        throw ArgumentError('Senha atual incorreta.');
      }
      await (_db.update(_db.students)..where((s) => s.id.equals(id))).write(
        StudentsCompanion(
          passwordHash: Value(newPassword),
          mustChangePassword: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _audit('password_change', 'student', entityId: id);
      await _remote.mirrorStudentRowNow(id);
      return;
    }
    final pid = _session.personalId;
    if (pid == null) {
      throw ArgumentError(
        'Troca de senha local só para aluno ou personal com cadastro identificado.',
      );
    }
    final row = await getPersonalById(pid);
    if (row == null) throw ArgumentError('Personal não encontrado.');
    final stored = row.passwordHash;
    if (stored != null && stored.isNotEmpty && stored != currentPassword) {
      throw ArgumentError('Senha atual incorreta.');
    }
    await (_db.update(_db.personals)..where((p) => p.id.equals(pid))).write(
      PersonalsCompanion(
        passwordHash: Value(newPassword),
        mustChangePassword: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _audit('password_change', 'personal', entityId: pid);
    await _remote.mirrorPersonalRowNow(pid);
  }

  /// Gera senha provisória para **personal** ou **aluno ativo** com o e-mail indicado.
  /// Se existir [PASSWORD_RESET_WEBHOOK_URL], tenta notificar por e-mail via HTTP POST.
  /// Retorna se o webhook aceitou e a senha provisória (para exibir só se o e-mail não foi enviado).
  Future<({bool emailSent, String provisionalPassword})>
  requestPasswordResetForActiveLocalUser(String rawEmail) async {
    final email = rawEmail.trim().toLowerCase();
    if (email.isEmpty) {
      throw ArgumentError('Informe o e-mail.');
    }
    final personals = await _db.select(_db.personals).get();
    PersonalEntity? personal;
    for (final p in personals) {
      if (p.email.trim().toLowerCase() == email) {
        personal = p;
        break;
      }
    }
    final students = await (_db.select(
      _db.students,
    )..where((s) => s.isArchived.equals(false))).get();
    StudentEntity? student;
    for (final s in students) {
      final em = s.email?.trim();
      if (em == null || em.isEmpty) continue;
      if (em.toLowerCase() == email) {
        student = s;
        break;
      }
    }
    if (personal != null && student != null) {
      throw ArgumentError(
        'Conflito de e-mail no cadastro. Contacte o administrador.',
      );
    }
    if (personal == null && student == null) {
      throw ArgumentError(
        'Não encontrámos personal nem aluno ativo com este e-mail.',
      );
    }
    final newPass = _generateProvisionalLocalPassword();
    final now = DateTime.now();
    if (personal != null) {
      final pRow = personal;
      await (_db.update(
        _db.personals,
      )..where((x) => x.id.equals(pRow.id))).write(
        PersonalsCompanion(
          passwordHash: Value(newPass),
          mustChangePassword: const Value(true),
          updatedAt: Value(now),
        ),
      );
      await _audit('password_change', 'personal', entityId: pRow.id);
      await _remote.mirrorPersonalRowNow(pRow.id);
      final sent = await PasswordResetWebhook.send(
        toEmail: pRow.email.trim(),
        newPassword: newPass,
        displayName: pRow.name,
        accountKind: 'personal',
      );
      return (emailSent: sent, provisionalPassword: newPass);
    }
    final st = student!;
    await (_db.update(_db.students)..where((x) => x.id.equals(st.id))).write(
      StudentsCompanion(
        passwordHash: Value(newPass),
        mustChangePassword: const Value(true),
        updatedAt: Value(now),
      ),
    );
    await _audit('password_change', 'student', entityId: st.id);
    await _remote.mirrorStudentRowNow(st.id);
    final toAddr = (st.email ?? '').trim();
    final sent = await PasswordResetWebhook.send(
      toEmail: toAddr.isNotEmpty ? toAddr : email,
      newPassword: newPass,
      displayName: st.name,
      accountKind: 'student',
    );
    return (emailSent: sent, provisionalPassword: newPass);
  }

  /// Cadastro: nova senha provisória para aluno **ativo** (não arquivado).
  /// Tenta enviar por e-mail se houver webhook e e-mail cadastrado.
  Future<({String provisionalPassword, bool emailSent, String? loginEmail})>
  adminGenerateNewStudentPassword(String studentId) async {
    await requireStudentAccess(studentId);
    final st = await getStudentById(studentId);
    if (st == null) throw ArgumentError('Aluno não encontrado.');
    if (st.isArchived) {
      throw ArgumentError(
        'Reative o aluno inativo antes de gerar uma nova senha.',
      );
    }
    final newPass = _generateProvisionalLocalPassword();
    final now = DateTime.now();
    await (_db.update(
      _db.students,
    )..where((s) => s.id.equals(studentId))).write(
      StudentsCompanion(
        passwordHash: Value(newPass),
        mustChangePassword: const Value(true),
        updatedAt: Value(now),
      ),
    );
    await _audit('password_change', 'student', entityId: studentId);
    await _remote.mirrorStudentRowNow(studentId);
    final loginEmail = st.email?.trim();
    var sent = false;
    if (loginEmail != null && loginEmail.isNotEmpty) {
      sent = await PasswordResetWebhook.send(
        toEmail: loginEmail,
        newPassword: newPass,
        displayName: st.name,
        accountKind: 'student',
      );
    }
    return (
      provisionalPassword: newPass,
      emailSent: sent,
      loginEmail: (loginEmail == null || loginEmail.isEmpty)
          ? null
          : loginEmail,
    );
  }

  /// Cadastro: nova senha provisória para um personal (próprio cadastro ou org admin).
  Future<({String provisionalPassword, bool emailSent, String loginEmail})>
  adminGenerateNewPersonalPassword(String personalId) async {
    if (_session.isStudent) {
      throw ArgumentError('Sem permissão para alterar senhas de personais.');
    }
    if (_session.isPersonalTrainer && !_session.hasFullOrgAccess) {
      if (personalId != _session.personalId) {
        throw ArgumentError(
          'Só pode gerar senha para o seu próprio cadastro de personal.',
        );
      }
    }
    final row = await getPersonalById(personalId);
    if (row == null) throw ArgumentError('Personal não encontrado.');
    final newPass = _generateProvisionalLocalPassword();
    final now = DateTime.now();
    await (_db.update(
      _db.personals,
    )..where((p) => p.id.equals(personalId))).write(
      PersonalsCompanion(
        passwordHash: Value(newPass),
        mustChangePassword: const Value(true),
        updatedAt: Value(now),
      ),
    );
    await _audit('password_change', 'personal', entityId: personalId);
    await _remote.mirrorPersonalRowNow(personalId);
    final addr = row.email.trim();
    var sent = false;
    if (addr.isNotEmpty) {
      sent = await PasswordResetWebhook.send(
        toEmail: addr,
        newPassword: newPass,
        displayName: row.name,
        accountKind: 'personal',
      );
    }
    return (provisionalPassword: newPass, emailSent: sent, loginEmail: addr);
  }

  Future<void> requireStudentAccess(String studentId) async {
    if (_session.hasFullOrgAccess) return;
    final s = await getStudentById(studentId);
    if (s == null || !_session.canAccessStudent(s)) {
      throw ArgumentError('Sem permissão para acessar os dados deste aluno.');
    }
  }

  Future<void> _requireCadastroAccess() async {
    if (_session.isStudent) {
      final sid = _session.studentId;
      if (sid == null) {
        throw ArgumentError('Aluno sem identificação na sessão.');
      }
      final s = await getStudentById(sid);
      if (s == null) {
        throw ArgumentError('Cadastro de aluno não encontrado.');
      }
      final perms = PermissionService(session: _session, student: s);
      if (!perms.studentCadastroMuscleExerciseGymGroup) {
        throw ArgumentError(
          'Seu plano não inclui estes cadastros. Use apenas o calendário para treinos programados.',
        );
      }
      return;
    }
  }

  Future<void> _requirePlanningAccess() async {
    if (_session.isStudent) {
      final sid = _session.studentId;
      if (sid == null) {
        throw ArgumentError('Aluno sem identificação na sessão.');
      }
      final s = await getStudentById(sid);
      if (s == null) throw ArgumentError('Aluno não encontrado.');
      final perms = PermissionService(session: _session, student: s);
      if (!perms.canOpenPlanningTab) {
        throw ArgumentError(
          'Seu plano só permite usar treinos já programados pelo personal.',
        );
      }
      return;
    }
  }

  Future<DayWorkoutEntity?> _dayWorkoutRow(String id) {
    return (_db.select(
      _db.dayWorkouts,
    )..where((w) => w.id.equals(id))).getSingleOrNull();
  }

  Future<void> _requireAccessForDayWorkoutId(String dayWorkoutId) async {
    final w = await _dayWorkoutRow(dayWorkoutId);
    if (w == null) {
      throw ArgumentError('Treino não encontrado.');
    }
    await requireStudentAccess(w.studentId);
  }

  Future<void> _requireAccessForDayWorkoutLineId(String lineId) async {
    final row = await (_db.select(
      _db.dayWorkoutExercises,
    )..where((x) => x.id.equals(lineId))).getSingleOrNull();
    if (row == null) {
      throw ArgumentError('Linha de exercício não encontrada.');
    }
    await _requireAccessForDayWorkoutId(row.dayWorkoutId);
  }

  List<StudentEntity> _visibleStudents(List<StudentEntity> all) {
    // Nunca mostrar arquivados nas listas normais de UI.
    final visible = all.where((s) => !s.isArchived).toList();
    if (_session.hasFullOrgAccess) return visible;
    switch (_session.role) {
      case SessionRole.adminPersonal:
        return visible;
      case SessionRole.personalTrainer:
        final pid = _session.personalId;
        if (pid == null) return [];
        return visible.where((s) => s.createdByPersonalId == pid).toList();
      case SessionRole.student:
        final sid = _session.studentId;
        if (sid == null) return [];
        return visible.where((s) => s.id == sid).toList();
    }
  }

  /// Alunos arquivados visíveis ao perfil atual (para reativação no cadastro).
  List<StudentEntity> _archivedStudentsForSession(List<StudentEntity> all) {
    if (_session.hasFullOrgAccess) return all;
    switch (_session.role) {
      case SessionRole.adminPersonal:
        return all;
      case SessionRole.personalTrainer:
        final pid = _session.personalId;
        if (pid == null) return [];
        return all.where((s) => s.createdByPersonalId == pid).toList();
      case SessionRole.student:
        return [];
    }
  }

  Future<List<DayWorkoutEntity>> _visibleDayWorkouts(
    List<DayWorkoutEntity> raw,
  ) async {
    if (raw.isEmpty) return raw;
    final ids = raw.map((e) => e.studentId).toSet().toList();
    final students = await (_db.select(
      _db.students,
    )..where((s) => s.id.isIn(ids))).get();
    final byId = {for (final s in students) s.id: s};
    return raw.where((w) {
      final s = byId[w.studentId];
      if (s == null) return false;
      if (!_session.hasFullOrgAccess && !_session.canAccessStudent(s)) {
        return false;
      }
      final cal = weekScheduleLocalCalendarDate(w.dayDate);
      return isArchivedStudentWorkoutVisibleOnCalendarDay(
        isArchived: s.isArchived,
        archivedAt: s.archivedAt,
        workoutCalendarDay: cal,
      );
    }).toList();
  }

  Future<void> warmUp() async {
    await _db.customSelect('SELECT 1').get();
  }

  /// Alinha [AppSession.hasFullOrgAccess] com [PersonalEntity.isAdmin] no SQLite (papel «Personal» + flag admin).
  Future<void> refreshSessionPersonalAdminFlag() =>
      _session.hydratePersonalAdminFlag(_db);

  Future<void> _audit(
    String action,
    String entityType, {
    String? entityId,
    Map<String, Object?>? payload,
  }) async {
    final auditId = _uuid.v4();
    await _db
        .into(_db.auditLogs)
        .insert(
          AuditLogsCompanion.insert(
            id: auditId,
            action: action,
            entityType: entityType,
            entityId: Value(entityId),
            payloadJson: Value(payload == null ? null : jsonEncode(payload)),
          ),
        );
    unawaited(
      _remote.enqueueAudit(
        auditLogId: auditId,
        action: action,
        entityType: entityType,
        entityId: entityId,
        payload: payload,
      ),
    );
  }

  Future<String> _syncDeviceId() => SyncDeviceIdentity.getOrCreate();

  int _nextRevision(int current) => current < 0 ? 1 : current + 1;

  Stream<List<MuscleGroupEntity>> watchMuscleGroupsAlphabetical() {
    return (_db.select(
      _db.muscleGroups,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  Future<void> upsertMuscleGroup({String? id, required String name}) async {
    await _requireCadastroAccess();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Nome do grupo muscular não pode ser vazio.');
    }
    final norm = normalizeMuscleGroupName(trimmed);
    final existingRows = await _db.select(_db.muscleGroups).get();
    for (final g in existingRows) {
      if (normalizeMuscleGroupName(g.name) != norm) continue;
      if (id != null && g.id == id) continue;
      throw DuplicateMuscleGroupNameException(existingDisplayName: g.name);
    }

    final now = DateTime.now();
    final sid = id ?? _uuid.v4();
    await _db
        .into(_db.muscleGroups)
        .insertOnConflictUpdate(
          MuscleGroupsCompanion.insert(
            id: sid,
            name: trimmed,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _audit(
      id == null ? 'create' : 'update',
      'muscle_group',
      entityId: sid,
      payload: {'name': trimmed},
    );
  }

  Future<void> deleteMuscleGroup(String id) async {
    await _requireCadastroAccess();
    await (_db.delete(_db.muscleGroups)..where((t) => t.id.equals(id))).go();
    await _audit('delete', 'muscle_group', entityId: id);
  }

  Stream<List<ExerciseEntity>> _exercisesRawStreamWithReplay() {
    _exercisesRawBroadcast ??=
        (_db.select(
              _db.exercises,
            )..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .watch()
            .map((list) {
              if (list.isEmpty) {
                _triggerCatalogRefreshIfNeeded();
              }
              _lastExercisesRaw = list;
              return list;
            })
            .asBroadcastStream();

    return Stream.multi((controller) async {
      final last = _lastExercisesRaw;
      if (last != null) {
        controller.add(last);
      }
      await controller.addStream(_exercisesRawBroadcast!);
    });
  }

  Stream<List<ExerciseEntity>> watchExercisesAlphabetical() {
    return _exercisesRawStreamWithReplay();
  }

  Future<List<ExerciseEntity>> getExercisesByIds(
    Iterable<String> exerciseIds,
  ) async {
    final ids = exerciseIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) return const <ExerciseEntity>[];
    return (_db.select(_db.exercises)..where((e) => e.id.isIn(ids))).get();
  }

  void _triggerCatalogRefreshIfNeeded() {
    if (_catalogRefreshInFlight) return;
    _catalogRefreshInFlight = true;
    Future<void>.microtask(() async {
      try {
        await refreshExercisesCatalogFromCloud().timeout(
          const Duration(seconds: 3),
          onTimeout: () {},
        );
      } finally {
        _catalogRefreshInFlight = false;
      }
    });
  }

  Future<void> upsertExercise({
    String? id,
    required String name,
    required String muscleGroupId,
    String? videoUrl,
    String? alternativeNote,
    String? alternativeVideoUrl,
  }) async {
    await _requireCadastroAccess();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Nome do exercício não pode ser vazio.');
    }
    final existingRows = await _db.select(_db.exercises).get();
    final clash = findDuplicateExerciseByNormalizedName(
      trimmed,
      existingRows,
      excludeExerciseId: id,
    );
    if (clash != null) {
      throw DuplicateExerciseNameException(existingDisplayName: clash.name);
    }

    final now = DateTime.now();
    final sid = id ?? _uuid.v4();
    await _db
        .into(_db.exercises)
        .insertOnConflictUpdate(
          ExercisesCompanion.insert(
            id: sid,
            name: trimmed,
            muscleGroupId: muscleGroupId,
            videoUrl: Value(videoUrl),
            alternativeNote: Value(alternativeNote),
            alternativeVideoUrl: Value(alternativeVideoUrl),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _audit(id == null ? 'create' : 'update', 'exercise', entityId: sid);
  }

  /// Remove o exercício do catálogo e:
  /// • de **todos** os grupos de treino (template);
  /// • do planejamento semanal **a partir desta semana**;
  /// • do calendário em treinos com dia **≥ hoje** e status diferente de concluído/cancelado;
  /// • demais referências (semanas passadas, histórico) só na etapa final para satisfazer FK.
  Future<void> deleteExercise(String id) async {
    await _requireCadastroAccess();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekCutoff = normalizeMonday(today);

    final wgeList = await (_db.select(
      _db.workoutGroupExercises,
    )..where((t) => t.exerciseId.equals(id))).get();
    for (final row in wgeList) {
      await removeWorkoutGroupExerciseLine(row.id);
    }

    final weekFutureJoin =
        _db.select(_db.weekScheduleItems).join([
          innerJoin(
            _db.weekScheduleBlocks,
            _db.weekScheduleBlocks.id.equalsExp(_db.weekScheduleItems.blockId),
          ),
        ])..where(
          _db.weekScheduleItems.exerciseId.equals(id) &
              _db.weekScheduleBlocks.weekStartMonday.isBiggerOrEqualValue(
                weekCutoff,
              ),
        );
    final weekFutureRows = await weekFutureJoin.get();
    for (final row in weekFutureRows) {
      final item = row.readTable(_db.weekScheduleItems);
      try {
        await deleteWeekScheduleItem(item.id);
      } catch (_) {
        // Sem permissão ao aluno do bloco.
      }
    }

    final dweActiveJoin =
        _db.select(_db.dayWorkoutExercises).join([
          innerJoin(
            _db.dayWorkouts,
            _db.dayWorkouts.id.equalsExp(_db.dayWorkoutExercises.dayWorkoutId),
          ),
        ])..where(
          _db.dayWorkoutExercises.exerciseId.equals(id) &
              _db.dayWorkouts.dayDate.isBiggerOrEqualValue(today) &
              _db.dayWorkouts.status.equals('completed').not() &
              _db.dayWorkouts.status.equals('cancelled').not(),
        );
    final dweActiveRows = await dweActiveJoin.get();
    for (final row in dweActiveRows) {
      final line = row.readTable(_db.dayWorkoutExercises);
      final w = row.readTable(_db.dayWorkouts);
      try {
        await requireStudentAccess(w.studentId);
      } catch (_) {
        continue;
      }
      await (_db.delete(
        _db.dayWorkoutExercises,
      )..where((e) => e.id.equals(line.id))).go();
      await _audit('delete', 'day_workout_exercise', entityId: line.id);
    }

    final wiRemaining = await (_db.select(
      _db.weekScheduleItems,
    )..where((i) => i.exerciseId.equals(id))).get();
    for (final item in wiRemaining) {
      try {
        await deleteWeekScheduleItem(item.id);
      } catch (_) {}
    }

    final dweRemaining = await (_db.select(
      _db.dayWorkoutExercises,
    )..where((e) => e.exerciseId.equals(id))).get();
    for (final line in dweRemaining) {
      final w = await _dayWorkoutRow(line.dayWorkoutId);
      if (w == null) {
        await (_db.delete(
          _db.dayWorkoutExercises,
        )..where((e) => e.id.equals(line.id))).go();
        await _audit('delete', 'day_workout_exercise', entityId: line.id);
        continue;
      }
      try {
        await requireStudentAccess(w.studentId);
      } catch (_) {
        continue;
      }
      await (_db.delete(
        _db.dayWorkoutExercises,
      )..where((e) => e.id.equals(line.id))).go();
      await _audit('delete', 'day_workout_exercise', entityId: line.id);
    }

    await (_db.delete(_db.exercises)..where((t) => t.id.equals(id))).go();
    await _audit('delete', 'exercise', entityId: id);
  }

  Stream<List<GymEntity>> watchGymsAlphabetical() {
    return (_db.select(
      _db.gyms,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  Future<void> upsertGym({
    String? id,
    required String name,
    required String cnpj,
    required String street,
    required String number,
    String? complement,
    required String district,
    required String city,
    required String stateUf,
    required String cep,
  }) async {
    await _requireCadastroAccess();
    final now = DateTime.now();
    final sid = id ?? _uuid.v4();
    await _db
        .into(_db.gyms)
        .insertOnConflictUpdate(
          GymsCompanion.insert(
            id: sid,
            name: name,
            cnpj: cnpj,
            street: street,
            number: number,
            complement: Value(complement),
            district: district,
            city: city,
            stateUf: stateUf,
            cep: cep,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _audit(id == null ? 'create' : 'update', 'gym', entityId: sid);
  }

  Future<void> deleteGym(String id) async {
    await _requireCadastroAccess();
    await (_db.delete(_db.studentGyms)..where((t) => t.gymId.equals(id))).go();
    await (_db.delete(_db.gyms)..where((t) => t.id.equals(id))).go();
    await _audit('delete', 'gym', entityId: id);
  }

  Stream<List<PersonalEntity>> watchPersonalsAlphabetical() {
    switch (_session.role) {
      case SessionRole.adminPersonal:
        return (_db.select(
          _db.personals,
        )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
      case SessionRole.personalTrainer:
        final pid = _session.personalId;
        if (pid == null) return Stream.value([]);
        return (_db.select(_db.personals)
              ..where((p) => p.id.equals(pid))
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .watch();
      case SessionRole.student:
        final sid = _session.studentId;
        if (sid == null) return Stream.value([]);
        return (_db.select(
          _db.students,
        )..where((s) => s.id.equals(sid))).watch().asyncMap((rows) async {
          if (rows.isEmpty) return <PersonalEntity>[];
          final tid = rows.first.createdByPersonalId;
          if (tid == null) return <PersonalEntity>[];
          return (_db.select(_db.personals)
                ..where((p) => p.id.equals(tid))
                ..orderBy([(t) => OrderingTerm.asc(t.name)]))
              .get();
        });
    }
  }

  Future<void> upsertPersonal({
    String? id,
    required String name,
    required String cpf,
    required String professionalRegistry,
    required String street,
    required String number,
    String? complement,
    required String city,
    required String stateUf,
    String? cep,
    String? phoneCommercial,
    String? phoneMobile,
    required String email,
    bool mustChangePassword = true,
    String? passwordHash,
    bool? isAdmin,
  }) async {
    if (_session.isStudent) {
      throw ArgumentError('Sem permissão para alterar cadastro de personais.');
    }
    if (_session.isPersonalTrainer) {
      final pid = _session.personalId;
      if (id != null && id != pid) {
        throw ArgumentError(
          'Só pode editar o seu próprio cadastro de personal.',
        );
      }
      if (id == null) {
        throw ArgumentError('Personal não pode cadastrar novos personais.');
      }
    }
    final now = DateTime.now();
    final sid = id ?? _uuid.v4();
    final PersonalEntity? prevPersonal = id != null
        ? await (_db.select(
            _db.personals,
          )..where((p) => p.id.equals(sid))).getSingleOrNull()
        : null;
    final effectiveIsAdmin = isAdmin ?? prevPersonal?.isAdmin ?? false;
    final tier = prevPersonal?.accessTier ?? AccessTiers.legacy;
    final cap = prevPersonal?.maxStudentsCap;
    await _db
        .into(_db.personals)
        .insertOnConflictUpdate(
          PersonalsCompanion.insert(
            id: sid,
            name: name,
            cpf: cpf,
            professionalRegistry: professionalRegistry,
            street: street,
            number: number,
            complement: Value(complement),
            city: city,
            stateUf: stateUf,
            cep: Value(cep),
            phoneCommercial: Value(phoneCommercial),
            phoneMobile: Value(phoneMobile),
            email: email,
            mustChangePassword: Value(mustChangePassword),
            passwordHash: Value(passwordHash),
            isAdmin: Value(effectiveIsAdmin),
            accessTier: Value(tier),
            maxStudentsCap: Value(cap),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _audit(id == null ? 'create' : 'update', 'personal', entityId: sid);
    // TODO: integrar envio de e-mail com senha provisória (serviço backend).
  }

  Future<void> deletePersonal(String id) async {
    if (_session.isStudent) {
      throw ArgumentError('Sem permissão para excluir personais.');
    }
    if (_session.isPersonalTrainer) {
      if (id != _session.personalId) {
        throw ArgumentError(
          'Só pode excluir o seu próprio cadastro de personal.',
        );
      }
    }
    await (_db.delete(_db.personals)..where((t) => t.id.equals(id))).go();
    await _audit('delete', 'personal', entityId: id);
  }

  Stream<List<StudentEntity>> _studentsRawStreamWithReplay() {
    _studentsRawBroadcast ??=
        (_db.select(_db.students)
              ..where((t) => t.isArchived.equals(false))
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .watch()
            .map((list) {
              _lastStudentsRaw = list;
              return list;
            })
            .asBroadcastStream();

    return Stream.multi((controller) async {
      final last = _lastStudentsRaw;
      if (last != null) {
        controller.add(last);
      }
      await controller.addStream(_studentsRawBroadcast!);
    });
  }

  Stream<List<StudentEntity>> watchStudentsAlphabetical() {
    return _studentsRawStreamWithReplay().map(_visibleStudents);
  }

  /// Alunos inativos (arquivados) do SQLite — só para reativação em Cadastro › Alunos.
  Stream<List<StudentEntity>> watchArchivedStudentsAlphabetical() {
    return (_db.select(_db.students)
          ..where((t) => t.isArchived.equals(true))
          ..orderBy([
            (t) => OrderingTerm.desc(t.archivedAt),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .watch()
        .map(_archivedStudentsForSession);
  }

  /// Traz o aluno de volta às listas ativas; remove prefixos «(Inativo)» / legado «(Excluído)» do nome.
  /// A senha continua vazia até o personal definir uma nova no cadastro do aluno.
  Future<void> unarchiveStudent(String id) async {
    if (_session.isStudent) {
      throw ArgumentError('Sem permissão para reativar aluno.');
    }
    await requireStudentAccess(id);
    final prev = await getStudentById(id);
    if (prev == null) {
      throw ArgumentError('Aluno não encontrado.');
    }
    if (!prev.isArchived) {
      throw ArgumentError('Este aluno já está ativo.');
    }
    var newName = studentNameWithoutArchivePrefix(prev.name.trim());
    if (newName.isEmpty) {
      newName = 'Aluno';
    }
    final now = DateTime.now();
    await (_db.update(_db.students)..where((t) => t.id.equals(id))).write(
      StudentsCompanion(
        name: Value(newName),
        isArchived: const Value(false),
        archivedAt: const Value(null),
        mustChangePassword: const Value(true),
        updatedAt: Value(now),
      ),
    );
    await _audit(
      'update',
      'student',
      entityId: id,
      payload: {'archived': false},
    );
    await _remote.mirrorStudentRowNow(id);
  }

  /// Lista completa de alunos para trocar sessão (apenas admin); demais perfis usam a lista filtrada.
  Stream<List<StudentEntity>> watchStudentsForSessionPicker() {
    if (_session.hasFullOrgAccess) {
      return _studentsRawStreamWithReplay();
    }
    return watchStudentsAlphabetical();
  }

  Future<List<String>> gymIdsForStudent(String studentId) async {
    await requireStudentAccess(studentId);
    final rows = await (_db.select(
      _db.studentGyms,
    )..where((t) => t.studentId.equals(studentId))).get();
    return rows.map((e) => e.gymId).toList();
  }

  /// Retorna o id do aluno (útil após criação).
  Future<String> upsertStudent({
    String? id,
    required String name,
    String? email,
    String? goal,
    String? cpf,
    DateTime? birthDate,
    String? street,
    String? number,
    String? complement,
    String? district,
    String? city,
    String? stateUf,
    String? cep,
    String? phoneCommercial,
    String? phoneMobile,
    List<String> gymIds = const [],
    bool mustChangePassword = true,
    String? passwordHash,
  }) async {
    if (_session.isStudent) {
      if (id == null || id != _session.studentId) {
        throw ArgumentError('Sem permissão para alterar este cadastro.');
      }
    } else if (id != null) {
      await requireStudentAccess(id);
    } else if (_session.isPersonalTrainer && _session.personalId == null) {
      throw ArgumentError('Sessão de personal sem identificação.');
    }

    final now = DateTime.now();
    final sid = id ?? _uuid.v4();
    final StudentEntity? prev = id != null
        ? await (_db.select(
            _db.students,
          )..where((s) => s.id.equals(sid))).getSingleOrNull()
        : null;
    String? ownerId = prev?.createdByPersonalId;
    if (prev == null) {
      if (_session.isPersonalTrainer && !_session.hasFullOrgAccess) {
        ownerId = _session.personalId;
      } else if (_session.hasFullOrgAccess) {
        ownerId = null;
      }
    }

    if (prev == null && ownerId != null) {
      final String ownerPersonalId = ownerId;
      final personalRow = await (_db.select(
        _db.personals,
      )..where((p) => p.id.equals(ownerPersonalId))).getSingleOrNull();
      final cap = PermissionService(
        session: _session,
        personal: personalRow,
      ).personalMaxStudents;
      if (cap != null) {
        final n = await _countStudentsForPersonal(ownerPersonalId);
        if (n >= cap) {
          throw ArgumentError(
            'Limite de alunos do seu plano ($cap) atingido. Faça upgrade ou remova um aluno.',
          );
        }
      }
    }

    final bool anamneseOk;
    final String tier;
    if (prev == null) {
      anamneseOk = false;
      tier = AccessTiers.studentFree;
    } else {
      anamneseOk = prev.anamneseCompleted;
      tier = prev.accessTier;
    }

    await _db.transaction(() async {
      await _db
          .into(_db.students)
          .insertOnConflictUpdate(
            StudentsCompanion.insert(
              id: sid,
              name: name,
              email: Value(email),
              goal: Value(goal),
              cpf: Value(cpf),
              birthDate: Value(birthDate),
              street: Value(street),
              number: Value(number),
              complement: Value(complement),
              district: Value(district),
              city: Value(city),
              stateUf: Value(stateUf),
              cep: Value(cep),
              phoneCommercial: Value(phoneCommercial),
              phoneMobile: Value(phoneMobile),
              mustChangePassword: Value(mustChangePassword),
              passwordHash: Value(passwordHash),
              createdByPersonalId: Value(ownerId),
              anamneseCompleted: Value(anamneseOk),
              accessTier: Value(tier),
              premiumPlanExpiresAt: Value(prev?.premiumPlanExpiresAt),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await (_db.delete(
        _db.studentGyms,
      )..where((t) => t.studentId.equals(sid))).go();
      for (final gid in gymIds) {
        await _db
            .into(_db.studentGyms)
            .insert(StudentGymsCompanion.insert(studentId: sid, gymId: gid));
      }
    });
    await _audit(id == null ? 'create' : 'update', 'student', entityId: sid);
    return sid;
  }

  Future<void> deleteStudent(String id) async {
    if (_session.isStudent) {
      throw ArgumentError('Sem permissão para excluir aluno.');
    }
    await requireStudentAccess(id);

    final now = DateTime.now();
    final cutoffDay = DateTime(now.year, now.month, now.day);
    final cutoffMonday = normalizeMonday(cutoffDay);

    // 1) Apagar planejamento semanal do aluno a partir da data de exclusão (mantém passado).
    final futureBlocks =
        await (_db.select(_db.weekScheduleBlocks)..where(
              (b) =>
                  b.studentId.equals(id) &
                  b.weekStartMonday.isBiggerOrEqualValue(cutoffMonday),
            ))
            .get();
    final futureBlockIds = futureBlocks.map((b) => b.id).toList();
    final futureItems = futureBlockIds.isEmpty
        ? <WeekScheduleItemEntity>[]
        : await (_db.select(
            _db.weekScheduleItems,
          )..where((i) => i.blockId.isIn(futureBlockIds))).get();

    // 2) Apagar treinos do calendário (agendados/programados/em andamento) a partir da data de exclusão.
    final futureWorkouts =
        await (_db.select(_db.dayWorkouts)..where(
              (w) =>
                  w.studentId.equals(id) &
                  w.dayDate.isBiggerOrEqualValue(cutoffDay) &
                  (w.status.equals('scheduled') |
                      w.status.equals('programmed') |
                      w.status.equals('started')),
            ))
            .get();
    final futureWorkoutIds = futureWorkouts.map((w) => w.id).toList();
    final futureWorkoutLines = futureWorkoutIds.isEmpty
        ? <DayWorkoutExerciseEntity>[]
        : await (_db.select(
            _db.dayWorkoutExercises,
          )..where((e) => e.dayWorkoutId.isIn(futureWorkoutIds))).get();

    await _db.transaction(() async {
      for (final line in futureWorkoutLines) {
        await (_db.delete(
          _db.dayWorkoutExercises,
        )..where((e) => e.id.equals(line.id))).go();
      }
      for (final w in futureWorkouts) {
        await (_db.delete(
          _db.dayWorkouts,
        )..where((d) => d.id.equals(w.id))).go();
      }
      for (final it in futureItems) {
        await (_db.delete(
          _db.weekScheduleItems,
        )..where((i) => i.id.equals(it.id))).go();
      }
      for (final b in futureBlocks) {
        await (_db.delete(
          _db.weekScheduleBlocks,
        )..where((x) => x.id.equals(b.id))).go();
      }
      await (_db.delete(
        _db.studentGyms,
      )..where((t) => t.studentId.equals(id))).go();
      final prev = await (_db.select(
        _db.students,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      final label = prev?.name ?? 'Aluno';
      await (_db.update(_db.students)..where((t) => t.id.equals(id))).write(
        StudentsCompanion(
          name: Value('$kStudentArchivedNamePrefix$label'),
          isArchived: const Value(true),
          archivedAt: Value(DateTime.now()),
          email: const Value(null),
          goal: const Value(null),
          cpf: const Value(null),
          birthDate: const Value(null),
          street: const Value(null),
          number: const Value(null),
          complement: const Value(null),
          district: const Value(null),
          city: const Value(null),
          stateUf: const Value(null),
          cep: const Value(null),
          phoneCommercial: const Value(null),
          phoneMobile: const Value(null),
          mustChangePassword: const Value(true),
          passwordHash: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });

    // Auditoria para sync: filhas antes do pai.
    for (final line in futureWorkoutLines) {
      await _audit('delete', 'day_workout_exercise', entityId: line.id);
    }
    for (final w in futureWorkouts) {
      await _audit('delete', 'day_workout', entityId: w.id);
    }
    for (final it in futureItems) {
      await _audit('delete', 'week_schedule_item', entityId: it.id);
    }
    for (final b in futureBlocks) {
      await _audit('delete', 'week_schedule_block', entityId: b.id);
    }

    // Mantém treinos passados (histórico) e planejamento passado; remove o aluno.
    await _audit(
      'update',
      'student',
      entityId: id,
      payload: {'archived': true},
    );
    await _remote.mirrorStudentRowNow(id);
  }

  Stream<List<TrainingMethodEntity>> watchTrainingMethodsAlphabetical() {
    return (_db.select(
      _db.trainingMethods,
    )..orderBy([(t) => OrderingTerm.asc(t.method)])).watch();
  }

  Future<void> upsertTrainingMethod({
    String? id,
    required String method,
    required String description,
  }) async {
    await _requireCadastroAccess();
    final now = DateTime.now();
    final sid = id ?? _uuid.v4();
    await _db
        .into(_db.trainingMethods)
        .insertOnConflictUpdate(
          TrainingMethodsCompanion.insert(
            id: sid,
            method: method,
            description: description,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _audit(
      id == null ? 'create' : 'update',
      'training_method',
      entityId: sid,
    );
  }

  Future<void> deleteTrainingMethod(String id) async {
    await _requireCadastroAccess();
    await (_db.delete(_db.trainingMethods)..where((t) => t.id.equals(id))).go();
    await _audit('delete', 'training_method', entityId: id);
  }

  Stream<List<WorkoutGroupEntity>> watchWorkoutGroupsAlphabetical() {
    _workoutGroupsInnerBroadcast ??=
        (_db.select(_db.workoutGroups)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .watch()
            .map((list) {
              _lastWorkoutGroups = list;
              return list;
            })
            .asBroadcastStream();

    return Stream.multi((controller) async {
      final last = _lastWorkoutGroups;
      if (last != null) {
        controller.add(last);
      }
      await controller.addStream(_workoutGroupsInnerBroadcast!);
    });
  }

  Future<String> upsertWorkoutGroup({
    String? id,
    required String name,
    required String description,
  }) async {
    await _requireCadastroAccess();
    final now = DateTime.now();
    final sid = id ?? _uuid.v4();
    await _db
        .into(_db.workoutGroups)
        .insertOnConflictUpdate(
          WorkoutGroupsCompanion.insert(
            id: sid,
            name: name,
            description: description,
            createdAt: Value(now),
            updatedAt: Value(now),
            deletedAt: const Value(null),
          ),
        );
    await _audit(
      id == null ? 'create' : 'update',
      'workout_group',
      entityId: sid,
    );
    return sid;
  }

  /// Reordena o segmento de [week_schedule_items] deste grupo dentro do bloco para seguir
  /// a ordem de [templateLines] (multiset por [exerciseId]).
  Future<int> _mergeWeekBlockGroupSortOrderToTemplate({
    required String blockId,
    required String workoutGroupId,
    required List<WorkoutGroupExerciseEntity> templateLines,
  }) async {
    final groupItems =
        await (_db.select(_db.weekScheduleItems)..where(
              (i) =>
                  i.blockId.equals(blockId) &
                  i.sourceWorkoutGroupId.equals(workoutGroupId),
            ))
            .get();
    if (groupItems.isEmpty) return 0;
    groupItems.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final orderedGroup = _weekScheduleItemsInTemplateMultisetOrder(
      groupItems,
      templateLines,
    );
    if (orderedGroup.length != groupItems.length) return 0;

    final allSorted = await (_db.select(
      _db.weekScheduleItems,
    )..where((i) => i.blockId.equals(blockId))).get();
    allSorted.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final merged = <WeekScheduleItemEntity>[];
    var idx = 0;
    while (idx < allSorted.length) {
      final it = allSorted[idx];
      if (it.sourceWorkoutGroupId != workoutGroupId) {
        merged.add(it);
        idx++;
      } else {
        merged.addAll(orderedGroup);
        while (idx < allSorted.length &&
            allSorted[idx].sourceWorkoutGroupId == workoutGroupId) {
          idx++;
        }
      }
    }

    var updates = 0;
    final now = DateTime.now();
    for (var k = 0; k < merged.length; k++) {
      if (merged[k].sortOrder != k) {
        await (_db.update(
          _db.weekScheduleItems,
        )..where((i) => i.id.equals(merged[k].id))).write(
          WeekScheduleItemsCompanion(
            sortOrder: Value(k),
            updatedAt: Value(now),
          ),
        );
        await _audit('update', 'week_schedule_item', entityId: merged[k].id);
        updates++;
      }
    }
    return updates;
  }

  bool _calendarDateInWeekBlock(DateTime dayDateRaw, DateTime weekMondayView) {
    final d = weekScheduleLocalCalendarDate(dayDateRaw);
    final start = weekScheduleLocalCalendarDate(
      DateTime(weekMondayView.year, weekMondayView.month, weekMondayView.day),
    );
    final end = start.add(const Duration(days: 7));
    return !d.isBefore(start) && d.isBefore(end);
  }

  Future<void> _replaceDayWorkoutSnapshotFromWeekBundleRows({
    required String dayWorkoutId,
    required List<WeekScheduleRow> orderedRows,
  }) async {
    final sorted = List<WeekScheduleRow>.from(orderedRows)
      ..sort((a, b) => a.item.sortOrder.compareTo(b.item.sortOrder));
    final now = DateTime.now();
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.dayWorkoutExercises,
      )..where((e) => e.dayWorkoutId.equals(dayWorkoutId))).get();
      for (final e in existing) {
        await (_db.delete(
          _db.dayWorkoutExercises,
        )..where((x) => x.id.equals(e.id))).go();
        await _audit('delete', 'day_workout_exercise', entityId: e.id);
      }
      for (final r in sorted) {
        final i = r.item;
        final disp = weekScheduleRepsDisplay(i);
        final hint = repsHintIntFromText(disp) ?? i.reps;
        final newId = _uuid.v4();
        await _db
            .into(_db.dayWorkoutExercises)
            .insert(
              DayWorkoutExercisesCompanion.insert(
                id: newId,
                dayWorkoutId: dayWorkoutId,
                exerciseId: i.exerciseId,
                sortOrder: Value(i.sortOrder),
                sets: i.sets,
                reps: hint > 0 ? hint : i.reps,
                repsText: Value(disp.isEmpty ? null : disp),
                loadKg: Value(i.loadKg),
                restBetweenSetsSec: Value(i.restBetweenSetsSec),
                trainingMethodId: Value(i.trainingMethodId),
                comboId: Value(i.comboId),
              ),
            );
      }
      await (_db.update(_db.dayWorkouts)
            ..where((x) => x.id.equals(dayWorkoutId)))
          .write(DayWorkoutsCompanion(updatedAt: Value(now)));
      await _audit('update', 'day_workout', entityId: dayWorkoutId);
    });
  }

  Future<void> _cancelProgrammedOrScheduledDayWorkout(
    String dayWorkoutId, {
    bool detachSourceWorkoutGroup = false,
  }) async {
    final now = DateTime.now();
    final dwes = await (_db.select(
      _db.dayWorkoutExercises,
    )..where((e) => e.dayWorkoutId.equals(dayWorkoutId))).get();
    for (final d in dwes) {
      await (_db.delete(
        _db.dayWorkoutExercises,
      )..where((e) => e.id.equals(d.id))).go();
      await _audit('delete', 'day_workout_exercise', entityId: d.id);
    }
    await (_db.update(
      _db.dayWorkouts,
    )..where((x) => x.id.equals(dayWorkoutId))).write(
      DayWorkoutsCompanion(
        status: const Value('cancelled'),
        timerResumeAt: const Value(null),
        sourceWorkoutGroupId: detachSourceWorkoutGroup
            ? const Value(null)
            : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
    await _audit('update', 'day_workout', entityId: dayWorkoutId);
  }

  /// Após alterar o planejamento semanal, atualiza no calendário os treinos
  /// `programmed` ou `scheduled` do **mesmo aluno** na mesma semana do bloco e com o(s)
  /// mesmo(s) [sourceWorkoutGroupId], exceto treinos iniciados/concluídos/cancelados.
  ///
  /// [onlyWorkoutGroupId] nulo: todos os grupos presentes no bloco.
  Future<void> propagateWeekBlockProgrammedSnapshotsFromPlanning({
    required String blockId,
    String? onlyWorkoutGroupId,
  }) async {
    await _requirePlanningAccess();
    final block = await (_db.select(
      _db.weekScheduleBlocks,
    )..where((b) => b.id.equals(blockId))).getSingleOrNull();
    if (block == null) return;
    await requireStudentAccess(block.studentId);

    final weekMonday = normalizeMonday(
      weekScheduleLocalCalendarDate(block.weekStartMonday),
    );

    final Set<String> groupIds;
    if (onlyWorkoutGroupId != null && onlyWorkoutGroupId.trim().isNotEmpty) {
      groupIds = {onlyWorkoutGroupId.trim()};
    } else {
      final items = await (_db.select(
        _db.weekScheduleItems,
      )..where((i) => i.blockId.equals(blockId))).get();
      groupIds = {
        for (final i in items)
          if (i.sourceWorkoutGroupId != null &&
              i.sourceWorkoutGroupId!.trim().isNotEmpty)
            i.sourceWorkoutGroupId!.trim(),
      };
    }
    if (groupIds.isEmpty) return;

    final startPad = weekMonday.subtract(const Duration(days: 2));
    final endPad = weekMonday.add(const Duration(days: 9));

    for (final gid in groupIds) {
      final rows = await loadWeekScheduleRows(
        studentId: block.studentId,
        weekMonday: weekMonday,
      );
      final bundleRows = rows
          .where((r) => r.item.sourceWorkoutGroupId == gid)
          .toList();
      bundleRows.sort((a, b) => a.item.sortOrder.compareTo(b.item.sortOrder));

      final candidates =
          await (_db.select(_db.dayWorkouts)..where(
                (w) =>
                    w.studentId.equals(block.studentId) &
                    w.sourceWorkoutGroupId.equals(gid) &
                    (w.status.equals('programmed') |
                        w.status.equals('scheduled')) &
                    w.dayDate.isBiggerOrEqualValue(startPad) &
                    w.dayDate.isSmallerThanValue(endPad),
              ))
              .get();

      for (final w in candidates) {
        if (!_calendarDateInWeekBlock(w.dayDate, weekMonday)) continue;
        try {
          await requireStudentAccess(w.studentId);
        } catch (_) {
          continue;
        }
        if (bundleRows.isEmpty) {
          await _cancelProgrammedOrScheduledDayWorkout(w.id);
        } else {
          await _replaceDayWorkoutSnapshotFromWeekBundleRows(
            dayWorkoutId: w.id,
            orderedRows: bundleRows,
          );
        }
      }
    }
  }

  /// Alinha o **planejamento semanal** ([week_schedule_items]) e snapshots **programados**
  /// ou **agendados** (`scheduled`) no calendário ao modelo do grupo.
  ///
  /// Não altera treinos **iniciados**, **concluídos** nem **cancelados**. Para o calendário,
  /// só entram linhas com [DayWorkoutEntity.dayDate] ≥ [effectiveFrom] (dia civil local).
  ///
  /// Semanas passadas no planejamento também são alinhadas (qualquer bloco com
  /// [WeekScheduleItemEntity.sourceWorkoutGroupId] deste grupo).
  ///
  /// A ordem dos exercícios do grupo no planejamento e no calendário passa a seguir a ordem
  /// do cadastro do grupo (incluindo combinações com o mesmo [comboId] do modelo).
  Future<({int weekItemsUpdated, int dayExercisesUpdated})>
  syncWorkoutGroupTemplateToScheduledFromDate(
    String workoutGroupId,
    DateTime effectiveFrom,
  ) async {
    await _requireCadastroAccess();
    final header = await (_db.select(
      _db.workoutGroups,
    )..where((t) => t.id.equals(workoutGroupId))).getSingleOrNull();
    if (header == null || header.deletedAt != null) {
      return (weekItemsUpdated: 0, dayExercisesUpdated: 0);
    }
    final effectiveDay = DateTime(
      effectiveFrom.year,
      effectiveFrom.month,
      effectiveFrom.day,
    );

    var weekItemsUpdated = 0;
    var dayExercisesUpdated = 0;

    final lines =
        await (_db.select(_db.workoutGroupExercises)
              ..where((t) => t.workoutGroupId.equals(workoutGroupId))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    final templateCounts = <String, int>{};
    final templateQueues = <String, List<WorkoutGroupExerciseEntity>>{};
    for (final l in lines) {
      templateCounts[l.exerciseId] = (templateCounts[l.exerciseId] ?? 0) + 1;
      templateQueues.putIfAbsent(l.exerciseId, () => []).add(l);
    }

    JoinedSelectStatement<HasResultSet, dynamic> weekJoin() {
      return _db.select(_db.weekScheduleItems).join([
        innerJoin(
          _db.weekScheduleBlocks,
          _db.weekScheduleBlocks.id.equalsExp(_db.weekScheduleItems.blockId),
        ),
      ])..where(
        _db.weekScheduleItems.sourceWorkoutGroupId.equals(workoutGroupId),
      );
    }

    if (lines.isEmpty) {
      final emptyWeekRows = await weekJoin().get();
      for (final row in emptyWeekRows) {
        final item = row.readTable(_db.weekScheduleItems);
        final block = row.readTable(_db.weekScheduleBlocks);
        try {
          await requireStudentAccess(block.studentId);
        } catch (_) {
          continue;
        }
        await deleteWeekScheduleItem(item.id);
        weekItemsUpdated++;
      }

      final dayWsEmpty =
          await (_db.select(_db.dayWorkouts)..where(
                (w) =>
                    w.sourceWorkoutGroupId.equals(workoutGroupId) &
                    w.dayDate.isBiggerOrEqualValue(effectiveDay) &
                    _dayWorkoutSubjectToGroupTemplateSync(w),
              ))
              .get();
      final now = DateTime.now();
      for (final w in dayWsEmpty) {
        try {
          await requireStudentAccess(w.studentId);
        } catch (_) {
          continue;
        }
        final dwes = await (_db.select(
          _db.dayWorkoutExercises,
        )..where((e) => e.dayWorkoutId.equals(w.id))).get();
        for (final d in dwes) {
          await (_db.delete(
            _db.dayWorkoutExercises,
          )..where((e) => e.id.equals(d.id))).go();
          await _audit('delete', 'day_workout_exercise', entityId: d.id);
          dayExercisesUpdated++;
        }
        await (_db.update(
          _db.dayWorkouts,
        )..where((x) => x.id.equals(w.id))).write(
          DayWorkoutsCompanion(
            status: const Value('cancelled'),
            timerResumeAt: const Value(null),
            updatedAt: Value(now),
          ),
        );
        await _audit('update', 'day_workout', entityId: w.id);
      }

      if (weekItemsUpdated > 0 || dayExercisesUpdated > 0) {
        await _audit(
          'propagate_group_template',
          'workout_group',
          entityId: workoutGroupId,
          payload: {
            'weekItems': weekItemsUpdated,
            'dayExercises': dayExercisesUpdated,
            'emptyTemplate': true,
          },
        );
      }
      return (
        weekItemsUpdated: weekItemsUpdated,
        dayExercisesUpdated: dayExercisesUpdated,
      );
    }

    final weekRowsInitial = await weekJoin().get();
    for (final row in weekRowsInitial) {
      final item = row.readTable(_db.weekScheduleItems);
      final block = row.readTable(_db.weekScheduleBlocks);
      if ((templateCounts[item.exerciseId] ?? 0) > 0) continue;
      try {
        await requireStudentAccess(block.studentId);
      } catch (_) {
        continue;
      }
      await deleteWeekScheduleItem(item.id);
      weekItemsUpdated++;
    }

    final weekRowsAfterDelete = await weekJoin().get();
    // Para lidar com exercícios repetidos, sincroniza por MULTISET:
    // - Remove sobras quando o planejamento tem mais ocorrências do que o template.
    // - Atualiza métricas (sets/reps/carga/etc.) por ocorrência.
    // Em seguida, reordena o segmento do grupo no bloco para coincidir com a ordem do cadastro.
    final weekBlockIds = <String>{};
    for (final row in weekRowsAfterDelete) {
      weekBlockIds.add(row.readTable(_db.weekScheduleItems).blockId);
    }

    for (final blockId in weekBlockIds) {
      final block = await (_db.select(
        _db.weekScheduleBlocks,
      )..where((b) => b.id.equals(blockId))).getSingleOrNull();
      if (block == null) continue;
      try {
        await requireStudentAccess(block.studentId);
      } catch (_) {
        continue;
      }
      final groupItems =
          await (_db.select(_db.weekScheduleItems)..where(
                (i) =>
                    i.blockId.equals(blockId) &
                    i.sourceWorkoutGroupId.equals(workoutGroupId),
              ))
              .get();
      groupItems.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      final remaining = <String, int>{...templateCounts};
      final queues = <String, List<WorkoutGroupExerciseEntity>>{};
      for (final entry in templateQueues.entries) {
        queues[entry.key] = List<WorkoutGroupExerciseEntity>.from(entry.value);
      }

      // 1) Atualiza ocorrências existentes e remove sobras
      for (final item in groupItems) {
        final left = remaining[item.exerciseId] ?? 0;
        if (left <= 0) {
          await deleteWeekScheduleItem(item.id);
          weekItemsUpdated++;
          continue;
        }
        remaining[item.exerciseId] = left - 1;
        final q = queues[item.exerciseId];
        final template = (q != null && q.isNotEmpty) ? q.removeAt(0) : null;
        if (template == null) continue;
        final sets = template.lastSets ?? 0;
        final reps = _repsIntFromWorkoutGroupLine(template);
        final needsDetail = sets <= 0 || reps <= 0;
        final rtw = _repsTextFromWorkoutGroupLine(template);
        await (_db.update(
          _db.weekScheduleItems,
        )..where((i) => i.id.equals(item.id))).write(
          WeekScheduleItemsCompanion(
            sets: Value(sets),
            reps: Value(reps),
            repsText: Value(rtw),
            loadKg: Value(template.lastLoadKg),
            needsDetail: Value(needsDetail),
            restBetweenSetsSec: Value(template.restBetweenSetsSec),
            trainingMethodId: Value(template.trainingMethodId),
            comboId: Value(template.comboId),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await _audit('update', 'week_schedule_item', entityId: item.id);
        weekItemsUpdated++;
      }

      // 2) Insere ocorrências faltantes (no fim do bloco, mantendo ordem atual do planejamento)
      final allBlockItems = await (_db.select(
        _db.weekScheduleItems,
      )..where((i) => i.blockId.equals(blockId))).get();
      var maxO = -1;
      for (final it in allBlockItems) {
        if (it.sortOrder > maxO) maxO = it.sortOrder;
      }
      for (final line in lines) {
        final left = remaining[line.exerciseId] ?? 0;
        if (left <= 0) continue;
        remaining[line.exerciseId] = left - 1;
        maxO++;
        final sets = line.lastSets ?? 0;
        final reps = _repsIntFromWorkoutGroupLine(line);
        final needsDetail = sets <= 0 || reps <= 0;
        final rtw = _repsTextFromWorkoutGroupLine(line);
        final newId = _uuid.v4();
        await _db
            .into(_db.weekScheduleItems)
            .insert(
              WeekScheduleItemsCompanion.insert(
                id: newId,
                blockId: blockId,
                exerciseId: line.exerciseId,
                sourceWorkoutGroupId: Value(workoutGroupId),
                sortOrder: Value(maxO),
                sets: Value(sets),
                reps: Value(reps),
                repsText: Value(rtw),
                loadKg: Value(line.lastLoadKg),
                needsDetail: Value(needsDetail),
                restBetweenSetsSec: Value(line.restBetweenSetsSec),
                trainingMethodId: Value(line.trainingMethodId),
                comboId: Value(line.comboId),
              ),
            );
        await _audit('update', 'week_schedule_item', entityId: newId);
        weekItemsUpdated++;
      }

      weekItemsUpdated += await _mergeWeekBlockGroupSortOrderToTemplate(
        blockId: blockId,
        workoutGroupId: workoutGroupId,
        templateLines: lines,
      );
    }

    final dayWorkouts =
        await (_db.select(_db.dayWorkouts)..where(
              (w) =>
                  w.sourceWorkoutGroupId.equals(workoutGroupId) &
                  w.dayDate.isBiggerOrEqualValue(effectiveDay) &
                  _dayWorkoutSubjectToGroupTemplateSync(w),
            ))
            .get();

    for (final w in dayWorkouts) {
      try {
        await requireStudentAccess(w.studentId);
      } catch (_) {
        continue;
      }
      var workoutTouched = false;

      var dweList = await (_db.select(
        _db.dayWorkoutExercises,
      )..where((e) => e.dayWorkoutId.equals(w.id))).get();
      dweList.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      final remaining = <String, int>{...templateCounts};
      final queues = <String, List<WorkoutGroupExerciseEntity>>{};
      for (final entry in templateQueues.entries) {
        queues[entry.key] = List<WorkoutGroupExerciseEntity>.from(entry.value);
      }

      for (final dwe in dweList) {
        final left = remaining[dwe.exerciseId] ?? 0;
        if (left <= 0) {
          await (_db.delete(
            _db.dayWorkoutExercises,
          )..where((e) => e.id.equals(dwe.id))).go();
          await _audit('delete', 'day_workout_exercise', entityId: dwe.id);
          dayExercisesUpdated++;
          workoutTouched = true;
          continue;
        }
        remaining[dwe.exerciseId] = left - 1;
        final q = queues[dwe.exerciseId];
        final template = (q != null && q.isNotEmpty) ? q.removeAt(0) : null;
        if (template == null) continue;
        final sets = template.lastSets ?? 0;
        final reps = _repsIntFromWorkoutGroupLine(template);
        if (sets <= 0 || reps <= 0) continue;
        await (_db.update(
          _db.dayWorkoutExercises,
        )..where((e) => e.id.equals(dwe.id))).write(
          DayWorkoutExercisesCompanion(
            sets: Value(sets),
            reps: Value(reps),
            repsText: Value(_repsTextFromWorkoutGroupLine(template)),
            loadKg: Value(template.lastLoadKg),
            restBetweenSetsSec: Value(template.restBetweenSetsSec),
            trainingMethodId: Value(template.trainingMethodId),
            comboId: Value(template.comboId),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await _audit('update', 'day_workout_exercise', entityId: dwe.id);
        dayExercisesUpdated++;
        workoutTouched = true;
      }

      var maxO = -1;
      for (final r in dweList) {
        if (r.sortOrder > maxO) maxO = r.sortOrder;
      }
      for (final line in lines) {
        final left = remaining[line.exerciseId] ?? 0;
        if (left <= 0) continue;
        remaining[line.exerciseId] = left - 1;
        maxO++;
        final sets = line.lastSets ?? 0;
        final reps = _repsIntFromWorkoutGroupLine(line);
        if (sets <= 0 || reps <= 0) continue;
        final newId = _uuid.v4();
        await _db
            .into(_db.dayWorkoutExercises)
            .insert(
              DayWorkoutExercisesCompanion.insert(
                id: newId,
                dayWorkoutId: w.id,
                exerciseId: line.exerciseId,
                sortOrder: Value(maxO),
                sets: sets,
                reps: reps,
                repsText: Value(_repsTextFromWorkoutGroupLine(line)),
                loadKg: Value(line.lastLoadKg),
                restBetweenSetsSec: Value(line.restBetweenSetsSec),
                trainingMethodId: Value(line.trainingMethodId),
                comboId: Value(line.comboId),
              ),
            );
        await _audit('update', 'day_workout_exercise', entityId: newId);
        dayExercisesUpdated++;
        workoutTouched = true;
      }

      dweList = await (_db.select(
        _db.dayWorkoutExercises,
      )..where((e) => e.dayWorkoutId.equals(w.id))).get();
      dweList.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final orderedDwe = _dayWorkoutExercisesInTemplateMultisetOrder(
        dweList,
        lines,
      );
      if (orderedDwe.length == dweList.length && orderedDwe.isNotEmpty) {
        final nowRen = DateTime.now();
        for (var i = 0; i < orderedDwe.length; i++) {
          final e = orderedDwe[i];
          if (e.sortOrder != i) {
            await (_db.update(
              _db.dayWorkoutExercises,
            )..where((x) => x.id.equals(e.id))).write(
              DayWorkoutExercisesCompanion(
                sortOrder: Value(i),
                updatedAt: Value(nowRen),
              ),
            );
            await _audit('update', 'day_workout_exercise', entityId: e.id);
            dayExercisesUpdated++;
            workoutTouched = true;
          }
        }
      }

      if (workoutTouched) {
        await (_db.update(_db.dayWorkouts)..where((x) => x.id.equals(w.id)))
            .write(DayWorkoutsCompanion(updatedAt: Value(DateTime.now())));
        await _audit('update', 'day_workout', entityId: w.id);
      }
    }

    if (weekItemsUpdated > 0 || dayExercisesUpdated > 0) {
      await _audit(
        'propagate_group_template',
        'workout_group',
        entityId: workoutGroupId,
        payload: {
          'weekItems': weekItemsUpdated,
          'dayExercises': dayExercisesUpdated,
        },
      );
    }

    return (
      weekItemsUpdated: weekItemsUpdated,
      dayExercisesUpdated: dayExercisesUpdated,
    );
  }

  /// Mesmo que [syncWorkoutGroupTemplateToScheduledFromDate] com data/hora atuais.
  Future<({int weekItemsUpdated, int dayExercisesUpdated})>
  propagateWorkoutGroupTemplateFromNow(String workoutGroupId) async {
    return syncWorkoutGroupTemplateToScheduledFromDate(
      workoutGroupId,
      DateTime.now(),
    );
  }

  Future<void> deleteWorkoutGroup(String id) async {
    await _requireCadastroAccess();
    final existing = await (_db.select(
      _db.workoutGroups,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null || existing.deletedAt != null) return;

    final now = DateTime.now();
    final today = weekScheduleLocalCalendarDate(
      DateTime(now.year, now.month, now.day),
    );

    await _db.transaction(() async {
      final weekItems = await (_db.select(
        _db.weekScheduleItems,
      )..where((i) => i.sourceWorkoutGroupId.equals(id))).get();
      for (final it in weekItems) {
        await (_db.update(
          _db.weekScheduleItems,
        )..where((i) => i.id.equals(it.id))).write(
          WeekScheduleItemsCompanion(
            sourceWorkoutGroupId: const Value(null),
            updatedAt: Value(now),
          ),
        );
        await _audit('update', 'week_schedule_item', entityId: it.id);
      }

      final dws = await (_db.select(
        _db.dayWorkouts,
      )..where((w) => w.sourceWorkoutGroupId.equals(id))).get();
      for (final w in dws) {
        try {
          await requireStudentAccess(w.studentId);
        } catch (_) {
          continue;
        }
        final dayOnly = weekScheduleLocalCalendarDate(w.dayDate);
        final keepGroupRef = w.status == 'completed' && dayOnly.isBefore(today);
        if (keepGroupRef) continue;

        if (w.status == 'programmed' || w.status == 'scheduled') {
          await _cancelProgrammedOrScheduledDayWorkout(
            w.id,
            detachSourceWorkoutGroup: true,
          );
        } else {
          await (_db.update(
            _db.dayWorkouts,
          )..where((x) => x.id.equals(w.id))).write(
            DayWorkoutsCompanion(
              sourceWorkoutGroupId: const Value(null),
              updatedAt: Value(now),
            ),
          );
          await _audit('update', 'day_workout', entityId: w.id);
        }
      }

      await (_db.delete(
        _db.workoutGroupExercises,
      )..where((t) => t.workoutGroupId.equals(id))).go();

      await (_db.update(
        _db.workoutGroups,
      )..where((t) => t.id.equals(id))).write(
        WorkoutGroupsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    });
    await _audit('delete', 'workout_group', entityId: id);
  }

  Stream<List<WorkoutGroupExerciseEntity>> watchGroupExercises(String groupId) {
    return (_db.select(_db.workoutGroupExercises)
          ..where((t) => t.workoutGroupId.equals(groupId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// Adiciona um exercício no modelo do grupo.
  /// O mesmo [exerciseId] pode aparecer mais de uma vez (variações de séries/reps/carga).
  Future<bool> addExerciseToWorkoutGroup({
    required String workoutGroupId,
    required String exerciseId,
    int? lastReps,
    int? lastSets,
    double? lastLoadKg,
    String? lastRepsText,
  }) async {
    await _requireCadastroAccess();
    final header = await (_db.select(
      _db.workoutGroups,
    )..where((t) => t.id.equals(workoutGroupId))).getSingleOrNull();
    if (header == null || header.deletedAt != null) return false;

    final rows = await (_db.select(
      _db.workoutGroupExercises,
    )..where((t) => t.workoutGroupId.equals(workoutGroupId))).get();
    var maxOrder = -1;
    for (final r in rows) {
      if (r.sortOrder > maxOrder) maxOrder = r.sortOrder;
    }
    final nextOrder = maxOrder + 1;
    await _db
        .into(_db.workoutGroupExercises)
        .insert(
          WorkoutGroupExercisesCompanion.insert(
            id: _uuid.v4(),
            workoutGroupId: workoutGroupId,
            exerciseId: exerciseId,
            sortOrder: Value(nextOrder),
            lastReps: Value(lastReps),
            lastSets: Value(lastSets ?? 3),
            lastLoadKg: Value(lastLoadKg),
            lastRepsText: Value(lastRepsText ?? '12-15'),
          ),
        );
    await _audit('add_exercise', 'workout_group', entityId: workoutGroupId);
    return true;
  }

  Future<void> updateWorkoutGroupExerciseLine({
    required String lineId,
    required int lastSets,
    required String lastRepsText,
    double? lastLoadKg,
    required int restBetweenSetsSec,
    String? trainingMethodId,
  }) async {
    await _requireCadastroAccess();
    await (_db.update(
      _db.workoutGroupExercises,
    )..where((t) => t.id.equals(lineId))).write(
      WorkoutGroupExercisesCompanion(
        lastSets: Value(lastSets),
        lastRepsText: Value(lastRepsText.trim()),
        lastLoadKg: Value(lastLoadKg),
        lastReps: const Value(null),
        restBetweenSetsSec: Value(restBetweenSetsSec),
        trainingMethodId: Value(trainingMethodId),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _audit('update', 'workout_group_exercise', entityId: lineId);
    final row = await (_db.select(
      _db.workoutGroupExercises,
    )..where((t) => t.id.equals(lineId))).getSingleOrNull();
    final cid = row?.comboId?.trim();
    if (row != null && cid != null && cid.isNotEmpty) {
      await _normalizeWorkoutGroupComboRest(row.workoutGroupId, cid);
    }
  }

  Future<void> _normalizeWorkoutGroupComboRest(
    String workoutGroupId,
    String comboId,
  ) async {
    final lines =
        await (_db.select(_db.workoutGroupExercises)
              ..where(
                (t) =>
                    t.workoutGroupId.equals(workoutGroupId) &
                    t.comboId.equals(comboId),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    if (lines.length < 2) return;
    var maxRest = 0;
    for (final l in lines) {
      if (l.restBetweenSetsSec > maxRest) maxRest = l.restBetweenSetsSec;
    }
    final now = DateTime.now();
    for (var i = 0; i < lines.length; i++) {
      final r = i == lines.length - 1 ? maxRest : 0;
      await (_db.update(
        _db.workoutGroupExercises,
      )..where((t) => t.id.equals(lines[i].id))).write(
        WorkoutGroupExercisesCompanion(
          restBetweenSetsSec: Value(r),
          updatedAt: Value(now),
        ),
      );
    }
    await _audit('update', 'workout_group', entityId: workoutGroupId);
  }

  Future<void> _normalizeWeekScheduleComboRest(
    String blockId,
    String comboId,
  ) async {
    final lines =
        await (_db.select(_db.weekScheduleItems)
              ..where(
                (i) => i.blockId.equals(blockId) & i.comboId.equals(comboId),
              )
              ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
            .get();
    if (lines.length < 2) return;
    var maxRest = 0;
    for (final l in lines) {
      if (l.restBetweenSetsSec > maxRest) maxRest = l.restBetweenSetsSec;
    }
    final now = DateTime.now();
    for (var i = 0; i < lines.length; i++) {
      final r = i == lines.length - 1 ? maxRest : 0;
      await (_db.update(
        _db.weekScheduleItems,
      )..where((x) => x.id.equals(lines[i].id))).write(
        WeekScheduleItemsCompanion(
          restBetweenSetsSec: Value(r),
          updatedAt: Value(now),
        ),
      );
    }
    await _audit('schedule_exercises_week', 'week_schedule', entityId: blockId);
  }

  Future<void> removeWorkoutGroupExerciseLine(String lineId) async {
    await _requireCadastroAccess();
    final row = await (_db.select(
      _db.workoutGroupExercises,
    )..where((t) => t.id.equals(lineId))).getSingleOrNull();
    if (row == null) return;
    final gid = row.workoutGroupId;
    final cid = row.comboId?.trim();
    await (_db.delete(
      _db.workoutGroupExercises,
    )..where((t) => t.id.equals(lineId))).go();
    await _audit('delete', 'workout_group_exercise', entityId: lineId);
    if (cid != null && cid.isNotEmpty) {
      final sibs =
          await (_db.select(_db.workoutGroupExercises)..where(
                (t) => t.workoutGroupId.equals(gid) & t.comboId.equals(cid),
              ))
              .get();
      if (sibs.length == 1) {
        final onlyId = sibs.single.id;
        await (_db.update(
          _db.workoutGroupExercises,
        )..where((t) => t.id.equals(onlyId))).write(
          WorkoutGroupExercisesCompanion(
            comboId: const Value(null),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await _audit('update', 'workout_group_exercise', entityId: onlyId);
      }
    }
  }

  Future<void> removeWorkoutGroupComboBlock({
    required String workoutGroupId,
    required String comboId,
  }) async {
    await _requireCadastroAccess();
    final cid = comboId.trim();
    if (cid.isEmpty) return;
    final lines =
        await (_db.select(_db.workoutGroupExercises)..where(
              (t) =>
                  t.workoutGroupId.equals(workoutGroupId) &
                  t.comboId.equals(cid),
            ))
            .get();
    for (final l in lines) {
      await (_db.delete(
        _db.workoutGroupExercises,
      )..where((t) => t.id.equals(l.id))).go();
      await _audit('delete', 'workout_group_exercise', entityId: l.id);
    }
  }

  /// Combina [secondExerciseId] logo após a linha âncora (mesmo [comboId]).
  /// O mesmo [secondExerciseId] pode repetir no grupo (para variações).
  Future<bool> combineWorkoutGroupExerciseLine({
    required String anchorLineId,
    required String secondExerciseId,
    required int lastSets,
    required String lastRepsText,
    double? lastLoadKg,
    required int restBetweenSetsSec,
    String? trainingMethodId,
  }) async {
    await _requireCadastroAccess();
    final anchor = await (_db.select(
      _db.workoutGroupExercises,
    )..where((t) => t.id.equals(anchorLineId))).getSingleOrNull();
    if (anchor == null) return false;
    final gid = anchor.workoutGroupId;

    final comboId =
        (anchor.comboId != null && anchor.comboId!.trim().isNotEmpty)
        ? anchor.comboId!.trim()
        : _uuid.v4();
    final now = DateTime.now();

    await _db.transaction(() async {
      if (anchor.comboId == null || anchor.comboId!.trim().isEmpty) {
        await (_db.update(
          _db.workoutGroupExercises,
        )..where((t) => t.id.equals(anchor.id))).write(
          WorkoutGroupExercisesCompanion(
            comboId: Value(comboId),
            updatedAt: Value(now),
          ),
        );
      }

      final after =
          await (_db.select(_db.workoutGroupExercises)
                ..where(
                  (t) =>
                      t.workoutGroupId.equals(gid) &
                      t.sortOrder.isBiggerThanValue(anchor.sortOrder),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)]))
              .get();

      for (final row in after) {
        await (_db.update(
          _db.workoutGroupExercises,
        )..where((t) => t.id.equals(row.id))).write(
          WorkoutGroupExercisesCompanion(
            sortOrder: Value(row.sortOrder + 1),
            updatedAt: Value(now),
          ),
        );
      }

      await _db
          .into(_db.workoutGroupExercises)
          .insert(
            WorkoutGroupExercisesCompanion.insert(
              id: _uuid.v4(),
              workoutGroupId: gid,
              exerciseId: secondExerciseId,
              sortOrder: Value(anchor.sortOrder + 1),
              lastReps: const Value(null),
              lastSets: Value(lastSets),
              lastLoadKg: Value(lastLoadKg),
              lastRepsText: Value(lastRepsText.trim()),
              restBetweenSetsSec: Value(restBetweenSetsSec),
              trainingMethodId: Value(trainingMethodId),
              comboId: Value(comboId),
              updatedAt: Value(now),
            ),
          );
    });

    await _normalizeWorkoutGroupComboRest(gid, comboId);
    await _audit('combine', 'workout_group', entityId: gid);
    return true;
  }

  Future<void> reorderWorkoutGroupExerciseLines({
    required String workoutGroupId,
    required List<String> orderedLineIds,
  }) async {
    await _requireCadastroAccess();
    if (orderedLineIds.isEmpty) return;
    final current = await (_db.select(
      _db.workoutGroupExercises,
    )..where((t) => t.workoutGroupId.equals(workoutGroupId))).get();
    final currentIds = {for (final r in current) r.id};
    if (currentIds.length != orderedLineIds.length ||
        orderedLineIds.any((id) => !currentIds.contains(id))) {
      throw ArgumentError('Ordem inválida para reordenar exercícios do grupo.');
    }

    await _db.transaction(() async {
      for (var i = 0; i < orderedLineIds.length; i++) {
        final lineId = orderedLineIds[i];
        await (_db.update(
          _db.workoutGroupExercises,
        )..where((t) => t.id.equals(lineId))).write(
          WorkoutGroupExercisesCompanion(
            sortOrder: Value(i),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
    // entityType = workout_group: o sync incremental reenvia todas as linhas do grupo
    // (entityId de linha seria o id da linha, não o do grupo).
    await _audit(
      'reorder',
      'workout_group',
      entityId: workoutGroupId,
      payload: {'count': orderedLineIds.length},
    );
  }

  Stream<List<AuditLogEntity>> watchAuditLogsDesc() {
    if (!_session.hasFullOrgAccess) {
      return Stream.value(const <AuditLogEntity>[]);
    }
    return (_db.select(
      _db.auditLogs,
    )..orderBy([(t) => OrderingTerm.desc(t.at)])).watch();
  }

  Future<List<AuditLogEntity>> allAuditLogs() async {
    if (!_session.hasFullOrgAccess) {
      return const <AuditLogEntity>[];
    }
    return (_db.select(
      _db.auditLogs,
    )..orderBy([(t) => OrderingTerm.desc(t.at)])).get();
  }

  Future<void> saveStudentAnamnese({
    required String studentId,
    required Map<String, String> answers,
  }) async {
    await requireStudentAccess(studentId);
    final clean = <String, String>{};
    for (final entry in answers.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;
      clean[key] = entry.value.trim();
    }
    await _audit(
      'anamnese_submit',
      'anamnese',
      entityId: studentId,
      payload: {'answers': clean},
    );
    await (_db.update(
      _db.students,
    )..where((s) => s.id.equals(studentId))).write(
      StudentsCompanion(
        anamneseCompleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<({DateTime at, Map<String, String> answers})>>
  studentAnamneseHistory({required String studentId, int limit = 20}) async {
    await requireStudentAccess(studentId);
    final rows =
        await (_db.select(_db.auditLogs)
              ..where(
                (a) =>
                    a.entityType.equals('anamnese') &
                    a.entityId.equals(studentId) &
                    a.action.equals('anamnese_submit'),
              )
              ..orderBy([(a) => OrderingTerm.desc(a.at)])
              ..limit(limit))
            .get();

    final out = <({DateTime at, Map<String, String> answers})>[];
    for (final row in rows) {
      final payload = row.payloadJson;
      if (payload == null || payload.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(payload);
        if (decoded is! Map) continue;
        final rawAnswers = decoded['answers'];
        if (rawAnswers is! Map) continue;
        final answers = <String, String>{};
        for (final e in rawAnswers.entries) {
          final key = '${e.key}'.trim();
          if (key.isEmpty) continue;
          answers[key] = '${e.value ?? ''}'.trim();
        }
        out.add((at: row.at, answers: answers));
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  /// Treinos no dia (calendário): incompletos programados em vermelho na UI.
  ///
  /// Margem no SQL + filtro por [weekScheduleLocalCalendarDate], igual ao recorte da semana
  /// no planejamento — evita perder linhas com `day_date` em UTC vindo do sync.
  Stream<List<DayWorkoutEntity>> watchDayWorkouts(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final startPad = start.subtract(const Duration(days: 2));
    final endPad = end.add(const Duration(days: 2));
    return (_db.select(_db.dayWorkouts)..where(
          (t) =>
              t.dayDate.isBiggerOrEqualValue(startPad) &
              t.dayDate.isSmallerThanValue(endPad) &
              _dayWorkoutNotCancelled(t),
        ))
        .watch()
        .map(
          (list) => list.where((w) {
            final d = weekScheduleLocalCalendarDate(w.dayDate);
            return !d.isBefore(start) && d.isBefore(end);
          }).toList(),
        )
        .asyncMap(_visibleDayWorkouts);
  }

  /// Snapshot imediato dos treinos do dia (mesma regra de dia civil local do calendário).
  Future<List<DayWorkoutEntity>> getDayWorkoutsForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final startPad = start.subtract(const Duration(days: 2));
    final endPad = end.add(const Duration(days: 2));
    final rows =
        await (_db.select(_db.dayWorkouts)..where(
              (t) =>
                  t.dayDate.isBiggerOrEqualValue(startPad) &
                  t.dayDate.isSmallerThanValue(endPad) &
                  _dayWorkoutNotCancelled(t),
            ))
            .get();
    final filtered = rows.where((w) {
      final d = weekScheduleLocalCalendarDate(w.dayDate);
      return !d.isBefore(start) && d.isBefore(end);
    }).toList();
    return _visibleDayWorkouts(filtered);
  }

  /// Treinos visíveis no intervalo **[fromInclusive, toExclusive)** por **dia civil local**
  /// (mesma regra da grade do calendário e da semana no planejamento).
  Stream<List<DayWorkoutEntity>> watchWorkoutsBetween(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) {
    final startPad = fromInclusive.subtract(const Duration(days: 2));
    final endPad = toExclusive.add(const Duration(days: 2));
    return (_db.select(_db.dayWorkouts)..where(
          (t) =>
              t.dayDate.isBiggerOrEqualValue(startPad) &
              t.dayDate.isSmallerThanValue(endPad) &
              _dayWorkoutNotCancelled(t),
        ))
        .watch()
        .map(
          (list) => list.where((w) {
            final d = weekScheduleLocalCalendarDate(w.dayDate);
            return !d.isBefore(fromInclusive) && d.isBefore(toExclusive);
          }).toList(),
        )
        .asyncMap(_visibleDayWorkouts);
  }

  // ——— Planejamento: semana (bloco + itens agendados) ———

  static DateTime normalizeMonday(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// Mesma semana que [weekMondayView] (segunda civil), após normalizar UTC/local do SQLite.
  bool _weekBlockMondayEquals(
    DateTime storedWeekStartMonday,
    DateTime weekMondayView,
  ) {
    final a = normalizeMonday(
      weekScheduleLocalCalendarDate(storedWeekStartMonday),
    );
    final b = normalizeMonday(
      DateTime(weekMondayView.year, weekMondayView.month, weekMondayView.day),
    );
    return a == b;
  }

  Future<String> _getOrCreateWeekBlock(
    String studentId,
    DateTime weekMonday,
  ) async {
    final mon = DateTime(weekMonday.year, weekMonday.month, weekMonday.day);
    final existingAll = await (_db.select(
      _db.weekScheduleBlocks,
    )..where((b) => b.studentId.equals(studentId))).get();
    for (final b in existingAll) {
      if (_weekBlockMondayEquals(b.weekStartMonday, mon)) {
        return b.id;
      }
    }
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db
        .into(_db.weekScheduleBlocks)
        .insert(
          WeekScheduleBlocksCompanion.insert(
            id: id,
            studentId: studentId,
            weekStartMonday: mon,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _audit('create', 'week_schedule_block', entityId: id);
    return id;
  }

  /// Itens agendados na semana (treinos planejados disponibilizados para a semana).
  Stream<List<WeekScheduleRow>> watchWeekScheduleRows({
    required String studentId,
    required DateTime weekMonday,
  }) {
    final mon = DateTime(weekMonday.year, weekMonday.month, weekMonday.day);
    final key = '$studentId|wsr|${mon.toIso8601String()}';
    _weekScheduleInnerByKey.putIfAbsent(key, () {
      // Só filtra aluno no SQL; o recorte da semana é em Dart ([_weekBlockMondayEquals]).
      // Assim blocos com `week_start_monday` gravado de forma inconsistente (UTC/local legado)
      // não somem para alguns alunos enquanto aparecem para outros.
      final q =
          _db.select(_db.weekScheduleItems).join([
              innerJoin(
                _db.weekScheduleBlocks,
                _db.weekScheduleBlocks.id.equalsExp(
                  _db.weekScheduleItems.blockId,
                ),
              ),
              leftOuterJoin(
                _db.exercises,
                _db.exercises.id.equalsExp(_db.weekScheduleItems.exerciseId),
              ),
            ])
            ..where(_db.weekScheduleBlocks.studentId.equals(studentId))
            ..orderBy([OrderingTerm.asc(_db.weekScheduleItems.sortOrder)]);

      return Stream.fromFuture(
            requireStudentAccess(studentId)
                .timeout(
                  const Duration(seconds: 8),
                  onTimeout: () => throw TimeoutException(
                    'Timeout ao verificar acesso ao aluno no planejamento.',
                  ),
                )
                .then((_) {
                  // Local-first: não bloquear a UI esperando pull da nuvem ao trocar aluno/semana.
                  // O pull roda em background para convergência entre dispositivos.
                  // Rede lenta (ex.: iPhone): 1,5s cortava o pull — planejamento ficava vazio
                  // com calendário já populado por outro caminho.
                  unawaited(
                    refreshStudentWeekScheduleFromCloud(
                      studentId,
                      weekMonday: mon,
                    ).timeout(const Duration(seconds: 25), onTimeout: () {}),
                  );
                  return true;
                }),
          )
          .asyncExpand(
            (_) => q.watch().map((rows) {
              final list = rows
                  .where(
                    (row) => _weekBlockMondayEquals(
                      row.readTable(_db.weekScheduleBlocks).weekStartMonday,
                      mon,
                    ),
                  )
                  .map((row) {
                    final ex = row.readTableOrNull(_db.exercises);
                    final rawName = ex?.name.trim();
                    return WeekScheduleRow(
                      item: row.readTable(_db.weekScheduleItems),
                      exerciseName: (rawName != null && rawName.isNotEmpty)
                          ? rawName
                          : 'Exercício ausente no catálogo',
                    );
                  })
                  .toList();
              _weekScheduleLastByKey[key] = list;
              return list;
            }),
          )
          .asBroadcastStream();
    });

    return Stream.multi((controller) async {
      final last = _weekScheduleLastByKey[key];
      if (last != null) {
        controller.add(last);
      }
      await controller.addStream(_weekScheduleInnerByKey[key]!);
    });
  }

  /// Treinos no calendário (programados / iniciados / concluídos) dentro da semana [monday, monday+7).
  Stream<List<DayWorkoutEntity>> watchStudentWeekDayWorkouts({
    required String studentId,
    required DateTime weekMonday,
  }) {
    final start = DateTime(weekMonday.year, weekMonday.month, weekMonday.day);
    final key = '$studentId|wdw|${start.toIso8601String()}';
    _studentWeekWorkoutsInnerByKey.putIfAbsent(key, () {
      final end = start.add(const Duration(days: 7));
      // Margem no SQL + filtro pelo dia civil local (igual calendário), para linhas legadas com `day_date` deslocado.
      final startPad = start.subtract(const Duration(days: 2));
      final endPad = end.add(const Duration(days: 2));
      final sel = _db.select(_db.dayWorkouts)
        ..where(
          (w) =>
              w.studentId.equals(studentId) &
              w.dayDate.isBiggerOrEqualValue(startPad) &
              w.dayDate.isSmallerThanValue(endPad) &
              _dayWorkoutNotCancelled(w),
        )
        ..orderBy([(w) => OrderingTerm.asc(w.dayDate)]);

      return Stream.fromFuture(
            requireStudentAccess(studentId).then((_) => true),
          )
          .asyncExpand(
            (_) => sel.watch().map((list) {
              final filtered = list.where((w) {
                final d = weekScheduleLocalCalendarDate(w.dayDate);
                return !d.isBefore(start) && d.isBefore(end);
              }).toList();
              _studentWeekWorkoutsLastByKey[key] = filtered;
              return filtered;
            }),
          )
          .asBroadcastStream();
    });

    return Stream.multi((controller) async {
      final last = _studentWeekWorkoutsLastByKey[key];
      if (last != null) {
        controller.add(last);
      }
      await controller.addStream(_studentWeekWorkoutsInnerByKey[key]!);
    });
  }

  /// Insere exercícios no bloco da semana.
  /// O mesmo [exerciseId] pode repetir para variações no mesmo treino.
  Future<({int added, int skipped})> addExercisesToWeekSchedule({
    required String studentId,
    required DateTime weekMonday,
    required List<String> exerciseIds,
  }) async {
    await _requirePlanningAccess();
    await requireStudentAccess(studentId);
    if (exerciseIds.isEmpty) return (added: 0, skipped: 0);
    final blockId = await _getOrCreateWeekBlock(studentId, weekMonday);
    final existing = await (_db.select(
      _db.weekScheduleItems,
    )..where((i) => i.blockId.equals(blockId))).get();
    var maxO = -1;
    for (final i in existing) {
      if (i.sortOrder > maxO) maxO = i.sortOrder;
    }
    var added = 0;
    await _db.transaction(() async {
      for (final exId in exerciseIds) {
        maxO++;
        added++;
        await _db
            .into(_db.weekScheduleItems)
            .insert(
              WeekScheduleItemsCompanion.insert(
                id: _uuid.v4(),
                blockId: blockId,
                exerciseId: exId,
                sourceWorkoutGroupId: const Value.absent(),
                sortOrder: Value(maxO),
                sets: const Value(0),
                reps: const Value(0),
                loadKg: const Value.absent(),
                needsDetail: const Value(true),
                restBetweenSetsSec: const Value(60),
              ),
            );
      }
    });
    if (added > 0) {
      await _audit(
        'schedule_exercises_week',
        'week_schedule',
        entityId: blockId,
      );
    }
    return (added: added, skipped: 0);
  }

  /// Todos os grupos de treino (mesma base do cadastro), com contagem de exercícios no modelo.
  /// Na UI de agendar treino, grupos com 0 exercícios não podem ser escolhidos.
  Stream<List<({WorkoutGroupEntity group, int exerciseCount})>>
  watchWorkoutGroupsSchedulable() {
    _workoutGroupsSchedulableInnerBroadcast ??=
        (_db.select(_db.workoutGroups)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .watch()
            .asyncMap((groups) async {
              final out = <({WorkoutGroupEntity group, int exerciseCount})>[];
              for (final g in groups) {
                final lines = await (_db.select(
                  _db.workoutGroupExercises,
                )..where((t) => t.workoutGroupId.equals(g.id))).get();
                out.add((group: g, exerciseCount: lines.length));
              }
              return out;
            })
            .map((list) {
              _lastSchedulable = list;
              return list;
            })
            .asBroadcastStream();

    return Stream.multi((controller) async {
      final last = _lastSchedulable;
      if (last != null) {
        controller.add(last);
      }
      await controller.addStream(_workoutGroupsSchedulableInnerBroadcast!);
    });
  }

  /// Inclui o modelo do grupo no planejamento por [weekCount] semanas consecutivas
  /// a partir de [startWeekMonday] (inclusive). Cada linha de [workoutGroupExercises]
  /// vira um item (o mesmo [exerciseId] pode repetir, como no cadastro do grupo).
  /// Itens recebem [sourceWorkoutGroupId].
  ///
  /// Não insere de novo o mesmo [workoutGroupId] numa semana em que já exista
  /// qualquer item com esse [sourceWorkoutGroupId].
  Future<({int weeksWithAdds, int itemsAdded})> scheduleWorkoutGroupForWeeks({
    required String studentId,
    required DateTime startWeekMonday,
    required String workoutGroupId,
    required int weekCount,
  }) async {
    await _requirePlanningAccess();
    await requireStudentAccess(studentId);
    if (weekCount < 1 || weekCount > 52) {
      throw ArgumentError('weekCount deve estar entre 1 e 52.');
    }
    final wg = await (_db.select(
      _db.workoutGroups,
    )..where((t) => t.id.equals(workoutGroupId))).getSingleOrNull();
    if (wg == null || wg.deletedAt != null) {
      throw ArgumentError('Grupo de treino indisponível ou excluído.');
    }
    final lines =
        await (_db.select(_db.workoutGroupExercises)
              ..where((t) => t.workoutGroupId.equals(workoutGroupId))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    if (lines.isEmpty) {
      throw ArgumentError(
        'Este grupo de treino não tem exercícios no modelo; não pode ser agendado.',
      );
    }

    final start = DateTime(
      startWeekMonday.year,
      startWeekMonday.month,
      startWeekMonday.day,
    );

    var weeksWithAdds = 0;
    var itemsAdded = 0;

    for (var wi = 0; wi < weekCount; wi++) {
      final mon = start.add(Duration(days: wi * 7));
      final blockId = await _getOrCreateWeekBlock(studentId, mon);
      final existing = await (_db.select(
        _db.weekScheduleItems,
      )..where((i) => i.blockId.equals(blockId))).get();
      final alreadyHasThisGroup = existing.any(
        (i) => i.sourceWorkoutGroupId == workoutGroupId,
      );
      if (alreadyHasThisGroup) {
        continue;
      }

      var maxO = -1;
      for (final i in existing) {
        if (i.sortOrder > maxO) maxO = i.sortOrder;
      }

      var addedThisWeek = 0;
      await _db.transaction(() async {
        for (final line in lines) {
          maxO++;
          final sets = line.lastSets ?? 0;
          final reps = _repsIntFromWorkoutGroupLine(line);
          final needsDetail = sets <= 0 || reps <= 0;
          final rtw = _repsTextFromWorkoutGroupLine(line);
          await _db
              .into(_db.weekScheduleItems)
              .insert(
                WeekScheduleItemsCompanion.insert(
                  id: _uuid.v4(),
                  blockId: blockId,
                  exerciseId: line.exerciseId,
                  sourceWorkoutGroupId: Value(workoutGroupId),
                  sortOrder: Value(maxO),
                  sets: Value(sets),
                  reps: Value(reps),
                  repsText: Value(rtw),
                  loadKg: Value(line.lastLoadKg),
                  needsDetail: Value(needsDetail),
                  restBetweenSetsSec: Value(line.restBetweenSetsSec),
                  trainingMethodId: Value(line.trainingMethodId),
                  comboId: Value(line.comboId),
                ),
              );
          addedThisWeek++;
        }
      });
      if (addedThisWeek > 0) {
        weeksWithAdds++;
        itemsAdded += addedThisWeek;
        await _audit(
          'schedule_exercises_week',
          'week_schedule',
          entityId: blockId,
        );
      }
    }

    return (weeksWithAdds: weeksWithAdds, itemsAdded: itemsAdded);
  }

  /// Copia o planejamento da semana [startWeekMonday] de [sourceStudentId] para [targetStudentId]
  /// e repete por [weekCount] semanas consecutivas.
  ///
  /// Mantém a ordem e sets/reps/carga/sourceWorkoutGroupId; [needsDetail] no destino é derivado
  /// de sets/reps para não herdar flag inconsistente que impedia programar no calendário.
  /// Não remove itens já existentes no aluno de destino; apenas adiciona.
  /// Grupos ([sourceWorkoutGroupId] não nulo) que o destino já tiver na semana não são
  /// copiados de novo. Exercícios avulsos (sem grupo) só entram se o [exerciseId]
  /// ainda não existir no bloco.
  Future<({int sourceItems, int weeksWithAdds, int itemsAdded})>
  copyStudentWeekScheduleForWeeks({
    required String sourceStudentId,
    required String targetStudentId,
    required DateTime startWeekMonday,
    required int weekCount,
  }) async {
    await _requirePlanningAccess();
    await requireStudentAccess(sourceStudentId);
    await requireStudentAccess(targetStudentId);
    if (sourceStudentId == targetStudentId) {
      throw ArgumentError('Selecione outro aluno para copiar o treino.');
    }
    if (weekCount < 1 || weekCount > 52) {
      throw ArgumentError('weekCount deve estar entre 1 e 52.');
    }

    final start = DateTime(
      startWeekMonday.year,
      startWeekMonday.month,
      startWeekMonday.day,
    );
    final sourceCandidates = await (_db.select(
      _db.weekScheduleBlocks,
    )..where((b) => b.studentId.equals(sourceStudentId))).get();
    WeekScheduleBlockEntity? sourceBlock;
    for (final b in sourceCandidates) {
      if (_weekBlockMondayEquals(b.weekStartMonday, start)) {
        sourceBlock = b;
        break;
      }
    }
    if (sourceBlock == null) {
      return (sourceItems: 0, weeksWithAdds: 0, itemsAdded: 0);
    }
    final srcBlock = sourceBlock;

    final sourceItems =
        await (_db.select(_db.weekScheduleItems)
              ..where((i) => i.blockId.equals(srcBlock.id))
              ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
            .get();
    if (sourceItems.isEmpty) {
      return (sourceItems: 0, weeksWithAdds: 0, itemsAdded: 0);
    }

    var weeksWithAdds = 0;
    var itemsAdded = 0;
    for (var wi = 0; wi < weekCount; wi++) {
      final mon = start.add(Duration(days: wi * 7));
      final targetBlockId = await _getOrCreateWeekBlock(targetStudentId, mon);
      final existing = await (_db.select(
        _db.weekScheduleItems,
      )..where((i) => i.blockId.equals(targetBlockId))).get();

      var maxO = -1;
      for (final i in existing) {
        if (i.sortOrder > maxO) maxO = i.sortOrder;
      }

      final initialGroupIds = {
        for (final i in existing)
          if (i.sourceWorkoutGroupId != null) i.sourceWorkoutGroupId!,
      };
      final avulsoExerciseIds = {
        for (final i in existing)
          if (i.sourceWorkoutGroupId == null) i.exerciseId,
      };

      var addedThisWeek = 0;
      await _db.transaction(() async {
        for (final source in sourceItems) {
          final gid = source.sourceWorkoutGroupId;
          if (gid != null && initialGroupIds.contains(gid)) {
            continue;
          }
          if (gid == null && avulsoExerciseIds.contains(source.exerciseId)) {
            continue;
          }
          maxO++;
          final copiedNeedsDetail = !weekScheduleItemHasValidPrescription(
            source,
          );
          await _db
              .into(_db.weekScheduleItems)
              .insert(
                WeekScheduleItemsCompanion.insert(
                  id: _uuid.v4(),
                  blockId: targetBlockId,
                  exerciseId: source.exerciseId,
                  sourceWorkoutGroupId: Value(source.sourceWorkoutGroupId),
                  sortOrder: Value(maxO),
                  sets: Value(source.sets),
                  reps: Value(source.reps),
                  repsText: Value(source.repsText),
                  loadKg: Value(source.loadKg),
                  needsDetail: Value(copiedNeedsDetail),
                  restBetweenSetsSec: Value(source.restBetweenSetsSec),
                  trainingMethodId: Value(source.trainingMethodId),
                  comboId: Value(source.comboId),
                ),
              );
          addedThisWeek++;
          if (gid == null) {
            avulsoExerciseIds.add(source.exerciseId);
          }
        }
      });

      if (addedThisWeek > 0) {
        weeksWithAdds++;
        itemsAdded += addedThisWeek;
        await _audit(
          'schedule_exercises_week',
          'week_schedule',
          entityId: targetBlockId,
        );
      }
    }

    return (
      sourceItems: sourceItems.length,
      weeksWithAdds: weeksWithAdds,
      itemsAdded: itemsAdded,
    );
  }

  Future<void> copyWorkoutGroupToWeekSchedule({
    required String studentId,
    required DateTime weekMonday,
    required String workoutGroupId,
  }) async {
    await scheduleWorkoutGroupForWeeks(
      studentId: studentId,
      startWeekMonday: weekMonday,
      workoutGroupId: workoutGroupId,
      weekCount: 1,
    );
  }

  Future<void> updateWeekScheduleItem({
    required String itemId,
    required int sets,
    required String repsText,
    required int repsHintInt,
    double? loadKg,
    required int restBetweenSetsSec,
    String? trainingMethodId,
  }) async {
    await _requirePlanningAccess();
    final item = await (_db.select(
      _db.weekScheduleItems,
    )..where((i) => i.id.equals(itemId))).getSingleOrNull();
    if (item == null) return;
    final block = await (_db.select(
      _db.weekScheduleBlocks,
    )..where((b) => b.id.equals(item.blockId))).getSingleOrNull();
    if (block == null) return;
    await requireStudentAccess(block.studentId);

    final trimmed = repsText.trim();
    final needsDetail = sets <= 0 || repsHintInt <= 0;
    await (_db.update(
      _db.weekScheduleItems,
    )..where((i) => i.id.equals(itemId))).write(
      WeekScheduleItemsCompanion(
        sets: Value(sets),
        reps: Value(repsHintInt),
        repsText: Value(trimmed.isEmpty ? null : trimmed),
        loadKg: Value(loadKg),
        needsDetail: Value(needsDetail),
        restBetweenSetsSec: Value(restBetweenSetsSec),
        trainingMethodId: Value(trainingMethodId),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _audit('update', 'week_schedule_item', entityId: itemId);
    final row = await (_db.select(
      _db.weekScheduleItems,
    )..where((i) => i.id.equals(itemId))).getSingleOrNull();
    final cid = row?.comboId?.trim();
    if (row != null && cid != null && cid.isNotEmpty) {
      await _normalizeWeekScheduleComboRest(row.blockId, cid);
    }
    final gid = row?.sourceWorkoutGroupId?.trim();
    if (row != null && gid != null && gid.isNotEmpty) {
      await propagateWeekBlockProgrammedSnapshotsFromPlanning(
        blockId: row.blockId,
        onlyWorkoutGroupId: gid,
      );
    }
  }

  Future<void> deleteWeekScheduleItem(String itemId) async {
    await _requirePlanningAccess();
    final item = await (_db.select(
      _db.weekScheduleItems,
    )..where((i) => i.id.equals(itemId))).getSingleOrNull();
    if (item == null) return;
    final block = await (_db.select(
      _db.weekScheduleBlocks,
    )..where((b) => b.id.equals(item.blockId))).getSingleOrNull();
    if (block == null) return;
    await requireStudentAccess(block.studentId);

    final now = DateTime.now();
    final blockId = item.blockId;
    final propagateGroupId = item.sourceWorkoutGroupId?.trim();
    final cid = item.comboId?.trim();
    final linkedDayWorkouts = await (_db.select(
      _db.dayWorkouts,
    )..where((d) => d.weekItemId.equals(itemId))).get();
    await (_db.update(
      _db.dayWorkouts,
    )..where((d) => d.weekItemId.equals(itemId))).write(
      DayWorkoutsCompanion(
        status: const Value('cancelled'),
        weekItemId: const Value(null),
        timerResumeAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
    await (_db.delete(
      _db.weekScheduleItems,
    )..where((i) => i.id.equals(itemId))).go();
    await _audit('delete', 'week_schedule_item', entityId: itemId);
    for (final w in linkedDayWorkouts) {
      await _audit('update', 'day_workout', entityId: w.id);
    }
    if (cid != null && cid.isNotEmpty) {
      final sibs = await (_db.select(
        _db.weekScheduleItems,
      )..where((i) => i.blockId.equals(blockId) & i.comboId.equals(cid))).get();
      if (sibs.length == 1) {
        final onlyId = sibs.single.id;
        await (_db.update(
          _db.weekScheduleItems,
        )..where((i) => i.id.equals(onlyId))).write(
          WeekScheduleItemsCompanion(
            comboId: const Value(null),
            updatedAt: Value(now),
          ),
        );
        await _audit('update', 'week_schedule_item', entityId: onlyId);
      }
    }
    if (propagateGroupId != null && propagateGroupId.isNotEmpty) {
      await propagateWeekBlockProgrammedSnapshotsFromPlanning(
        blockId: blockId,
        onlyWorkoutGroupId: propagateGroupId,
      );
    }
  }

  Future<void> removeWeekScheduleComboBlock({
    required String blockId,
    required String comboId,
  }) async {
    await _requirePlanningAccess();
    final cid = comboId.trim();
    if (cid.isEmpty) return;
    final block = await (_db.select(
      _db.weekScheduleBlocks,
    )..where((b) => b.id.equals(blockId))).getSingleOrNull();
    if (block == null) return;
    await requireStudentAccess(block.studentId);
    final lines = await (_db.select(
      _db.weekScheduleItems,
    )..where((i) => i.blockId.equals(blockId) & i.comboId.equals(cid))).get();
    final now = DateTime.now();
    for (final item in lines) {
      final linkedDayWorkouts = await (_db.select(
        _db.dayWorkouts,
      )..where((d) => d.weekItemId.equals(item.id))).get();
      await (_db.update(
        _db.dayWorkouts,
      )..where((d) => d.weekItemId.equals(item.id))).write(
        DayWorkoutsCompanion(
          status: const Value('cancelled'),
          weekItemId: const Value(null),
          timerResumeAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await (_db.delete(
        _db.weekScheduleItems,
      )..where((i) => i.id.equals(item.id))).go();
      await _audit('delete', 'week_schedule_item', entityId: item.id);
      for (final w in linkedDayWorkouts) {
        await _audit('update', 'day_workout', entityId: w.id);
      }
    }
    final gid0 = lines.isNotEmpty
        ? lines.first.sourceWorkoutGroupId?.trim()
        : null;
    if (gid0 != null && gid0.isNotEmpty) {
      await propagateWeekBlockProgrammedSnapshotsFromPlanning(
        blockId: blockId,
        onlyWorkoutGroupId: gid0,
      );
    }
  }

  Future<bool> combineWeekScheduleItemWithExercise({
    required String anchorItemId,
    required String secondExerciseId,
    required int sets,
    required String repsText,
    required int repsHintInt,
    double? loadKg,
    required int restBetweenSetsSec,
    String? trainingMethodId,
  }) async {
    await _requirePlanningAccess();
    final anchor = await (_db.select(
      _db.weekScheduleItems,
    )..where((i) => i.id.equals(anchorItemId))).getSingleOrNull();
    if (anchor == null) return false;
    final block = await (_db.select(
      _db.weekScheduleBlocks,
    )..where((b) => b.id.equals(anchor.blockId))).getSingleOrNull();
    if (block == null) return false;
    await requireStudentAccess(block.studentId);

    final blockId = anchor.blockId;

    final comboId =
        (anchor.comboId != null && anchor.comboId!.trim().isNotEmpty)
        ? anchor.comboId!.trim()
        : _uuid.v4();
    final now = DateTime.now();
    final trimmed = repsText.trim();
    final needsDetail = sets <= 0 || repsHintInt <= 0;

    await _db.transaction(() async {
      if (anchor.comboId == null || anchor.comboId!.trim().isEmpty) {
        await (_db.update(
          _db.weekScheduleItems,
        )..where((i) => i.id.equals(anchor.id))).write(
          WeekScheduleItemsCompanion(
            comboId: Value(comboId),
            updatedAt: Value(now),
          ),
        );
      }

      final after =
          await (_db.select(_db.weekScheduleItems)
                ..where(
                  (i) =>
                      i.blockId.equals(blockId) &
                      i.sortOrder.isBiggerThanValue(anchor.sortOrder),
                )
                ..orderBy([(i) => OrderingTerm.desc(i.sortOrder)]))
              .get();

      for (final row in after) {
        await (_db.update(
          _db.weekScheduleItems,
        )..where((i) => i.id.equals(row.id))).write(
          WeekScheduleItemsCompanion(
            sortOrder: Value(row.sortOrder + 1),
            updatedAt: Value(now),
          ),
        );
      }

      await _db
          .into(_db.weekScheduleItems)
          .insert(
            WeekScheduleItemsCompanion.insert(
              id: _uuid.v4(),
              blockId: blockId,
              exerciseId: secondExerciseId,
              sourceWorkoutGroupId: Value(anchor.sourceWorkoutGroupId),
              sortOrder: Value(anchor.sortOrder + 1),
              sets: Value(sets),
              reps: Value(repsHintInt),
              repsText: Value(trimmed.isEmpty ? null : trimmed),
              loadKg: Value(loadKg),
              needsDetail: Value(needsDetail),
              restBetweenSetsSec: Value(restBetweenSetsSec),
              trainingMethodId: Value(trainingMethodId),
              comboId: Value(comboId),
              updatedAt: Value(now),
            ),
          );
    });

    await _normalizeWeekScheduleComboRest(blockId, comboId);
    await _audit('combine', 'week_schedule_item', entityId: anchorItemId);
    final pg = anchor.sourceWorkoutGroupId?.trim();
    if (pg != null && pg.isNotEmpty) {
      await propagateWeekBlockProgrammedSnapshotsFromPlanning(
        blockId: blockId,
        onlyWorkoutGroupId: pg,
      );
    }
    return true;
  }

  Future<void> reorderWeekScheduleItemsInGroup({
    required String blockId,
    required String? sourceWorkoutGroupId,
    required List<String> orderedItemIds,
  }) async {
    await _requirePlanningAccess();
    if (orderedItemIds.isEmpty) return;
    final block = await (_db.select(
      _db.weekScheduleBlocks,
    )..where((b) => b.id.equals(blockId))).getSingleOrNull();
    if (block == null) return;
    await requireStudentAccess(block.studentId);

    final query = _db.select(_db.weekScheduleItems)
      ..where((i) => i.blockId.equals(blockId));
    if (sourceWorkoutGroupId == null) {
      query.where((i) => i.sourceWorkoutGroupId.isNull());
    } else {
      query.where((i) => i.sourceWorkoutGroupId.equals(sourceWorkoutGroupId));
    }
    final current = await query.get();
    final currentIds = {for (final r in current) r.id};
    if (currentIds.length != orderedItemIds.length ||
        orderedItemIds.any((id) => !currentIds.contains(id))) {
      throw ArgumentError('Ordem inválida para reordenar itens da semana.');
    }

    var baseOrder = 0;
    if (current.isNotEmpty) {
      baseOrder = current
          .map((e) => e.sortOrder)
          .reduce((a, b) => a < b ? a : b);
    }

    await _db.transaction(() async {
      for (var i = 0; i < orderedItemIds.length; i++) {
        final itemId = orderedItemIds[i];
        await (_db.update(
          _db.weekScheduleItems,
        )..where((x) => x.id.equals(itemId))).write(
          WeekScheduleItemsCompanion(
            sortOrder: Value(baseOrder + i),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
    await _audit(
      'reorder',
      'week_schedule',
      entityId: blockId,
      payload: {
        'sourceWorkoutGroupId': sourceWorkoutGroupId,
        'count': orderedItemIds.length,
      },
    );
    final g = sourceWorkoutGroupId?.trim();
    if (g != null && g.isNotEmpty) {
      await propagateWeekBlockProgrammedSnapshotsFromPlanning(
        blockId: blockId,
        onlyWorkoutGroupId: g,
      );
    }
  }

  // ——— Calendário: programar / iniciar / timer / concluir ———

  Future<List<WeekScheduleRow>> loadWeekScheduleRows({
    required String studentId,
    required DateTime weekMonday,
  }) async {
    await requireStudentAccess(studentId);
    final mon = DateTime(weekMonday.year, weekMonday.month, weekMonday.day);
    final q =
        _db.select(_db.weekScheduleItems).join([
            innerJoin(
              _db.weekScheduleBlocks,
              _db.weekScheduleBlocks.id.equalsExp(
                _db.weekScheduleItems.blockId,
              ),
            ),
            leftOuterJoin(
              _db.exercises,
              _db.exercises.id.equalsExp(_db.weekScheduleItems.exerciseId),
            ),
          ])
          ..where(_db.weekScheduleBlocks.studentId.equals(studentId))
          ..orderBy([OrderingTerm.asc(_db.weekScheduleItems.sortOrder)]);
    final rows = await q.get();
    return rows
        .where(
          (row) => _weekBlockMondayEquals(
            row.readTable(_db.weekScheduleBlocks).weekStartMonday,
            mon,
          ),
        )
        .map((row) {
          final ex = row.readTableOrNull(_db.exercises);
          final rawName = ex?.name.trim();
          return WeekScheduleRow(
            item: row.readTable(_db.weekScheduleItems),
            exerciseName: (rawName != null && rawName.isNotEmpty)
                ? rawName
                : 'Exercício ausente no catálogo',
          );
        })
        .toList();
  }

  /// Alunos com pelo menos um item de semana com séries e reps preenchidos na semana do dia.
  /// Não exige `!needsDetail`: o flag pode ficar inconsistente após sync/cópia.
  Future<List<StudentEntity>> getStudentsWithProgrammableWeek(
    DateTime day,
  ) async {
    final monday = normalizeMonday(day);
    final allStudents = await (_db.select(_db.students)).get();
    final visible = _visibleStudents(allStudents);
    if (visible.isEmpty) return [];
    // Hidrata planning da semana na nuvem antes de decidir quem é programável.
    // Limite para não degradar UX em bases muito grandes.
    final refreshCandidates = visible.take(10).toList(growable: false);
    await Future.wait(
      refreshCandidates.map(
        (s) => refreshStudentWeekScheduleFromCloud(
          s.id,
          weekMonday: monday,
        ).timeout(const Duration(milliseconds: 650), onTimeout: () {}),
      ),
    );
    final visibleIds = visible.map((s) => s.id).toList();
    // Só alunos visíveis na sessão; sem janela SQL em week_start_monday (evita falsos negativos por data/UTC).
    final blockCandidates = await (_db.select(
      _db.weekScheduleBlocks,
    )..where((b) => b.studentId.isIn(visibleIds))).get();
    final blocks = blockCandidates
        .where((b) => _weekBlockMondayEquals(b.weekStartMonday, monday))
        .toList();
    final okStudents = <String>{};
    for (final b in blocks) {
      final items = await (_db.select(
        _db.weekScheduleItems,
      )..where((i) => i.blockId.equals(b.id))).get();
      final ok = items.any(weekScheduleItemHasValidPrescription);
      if (ok) okStudents.add(b.studentId);
    }
    if (okStudents.isEmpty) return [];
    final list =
        await (_db.select(_db.students)
              ..where((s) => s.id.isIn(okStudents.toList()))
              ..orderBy([(s) => OrderingTerm.asc(s.name)]))
            .get();
    return _visibleStudents(list);
  }

  Future<List<ProgrammableBundle>> getProgrammableBundles(
    String studentId,
    DateTime day,
  ) async {
    await requireStudentAccess(studentId);
    final monday = normalizeMonday(day);
    await refreshStudentWeekScheduleFromCloud(
      studentId,
      weekMonday: monday,
    ).timeout(const Duration(milliseconds: 1500), onTimeout: () {});
    final rows = await loadWeekScheduleRows(
      studentId: studentId,
      weekMonday: monday,
    );
    final valid = rows
        .where((r) => weekScheduleItemHasValidPrescription(r.item))
        .toList();
    final rawGroupIds = <String>{};
    for (final r in valid) {
      final g = r.item.sourceWorkoutGroupId?.trim();
      if (g != null && g.isNotEmpty) rawGroupIds.add(g);
    }
    final activeGroupIds = <String>{};
    if (rawGroupIds.isNotEmpty) {
      final headers =
          await (_db.select(_db.workoutGroups)..where(
                (t) => t.id.isIn(rawGroupIds.toList()) & t.deletedAt.isNull(),
              ))
              .get();
      activeGroupIds.addAll(headers.map((h) => h.id));
    }
    final byGroup = <String?, List<WeekScheduleRow>>{};
    for (final r in valid) {
      final raw = r.item.sourceWorkoutGroupId?.trim();
      final key =
          (raw != null && raw.isNotEmpty && activeGroupIds.contains(raw))
          ? raw
          : null;
      byGroup.putIfAbsent(key, () => []).add(r);
    }
    final bundles = <ProgrammableBundle>[];
    for (final e in byGroup.entries) {
      final list = e.value
        ..sort((a, b) => a.item.sortOrder.compareTo(b.item.sortOrder));
      final key = e.key;
      String title;
      if (key == null) {
        title = 'Exercícios avulsos (${list.length})';
      } else {
        final g = await (_db.select(
          _db.workoutGroups,
        )..where((t) => t.id.equals(key))).getSingleOrNull();
        title = g?.name ?? 'Grupo de treino';
      }
      bundles.add(
        ProgrammableBundle(title: title, workoutGroupId: key, rows: list),
      );
    }
    bundles.sort((a, b) => a.title.compareTo(b.title));
    return bundles;
  }

  /// Nome do grupo de treino vinculado ao dia (quando programado a partir de um grupo).
  Future<String?> getDayWorkoutGroupBadgeLabel(DayWorkoutEntity w) async {
    await requireStudentAccess(w.studentId);
    final gid = w.sourceWorkoutGroupId;
    if (gid == null || gid.isEmpty) return null;
    final g = await (_db.select(
      _db.workoutGroups,
    )..where((t) => t.id.equals(gid))).getSingleOrNull();
    return g?.name;
  }

  /// Cria treino do dia (snapshot) a partir dos itens da semana — não altera o planejamento.
  Future<String> createProgrammedDayWorkout({
    required String studentId,
    required DateTime day,
    required List<WeekScheduleRow> rows,
    String? sourceWorkoutGroupId,
  }) async {
    await requireStudentAccess(studentId);
    if (rows.isEmpty) throw ArgumentError('rows vazio');
    final dayOnly = weekScheduleLocalCalendarDate(
      DateTime(day.year, day.month, day.day),
    );
    if (isCalendarDateBeforeToday(dayOnly)) {
      throw ArgumentError('Não é possível programar treino em data passada.');
    }
    final wid = _uuid.v4();
    final now = DateTime.now();
    await _db.transaction(() async {
      await _db
          .into(_db.dayWorkouts)
          .insert(
            DayWorkoutsCompanion.insert(
              id: wid,
              studentId: studentId,
              dayDate: dayOnly,
              status: 'programmed',
              activeDurationSeconds: const Value(0),
              createdAt: Value(now),
              updatedAt: Value(now),
              sourceWorkoutGroupId: sourceWorkoutGroupId != null
                  ? Value(sourceWorkoutGroupId)
                  : const Value.absent(),
            ),
          );
      for (final r in rows) {
        final i = r.item;
        final disp = weekScheduleRepsDisplay(i);
        final hint = repsHintIntFromText(disp) ?? i.reps;
        await _db
            .into(_db.dayWorkoutExercises)
            .insert(
              DayWorkoutExercisesCompanion.insert(
                id: _uuid.v4(),
                dayWorkoutId: wid,
                exerciseId: i.exerciseId,
                sortOrder: Value(i.sortOrder),
                sets: i.sets,
                reps: hint > 0 ? hint : i.reps,
                repsText: Value(disp.isEmpty ? null : disp),
                loadKg: Value(i.loadKg),
                restBetweenSetsSec: Value(i.restBetweenSetsSec),
                trainingMethodId: Value(i.trainingMethodId),
                comboId: Value(i.comboId),
              ),
            );
      }
    });
    await _audit('program_day_workout', 'day_workout', entityId: wid);
    return wid;
  }

  /// Quando o snapshot do calendário veio sem linhas (sync incompleto / FK) mas o treino
  /// está ligado a um [DayWorkoutEntity.sourceWorkoutGroupId], recria [day_workout_exercises]
  /// a partir do modelo local do grupo (não altera treinos concluídos ou cancelados).
  Future<int> repairDayWorkoutExercisesFromSourceGroupIfNeeded(
    String dayWorkoutId,
  ) async {
    await _requireAccessForDayWorkoutId(dayWorkoutId);
    final w = await _dayWorkoutRow(dayWorkoutId);
    if (w == null) return 0;
    if (w.status == 'completed' || w.status == 'cancelled') return 0;

    final existing = await (_db.select(
      _db.dayWorkoutExercises,
    )..where((e) => e.dayWorkoutId.equals(dayWorkoutId))).get();
    if (existing.isNotEmpty) return 0;

    final gid = w.sourceWorkoutGroupId?.trim();
    if (gid == null || gid.isEmpty) return 0;

    final lines =
        await (_db.select(_db.workoutGroupExercises)
              ..where((t) => t.workoutGroupId.equals(gid))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    if (lines.isEmpty) return 0;

    final exIds = lines.map((l) => l.exerciseId).toSet().toList();
    if (exIds.isEmpty) return 0;
    final existingEx = await (_db.select(
      _db.exercises,
    )..where((e) => e.id.isIn(exIds))).get();
    final exerciseOk = existingEx.map((e) => e.id).toSet();
    if (exerciseOk.isEmpty) return 0;

    var added = 0;
    await _db.transaction(() async {
      for (final line in lines) {
        if (!exerciseOk.contains(line.exerciseId)) continue;
        final sets = line.lastSets != null && line.lastSets! > 0
            ? line.lastSets!
            : 3;
        var reps = _repsIntFromWorkoutGroupLine(line);
        if (reps <= 0) reps = 12;
        final rtw = _repsTextFromWorkoutGroupLine(line);
        await _db
            .into(_db.dayWorkoutExercises)
            .insert(
              DayWorkoutExercisesCompanion.insert(
                id: _uuid.v4(),
                dayWorkoutId: dayWorkoutId,
                exerciseId: line.exerciseId,
                sortOrder: Value(line.sortOrder),
                sets: sets,
                reps: reps,
                repsText: Value(rtw),
                loadKg: Value(line.lastLoadKg),
                restBetweenSetsSec: Value(line.restBetweenSetsSec),
                trainingMethodId: Value(line.trainingMethodId),
                comboId: Value(line.comboId),
              ),
            );
        added++;
      }
    });
    if (added > 0) {
      await (_db.update(_db.dayWorkouts)
            ..where((x) => x.id.equals(dayWorkoutId)))
          .write(DayWorkoutsCompanion(updatedAt: Value(DateTime.now())));
      await _audit(
        'repair_day_workout_exercises',
        'day_workout',
        entityId: dayWorkoutId,
        payload: {'from_workout_group_id': gid, 'lines_added': added},
      );
    }
    return added;
  }

  Future<DayWorkoutEntity?> getDayWorkout(String id) async {
    final w = await _dayWorkoutRow(id);
    if (w == null) return null;
    final s = await getStudentById(w.studentId);
    if (s == null || !_session.canAccessStudent(s)) return null;
    final cal = weekScheduleLocalCalendarDate(w.dayDate);
    if (!isArchivedStudentWorkoutVisibleOnCalendarDay(
      isArchived: s.isArchived,
      archivedAt: s.archivedAt,
      workoutCalendarDay: cal,
    )) {
      return null;
    }
    return w;
  }

  /// Linha local do treino (ignora política de aluno inativo no calendário) — ex.: deep link.
  Future<DayWorkoutEntity?> getDayWorkoutLocalRow(String id) =>
      _dayWorkoutRow(id);

  /// Antes de abrir o treino no calendário, força um pull pontual da nuvem para
  /// reduzir atraso entre dispositivos (aluno/personal/admin).
  Future<void> refreshDayWorkoutFromCloud(String dayWorkoutId) async {
    final muted = _dayWorkoutCloudPullMutedUntil;
    if (muted != null && DateTime.now().isBefore(muted)) {
      return;
    }
    try {
      await _remote.refreshDayWorkoutFromCloud(dayWorkoutId);
    } catch (_) {
      // Best effort: a UI continua com o snapshot local.
    }
  }

  /// Antes de abrir/avaliar o planejamento semanal, força pull pontual da nuvem
  /// para o aluno+semana (best effort).
  Future<void> refreshStudentWeekScheduleFromCloud(
    String studentId, {
    required DateTime weekMonday,
  }) async {
    try {
      await _remote.refreshStudentWeekScheduleFromCloud(
        studentId,
        weekMonday: weekMonday,
      );
    } catch (_) {
      // Best effort: UI segue com snapshot local.
    }
  }

  Future<void> refreshExercisesCatalogFromCloud() async {
    try {
      await _remote.refreshExercisesCatalogFromCloud();
    } catch (_) {
      // Best effort: mantém cache local.
    }
  }

  Future<void> refreshExercisesByIdsFromCloud(
    Iterable<String> exerciseIds,
  ) async {
    try {
      await _remote.refreshExercisesByIdsFromCloud(exerciseIds);
    } catch (_) {
      // Best effort: mantém cache local.
    }
  }

  /// Pré-carrega histórico concluído recente do aluno para comparação de score
  /// (ex.: % vs último treino do mesmo exercício) entre dispositivos.
  Future<void> prewarmCompletedHistoryForWorkout(
    String dayWorkoutId, {
    int limit = 40,
  }) async {
    try {
      final w = await _dayWorkoutRow(dayWorkoutId);
      if (w == null) return;
      await _remote.refreshRecentCompletedHistoryForStudent(
        w.studentId,
        limit: limit,
      );
    } catch (_) {
      // Best effort: UI segue com o histórico local disponível.
    }
  }

  Stream<DayWorkoutEntity?> watchDayWorkout(String id) {
    return (_db.select(_db.dayWorkouts)..where((w) => w.id.equals(id)))
        .watch()
        .map((list) => list.singleOrNull)
        .asyncMap((w) async {
          if (w == null) return null;
          final s = await getStudentById(w.studentId);
          if (s == null || !_session.canAccessStudent(s)) return null;
          final cal = weekScheduleLocalCalendarDate(w.dayDate);
          if (!isArchivedStudentWorkoutVisibleOnCalendarDay(
            isArchived: s.isArchived,
            archivedAt: s.archivedAt,
            workoutCalendarDay: cal,
          )) {
            return null;
          }
          return w;
        });
  }

  /// Treinos `started` do aluno (gadget “ao vivo” / overlay).
  Stream<List<DayWorkoutEntity>> watchStudentStartedDayWorkouts(
    String studentId,
  ) async* {
    await requireStudentAccess(studentId);
    yield* (_db.select(_db.dayWorkouts)..where(
          (w) => w.studentId.equals(studentId) & w.status.equals('started'),
        ))
        .watch();
  }

  /// Snapshot pontual (ex.: ao pausar app para atualizar Live Activity no lock screen).
  Future<List<DayWorkoutEntity>> fetchStudentStartedDayWorkouts(
    String studentId,
  ) async {
    await requireStudentAccess(studentId);
    return (_db.select(_db.dayWorkouts)..where(
          (w) => w.studentId.equals(studentId) & w.status.equals('started'),
        ))
        .get();
  }

  /// Treinos `started` que a sessão atual pode ver (aluno: só o seu; personal: os seus alunos; admin: todos).
  Stream<List<DayWorkoutEntity>> watchAccessibleStartedDayWorkouts() {
    return (_db.select(_db.dayWorkouts)
          ..where((w) => w.status.equals('started')))
        .watch()
        .asyncMap(_visibleDayWorkouts);
  }

  Future<List<DayWorkoutEntity>> fetchAccessibleStartedDayWorkouts() async {
    final raw = await (_db.select(
      _db.dayWorkouts,
    )..where((w) => w.status.equals('started'))).get();
    return _visibleDayWorkouts(raw);
  }

  Stream<List<DayWorkoutExerciseEntity>> watchDayWorkoutExercises(
    String dayWorkoutId,
  ) async* {
    // Importante para UX: não bloquear o stream por checagem de permissão/DB,
    // senão a sheet pode ficar em loading infinito quando o SQLite está ocupado.
    //
    // As operações mutáveis (append/edit/delete) continuam exigindo acesso via
    // [_requireAccessForDayWorkoutLineId] e [_requireAccessForDayWorkoutId].
    yield* (_db.select(_db.dayWorkoutExercises)
          ..where((e) => e.dayWorkoutId.equals(dayWorkoutId))
          ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
        .watch();
  }

  Future<List<DayWorkoutExerciseEntity>> getDayWorkoutExercises(
    String dayWorkoutId,
  ) async {
    await _requireAccessForDayWorkoutId(dayWorkoutId);
    return (_db.select(_db.dayWorkoutExercises)
          ..where((e) => e.dayWorkoutId.equals(dayWorkoutId))
          ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
        .get();
  }

  /// Busca uma linha de exercício por id para validação de persistência local
  /// imediatamente após o registo de série na UI.
  Future<DayWorkoutExerciseEntity?> getDayWorkoutExerciseById(
    String lineId,
  ) async {
    await _requireAccessForDayWorkoutLineId(lineId);
    return (_db.select(
      _db.dayWorkoutExercises,
    )..where((e) => e.id.equals(lineId))).getSingleOrNull();
  }

  /// Para descanso entre séries: no último exercício do bloco [comboId] oferece intervalo; entre movimentos do combo, não.
  Future<bool> isLastLineInExerciseCombo(String lineId) async {
    final line = await (_db.select(
      _db.dayWorkoutExercises,
    )..where((e) => e.id.equals(lineId))).getSingleOrNull();
    if (line == null) return true;
    final cid = line.comboId?.trim();
    if (cid == null || cid.isEmpty) return true;
    await _requireAccessForDayWorkoutId(line.dayWorkoutId);
    final same =
        await (_db.select(_db.dayWorkoutExercises)
              ..where(
                (e) =>
                    e.dayWorkoutId.equals(line.dayWorkoutId) &
                    e.comboId.equals(cid),
              )
              ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
            .get();
    if (same.isEmpty) return true;
    return same.last.id == line.id;
  }

  Future<
    List<({DayWorkoutEntity workout, List<DayWorkoutExerciseEntity> exercises})>
  >
  completedWorkoutSnapshots({
    required String studentId,
    DateTime? fromInclusive,
    DateTime? toExclusive,
  }) async {
    await requireStudentAccess(studentId);
    final q = _db.select(_db.dayWorkouts)
      ..where(
        (w) => w.studentId.equals(studentId) & w.status.equals('completed'),
      );
    if (fromInclusive != null) {
      q.where((w) => w.dayDate.isBiggerOrEqualValue(fromInclusive));
    }
    if (toExclusive != null) {
      q.where((w) => w.dayDate.isSmallerThanValue(toExclusive));
    }
    q.orderBy([
      (w) => OrderingTerm.asc(w.dayDate),
      (w) => OrderingTerm.asc(w.completedAt),
    ]);
    final workouts = await q.get();
    final out =
        <
          ({DayWorkoutEntity workout, List<DayWorkoutExerciseEntity> exercises})
        >[];
    for (final workout in workouts) {
      final exercises =
          await (_db.select(_db.dayWorkoutExercises)
                ..where((e) => e.dayWorkoutId.equals(workout.id))
                ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
              .get();
      out.add((workout: workout, exercises: exercises));
    }
    return out;
  }

  /// Score do exercício no último treino concluído anterior (mesmo aluno + exercício).
  /// Retorna `null` quando não há histórico.
  Future<double?> previousCompletedExerciseScoreForWorkout({
    required String dayWorkoutId,
    required String exerciseId,
  }) async {
    await _requireAccessForDayWorkoutId(dayWorkoutId);
    final current = await _dayWorkoutRow(dayWorkoutId);
    if (current == null) return null;

    final cutoff = current.completedAt ?? DateTime.now();
    final join =
        _db.select(_db.dayWorkoutExercises).join([
            innerJoin(
              _db.dayWorkouts,
              _db.dayWorkouts.id.equalsExp(
                _db.dayWorkoutExercises.dayWorkoutId,
              ),
            ),
          ])
          ..where(
            _db.dayWorkoutExercises.exerciseId.equals(exerciseId) &
                _db.dayWorkouts.studentId.equals(current.studentId) &
                _db.dayWorkouts.status.equals('completed') &
                _db.dayWorkouts.id.equals(dayWorkoutId).not() &
                _db.dayWorkouts.completedAt.isSmallerThanValue(cutoff),
          )
          ..orderBy([OrderingTerm.desc(_db.dayWorkouts.completedAt)])
          ..limit(1);

    final row = await join.getSingleOrNull();
    if (row == null) return null;
    final line = row.readTable(_db.dayWorkoutExercises);
    final stored = line.exerciseScore;
    if (stored != null) return stored;
    final decoded = DayWorkoutPerformedSetCodec.decode(line.performedSetsJson);
    if (decoded.isNotEmpty) {
      return DayWorkoutPerformedSetCodec.totalExerciseScore(decoded);
    }
    return scoring.prescribedExerciseLineScore(
      sets: line.sets,
      loadKg: line.loadKg ?? 0,
      reps: line.reps,
    );
  }

  /// [DayWorkoutEntity.workoutScore] do treino concluído **imediatamente anterior**
  /// do mesmo aluno (exclui o treino atual). `null` se não há histórico.
  Future<double?> previousCompletedWorkoutScore({
    required String dayWorkoutId,
  }) async {
    await _requireAccessForDayWorkoutId(dayWorkoutId);
    final current = await _dayWorkoutRow(dayWorkoutId);
    if (current == null) return null;

    final cutoff = current.completedAt ?? DateTime.now();
    final prev = await (_db.select(_db.dayWorkouts)
          ..where(
            (w) =>
                w.studentId.equals(current.studentId) &
                w.status.equals('completed') &
                w.id.equals(dayWorkoutId).not() &
                w.completedAt.isSmallerThanValue(cutoff),
          )
          ..orderBy([
            (w) => OrderingTerm.desc(w.completedAt),
            (w) => OrderingTerm.desc(w.dayDate),
          ]))
        .getSingleOrNull();
    return prev?.workoutScore;
  }

  /// Maior [DayWorkoutPerformedSet.loadKg] entre as séries do **último treino
  /// concluído** anterior com o mesmo aluno + exercício (não conta o treino atual).
  /// `null` se não há treino anterior ou não há carga registada nas séries feitas.
  Future<double?> maxLoadKgLastCompletedSameExerciseForWorkout({
    required String dayWorkoutId,
    required String exerciseId,
  }) async {
    await _requireAccessForDayWorkoutId(dayWorkoutId);
    final current = await _dayWorkoutRow(dayWorkoutId);
    if (current == null) return null;

    final cutoff = current.completedAt ?? DateTime.now();
    final join =
        _db.select(_db.dayWorkoutExercises).join([
            innerJoin(
              _db.dayWorkouts,
              _db.dayWorkouts.id.equalsExp(
                _db.dayWorkoutExercises.dayWorkoutId,
              ),
            ),
          ])
          ..where(
            _db.dayWorkoutExercises.exerciseId.equals(exerciseId) &
                _db.dayWorkouts.studentId.equals(current.studentId) &
                _db.dayWorkouts.status.equals('completed') &
                _db.dayWorkouts.id.equals(dayWorkoutId).not() &
                _db.dayWorkouts.completedAt.isSmallerThanValue(cutoff),
          )
          ..orderBy([OrderingTerm.desc(_db.dayWorkouts.completedAt)])
          ..limit(1);

    final row = await join.getSingleOrNull();
    if (row == null) return null;
    final line = row.readTable(_db.dayWorkoutExercises);
    final decoded = DayWorkoutPerformedSetCodec.decode(line.performedSetsJson);
    if (decoded.isEmpty) return null;
    double? maxKg;
    for (final s in decoded) {
      final kg = s.loadKg;
      if (kg == null) continue;
      if (maxKg == null || kg > maxKg) maxKg = kg;
    }
    return maxKg;
  }

  /// Última série registrada para o mesmo aluno + exercício da [lineId].
  /// Não considera a própria linha atual.
  Future<DayWorkoutPerformedSet?> lastPerformedSetSeedForLine(
    String lineId,
  ) async {
    await _requireAccessForDayWorkoutLineId(lineId);
    final line = await (_db.select(
      _db.dayWorkoutExercises,
    )..where((e) => e.id.equals(lineId))).getSingleOrNull();
    if (line == null) return null;

    final workout = await _dayWorkoutRow(line.dayWorkoutId);
    if (workout == null) return null;

    final q =
        _db.select(_db.dayWorkoutExercises).join([
            innerJoin(
              _db.dayWorkouts,
              _db.dayWorkouts.id.equalsExp(
                _db.dayWorkoutExercises.dayWorkoutId,
              ),
            ),
          ])
          ..where(
            _db.dayWorkoutExercises.id.equals(lineId).not() &
                _db.dayWorkoutExercises.exerciseId.equals(line.exerciseId) &
                _db.dayWorkouts.studentId.equals(workout.studentId) &
                _dayWorkoutNotCancelled(_db.dayWorkouts),
          )
          ..orderBy([
            OrderingTerm.desc(_db.dayWorkouts.dayDate),
            OrderingTerm.desc(_db.dayWorkouts.updatedAt),
          ]);

    final rows = await q.get();
    for (final row in rows) {
      final exerciseRow = row.readTable(_db.dayWorkoutExercises);
      final performed = DayWorkoutPerformedSetCodec.decode(
        exerciseRow.performedSetsJson,
      );
      if (performed.isNotEmpty) return performed.last;
    }
    return null;
  }

  Duration _wallSpanPerformed(List<DayWorkoutPerformedSet> performed) {
    final a = DayWorkoutPerformedSetCodec.minLoggedAtMs(performed);
    final b = DayWorkoutPerformedSetCodec.maxLoggedAtMs(performed);
    if (a == null || b == null || b < a) return Duration.zero;
    return Duration(milliseconds: b - a);
  }

  Future<double> _sumPerformedScoresForDayWorkout(String dayWorkoutId) async {
    final lines = await getDayWorkoutExercises(dayWorkoutId);
    var sum = 0.0;
    for (final e in lines) {
      sum += DayWorkoutPerformedSetCodec.totalExerciseScore(
        DayWorkoutPerformedSetCodec.decode(e.performedSetsJson),
      );
    }
    return sum <= 0 ? 1.0 : sum;
  }

  /// Resumo comparativo (treino anterior concluído vs atual) quando a linha já tem
  /// todas as séries registadas. Usa apenas dados locais / JSON já espelhados.
  Future<ExerciseSessionComparison?> getExerciseSessionComparison(
    String dayWorkoutExerciseLineId,
  ) async {
    await _requireAccessForDayWorkoutLineId(dayWorkoutExerciseLineId);
    final curLine =
        await (_db.select(
              _db.dayWorkoutExercises,
            )..where((e) => e.id.equals(dayWorkoutExerciseLineId)))
            .getSingleOrNull();
    if (curLine == null) return null;
    final performed = DayWorkoutPerformedSetCodec.decode(
      curLine.performedSetsJson,
    );
    if (curLine.sets <= 0 || performed.length < curLine.sets) return null;

    final exRow =
        await (_db.select(
              _db.exercises,
            )..where((e) => e.id.equals(curLine.exerciseId)))
            .getSingleOrNull();
    final exerciseName = (exRow?.name ?? '').trim().isEmpty
        ? 'Exercício'
        : exRow!.name.trim();

    final prescribedContrib = scoring.perSetScoreContribution(
      loadKg: curLine.loadKg ?? 0,
      reps: curLine.reps,
    );
    final prescribedSafe =
        prescribedContrib <= 1e-9 ? 1e-6 : prescribedContrib;

    final curDw = await _dayWorkoutRow(curLine.dayWorkoutId);
    if (curDw == null) return null;

    final sumCurScores = await _sumPerformedScoresForDayWorkout(
      curLine.dayWorkoutId,
    );
    final curTotal = DayWorkoutPerformedSetCodec.totalExerciseScore(performed);
    final wkCal = curDw.watchCaloriesKcal;
    double? currentKcal;
    var hasWatch = false;
    if (wkCal != null && wkCal > 0) {
      hasWatch = true;
      currentKcal = wkCal * (curTotal / sumCurScores);
    }

    final cutoff = curDw.completedAt ?? DateTime.now();
    final prevJoin =
        _db.select(_db.dayWorkoutExercises).join([
            innerJoin(
              _db.dayWorkouts,
              _db.dayWorkouts.id.equalsExp(
                _db.dayWorkoutExercises.dayWorkoutId,
              ),
            ),
          ])
          ..where(
            _db.dayWorkoutExercises.exerciseId.equals(curLine.exerciseId) &
                _db.dayWorkouts.studentId.equals(curDw.studentId) &
                _db.dayWorkouts.status.equals('completed') &
                _db.dayWorkouts.id.equals(curLine.dayWorkoutId).not() &
                _db.dayWorkouts.completedAt.isSmallerThanValue(cutoff),
          )
          ..orderBy([OrderingTerm.desc(_db.dayWorkouts.completedAt)])
          ..limit(1);

    final prevJoined = await prevJoin.getSingleOrNull();
    DayWorkoutExerciseEntity? prevLine;
    DayWorkoutEntity? prevDw;
    if (prevJoined != null) {
      prevLine = prevJoined.readTable(_db.dayWorkoutExercises);
      prevDw = prevJoined.readTable(_db.dayWorkouts);
    }
    final prevPerformed = prevLine == null
        ? const <DayWorkoutPerformedSet>[]
        : DayWorkoutPerformedSetCodec.decode(prevLine.performedSetsJson);
    final prevPrescribedContrib = prevLine == null
        ? 0.0
        : scoring.perSetScoreContribution(
            loadKg: prevLine.loadKg ?? 0,
            reps: prevLine.reps,
          );
    final prevPrescribedSafe =
        prevPrescribedContrib <= 1e-9 ? 1e-6 : prevPrescribedContrib;

    double? prevTotal;
    Duration? prevWall;
    double? previousKcal;
    if (prevLine != null && prevPerformed.isNotEmpty) {
      prevTotal = DayWorkoutPerformedSetCodec.totalExerciseScore(
        prevPerformed,
      );
      prevWall = _wallSpanPerformed(prevPerformed);
      final pk = prevDw?.watchCaloriesKcal;
      if (pk != null && pk > 0) {
        final sumPrev = await _sumPerformedScoresForDayWorkout(
          prevLine.dayWorkoutId,
        );
        if (sumPrev > 0) {
          previousKcal = pk * (prevTotal / sumPrev);
        }
      }
    }

    double? totalEvol;
    if (prevTotal != null && prevTotal > 1e-6) {
      final pt = prevTotal;
      totalEvol = (curTotal - pt) / pt * 100.0;
    }

    final rows = <ExerciseSetComparisonRow>[];
    for (var i = 0; i < performed.length; i++) {
      final s = performed[i];
      final curSetScore = scoring.perSetScoreContribution(
        loadKg: s.loadKg ?? curLine.loadKg ?? 0,
        reps: s.reps,
      );
      final curPct = (curSetScore / prescribedSafe) * 100.0;

      double? prevSetScore;
      double? prevPct;
      double? evol;
      if (i < prevPerformed.length) {
        final ps = prevPerformed[i];
        prevSetScore = scoring.perSetScoreContribution(
          loadKg: ps.loadKg ?? prevLine!.loadKg ?? 0,
          reps: ps.reps,
        );
        prevPct = (prevSetScore / prevPrescribedSafe) * 100.0;
        if (prevSetScore > 1e-6) {
          evol = (curSetScore - prevSetScore) / prevSetScore * 100.0;
        }
      }

      final int? restAfterCur =
          i < performed.length - 1 ? performed[i].restCountdownElapsedMs : null;
      final int? restAfterPrev = i < prevPerformed.length - 1
          ? prevPerformed[i].restCountdownElapsedMs
          : null;
      final int? restPrescribed =
          i < performed.length - 1
          ? (performed[i].restPrescribedSec ?? curLine.restBetweenSetsSec)
          : null;

      rows.add(
        ExerciseSetComparisonRow(
          setNumber: i + 1,
          currentSetScore: curSetScore,
          previousSetScore: prevSetScore,
          currentPctOfPrescribed: curPct,
          previousPctOfPrescribed: prevPct,
          scoreEvolutionPctVsPrevious: evol,
          restAfterCurrentCountdownMs: restAfterCur,
          restAfterPreviousCountdownMs: restAfterPrev,
          restPrescribedSec: restPrescribed,
        ),
      );
    }

    return ExerciseSessionComparison(
      exerciseName: exerciseName,
      sets: rows,
      currentWallDuration: _wallSpanPerformed(performed),
      previousWallDuration: prevWall,
      currentTotalScore: curTotal,
      previousTotalScore: prevTotal,
      totalScoreEvolutionPctVsPrevious: totalEvol,
      currentEstimatedKcal: currentKcal,
      previousEstimatedKcal: previousKcal,
      hasWorkoutWatchKcal: hasWatch,
    );
  }

  /// Últimos [limit] treinos **concluídos**, ordenados do mais **antigo** ao mais **novo** (eixo X).
  /// [scorePerMinute] = Σ score dos exercícios ÷ tempo ativo em minutos.
  Future<List<({DateTime completedAt, double scorePerMinute})>>
  lastCompletedWorkoutRendimentoSeries({
    required String studentId,
    int limit = 7,
  }) async {
    await requireStudentAccess(studentId);
    final rows =
        await (_db.select(_db.dayWorkouts)
              ..where(
                (w) =>
                    w.studentId.equals(studentId) &
                    w.status.equals('completed'),
              )
              ..orderBy([
                (w) => OrderingTerm.desc(w.completedAt),
                (w) => OrderingTerm.desc(w.dayDate),
              ])
              ..limit(limit))
            .get();

    final out = <({DateTime completedAt, double scorePerMinute})>[];
    for (final w in rows.reversed) {
      final exercises = await getDayWorkoutExercises(w.id);
      final score = _rendimentoPorMinuto(w: w, exercises: exercises);
      final at =
          w.completedAt ??
          DateTime(w.dayDate.year, w.dayDate.month, w.dayDate.day);
      out.add((completedAt: at, scorePerMinute: score));
    }
    return out;
  }

  /// Série diária (7 dias): cada dia civil no intervalo (hoje-6 … hoje) aparece no gráfico.
  /// Se não houver treino concluído no dia, o score é 0.
  ///
  /// [scorePerMinute] do dia = média do score/min dos treinos concluídos naquele dia.
  Future<List<({DateTime day, double scorePerMinute})>>
  last7DaysRendimentoDailySeries({required String studentId}) async {
    await requireStudentAccess(studentId);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    final endExclusive = today.add(const Duration(days: 1));

    final rows =
        await (_db.select(_db.dayWorkouts)
              ..where(
                (w) =>
                    w.studentId.equals(studentId) &
                    w.status.equals('completed') &
                    w.dayDate.isBiggerOrEqualValue(start) &
                    w.dayDate.isSmallerThanValue(endExclusive),
              )
              ..orderBy([
                (w) => OrderingTerm.asc(w.dayDate),
                (w) => OrderingTerm.asc(w.completedAt),
              ]))
            .get();

    final scoresByDay = <DateTime, List<double>>{};
    for (final w in rows) {
      final d = DateTime(w.dayDate.year, w.dayDate.month, w.dayDate.day);
      final exercises = await getDayWorkoutExercises(w.id);
      final score = _rendimentoPorMinuto(w: w, exercises: exercises);
      scoresByDay.putIfAbsent(d, () => <double>[]).add(score);
    }

    final out = <({DateTime day, double scorePerMinute})>[];
    for (var i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      final list = scoresByDay[d];
      if (list == null || list.isEmpty) {
        out.add((day: d, scorePerMinute: 0));
      } else {
        final sum = list.fold<double>(0, (a, b) => a + b);
        out.add((day: d, scorePerMinute: sum / list.length));
      }
    }
    return out;
  }

  /// Até [limit] treinos concluídos **mais recentes** em que o score (por minuto ativo)
  /// **subiu em cada um dos últimos 3 treinos** em sequência: numa janela de 4 treinos
  /// cronológicos, vale [s₀ < s₁ < s₂ < s₃]; devolve o treino que encerra a sequência ([s₃]).
  /// Ordem no resultado: cronológica (mais antigo → mais novo no eixo X do gráfico).
  Future<List<({DateTime completedAt, double scorePerMinute})>>
  lastWorkoutsWithThreeConsecutiveScoreIncreases({
    required String studentId,
    int limit = 10,
  }) async {
    await requireStudentAccess(studentId);
    final rows =
        await (_db.select(_db.dayWorkouts)
              ..where(
                (w) =>
                    w.studentId.equals(studentId) &
                    w.status.equals('completed'),
              )
              ..orderBy([
                (w) => OrderingTerm.asc(w.completedAt),
                (w) => OrderingTerm.asc(w.dayDate),
              ]))
            .get();

    if (rows.length < 4) return [];

    final scores = <double>[];
    for (final w in rows) {
      final exercises = await getDayWorkoutExercises(w.id);
      scores.add(_rendimentoPorMinuto(w: w, exercises: exercises));
    }

    final matches = <({DateTime completedAt, double scorePerMinute})>[];
    for (var i = 3; i < rows.length; i++) {
      final s0 = scores[i - 3];
      final s1 = scores[i - 2];
      final s2 = scores[i - 1];
      final s3 = scores[i];
      if (s1 > s0 && s2 > s1 && s3 > s2) {
        final w = rows[i];
        final at =
            w.completedAt ??
            DateTime(w.dayDate.year, w.dayDate.month, w.dayDate.day);
        matches.add((completedAt: at, scorePerMinute: s3));
      }
    }

    if (matches.isEmpty) return [];
    if (matches.length <= limit) return matches;
    return matches.sublist(matches.length - limit);
  }

  /// Por grupo de treino ([sourceWorkoutGroupId]), o **melhor** score por minuto ativo entre treinos
  /// **concluídos** cuja data efetiva ([completedAt] ou início do [dayDate]) cai em **[window]** até agora.
  /// Ordenado do maior score para o menor; no máximo [maxGroups] linhas.
  Future<List<({String groupId, String groupName, double bestScorePerMinute})>>
  workoutGroupsBestRendimentoInWindow({
    required String studentId,
    required Duration window,
    int maxGroups = 15,
  }) async {
    await requireStudentAccess(studentId);
    final now = DateTime.now();
    final cutoff = now.subtract(window);

    final rows =
        await (_db.select(_db.dayWorkouts)..where(
              (w) =>
                  w.studentId.equals(studentId) & w.status.equals('completed'),
            ))
            .get();

    DateTime effectiveAt(DayWorkoutEntity w) =>
        w.completedAt ??
        DateTime(w.dayDate.year, w.dayDate.month, w.dayDate.day);

    final byGroupBest = <String, double>{};
    for (final w in rows) {
      final gid = w.sourceWorkoutGroupId?.trim();
      if (gid == null || gid.isEmpty) continue;
      if (effectiveAt(w).isBefore(cutoff)) continue;
      final exercises = await getDayWorkoutExercises(w.id);
      final score = _rendimentoPorMinuto(w: w, exercises: exercises);
      final prev = byGroupBest[gid];
      if (prev == null || score > prev) {
        byGroupBest[gid] = score;
      }
    }

    if (byGroupBest.isEmpty) return [];

    final sorted = byGroupBest.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final out =
        <({String groupId, String groupName, double bestScorePerMinute})>[];
    final take = sorted.length > maxGroups ? maxGroups : sorted.length;
    for (var i = 0; i < take; i++) {
      final e = sorted[i];
      final g = await (_db.select(
        _db.workoutGroups,
      )..where((t) => t.id.equals(e.key))).getSingleOrNull();
      final name = g?.name.trim();
      out.add((
        groupId: e.key,
        groupName: (name == null || name.isEmpty) ? 'Grupo' : name,
        bestScorePerMinute: e.value,
      ));
    }
    return out;
  }

  /// Atalho: melhor score por grupo nas últimas 4 semanas (28 dias).
  Future<List<({String groupId, String groupName, double bestScorePerMinute})>>
  workoutGroupsBestRendimentoLast4Weeks({
    required String studentId,
    int maxGroups = 15,
  }) {
    return workoutGroupsBestRendimentoInWindow(
      studentId: studentId,
      window: const Duration(days: 28),
      maxGroups: maxGroups,
    );
  }

  /// Acrescenta uma série executada (JSON). Não altera [reps] prescrito da linha.
  Future<void> appendDayWorkoutExercisePerformedSet({
    required String lineId,
    double? loadKg,
    required int reps,
  }) async {
    _syncTrace(
      'append_set/start line=$lineId reps=$reps load=${loadKg ?? 'null'}',
    );
    muteDayWorkoutCloudPullFor(const Duration(seconds: 3));
    await _requireAccessForDayWorkoutLineId(lineId);
    final row = await (_db.select(
      _db.dayWorkoutExercises,
    )..where((x) => x.id.equals(lineId))).getSingleOrNull();
    if (row == null) {
      throw ArgumentError('Linha de exercício não encontrada.');
    }
    final existing = DayWorkoutPerformedSetCodec.decode(row.performedSetsJson);
    if (existing.length >= row.sets) {
      throw ArgumentError(
        'Já foram registradas as ${row.sets} série(s) planejadas.',
      );
    }
    final workout = await _dayWorkoutRow(row.dayWorkoutId);
    if (workout != null && workout.status == 'started' && loadKg == null) {
      throw ArgumentError(
        'Com o treino em execução, preencha a carga (kg) e as repetições em cada série.',
      );
    }
    final next = [
      ...existing,
      DayWorkoutPerformedSet(
        loadKg: loadKg,
        reps: reps,
        loggedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    ];
    final exerciseScore = DayWorkoutPerformedSetCodec.totalExerciseScore(next);
    final newLoadKg = next.isEmpty
        ? row.loadKg
        : (next.last.loadKg ?? row.loadKg);
    final dayWorkoutId = row.dayWorkoutId;
    final now = DateTime.now();
    final deviceId = await _syncDeviceId();
    final workoutBefore = await _dayWorkoutRow(dayWorkoutId);
    final appendAuditId = _uuid.v4();
    final touchAuditId = _uuid.v4();

    await _db.transaction(() async {
      await (_db.update(
        _db.dayWorkoutExercises,
      )..where((x) => x.id.equals(lineId))).write(
        DayWorkoutExercisesCompanion(
          performedSetsJson: Value(DayWorkoutPerformedSetCodec.encode(next)),
          exerciseScore: Value(exerciseScore),
          loadKg: Value(newLoadKg),
          updatedAt: Value(now),
          revision: Value(_nextRevision(row.revision)),
          lastModifiedByDeviceId: Value(deviceId),
          syncStatus: const Value('pending'),
        ),
      );
      if (workoutBefore != null) {
        await (_db.update(_db.dayWorkouts)
              ..where((w) => w.id.equals(dayWorkoutId)))
            .write(
              DayWorkoutsCompanion(
                updatedAt: Value(now),
                revision: Value(_nextRevision(workoutBefore.revision)),
                lastModifiedByDeviceId: Value(deviceId),
                syncStatus: const Value('pending'),
              ),
            );
      }
      await _db
          .into(_db.auditLogs)
          .insert(
            AuditLogsCompanion.insert(
              id: appendAuditId,
              action: 'append_set',
              entityType: 'day_workout_exercise',
              entityId: Value(lineId),
            ),
          );
      await _db
          .into(_db.auditLogs)
          .insert(
            AuditLogsCompanion.insert(
              id: touchAuditId,
              action: 'touch',
              entityType: 'day_workout',
              entityId: Value(dayWorkoutId),
              payloadJson: Value(jsonEncode({'reason': 'append_set'})),
            ),
          );
    });

    _syncTrace(
      'append_set/local_commit_ok line=$lineId dayWorkout=$dayWorkoutId sets_now=${next.length}/${row.sets} score=$exerciseScore',
    );

    await _refreshWorkoutScoreForDayWorkoutAtNow(dayWorkoutId);

    unawaited(
      _remote.enqueueAudit(
        auditLogId: appendAuditId,
        action: 'append_set',
        entityType: 'day_workout_exercise',
        entityId: lineId,
      ),
    );
    unawaited(
      _remote.enqueueAudit(
        auditLogId: touchAuditId,
        action: 'touch',
        entityType: 'day_workout',
        entityId: dayWorkoutId,
        payload: {'reason': 'append_set'},
      ),
    );
    unawaited(_remote.recoverPendingWork());
    _syncTrace(
      'append_set/enqueued line=$lineId audit_append=$appendAuditId audit_touch=$touchAuditId',
    );
  }

  /// Grava tempos de descanso na **última** série da linha (após modal entre séries).
  Future<void> patchLastPerformedSetRestTelemetry({
    required String lineId,
    required int prescribedSec,
    required int countdownElapsedMs,
    required int postPhaseMs,
  }) async {
    await _requireAccessForDayWorkoutLineId(lineId);
    final row = await (_db.select(
      _db.dayWorkoutExercises,
    )..where((x) => x.id.equals(lineId))).getSingleOrNull();
    if (row == null) {
      throw ArgumentError('Linha de exercício não encontrada.');
    }
    final existing = DayWorkoutPerformedSetCodec.decode(row.performedSetsJson);
    if (existing.isEmpty) return;
    final last = existing.last;
    final next = [...existing];
    next[next.length - 1] = DayWorkoutPerformedSet(
      loadKg: last.loadKg,
      reps: last.reps,
      loggedAtMs: last.loggedAtMs,
      restPrescribedSec: prescribedSec,
      restCountdownElapsedMs: countdownElapsedMs,
      postRestModalMs: postPhaseMs,
    );
    await _persistDayWorkoutPerformedSets(
      lineId,
      row,
      next,
      syncParentWorkoutScore: false,
    );
    await _audit('patch_set_rest', 'day_workout_exercise', entityId: lineId);
    await _touchDayWorkoutAfterLineMutation(
      row.dayWorkoutId,
      reason: 'patch_set_rest',
    );
    unawaited(_remote.recoverPendingWork());
  }

  Future<void> _persistDayWorkoutPerformedSets(
    String lineId,
    DayWorkoutExerciseEntity row,
    List<DayWorkoutPerformedSet> next, {
    bool syncParentWorkoutScore = true,
  }) async {
    final deviceId = await _syncDeviceId();
    final exerciseScore = DayWorkoutPerformedSetCodec.totalExerciseScore(next);
    final newLoadKg = next.isEmpty
        ? row.loadKg
        : (next.last.loadKg ?? row.loadKg);
    await (_db.update(
      _db.dayWorkoutExercises,
    )..where((x) => x.id.equals(lineId))).write(
      DayWorkoutExercisesCompanion(
        performedSetsJson: Value(DayWorkoutPerformedSetCodec.encode(next)),
        exerciseScore: Value(exerciseScore),
        loadKg: Value(newLoadKg),
        updatedAt: Value(DateTime.now()),
        revision: Value(_nextRevision(row.revision)),
        lastModifiedByDeviceId: Value(deviceId),
        syncStatus: const Value('pending'),
      ),
    );
    if (syncParentWorkoutScore) {
      await _refreshWorkoutScoreForDayWorkoutAtNow(row.dayWorkoutId);
    }
  }

  Future<void> _touchDayWorkoutAfterLineMutation(
    String dayWorkoutId, {
    required String reason,
  }) async {
    final now = DateTime.now();
    final deviceId = await _syncDeviceId();
    final current = await _dayWorkoutRow(dayWorkoutId);
    await (_db.update(_db.dayWorkouts)..where((w) => w.id.equals(dayWorkoutId)))
        .write(
          DayWorkoutsCompanion(
            updatedAt: Value(now),
            revision: Value(_nextRevision(current?.revision ?? 0)),
            lastModifiedByDeviceId: Value(deviceId),
            syncStatus: const Value('pending'),
          ),
        );
    await _audit(
      'touch',
      'day_workout',
      entityId: dayWorkoutId,
      payload: {'reason': reason},
    );
    unawaited(_remote.recoverPendingWork());
  }

  /// Remove a série executada no índice [performedIndex] (0-based na lista JSON).
  Future<void> removeDayWorkoutExercisePerformedSetAt({
    required String lineId,
    required int performedIndex,
  }) async {
    await _requireAccessForDayWorkoutLineId(lineId);
    final row = await (_db.select(
      _db.dayWorkoutExercises,
    )..where((x) => x.id.equals(lineId))).getSingleOrNull();
    if (row == null) {
      throw ArgumentError('Linha de exercício não encontrada.');
    }
    final existing = DayWorkoutPerformedSetCodec.decode(row.performedSetsJson);
    if (performedIndex < 0 || performedIndex >= existing.length) {
      throw ArgumentError('Índice de série inválido.');
    }
    final next = [...existing]..removeAt(performedIndex);
    await _persistDayWorkoutPerformedSets(lineId, row, next);
    await _audit('remove_set', 'day_workout_exercise', entityId: lineId);
    await _touchDayWorkoutAfterLineMutation(
      row.dayWorkoutId,
      reason: 'remove_set',
    );
    unawaited(_remote.recoverPendingWork());
  }

  /// Atualiza carga/reps da série executada no índice [performedIndex] (0-based).
  Future<void> updateDayWorkoutExercisePerformedSetAt({
    required String lineId,
    required int performedIndex,
    double? loadKg,
    required int reps,
  }) async {
    if (reps < 1) {
      throw ArgumentError('Repetições deve ser ≥ 1.');
    }
    await _requireAccessForDayWorkoutLineId(lineId);
    final row = await (_db.select(
      _db.dayWorkoutExercises,
    )..where((x) => x.id.equals(lineId))).getSingleOrNull();
    if (row == null) {
      throw ArgumentError('Linha de exercício não encontrada.');
    }
    final existing = DayWorkoutPerformedSetCodec.decode(row.performedSetsJson);
    if (performedIndex < 0 || performedIndex >= existing.length) {
      throw ArgumentError('Índice de série inválido.');
    }
    final workout = await _dayWorkoutRow(row.dayWorkoutId);
    if (workout != null && workout.status == 'started' && loadKg == null) {
      throw ArgumentError(
        'Com o treino em execução, preencha a carga (kg) e as repetições em cada série.',
      );
    }
    final next = [...existing];
    final prev = existing[performedIndex];
    next[performedIndex] = DayWorkoutPerformedSet(
      loadKg: loadKg,
      reps: reps,
      loggedAtMs: prev.loggedAtMs,
      restPrescribedSec: prev.restPrescribedSec,
      restCountdownElapsedMs: prev.restCountdownElapsedMs,
      postRestModalMs: prev.postRestModalMs,
    );
    await _persistDayWorkoutPerformedSets(lineId, row, next);
    await _audit('update_set', 'day_workout_exercise', entityId: lineId);
    await _touchDayWorkoutAfterLineMutation(
      row.dayWorkoutId,
      reason: 'update_set',
    );
    unawaited(_remote.recoverPendingWork());
  }

  /// Só **administrador**. Remove do SQLite **todos** os treinos do aluno na data
  /// (programado, em andamento ou concluído) e as linhas de exercício; gera auditorias
  /// `delete` para o Supabase (filhas antes do pai).
  ///
  /// Retorna quantos treinos (`day_workouts`) foram apagados.
  Future<int> adminHardDeleteAllDayWorkoutsForStudent({
    required String studentId,
    required DateTime day,
  }) async {
    if (!_session.hasFullOrgAccess) {
      throw ArgumentError(
        'Apenas administradores podem excluir treinos do dia desta forma.',
      );
    }
    await requireStudentAccess(studentId);
    final dayOnly = DateTime(day.year, day.month, day.day);
    final workouts =
        await (_db.select(_db.dayWorkouts)..where(
              (w) => w.studentId.equals(studentId) & w.dayDate.equals(dayOnly),
            ))
            .get();
    if (workouts.isEmpty) return 0;

    final lineIds = <String>[];
    final workoutIds = <String>[];
    for (final w in workouts) {
      workoutIds.add(w.id);
      final lines = await (_db.select(
        _db.dayWorkoutExercises,
      )..where((e) => e.dayWorkoutId.equals(w.id))).get();
      for (final line in lines) {
        lineIds.add(line.id);
      }
    }

    await _db.transaction(() async {
      for (final lid in lineIds) {
        await (_db.delete(
          _db.dayWorkoutExercises,
        )..where((e) => e.id.equals(lid))).go();
      }
      for (final wid in workoutIds) {
        await (_db.delete(
          _db.dayWorkouts,
        )..where((d) => d.id.equals(wid))).go();
      }
    });

    for (final lid in lineIds) {
      await _audit('delete', 'day_workout_exercise', entityId: lid);
    }
    for (final wid in workoutIds) {
      await _audit('delete', 'day_workout', entityId: wid);
    }

    return workoutIds.length;
  }

  /// Cancela treino programado (troca no calendário): linha e exercícios permanecem no BD.
  Future<bool> deleteProgrammedDayWorkout(String id) async {
    await _requireAccessForDayWorkoutId(id);
    final w = await _dayWorkoutRow(id);
    if (w == null) return false;
    if (w.status != 'programmed') return false;
    final deviceId = await _syncDeviceId();
    await (_db.update(_db.dayWorkouts)..where((x) => x.id.equals(id))).write(
      DayWorkoutsCompanion(
        status: const Value('cancelled'),
        timerResumeAt: const Value(null),
        updatedAt: Value(DateTime.now()),
        deletedAt: Value(DateTime.now()),
        revision: Value(_nextRevision(w.revision)),
        lastModifiedByDeviceId: Value(deviceId),
        syncStatus: const Value('pending'),
      ),
    );
    await _audit('cancel', 'day_workout', entityId: id);
    unawaited(_remote.recoverPendingWork());
    return true;
  }

  Future<void> startDayWorkout(String id) async {
    await _requireAccessForDayWorkoutId(id);
    final cur = await _dayWorkoutRow(id);
    if (cur == null || cur.status != 'programmed') return;
    if (isCalendarDateBeforeToday(cur.dayDate)) {
      throw ArgumentError('Treinos em datas passadas não podem ser iniciados.');
    }
    final now = DateTime.now();
    final deviceId = await _syncDeviceId();
    await (_db.update(_db.dayWorkouts)..where((w) => w.id.equals(id))).write(
      DayWorkoutsCompanion(
        status: const Value('started'),
        startedAt: Value(now),
        timerResumeAt: Value(now),
        updatedAt: Value(now),
        revision: Value(_nextRevision(cur.revision)),
        lastModifiedByDeviceId: Value(deviceId),
        syncStatus: const Value('pending'),
      ),
    );
    await _audit('start', 'day_workout', entityId: id);
    unawaited(_remote.recoverPendingWork());
  }

  Future<void> pauseDayWorkout(String id) async {
    await _requireAccessForDayWorkoutId(id);
    final w = await _dayWorkoutRow(id);
    if (w == null || w.status != 'started' || w.timerResumeAt == null) return;
    final add = DateTime.now().difference(w.timerResumeAt!).inSeconds;
    final deviceId = await _syncDeviceId();
    await (_db.update(_db.dayWorkouts)..where((x) => x.id.equals(id))).write(
      DayWorkoutsCompanion(
        activeDurationSeconds: Value(w.activeDurationSeconds + add),
        // `Value.absent()` não altera a coluna; é preciso NULL para pausar o cronômetro.
        timerResumeAt: const Value(null),
        updatedAt: Value(DateTime.now()),
        revision: Value(_nextRevision(w.revision)),
        lastModifiedByDeviceId: Value(deviceId),
        syncStatus: const Value('pending'),
      ),
    );
    await _audit('pause', 'day_workout', entityId: id);
    unawaited(_remote.recoverPendingWork());
  }

  Future<void> resumeDayWorkout(String id) async {
    await _requireAccessForDayWorkoutId(id);
    final w = await _dayWorkoutRow(id);
    if (w == null || w.status != 'started' || w.timerResumeAt != null) return;
    final deviceId = await _syncDeviceId();
    await (_db.update(_db.dayWorkouts)..where((x) => x.id.equals(id))).write(
      DayWorkoutsCompanion(
        timerResumeAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        revision: Value(_nextRevision(w.revision)),
        lastModifiedByDeviceId: Value(deviceId),
        syncStatus: const Value('pending'),
      ),
    );
    await _audit('resume', 'day_workout', entityId: id);
    unawaited(_remote.recoverPendingWork());
  }

  /// Segundos de treino ativo (inclui trecho atual se cronômetro ligado).
  int effectiveActiveSeconds(DayWorkoutEntity w, DateTime now) {
    var t = w.activeDurationSeconds;
    final resume = w.timerResumeAt;
    if (resume != null) {
      t += now.difference(resume).inSeconds;
    }
    return t;
  }

  /// Soma dos volumes já registrados (carga × reps) em todas as linhas do treino.
  double sumPerformedVolumeDayWorkoutLines(
    List<DayWorkoutExerciseEntity> exercises,
  ) {
    var sum = 0.0;
    for (final e in exercises) {
      sum += DayWorkoutPerformedSetCodec.totalVolumeScore(
        DayWorkoutPerformedSetCodec.decode(e.performedSetsJson),
      );
    }
    return sum;
  }

  /// Mesma fórmula do score final do treino, para uso pontual (treinos concluídos).
  double liveWorkoutScorePerActiveMinute({
    required DayWorkoutEntity workout,
    required List<DayWorkoutExerciseEntity> exercises,
    DateTime? now,
  }) {
    final agg = _completedExerciseScoreAgg(exercises);
    final sec = effectiveActiveSeconds(workout, now ?? DateTime.now());
    final activeClamped = sec > 0 ? sec : 1;
    return scoring.workoutFinalScoreFromExerciseScores(
      exerciseScoresSum: agg.sumScores,
      activeDurationSeconds: activeClamped,
      completedExerciseCount: agg.completedCount,
    );
  }

  /// Atualiza [DayWorkoutEntity.workoutScore] só em treino **concluído** (edição tardia de séries).
  Future<void> _refreshWorkoutScoreForDayWorkoutAtNow(
    String dayWorkoutId,
  ) async {
    await _requireAccessForDayWorkoutId(dayWorkoutId);
    final w = await _dayWorkoutRow(dayWorkoutId);
    if (w == null || w.status != 'completed') return;
    final exercises = await getDayWorkoutExercises(dayWorkoutId);
    final agg = _completedExerciseScoreAgg(exercises);
    final now = DateTime.now();
    final sec = effectiveActiveSeconds(w, now);
    final activeClamped = sec > 0 ? sec : 1;
    final ws = scoring.workoutFinalScoreFromExerciseScores(
      exerciseScoresSum: agg.sumScores,
      activeDurationSeconds: activeClamped,
      completedExerciseCount: agg.completedCount,
    );
    await (_db.update(
      _db.dayWorkouts,
    )..where((x) => x.id.equals(dayWorkoutId))).write(
      DayWorkoutsCompanion(
        workoutScore: Value(ws),
        updatedAt: Value(now),
        revision: Value(_nextRevision(w.revision)),
        lastModifiedByDeviceId: Value(await _syncDeviceId()),
        syncStatus: const Value('pending'),
      ),
    );
    final prev = w.workoutScore;
    final changed = prev == null || (prev - ws).abs() > 0.0001;
    if (changed) {
      await _audit(
        'score_refresh',
        'day_workout',
        entityId: dayWorkoutId,
        payload: {'workoutScore': ws, 'activeSeconds': sec},
      );
    }
  }

  Future<void> completeDayWorkout(String id) async {
    await _requireAccessForDayWorkoutId(id);
    final before = await _dayWorkoutRow(id);
    if (before == null || before.status != 'started') return;
    if (before.timerResumeAt != null) {
      await pauseDayWorkout(id);
    }
    final w = await _dayWorkoutRow(id);
    if (w == null) return;
    final deviceId = await _syncDeviceId();
    final exercises = await getDayWorkoutExercises(id);
    for (final e in exercises) {
      final performed = DayWorkoutPerformedSetCodec.decode(e.performedSetsJson);
      final exScore = performed.isNotEmpty
          ? DayWorkoutPerformedSetCodec.totalExerciseScore(performed)
          : scoring.prescribedExerciseLineScore(
              sets: e.sets,
              loadKg: e.loadKg ?? 0,
              reps: e.reps,
            );
      await (_db.update(
        _db.dayWorkoutExercises,
      )..where((x) => x.id.equals(e.id))).write(
        DayWorkoutExercisesCompanion(
          exerciseScore: Value(exScore),
          updatedAt: Value(DateTime.now()),
          revision: Value(_nextRevision(e.revision)),
          lastModifiedByDeviceId: Value(deviceId),
          syncStatus: const Value('pending'),
        ),
      );
    }
    final agg = _completedExerciseScoreAgg(exercises);
    final active = w.activeDurationSeconds > 0 ? w.activeDurationSeconds : 1;
    final ws = scoring.workoutFinalScoreFromExerciseScores(
      exerciseScoresSum: agg.sumScores,
      activeDurationSeconds: active,
      completedExerciseCount: agg.completedCount,
    );
    final now = DateTime.now();
    await (_db.update(_db.dayWorkouts)..where((x) => x.id.equals(id))).write(
      DayWorkoutsCompanion(
        status: const Value('completed'),
        completedAt: Value(now),
        updatedAt: Value(now),
        workoutScore: Value(ws),
        revision: Value(_nextRevision(w.revision)),
        lastModifiedByDeviceId: Value(deviceId),
        syncStatus: const Value('pending'),
      ),
    );
    await _audit(
      'complete',
      'day_workout',
      entityId: id,
      payload: {'workoutScore': ws, 'activeSeconds': w.activeDurationSeconds},
    );
  }

  /// Opcional: calorias (kcal) e FC média (bpm) do relógio após concluir o treino.
  Future<void> setDayWorkoutWatchMetrics(
    String id, {
    double? caloriesKcal,
    int? avgHeartRateBpm,
  }) async {
    await _requireAccessForDayWorkoutId(id);
    final w = await _dayWorkoutRow(id);
    if (w == null || w.status != 'completed') {
      throw ArgumentError('Treino não encontrado ou ainda não concluído.');
    }
    if (caloriesKcal == null && avgHeartRateBpm == null) return;
    final now = DateTime.now();
    final deviceId = await _syncDeviceId();
    await (_db.update(_db.dayWorkouts)..where((x) => x.id.equals(id))).write(
      DayWorkoutsCompanion(
        watchCaloriesKcal: caloriesKcal != null
            ? Value(caloriesKcal)
            : const Value.absent(),
        watchAvgHeartRateBpm: avgHeartRateBpm != null
            ? Value(avgHeartRateBpm)
            : const Value.absent(),
        updatedAt: Value(now),
        revision: Value(_nextRevision(w.revision)),
        lastModifiedByDeviceId: Value(deviceId),
        syncStatus: const Value('pending'),
      ),
    );
    await _audit(
      'update_watch_metrics',
      'day_workout',
      entityId: id,
      payload: {
        'watchCaloriesKcal': ?caloriesKcal,
        'watchAvgHeartRateBpm': ?avgHeartRateBpm,
      },
    );
  }
}

/// Já existe outro grupo muscular com o mesmo nome (comparação sem diferenciar maiúsculas/minúsculas nem espaços nas pontas).
class DuplicateMuscleGroupNameException implements Exception {
  DuplicateMuscleGroupNameException({required this.existingDisplayName});

  final String existingDisplayName;

  @override
  String toString() =>
      'DuplicateMuscleGroupNameException: já existe o grupo "$existingDisplayName".';
}

/// Já existe exercício com o mesmo nome (mesma regra de normalização).
class DuplicateExerciseNameException implements Exception {
  DuplicateExerciseNameException({required this.existingDisplayName});

  final String existingDisplayName;

  @override
  String toString() =>
      'DuplicateExerciseNameException: já existe o exercício "$existingDisplayName".';
}
