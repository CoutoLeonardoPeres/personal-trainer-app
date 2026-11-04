# Sprint 1 — Relatório de Segurança

> Documento histórico. Os SQL citados foram desativados e não devem ser
> executados; novas mudanças devem usar `supabase/migrations/`.

**Projeto:** Personal Gym (Flutter + Supabase)
**Escopo:** Bloqueadores críticos de vazamento de dados
**Data:** Julho 2026

---

## Objetivo

Eliminar o risco de vazamento e adulteração total da base causado por:

- RLS permissivo para `anon`
- Senhas em texto puro no SQLite e Postgres
- Login local sem JWT
- Controle de acesso apenas no cliente
- Sync enviando `password_hash` para o Supabase

---

## Entregas realizadas

### 1. RLS permissivo com `anon` → RLS por `auth.uid()`

**Arquivo:** `docs/legacy-sql/sprint1_security_migration.sql.disabled`

- Remove políticas `app_sync_anon_all` / `app_sync_authenticated_all`
- Revoga `GRANT` para `anon` em todas as tabelas `public`
- Aplica políticas restritivas por `authenticated` usando funções `app_*` (pré-requisito: secção 1 de `docs/legacy-sql/supabase_rls_strict_auth_uid.sql.disabled`)

### 2. Login local inseguro → Supabase Auth

**Arquivos:**

- `lib/features/auth/local_login_page.dart` — login via `SupabaseAuthBridge.signInAndBindAppSession`
- `lib/features/splash/splash_page.dart` — valida JWT no boot; sem sessão Auth → tela de login
- `lib/core/auth/app_session.dart` — removido auto-login como primeiro personal/admin

### 3. Senhas em texto puro → removidas

**Drift v36** (`lib/data/local/app_database.dart`):

- Coluna `password_hash` removida de `personals` e `students`
- Nova coluna `auth_user_id` (ligação a `auth.users`)

**Postgres** (`docs/legacy-sql/sprint1_security_migration.sql.disabled`):

- `ALTER TABLE ... DROP COLUMN password_hash`

### 4. Autenticação server-side

- Todas as operações de sync passam a exigir JWT `authenticated` após migração SQL
- `auth.uid()` usado nas políticas RLS via `auth_user_id` em `personals` / `students`

### 5. Vinculação usuários locais ↔ Supabase Auth

**Arquivo:** `lib/core/auth/supabase_auth_bridge.dart`

- No login: procura perfil por `auth_user_id` ou e-mail; grava `auth_user_id` se ausente
- No cadastro de aluno novo: `signUp` + grava `auth_user_id`
- Admin “gerar senha”: `signUp` (sem conta) ou `resetPasswordForEmail` (conta existente)

### 6. Remoção de senha do sync

**Arquivos:**

- `lib/data/sync/supabase_table_mappers.dart` — removido `password_hash`; adicionado `auth_user_id`
- `lib/data/sync/supabase_pull_sync_service.dart` — pull sem `password_hash`
- `lib/data/repositories/app_data_repository.dart` — métodos de senha usam só Supabase Auth
- `lib/core/auth/password_reset_webhook.dart` — descontinuado (não envia mais `new_password`)

### 7. Migração SQL segura

| Ordem | Script |
|-------|--------|
| 1 | `docs/legacy-sql/supabase_rls_strict_auth_uid.sql.disabled` (secção 1 — funções) |
| 2 | `docs/legacy-sql/sprint1_security_migration.sql.disabled` (drop senhas + RLS + revoke anon) |

### 8. Fluxos de senha (pós-sprint)

| Ação | Comportamento |
|------|----------------|
| Login | `signInWithPassword` → liga `AppSession` |
| Esqueci senha | `resetPasswordForEmail` |
| Alterar senha (configurações) | Reauth + `updateUser(password)` |
| Novo aluno | `signUp` com senha provisória; mostrada uma vez ao admin |
| Reset admin (conta existente) | E-mail de recuperação Supabase |

---

## Checklist de deploy (obrigatório)

1. **Criar utilizadores** em Supabase Dashboard › Authentication para cada personal/aluno existente.
2. **Ligar perfis:**
   ```sql
   UPDATE public.personals SET auth_user_id = '<uuid>' WHERE email = 'personal@exemplo.com';
   UPDATE public.students SET auth_user_id = '<uuid>' WHERE email = 'aluno@exemplo.com';
   ```
3. **Build com anon key:** `dart_defines.prod.json` ou `--dart-define=SUPABASE_ANON_KEY=...`
4. **Executar migração SQL** (ordem acima) em janela de manutenção.
5. **Testar login** no app antes de distribuir build aos utilizadores.
6. **Confirmar** que `anon` não consegue `SELECT` em `personals` / `students` (SQL Editor com role anon).

---

## Riscos residuais (fora do escopo Sprint 1)

- **Sign-up no cliente:** depende de “Enable email signups” no projeto Supabase; produção pode exigir Edge Function com `service_role` para provisionamento em massa.
- **Utilizadores legados sem conta Auth:** não entram até criar user + `auth_user_id`.
- **OAuth Google/GitHub:** callback hidrata sessão; fluxo completo de onboarding ainda manual.
- **Performance, UI, publicação App Store:** não tratados nesta sprint.

---

## Arquivos principais alterados

| Área | Arquivos |
|------|----------|
| Auth | `supabase_auth_bridge.dart`, `supabase_auth_service.dart`, `app_session.dart`, `local_login_page.dart` |
| Dados | `app_database.dart` (schema 36), `app_data_repository.dart` |
| Sync | `supabase_table_mappers.dart`, `supabase_pull_sync_service.dart` |
| UI | `splash_page.dart`, `settings_page.dart`, `alunos_page.dart`, `personais_page.dart` |
| SQL | `docs/legacy-sql/sprint1_security_migration.sql.disabled` |

---

## Critério de sucesso Sprint 1

- [x] Nenhuma senha em Drift/SQLite/Postgres/sync
- [x] Login obrigatório via Supabase Auth no app
- [x] `auth_user_id` propagado no sync
- [x] Migração SQL para RLS estrito e revoke `anon`
- [x] Relatório documentado

**Estado:** implementação no código concluída; **deploy SQL + criação de contas Auth** é ação manual do operador antes de produção.
