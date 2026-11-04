import 'package:app_personal/data/models/day_workout_performed_set.dart';
import 'package:app_personal/data/sync/conflict_resolver.dart';
import 'package:app_personal/data/sync/performed_sets_merge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConflictResolver', () {
    test('detecta escrita stale', () {
      expect(
        ConflictResolver.isStaleWrite(
          expectedRevision: 3,
          serverRevision: 5,
        ),
        isTrue,
      );
      expect(
        ConflictResolver.isStaleWrite(
          expectedRevision: 5,
          serverRevision: 5,
        ),
        isFalse,
      );
    });

    test('remote vence quando revision maior', () {
      expect(
        ConflictResolver.remoteWins(localRevision: 2, remoteRevision: 4),
        isTrue,
      );
      expect(
        ConflictResolver.remoteWins(localRevision: 4, remoteRevision: 4),
        isFalse,
      );
    });

    test('empate de revision favorece remoto', () {
      expect(
        ConflictResolver.acceptRemoteOnRevisionTie(
          localRevision: 7,
          remoteRevision: 7,
        ),
        isTrue,
      );
    });
  });

  group('PerformedSetsMerge', () {
    test('união por setId preserva séries de dois dispositivos', () {
      final a = [
        const DayWorkoutPerformedSet(
          setId: 'a1',
          loadKg: 20,
          reps: 10,
          loggedAtMs: 1000,
        ),
      ];
      final b = [
        const DayWorkoutPerformedSet(
          setId: 'b1',
          loadKg: 22,
          reps: 8,
          loggedAtMs: 2000,
        ),
      ];
      final merged = PerformedSetsMerge.unionBySetId(a, b);
      expect(merged.length, 2);
      expect(merged.map((s) => s.setId).toSet(), {'a1', 'b1'});
    });

    test('normaliza legado sem setId', () {
      final legacy = [
        const DayWorkoutPerformedSet(loadKg: 10, reps: 12, loggedAtMs: 500),
      ];
      final norm = PerformedSetsMerge.normalizeLegacySets(legacy, lineId: 'L');
      expect(norm.first.setId, 'L:set:0');
    });

    test('mesmo setId não duplica', () {
      const s = DayWorkoutPerformedSet(
        setId: 'x',
        loadKg: 30,
        reps: 6,
        loggedAtMs: 1,
      );
      final merged = PerformedSetsMerge.unionBySetId([s], [s]);
      expect(merged.length, 1);
    });
  });
}
