# Dependências planejadas

Nenhuma dependência desta lista é adicionada na Fase 0. As versões ficam
fixadas para análise de compatibilidade e instalação apenas na fase que as usa.

| Pacote | Versão planejada | Motivo |
|---|---:|---|
| `uuid` | `4.6.0` | IDs UUID v7 ordenáveis para entidades e fila offline |
| `sqlcipher_flutter_libs` | `0.7.0+eol` | Biblioteca solicitada para SQLite criptografado; está encerrada e exige validação/substituição antes da adoção |
| `flutter_secure_storage` | `11.2.0` | Armazenar material de chave fora do banco local |
| `connectivity_plus` | `7.3.2` | Sinal de conectividade para disparar sincronização, sem assumir acesso real à internet |
| `workmanager` | `0.10.10` | Sincronização oportunista em segundo plano no Android/iOS |
| `package_info_plus` | `10.2.2` | Versão do app em diagnóstico, telemetria e compatibilidade de sync |
| `sentry_flutter` | `9.30.1` | Observabilidade compatível com Flutter 3.38; a série 10 exige Flutter mais novo |

Antes de instalar, cada pacote deve passar por revisão de licença, manutenção,
plataformas suportadas, impacto no binário e duplicidade com as dependências
atuais. O `sqlcipher_flutter_libs` não deve entrar em produção enquanto o risco
de fim de vida não tiver uma decisão explícita.
