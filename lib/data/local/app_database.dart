import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

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
  TextColumn get email => text()();
  BoolColumn get mustChangePassword =>
      boolean().withDefault(const Constant(true))();
  TextColumn get passwordHash => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('StudentEntity')
class Students extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
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
  /// Quando true, o app exige troca de senha no próximo acesso.
  BoolColumn get mustChangePassword =>
      boolean().withDefault(const Constant(true))();
  TextColumn get passwordHash => text().nullable()();
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
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

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
  IntColumn get lastReps => integer().nullable()();
  IntColumn get lastSets => integer().nullable()();

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
  RealColumn get loadKg => real().nullable()();
  BoolColumn get needsDetail =>
      boolean().withDefault(const Constant(false))();

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
  IntColumn get activeDurationSeconds => integer().withDefault(const Constant(0))();
  RealColumn get workoutScore => real().nullable()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  /// Quando não nulo, o cronômetro está correndo desde este instante (tempo ativo acumulado em [activeDurationSeconds]).
  DateTimeColumn get timerResumeAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  /// Quando veio de um grupo ao programar no calendário — exibe o nome do grupo na folha.
  TextColumn get sourceWorkoutGroupId => text().nullable()();

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
  RealColumn get loadKg => real().nullable()();
  RealColumn get exerciseScore => real().nullable()();
  /// JSON: lista `[{ "loadKg": 20.0, "reps": 15 }, ...]` — séries executadas (modal Adicionar série).
  TextColumn get performedSetsJson => text().nullable()();

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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 5;

  /// Migrações **incrementais** apenas (`addColumn`, `create`, etc.).
  /// Nunca usar recriação destrutiva do banco: os dados do usuário devem persistir
  /// após atualizações do app. Ao subir [schemaVersion], acrescente blocos `if (from < N)`.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
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
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'app_personal',
      native: DriftNativeOptions(
        databaseDirectory: _getDirectory,
      ),
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
