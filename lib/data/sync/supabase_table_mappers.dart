import '../local/app_database.dart';
import '../models/day_workout_performed_set.dart';

String supabaseTs(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> supabaseMuscleGroup(MuscleGroupEntity e) => {
  'id': e.id,
  'name': e.name,
  'created_at': supabaseTs(e.createdAt),
  'updated_at': supabaseTs(e.updatedAt),
};

Map<String, dynamic> supabaseExercise(ExerciseEntity e) => {
  'id': e.id,
  'name': e.name,
  'muscle_group_id': e.muscleGroupId,
  'video_url': e.videoUrl,
  'alternative_note': e.alternativeNote,
  'alternative_video_url': e.alternativeVideoUrl,
  'created_at': supabaseTs(e.createdAt),
  'updated_at': supabaseTs(e.updatedAt),
};

Map<String, dynamic> supabaseGym(GymEntity e) => {
  'id': e.id,
  'name': e.name,
  'cnpj': e.cnpj,
  'street': e.street,
  'number': e.number,
  'complement': e.complement,
  'district': e.district,
  'city': e.city,
  'state_uf': e.stateUf,
  'cep': e.cep,
  'created_at': supabaseTs(e.createdAt),
  'updated_at': supabaseTs(e.updatedAt),
};

Map<String, dynamic> supabasePersonal(PersonalEntity e) => {
  'id': e.id,
  'name': e.name,
  'cpf': e.cpf,
  'professional_registry': e.professionalRegistry,
  'street': e.street,
  'number': e.number,
  'complement': e.complement,
  'city': e.city,
  'state_uf': e.stateUf,
  'cep': e.cep,
  'email': e.email,
  'phone_commercial': e.phoneCommercial,
  'phone_mobile': e.phoneMobile,
  'must_change_password': e.mustChangePassword,
  'password_hash': e.passwordHash,
  'is_admin': e.isAdmin,
  'access_tier': e.accessTier,
  'max_students_cap': e.maxStudentsCap,
  'created_at': supabaseTs(e.createdAt),
  'updated_at': supabaseTs(e.updatedAt),
};

Map<String, dynamic> supabaseStudent(StudentEntity e) => {
  'id': e.id,
  'name': e.name,
  'is_archived': e.isArchived,
  'archived_at': e.archivedAt != null ? supabaseTs(e.archivedAt!) : null,
  'email': e.email,
  'goal': e.goal,
  'cpf': e.cpf,
  'birth_date': e.birthDate != null ? supabaseTs(e.birthDate!) : null,
  'street': e.street,
  'number': e.number,
  'complement': e.complement,
  'district': e.district,
  'city': e.city,
  'state_uf': e.stateUf,
  'cep': e.cep,
  'phone_commercial': e.phoneCommercial,
  'phone_mobile': e.phoneMobile,
  'must_change_password': e.mustChangePassword,
  'password_hash': e.passwordHash,
  'created_by_personal_id': e.createdByPersonalId,
  'anamnese_completed': e.anamneseCompleted,
  'access_tier': e.accessTier,
  'premium_plan_expires_at': e.premiumPlanExpiresAt != null
      ? supabaseTs(e.premiumPlanExpiresAt!)
      : null,
  'created_at': supabaseTs(e.createdAt),
  'updated_at': supabaseTs(e.updatedAt),
};

Map<String, dynamic> supabaseStudentGym(StudentGymEntity e) => {
  'student_id': e.studentId,
  'gym_id': e.gymId,
};

Map<String, dynamic> supabaseTrainingMethod(TrainingMethodEntity e) => {
  'id': e.id,
  'method': e.method,
  'description': e.description,
  'created_at': supabaseTs(e.createdAt),
  'updated_at': supabaseTs(e.updatedAt),
};

Map<String, dynamic> supabaseWorkoutGroup(WorkoutGroupEntity e) => {
  'id': e.id,
  'name': e.name,
  'description': e.description,
  'created_by_personal_id': e.createdByPersonalId,
  'is_shared': e.isShared,
  'revision': e.revision,
  'last_modified_by_device_id': e.lastModifiedByDeviceId,
  'created_at': supabaseTs(e.createdAt),
  'updated_at': supabaseTs(e.updatedAt),
  'deleted_at': e.deletedAt != null ? supabaseTs(e.deletedAt!) : null,
};

Map<String, dynamic> supabaseWorkoutGroupExercise(
  WorkoutGroupExerciseEntity e,
) => {
  'id': e.id,
  'workout_group_id': e.workoutGroupId,
  'exercise_id': e.exerciseId,
  'sort_order': e.sortOrder,
  'last_load_kg': e.lastLoadKg,
  'last_reps': e.lastReps,
  'last_reps_text': e.lastRepsText,
  'last_sets': e.lastSets,
  'rest_between_sets_sec': e.restBetweenSetsSec,
  'training_method_id': e.trainingMethodId,
  'combo_id': e.comboId,
  'updated_at': supabaseTs(e.updatedAt),
};

Map<String, dynamic> supabaseWeekBlock(WeekScheduleBlockEntity e) => {
  'id': e.id,
  'student_id': e.studentId,
  'week_start_monday': supabaseTs(e.weekStartMonday),
  'created_at': supabaseTs(e.createdAt),
  'updated_at': supabaseTs(e.updatedAt),
};

Map<String, dynamic> supabaseWeekItem(WeekScheduleItemEntity e) => {
  'id': e.id,
  'block_id': e.blockId,
  'exercise_id': e.exerciseId,
  'source_workout_group_id': e.sourceWorkoutGroupId,
  'sort_order': e.sortOrder,
  'sets': e.sets,
  'reps': e.reps,
  'reps_text': e.repsText,
  'load_kg': e.loadKg,
  'needs_detail': e.needsDetail,
  'rest_between_sets_sec': e.restBetweenSetsSec,
  'training_method_id': e.trainingMethodId,
  'combo_id': e.comboId,
  'updated_at': supabaseTs(e.updatedAt),
};

Map<String, dynamic> supabaseDayWorkout(DayWorkoutEntity e) => {
  'id': e.id,
  'student_id': e.studentId,
  'day_date': supabaseTs(e.dayDate),
  'status': e.status,
  'week_item_id': e.weekItemId,
  'active_duration_seconds': e.activeDurationSeconds,
  'workout_score': e.workoutScore,
  'started_at': e.startedAt != null ? supabaseTs(e.startedAt!) : null,
  'completed_at': e.completedAt != null ? supabaseTs(e.completedAt!) : null,
  'timer_resume_at': e.timerResumeAt != null
      ? supabaseTs(e.timerResumeAt!)
      : null,
  'created_at': supabaseTs(e.createdAt),
  'updated_at': supabaseTs(e.updatedAt),
  'source_workout_group_id': e.sourceWorkoutGroupId,
  'watch_calories_kcal': e.watchCaloriesKcal,
  'watch_avg_heart_rate_bpm': e.watchAvgHeartRateBpm,
  'revision': e.revision,
  'last_modified_by_device_id': e.lastModifiedByDeviceId,
  'sync_status': e.syncStatus,
  'deleted_at': e.deletedAt != null ? supabaseTs(e.deletedAt!) : null,
};

Map<String, dynamic> supabaseDayWorkoutExercise(DayWorkoutExerciseEntity e) {
  final performed = DayWorkoutPerformedSetCodec.decode(e.performedSetsJson);
  final score = performed.isNotEmpty
      ? DayWorkoutPerformedSetCodec.totalExerciseScore(performed)
      : e.exerciseScore;
  return {
  'id': e.id,
  'day_workout_id': e.dayWorkoutId,
  'exercise_id': e.exerciseId,
  'sort_order': e.sortOrder,
  'sets': e.sets,
  'reps': e.reps,
  'reps_text': e.repsText,
  'load_kg': e.loadKg,
  'exercise_score': score,
  'performed_sets_json': e.performedSetsJson,
  'rest_between_sets_sec': e.restBetweenSetsSec,
  'training_method_id': e.trainingMethodId,
  'combo_id': e.comboId,
  'updated_at': supabaseTs(e.updatedAt),
  'revision': e.revision,
  'last_modified_by_device_id': e.lastModifiedByDeviceId,
  'sync_status': e.syncStatus,
  'deleted_at': e.deletedAt != null ? supabaseTs(e.deletedAt!) : null,
};
}

Map<String, dynamic> supabaseAuditLog(AuditLogEntity e) => {
  'id': e.id,
  'at': supabaseTs(e.at),
  'action': e.action,
  'entity_type': e.entityType,
  'entity_id': e.entityId,
  'payload_json': e.payloadJson,
  'device_id': e.deviceId,
  'personal_id': e.personalId,
  'student_id': e.studentId,
};
