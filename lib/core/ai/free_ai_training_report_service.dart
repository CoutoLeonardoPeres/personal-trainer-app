class FreeAiTrainingReportService {
  const FreeAiTrainingReportService._();

  /// A geração externa fica desativada até o provedor contratado e o
  /// consentimento correspondente serem configurados na Edge Function.
  static bool get isConfigured => false;

  static Future<String?> enrichReport({
    required String prompt,
    Duration timeout = const Duration(seconds: 18),
  }) async {
    // O relatório local continua disponível como fallback. A Edge Function
    // receberá apenas métricas agregadas quando consentimento e provedor
    // contratado forem habilitados, evitando qualquer envio direto de texto.
    return null;
  }
}
