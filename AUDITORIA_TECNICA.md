# Auditoria Técnica — App Personal (Flutter + Drift + Supabase)

> Registro histórico. Os caminhos SQL citados apontam para arquivos
> desativados e não são instruções de execução.

Data: 2026-07-09 · Escopo: segurança, controle de acesso, sincronização/sobregravação, observabilidade, produção, UI/performance.

Veredito curto: **o app não está pronto para produção.** A arquitetura de segurança é decorativa (tudo é validado no cliente contra um banco aberto ao mundo) e a camada de sync é um conjunto de heurísticas de relógio empilhadas que garante, por design, os conflitos e sobregravações que você está vendo.

---

## 1. SEGURANÇA — CRÍTICO

### 1.1 Senhas em texto puro, sincronizadas para a nuvem (CRÍTICO)
- A coluna chama-se `passwordHash`, mas guarda a **senha em texto puro**. O login compara `stored != password` (`local_login_page.dart:238` e `:256`). Não há hash, salt, nada.
- Pior: `supabase_table_mappers.dart:54/81` envia `password_hash` (a senha em claro) para o Postgres, e o schema (`docs/legacy-sql/supabase.sql.disabled:102/125`) a armazena.
- Combinado com 1.2, **qualquer pessoa na internet pode ler a senha de todos os personais e alunos**.

### 1.2 Banco Supabase aberto para o mundo (CRÍTICO)
- `docs/legacy-sql/supabase.sql.disabled:704-711` cria políticas RLS `using (true) with check (true)` para o role **anon** em TODAS as tabelas. A anon key embutida no app (extraível de qualquer APK/IPA) dá **leitura e escrita total**
