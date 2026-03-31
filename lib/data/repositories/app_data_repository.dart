import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

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

/// Repositório central: CRUD local, auditoria e fila para Supabase (segundo plano).
class AppDataRepository {
  AppDataRepository(
    this._db, {
    RemoteSyncService? remoteSync,
  }) : _remote = remoteSync ?? const NoOpRemoteSyncService();

  final AppDatabase _db;
  final RemoteSyncService _remote;

  AppDatabase get db => _db;

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
  }) async {
    final now = DateTime.now();
    final sid = id ?? _uuid.v4();
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
        .watch();
  }

  Future<List<String>> gymIdsForStudent(String studentId) async {
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
    final now = DateTime.now();
    final sid = id ?? _uuid.v4();
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

  Future<void> addExerciseToWorkoutGroup({
    required String workoutGroupId,
    required String exerciseId,
    int? lastReps,
    int? lastSets,
    double? lastLoadKg,
  }) async {
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
    return (_db.select(_db.auditLogs)..orderBy([(t) => OrderingTerm.desc(t.at)]))
        .watch();
  }

  Future<List<AuditLogEntity>> allAuditLogs() {
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
        .watch();
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
        .watch();
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
  }) {
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

    return q.watch().map(
          (rows) => rows
              .map(
                (row) => WeekScheduleRow(
                  item: row.readTable(_db.weekScheduleItems),
                  exerciseName: row.readTable(_db.exercises).name,
                ),
              )
              .toList(),
        );
  }

  /// Treinos no calendário (programados / iniciados / concluídos) dentro da semana [monday, monday+7).
  Stream<List<DayWorkoutEntity>> watchStudentWeekDayWorkouts({
    required String studentId,
    required DateTime weekMonday,
  }) {
    final start = DateTime(weekMonday.year, weekMonday.month, weekMonday.day);
    final end = start.add(const Duration(days: 7));
    return (_db.select(_db.dayWorkouts)
          ..where(
            (w) =>
                w.studentId.equals(studentId) &
                w.dayDate.isBiggerOrEqualValue(start) &
                w.dayDate.isSmallerThanValue(end) &
                _dayWorkoutNotCancelled(w),
          )
          ..orderBy([(w) => OrderingTerm.asc(w.dayDate)]))
        .watch();
  }

  Future<void> addExercisesToWeekSchedule({
    required String studentId,
    required DateTime weekMonday,
    required List<String> exerciseIds,
  }) async {
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
    final now = DateTime.now();
    await (_db.update(_db.dayWorkouts)..where((d) => d.weekItemId.equals(itemId))).write(
          DayWorkoutsCompanion(
            status: const Value('cancelled'),
            weekItemId: const Value(null),
            timerResumeAt: const Value.absent(),
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
    return (_db.select(_db.students)
          ..where((s) => s.id.isIn(okStudents.toList()))
          ..orderBy([(s) => OrderingTerm.asc(s.name)]))
        .get();
  }

  Future<List<ProgrammableBundle>> getProgrammableBundles(
    String studentId,
    DateTime day,
  ) async {
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
    if (rows.isEmpty) throw ArgumentError('rows vazio');
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
      for (final r in rows) {
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

  Future<DayWorkoutEntity?> getDayWorkout(String id) {
    return (_db.select(_db.dayWorkouts)..where((w) => w.id.equals(id)))
        .getSingleOrNull();
  }

  Stream<DayWorkoutEntity?> watchDayWorkout(String id) {
    return (_db.select(_db.dayWorkouts)..where((w) => w.id.equals(id)))
        .watch()
        .map((list) => list.singleOrNull);
  }

  Stream<List<DayWorkoutExerciseEntity>> watchDayWorkoutExercises(String dayWorkoutId) {
    return (_db.select(_db.dayWorkoutExercises)
          ..where((e) => e.dayWorkoutId.equals(dayWorkoutId))
          ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
        .watch();
  }

  Future<List<DayWorkoutExerciseEntity>> getDayWorkoutExercises(String dayWorkoutId) {
    return (_db.select(_db.dayWorkoutExercises)
          ..where((e) => e.dayWorkoutId.equals(dayWorkoutId))
          ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
        .get();
  }

  /// Acrescenta uma série executada (JSON). Não altera [reps] prescrito da linha.
  Future<void> appendDayWorkoutExercisePerformedSet({
    required String lineId,
    double? loadKg,
    required int reps,
  }) async {
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
    final volumeScore = DayWorkoutPerformedSetCodec.totalVolumeScore(next);
    await (_db.update(_db.dayWorkoutExercises)..where((x) => x.id.equals(lineId)))
        .write(
      DayWorkoutExercisesCompanion(
        performedSetsJson: Value(DayWorkoutPerformedSetCodec.encode(next)),
        loadKg: Value(loadKg ?? row.loadKg),
        exerciseScore: Value(volumeScore),
      ),
    );
    await _audit('append_set', 'day_workout_exercise', entityId: lineId);
  }

  /// Cancela treino programado (troca no calendário): linha e exercícios permanecem no BD.
  Future<bool> deleteProgrammedDayWorkout(String id) async {
    final w = await getDayWorkout(id);
    if (w == null) return false;
    if (w.status != 'programmed') return false;
    await (_db.update(_db.dayWorkouts)..where((x) => x.id.equals(id))).write(
          DayWorkoutsCompanion(
            status: const Value('cancelled'),
            timerResumeAt: const Value.absent(),
            updatedAt: Value(DateTime.now()),
          ),
        );
    await _audit('cancel', 'day_workout', entityId: id);
    return true;
  }

  Future<void> startDayWorkout(String id) async {
    final cur = await getDayWorkout(id);
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
    final w = await getDayWorkout(id);
    if (w == null || w.status != 'started' || w.timerResumeAt == null) return;
    final add = DateTime.now().difference(w.timerResumeAt!).inSeconds;
    await (_db.update(_db.dayWorkouts)..where((x) => x.id.equals(id))).write(
          DayWorkoutsCompanion(
            activeDurationSeconds: Value(w.activeDurationSeconds + add),
            timerResumeAt: const Value.absent(),
            updatedAt: Value(DateTime.now()),
          ),
        );
    await _audit('pause', 'day_workout', entityId: id);
  }

  Future<void> resumeDayWorkout(String id) async {
    final w = await getDayWorkout(id);
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
    final before = await getDayWorkout(id);
    if (before == null || before.status != 'started') return;
    if (before.timerResumeAt != null) {
      await pauseDayWorkout(id);
    }
    final w = await getDayWorkout(id);
    if (w == null) return;
    final exercises = await getDayWorkoutExercises(id);
    var sum = 0.0;
    for (final e in exercises) {
      final load = e.loadKg ?? 0;
      final exScore =
          e.sets * scoring.setScore(loadKg: load, reps: e.reps);
      sum += exScore;
      await (_db.update(_db.dayWorkoutExercises)..where((x) => x.id.equals(e.id)))
          .write(DayWorkoutExercisesCompanion(exerciseScore: Value(exScore)));
    }
    final active = w.activeDurationSeconds;
    final ws = scoring.workoutScore(
      exercisesScoreSum: sum,
      activeDurationSeconds: active > 0 ? active : 1,
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
