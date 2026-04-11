import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/app_session.dart';
import '../../core/utils/calendar_day_utils.dart';
import '../../core/utils/muscle_group_utils.dart';
import '../../core/utils/reps_text_utils.dart';
import '../../domain/scoring.dart' as scoring;
import '../exercise_name_similarity.dart';
import '../local/app_database.dart';
import '../models/day_workout_performed_set.dart';
import '../models/programmable_bundle.dart';
import '../models/week_schedule_row.dart';
import '../sync/remote_sync_service.dart';

const _uuid = Uuid();

/// Rendimento do treino: usa [DayWorkoutEntity.workoutScore] se existir (gravado ao registrar séries);
/// senão recalcula com a mesma fórmula ×10 (volume realizado ÷ min ativo).
double _rendimentoPorMinuto({
  required DayWorkoutEntity w,
  required List<DayWorkoutExerciseEntity> exercises,
}) {
  final stored = w.workoutScore;
  if (stored != null) return stored;
  var sum = 0.0;
  for (final e in exercises) {
    sum += DayWorkoutPerformedSetCodec.totalVolumeScore(
      DayWorkoutPerformedSetCodec.decode(e.performedSetsJson),
    );
  }
  final sec = w.activeDurationSeconds > 0 ? w.activeDurationSeconds : 1;
  return scoring.workoutScoreStoredAtInstant(
    performedVolumeSum: sum,
    activeDurationSeconds: sec,
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

/// Treinos já colocados no calendário (snapshot) ou em execução: não alinhar linhas ao
/// modelo do grupo em [AppDataRepository.syncWorkoutGroupTemplateToScheduledFromDate].
Expression<bool> _dayWorkoutSubjectToGroupTemplateSync($DayWorkoutsTable w) =>
    w.status.equals('completed').not() &
    w.status.equals('cancelled').not() &
    w.status.equals('programmed').not() &
    w.status.equals('started').not() &
    w.status.equals('scheduled').not();

/// Repositório central: CRUD local, auditoria e fila para Supabase (segundo plano).
class AppDataRepository {
  AppDataRepository(
    this._db,
    this._session, {
    RemoteSyncService? remoteSync,
  }) : _remote = remoteSync ?? const NoOpRemoteSyncService() {
    _session.addListener(_clearReactiveStreamCaches);
  }

  final AppDatabase _db;
  final AppSession _session;
  final RemoteSyncService _remote;

  /// O Drift reaproveita o mesmo [Stream] quando a query é idêntica ([StreamKey]).
  /// Usamos [asBroadcastStream] + último snapshot + [Stream.multi] para que cada
  /// novo ouvinte receba o estado atual (broadcast puro não reenvia o último evento).
  Stream<List<StudentEntity>>? _studentsRawBroadcast;
  List<StudentEntity>? _lastStudentsRaw;

  Stream<List<WorkoutGroupEntity>>? _workoutGroupsInnerBroadcast;
  List<WorkoutGroupEntity>? _lastWorkoutGroups;

  Stream<List<({WorkoutGroupEntity group, int exerciseCount})>>?
      _workoutGroupsSchedulableInnerBroadcast;
  List<({WorkoutGroupEntity group, int exerciseCount})>? _lastSchedulable;

  /// [watch] por aluno+semana: broadcast por chave + último snapshot (replay para novos ouvintes).
  final Map<String, Stream<List<WeekScheduleRow>>> _weekScheduleInnerByKey = {};
  final Map<String, List<WeekScheduleRow>> _weekScheduleLastByKey = {};

  final Map<String, Stream<List<DayWorkoutEntity>>> _studentWeekWorkoutsInnerByKey =
      {};
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
    return (_db.select(_db.students)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> requireStudentAccess(String studentId) async {
    final s = await getStudentById(studentId);
    if (s == null || !_session.canAccessStudent(s)) {
      throw ArgumentError('Sem permissão para acessar os dados deste aluno.');
    }
  }

  void _requireProfessionalCadastro() {
    if (_session.isStudent) {
      throw ArgumentError(
        'Perfil aluno não pode criar, editar ou excluir itens de cadastro.',
      );
    }
  }

  void _requireProfessionalPlanning() {
    if (_session.isStudent) {
      throw ArgumentError('Perfil aluno não pode alterar o planejamento.');
    }
  }

  Future<DayWorkoutEntity?> _dayWorkoutRow(String id) {
    return (_db.select(_db.dayWorkouts)..where((w) => w.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> _requireAccessForDayWorkoutId(String dayWorkoutId) async {
    final w = await _dayWorkoutRow(dayWorkoutId);
    if (w == null) {
      throw ArgumentError('Treino não encontrado.');
    }
    await requireStudentAccess(w.studentId);
  }

  Future<void> _requireAccessForDayWorkoutLineId(String lineId) async {
    final row = await (_db.select(_db.dayWorkoutExercises)
          ..where((x) => x.id.equals(lineId)))
        .getSingleOrNull();
    if (row == null) {
      throw ArgumentError('Linha de exercício não encontrada.');
    }
    await _requireAccessForDayWorkoutId(row.dayWorkoutId);
  }

  List<StudentEntity> _visibleStudents(List<StudentEntity> all) {
    switch (_session.role) {
      case SessionRole.adminPersonal:
        return all;
      case SessionRole.personalTrainer:
        final pid = _session.personalId;
        if (pid == null) return [];
        return all.where((s) => s.createdByPersonalId == pid).toList();
      case SessionRole.student:
        final sid = _session.studentId;
        if (sid == null) return [];
        return all.where((s) => s.id == sid).toList();
    }
  }

  Future<List<DayWorkoutEntity>> _visibleDayWorkouts(
    List<DayWorkoutEntity> raw,
  ) async {
    if (_session.role == SessionRole.adminPersonal) return raw;
    final ids = raw.map((e) => e.studentId).toSet().toList();
    if (ids.isEmpty) return raw;
    final students = await (_db.select(_db.students)
          ..where((s) => s.id.isIn(ids)))
        .get();
    final byId = {for (final s in students) s.id: s};
    return raw.where((w) {
      final s = byId[w.studentId];
      return s != null && _session.canAccessStudent(s);
    }).toList();
  }

  Future<void> warmUp() async {
    await _db.customSelect('SELECT 1').get();
  }

  Future<void> _audit(
    String action,
    String entityType, {
    String? entityId,
    Map<String, Object?>? payload,
  }) async {
    final auditId = _uuid.v4();
    await _db.into(_db.auditLogs).insert(
          AuditLogsCompanion.insert(
            id: auditId,
            action: action,
            entityType: entityType,
            entityId: Value(entityId),
            payloadJson: Value(payload == null ? null : jsonEncode(payload)),
          ),
        );
    await _remote.enqueueAudit(
      auditLogId: auditId,
      action: action,
      entityType: entityType,
      entityId: entityId,
      payload: payload,
    );
  }

  Stream<List<MuscleGroupEntity>> watchMuscleGroupsAlphabetical() {
    return (_db.select(_db.muscleGroups)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<void> upsertMuscleGroup({
    String? id,
    required String name,
  }) async {
    _requireProfessionalCadastro();
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
    await _db.into(_db.muscleGroups).insertOnConflictUpdate(
          MuscleGroupsCompanion.insert(
            id: sid,
            name: trimmed,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _audit(id == null ? 'create' : 'update', 'muscle_group',
        entityId: sid, payload: {'name': trimmed});
  }

  Future<void> deleteMuscleGroup(String id) async {
    _requireProfessionalCadastro();
    await (_db.delete(_db.muscleGroups)..where((t) => t.id.equals(id))).go();
    await _audit('delete', 'muscle_group', entityId: id);
  }

  Stream<List<ExerciseEntity>> watchExercisesAlphabetical() {
    return (_db.select(_db.exercises)..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<void> upsertExercise({
    String? id,
    required String name,
    required String muscleGroupId,
    String? videoUrl,
    String? alternativeNote,
    String? alternativeVideoUrl,
  }) async {
    _requireProfessionalCadastro();
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
    await _db.into(_db.exercises).insertOnConflictUpdate(
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
    _requireProfessionalCadastro();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekCutoff = normalizeMonday(today);

    final wgeList = await (_db.select(_db.workoutGroupExercises)
          ..where((t) => t.exerciseId.equals(id)))
        .get();
    for (final row in wgeList) {
      await removeWorkoutGroupExerciseLine(row.id);
    }

    final weekFutureJoin = _db.select(_db.weekScheduleItems).join([
      innerJoin(
        _db.weekScheduleBlocks,
        _db.weekScheduleBlocks.id.equalsExp(_db.weekScheduleItems.blockId),
      ),
    ])
      ..where(
        _db.weekScheduleItems.exerciseId.equals(id) &
            _db.weekScheduleBlocks.weekStartMonday
                .isBiggerOrEqualValue(weekCutoff),
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

    final dweActiveJoin = _db.select(_db.dayWorkoutExercises).join([
      innerJoin(
        _db.dayWorkouts,
        _db.dayWorkouts.id.equalsExp(_db.dayWorkoutExercises.dayWorkoutId),
      ),
    ])
      ..where(
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
      await (_db.delete(_db.dayWorkoutExercises)..where((e) => e.id.equals(line.id)))
          .go();
      await _audit('delete', 'day_workout_exercise', entityId: line.id);
    }

    final wiRemaining = await (_db.select(_db.weekScheduleItems)
          ..where((i) => i.exerciseId.equals(id)))
        .get();
    for (final item in wiRemaining) {
      try {
        await deleteWeekScheduleItem(item.id);
      } catch (_) {}
    }

    final dweRemaining = await (_db.select(_db.dayWorkoutExercises)
          ..where((e) => e.exerciseId.equals(id)))
        .get();
    for (final line in dweRemaining) {
      final w = await _dayWorkoutRow(line.dayWorkoutId);
      if (w == null) {
        await (_db.delete(_db.dayWorkoutExercises)..where((e) => e.id.equals(line.id)))
            .go();
        await _audit('delete', 'day_workout_exercise', entityId: line.id);
        continue;
      }
      try {
        await requireStudentAccess(w.studentId);
      } catch (_) {
        continue;
      }
      await (_db.delete(_db.dayWorkoutExercises)..where((e) => e.id.equals(line.id)))
          .go();
      await _audit('delete', 'day_workout_exercise', entityId: line.id);
    }

    await (_db.delete(_db.exercises)..where((t) => t.id.equals(id))).go();
    await _audit('delete', 'exercise', entityId: id);
  }

  Stream<List<GymEntity>> watchGymsAlphabetical() {
    return (_db.select(_db.gyms)..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
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
    _requireProfessionalCadastro();
    final now = DateTime.now();
    final sid = id ?? _uuid.v4();
    await _db.into(_db.gyms).insertOnConflictUpdate(
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
    _requireProfessionalCadastro();
    await (_db.delete(_db.studentGyms)..where((t) => t.gymId.equals(id))).go();
    await (_db.delete(_db.gyms)..where((t) => t.id.equals(id))).go();
    await _audit('delete', 'gym', entityId: id);
  }

  Stream<List<PersonalEntity>> watchPersonalsAlphabetical() {
    switch (_session.role) {
      case SessionRole.adminPersonal:
        return (_db.select(_db.personals)
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .watch();
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
        return (_db.select(_db.students)..where((s) => s.id.equals(sid)))
            .watch()
            .asyncMap((rows) async {
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
        throw ArgumentError('Só pode editar o seu próprio cadastro de personal.');
      }
      if (id == null) {
        throw ArgumentError('Personal não pode cadastrar novos personais.');
      }
    }
    final now = DateTime.now();
    final sid = id ?? _uuid.v4();
    final PersonalEntity? prevPersonal = id != null
        ? await (_db.select(_db.personals)..where((p) => p.id.equals(sid)))
            .getSingleOrNull()
        : null;
    final effectiveIsAdmin =
        isAdmin ?? prevPersonal?.isAdmin ?? false;
    await _db.into(_db.personals).insertOnConflictUpdate(
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
        throw ArgumentError('Só pode excluir o seu próprio cadastro de personal.');
      }
    }
    await (_db.delete(_db.personals)..where((t) => t.id.equals(id))).go();
    await _audit('delete', 'personal', entityId: id);
  }

  Stream<List<StudentEntity>> _studentsRawStreamWithReplay() {
    _studentsRawBroadcast ??= (_db.select(_db.students)
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

  /// Lista completa de alunos para trocar sessão (apenas admin); demais perfis usam a lista filtrada.
  Stream<List<StudentEntity>> watchStudentsForSessionPicker() {
    if (_session.isAdminPersonal) {
      return _studentsRawStreamWithReplay();
    }
    return watchStudentsAlphabetical();
  }

  Future<List<String>> gymIdsForStudent(String studentId) async {
    await requireStudentAccess(studentId);
    final rows = await (_db.select(_db.studentGyms)
          ..where((t) => t.studentId.equals(studentId)))
        .get();
    return rows.map((e) => e.gymId).toList();
  }

  Future<void> upsertStudent({
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
        ? await (_db.select(_db.students)..where((s) => s.id.equals(sid)))
            .getSingleOrNull()
        : null;
    String? ownerId = prev?.createdByPersonalId;
    if (prev == null) {
      if (_session.isPersonalTrainer) {
        ownerId = _session.personalId;
      } else if (_session.isAdminPersonal) {
        ownerId = null;
      }
    }

    await _db.transaction(() async {
      await _db.into(_db.students).insertOnConflictUpdate(
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
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await (_db.delete(_db.studentGyms)
            ..where((t) => t.studentId.equals(sid)))
          .go();
      for (final gid in gymIds) {
        await _db.into(_db.studentGyms).insert(
              StudentGymsCompanion.insert(studentId: sid, gymId: gid),
            );
      }
    });
    await _audit(id == null ? 'create' : 'update', 'student', entityId: sid);
  }

  Future<void> deleteStudent(String id) async {
    if (_session.isStudent) {
      throw ArgumentError('Sem permissão para excluir aluno.');
    }
    await requireStudentAccess(id);
    await (_db.delete(_db.studentGyms)..where((t) => t.studentId.equals(id)))
        .go();
    await (_db.delete(_db.students)..where((t) => t.id.equals(id))).go();
    await _audit('delete', 'student', entityId: id);
  }

  Stream<List<TrainingMethodEntity>> watchTrainingMethodsAlphabetical() {
    return (_db.select(_db.trainingMethods)
          ..orderBy([(t) => OrderingTerm.asc(t.method)]))
        .watch();
  }

  Future<void> upsertTrainingMethod({
    String? id,
    required String method,
    required String description,
  }) async {
    _requireProfessionalCadastro();
    final now = DateTime.now();
    final sid = id ?? _uuid.v4();
    await _db.into(_db.trainingMethods).insertOnConflictUpdate(
          TrainingMethodsCompanion.insert(
            id: sid,
            method: method,
            description: description,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _audit(id == null ? 'create' : 'update', 'training_method',
        entityId: sid);
  }

  Future<void> deleteTrainingMethod(String id) async {
    _requireProfessionalCadastro();
    await (_db.delete(_db.trainingMethods)..where((t) => t.id.equals(id))).go();
    await _audit('delete', 'training_method', entityId: id);
  }

  Stream<List<WorkoutGroupEntity>> watchWorkoutGroupsAlphabetical() {
    _workoutGroupsInnerBroadcast ??= (_db.select(_db.workoutGroups)
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
    _requireProfessionalCadastro();
    final now = DateTime.now();
    final sid = id ?? _uuid.v4();
    await _db.into(_db.workoutGroups).insertOnConflictUpdate(
          WorkoutGroupsCompanion.insert(
            id: sid,
            name: name,
            description: description,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _audit(id == null ? 'create' : 'update', 'workout_group',
        entityId: sid);
    return sid;
  }

  /// Alinha o **planejamento semanal** ao modelo do grupo ([week_schedule_items]).
  ///
  /// Treinos **já programados no calendário** (`programmed`), **em andamento** (`started`) ou
  /// `scheduled` **não** têm `day_workout_exercises` alterados nem são cancelados por esta
  /// função — o snapshot do dia só muda se o utilizador editar/apagar esse treino no calendário.
  /// Remover o grupo nas semanas futuras no planeamento não apaga exercícios de dias já programados.
  ///
  /// [effectiveFrom]: dia e semanas (segunda ≥) a considerar. Se o modelo do grupo ficar vazio,
  /// remove itens da semana ligados ao grupo; treinos do calendário em snapshot não são tocados.
  Future<({int weekItemsUpdated, int dayExercisesUpdated})>
      syncWorkoutGroupTemplateToScheduledFromDate(
    String workoutGroupId,
    DateTime effectiveFrom,
  ) async {
    _requireProfessionalCadastro();
    final effectiveDay =
        DateTime(effectiveFrom.year, effectiveFrom.month, effectiveFrom.day);
    final weekCutoff = normalizeMonday(effectiveDay);

    var weekItemsUpdated = 0;
    var dayExercisesUpdated = 0;

    final lines = await (_db.select(_db.workoutGroupExercises)
          ..where((t) => t.workoutGroupId.equals(workoutGroupId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    final byExercise = {for (final l in lines) l.exerciseId: l};

    JoinedSelectStatement<HasResultSet, dynamic> weekJoin() {
      return _db.select(_db.weekScheduleItems).join([
        innerJoin(
          _db.weekScheduleBlocks,
          _db.weekScheduleBlocks.id.equalsExp(_db.weekScheduleItems.blockId),
        ),
      ])
        ..where(
          _db.weekScheduleItems.sourceWorkoutGroupId.equals(workoutGroupId) &
              _db.weekScheduleBlocks.weekStartMonday
                  .isBiggerOrEqualValue(weekCutoff),
        );
    }

    if (byExercise.isEmpty) {
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

      final dayWsEmpty = await (_db.select(_db.dayWorkouts)
            ..where(
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
        final dwes = await (_db.select(_db.dayWorkoutExercises)
              ..where((e) => e.dayWorkoutId.equals(w.id)))
            .get();
        for (final d in dwes) {
          await (_db.delete(_db.dayWorkoutExercises)
                ..where((e) => e.id.equals(d.id)))
              .go();
          await _audit('delete', 'day_workout_exercise', entityId: d.id);
          dayExercisesUpdated++;
        }
        await (_db.update(_db.dayWorkouts)..where((x) => x.id.equals(w.id)))
            .write(
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
      if (byExercise.containsKey(item.exerciseId)) continue;
      try {
        await requireStudentAccess(block.studentId);
      } catch (_) {
        continue;
      }
      await deleteWeekScheduleItem(item.id);
      weekItemsUpdated++;
    }

    final weekRowsAfterDelete = await weekJoin().get();
    for (final row in weekRowsAfterDelete) {
      final item = row.readTable(_db.weekScheduleItems);
      final block = row.readTable(_db.weekScheduleBlocks);
      final template = byExercise[item.exerciseId];
      if (template == null) continue;
      try {
        await requireStudentAccess(block.studentId);
      } catch (_) {
        continue;
      }
      final sets = template.lastSets ?? 0;
      final reps = _repsIntFromWorkoutGroupLine(template);
      final needsDetail = sets <= 0 || reps <= 0;
      final rtw = _repsTextFromWorkoutGroupLine(template);
      await (_db.update(_db.weekScheduleItems)..where((i) => i.id.equals(item.id)))
          .write(
        WeekScheduleItemsCompanion(
          sortOrder: Value(template.sortOrder),
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

    final blockIds = <String>{};
    for (final row in await weekJoin().get()) {
      blockIds.add(row.readTable(_db.weekScheduleItems).blockId);
    }
    for (final blockId in blockIds) {
      final block = await (_db.select(_db.weekScheduleBlocks)
            ..where((b) => b.id.equals(blockId)))
          .getSingleOrNull();
      if (block == null) continue;
      try {
        await requireStudentAccess(block.studentId);
      } catch (_) {
        continue;
      }
      final groupItems = await (_db.select(_db.weekScheduleItems)
            ..where(
              (i) =>
                  i.blockId.equals(blockId) &
                  i.sourceWorkoutGroupId.equals(workoutGroupId),
            ))
          .get();
      final have = {for (final i in groupItems) i.exerciseId};
      for (final line in lines) {
        if (have.contains(line.exerciseId)) continue;
        final sets = line.lastSets ?? 0;
        final reps = _repsIntFromWorkoutGroupLine(line);
        final needsDetail = sets <= 0 || reps <= 0;
        final rtw = _repsTextFromWorkoutGroupLine(line);
        final newId = _uuid.v4();
        await _db.into(_db.weekScheduleItems).insert(
              WeekScheduleItemsCompanion.insert(
                id: newId,
                blockId: blockId,
                exerciseId: line.exerciseId,
                sourceWorkoutGroupId: Value(workoutGroupId),
                sortOrder: Value(line.sortOrder),
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
    }

    final dayWorkouts = await (_db.select(_db.dayWorkouts)
          ..where(
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

      var dweList = await (_db.select(_db.dayWorkoutExercises)
            ..where((e) => e.dayWorkoutId.equals(w.id)))
          .get();
      for (final dwe in dweList) {
        if (byExercise.containsKey(dwe.exerciseId)) continue;
        await (_db.delete(_db.dayWorkoutExercises)
              ..where((e) => e.id.equals(dwe.id)))
            .go();
        await _audit('delete', 'day_workout_exercise', entityId: dwe.id);
        dayExercisesUpdated++;
        workoutTouched = true;
      }

      dweList = await (_db.select(_db.dayWorkoutExercises)
            ..where((e) => e.dayWorkoutId.equals(w.id)))
          .get();
      for (final dwe in dweList) {
        final template = byExercise[dwe.exerciseId];
        if (template == null) continue;
        final sets = template.lastSets ?? 0;
        final reps = _repsIntFromWorkoutGroupLine(template);
        if (sets <= 0 || reps <= 0) continue;
        await (_db.update(_db.dayWorkoutExercises)
              ..where((e) => e.id.equals(dwe.id)))
            .write(
          DayWorkoutExercisesCompanion(
            sortOrder: Value(template.sortOrder),
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

      final present = {
        for (final d
            in await (_db.select(_db.dayWorkoutExercises)
                  ..where((e) => e.dayWorkoutId.equals(w.id)))
                .get())
          d.exerciseId,
      };
      for (final line in lines) {
        if (present.contains(line.exerciseId)) continue;
        final sets = line.lastSets ?? 0;
        final reps = _repsIntFromWorkoutGroupLine(line);
        if (sets <= 0 || reps <= 0) continue;
        final newId = _uuid.v4();
        await _db.into(_db.dayWorkoutExercises).insert(
              DayWorkoutExercisesCompanion.insert(
                id: newId,
                dayWorkoutId: w.id,
                exerciseId: line.exerciseId,
                sortOrder: Value(line.sortOrder),
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
    _requireProfessionalCadastro();
    await (_db.delete(_db.workoutGroupExercises)
          ..where((t) => t.workoutGroupId.equals(id)))
        .go();
    await (_db.delete(_db.workoutGroups)..where((t) => t.id.equals(id))).go();
    await _audit('delete', 'workout_group', entityId: id);
  }

  Stream<List<WorkoutGroupExerciseEntity>> watchGroupExercises(String groupId) {
    return (_db.select(_db.workoutGroupExercises)
          ..where((t) => t.workoutGroupId.equals(groupId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  /// Retorna `false` se [exerciseId] já existir neste grupo (não insere duplicata).
  Future<bool> addExerciseToWorkoutGroup({
    required String workoutGroupId,
    required String exerciseId,
    int? lastReps,
    int? lastSets,
    double? lastLoadKg,
    String? lastRepsText,
  }) async {
    _requireProfessionalCadastro();
    final dup = await (_db.select(_db.workoutGroupExercises)
          ..where(
            (t) =>
                t.workoutGroupId.equals(workoutGroupId) &
                t.exerciseId.equals(exerciseId),
          ))
        .get();
    if (dup.isNotEmpty) return false;

    final rows = await (_db.select(_db.workoutGroupExercises)
          ..where((t) => t.workoutGroupId.equals(workoutGroupId)))
        .get();
    var maxOrder = -1;
    for (final r in rows) {
      if (r.sortOrder > maxOrder) maxOrder = r.sortOrder;
    }
    final nextOrder = maxOrder + 1;
    await _db.into(_db.workoutGroupExercises).insert(
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
    _requireProfessionalCadastro();
    await (_db.update(_db.workoutGroupExercises)..where((t) => t.id.equals(lineId)))
        .write(
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
    final row = await (_db.select(_db.workoutGroupExercises)
          ..where((t) => t.id.equals(lineId)))
        .getSingleOrNull();
    final cid = row?.comboId?.trim();
    if (row != null && cid != null && cid.isNotEmpty) {
      await _normalizeWorkoutGroupComboRest(row.workoutGroupId, cid);
    }
  }

  Future<void> _normalizeWorkoutGroupComboRest(
    String workoutGroupId,
    String comboId,
  ) async {
    final lines = await (_db.select(_db.workoutGroupExercises)
          ..where(
            (t) =>
                t.workoutGroupId.equals(workoutGroupId) & t.comboId.equals(comboId),
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
      await (_db.update(_db.workoutGroupExercises)
            ..where((t) => t.id.equals(lines[i].id)))
          .write(
        WorkoutGroupExercisesCompanion(
          restBetweenSetsSec: Value(r),
          updatedAt: Value(now),
        ),
      );
    }
  }

  Future<void> _normalizeWeekScheduleComboRest(String blockId, String comboId) async {
    final lines = await (_db.select(_db.weekScheduleItems)
          ..where((i) => i.blockId.equals(blockId) & i.comboId.equals(comboId))
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
      await (_db.update(_db.weekScheduleItems)..where((x) => x.id.equals(lines[i].id)))
          .write(
        WeekScheduleItemsCompanion(
          restBetweenSetsSec: Value(r),
          updatedAt: Value(now),
        ),
      );
    }
  }

  Future<void> removeWorkoutGroupExerciseLine(String lineId) async {
    _requireProfessionalCadastro();
    final row = await (_db.select(_db.workoutGroupExercises)
          ..where((t) => t.id.equals(lineId)))
        .getSingleOrNull();
    if (row == null) return;
    final gid = row.workoutGroupId;
    final cid = row.comboId?.trim();
    await (_db.delete(_db.workoutGroupExercises)
          ..where((t) => t.id.equals(lineId)))
        .go();
    await _audit('delete', 'workout_group_exercise', entityId: lineId);
    if (cid != null && cid.isNotEmpty) {
      final sibs = await (_db.select(_db.workoutGroupExercises)
            ..where(
              (t) => t.workoutGroupId.equals(gid) & t.comboId.equals(cid),
            ))
          .get();
      if (sibs.length == 1) {
        await (_db.update(_db.workoutGroupExercises)
              ..where((t) => t.id.equals(sibs.single.id)))
            .write(
          WorkoutGroupExercisesCompanion(
            comboId: const Value(null),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    }
  }

  Future<void> removeWorkoutGroupComboBlock({
    required String workoutGroupId,
    required String comboId,
  }) async {
    _requireProfessionalCadastro();
    final cid = comboId.trim();
    if (cid.isEmpty) return;
    final lines = await (_db.select(_db.workoutGroupExercises)
          ..where(
            (t) =>
                t.workoutGroupId.equals(workoutGroupId) & t.comboId.equals(cid),
          ))
        .get();
    for (final l in lines) {
      await (_db.delete(_db.workoutGroupExercises)
            ..where((t) => t.id.equals(l.id)))
          .go();
      await _audit('delete', 'workout_group_exercise', entityId: l.id);
    }
  }

  /// Combina [secondExerciseId] logo após a linha âncora (mesmo [comboId]).
  /// Retorna `false` se o exercício já existir no grupo ou for o mesmo da âncora.
  Future<bool> combineWorkoutGroupExerciseLine({
    required String anchorLineId,
    required String secondExerciseId,
    required int lastSets,
    required String lastRepsText,
    double? lastLoadKg,
    required int restBetweenSetsSec,
    String? trainingMethodId,
  }) async {
    _requireProfessionalCadastro();
    final anchor = await (_db.select(_db.workoutGroupExercises)
          ..where((t) => t.id.equals(anchorLineId)))
        .getSingleOrNull();
    if (anchor == null) return false;
    final gid = anchor.workoutGroupId;
    if (anchor.exerciseId == secondExerciseId) return false;
    final dup = await (_db.select(_db.workoutGroupExercises)
          ..where(
            (t) =>
                t.workoutGroupId.equals(gid) & t.exerciseId.equals(secondExerciseId),
          ))
        .get();
    if (dup.isNotEmpty) return false;

    final comboId = (anchor.comboId != null && anchor.comboId!.trim().isNotEmpty)
        ? anchor.comboId!.trim()
        : _uuid.v4();
    final now = DateTime.now();

    await _db.transaction(() async {
      if (anchor.comboId == null || anchor.comboId!.trim().isEmpty) {
        await (_db.update(_db.workoutGroupExercises)
              ..where((t) => t.id.equals(anchor.id)))
            .write(
          WorkoutGroupExercisesCompanion(
            comboId: Value(comboId),
            updatedAt: Value(now),
          ),
        );
      }

      final after = await (_db.select(_db.workoutGroupExercises)
            ..where(
              (t) =>
                  t.workoutGroupId.equals(gid) &
                  t.sortOrder.isBiggerThanValue(anchor.sortOrder),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)]))
          .get();

      for (final row in after) {
        await (_db.update(_db.workoutGroupExercises)
              ..where((t) => t.id.equals(row.id)))
            .write(
          WorkoutGroupExercisesCompanion(
            sortOrder: Value(row.sortOrder + 1),
            updatedAt: Value(now),
          ),
        );
      }

      await _db.into(_db.workoutGroupExercises).insert(
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
    _requireProfessionalCadastro();
    if (orderedLineIds.isEmpty) return;
    final current = await (_db.select(_db.workoutGroupExercises)
          ..where((t) => t.workoutGroupId.equals(workoutGroupId)))
        .get();
    final currentIds = {for (final r in current) r.id};
    if (currentIds.length != orderedLineIds.length ||
        orderedLineIds.any((id) => !currentIds.contains(id))) {
      throw ArgumentError('Ordem inválida para reordenar exercícios do grupo.');
    }

    await _db.transaction(() async {
      for (var i = 0; i < orderedLineIds.length; i++) {
        final lineId = orderedLineIds[i];
        await (_db.update(_db.workoutGroupExercises)
              ..where((t) => t.id.equals(lineId)))
            .write(
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
    if (!_session.isAdminPersonal) {
      return Stream.value(const <AuditLogEntity>[]);
    }
    return (_db.select(_db.auditLogs)..orderBy([(t) => OrderingTerm.desc(t.at)]))
        .watch();
  }

  Future<List<AuditLogEntity>> allAuditLogs() async {
    if (!_session.isAdminPersonal) {
      return const <AuditLogEntity>[];
    }
    return (_db.select(_db.auditLogs)..orderBy([(t) => OrderingTerm.desc(t.at)]))
        .get();
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
  }

  Future<List<({DateTime at, Map<String, String> answers})>>
      studentAnamneseHistory({
    required String studentId,
    int limit = 20,
  }) async {
    await requireStudentAccess(studentId);
    final rows = await (_db.select(_db.auditLogs)
          ..where((a) =>
              a.entityType.equals('anamnese') &
              a.entityId.equals(studentId) &
              a.action.equals('anamnese_submit'))
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
    return (_db.select(_db.dayWorkouts)
          ..where((t) =>
              t.dayDate.isBiggerOrEqualValue(startPad) &
              t.dayDate.isSmallerThanValue(endPad) &
              _dayWorkoutNotCancelled(t)))
        .watch()
        .map(
          (list) => list
              .where((w) {
                final d = weekScheduleLocalCalendarDate(w.dayDate);
                return !d.isBefore(start) && d.isBefore(end);
              })
              .toList(),
        )
        .asyncMap(_visibleDayWorkouts);
  }

  /// Treinos visíveis no intervalo **[fromInclusive, toExclusive)** por **dia civil local**
  /// (mesma regra da grade do calendário e da semana no planejamento).
  Stream<List<DayWorkoutEntity>> watchWorkoutsBetween(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) {
    final startPad = fromInclusive.subtract(const Duration(days: 2));
    final endPad = toExclusive.add(const Duration(days: 2));
    return (_db.select(_db.dayWorkouts)
          ..where((t) =>
              t.dayDate.isBiggerOrEqualValue(startPad) &
              t.dayDate.isSmallerThanValue(endPad) &
              _dayWorkoutNotCancelled(t)))
        .watch()
        .map(
          (list) => list
              .where((w) {
                final d = weekScheduleLocalCalendarDate(w.dayDate);
                return !d.isBefore(fromInclusive) && d.isBefore(toExclusive);
              })
              .toList(),
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
      DateTime(
        weekMondayView.year,
        weekMondayView.month,
        weekMondayView.day,
      ),
    );
    return a == b;
  }

  Future<String> _getOrCreateWeekBlock(String studentId, DateTime weekMonday) async {
    final mon = DateTime(weekMonday.year, weekMonday.month, weekMonday.day);
    final existingAll = await (_db.select(_db.weekScheduleBlocks)
          ..where((b) => b.studentId.equals(studentId)))
        .get();
    for (final b in existingAll) {
      if (_weekBlockMondayEquals(b.weekStartMonday, mon)) {
        return b.id;
      }
    }
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.into(_db.weekScheduleBlocks).insert(
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
      final q = _db.select(_db.weekScheduleItems).join([
        innerJoin(
          _db.weekScheduleBlocks,
          _db.weekScheduleBlocks.id.equalsExp(_db.weekScheduleItems.blockId),
        ),
        leftOuterJoin(
          _db.exercises,
          _db.exercises.id.equalsExp(_db.weekScheduleItems.exerciseId),
        ),
      ])
        ..where(_db.weekScheduleBlocks.studentId.equals(studentId))
        ..orderBy([OrderingTerm.asc(_db.weekScheduleItems.sortOrder)]);

      return Stream.fromFuture(requireStudentAccess(studentId).then((_) => true))
          .asyncExpand(
            (_) => q.watch().map(
                  (rows) {
                    final list = rows
                        .where(
                          (row) => _weekBlockMondayEquals(
                            row
                                .readTable(_db.weekScheduleBlocks)
                                .weekStartMonday,
                            mon,
                          ),
                        )
                        .map(
                          (row) {
                            final ex = row.readTableOrNull(_db.exercises);
                            return WeekScheduleRow(
                              item: row.readTable(_db.weekScheduleItems),
                              exerciseName:
                                  ex?.name ?? 'Exercício ausente no catálogo',
                            );
                          },
                        )
                        .toList();
                    _weekScheduleLastByKey[key] = list;
                    return list;
                  },
                ),
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

      return Stream.fromFuture(requireStudentAccess(studentId).then((_) => true))
          .asyncExpand(
            (_) => sel.watch().map((list) {
                  final filtered = list
                      .where((w) {
                        final d = weekScheduleLocalCalendarDate(w.dayDate);
                        return !d.isBefore(start) && d.isBefore(end);
                      })
                      .toList();
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

  /// Insere só exercícios que ainda não existem no bloco da semana (sem duplicar [exerciseId]).
  Future<({int added, int skipped})> addExercisesToWeekSchedule({
    required String studentId,
    required DateTime weekMonday,
    required List<String> exerciseIds,
  }) async {
    _requireProfessionalPlanning();
    await requireStudentAccess(studentId);
    if (exerciseIds.isEmpty) return (added: 0, skipped: 0);
    final blockId = await _getOrCreateWeekBlock(studentId, weekMonday);
    final existing = await (_db.select(_db.weekScheduleItems)
          ..where((i) => i.blockId.equals(blockId)))
        .get();
    final already = {for (final i in existing) i.exerciseId};
    var maxO = -1;
    for (final i in existing) {
      if (i.sortOrder > maxO) maxO = i.sortOrder;
    }
    var added = 0;
    var skipped = 0;
    await _db.transaction(() async {
      for (final exId in exerciseIds) {
        if (already.contains(exId)) {
          skipped++;
          continue;
        }
        already.add(exId);
        maxO++;
        added++;
        await _db.into(_db.weekScheduleItems).insert(
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
      await _audit('schedule_exercises_week', 'week_schedule', entityId: blockId);
    }
    return (added: added, skipped: skipped);
  }

  /// Todos os grupos de treino (mesma base do cadastro), com contagem de exercícios no modelo.
  /// Na UI de agendar treino, grupos com 0 exercícios não podem ser escolhidos.
  Stream<List<({WorkoutGroupEntity group, int exerciseCount})>>
      watchWorkoutGroupsSchedulable() {
    _workoutGroupsSchedulableInnerBroadcast ??= (_db.select(_db.workoutGroups)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch()
        .asyncMap((groups) async {
          final out = <({WorkoutGroupEntity group, int exerciseCount})>[];
          for (final g in groups) {
            final lines = await (_db.select(_db.workoutGroupExercises)
                  ..where((t) => t.workoutGroupId.equals(g.id)))
                .get();
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
    _requireProfessionalPlanning();
    await requireStudentAccess(studentId);
    if (weekCount < 1 || weekCount > 52) {
      throw ArgumentError('weekCount deve estar entre 1 e 52.');
    }
    final lines = await (_db.select(_db.workoutGroupExercises)
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
      final existing = await (_db.select(_db.weekScheduleItems)
            ..where((i) => i.blockId.equals(blockId)))
          .get();
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
          await _db.into(_db.weekScheduleItems).insert(
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
        await _audit('schedule_exercises_week', 'week_schedule', entityId: blockId);
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
    _requireProfessionalPlanning();
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
    final sourceCandidates = await (_db.select(_db.weekScheduleBlocks)
          ..where((b) => b.studentId.equals(sourceStudentId)))
        .get();
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

    final sourceItems = await (_db.select(_db.weekScheduleItems)
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
      final existing = await (_db.select(_db.weekScheduleItems)
            ..where((i) => i.blockId.equals(targetBlockId)))
          .get();

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
          final copiedNeedsDetail =
              !weekScheduleItemHasValidPrescription(source);
          await _db.into(_db.weekScheduleItems).insert(
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
    _requireProfessionalPlanning();
    final item = await (_db.select(_db.weekScheduleItems)
          ..where((i) => i.id.equals(itemId)))
        .getSingleOrNull();
    if (item == null) return;
    final block = await (_db.select(_db.weekScheduleBlocks)
          ..where((b) => b.id.equals(item.blockId)))
        .getSingleOrNull();
    if (block == null) return;
    await requireStudentAccess(block.studentId);

    final trimmed = repsText.trim();
    final needsDetail = sets <= 0 || repsHintInt <= 0;
    await (_db.update(_db.weekScheduleItems)..where((i) => i.id.equals(itemId))).write(
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
    final row = await (_db.select(_db.weekScheduleItems)
          ..where((i) => i.id.equals(itemId)))
        .getSingleOrNull();
    final cid = row?.comboId?.trim();
    if (row != null && cid != null && cid.isNotEmpty) {
      await _normalizeWeekScheduleComboRest(row.blockId, cid);
    }
  }

  Future<void> deleteWeekScheduleItem(String itemId) async {
    _requireProfessionalPlanning();
    final item = await (_db.select(_db.weekScheduleItems)
          ..where((i) => i.id.equals(itemId)))
        .getSingleOrNull();
    if (item == null) return;
    final block = await (_db.select(_db.weekScheduleBlocks)
          ..where((b) => b.id.equals(item.blockId)))
        .getSingleOrNull();
    if (block == null) return;
    await requireStudentAccess(block.studentId);

    final now = DateTime.now();
    final blockId = item.blockId;
    final cid = item.comboId?.trim();
    await (_db.update(_db.dayWorkouts)..where((d) => d.weekItemId.equals(itemId))).write(
          DayWorkoutsCompanion(
            status: const Value('cancelled'),
            weekItemId: const Value(null),
            timerResumeAt: const Value(null),
            updatedAt: Value(now),
          ),
        );
    await (_db.delete(_db.weekScheduleItems)..where((i) => i.id.equals(itemId))).go();
    await _audit('delete', 'week_schedule_item', entityId: itemId);
    if (cid != null && cid.isNotEmpty) {
      final sibs = await (_db.select(_db.weekScheduleItems)
            ..where((i) => i.blockId.equals(blockId) & i.comboId.equals(cid)))
          .get();
      if (sibs.length == 1) {
        await (_db.update(_db.weekScheduleItems)
              ..where((i) => i.id.equals(sibs.single.id)))
            .write(
          WeekScheduleItemsCompanion(
            comboId: const Value(null),
            updatedAt: Value(now),
          ),
        );
      }
    }
  }

  Future<void> removeWeekScheduleComboBlock({
    required String blockId,
    required String comboId,
  }) async {
    _requireProfessionalPlanning();
    final cid = comboId.trim();
    if (cid.isEmpty) return;
    final block = await (_db.select(_db.weekScheduleBlocks)
          ..where((b) => b.id.equals(blockId)))
        .getSingleOrNull();
    if (block == null) return;
    await requireStudentAccess(block.studentId);
    final lines = await (_db.select(_db.weekScheduleItems)
          ..where((i) => i.blockId.equals(blockId) & i.comboId.equals(cid)))
        .get();
    final now = DateTime.now();
    for (final item in lines) {
      await (_db.update(_db.dayWorkouts)
            ..where((d) => d.weekItemId.equals(item.id)))
          .write(
        DayWorkoutsCompanion(
          status: const Value('cancelled'),
          weekItemId: const Value(null),
          timerResumeAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await (_db.delete(_db.weekScheduleItems)..where((i) => i.id.equals(item.id))).go();
      await _audit('delete', 'week_schedule_item', entityId: item.id);
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
    _requireProfessionalPlanning();
    final anchor = await (_db.select(_db.weekScheduleItems)
          ..where((i) => i.id.equals(anchorItemId)))
        .getSingleOrNull();
    if (anchor == null) return false;
    final block = await (_db.select(_db.weekScheduleBlocks)
          ..where((b) => b.id.equals(anchor.blockId)))
        .getSingleOrNull();
    if (block == null) return false;
    await requireStudentAccess(block.studentId);

    final blockId = anchor.blockId;
    if (anchor.exerciseId == secondExerciseId) return false;

    final inBlock = await (_db.select(_db.weekScheduleItems)
          ..where((i) => i.blockId.equals(blockId)))
        .get();
    final exIds = {for (final i in inBlock) i.exerciseId};
    if (exIds.contains(secondExerciseId)) return false;

    final comboId = (anchor.comboId != null && anchor.comboId!.trim().isNotEmpty)
        ? anchor.comboId!.trim()
        : _uuid.v4();
    final now = DateTime.now();
    final trimmed = repsText.trim();
    final needsDetail = sets <= 0 || repsHintInt <= 0;

    await _db.transaction(() async {
      if (anchor.comboId == null || anchor.comboId!.trim().isEmpty) {
        await (_db.update(_db.weekScheduleItems)
              ..where((i) => i.id.equals(anchor.id)))
            .write(
          WeekScheduleItemsCompanion(
            comboId: Value(comboId),
            updatedAt: Value(now),
          ),
        );
      }

      final after = await (_db.select(_db.weekScheduleItems)
            ..where(
              (i) =>
                  i.blockId.equals(blockId) &
                  i.sortOrder.isBiggerThanValue(anchor.sortOrder),
            )
            ..orderBy([(i) => OrderingTerm.desc(i.sortOrder)]))
          .get();

      for (final row in after) {
        await (_db.update(_db.weekScheduleItems)
              ..where((i) => i.id.equals(row.id)))
            .write(
          WeekScheduleItemsCompanion(
            sortOrder: Value(row.sortOrder + 1),
            updatedAt: Value(now),
          ),
        );
      }

      await _db.into(_db.weekScheduleItems).insert(
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
    return true;
  }

  Future<void> reorderWeekScheduleItemsInGroup({
    required String blockId,
    required String? sourceWorkoutGroupId,
    required List<String> orderedItemIds,
  }) async {
    _requireProfessionalPlanning();
    if (orderedItemIds.isEmpty) return;
    final block = await (_db.select(_db.weekScheduleBlocks)
          ..where((b) => b.id.equals(blockId)))
        .getSingleOrNull();
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
        await (_db.update(_db.weekScheduleItems)
              ..where((x) => x.id.equals(itemId)))
            .write(
          WeekScheduleItemsCompanion(
            sortOrder: Value(baseOrder + i),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
    await _audit(
      'reorder',
      'week_schedule_item',
      entityId: blockId,
      payload: {
        'sourceWorkoutGroupId': sourceWorkoutGroupId,
        'count': orderedItemIds.length,
      },
    );
  }

  // ——— Calendário: programar / iniciar / timer / concluir ———

  Future<List<WeekScheduleRow>> loadWeekScheduleRows({
    required String studentId,
    required DateTime weekMonday,
  }) async {
    await requireStudentAccess(studentId);
    final mon = DateTime(weekMonday.year, weekMonday.month, weekMonday.day);
    final q = _db.select(_db.weekScheduleItems).join([
      innerJoin(
        _db.weekScheduleBlocks,
        _db.weekScheduleBlocks.id.equalsExp(_db.weekScheduleItems.blockId),
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
        .map(
          (row) {
            final ex = row.readTableOrNull(_db.exercises);
            return WeekScheduleRow(
              item: row.readTable(_db.weekScheduleItems),
              exerciseName: ex?.name ?? 'Exercício ausente no catálogo',
            );
          },
        )
        .toList();
  }

  /// Alunos com pelo menos um item de semana com séries e reps preenchidos na semana do dia.
  /// Não exige `!needsDetail`: o flag pode ficar inconsistente após sync/cópia.
  Future<List<StudentEntity>> getStudentsWithProgrammableWeek(DateTime day) async {
    final monday = normalizeMonday(day);
    final allStudents = await (_db.select(_db.students)).get();
    final visible = _visibleStudents(allStudents);
    if (visible.isEmpty) return [];
    final visibleIds = visible.map((s) => s.id).toList();
    // Só alunos visíveis na sessão; sem janela SQL em week_start_monday (evita falsos negativos por data/UTC).
    final blockCandidates = await (_db.select(_db.weekScheduleBlocks)
          ..where((b) => b.studentId.isIn(visibleIds)))
        .get();
    final blocks = blockCandidates
        .where((b) => _weekBlockMondayEquals(b.weekStartMonday, monday))
        .toList();
    final okStudents = <String>{};
    for (final b in blocks) {
      final items = await (_db.select(_db.weekScheduleItems)
            ..where((i) => i.blockId.equals(b.id)))
          .get();
      final ok = items.any(weekScheduleItemHasValidPrescription);
      if (ok) okStudents.add(b.studentId);
    }
    if (okStudents.isEmpty) return [];
    final list = await (_db.select(_db.students)
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
    final rows = await loadWeekScheduleRows(studentId: studentId, weekMonday: monday);
    final valid = rows
        .where((r) => weekScheduleItemHasValidPrescription(r.item))
        .toList();
    final byGroup = <String?, List<WeekScheduleRow>>{};
    for (final r in valid) {
      byGroup.putIfAbsent(r.item.sourceWorkoutGroupId, () => []).add(r);
    }
    final bundles = <ProgrammableBundle>[];
    for (final e in byGroup.entries) {
      final list = e.value..sort((a, b) => a.item.sortOrder.compareTo(b.item.sortOrder));
      final key = e.key;
      String title;
      if (key == null) {
        title = 'Exercícios avulsos (${list.length})';
      } else {
        final g = await (_db.select(_db.workoutGroups)
              ..where((t) => t.id.equals(key)))
            .getSingleOrNull();
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
    final g = await (_db.select(_db.workoutGroups)
          ..where((t) => t.id.equals(gid)))
        .getSingleOrNull();
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
      await _db.into(_db.dayWorkouts).insert(
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
        await _db.into(_db.dayWorkoutExercises).insert(
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

  Future<DayWorkoutEntity?> getDayWorkout(String id) async {
    final w = await _dayWorkoutRow(id);
    if (w == null) return null;
    final s = await getStudentById(w.studentId);
    if (s == null || !_session.canAccessStudent(s)) return null;
    return w;
  }

  Stream<DayWorkoutEntity?> watchDayWorkout(String id) {
    return (_db.select(_db.dayWorkouts)..where((w) => w.id.equals(id)))
        .watch()
        .map((list) => list.singleOrNull)
        .asyncMap((w) async {
      if (w == null) return null;
      final s = await getStudentById(w.studentId);
      if (s == null || !_session.canAccessStudent(s)) return null;
      return w;
    });
  }

  /// Treinos `started` do aluno (gadget “ao vivo” / overlay).
  Stream<List<DayWorkoutEntity>> watchStudentStartedDayWorkouts(
    String studentId,
  ) async* {
    await requireStudentAccess(studentId);
    yield* (_db.select(_db.dayWorkouts)
          ..where(
            (w) =>
                w.studentId.equals(studentId) & w.status.equals('started'),
          ))
        .watch();
  }

  Stream<List<DayWorkoutExerciseEntity>> watchDayWorkoutExercises(
    String dayWorkoutId,
  ) async* {
    await _requireAccessForDayWorkoutId(dayWorkoutId);
    yield* (_db.select(_db.dayWorkoutExercises)
          ..where((e) => e.dayWorkoutId.equals(dayWorkoutId))
          ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
        .watch();
  }

  Future<List<DayWorkoutExerciseEntity>> getDayWorkoutExercises(String dayWorkoutId) async {
    await _requireAccessForDayWorkoutId(dayWorkoutId);
    return (_db.select(_db.dayWorkoutExercises)
          ..where((e) => e.dayWorkoutId.equals(dayWorkoutId))
          ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
        .get();
  }

  /// Para descanso entre séries: no último exercício do bloco [comboId] oferece intervalo; entre movimentos do combo, não.
  Future<bool> isLastLineInExerciseCombo(String lineId) async {
    final line = await (_db.select(_db.dayWorkoutExercises)
          ..where((e) => e.id.equals(lineId)))
        .getSingleOrNull();
    if (line == null) return true;
    final cid = line.comboId?.trim();
    if (cid == null || cid.isEmpty) return true;
    await _requireAccessForDayWorkoutId(line.dayWorkoutId);
    final same = await (_db.select(_db.dayWorkoutExercises)
          ..where(
            (e) => e.dayWorkoutId.equals(line.dayWorkoutId) & e.comboId.equals(cid),
          )
          ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
        .get();
    if (same.isEmpty) return true;
    return same.last.id == line.id;
  }

  Future<List<({DayWorkoutEntity workout, List<DayWorkoutExerciseEntity> exercises})>>
      completedWorkoutSnapshots({
    required String studentId,
    DateTime? fromInclusive,
    DateTime? toExclusive,
  }) async {
    await requireStudentAccess(studentId);
    final q = _db.select(_db.dayWorkouts)
      ..where((w) => w.studentId.equals(studentId) & w.status.equals('completed'));
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
        <({DayWorkoutEntity workout, List<DayWorkoutExerciseEntity> exercises})>[];
    for (final workout in workouts) {
      final exercises = await (_db.select(_db.dayWorkoutExercises)
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
    final join = _db.select(_db.dayWorkoutExercises).join([
      innerJoin(
        _db.dayWorkouts,
        _db.dayWorkouts.id.equalsExp(_db.dayWorkoutExercises.dayWorkoutId),
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
    return DayWorkoutPerformedSetCodec.totalVolumeScore(
      DayWorkoutPerformedSetCodec.decode(line.performedSetsJson),
    );
  }

  /// Última série registrada para o mesmo aluno + exercício da [lineId].
  /// Não considera a própria linha atual.
  Future<DayWorkoutPerformedSet?> lastPerformedSetSeedForLine(
    String lineId,
  ) async {
    await _requireAccessForDayWorkoutLineId(lineId);
    final line = await (_db.select(_db.dayWorkoutExercises)
          ..where((e) => e.id.equals(lineId)))
        .getSingleOrNull();
    if (line == null) return null;

    final workout = await _dayWorkoutRow(line.dayWorkoutId);
    if (workout == null) return null;

    final q = _db.select(_db.dayWorkoutExercises).join([
      innerJoin(
        _db.dayWorkouts,
        _db.dayWorkouts.id.equalsExp(_db.dayWorkoutExercises.dayWorkoutId),
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

  /// Últimos [limit] treinos **concluídos**, ordenados do mais **antigo** ao mais **novo** (eixo X).
  /// [scorePerMinute] = Σ score dos exercícios ÷ tempo ativo em minutos.
  Future<List<({DateTime completedAt, double scorePerMinute})>>
      lastCompletedWorkoutRendimentoSeries({
    required String studentId,
    int limit = 7,
  }) async {
    await requireStudentAccess(studentId);
    final rows = await (_db.select(_db.dayWorkouts)
          ..where((w) =>
              w.studentId.equals(studentId) &
              w.status.equals('completed'))
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
      final at = w.completedAt ??
          DateTime(w.dayDate.year, w.dayDate.month, w.dayDate.day);
      out.add((completedAt: at, scorePerMinute: score));
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
    final rows = await (_db.select(_db.dayWorkouts)
          ..where((w) =>
              w.studentId.equals(studentId) &
              w.status.equals('completed'))
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
        final at = w.completedAt ??
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

    final rows = await (_db.select(_db.dayWorkouts)
          ..where((w) =>
              w.studentId.equals(studentId) & w.status.equals('completed')))
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

    final out = <({String groupId, String groupName, double bestScorePerMinute})>[];
    final take = sorted.length > maxGroups ? maxGroups : sorted.length;
    for (var i = 0; i < take; i++) {
      final e = sorted[i];
      final g = await (_db.select(_db.workoutGroups)
            ..where((t) => t.id.equals(e.key)))
          .getSingleOrNull();
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
    await _requireAccessForDayWorkoutLineId(lineId);
    final row = await (_db.select(_db.dayWorkoutExercises)
          ..where((x) => x.id.equals(lineId)))
        .getSingleOrNull();
    if (row == null) {
      throw ArgumentError('Linha de exercício não encontrada.');
    }
    final existing = DayWorkoutPerformedSetCodec.decode(row.performedSetsJson);
    if (existing.length >= row.sets) {
      throw ArgumentError('Já foram registradas as ${row.sets} série(s) planejadas.');
    }
    final next = [
      ...existing,
      DayWorkoutPerformedSet(
        loadKg: loadKg,
        reps: reps,
        loggedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    ];
    await _persistDayWorkoutPerformedSets(lineId, row, next);
    await _audit('append_set', 'day_workout_exercise', entityId: lineId);
  }

  /// Grava tempos de descanso na **última** série da linha (após modal entre séries).
  Future<void> patchLastPerformedSetRestTelemetry({
    required String lineId,
    required int prescribedSec,
    required int countdownElapsedMs,
    required int postPhaseMs,
  }) async {
    await _requireAccessForDayWorkoutLineId(lineId);
    final row = await (_db.select(_db.dayWorkoutExercises)
          ..where((x) => x.id.equals(lineId)))
        .getSingleOrNull();
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
  }

  Future<void> _persistDayWorkoutPerformedSets(
    String lineId,
    DayWorkoutExerciseEntity row,
    List<DayWorkoutPerformedSet> next, {
    bool syncParentWorkoutScore = true,
  }) async {
    final volumeScore = DayWorkoutPerformedSetCodec.totalVolumeScore(next);
    final newLoadKg = next.isEmpty
        ? row.loadKg
        : (next.last.loadKg ?? row.loadKg);
    await (_db.update(_db.dayWorkoutExercises)..where((x) => x.id.equals(lineId)))
        .write(
      DayWorkoutExercisesCompanion(
        performedSetsJson: Value(DayWorkoutPerformedSetCodec.encode(next)),
        exerciseScore: Value(volumeScore),
        loadKg: Value(newLoadKg),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (syncParentWorkoutScore) {
      await _refreshWorkoutScoreForDayWorkoutAtNow(row.dayWorkoutId);
    }
  }

  /// Remove a série executada no índice [performedIndex] (0-based na lista JSON).
  Future<void> removeDayWorkoutExercisePerformedSetAt({
    required String lineId,
    required int performedIndex,
  }) async {
    await _requireAccessForDayWorkoutLineId(lineId);
    final row = await (_db.select(_db.dayWorkoutExercises)
          ..where((x) => x.id.equals(lineId)))
        .getSingleOrNull();
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
    final row = await (_db.select(_db.dayWorkoutExercises)
          ..where((x) => x.id.equals(lineId)))
        .getSingleOrNull();
    if (row == null) {
      throw ArgumentError('Linha de exercício não encontrada.');
    }
    final existing = DayWorkoutPerformedSetCodec.decode(row.performedSetsJson);
    if (performedIndex < 0 || performedIndex >= existing.length) {
      throw ArgumentError('Índice de série inválido.');
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
    if (!_session.isAdminPersonal) {
      throw ArgumentError(
        'Apenas administradores podem excluir treinos do dia desta forma.',
      );
    }
    await requireStudentAccess(studentId);
    final dayOnly = DateTime(day.year, day.month, day.day);
    final workouts = await (_db.select(_db.dayWorkouts)
          ..where(
            (w) => w.studentId.equals(studentId) & w.dayDate.equals(dayOnly),
          ))
        .get();
    if (workouts.isEmpty) return 0;

    final lineIds = <String>[];
    final workoutIds = <String>[];
    for (final w in workouts) {
      workoutIds.add(w.id);
      final lines = await (_db.select(_db.dayWorkoutExercises)
            ..where((e) => e.dayWorkoutId.equals(w.id)))
          .get();
      for (final line in lines) {
        lineIds.add(line.id);
      }
    }

    await _db.transaction(() async {
      for (final lid in lineIds) {
        await (_db.delete(_db.dayWorkoutExercises)
              ..where((e) => e.id.equals(lid)))
            .go();
      }
      for (final wid in workoutIds) {
        await (_db.delete(_db.dayWorkouts)..where((d) => d.id.equals(wid))).go();
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
    await (_db.update(_db.dayWorkouts)..where((x) => x.id.equals(id))).write(
          DayWorkoutsCompanion(
            status: const Value('cancelled'),
            timerResumeAt: const Value(null),
            updatedAt: Value(DateTime.now()),
          ),
        );
    await _audit('cancel', 'day_workout', entityId: id);
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
    await (_db.update(_db.dayWorkouts)..where((w) => w.id.equals(id))).write(
          DayWorkoutsCompanion(
            status: const Value('started'),
            startedAt: Value(now),
            timerResumeAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _audit('start', 'day_workout', entityId: id);
  }

  Future<void> pauseDayWorkout(String id) async {
    await _requireAccessForDayWorkoutId(id);
    final w = await _dayWorkoutRow(id);
    if (w == null || w.status != 'started' || w.timerResumeAt == null) return;
    final add = DateTime.now().difference(w.timerResumeAt!).inSeconds;
    await (_db.update(_db.dayWorkouts)..where((x) => x.id.equals(id))).write(
          DayWorkoutsCompanion(
            activeDurationSeconds: Value(w.activeDurationSeconds + add),
            // `Value.absent()` não altera a coluna; é preciso NULL para pausar o cronômetro.
            timerResumeAt: const Value(null),
            updatedAt: Value(DateTime.now()),
          ),
        );
    await _audit('pause', 'day_workout', entityId: id);
  }

  Future<void> resumeDayWorkout(String id) async {
    await _requireAccessForDayWorkoutId(id);
    final w = await _dayWorkoutRow(id);
    if (w == null || w.status != 'started' || w.timerResumeAt != null) return;
    await (_db.update(_db.dayWorkouts)..where((x) => x.id.equals(id))).write(
          DayWorkoutsCompanion(
            timerResumeAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
    await _audit('resume', 'day_workout', entityId: id);
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

  /// Rendimento no instante [now]: (volume registrado ÷ min ativo) × 10 — igual ao valor gravado ao registrar série.
  double liveWorkoutScorePerActiveMinute({
    required DayWorkoutEntity workout,
    required List<DayWorkoutExerciseEntity> exercises,
    DateTime? now,
  }) {
    final sum = sumPerformedVolumeDayWorkoutLines(exercises);
    final sec = effectiveActiveSeconds(workout, now ?? DateTime.now());
    final activeClamped = sec > 0 ? sec : 1;
    return scoring.workoutScoreStoredAtInstant(
      performedVolumeSum: sum,
      activeDurationSeconds: activeClamped,
    );
  }

  /// Atualiza [DayWorkoutEntity.workoutScore] com o tempo ativo e o volume **neste instante**
  /// (só para treino iniciado ou já concluído, ex.: edição de séries).
  Future<void> _refreshWorkoutScoreForDayWorkoutAtNow(String dayWorkoutId) async {
    await _requireAccessForDayWorkoutId(dayWorkoutId);
    final w = await _dayWorkoutRow(dayWorkoutId);
    if (w == null) return;
    if (w.status != 'started' && w.status != 'completed') return;
    final exercises = await getDayWorkoutExercises(dayWorkoutId);
    final sum = sumPerformedVolumeDayWorkoutLines(exercises);
    final now = DateTime.now();
    final sec = effectiveActiveSeconds(w, now);
    final activeClamped = sec > 0 ? sec : 1;
    final ws = scoring.workoutScoreStoredAtInstant(
      performedVolumeSum: sum,
      activeDurationSeconds: activeClamped,
    );
    await (_db.update(_db.dayWorkouts)..where((x) => x.id.equals(dayWorkoutId))).write(
          DayWorkoutsCompanion(
            workoutScore: Value(ws),
            updatedAt: Value(now),
          ),
        );
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
    final exercises = await getDayWorkoutExercises(id);
    for (final e in exercises) {
      final performedVol = DayWorkoutPerformedSetCodec.totalVolumeScore(
        DayWorkoutPerformedSetCodec.decode(e.performedSetsJson),
      );
      final load = e.loadKg ?? 0;
      final prescribed = e.sets * scoring.setScore(loadKg: load, reps: e.reps);
      final exScore = performedVol > 0 ? performedVol : prescribed;
      await (_db.update(_db.dayWorkoutExercises)..where((x) => x.id.equals(e.id)))
          .write(
        DayWorkoutExercisesCompanion(
          exerciseScore: Value(exScore),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
    final active = w.activeDurationSeconds;
    final now = DateTime.now();
    final wScore = w.workoutScore;
    await (_db.update(_db.dayWorkouts)..where((x) => x.id.equals(id))).write(
          DayWorkoutsCompanion(
            status: const Value('completed'),
            completedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _audit('complete', 'day_workout', entityId: id, payload: {
      'workoutScore': wScore,
      'activeSeconds': active,
    });
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
    await (_db.update(_db.dayWorkouts)..where((x) => x.id.equals(id))).write(
          DayWorkoutsCompanion(
            watchCaloriesKcal: caloriesKcal != null
                ? Value(caloriesKcal)
                : const Value.absent(),
            watchAvgHeartRateBpm: avgHeartRateBpm != null
                ? Value(avgHeartRateBpm)
                : const Value.absent(),
            updatedAt: Value(now),
          ),
        );
    await _audit('update_watch_metrics', 'day_workout', entityId: id, payload: {
      'watchCaloriesKcal': ?caloriesKcal,
      'watchAvgHeartRateBpm': ?avgHeartRateBpm,
    });
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
