# Credenciais do Supabase

## Regras do cliente

- O aplicativo aceita somente chave pública (`publishable` ou a `anon` legada).
- `service_role`, secret keys e senhas de banco nunca entram no Flutter, em
  arquivos de exemplo, no Git ou nos artefatos de build.
- `dart_defines.example.json` contém apenas o texto `false`. O arquivo real
  deve permanecer local como `dart_defines.prod.json`.
- A CI verifica o histórico com Gitleaks e rejeita exemplos com valores ativos.

## Rotação da chave pública

1. No Dashboard do Supabase, abra **Settings > API Keys** e crie ou copie a
   chave `sb_publishable_...`.
2. Atualize o ambiente local e os destinos de build sem remover a chave
   anterior ainda.
3. Publique uma versão do aplicativo, valide login, sincronização, automações,
   webhooks e CI com a chave nova.
4. Observe a adoção da versão e mantenha a chave antiga durante a janela de
   atualização dos clientes instalados.
5. Desative a chave `anon` legada somente depois de confirmar que não há
   consumidores restantes. Prepare rollback antes da desativação.

As chaves públicas não substituem autorização: todas as tabelas expostas
precisam de RLS restritiva baseada no usuário autenticado. Secret keys são
exclusivas de serviços de backend confiáveis.

Referência: <https://supabase.com/docs/guides/api/api-keys>
