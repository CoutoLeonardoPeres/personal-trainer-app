# SQL legado

**NÃO EXECUTAR estes arquivos diretamente.**

Este diretório preserva os scripts anteriores à refatoração apenas para
auditoria, rastreabilidade e consulta durante a conversão para migrações do
Supabase CLI. A extensão `.sql.disabled` impede que verificadores e comandos
de migração os tratem como SQL executável.

Toda alteração de banco nova deve entrar em `supabase/migrations/`, ser
reversível quando possível e passar pelos testes locais antes da aplicação
remota.
