# Sprint 1 — Relatório de Segurança

> Documento histórico. Os SQL citados estão desativados e não devem ser
> executados; novas mudanças usam `supabase/migrations/`.

**Projeto:** App Personal (Flutter + Drift + Supabase)
**Data:** 2026-07-09
**Escopo:** exclusivamente bloqueadores críticos de segurança (sem Sprint 2)

---

## 1. Auditoria inicial (antes das alterações)

### Achados críticos (fonte: `AUDITORIA_TECNICA.md`)

| # | Achado | Severidade | Evidência |
|---|--------|------------|-----------|
| A1 | Senhas em **texto puro** no SQLite (`password_hash` sem hash) | Crítico | `local_login_page.dart` comparava `stored != password` |
| A2 | Senhas sincronizadas para Postgres via `anon` | Crítico | `supabase_table_mappers.dart` enviava `password_hash` |
| A3 | RLS permissivo: `using (true)` para role `anon` em 17 tabelas | Crítico | `docs/legacy-sql/supabase.sql.disabled` políticas `app_sync_anon_all` |
| A4 | Login local sem JWT; `AppSession` independente do Supabase Auth | Crítico | Boot auto-entrava como primeiro admin |
| A5 | `auth_user_id` existia no SQL mas **não era usado** no app | Alto | Colunas sem lógica Dart |
| A6 | Webhook enviava `new_password` em JSON | Alto | `password_reset_webhook.dart` |

### Estado do código na auditoria

- Supabase Auth existia só em Configurações (paralelo à sessão local).
- Controle de acesso efetivo apenas no cliente (`AppSession` + `PermissionService`).
- Sync com chave `anon` tinha leitura/escrita total no servidor.

---

## 2. Plano de alteração por arquivo

| Arquivo | Ação planejada | Status |
|---------|----------------|--------|
| `lib/core/auth/supabase_auth_bridge.dart` | **Criar** — login, signUp, reset, ligação `auth_user_id` ↔ `AppSession` | ✅ |
| `lib/core/supabase/supabase_auth_service.dart` | Adicionar `resetPasswordForEmail` | ✅ |
| `lib/core/auth/app_session.dart` | Remover auto-login; `completeAuthLogin`; exigir relogin | ✅ |
| `lib/features/auth/local_login_page.dart` | Login via Supabase Auth (sem compare local) | ✅ |
| `lib/features/splash/splash_page.dart` | Validar JWT no boot; hidratar sessão | ✅ |
| `lib/app/personal_app.dart` | OAuth callback hidrata `AppSession` | ✅ |
| `lib/data/local/app_database.dart` | Schema v36: `-password_hash`, `+auth_user_id` | ✅ |
| `lib/data/local/app_database.g.dart` | Regenerado (`build_runner`) | ✅ |
| `lib/data/repositories/app_data_repository.dart` | Senhas só via Auth; provisionar `auth_user_id` | ✅ |
| `lib/data/sync/supabase_table_mappers.dart` | Remover `password_hash`; sync `auth_user_id` | ✅ |
| `lib/data/sync/supabase_pull_sync_service.dart` | Pull sem `password_hash` | ✅ |
| `lib/data/sync/remote_sync_service.dart` | Atualizar comentários | ✅ |
| `lib/core/auth/password_reset_webhook.dart` | Descontinuar (sem `new_password`) | ✅ |
| `lib/features/cadastro/registry/alunos_page.dart` | `provisionalPasswordForNewAuth` em vez de hash local | ✅ |
| `lib/features/cadastro/registry/personais_page.dart` | Remover `passwordHash` do save | ✅ |
| `lib/features/settings/settings_page.dart` | Textos e troca de senha só Auth | ✅ |
| `docs/legacy-sql/sprint1_security_migration.sql.disabled` | **Criar** — drop senhas + RLS estrito + revoke `anon` | ✅ |
| `docs/legacy-sql/supabase.sql.disabled` | Schema base sem `password_hash`; drop legado | ✅ |
| `test/supabase_auth_bridge_test.dart` | Teste unitário `normEmail` | ✅ |

**Fora do escopo Sprint 1 (Sprint 2+):** performance, UI, sync LWW complexo, publicação App Store, Edge Functions admin.

---

## 3. Implementação — resumo técnico

### 3.1 Nenhuma senha fora do Supabase Auth

- Drift v36 remove `password_hash` de `personals` e `students`.
- Repositório não grava nem compara senha localmente.
- Mappers e pull não tocam em `password_hash`.
- Webhook de reset desativado.

### 3.2 Autenticação server-side

- Login: `signInWithPassword` → JWT `authenticated`.
- Migração SQL aplica RLS por `auth.uid()` e revoga `anon`.
- Dados isolados via `auth_user_id` + funções `app_*`.

### 3.3 Fluxo no app

```
Splash → JWT válido? → SupabaseAuthBridge → AppSession → MainShell
         └─ não → LocalLoginPage → signIn → bind auth_user_id → MainShell
```

### 3.4 Provisionamento de contas

- **Novo aluno:** `signUp` + grava `auth_user_id` local + sync.
- **Conta Auth existente:** `resetPasswordForEmail` (admin / esqueci senha).
- **Login:** liga `auth_user_id` por e-mail se ainda ausente.

---

## 4. Testes executados

```bash
flutter test
```

| Teste | Resultado |
|-------|-----------|
| `test/widget_test.dart` — Material smoke | ✅ passou |
| `test/supabase_auth_bridge_test.dart` — `normEmail` | ✅ passou |

```bash
dart analyze lib
```

**Resultado:** sem issues.

---

## 5. Deploy SQL (operador — obrigatório antes de produção)

**Ordem:**

1. `docs/legacy-sql/supabase_rls_strict_auth_uid.sql.disabled` — secção 1 (funções `app_*`)
2. `docs/legacy-sql/sprint1_security_migration.sql.disabled` — drop senhas + RLS + revoke `anon`

**Dados:**

```sql
-- Criar users em Authentication, depois:
UPDATE public.personals SET auth_user_id = '<uuid-auth>' WHERE email = '...';
UPDATE public.students SET auth_user_id = '<uuid-auth>' WHERE email = '...';
```

**Build:**

```bash
flutter build ios --release --dart-define-from-file=dart_defines.prod.json
```

---

## 6. Critérios de aceite Sprint 1

| Critério | Atendido |
|----------|----------|
| RLS restritivo (não permissivo `anon`) | ✅ migração SQL pronta |
| Login via Supabase Auth | ✅ |
| Sem senha em Drift/SQLite/sync | ✅ |
| `auth_user_id` no app e sync | ✅ |
| Migração SQL segura | ✅ |
| Relatório Sprint 1 | ✅ este arquivo |

---

## 7. Riscos residuais (não tratados nesta sprint)

- Utilizadores legados sem conta em `auth.users` não entram até provisionamento manual.
- `signUp` no cliente depende da configuração do projeto Supabase.
- Builds **sem** `SUPABASE_ANON_KEY` bloqueiam login (comportamento esperado).
- `docs/legacy-sql/supabase_FIXED_COPY_PASTE.sql.disabled` ainda referencia `password_hash` (cópia legada; usar `sprint1_security_migration.sql`).

---

## 8. Arquivos entregues nesta sprint

```
lib/core/auth/supabase_auth_bridge.dart          (novo)
docs/legacy-sql/sprint1_security_migration.sql.disabled           (novo)
test/supabase_auth_bridge_test.dart              (novo)
SPRINT_1_REPORT.md                               (este arquivo)
```

**Estado:** código e migração prontos. **Ação pendente:** executar SQL no Supabase e criar/ligar contas Auth antes de release.
