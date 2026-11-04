import 'package:app_personal/core/auth/app_session.dart';
import 'package:app_personal/core/auth/server_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppSession server profile RBAC', () {
    test(
      'hasFullOrgAccess usa isAdmin do servidor para personal comum',
      () async {
        final session = AppSession();
        await session.setSession(
          role: SessionRole.personalTrainer,
          personalId: 'p1',
        );
        session.applyServerProfile(
          const ServerProfileSnapshot(
            profileKind: 'personal',
            profileId: 'p1',
            isAdmin: true,
            accessTier: 'legacy',
          ),
        );

        expect(session.hasFullOrgAccess, isTrue);
      },
    );

    test(
      'personal comum sem flag admin no servidor não tem acesso total',
      () async {
        final session = AppSession();
        await session.setSession(
          role: SessionRole.personalTrainer,
          personalId: 'p1',
        );
        session.applyServerProfile(
          const ServerProfileSnapshot(
            profileKind: 'personal',
            profileId: 'p1',
            isAdmin: false,
            accessTier: 'legacy',
          ),
        );

        expect(session.hasFullOrgAccess, isFalse);
      },
    );

    test(
      'authoritativeStudentAccessTier vem do servidor quando aluno',
      () async {
        final session = AppSession();
        await session.setSession(role: SessionRole.student, studentId: 's1');
        session.applyServerProfile(
          const ServerProfileSnapshot(
            profileKind: 'student',
            profileId: 's1',
            isAdmin: false,
            accessTier: 'student_premium',
            anamneseCompleted: false,
          ),
        );

        expect(session.authoritativeStudentAccessTier, 'student_premium');
        expect(session.authoritativeAnamneseCompleted, isFalse);
      },
    );

    test(
      'adminPersonal explícito mantém hasFullOrgAccess sem server profile',
      () async {
        final session = AppSession();
        await session.setSession(
          role: SessionRole.adminPersonal,
          personalId: 'admin',
        );
        session.clearServerProfile();

        expect(session.hasFullOrgAccess, isTrue);
      },
    );
  });
}
