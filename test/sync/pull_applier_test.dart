import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_personal/data/local/app_database.dart';
import 'package:app_personal/data/sync/pull_applier.dart';

void main() {
  late AppDatabase db;
  late PullApplier applier;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    applier = PullApplier(db);
  });

  tearDown(() => db.close());

  test('reaplicar snapshot mantém uma única linha e traduz status', () async {
    await applier.apply({
      'entity': 'students',
      'payload': {
        'id': '00000000-0000-0000-0000-000000000001',
        'name': 'Aluno',
        'is_archived': false,
        'must_change_password': true,
        'anamnese_completed': true,
        'access_tier': 'legacy',
        'created_at': '2026-11-05T10:00:00Z',
        'updated_at': '2026-11-05T10:00:00Z',
      },
    });
    await applier.apply({
      'entity': 'students',
      'payload': {
        'id': '00000000-0000-0000-0000-000000000001',
        'name': 'Aluno atualizado',
        'is_archived': false,
        'must_change_password': true,
        'anamnese_completed': true,
        'access_tier': 'legacy',
        'created_at': '2026-11-05T10:00:00Z',
        'updated_at': '2026-11-05T10:01:00Z',
      },
    });

    final rows = await db.select(db.students).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Aluno atualizado');
  });

  test('traduz status do backend para o modelo legado local', () async {
    await db
        .into(db.students)
        .insert(
          StudentsCompanion.insert(
            id: '00000000-0000-0000-0000-000000000001',
            name: 'Aluno',
          ),
        );
    await applier.apply({
      'entity': 'day_workouts',
      'payload': {
        'id': '00000000-0000-0000-0000-000000000010',
        'student_id': '00000000-0000-0000-0000-000000000001',
        'day_date': '2026-11-05T10:00:00Z',
        'status': 'concluido',
        'active_duration_seconds': 0,
        'created_at': '2026-11-05T10:00:00Z',
        'updated_at': '2026-11-05T10:00:00Z',
      },
    });

    final workout = await db.select(db.dayWorkouts).getSingle();
    expect(workout.status, 'completed');
  });
}
