import '../local/app_database.dart';

/// Aplica uma mudança completa do servidor de forma idempotente.
///
/// A chave primária do Drift é a barreira contra duplicação: repetir a mesma
/// página ou o mesmo evento atualiza a linha existente em vez de criar outra.
class PullApplier {
  PullApplier(this._db);

  final AppDatabase _db;

  Future<void> apply(Map<String, dynamic> change) async {
    final entity = change['entity'] as String?;
    final raw = change['payload'];
    if (entity == null || raw is! Map) return;
    final payload = _normalisePayload(
      entity,
      Map<String, dynamic>.from(raw),
    );

    await _db.transaction(() async {
      switch (entity) {
        case 'muscle_groups':
          await _db
              .into(_db.muscleGroups)
              .insertOnConflictUpdate(
                MuscleGroupEntity.fromJson(payload).toCompanion(false),
              );
        case 'exercises':
          await _db
              .into(_db.exercises)
              .insertOnConflictUpdate(
                ExerciseEntity.fromJson(payload).toCompanion(false),
              );
        case 'gyms':
          await _db
              .into(_db.gyms)
              .insertOnConflictUpdate(
                GymEntity.fromJson(payload).toCompanion(false),
              );
        case 'personals':
          await _db
              .into(_db.personals)
              .insertOnConflictUpdate(
                PersonalEntity.fromJson(payload).toCompanion(false),
              );
        case 'students':
          await _db
              .into(_db.students)
              .insertOnConflictUpdate(
                StudentEntity.fromJson(payload).toCompanion(false),
              );
        case 'student_gyms':
          await _db
              .into(_db.studentGyms)
              .insertOnConflictUpdate(
                StudentGymEntity.fromJson(payload).toCompanion(false),
              );
        case 'training_methods':
          await _db
              .into(_db.trainingMethods)
              .insertOnConflictUpdate(
                TrainingMethodEntity.fromJson(payload).toCompanion(false),
              );
        case 'workout_groups':
          await _db
              .into(_db.workoutGroups)
              .insertOnConflictUpdate(
                WorkoutGroupEntity.fromJson(payload).toCompanion(false),
              );
        case 'workout_group_exercises':
          await _db
              .into(_db.workoutGroupExercises)
              .insertOnConflictUpdate(
                WorkoutGroupExerciseEntity.fromJson(payload).toCompanion(false),
              );
        case 'week_schedule_blocks':
          await _db
              .into(_db.weekScheduleBlocks)
              .insertOnConflictUpdate(
                WeekScheduleBlockEntity.fromJson(payload).toCompanion(false),
              );
        case 'week_schedule_items':
          await _db
              .into(_db.weekScheduleItems)
              .insertOnConflictUpdate(
                WeekScheduleItemEntity.fromJson(payload).toCompanion(false),
              );
        case 'day_workouts':
          await _db
              .into(_db.dayWorkouts)
              .insertOnConflictUpdate(
                DayWorkoutEntity.fromJson(payload).toCompanion(false),
              );
        case 'day_workout_exercises':
          await _db
              .into(_db.dayWorkoutExercises)
              .insertOnConflictUpdate(
                DayWorkoutExerciseEntity.fromJson(payload).toCompanion(false),
              );
        case 'performed_set_events':
          await _applyPerformedSet(payload);
        case 'workout_timer_events':
          // A tabela local de timer será adicionada na fase de eventos. Não
          // descartar a mudança silenciosamente quando o modelo ainda não a tem.
          return;
      }
    });
  }

  Future<void> _applyPerformedSet(Map<String, dynamic> payload) async {
    if (payload['kind'] != null && payload['kind'] != 'logged') return;
    final id = payload['id'] as String?;
    final lineId = payload['dayWorkoutExerciseId'] as String?;
    final reps = payload['reps'];
    if (id == null || lineId == null || reps == null) return;
    await _db
        .into(_db.performedSetEvents)
        .insertOnConflictUpdate(
          PerformedSetEventEntity(
            id: id,
            lineId: lineId,
            loadKg: (payload['loadKg'] as num?)?.toDouble(),
            reps: (reps as num).toInt(),
            loggedAtMs: null,
            restPrescribedSec: null,
            restCountdownElapsedMs: null,
            postRestModalMs: null,
            deviceId: payload['originDevice'] as String?,
            synced: true,
            createdAt: _date(payload['createdAt']),
          ),
        );
  }

  static Map<String, dynamic> _normalisePayload(
    String entity,
    Map<String, dynamic> source,
  ) {
    final out = <String, dynamic>{};
    for (final entry in source.entries) {
      final key = _snakeToCamel(entry.key);
      out[key] = entry.value;
    }
    final status = out['status'];
    if (status is String) {
      out['status'] = switch (status) {
        'programado' => 'programmed',
        'em_andamento' => 'started',
        'concluido' => 'completed',
        'cancelado' => 'cancelled',
        _ => status,
      };
    }
    if (entity == 'day_workouts') {
      out['activeDurationSeconds'] ??= 0;
      out['createdAt'] ??= DateTime.now().toUtc().toIso8601String();
      out['updatedAt'] ??= out['createdAt'];
      out['revision'] ??= 0;
      out['syncStatus'] ??= 'synced';
    }
    return out;
  }

  static String _snakeToCamel(String value) {
    return value.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (match) => match.group(1)!.toUpperCase(),
    );
  }

  static DateTime _date(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value).toLocal();
    return DateTime.now();
  }
}
