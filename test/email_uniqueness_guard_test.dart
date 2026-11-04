import 'package:app_personal/core/auth/email_uniqueness_guard.dart';
import 'package:app_personal/data/local/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertPersonal({
    required String id,
    required String email,
  }) async {
    await db.into(db.personals).insert(
          PersonalsCompanion.insert(
            id: id,
            name: 'Personal $id',
            cpf: '12345678901',
            professionalRegistry: 'CREF',
            street: 'Rua A',
            number: '1',
            city: 'SP',
            stateUf: 'SP',
            email: email,
          ),
        );
  }

  Future<void> insertStudent({
    required String id,
    required String email,
    bool archived = false,
  }) async {
    await db.into(db.students).insert(
          StudentsCompanion.insert(
            id: id,
            name: 'Aluno $id',
            email: Value(email),
            isArchived: Value(archived),
          ),
        );
  }

  group('EmailUniquenessGuard', () {
    test('normaliza e-mail com trim e lowercase', () {
      expect(
        EmailUniquenessGuard.normalize('  User@Mail.COM  '),
        'user@mail.com',
      );
    });

    test('rejeita e-mail duplicado em personals', () async {
      await insertPersonal(id: 'p1', email: 'coach@test.com');
      expect(
        () => EmailUniquenessGuard.assertLoginEmailAvailable(
          db,
          email: 'Coach@Test.com',
          excludePersonalId: 'p2',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejeita e-mail duplicado em students ativos', () async {
      await insertStudent(id: 's1', email: 'aluno@test.com');
      expect(
        () => EmailUniquenessGuard.assertLoginEmailAvailable(
          db,
          email: 'ALUNO@test.com',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('permite mesmo e-mail se student está arquivado', () async {
      await insertStudent(id: 's1', email: 'reuse@test.com', archived: true);
      await expectLater(
        EmailUniquenessGuard.assertLoginEmailAvailable(
          db,
          email: 'reuse@test.com',
        ),
        completes,
      );
    });

    test('rejeita colisão personal ↔ aluno', () async {
      await insertPersonal(id: 'p1', email: 'shared@test.com');
      expect(
        () => EmailUniquenessGuard.assertLoginEmailAvailable(
          db,
          email: 'shared@test.com',
          excludePersonalId: 'p2',
        ),
        throwsA(isA<ArgumentError>()),
      );

      await db.delete(db.personals).go();
      await insertStudent(id: 's1', email: 'other@test.com');
      expect(
        () => EmailUniquenessGuard.assertLoginEmailAvailable(
          db,
          email: 'other@test.com',
          excludeStudentId: 's2',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('findProfileKindForEmail identifica perfil existente', () async {
      await insertPersonal(id: 'p1', email: 'p@test.com');
      expect(
        await EmailUniquenessGuard.findProfileKindForEmail(db, 'p@test.com'),
        'personal',
      );

      await db.delete(db.personals).go();
      await insertStudent(id: 's1', email: 's@test.com');
      expect(
        await EmailUniquenessGuard.findProfileKindForEmail(db, 's@test.com'),
        'student',
      );
    });

    test('permite atualizar perfil mantendo o próprio e-mail', () async {
      await insertPersonal(id: 'p1', email: 'me@test.com');
      await expectLater(
        EmailUniquenessGuard.assertLoginEmailAvailable(
          db,
          email: 'me@test.com',
          excludePersonalId: 'p1',
        ),
        completes,
      );
    });
  });
}
