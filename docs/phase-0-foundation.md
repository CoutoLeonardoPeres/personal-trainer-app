# Fase 0: fundação segura

## Estado preservado

- Branch de trabalho: `refactor/robust-sync`.
- Trabalho anterior separado em commits de código, SQL e documentação.
- Matriz aprovada em `docs/requirements/matrix.md`.
- SQL anterior preservado em `docs/legacy-sql/` com extensão não executável.
- Tag de segurança: `pre-refactor-2026-11-04` após a validação final da fase.

## Supabase local

O projeto foi inicializado com o Supabase CLI. Novas alterações de banco devem
usar `supabase/migrations/`; funções ficam em `supabase/functions/`, testes em
`supabase/tests/` e dados determinísticos de desenvolvimento em
`supabase/seed.sql`.

O ambiente local usa PostgreSQL 17, versão gerada pelo CLI atual. A versão do
projeto remoto deve ser confirmada antes de qualquer `db push`; se for
diferente, `db.major_version` precisa ser alinhado primeiro.

O exportador `scripts/export_supabase_json.sh` gera um JSON por tabela do
schema `public`, mais um manifesto com contagem e SHA-256. Ele usa uma única
transação `REPEATABLE READ`, transmite as linhas sem agregar a tabela inteira
em memória, guarda a conexão num arquivo temporário privado e recusa destinos
dentro do repositório.

Exemplo seguro:

```bash
DATABASE_URL='postgresql://...' \
  scripts/export_supabase_json.sh /private/tmp/app-personal-export
```

## Verificações

- Formatação, análise estática e testes Flutter com cobertura.
- Histórico completo sem segredos pelo Gitleaks.
- Exemplos de configuração somente com valores inertes.
- Rejeição automática de RLS aberta e grants para `anon`/`public`.
- Testes dos próprios verificadores em `tool/ci/test_checks.sh`.
- Inicialização e `supabase db reset` num Postgres descartável na CI.

## Pacote de recuperação local

Antes dos commits de preservação, foram verificados estes arquivos privados:

| Arquivo | SHA-256 |
|---|---|
| `/private/tmp/App_Personal-pre-refactor-2026-11-04.bundle` | `0cebc6679e660f0dff3ed63e20c60a2b429838a1e2339f6d91b94655d0870ad0` |
| `/private/tmp/App_Personal-working-tree.patch` | `89217c791ab9fd4767afc6c5a3a17744fee27b925727ec3d8daa459774a9e280` |
| `/private/tmp/App_Personal-untracked.tar.gz` | `750d1e7442fc67de2112fd9036bd78b0c4e7307d139dcfc3f84e18aed7536176` |
| `/private/tmp/App_Personal-ignored-private.tar.gz` | `d7628e2e5f157e3ef51354b586af007b0d6db7c354c397a60e4d8ba5ae008160` |

O último arquivo contém material ignorado e permanece com permissão `0600`;
nenhum desses backups entra no Git.
