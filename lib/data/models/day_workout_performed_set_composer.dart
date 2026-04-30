import 'day_workout_performed_set.dart';

typedef WorkoutSetEventRow = ({
  String eventId,
  int reps,
  double? loadKg,
  int loggedAtMs,
  int createdAtMs,
});

typedef WorkoutRestEventRow = ({
  String restEventId,
  String setEventId,
  int? restPrescribedSec,
  int? restCountdownElapsedMs,
  int? postRestModalMs,
  int recordedAtMs,
  int createdAtMs,
});

typedef WorkoutTombstoneRow = ({String tombstoneId, String eventId, int deletedAtMs});

abstract final class DayWorkoutPerformedSetComposer {
  static List<DayWorkoutPerformedSet> compose({
    String? legacyJsonRaw,
    required List<WorkoutSetEventRow> setEvents,
    required List<WorkoutRestEventRow> restEvents,
    required List<WorkoutTombstoneRow> tombstones,
  }) {
    final tombed = tombstones.map((t) => t.eventId).toSet();
    final restBySet = <String, WorkoutRestEventRow>{};
    for (final rest in restEvents) {
      final prev = restBySet[rest.setEventId];
      if (prev == null ||
          rest.recordedAtMs > prev.recordedAtMs ||
          (rest.recordedAtMs == prev.recordedAtMs &&
              rest.createdAtMs >= prev.createdAtMs)) {
        restBySet[rest.setEventId] = rest;
      }
    }
    final ordered = [...setEvents]
      ..sort((a, b) {
        final byLogged = a.loggedAtMs.compareTo(b.loggedAtMs);
        if (byLogged != 0) return byLogged;
        final byCreated = a.createdAtMs.compareTo(b.createdAtMs);
        if (byCreated != 0) return byCreated;
        return a.eventId.compareTo(b.eventId);
      });
    final out = <DayWorkoutPerformedSet>[];
    for (final set in ordered) {
      if (tombed.contains(set.eventId)) continue;
      final rest = restBySet[set.eventId];
      out.add(
        DayWorkoutPerformedSet(
          loadKg: set.loadKg,
          reps: set.reps,
          loggedAtMs: set.loggedAtMs,
          restPrescribedSec: rest?.restPrescribedSec,
          restCountdownElapsedMs: rest?.restCountdownElapsedMs,
          postRestModalMs: rest?.postRestModalMs,
        ),
      );
    }
    if (out.isNotEmpty) return out;
    return DayWorkoutPerformedSetCodec.decode(legacyJsonRaw);
  }
}
