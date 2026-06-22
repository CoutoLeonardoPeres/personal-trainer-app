import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/calendar_day_utils.dart';
import '../../core/utils/muscle_group_utils.dart';
import '../../domain/scoring.dart' as scoring;
import '../models/day_workout_performed_set.dart';
import 'exercise_seed_defaults.dart';

part 'app_database.g.dart';

/// Nomes padrão de grupos musculares (cadastro de exercícios).
const kDefaultMuscleGroupNames = <String>[
  'Ombros',
  'Coxas',
  'Coxas Posterior',
  'Bíceps',
  'Tríceps',
  'Dorsal',
  'Abdômen',
  'Peitoral',
  'Panturrilhas',
  'Glúteos',
  'Trapézio',
  'Glúteo',
  'Antebraço',
  'Lombar',
  'Coxas Interno',
  'HITT',
  'Alongamento',
  'Mobilidade',
  'Aeróbico',
  'Funcional',
  'Elástico e Faixas',
  'Treino em Casa',
];

// ——— Cadastros ———

@DataClassName('MuscleGroupEntity')
class MuscleGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ExerciseEntity')
class Exercises extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get muscleGroupId => text().references(MuscleGroups, #id)();
  TextColumn get videoUrl => text().nullable()();
  TextColumn get alternativeNote => text().nullable()();
  TextColumn get alternativeVideoUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('GymEntity')
class Gyms extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get cnpj => text()();
  TextColumn get street => text()();
  TextColumn get number => text()();
  TextColumn get complement => text().nullable()();
  TextColumn get district => text()();
  TextColumn get city => text()();
  TextColumn get stateUf => text()();
  TextColumn get cep => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PersonalEntity')
class Personals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get cpf => text()();
  TextColumn get professionalRegistry => text()();
  TextColumn get street => text()();
  TextColumn get number => text()();
  TextColumn get complement => text().nullable()();
  TextColumn get city => text()();
  TextColumn get stateUf => text()();
  TextColumn get cep => text().nullable()();
  TextColumn get email => text()();
  TextColumn get phoneCommercial => text().nullable()();
  TextColumn get phoneMobile => text().nullable()();
  BoolColumn get mustChangePassword =>
      boolean().withDefault(const Constant(true))();
  TextColumn get passwordHash => text().nullable()();

  /// Acesso total aos dados de todos os alunos (calendário, planejamento, cadastro).
  BoolColumn get isAdmin => boolean().withDefault(const Constant(false))();

  /// Plano / perfil comercial (RBAC). `legacy` = comportamento anterior ao controle fino.
  TextColumn get accessTier => text().withDefault(const Constant('legacy'))();

  /// Limite de alunos (personal starter/pro). Null = ilimitado (legacy / pro+).
  IntColumn get maxStudentsCap => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('StudentEntity')
class Students extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get goal => text().nullable()();
  TextColumn get cpf => text().nullable()();
  DateTimeColumn get birthDate => dateTime().nullable()();
  TextColumn get street => text().nullable()();
  TextColumn get number => text().nullable()();
  TextColumn get complement => text().nullable()();
  TextColumn get district => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get stateUf => text().nullable()();
  TextColumn get cep => text().nullable()();
  TextColumn get phoneCommercial => text().nullable()();
  TextColumn get phoneMobile => text().nullable()();

  /// Quando true, o app exige troca de senha no próximo acesso.
  BoolColumn get mustChangePassword =>
      boolean().withDefault(const Constant(true))();
  TextColumn get passwordHash => text().nullable()();

  /// Personal que cadastrou o aluno — visibilidade dos dados (com admin e o próprio aluno).
  TextColumn get createdByPersonalId =>
      text().nullable().references(Personals, #id)();

  /// Obrigatório para alunos com perfil comercial (free/basic/premium); `true` libera o app.
  BoolColumn get anamneseCompleted =>
      boolean().withDefault(const Constant(true))();

  /// Plano aluno (RBAC). `legacy` = sem restrições do novo modelo.
  TextColumn get accessTier => text().withDefault(const Constant('legacy'))();

  /// Fim do período premium (trial ou assinatura); após esta data o app faz downgrade local para standard.
  DateTimeColumn get premiumPlanExpiresAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('StudentGymEntity')
class StudentGyms extends Table {
  TextColumn get studentId => text().references(Students, #id)();
  TextColumn get gymId => text().references(Gyms, #id)();

  @override
  Set<Column<Object>> get primaryKey => {studentId, gymId};
}

@DataClassName('TrainingMethodEntity')
class TrainingMethods extends Table {
  TextColumn get id => text()();
  TextColumn get method => text()();
  TextColumn get description => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('WorkoutGroupEntity')
class WorkoutGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text()();

  /// Personal dono do modelo. Admin pode deixar nulo para modelos globais/legados.
  TextColumn get createdByPersonalId =>
      text().nullable().references(Personals, #id)();

  /// Quando true, o modelo pode aparecer para outros personais como catálogo compartilhado.
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();

  /// Versão LWW para conflitos entre dispositivos.
  IntColumn get revision => integer().withDefault(const Constant(0))();

  /// Dispositivo que fez a última alteração local/remota.
  TextColumn get lastModifiedByDeviceId => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Exclusão lógica: não aparece em cadastro/planejamento/agenda futura; permanece no BD
  /// para nome em histórico (ex.: treino concluído no passado com [DayWorkouts.sourceWorkoutGroupId]).
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('WorkoutGroupExerciseEntity')
class WorkoutGroupExercises extends Table {
  TextColumn get id => text()();
  TextColumn get workoutGroupId => text().references(WorkoutGroups, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  RealColumn get lastLoadKg => real().nullable()();

  /// Legado (número inteiro); preferir [lastRepsText] para faixas como «12-15».
  IntColumn get lastReps => integer().nullable()();
  TextColumn get lastRepsText => text().nullable()();
  IntColumn get lastSets => integer().nullable()();

  /// Descanso prescrito entre séries deste exercício no modelo (segundos).
  IntColumn get restBetweenSetsSec =>
      integer().withDefault(const Constant(60))();

  /// Método de treino associado a esta linha (opcional).
  TextColumn get trainingMethodId =>
      text().nullable().references(TrainingMethods, #id)();

  /// Para importação admin (LWW) alinhada ao Supabase.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Exercícios consecutivos com o mesmo id formam um bloco (superserie); descanso só após a última linha do bloco.
  TextColumn get comboId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ——— Agendamento / calendário ———

/// Bloco da semana (segunda-feira como início) por aluno.
@DataClassName('WeekScheduleBlockEntity')
class WeekScheduleBlocks extends Table {
  TextColumn get id => text()();
  TextColumn get studentId => text().references(Students, #id)();
  DateTimeColumn get weekStartMonday => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Itens agendados na semana (exercícios com séries/reps/carga).
@DataClassName('WeekScheduleItemEntity')
class WeekScheduleItems extends Table {
  TextColumn get id => text()();
  TextColumn get blockId => text().references(WeekScheduleBlocks, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  TextColumn get sourceWorkoutGroupId => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get sets => integer().withDefault(const Constant(0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();

  /// Faixa livre (ex.: «12-15»); quando preenchido, tem precedência na UI sobre [reps].
  TextColumn get repsText => text().nullable()();
  RealColumn get loadKg => real().nullable()();
  BoolColumn get needsDetail => boolean().withDefault(const Constant(false))();

  /// Descanso entre séries (s); copiado do grupo ou ajustado no planejamento.
  IntColumn get restBetweenSetsSec =>
      integer().withDefault(const Constant(60))();

  TextColumn get trainingMethodId =>
      text().nullable().references(TrainingMethods, #id)();

  /// Para importação admin (LWW) alinhada ao Supabase.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  TextColumn get comboId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Treino em dia específico: programado, iniciado, concluído.
@DataClassName('DayWorkoutEntity')
class DayWorkouts extends Table {
  TextColumn get id => text()();
  TextColumn get studentId => text().references(Students, #id)();
  DateTimeColumn get dayDate => dateTime()();

  /// scheduled | programmed | started | completed | cancelled (cancelado = permanece no BD)
  TextColumn get status => text()();
  TextColumn get weekItemId => text().nullable()();
  IntColumn get activeDurationSeconds =>
      integer().withDefault(const Constant(0))();
  RealColumn get workoutScore => real().nullable()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// Quando não nulo, o cronômetro está correndo desde este instante (tempo ativo acumulado em [activeDurationSeconds]).
  DateTimeColumn get timerResumeAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Quando veio de um grupo ao programar no calendário — exibe o nome do grupo na folha.
  TextColumn get sourceWorkoutGroupId => text().nullable()();

  /// Calorias (kcal) opcionais do relógio/smartphone após o treino.
  RealColumn get watchCaloriesKcal => real().nullable()();

  /// Frequência cardíaca média (bpm) opcional, ex.: Apple Watch / Garmin.
  IntColumn get watchAvgHeartRateBpm => integer().nullable()();

  /// Revisão monotônica para resolução determinística de conflito (local x nuvem).
  IntColumn get revision => integer().withDefault(const Constant(0))();

  /// Identificador do dispositivo que alterou por último.
  TextColumn get lastModifiedByDeviceId => text().nullable()();

  /// pending | syncing | synced | failed (somente para observabilidade local).
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();

  /// Tombstone local para evitar ressurreição por pull remoto antigo.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('DayWorkoutExerciseEntity')
class DayWorkoutExercises extends Table {
  TextColumn get id => text()();
  TextColumn get dayWorkoutId => text().references(DayWorkouts, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get sets => integer()();
  IntColumn get reps => integer()();
  TextColumn get repsText => text().nullable()();
  RealColumn get loadKg => real().nullable()();
  RealColumn get exerciseScore => real().nullable()();

  /// JSON: lista `[{ "loadKg": 20.0, "reps": 15 }, ...]` — séries executadas (modal Adicionar série).
  TextColumn get performedSetsJson => text().nullable()();

  /// Descanso prescrito entre séries neste dia (s); vindo do planejamento / grupo.
  IntColumn get restBetweenSetsSec =>
      integer().withDefault(const Constant(60))();

  TextColumn get trainingMethodId =>
      text().nullable().references(TrainingMethods, #id)();

  /// Para importação admin (LWW) alinhada ao Supabase.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  TextColumn get comboId => text().nullable()();

  /// Revisão monotônica para resolução determinística de conflito (local x nuvem).
  IntColumn get revision => integer().withDefault(const Constant(0))();

  /// Identificador do dispositivo que alterou por último.
  TextColumn get lastModifiedByDeviceId => text().nullable()();

  /// pending | syncing | synced | failed (somente para observabilidade local).
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();

  /// Tombstone local para evitar ressurreição por pull remoto antigo.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ——— Auditoria / logs ———

@DataClassName('AuditLogEntity')
class AuditLogs extends Table {
  TextColumn get id => text()();
  DateTimeColumn get at => dateTime().withDefault(currentDateAndTime)();
  TextColumn get action => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text().nullable()();
  TextColumn get payloadJson => text().nullable()();
  TextColumn get deviceId => text().nullable()();
  TextColumn get personalId => text().nullable().references(Personals, #id)();
  TextColumn get studentId => text().nullable().references(Students, #id)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SyncQueueItemEntity')
class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payloadJson => text().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(2))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  TextColumn get dedupeKey => text().nullable()();
  TextColumn get auditLogId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    MuscleGroups,
    Exercises,
    Gyms,
    Personals,
    Students,
    StudentGyms,
    TrainingMethods,
    WorkoutGroups,
    WorkoutGroupExercises,
    WeekScheduleBlocks,
    WeekScheduleItems,
    DayWorkouts,
    DayWorkoutExercises,
    AuditLogs,
    SyncQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 32;

  /// Migrações **incrementais** apenas (`addColumn`, `create`, etc.).
  /// Nunca usar recriação destrutiva do banco: os dados do usuário devem persistir
  /// após atualizações do app. Ao subir [schemaVersion], acrescente blocos `if (from < N)`.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedMuscleGroupsFromDefaults();
      await _seedExercisesFromDefaults();
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS muscle_groups_unique_normalized_name '
        'ON muscle_groups (lower(trim(name)))',
      );
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS exercises_unique_normalized_name '
        'ON exercises (lower(trim(name)))',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS sync_queue_status_next_retry_idx '
        'ON sync_queue(status, next_retry_at, priority, updated_at)',
      );
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS sync_queue_dedupe_key_uidx '
        'ON sync_queue(dedupe_key) WHERE dedupe_key IS NOT NULL',
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(personals, personals.mustChangePassword);
        await m.addColumn(personals, personals.passwordHash);
      }
      if (from < 3) {
        await m.addColumn(dayWorkouts, dayWorkouts.timerResumeAt);
      }
      if (from < 4) {
        await m.addColumn(dayWorkouts, dayWorkouts.sourceWorkoutGroupId);
      }
      if (from < 5) {
        await m.addColumn(
          dayWorkoutExercises,
          dayWorkoutExercises.performedSetsJson,
        );
      }
      if (from < 6) {
        await m.addColumn(personals, personals.isAdmin);
        await m.addColumn(students, students.createdByPersonalId);
        await customStatement(
          'UPDATE personals SET is_admin = 1 WHERE id = '
          '(SELECT id FROM personals ORDER BY created_at ASC LIMIT 1) '
          'AND (SELECT COUNT(*) FROM personals) >= 1;',
        );
        await customStatement(
          'UPDATE students SET created_by_personal_id = '
          '(SELECT id FROM personals ORDER BY created_at ASC LIMIT 1) '
          'WHERE created_by_personal_id IS NULL '
          'AND (SELECT COUNT(*) FROM personals) = 1;',
        );
      }
      if (from < 7) {
        await _seedMuscleGroupsFromDefaults();
      }
      if (from < 9) {
        await _seedExercisesFromDefaults();
      }
      if (from < 10) {
        await m.addColumn(personals, personals.cep);
      }
      if (from < 11) {
        await m.addColumn(
          workoutGroupExercises,
          workoutGroupExercises.lastRepsText,
        );
        await customStatement(
          'UPDATE workout_group_exercises SET last_reps_text = CAST(last_reps AS TEXT) '
          'WHERE last_reps IS NOT NULL AND (last_reps_text IS NULL OR last_reps_text = \'\');',
        );
      }
      if (from < 12) {
        await _dedupeMuscleGroupsByNormalizedName();
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS muscle_groups_unique_normalized_name '
          'ON muscle_groups (lower(trim(name)))',
        );
      }
      if (from < 13) {
        await _dedupeExercisesByNormalizedName();
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS exercises_unique_normalized_name '
          'ON exercises (lower(trim(name)))',
        );
      }
      if (from < 14) {
        await m.addColumn(personals, personals.phoneCommercial);
        await m.addColumn(personals, personals.phoneMobile);
        await m.addColumn(students, students.phoneCommercial);
        await m.addColumn(students, students.phoneMobile);
      }
      if (from < 15) {
        await m.addColumn(
          workoutGroupExercises,
          workoutGroupExercises.restBetweenSetsSec,
        );
        await m.addColumn(
          weekScheduleItems,
          weekScheduleItems.restBetweenSetsSec,
        );
        await m.addColumn(
          dayWorkoutExercises,
          dayWorkoutExercises.restBetweenSetsSec,
        );
        await customStatement(
          'UPDATE workout_group_exercises SET rest_between_sets_sec = 60 '
          'WHERE rest_between_sets_sec IS NULL;',
        );
        await customStatement(
          'UPDATE week_schedule_items SET rest_between_sets_sec = 60 '
          'WHERE rest_between_sets_sec IS NULL;',
        );
        await customStatement(
          'UPDATE day_workout_exercises SET rest_between_sets_sec = 60 '
          'WHERE rest_between_sets_sec IS NULL;',
        );
      }
      if (from < 16) {
        await _backfillCompletedWorkoutScoresV16();
      }
      if (from < 17) {
        // Drift's `addColumn` + `currentDateAndTime` emits
        // `DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))`, which
        // SQLite rejects for ALTER TABLE (non-constant default).
        await _addUpdatedAtSecondsColumn('workout_group_exercises');
        await _addUpdatedAtSecondsColumn('week_schedule_items');
        await _addUpdatedAtSecondsColumn('day_workout_exercises');
      }
      if (from < 18) {
        await m.addColumn(dayWorkouts, dayWorkouts.watchCaloriesKcal);
        await m.addColumn(dayWorkouts, dayWorkouts.watchAvgHeartRateBpm);
      }
      if (from < 19) {
        await _normalizeWeekBlocksAndDayWorkoutDatesV19();
      }
      if (from < 20) {
        await m.addColumn(
          workoutGroupExercises,
          workoutGroupExercises.trainingMethodId,
        );
        await m.addColumn(weekScheduleItems, weekScheduleItems.repsText);
        await m.addColumn(
          weekScheduleItems,
          weekScheduleItems.trainingMethodId,
        );
        await m.addColumn(dayWorkoutExercises, dayWorkoutExercises.repsText);
        await m.addColumn(
          dayWorkoutExercises,
          dayWorkoutExercises.trainingMethodId,
        );
        await customStatement(
          'UPDATE week_schedule_items SET reps_text = CAST(reps AS TEXT) '
          'WHERE (reps_text IS NULL OR reps_text = \'\') AND reps > 0;',
        );
        await customStatement(
          'UPDATE day_workout_exercises SET reps_text = CAST(reps AS TEXT) '
          'WHERE (reps_text IS NULL OR reps_text = \'\') AND reps > 0;',
        );
      }
      if (from < 21) {
        await m.addColumn(workoutGroupExercises, workoutGroupExercises.comboId);
        await m.addColumn(weekScheduleItems, weekScheduleItems.comboId);
        await m.addColumn(dayWorkoutExercises, dayWorkoutExercises.comboId);
      }
      if (from < 22) {
        await m.addColumn(students, students.anamneseCompleted);
        await m.addColumn(students, students.accessTier);
        await m.addColumn(personals, personals.accessTier);
        await m.addColumn(personals, personals.maxStudentsCap);
        await customStatement(
          'UPDATE students SET anamnese_completed = 1 WHERE anamnese_completed IS NULL;',
        );
        await customStatement(
          "UPDATE students SET access_tier = 'legacy' WHERE access_tier IS NULL OR access_tier = '';",
        );
        await customStatement(
          "UPDATE personals SET access_tier = 'legacy' WHERE access_tier IS NULL OR access_tier = '';",
        );
      }
      if (from < 23) {
        await m.addColumn(students, students.premiumPlanExpiresAt);
      }
      if (from < 24) {
        await _recomputeWorkoutAndExerciseScoresV24();
      }
      if (from < 25) {
        await m.addColumn(students, students.isArchived);
        await m.addColumn(students, students.archivedAt);
      }
      if (from < 26) {
        await _recomputeWorkoutScoresCompletedExerciseFormulaV26();
      }
      if (from < 27) {
        await m.addColumn(workoutGroups, workoutGroups.deletedAt);
      }
      if (from < 28) {
        await m.addColumn(dayWorkouts, dayWorkouts.revision);
        await m.addColumn(dayWorkouts, dayWorkouts.lastModifiedByDeviceId);
        await m.addColumn(dayWorkouts, dayWorkouts.syncStatus);
        await m.addColumn(dayWorkouts, dayWorkouts.deletedAt);
        await m.addColumn(dayWorkoutExercises, dayWorkoutExercises.revision);
        await m.addColumn(
          dayWorkoutExercises,
          dayWorkoutExercises.lastModifiedByDeviceId,
        );
        await m.addColumn(dayWorkoutExercises, dayWorkoutExercises.syncStatus);
        await m.addColumn(dayWorkoutExercises, dayWorkoutExercises.deletedAt);
        await m.createTable(syncQueue);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS sync_queue_status_next_retry_idx '
          'ON sync_queue(status, next_retry_at, priority, updated_at)',
        );
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS sync_queue_dedupe_key_uidx '
          'ON sync_queue(dedupe_key) WHERE dedupe_key IS NOT NULL',
        );
      }
      if (from < 29) {
        await m.addColumn(workoutGroups, workoutGroups.createdByPersonalId);
        await m.addColumn(workoutGroups, workoutGroups.isShared);
      }
      if (from < 30) {
        await m.addColumn(workoutGroups, workoutGroups.revision);
        await m.addColumn(workoutGroups, workoutGroups.lastModifiedByDeviceId);
        await m.addColumn(auditLogs, auditLogs.deviceId);
        await m.addColumn(auditLogs, auditLogs.personalId);
        await m.addColumn(auditLogs, auditLogs.studentId);
      }
      if (from < 31) {
        await _repairSyncColumnsV31();
      }
      if (from < 32) {
        await _recomputeScoresVolumeFormulaV32();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await _repairSyncColumnsV31();
    },
  );

  /// Alinha datas legadas ao dia civil local (mesma regra do pull Supabase / planejamento).
  Future<void> _normalizeWeekBlocksAndDayWorkoutDatesV19() async {
    final blocks = await select(weekScheduleBlocks).get();
    for (final b in blocks) {
      final fixed = normalizeStoredWeekStartMonday(b.weekStartMonday);
      await (update(weekScheduleBlocks)..where((t) => t.id.equals(b.id))).write(
        WeekScheduleBlocksCompanion(weekStartMonday: Value(fixed)),
      );
    }
    final dws = await select(dayWorkouts).get();
    for (final w in dws) {
      final fixedDay = weekScheduleLocalCalendarDate(w.dayDate);
      await (update(dayWorkouts)..where((t) => t.id.equals(w.id))).write(
        DayWorkoutsCompanion(dayDate: Value(fixedDay)),
      );
    }
  }

  /// Adiciona [updated_at] (epoch segundos, como o Drift grava [DateTime]) sem
  /// DEFAULT dinâmico, incompatível com `ALTER TABLE` no SQLite.
  Future<void> _addUpdatedAtSecondsColumn(String tableName) async {
    await customStatement(
      'ALTER TABLE $tableName ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
    );
    await customStatement(
      "UPDATE $tableName SET updated_at = CAST(strftime('%s', 'now') AS INTEGER)",
    );
  }

  Future<void> _addColumnIfMissing(
    String tableName,
    String columnName,
    String columnSql,
  ) async {
    final info = await customSelect('PRAGMA table_info($tableName)').get();
    final exists = info.any((row) => row.data['name'] == columnName);
    if (exists) return;
    await customStatement('ALTER TABLE $tableName ADD COLUMN $columnSql');
  }

  Future<void> _repairSyncColumnsV31() async {
    await _addColumnIfMissing(
      'workout_groups',
      'created_by_personal_id',
      'created_by_personal_id TEXT NULL REFERENCES personals(id)',
    );
    await _addColumnIfMissing(
      'workout_groups',
      'is_shared',
      'is_shared INTEGER NOT NULL DEFAULT 0 CHECK ("is_shared" IN (0, 1))',
    );
    await _addColumnIfMissing(
      'workout_groups',
      'revision',
      'revision INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      'workout_groups',
      'last_modified_by_device_id',
      'last_modified_by_device_id TEXT NULL',
    );
    await _addColumnIfMissing(
      'audit_logs',
      'device_id',
      'device_id TEXT NULL',
    );
    await _addColumnIfMissing(
      'audit_logs',
      'personal_id',
      'personal_id TEXT NULL REFERENCES personals(id)',
    );
    await _addColumnIfMissing(
      'audit_logs',
      'student_id',
      'student_id TEXT NULL REFERENCES students(id)',
    );
  }

  /// Insere grupos de [kDefaultMuscleGroupNames] se não existir nenhum com o mesmo nome normalizado.
  Future<void> _seedMuscleGroupsFromDefaults() async {
    const uuid = Uuid();
    final existing = await select(muscleGroups).get();
    final norms = existing.map((e) => normalizeMuscleGroupName(e.name)).toSet();
    for (final name in kDefaultMuscleGroupNames) {
      final trimmed = name.trim();
      if (norms.contains(normalizeMuscleGroupName(trimmed))) continue;
      await into(
        muscleGroups,
      ).insert(MuscleGroupsCompanion.insert(id: uuid.v4(), name: trimmed));
      norms.add(normalizeMuscleGroupName(trimmed));
    }
  }

  /// Une grupos com o mesmo nome (ignorando maiúsculas e espaços) e remonta FKs de [exercises].
  Future<void> _dedupeMuscleGroupsByNormalizedName() async {
    await transaction(() async {
      final all = await select(muscleGroups).get();
      final byNorm = <String, List<MuscleGroupEntity>>{};
      for (final g in all) {
        var k = normalizeMuscleGroupName(g.name);
        if (k.isEmpty) k = '\u0000empty';
        byNorm.putIfAbsent(k, () => []).add(g);
      }

      for (final list in byNorm.values) {
        if (list.length == 1) {
          final only = list.single;
          if (only.name.trim().isEmpty) {
            await (update(
              muscleGroups,
            )..where((t) => t.id.equals(only.id))).write(
              MuscleGroupsCompanion(
                name: const Value('Sem nome'),
                updatedAt: Value(DateTime.now()),
              ),
            );
          }
          continue;
        }
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final keeper = list.first;
        final keeperId = keeper.id;
        final emptyName = keeper.name.trim().isEmpty;
        final keeperName = emptyName ? 'Sem nome' : keeper.name.trim();
        if (emptyName) {
          await (update(
            muscleGroups,
          )..where((t) => t.id.equals(keeperId))).write(
            MuscleGroupsCompanion(
              name: Value(keeperName),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
        for (var i = 1; i < list.length; i++) {
          final dup = list[i];
          await (update(exercises)
                ..where((e) => e.muscleGroupId.equals(dup.id)))
              .write(ExercisesCompanion(muscleGroupId: Value(keeperId)));
          await (delete(muscleGroups)..where((t) => t.id.equals(dup.id))).go();
        }
      }
    });
  }

  static Value<String?> _optionalSeedText(String? s) {
    final t = s?.trim();
    if (t == null || t.isEmpty) return const Value(null);
    return Value(t);
  }

  /// Insere ou atualiza exercícios de [kDefaultExerciseSeeds] (vínculo ao grupo por nome).
  /// Na migração v9+, preenche vídeos e alternativa em registros já existentes (mesmo nome).
  Future<void> _seedExercisesFromDefaults() async {
    const uuid = Uuid();
    final now = DateTime.now();
    final muscleRows = await select(muscleGroups).get();
    MuscleGroupEntity? muscleForSeed(String muscleGroupName) {
      final norm = normalizeMuscleGroupName(muscleGroupName);
      for (final g in muscleRows) {
        if (normalizeMuscleGroupName(g.name) == norm) return g;
      }
      return null;
    }

    var exerciseRows = await select(exercises).get();
    ExerciseEntity? exerciseForSeedName(String seedName) {
      final norm = _normExerciseName(seedName);
      for (final e in exerciseRows) {
        if (_normExerciseName(e.name) == norm) return e;
      }
      return null;
    }

    for (final seed in kDefaultExerciseSeeds) {
      final mg = muscleForSeed(seed.muscleGroupName);
      if (mg == null) continue;
      final existing = exerciseForSeedName(seed.name);
      final v = _optionalSeedText(seed.videoUrl);
      final alt = _optionalSeedText(seed.alternativeName);
      final altV = _optionalSeedText(seed.alternativeVideoUrl);
      if (existing == null) {
        final newId = uuid.v4();
        await into(exercises).insert(
          ExercisesCompanion.insert(
            id: newId,
            name: seed.name.trim(),
            muscleGroupId: mg.id,
            videoUrl: v,
            alternativeNote: alt,
            alternativeVideoUrl: altV,
          ),
        );
        final inserted = await (select(
          exercises,
        )..where((t) => t.id.equals(newId))).getSingle();
        exerciseRows = [...exerciseRows, inserted];
      } else {
        await (update(exercises)..where((t) => t.id.equals(existing.id))).write(
          ExercisesCompanion(
            videoUrl: v,
            alternativeNote: alt,
            alternativeVideoUrl: altV,
            updatedAt: Value(now),
          ),
        );
      }
    }
  }

  static String _normExerciseName(String raw) => raw.trim().toLowerCase();

  /// Une exercícios com o mesmo nome normalizado; remonta FKs em templates, planejamento e treinos.
  Future<void> _dedupeExercisesByNormalizedName() async {
    await transaction(() async {
      final all = await select(exercises).get();
      final byNorm = <String, List<ExerciseEntity>>{};
      for (final e in all) {
        var k = _normExerciseName(e.name);
        if (k.isEmpty) k = '\u0000empty';
        byNorm.putIfAbsent(k, () => []).add(e);
      }

      for (final list in byNorm.values) {
        if (list.length == 1) {
          final only = list.single;
          if (only.name.trim().isEmpty) {
            await (update(exercises)..where((t) => t.id.equals(only.id))).write(
              ExercisesCompanion(
                name: const Value('Sem nome'),
                updatedAt: Value(DateTime.now()),
              ),
            );
          }
          continue;
        }
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final keeper = list.first;
        final keeperId = keeper.id;
        if (keeper.name.trim().isEmpty) {
          await (update(exercises)..where((t) => t.id.equals(keeperId))).write(
            ExercisesCompanion(
              name: const Value('Sem nome'),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
        for (var i = 1; i < list.length; i++) {
          final dupId = list[i].id;
          await _repointExerciseReferencesToKeeper(dupId, keeperId);
          await (delete(exercises)..where((t) => t.id.equals(dupId))).go();
        }
      }
    });
  }

  Future<void> _repointExerciseReferencesToKeeper(
    String dupId,
    String keeperId,
  ) async {
    final wges = await (select(
      workoutGroupExercises,
    )..where((w) => w.exerciseId.equals(dupId))).get();
    for (final row in wges) {
      final clash =
          await (select(workoutGroupExercises)..where(
                (w) =>
                    w.workoutGroupId.equals(row.workoutGroupId) &
                    w.exerciseId.equals(keeperId),
              ))
              .getSingleOrNull();
      if (clash != null) {
        await (delete(
          workoutGroupExercises,
        )..where((w) => w.id.equals(row.id))).go();
      } else {
        await (update(workoutGroupExercises)..where((w) => w.id.equals(row.id)))
            .write(WorkoutGroupExercisesCompanion(exerciseId: Value(keeperId)));
      }
    }

    final wis = await (select(
      weekScheduleItems,
    )..where((w) => w.exerciseId.equals(dupId))).get();
    for (final row in wis) {
      final clash =
          await (select(weekScheduleItems)..where(
                (w) =>
                    w.blockId.equals(row.blockId) &
                    w.exerciseId.equals(keeperId),
              ))
              .getSingleOrNull();
      if (clash != null) {
        await (delete(
          weekScheduleItems,
        )..where((w) => w.id.equals(row.id))).go();
      } else {
        await (update(
          weekScheduleItems,
        )..where((w) => w.id.equals(row.id))).write(
          WeekScheduleItemsCompanion(
            exerciseId: Value(keeperId),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    }

    final dwes = await (select(
      dayWorkoutExercises,
    )..where((w) => w.exerciseId.equals(dupId))).get();
    for (final row in dwes) {
      final clash =
          await (select(dayWorkoutExercises)..where(
                (w) =>
                    w.dayWorkoutId.equals(row.dayWorkoutId) &
                    w.exerciseId.equals(keeperId),
              ))
              .getSingleOrNull();
      if (clash != null) {
        await (delete(
          dayWorkoutExercises,
        )..where((w) => w.id.equals(row.id))).go();
      } else {
        await (update(
          dayWorkoutExercises,
        )..where((w) => w.id.equals(row.id))).write(
          DayWorkoutExercisesCompanion(
            exerciseId: Value(keeperId),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    }
  }

  /// Alinha `exercise_id` nas tabelas filhas de [dupId] para [keeperId], com a mesma
  /// regra de choque que a deduplicação local (remove linha duplicada no mesmo bloco/treino).
  Future<void> repointExerciseReferencesToKeeperId(
    String dupId,
    String keeperId,
  ) => _repointExerciseReferencesToKeeper(dupId, keeperId);

  /// Recalcula [day_workouts.workout_score] para treinos **concluídos** com data do dia ≤ hoje
  /// (fórmula legada v16: Σ score de todas as linhas × 10 ÷ min; corrigido em v26).
  Future<void> _backfillCompletedWorkoutScoresV16() async {
    final now = DateTime.now();
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final completed =
        await (select(dayWorkouts)
              ..where((w) => w.status.equals('completed'))
              ..where((w) => w.dayDate.isSmallerThanValue(tomorrow)))
            .get();
    for (final w in completed) {
      final lines = await (select(
        dayWorkoutExercises,
      )..where((e) => e.dayWorkoutId.equals(w.id))).get();
      var sumEx = 0.0;
      for (final line in lines) {
        final performed = DayWorkoutPerformedSetCodec.decode(
          line.performedSetsJson,
        );
        sumEx += performed.isNotEmpty
            ? DayWorkoutPerformedSetCodec.totalExerciseScore(performed)
            : scoring.prescribedExerciseLineScore(
                sets: line.sets,
                loadKg: line.loadKg ?? 0,
                reps: line.reps,
              );
      }
      final sec = w.activeDurationSeconds > 0 ? w.activeDurationSeconds : 1;
      final minutes = sec / 60.0;
      final ws = minutes > 0 ? sumEx * 10.0 / minutes : 0.0;
      await (update(dayWorkouts)..where((x) => x.id.equals(w.id))).write(
        DayWorkoutsCompanion(workoutScore: Value(ws)),
      );
    }
  }

  /// Escala v24: série = carga×reps÷10; `exercise_score` por linha; treino legado = Σ todas ×10 ÷ min (v26 corrige).
  Future<void> _recomputeWorkoutAndExerciseScoresV24() async {
    final allLines = await select(dayWorkoutExercises).get();
    final sumByWorkout = <String, double>{};
    for (final line in allLines) {
      final performed = DayWorkoutPerformedSetCodec.decode(
        line.performedSetsJson,
      );
      final exScore = performed.isNotEmpty
          ? DayWorkoutPerformedSetCodec.totalExerciseScore(performed)
          : scoring.prescribedExerciseLineScore(
              sets: line.sets,
              loadKg: line.loadKg ?? 0,
              reps: line.reps,
            );
      sumByWorkout[line.dayWorkoutId] =
          (sumByWorkout[line.dayWorkoutId] ?? 0) + exScore;
      await (update(dayWorkoutExercises)..where((x) => x.id.equals(line.id)))
          .write(DayWorkoutExercisesCompanion(exerciseScore: Value(exScore)));
    }
    await customStatement(
      "UPDATE day_workouts SET workout_score = NULL WHERE status IS NOT NULL AND status != 'completed'",
    );
    final completed = await (select(
      dayWorkouts,
    )..where((w) => w.status.equals('completed'))).get();
    for (final w in completed) {
      final sumEx = sumByWorkout[w.id] ?? 0;
      final sec = w.activeDurationSeconds > 0 ? w.activeDurationSeconds : 1;
      final minutes = sec / 60.0;
      final ws = minutes > 0 ? sumEx * 10.0 / minutes : 0.0;
      await (update(dayWorkouts)..where((x) => x.id.equals(w.id))).write(
        DayWorkoutsCompanion(workoutScore: Value(ws)),
      );
    }
  }

  /// v26: [workout_score] = (Σ score só linhas concluídas) × 10 ÷ min × nº concluídas.
  Future<void> _recomputeWorkoutScoresCompletedExerciseFormulaV26() async {
    final completed = await (select(
      dayWorkouts,
    )..where((w) => w.status.equals('completed'))).get();
    for (final w in completed) {
      final lines = await (select(
        dayWorkoutExercises,
      )..where((e) => e.dayWorkoutId.equals(w.id))).get();
      var sumDone = 0.0;
      var nDone = 0;
      for (final line in lines) {
        if (line.sets <= 0) continue;
        final performed = DayWorkoutPerformedSetCodec.decode(
          line.performedSetsJson,
        );
        if (performed.length < line.sets) continue;
        nDone++;
        sumDone += performed.isNotEmpty
            ? DayWorkoutPerformedSetCodec.totalExerciseScore(performed)
            : scoring.prescribedExerciseLineScore(
                sets: line.sets,
                loadKg: line.loadKg ?? 0,
                reps: line.reps,
              );
      }
      final sec = w.activeDurationSeconds > 0 ? w.activeDurationSeconds : 1;
      final ws = scoring.workoutFinalScoreFromExerciseScores(
        exerciseScoresSum: sumDone,
        activeDurationSeconds: sec,
        completedExerciseCount: nDone,
      );
      await (update(dayWorkouts)..where((x) => x.id.equals(w.id))).write(
        DayWorkoutsCompanion(workoutScore: Value(ws)),
      );
    }
  }

  /// v32: score exercício = Σ(carga×reps); treino = Σ(concluídos) × nº concluídos.
  Future<void> _recomputeScoresVolumeFormulaV32() async {
    final allLines = await select(dayWorkoutExercises).get();
    final sumByWorkout = <String, double>{};
    for (final line in allLines) {
      final performed = DayWorkoutPerformedSetCodec.decode(
        line.performedSetsJson,
      );
      final exScore = performed.isNotEmpty
          ? DayWorkoutPerformedSetCodec.totalExerciseScore(performed)
          : scoring.prescribedExerciseLineScore(
              sets: line.sets,
              loadKg: line.loadKg ?? 0,
              reps: line.reps,
            );
      sumByWorkout[line.dayWorkoutId] =
          (sumByWorkout[line.dayWorkoutId] ?? 0) + exScore;
      await (update(dayWorkoutExercises)..where((x) => x.id.equals(line.id)))
          .write(DayWorkoutExercisesCompanion(exerciseScore: Value(exScore)));
    }
    await customStatement(
      "UPDATE day_workouts SET workout_score = NULL WHERE status IS NOT NULL AND status != 'completed'",
    );
    final completed = await (select(
      dayWorkouts,
    )..where((w) => w.status.equals('completed'))).get();
    for (final w in completed) {
      final lines = await (select(
        dayWorkoutExercises,
      )..where((e) => e.dayWorkoutId.equals(w.id))).get();
      var sumDone = 0.0;
      var nDone = 0;
      for (final line in lines) {
        if (line.sets <= 0) continue;
        final performed = DayWorkoutPerformedSetCodec.decode(
          line.performedSetsJson,
        );
        if (performed.length < line.sets) continue;
        nDone++;
        sumDone += performed.isNotEmpty
            ? DayWorkoutPerformedSetCodec.totalExerciseScore(performed)
            : scoring.prescribedExerciseLineScore(
                sets: line.sets,
                loadKg: line.loadKg ?? 0,
                reps: line.reps,
              );
      }
      final ws = scoring.workoutFinalScoreFromExerciseScores(
        exerciseScoresSum: sumDone,
        completedExerciseCount: nDone,
      );
      await (update(dayWorkouts)..where((x) => x.id.equals(w.id))).write(
        DayWorkoutsCompanion(workoutScore: Value(ws)),
      );
    }
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'app_personal',
      native: DriftNativeOptions(databaseDirectory: _getDirectory),
    );
  }
}

Future<String> _getDirectory() async {
  if (Platform.isAndroid || Platform.isIOS) {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'drift');
  }
  final dir = await getApplicationSupportDirectory();
  return p.join(dir.path, 'drift');
}
