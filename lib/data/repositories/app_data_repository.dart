import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/auth/app_session.dart';
import '../../core/utils/calendar_day_utils.dart';
import '../../domain/scoring.dart' as scoring;
import '../local/app_database.dart';
import '../models/day_workout_performed_set.dart';
import '../models/programmable_bundle.dart';
import '../models/week_schedule_row.dart';
import '../sync/remote_sync_service.dart';

const _uuid = Uuid();

Expression<bool> _dayWorkoutNotCancelled($DayWorkoutsTable t) =>
    t.status.equals('cancelled').not();

/// Uma linha por exercício: evita o mesmo [exerciseId] repetido no treino do dia
/// (lista na modal do calendário e demais leituras).
List<DayWorkoutExerciseEntity> _uniqueDayWorkoutLinesByExerciseId(
  List<DayWorkoutExerciseEntity> lines,
) {
  final seen = <String>{};
  return [
    for (final line in lines)
      if (seen.add(line.exerciseId)) line,
  ];
}

/// Preserva a primeira ocorrência de cada exercício ao montar o snapshot do dia.
List<WeekScheduleRow> _uniqueWeekScheduleRowsByExerciseId(
  List<WeekScheduleRow> rows,
) {
  final seen = <String>{};
  return [
    for (final r in rows)
      if (seen.add(r.item.exerciseId)) r,
  ];
}

/// Repositório central: CRUD local, auditoria e fila para Supabase (segundo plano).
class AppDataRepository {
  AppDataRepository(
    this._db,
    this._session, {
    RemoteSyncService? remoteSync,
  }) : _remote = remoteSync ?? const NoOpRemoteSyncService();

  final AppDatabase _db;
  final AppSession _session;
  final RemoteSyncService _remote;

  AppDatabase get db => _db;
  AppSession get session => _session;

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
    await _db.into(_db.auditLogs).insert(
          AuditLogsCompanion.insert(
            id: _uuid.v4(),
            action: action,
            entityType: entityType,
            entityId: Value(entityId),
            payloadJson: Value(payload == null ? null : jsonEncode(payload)),
          ),
        );
    await _remote.enqueueAudit(
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
    final now = DateTime.now();
    final sid = id ?? _uuid.v4();
    await _db.into(_db.muscleGroups).insertOnConflictUpdate(
          MuscleGroupsCompanion.insert(
            id: sid,
            name: name,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _audit(id == null ? 'create' : 'update', 'muscle_group',
        entityId: sid, payload: {'name': name});
  }

  Future<void> deleteMuscleGroup(String id) async {
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
    final now = DateTime.now();
    final sid = id ?? _uuid.v4();
    await _db.into(_db.exercises).insertOnConflictUpdate(
          ExercisesCompanion.insert(
            id: sid,
            name: name,
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

  Future<void> deleteExercise(String id) async {
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
    await (_db.delete(_db.studentGyms)..where((t) => t.gymId.equals(id))).go();
    await (_db.delete(_db.gyms)..where((t) => t.id.equals(id))).go();
    await _audit('delete', 'gym', entityId: id);
  }

  Stream<List<PersonalEntity>> watchPersonalsAlphabetical() {
    return (_db.select(_db.personals)..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
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
    required String email,
    bool mustChangePassword = true,
    String? passwordHash,
    bool? isAdmin,
  }) async {
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
    await (_db.delete(_db.personals)..where((t) => t.id.equals(id))).go();
    await _audit('delete', 'personal', entityId: id);
  }

  Stream<List<StudentEntity>> watchStudentsAlphabetical() {
    return (_db.select(_db.students)..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch()
        .map(_visibleStudents);
  }

  /// Lista completa de alunos para trocar sessão (apenas admin); demais perfis usam a lista filtrada.
  Stream<List<StudentEntity>> watchStudentsForSessionPicker() {
    if (_session.isAdminPersonal) {
      return (_db.select(_db.students)..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();
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
    await (_db.delete(_db.trainingMethods)..where((t) => t.id.equals(id))).go();
    await _audit('delete', 'training_method', entityId: id);
  }

  Stream<List<WorkoutGroupEntity>> watchWorkoutGroupsAlphabetical() {
    return (_db.select(_db.workoutGroups)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<void> upsertWorkoutGroup({
    String? id,
    required String name,
    required String description,
  }) async {
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
  }

  Future<void> deleteWorkoutGroup(String id) async {
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
  }) async {
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
            lastSets: Value(lastSets),
            lastLoadKg: Value(lastLoadKg),
          ),
        );
    await _audit('add_exercise', 'workout_group', entityId: workoutGroupId);
    return true;
  }

  Future<void> updateWorkoutGroupExerciseLine({
    required String lineId,
    int? lastReps,
    int? lastSets,
    double? lastLoadKg,
  }) async {
    await (_db.update(_db.workoutGroupExercises)..where((t) => t.id.equals(lineId)))
        .write(
      WorkoutGroupExercisesCompanion(
        lastReps: Value(lastReps),
        lastSets: Value(lastSets),
        lastLoadKg: Value(lastLoadKg),
      ),
    );
    await _audit('update', 'workout_group_exercise', entityId: lineId);
  }

  Future<void> removeWorkoutGroupExerciseLine(String lineId) async {
    await (_db.delete(_db.workoutGroupExercises)
          ..where((t) => t.id.equals(lineId)))
        .go();
    await _audit('delete', 'workout_group_exercise', entityId: lineId);
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

  /// Treinos no dia (calendário): incompletos programados em vermelho na UI.
  Stream<List<DayWorkoutEntity>> watchDayWorkouts(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (_db.select(_db.dayWorkouts)
          ..where((t) =>
              t.dayDate.isBiggerOrEqualValue(start) &
              t.dayDate.isSmallerThanValue(end) &
              _dayWorkoutNotCancelled(t)))
        .watch()
        .asyncMap(_visibleDayWorkouts);
  }

  Stream<List<DayWorkoutEntity>> watchWorkoutsBetween(
    DateTime fromInclusive,
    DateTime toExclusive,
  ) {
    return (_db.select(_db.dayWorkouts)
          ..where((t) =>
              t.dayDate.isBiggerOrEqualValue(fromInclusive) &
              t.dayDate.isSmallerThanValue(toExclusive) &
              _dayWorkoutNotCancelled(t)))
        .watch()
        .asyncMap(_visibleDayWorkouts);
  }

  // ——— Planejamento: semana (bloco + itens agendados) ———

  static DateTime normalizeMonday(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  Future<String> _getOrCreateWeekBlock(String studentId, DateTime weekMonday) async {
    final mon = DateTime(weekMonday.year, weekMonday.month, weekMonday.day);
    final existing = await (_db.select(_db.weekScheduleBlocks)
          ..where(
            (b) => b.studentId.equals(studentId) & b.weekStartMonday.equals(mon),
          ))
        .getSingleOrNull();
    if (existing != null) return existing.id;
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
  }) async* {
    await requireStudentAccess(studentId);
    final mon = DateTime(weekMonday.year, weekMonday.month, weekMonday.day);
    final q = _db.select(_db.weekScheduleItems).join([
      innerJoin(
        _db.weekScheduleBlocks,
        _db.weekScheduleBlocks.id.equalsExp(_db.weekScheduleItems.blockId),
      ),
      innerJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.weekScheduleItems.exerciseId),
      ),
    ])
      ..where(
        _db.weekScheduleBlocks.studentId.equals(studentId) &
            _db.weekScheduleBlocks.weekStartMonday.equals(mon),
      )
      ..orderBy([OrderingTerm.asc(_db.weekScheduleItems.sortOrder)]);

    await for (final rows in q.watch()) {
      yield rows
          .map(
            (row) => WeekScheduleRow(
              item: row.readTable(_db.weekScheduleItems),
              exerciseName: row.readTable(_db.exercises).name,
            ),
          )
          .toList();
    }
  }

  /// Treinos no calendário (programados / iniciados / concluídos) dentro da semana [monday, monday+7).
  Stream<List<DayWorkoutEntity>> watchStudentWeekDayWorkouts({
    required String studentId,
    required DateTime weekMonday,
  }) async* {
    await requireStudentAccess(studentId);
    final start = DateTime(weekMonday.year, weekMonday.month, weekMonday.day);
    final end = start.add(const Duration(days: 7));
    final stream = (_db.select(_db.dayWorkouts)
          ..where(
            (w) =>
                w.studentId.equals(studentId) &
                w.dayDate.isBiggerOrEqualValue(start) &
                w.dayDate.isSmallerThanValue(end) &
                _dayWorkoutNotCancelled(w),
          )
          ..orderBy([(w) => OrderingTerm.asc(w.dayDate)]))
        .watch();
    await for (final list in stream) {
      yield list;
    }
  }

  Future<void> addExercisesToWeekSchedule({
    required String studentId,
    required DateTime weekMonday,
    required List<String> exerciseIds,
  }) async {
    await requireStudentAccess(studentId);
    if (exerciseIds.isEmpty) return;
    final blockId = await _getOrCreateWeekBlock(studentId, weekMonday);
    final existing = await (_db.select(_db.weekScheduleItems)
          ..where((i) => i.blockId.equals(blockId)))
        .get();
    var maxO = -1;
    for (final i in existing) {
      if (i.sortOrder > maxO) maxO = i.sortOrder;
    }
    await _db.transaction(() async {
      for (final exId in exerciseIds) {
        maxO++;
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
              ),
            );
      }
    });
    await _audit('schedule_exercises_week', 'week_schedule', entityId: blockId);
  }

  Future<void> copyWorkoutGroupToWeekSchedule({
    required String studentId,
    required DateTime weekMonday,
    required String workoutGroupId,
  }) async {
    await requireStudentAccess(studentId);
    final blockId = await _getOrCreateWeekBlock(studentId, weekMonday);
    final lines = await (_db.select(_db.workoutGroupExercises)
          ..where((t) => t.workoutGroupId.equals(workoutGroupId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    if (lines.isEmpty) return;
    final existing = await (_db.select(_db.weekScheduleItems)
          ..where((i) => i.blockId.equals(blockId)))
        .get();
    var maxO = -1;
    for (final i in existing) {
      if (i.sortOrder > maxO) maxO = i.sortOrder;
    }
    await _db.transaction(() async {
      for (final line in lines) {
        maxO++;
        final sets = line.lastSets ?? 0;
        final reps = line.lastReps ?? 0;
        final needsDetail = sets <= 0 || reps <= 0;
        await _db.into(_db.weekScheduleItems).insert(
              WeekScheduleItemsCompanion.insert(
                id: _uuid.v4(),
                blockId: blockId,
                exerciseId: line.exerciseId,
                sourceWorkoutGroupId: Value(workoutGroupId),
                sortOrder: Value(maxO),
                sets: Value(sets),
                reps: Value(reps),
                loadKg: Value(line.lastLoadKg),
                needsDetail: Value(needsDetail),
              ),
            );
      }
    });
    await _audit(
      'schedule_group_week',
      'week_schedule',
      entityId: blockId,
      payload: {'workoutGroupId': workoutGroupId},
    );
  }

  Future<void> updateWeekScheduleItem({
    required String itemId,
    required int sets,
    required int reps,
    double? loadKg,
  }) async {
    final item = await (_db.select(_db.weekScheduleItems)
          ..where((i) => i.id.equals(itemId)))
        .getSingleOrNull();
    if (item == null) return;
    final block = await (_db.select(_db.weekScheduleBlocks)
          ..where((b) => b.id.equals(item.blockId)))
        .getSingleOrNull();
    if (block == null) return;
    await requireStudentAccess(block.studentId);

    final needsDetail = sets <= 0 || reps <= 0;
    await (_db.update(_db.weekScheduleItems)..where((i) => i.id.equals(itemId))).write(
          WeekScheduleItemsCompanion(
            sets: Value(sets),
            reps: Value(reps),
            loadKg: Value(loadKg),
            needsDetail: Value(needsDetail),
          ),
        );
    await _audit('update', 'week_schedule_item', entityId: itemId);
  }

  Future<void> deleteWeekScheduleItem(String itemId) async {
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
      innerJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.weekScheduleItems.exerciseId),
      ),
    ])
      ..where(
        _db.weekScheduleBlocks.studentId.equals(studentId) &
            _db.weekScheduleBlocks.weekStartMonday.equals(mon),
      )
      ..orderBy([OrderingTerm.asc(_db.weekScheduleItems.sortOrder)]);
    final rows = await q.get();
    return rows
        .map(
          (row) => WeekScheduleRow(
            item: row.readTable(_db.weekScheduleItems),
            exerciseName: row.readTable(_db.exercises).name,
          ),
        )
        .toList();
  }

  /// Alunos com pelo menos um item de semana válido (séries/reps preenchidos) na semana do dia.
  Future<List<StudentEntity>> getStudentsWithProgrammableWeek(DateTime day) async {
    final monday = normalizeMonday(day);
    final blocks = await (_db.select(_db.weekScheduleBlocks)
          ..where((b) => b.weekStartMonday.equals(monday)))
        .get();
    final okStudents = <String>{};
    for (final b in blocks) {
      final items = await (_db.select(_db.weekScheduleItems)
            ..where((i) => i.blockId.equals(b.id)))
          .get();
      final ok = items.any((i) => i.sets > 0 && i.reps > 0 && !i.needsDetail);
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
        .where((r) => r.item.sets > 0 && r.item.reps > 0 && !r.item.needsDetail)
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
    final uniqueRows = _uniqueWeekScheduleRowsByExerciseId(rows);
    if (uniqueRows.isEmpty) throw ArgumentError('rows vazio');
    final dayOnly = DateTime(day.year, day.month, day.day);
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
      var order = 0;
      for (final r in uniqueRows) {
        final i = r.item;
        order++;
        await _db.into(_db.dayWorkoutExercises).insert(
              DayWorkoutExercisesCompanion.insert(
                id: _uuid.v4(),
                dayWorkoutId: wid,
                exerciseId: i.exerciseId,
                sortOrder: Value(order),
                sets: i.sets,
                reps: i.reps,
                loadKg: Value(i.loadKg),
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

  Stream<List<DayWorkoutExerciseEntity>> watchDayWorkoutExercises(
    String dayWorkoutId,
  ) async* {
    await _requireAccessForDayWorkoutId(dayWorkoutId);
    yield* (_db.select(_db.dayWorkoutExercises)
          ..where((e) => e.dayWorkoutId.equals(dayWorkoutId))
          ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
        .watch()
        .map(_uniqueDayWorkoutLinesByExerciseId);
  }

  Future<List<DayWorkoutExerciseEntity>> getDayWorkoutExercises(String dayWorkoutId) async {
    await _requireAccessForDayWorkoutId(dayWorkoutId);
    final raw = await (_db.select(_db.dayWorkoutExercises)
          ..where((e) => e.dayWorkoutId.equals(dayWorkoutId))
          ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
        .get();
    return _uniqueDayWorkoutLinesByExerciseId(raw);
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
      DayWorkoutPerformedSet(loadKg: loadKg, reps: reps),
    ];
    await _persistDayWorkoutPerformedSets(lineId, row, next);
    await _audit('append_set', 'day_workout_exercise', entityId: lineId);
  }

  Future<void> _persistDayWorkoutPerformedSets(
    String lineId,
    DayWorkoutExerciseEntity row,
    List<DayWorkoutPerformedSet> next,
  ) async {
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
      ),
    );
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
    next[performedIndex] = DayWorkoutPerformedSet(loadKg: loadKg, reps: reps);
    await _persistDayWorkoutPerformedSets(lineId, row, next);
    await _audit('update_set', 'day_workout_exercise', entityId: lineId);
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
    var sum = 0.0;
    for (final e in exercises) {
      final performedVol = DayWorkoutPerformedSetCodec.totalVolumeScore(
        DayWorkoutPerformedSetCodec.decode(e.performedSetsJson),
      );
      final load = e.loadKg ?? 0;
      final prescribed = e.sets * scoring.setScore(loadKg: load, reps: e.reps);
      final exScore = performedVol > 0 ? performedVol : prescribed;
      sum += exScore;
      await (_db.update(_db.dayWorkoutExercises)..where((x) => x.id.equals(e.id)))
          .write(DayWorkoutExercisesCompanion(exerciseScore: Value(exScore)));
    }
    final active = w.activeDurationSeconds;
    final activeClamped = active > 0 ? active : 1;
    final ws = scoring.workoutScorePerActiveMinute(
      exercisesScoreSum: sum,
      activeDurationSeconds: activeClamped,
    );
    final now = DateTime.now();
    await (_db.update(_db.dayWorkouts)..where((x) => x.id.equals(id))).write(
          DayWorkoutsCompanion(
            status: const Value('completed'),
            completedAt: Value(now),
            workoutScore: Value(ws),
            updatedAt: Value(now),
          ),
        );
    await _audit('complete', 'day_workout', entityId: id, payload: {
      'workoutScore': ws,
      'activeSeconds': active,
    });
  }
}
