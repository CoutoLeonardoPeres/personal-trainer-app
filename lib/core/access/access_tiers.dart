/// Identificadores persistidos em SQLite / Supabase (`access_tier`).
abstract final class AccessTiers {
  static const legacy = 'legacy';

  static const studentFree = 'aluno_free';
  static const studentBasic = 'aluno_basic';
  static const studentPremium = 'aluno_premium';
  static const studentStandard = 'aluno_standard';

  static const personalStarter = 'personal_starter';
  static const personalPro = 'personal_pro';
  static const personalProPlus = 'personal_pro_plus';
}
