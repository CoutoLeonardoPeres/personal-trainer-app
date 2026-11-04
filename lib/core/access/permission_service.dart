import '../auth/app_session.dart';
import '../../data/local/app_database.dart';
import 'access_tiers.dart';

/// RBAC derivado de [AppSession] + entidades locais (sem duplicar regras na UI).
class PermissionService {
  const PermissionService({
    required this.session,
    this.student,
    this.personal,
  });

  final AppSession session;
  final StudentEntity? student;
  final PersonalEntity? personal;

  bool get _studentLegacy {
    final tier =
        session.authoritativeStudentAccessTier ?? student?.accessTier;
    return student == null || tier == AccessTiers.legacy;
  }

  bool get _personalLegacy {
    final tier =
        session.authoritativePersonalAccessTier ?? personal?.accessTier;
    return personal == null || tier == AccessTiers.legacy;
  }

  /// Só administrador (personal com flag) pode gerir perfis comerciais / permissões finas.
  bool get canManageAccessProfiles =>
      session.hasFullOrgAccess && (personal?.isAdmin ?? true);

  /// Anamnese obrigatória: perfis de aluno não legados com flag pendente.
  bool get mustBlockAppForAnamnese =>
      session.isStudent &&
      student != null &&
      !_studentLegacy &&
      !_anamneseCompletedForSession;

  bool get _anamneseCompletedForSession {
    if (session.serverProfile?.isStudent == true) {
      return session.authoritativeAnamneseCompleted;
    }
    return student?.anamneseCompleted ?? true;
  }

  /// Esconder selector de aluno na sessão (auto: próprio id).
  bool get hideStudentSessionPicker =>
      session.isStudent && student != null && !_studentLegacy;

  bool get canOpenPerformanceTab {
    if (!session.isStudent) return true;
    if (_studentLegacy) return true;
    final t = session.authoritativeStudentAccessTier ?? student!.accessTier;
    if (t == AccessTiers.studentFree) return false;
    return t == AccessTiers.studentBasic ||
        t == AccessTiers.studentPremium ||
        t == AccessTiers.studentStandard;
  }

  bool get canOpenPlanningTab {
    if (!session.isStudent) return true;
    if (_studentLegacy) return true;
    final t = session.authoritativeStudentAccessTier ?? student!.accessTier;
    if (t == AccessTiers.studentFree) return false;
    return t == AccessTiers.studentBasic ||
        t == AccessTiers.studentPremium ||
        t == AccessTiers.studentStandard;
  }

  bool get canOpenCadastroTab {
    if (!session.isStudent) return true;
    if (_studentLegacy) return false;
    final t = session.authoritativeStudentAccessTier ?? student!.accessTier;
    return t == AccessTiers.studentBasic ||
        t == AccessTiers.studentPremium ||
        t == AccessTiers.studentStandard;
  }

  bool get canSeeCadastroAlunosPersonais {
    if (session.isStudent) return false;
    return true;
  }

  bool get canSeeCadastroMetodosTreino {
    if (session.isStudent) return false;
    if (!_personalLegacy && personal != null) {
      final t = session.authoritativePersonalAccessTier ?? personal!.accessTier;
      if (t == AccessTiers.personalStarter ||
          t == AccessTiers.personalPro ||
          t == AccessTiers.personalProPlus) {
        return true;
      }
    }
    return _personalLegacy || session.hasFullOrgAccess;
  }

  bool get canSyncSupabaseExerciseCatalog {
    if (session.isStudent) {
      if (_studentLegacy) return true;
      final t = session.authoritativeStudentAccessTier ?? student!.accessTier;
      return t == AccessTiers.studentPremium;
    }
    if (session.isPersonalTrainer || session.isAdminPersonal) {
      if (_personalLegacy || session.hasFullOrgAccess) return true;
      final t = session.authoritativePersonalAccessTier ?? personal?.accessTier;
      return t == AccessTiers.personalProPlus;
    }
    return true;
  }

  bool get canUseAiTrainingReports {
    if (session.isStudent) {
      if (_studentLegacy) return true;
      final t = session.authoritativeStudentAccessTier ?? student!.accessTier;
      return t == AccessTiers.studentPremium;
    }
    if (personal != null && !_personalLegacy) {
      final t = session.authoritativePersonalAccessTier ?? personal!.accessTier;
      return t == AccessTiers.personalProPlus;
    }
    return session.hasFullOrgAccess;
  }

  /// Itens de cadastro para aluno basic/premium/standard (sem alunos/personais).
  bool get studentCadastroMuscleExerciseGymGroup {
    if (!session.isStudent || student == null) return false;
    if (_studentLegacy) return false;
    final t = session.authoritativeStudentAccessTier ?? student!.accessTier;
    return t == AccessTiers.studentBasic ||
        t == AccessTiers.studentPremium ||
        t == AccessTiers.studentStandard;
  }

  int? get personalMaxStudents {
    if (personal == null || _personalLegacy) return null;
    final cap =
        session.authoritativePersonalMaxStudentsCap ?? personal!.maxStudentsCap;
    if (cap != null) return cap;
    final t = session.authoritativePersonalAccessTier ?? personal!.accessTier;
    return switch (t) {
      AccessTiers.personalStarter => 3,
      AccessTiers.personalPro => 10,
      AccessTiers.personalProPlus => null,
      _ => null,
    };
  }
}
