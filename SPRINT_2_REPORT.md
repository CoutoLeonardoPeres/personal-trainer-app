# Sprint 2 — Relatório de Segurança

> Documento histórico. Os SQL citados estão desativados e não devem ser
> executados; novas mudanças usam `supabase/migrations/`.

**Projeto:** App Personal (Flutter + Drift + Supabase)
**Data:** 2026-07-09
**Escopo:** reset seguro, RBAC server-side, unicidade de e-mail, RLS reforçado e testes de segurança (sem Sprint 3)

---

## 1. Auditoria inicial (pós-Sprint 1)

### Achados remanescentes

| # | Achado | Severidade | Evidência |
|---|--------|------------|-----------|
| B1 | App ainda **gerava senha provisória** no Flutter | Crítico | `_generateTempPassword`, `_generateProvisionalLocalPassword`, `provisionAuthUser` |
| B2 | Senhas provisórias exibidas em dialogs de cadastro | Crítico | `alunos_page.dart`, `personais_page.dart` |
| B3 | Webhook legado com `new_password` em JSON | Alto | `password_reset_webhook.dart` |
| B4 | RBAC/privilégios decididos só no cliente | Alto | `PermissionService`, `AppSession.hasFullOrgAccess` via SQLite |
| B5 | Sem garantia formal de unicidade de e-mail | Alto | Upserts sem validação cross-table |
| B6 | Colisão personal ↔ aluno com mesmo e-mail | Alto | Nenhum guard local ou trigger SQL |
| B7 | RLS não impedia elevação de `is_admin` / tiers via UPDATE | Alto | Políticas Sprint 1 permissivas em colunas sensíveis |
| B8 | Sem testes automatizados de segurança além de `normEmail` | Médio | Apenas `supabase_auth_bridge_test.dart` |

---

## 2. Plano de alteração por arquivo

| Arquivo | Ação | Status |
|---------|------|--------|
| `lib/core/auth/email_uniqueness_guard.dart` | **Criar** — validação local cross-table | ✅ |
| `lib/core/auth/server_profile_service.dart` | **Criar** — fetch `is_admin`, `access_tier` do Postgres | ✅ |
| `lib/core/auth/app_session.dart` | `ServerProfileSnapshot`, `applyServerProfile`, `hasFullOrgAccess` autoritativo | ✅ |
| `lib/core/auth/supabase_auth_bridge.dart` | Remover `provisionAuthUser`; `sendSecureAccessLink`; sync privilégios no login | ✅ |
| `lib/core/supabase/supabase_auth_service.dart` | `signInWithOtp` para link seguro | ✅ |
| `lib/core/access/permission_service.dart` | Tiers/cap/anamnese via `session.authoritative*` | ✅ |
| `lib/data/repositories/app_data_repository.dart` | Remover geração de senha; `adminSendAccessLinkFor*`; guards nos upserts | ✅ |
| `lib/features/cadastro/registry/alunos_page.dart` | Remover senhas; botão «Enviar link de acesso» | ✅ |
| `lib/features/cadastro/registry/personais_page.dart` | Idem | ✅ |
| `lib/core/auth/password_reset_webhook.dart` | **Remover** | ✅ |
| `docs/legacy-sql/sprint2_security_migration.sql.disabled` | **Criar** — unique e-mail, triggers, RLS privilegiado | ✅ |
| `test/email_uniqueness_guard_test.dart` | Testes de unicidade e colisão | ✅ |
| `test/app_session_server_profile_test.dart` | Testes RBAC server-side | ✅ |

**Fora do escopo (Sprint 3+):** sync LWW complexo, performance, UI geral, publicação App Store.

---

## 3. Implementação — resumo técnico

### 3.1 Nunca gerar senha no app (Regra 1)

- Removidos `_generateTempPassword`, `_generateProvisionalLocalPassword`, `provisionAuthUser`, `adminGenerateNew*Password`.
- Cadastro de aluno/personal **não cria senha** — apenas envia link OTP/magic link via Supabase Auth.
- UI não exibe mais credenciais provisórias; snackbar confirma envio do link.
- `password_reset_webhook.dart` **deletado** (nenhum POST com senha em claro).

### 3.2 Reset / convite seguro

| Fluxo | Mecanismo |
|-------|-----------|
| Novo aluno | `upsertStudent(sendAccessLinkAfterCreate: true)` → `sendSecureAccessLink` |
| Admin reenvia acesso | `adminSendAccessLinkForStudent` / `adminSendAccessLinkForPersonal` |
| Esqueci senha | `sendPasswordResetEmail` → `resetPasswordForEmail` (token Supabase) |
| Troca obrigatória | `updatePassword` após login (usuário define senha) |

### 3.3 RBAC server-side

- `ServerProfileService.fetchForAuthUser` lê `is_admin`, `access_tier`, `max_students_cap`, `anamnese_completed` do Postgres com JWT.
- `AppSession.applyServerProfile` torna esses valores **autoritativos** quando presentes.
- `PermissionService` usa `session.authoritativeStudentAccessTier`, `authoritativePersonalAccessTier`, `authoritativeAnamneseCompleted`.
- `hasFullOrgAccess` exige `serverProfile.isAdmin == true` (ou papel `adminPersonal` explícito) — SQLite local não basta.

### 3.4 Unicidade de e-mail e anti-colisão

**Cliente (Drift):**

- `EmailUniquenessGuard.assertLoginEmailAvailable` em `upsertPersonal` e `upsertStudent`.
- Normalização: `trim` + `lowercase` (`SupabaseAuthBridge.normEmail`).
- Alunos arquivados não bloqueiam reutilização do e-mail.

**Servidor (Postgres — `docs/legacy-sql/sprint2_security_migration.sql.disabled`):**

- Índices únicos parciais em `app_norm_email(email)`.
- Trigger `app_assert_login_email_unique` impede personal ↔ aluno com mesmo e-mail.
- Triggers `app_guard_privileged_*` bloqueiam UPDATE de colunas sensíveis por non-admin.
- Políticas RLS de UPDATE reforçadas (`personals_update_auth`, `students_update_auth`).
- View `app_my_server_profile` para consulta segura de privilégios.

### 3.5 Proteção de flags privilegiadas

| Coluna | Proteção |
|--------|----------|
| `personals.is_admin` | Trigger + RLS; app só altera se `hasFullOrgAccess` |
| `personals.access_tier`, `max_students_cap` | Idem |
| `students.access_tier`, `anamnese_completed`, `premium_plan_expires_at` | Trigger + RLS |
| `students.created_by_personal_id` | Só admin pode reatribuir (servidor) |

---

## 4. Migração SQL (aplicar no Supabase)

Ordem recomendada:

1. `docs/legacy-sql/supabase_rls_strict_auth_uid.sql.disabled`
2. `docs/legacy-sql/sprint1_security_migration.sql.disabled`
3. **`docs/legacy-sql/sprint2_security_migration.sql.disabled`**

Validar após aplicar:

```sql
-- Deve falhar (23505) se e-mail já existir em outra tabela
insert into personals (...) values (..., 'aluno@test.com', ...);

-- Non-admin não deve conseguir:
update personals set is_admin = true where id = '...';
```

---

## 5. Testes automatizados

```bash
flutter analyze lib test   # No issues found
flutter test               # 14 tests passed
```

| Arquivo | Cobertura |
|---------|-----------|
| `test/supabase_auth_bridge_test.dart` | Normalização de e-mail |
| `test/email_uniqueness_guard_test.dart` | Duplicatas, colisão personal↔aluno, arquivados |
| `test/app_session_server_profile_test.dart` | `hasFullOrgAccess`, tiers autoritativos |
| `test/widget_test.dart` | Smoke Material |

---

## 6. Checklist de aceite Sprint 2

| Critério | Status |
|----------|--------|
| Nenhuma senha gerada no Flutter | ✅ |
| Nenhuma senha provisória na UI | ✅ |
| Webhook com senha removido | ✅ |
| Reset/convite via link Supabase Auth | ✅ |
| Privilégios lidos do servidor (JWT + Postgres) | ✅ |
| `is_admin`/tier não confiados só no SQLite | ✅ |
| E-mail único local + SQL | ✅ |
| Anti-colisão personal ↔ aluno | ✅ |
| RLS/triggers para colunas sensíveis | ✅ (script SQL) |
| Testes de segurança | ✅ |
| Documentação | ✅ (este arquivo) |

---

## 7. Riscos remanescentes / próximos passos (Sprint 3+)

- Converter as proteções necessárias em migração versionada antes de qualquer aplicação remota.
- Offline: privilégios do servidor indisponíveis — app usa fallback local conservador até reconectar.
- Edge Function para convites admin com audit trail (opcional, Sprint 3).
- Sincronização LWW, performance e publicação permanecem fora desta sprint.

---

## 8. Referências

- Sprint 1: `SPRINT_1_REPORT.md`
- Migração Sprint 1: `docs/legacy-sql/sprint1_security_migration.sql.disabled`
- Migração Sprint 2: `docs/legacy-sql/sprint2_security_migration.sql.disabled`
- Funções RLS base: `docs/legacy-sql/supabase_rls_strict_auth_uid.sql.disabled`
