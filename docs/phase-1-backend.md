# Fase 1 - Backend Supabase

## Estado

O backend offline-first foi implementado em migrations versionadas e validado em
banco local vazio. Ele ainda nao deve ser aplicado ao projeto de producao: o app
publicado usa acesso direto as tabelas e so sera compativel depois das Fases 2 e 3.

## Contratos implementados

- Tenant por personal e associacao autoritativa em `tenant_memberships`.
- RLS forcada em todas as tabelas publicas, sem leitura ou escrita direta do app.
- API autenticada limitada a sete RPCs: registro, tempo, push, pull, snapshot,
  exportacao e exclusao de conta.
- HLC canonico por campo, tombstones e restauracao explicita.
- Sequencia monotonicamente crescente por tenant, sem usar horario do aparelho
  como cursor.
- Idempotencia por `op_id`, hash da operacao e sequencia por dispositivo.
- Eventos de serie e cronometro append-only.
- Auditoria append-only sem payload, anamnese ou dados de saude.
- Poke vazio via Broadcast privado; o pull continua sendo a fonte da verdade.
- Convite sem senha, relatorio de IA com consentimento e limite persistente, e
  exclusao de conta com reautenticacao recente.

## Realtime

O Supabase reserva a propriedade de `realtime.messages` ao papel interno do
Realtime. Por isso, a trigger fica na migration `0007_realtime_poke.sql`, enquanto
a policy de assinatura privada fica em `scripts/apply-realtime-policy.sql` e deve
ser aplicada com o papel administrativo do projeto de homologacao.

## Verificacoes

- [x] `supabase db reset --local` recria o banco do zero.
- [x] Contrato pgTAP: 28 assercoes.
- [x] T1-T9: 25 assercoes, incluindo claims maliciosas em `user_metadata`.
- [x] Concorrencia T9 e cronometro com duas conexoes PostgreSQL simultaneas: 7 assercoes.
- [x] Conflitos, tombstones, restore, pull, snapshot e auditoria: 14 assercoes.
- [x] Regressoes de seguranca de exportacao, cursor e exclusao: 21 assercoes.
- [x] Total local: 95 assercoes pgTAP aprovadas.
- [x] Consulta de grants e policies abertas no schema `public`: zero resultados.
- [x] `flutter analyze` e `flutter test` passam.
- [ ] Aplicar migrations e policy Realtime em projeto de homologacao isolado.
- [ ] Executar o pen test T1-T9 por HTTP contra a homologacao.

O comando oficial `supabase test db --local` esta no CI. Neste Mac, o Docker
Desktop nao compartilha a pasta do projeto com containers auxiliares; os mesmos
arquivos pgTAP foram executados diretamente no container PostgreSQL local. O CI
Linux nao possui essa restricao de compartilhamento.
