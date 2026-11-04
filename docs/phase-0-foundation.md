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

O exportador `scripts/export_supabase_json.sh` gera um JSON por tabela do
schema `public`, mais um manifesto com contagem e SHA-256. Ele exige
`DATABASE_URL`, não imprime a conexão, cria arquivos privados e recusa destinos
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
