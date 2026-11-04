# Auditoria Técnica — App Personal (Flutter + Supabase)

Revisão de arquitetura, cibersegurança, banco de dados, sincronização, observabilidade,
prontidão para produção e UI/performance. Análise crua, sem suavizar. Cada item traz
severidade, o arquivo/linha onde está o problema e a correção recomendada.

Legenda de severidade: 🔴 Crítico · 🟠 Alto · 🟡 Médio · 🔵 Baixo

---

## Resumo executivo (leia isto primeiro)

O app **não está pronto para produção** e, no estado atual, tem falhas de segurança que
configuram vazamento de dados pessoais de todos os usuários. Os três problemas que
sozinhos já impedem qualquer lançamento:

1. **RLS do Supabase é 100% permissivo para `anon`** — a chave anônima está embutida no
   binário do app e a política ativa é `for all to anon using (true) with check (true)`.
   Qualquer pessoa que extraia a chave (trivial em qualquer APK/IPA) pode **ler, alterar e
   apagar os dados de todos os personais e todos os alunos** — treinos, CPF, e-mail,
   telefone, endereço e senhas. Isso é um incidente de LGPD à espera de acontecer.

2. **Senhas armazenadas e sincronizadas em texto puro.** A coluna chama-se `password_hash`
   mas guarda a senha literal (comparação `stored != password`, sem hash). Essa senha é
   enviada ao Supabase em claro pelo mapper e, dado o item 1, fica legível para qualquer um.

3. **Autenticação real inexistente.** O "login" é uma comparação local de string contra o
   SQLite. Não há `auth.uid()`, não há JWT por usuário, não há isolamento no servidor. Todo
   o controle de acesso vive no cliente e pode ser contornado.

Além disso, a camada de sincronização é extraordinariamente complexa (um `pull` de ~4.000
linhas, um `remote sync` de ~2.100), acumulou muitas heurísticas de "quem vence o conflito"
e ainda assim mantém condições de corrida e sobregravação entre dispositivos por depender de
relógios de parede (`updated_at`) e de um `revision` que não é atômico no servidor.

Abaixo, o detalhamento.

---

## 1. Segurança e controle de acesso

### 1.1 🔴 RLS permissivo — acesso total via chave anônima
`scripts/supabase.sql` (linhas ~704–712) cria, para praticamente todas as tabelas:

```sql
create policy app_sync_anon_all on public.<tabela>
  for all to anon using (true) with check (true);
```

Isso significa que a chave `anon` (presente em `dart_defines.prod.json` e, por definição,
embutida em todo build distribuído) concede **SELECT/INSERT/UPDATE/DELETE irrestrito** sobre
`personals`, `students`, `day_workouts`, `audit_logs`, etc. O comentário no `.sql` reconhece
que isto é "para desenvolvimento", mas é a política que está de fato aplicada. Existe um
`supabase_rls_strict_auth_uid.sql`, porém ele **só funciona depois de migrar para Supabase
Auth**, o que o app não faz.

**Impacto:** vazamento e adulteração total do banco por qualquer pessoa com o app instalado.
Um aluno mal-intencionado pode ler os dados de todos os outros alunos e personais.

**Correção:** migrar de fato para Supabase Auth (item 1.3), preencher `auth_user_id` em
`personals`/`students`, aplicar `supabase_rls_strict_auth_uid.sql` e **revogar as políticas
`anon`**. Enquanto isso não acontece, qualquer escrita/leitura sensível deveria passar por
Edge Functions que validem a identidade — nunca direto do cliente com anon key.

### 1.2 🔴 Senhas em texto puro (armazenadas e sincronizadas)
- `lib/features/auth/local_login_page.dart:238` e `:257` — `if (stored != password)`:
  comparação direta de string. A senha nunca é hasheada.
- `lib/data/repositories/app_data_repository.dart` — ao definir/alterar senha grava
  `passwordHash: Value(newPassword)` (o valor cru).
- `lib/data/sync/supabase_table_mappers.dart:54` e `:81` — `'password_hash': e.passwordHash`
  envia a senha literal para o Postgres.

Combinado com o item 1.1, **todas as senhas de todos os usuários são recuperáveis** por
quem tiver a anon key. Muitos usuários reusam senhas; o dano extrapola o app.

**Correção:** nunca sincronizar senha para a nuvem. Se autenticar via Supabase Auth, o
Supabase cuida do hash (bcrypt) do lado do servidor e o app não precisa da coluna. Se por
algum motivo mantiver login local, use no mínimo `argon2`/`bcrypt`/`scrypt` com salt por
usuário e **jamais** exporte o hash em tabela lida por `anon`.

### 1.3 🔴 Ausência de autenticação server-side
`SupabaseAuthService` existe (e-mail/senha, Google, GitHub, deep link) mas **não é usado no
fluxo de login**. O `LocalLoginPage` autentica só contra o SQLite local. Resultado:
`auth.uid()` é sempre nulo, o RLS estrito não pode ser ligado, e todo o RBAC
(`AppSession`, `PermissionService`) é decorativo do ponto de vista de segurança — roda no
cliente e é totalmente burlável (basta editar o SQLite local ou falar direto com a API).

**Correção:** adotar `SupabaseAuthService.signInWithEmail` como caminho principal de login,
ligar contas via `auth_user_id`, e mover as regras de acesso para políticas RLS no servidor.

### 1.4 🟠 Reset de senha exibe/compartilha senha provisória em tela
`local_login_page.dart:125` mostra a nova senha via `SelectableText`, oferece "Copiar" e
"Partilhar…" (`SharePlus`). Sem verificação de posse do e-mail: qualquer um que digite o
e-mail de uma vítima e clique em "Esqueci minha senha" **gera uma nova senha e a vê na hora**
(quando o webhook não está configurado — que é o default). Isso é um sequestro de conta de
um clique.

**Correção:** o reset deve enviar o segredo apenas pelo canal de posse (e-mail/SMS), nunca
exibi-lo a quem solicitou. Exigir confirmação por link/token.

### 1.5 🟠 Webhook de reset envia senha em claro por HTTP POST
`lib/core/auth/password_reset_webhook.dart` faz `POST` com `new_password` em texto puro para
uma URL de `--dart-define`. Sem assinatura HMAC, sem autenticação do endpoint. Um MITM ou um
endpoint mal configurado captura senhas.

**Correção:** enviar apenas um token de reset de uso único e curta validade; nunca a senha.
Assinar o payload; exigir TLS e autenticação mútua/segredo compartilhado.

### 1.6 🟠 RBAC só no cliente + `hasFullOrgAccess` inferido de flag local
`AppSession.hydratePersonalAdminFlag` lê `is_admin` do SQLite local. Como o SQLite é
sincronizado com anon key (item 1.1), qualquer um pode marcar-se `is_admin=true` localmente
(ou na nuvem) e obter acesso de administrador a toda a organização. `PermissionService`
inteiro (planos "free/basic/premium", limite de alunos, IA) é apenas conveniência de UI e
não impõe nada no servidor.

**Correção:** flags de privilégio e tier devem ser resolvidos e impostos no servidor via RLS
/ claims do JWT, não lidos de uma tabela gravável pelo cliente.

### 1.7 🟡 Colisão de identidade por e-mail tratada como erro de runtime
Se um e-mail existir como personal **e** aluno, o login lança `ArgumentError` e pede para
"corrigir no SQLite" (`local_login_page.dart:225`). Não deveria ser possível chegar a esse
estado; a unicidade de e-mail precisa ser garantida por constraint no banco, não descoberta
no login.

### 1.8 🟡 Segredos de projeto versionados no repositório
`dart_defines.prod.json` (com a URL e a anon key reais) está no repo. Está no `.gitignore`
agora, mas `dart_defines.prod.example.json` e o histórico do Git podem conter chaves. A anon
key em si não é secreta por natureza — o problema real é o item 1.1 que a torna perigosa.
Ainda assim, `service_role` jamais pode chegar perto do cliente.

**Correção:** confirmar que `service_role` nunca foi commitada; rotacionar chaves se houve
exposição; manter defines de produção fora do versionamento.

---

## 2. Banco de dados e sincronização (sobregravação entre dispositivos)

Este é o ponto que o usuário citou como mais problemático, e com razão. A estratégia de
conflito é "Last-Write-Wins com remendos", e LWW baseado em `updated_at` **garante perda de
dados** quando dois dispositivos editam offline.

### 2.1 🔴 Resolução de conflito depende de relógio de parede do dispositivo
Por toda a base, a decisão "local vence x remoto vence" usa `DateTime.now()` do aparelho e
`updated_at`:
- `supabase_push_diff.dart:32` `_localIsNewer` compara timestamps com tolerância de 1s.
- `supabase_remote_sync_service.dart:770` compara `localUpdatedAt.isAfter(remoteUpdatedAt)`.
- `supabase_pull_sync_service.dart` usa dezenas de comparações de `updated_at` com tolerâncias
  de 1–3s, além de janelas de 90s/3min em `_hasRecentBlockingPerformedSetAuditForLine`.

Relógios de celular divergem (fuso, drift, usuário que muda a hora). Um aparelho com relógio
adiantado **sempre ganha** e sobregrava o que o outro fez, mesmo tendo dados mais antigos.
As "tolerâncias" mágicas (1s, 2s, 3s, 90s, 3min) são sintomas de tentar consertar isso no
escuro.

**Correção:** parar de decidir por relógio. Usar versionamento monotônico no servidor
(sequência/trigger que incrementa `revision` no Postgres a cada UPDATE) e resolver conflito
por `revision`, com o servidor como fonte da verdade. Para o log de séries de treino,
considerar CRDT/append-only (cada série é um evento imutável com id próprio) em vez de
sobrescrever um `performed_sets_json` inteiro.

### 2.2 🔴 `revision` não é atômico no servidor
O `revision` é calculado no cliente (`_nextRevision(previous.revision)` em
`app_data_repository.dart`) e enviado no upsert. `_lwwUpdateById`
(`supabase_remote_sync_service.dart:779`) tenta um update condicional
`.lt('revision', rev)`, mas dois dispositivos partindo de `revision=5` geram ambos
`revision=6` e um sobrescreve o outro (mesma revisão, desempate por `updated_at`/deviceId —
volta ao problema 2.1). Não há incremento atômico garantido pelo Postgres.

**Correção:** incrementar `revision` via trigger `BEFORE UPDATE` no Postgres
(`NEW.revision = OLD.revision + 1`) e rejeitar escritas com `revision` desatualizada
(optimistic concurrency real), devolvendo conflito para o cliente reconciliar.

### 2.3 🟠 `performed_sets_json` é sobrescrito como bloco único
Séries executadas ("started"/"append_set") são guardadas como um JSON inteiro na linha do
exercício. Dois aparelhos que registrem séries no mesmo exercício ao mesmo tempo
sobregravam o array um do outro. Todo o arsenal de heurísticas
(`_localPerformedSetsAheadOfRemote`, `_tryMergeRemotePerformedSetsWhenLocalLooksNewer`,
`_hasRecentBlockingPerformedSetAuditForLine`) existe só para mitigar isso, e ainda assim
compara por `length` e `max(loggedAtMs)`, o que perde séries silenciosamente.

**Correção:** modelar séries executadas como linhas append-only (tabela
`performed_sets` com id por série), fazendo merge por união de ids em vez de comparar arrays.

### 2.4 🟠 Polling agressivo em foreground (4s) + realtime + fidelity + heartbeat sobrepostos
Rodando ao mesmo tempo:
- `SupabaseAutoPullScheduler.startForegroundPolling` a cada **4s** (`personal_app.dart:259`).
- `SupabaseRealtimeSyncService` com canais Postgres + poll de "started" a cada 30s.
- `SupabaseCloudFidelityChecker` a cada 18min.
- Heartbeat a cada 120s.
- `scheduleAfterResume` disparado de 6+ lugares (calendar, planning, shell, day_flow).

Isso é muito tráfego, muita bateria, e cria **corridas entre o pull periódico e o realtime**
importando a mesma linha em ordens diferentes, reabrindo a janela de sobregravação. Também
multiplica leituras faturáveis no Supabase.

**Correção:** confiar no realtime como caminho primário e reduzir drasticamente o polling
(ex.: só um pull no resume e um fallback esparso). Debounce/coalescência central de sync em
vez de vários agendadores independentes.

### 2.5 🟠 `pullAllFromRemote` do admin baixa a base inteira sem paginação incremental de tempo
`_pullTableRowsPaged` (`supabase_pull_sync_service.dart:672`) pagina por `range`, mas puxa
**todas as linhas** de cada tabela a cada pull completo (admin), sem filtro por
`updated_at > lastSync`. Em uma base com histórico de treinos isso escala mal — cada
foreground pull relê tudo. Somado ao polling de 4s, é custo e latência crescentes.

**Correção:** sync incremental por watermark (`updated_at > última sincronização`) e cursores
persistidos por tabela.

### 2.6 🟠 `recomputeAllCompletedWorkoutScores` roda em loop O(N) a cada pull
`supabase_pull_sync_service.dart:1125` e `:1132` chamam
`recomputeAllCompletedWorkoutScores()` dentro de todo pull. Essa função
(`app_database.dart:1271`) percorre **todos** os treinos concluídos e recalcula um a um, cada
qual com seu próprio SELECT das linhas (`recomputeCompletedDayWorkoutScore`). É N+1 puro
executado a cada ciclo de sync — inclusive no polling de 4s.

**Correção:** recalcular só os treinos afetados pelo pull atual; ou mover o cálculo de score
para o servidor (view/coluna gerada) e nunca varrer o histórico inteiro em foreground.

### 2.7 🟡 Deletes por "tombstone" derivados de auditoria/nome
A prevenção de "ressuscitar" registros apagados usa tombstones inferidos de `audit_logs` e
até de heurística de nome (`studentNameIndicatesArchivedStub`,
`_pullStudentIsArchivedFromRow`). Isso é frágil: depende da fila de auditoria estar intacta e
sincronizada. Se a auditoria for podada ou falhar, deletes voltam.

**Correção:** usar soft-delete explícito com `deleted_at` como fonte única (já existe a
coluna em algumas tabelas) e propagar tombstones reais, não inferidos.

### 2.8 🟡 Tratamento de erro por *string matching* da mensagem do Postgres
`_isMissingSchemaColumn`, `_looksLikeDuplicateKey`, `_isDayWorkoutParentFkError` decidem o
fluxo comparando substrings como `'PGRST204'`, `'23505'`, `'duplicate'`
(`supabase_remote_sync_service.dart:863–887`). Qualquer mudança de versão/idioma da API do
Supabase quebra a lógica de recuperação silenciosamente.

**Correção:** tratar por código de erro estruturado (`PostgrestException.code`), não por texto.

### 2.9 🟡 "Auto-reparo" de sessão pode trocar o usuário logado sem avisar
`AppSession.repairSessionIfInconsistent` (`app_session.dart:223`), diante de prefs
inconsistentes, promove silenciosamente o primeiro personal/admin da lista à sessão ativa.
Num aparelho onde um aluno está logado com estado corrompido, isso pode **elevar
privilégios** para admin sem interação. Perigoso combinado com 1.6.

**Correção:** em inconsistência, deslogar e exigir login, nunca auto-selecionar um perfil de
maior privilégio.

---

## 3. Observabilidade e prontidão para produção

### 3.1 🔴 Build de release assinado com a chave de debug
`android/app/build.gradle.kts`: `release { signingConfig = signingConfigs.getByName("debug") }`
com o `// TODO` original do Flutter. Não dá para publicar na Play Store assim, e um APK
assinado em debug é instalável/adulterável sem as garantias de assinatura de release.

**Correção:** criar keystore de release, configurar `signingConfigs` real e habilitar
`minifyShrinkResources`/R8.

### 3.2 🟠 Sem crash reporting / telemetria de produção
Toda a "observabilidade" é `debugPrint` + `developer.log` (`launch_diagnostic.dart`). Há 78
pontos de log com `debugPrint`/`print` no `lib`. Em produção, ninguém vê esses logs. Não há
Sentry/Crashlytics/Firebase, nem métricas de sync (taxa de conflito, falhas de push).

**Correção:** integrar um crash reporter (Sentry/Crashlytics), reportar
`FlutterError.onError` e `PlatformDispatcher.onError` (já capturados localmente — só falta
enviar) e instrumentar a fila de sync com contadores.

### 3.3 🟠 Cobertura de teste praticamente nula
`test/` tem apenas um smoke test de `MaterialApp`. **Zero** testes para a lógica mais crítica
e mais complexa do app: resolução de conflito, LWW, merge de séries, RBAC. Dado o volume de
heurísticas frágeis (seção 2), isto é temerário — qualquer refactor quebra sync sem aviso.

**Correção:** testes unitários para `SupabasePushDiff`, `_localWinsConflictByVersion`, merge
de `performed_sets`, e `PermissionService`. Testes de integração de sync com relógios
divergentes simulados.

### 3.4 🟡 Logs podem vazar dados sensíveis
Vários `debugPrint` incluem ids de entidades, e o fluxo de reset chega a manipular a senha em
memória perto de logs. Em builds de perfil/log ativado, PII pode escapar.

**Correção:** garantir que nada de PII/segredo é logado; usar níveis de log e redigir.

### 3.5 🟡 Migrações de schema acopladas a `ALTER TABLE ADD COLUMN IF NOT EXISTS` manuais
Há múltiplos scripts SQL paralelos (`supabase.sql`, `supabase_FIXED_COPY_PASTE.sql`,
`supabase_FIX_SYNC_MIGRATION_ONLY.sql`, etc.) que precisam ser rodados na mão e mantidos em
paridade com o Drift. Isso é fonte garantida de divergência de schema entre ambientes (e o
próprio código tem fallback `_compatMapWithoutNewSyncColumns` por causa disso).

**Correção:** adotar migrações versionadas do Supabase (CLI) como fonte única e um processo
de deploy, eliminando os scripts "copy-paste".

### 3.6 🔵 Sem trilha de ambiente (dev/staging/prod)
Um único projeto Supabase, sem separação de ambientes. Testes batem no mesmo banco de
produção.

---

## 4. UI, design e performance (lentidão)

### 4.1 🟠 Arquivos de UI gigantescos = jank e manutenção difícil
`calendar_day_exercises_sheet.dart` tem **3.909 linhas**, `performance_page.dart` **2.741**,
`calendar_day_flow.dart` **2.324**, `planning_page.dart` **1.546**. Widgets desse tamanho
tendem a reconstruir subárvores enormes a cada `setState` (há 20 `setState` só no sheet de
exercícios). Isso é causa direta de travadas ao interagir.

**Correção:** quebrar em widgets menores com `const` onde possível, isolar estado com
`ValueListenableBuilder`/`Selector` (o app já usa Provider) para reconstruir só o necessário.

### 4.2 🟠 Recomputo de score no caminho de foreground (ver 2.6)
Já citado, mas vale como causa de lentidão percebida: a cada pull (incluindo o de 4s) o app
varre e reescreve todos os treinos concluídos. Em quem tem histórico, o calendário/dashboard
"congela" periodicamente enquanto isso roda na thread de UI/DB.

### 4.3 🟡 Vários `Timer.periodic` de 1s simultâneos
`rest_live_activity_controller`, `student_workout_live_activity_bar`, `inter_set_rest_modal`,
`calendar_day_exercises_sheet:1460` — todos com tick de 1s. Se mais de um fica ativo, são
múltiplos rebuilds por segundo. Verificar cancelamento em `dispose` de todos (o modal usa
`??=`, bom; confirmar os demais).

### 4.4 🟡 Sem internacionalização / strings mistas
Não há `localizationsDelegates`/`supportedLocales`. As strings são pt-PT/pt-BR misturadas
("utilizador", "telemóvel", "Partilhar" convivem com português do Brasil). Para um app de
personal brasileiro isso soa estranho e inconsistente. 11 ocorrências de termos pt-PT.

**Correção:** padronizar o locale (pt-BR) e, idealmente, extrair para ARB/l10n.

### 4.5 🟡 Acessibilidade ausente
Zero `Semantics`/`semanticLabel` em todo o `lib`. Botões de ícone, cards e o fundo
"futurista" não têm rótulos para leitores de tela. Reprova em critérios básicos de
acessibilidade das lojas.

### 4.6 🔵 Fundo com `Image.asset` full-screen sem `cacheWidth`
`futuristic_background.dart:32` pinta uma imagem de fundo em tela cheia. Sem
`precacheImage`/`cacheWidth`, decodifica no tamanho original a cada tela que o usa — custo de
memória e primeiro frame. Menor, mas soma no jank inicial.

### 4.7 🔵 Um único `MaterialApp` com tema claro fixo
`buildAppTheme()` sem `darkTheme`/`themeMode`. Dado o visual escuro "futurista" já embutido
manualmente nas cores, formalizar como tema dark evitaria os inúmeros
`Colors.white.withValues(alpha: …)` espalhados.

---

## Prioridade de correção (o que fazer primeiro)

1. **Bloquear o vazamento (itens 1.1, 1.2, 1.3):** migrar para Supabase Auth, aplicar RLS
   estrito com `auth.uid()`, revogar políticas `anon`, parar de sincronizar senhas e passar a
   hash no servidor. Nada mais importa antes disto.
2. **Fechar o sequestro de conta (1.4, 1.5):** reset por token via canal de posse, nunca
   exibindo a senha.
3. **Estancar sobregravação (2.1, 2.2, 2.3):** `revision` atômico por trigger no Postgres,
   concorrência otimista real, séries executadas append-only.
4. **Produção (3.1, 3.2, 3.3):** assinatura de release, crash reporting, testes da lógica de
   sync/RBAC.
5. **Performance/UI (2.6/4.2, 4.1):** tirar o recomputo de score do foreground, quebrar os
   widgets gigantes, reduzir o polling de 4s.

---

## Nota de método

Análise estática do código-fonte em `lib/`, dos scripts em `scripts/` e das configs de
build. Não executei o app nem o banco. Os números de linha referem-se ao estado atual do
repositório no momento desta auditoria. Recomendo tratar os itens 🔴 como bloqueadores
absolutos de lançamento.
