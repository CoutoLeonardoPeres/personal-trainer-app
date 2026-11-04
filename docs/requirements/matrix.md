# Matriz de requisitos do App Personal

Esta matriz consolida o prompt mestre de 4 de novembro de 2026, `App Personal.docx`, `Prompt Personal Pro.docx`, o comportamento atual encontrado no repositório e as solicitações registradas nesta conversa. Ela é a trava de aprovação anterior a qualquer alteração funcional da refatoração.

## Convenções

- **Mestre**: `Texto colado.txt`, prompt final da refatoração.
- **AP**: `App Personal.docx`.
- **PPP**: `Prompt Personal Pro.docx`.
- **Padrão sugerido**: decisão mais restritiva aplicada somente se aprovada pelo usuário.
- Nenhuma lacuna marcada nesta matriz foi corrigida durante sua elaboração.

## Arquitetura e dados

| ID | Fonte | Exigência | Tela ou regra | Situação atual | Prova de aceite | Conflito ou padrão sugerido |
|---|---|---|---|---|---|---|
| CORE-01 | Mestre 1.2; AP 3; PPP 121,125 | Toda ação grava primeiro no Drift e cria outbox na mesma transação | Todo o app | Schema 37 usa `SyncQueue`; não há porta única atômica | Interromper o processo durante a escrita e provar ambos ou nenhum | Adotar `Mutator` único |
| CORE-02 | Mestre 1.3-1.4 | Servidor define ordem e conflitos com HLC, `device_seq` e `server_seq` | Sincronização | Ainda há `revision`, cursores temporais e relógio local | Três dispositivos convergem com ordem idêntica | Prompt mestre prevalece |
| CORE-03 | Mestre 1.4 | Eventos são append-only; cadastros usam merge por campo | Sync e séries | Caminhos atuais ainda alteram estado consolidado | Testes de comutatividade, associatividade e idempotência | Prompt mestre prevalece |
| CORE-04 | Mestre 1.4; Fases 1-3 | Exclusão de negócio é tombstone, sem delete físico | Cadastros e treinos | Há deletes físicos no repositório | Dispositivo atrasado não ressuscita exclusão | Prompt mestre prevalece |
| CORE-05 | Mestre 1.6 | Proibido corrigir sync com tolerâncias, silêncio de pull ou `updated_at` | Sincronização | Há atrasos e filtros temporais legados | Busca estática e testes com relógios em mais ou menos 1 hora | O atraso de 2 s só agrupa envio |
| CORE-06 | Mestre 2 | Manter Flutter, Drift, Supabase, estado, navegação e bibliotecas atuais | Arquitetura | Stack confirmada | Build e testes por plataforma | Trocas apenas quando o mestre exigir |
| CORE-07 | Mestre 1.1; Fase 5 | Preservar telas, ordem, textos, fluxos, modais, popups, gestos e animações | UI inteira | Goldens de linha de base não existem | Goldens antes e depois, claro e escuro | Na Fase 5 só cores, tipografia e formas |
| CORE-08 | Mestre 1.8 | Interface em português do Brasil | UI inteira | Revisão completa ainda pendente | Busca de termos portugueses e revisão visual | Corrigir idioma sem mudar significado |
| CORE-09 | Mestre Fases 1-3 | Pull nunca apaga linha local com operação pendente | Sincronização | Não provado pelo motor atual | Cenário offline por 4 horas com duas instâncias | Estado exibido é sempre o local |
| CORE-10 | Mestre Fase 3 | Um único motor de push e pull; remover motores antigos ao final | Sincronização | Vários serviços concorrentes existem | Busca comprova ausência dos motores antigos | Não manter dois motores em paralelo |

## Cadastros e planejamento

| ID | Fonte | Exigência | Tela ou regra | Situação atual | Prova de aceite | Conflito ou padrão sugerido |
|---|---|---|---|---|---|---|
| CAD-01 | AP 5-10; PPP 16-57 | Cadastrar academias, alunos, grupos musculares, exercícios, personais, métodos e grupos de treino | Cadastro | Telas principais existem | Criar, editar e reabrir cada entidade offline | PPP repete cadastro de personal; tratar como uma tela |
| CAD-02 | PPP 17-20 | Exercício: nome, grupo muscular, vídeo opcional, alternativa e vídeo alternativo | Cadastro de exercício | Campos principais existem | Teste de formulário e persistência | Manter ordem atual dos campos |
| CAD-03 | PPP 22-25 | Aluno: nome, e-mail, objetivo, CPF, nascimento, endereço, UF, CEP e academias múltiplas | Cadastro de aluno | Campos existem parcialmente | Round-trip de todos os campos e multiselect | E-mail opcional conflita com convite; ver D03 |
| CAD-04 | PPP 29-52 | Academia, personal, grupo muscular e método com os campos documentados | Cadastros | Implementação substancial existe | Testes por formulário | Campos sem obrigatoriedade explícita mantêm comportamento atual |
| CAD-05 | AP 10; PPP 54-57 | Grupo de treino contém a lista completa e ordenada de exercícios | Grupo de treino | Relações existem; houve duplicação remota | Grupo com 13 itens aparece exatamente 13 vezes em todas as telas | Deduplicar por identidade, não por nome |
| CAD-06 | AP 10 | Alterar exercício atualiza sua referência nos grupos | Exercício e grupos | Vínculos usam IDs, mas propagação não está coberta | Renomear e verificar cadastro, planejamento e calendário | Histórico concluído permanece snapshot |
| PLN-01 | AP 12-20; PPP 62-66 | Planejamento independente por aluno e semana, com navegação horizontal | Planejamento | Estruturas semanais existem | Duas semanas e dois alunos não se misturam | Sem conflito |
| PLN-02 | PPP 66 | Exibir agendados, programados, em andamento e concluídos | Planejamento | Cobertura parcial | Um treino por estado aparece no grupo correto | Padronizar termos sem alterar dados |
| PLN-03 | AP 15 | Personal e aluno autorizado personalizam grupo sem alterar o cadastro-base | Planejamento | Snapshots existem | Alterar planejamento e comparar grupo-base | Aluno Free não pode planejar |
| PLN-04 | PPP 71-73 | Agendar exercícios ou grupo para a semana | Planejamento | Fluxos existem parcialmente | Agendamento persiste offline e reaparece após reinício | Respeitar permissões do plano |
| PLN-05 | PPP 73 | Carga opcional; repetição e número de séries obrigatórios; carregar últimos registros | Planejamento | Parcial | Bloquear prescrição incompleta e preencher histórico | “Inteiro 12-15” é contraditório; preservar faixa de prescrição |
| PLN-06 | AP 17-20; PPP 75 | Alterações propagam conforme o estado do treino | Planejamento e calendário | Regras estão espalhadas | Matriz editar/excluir por estado | Padrão: atualizar apenas ainda não programados |
| PLN-07 | AP 18-20 | Programado é snapshot; excluir explicitamente o agendado remove sua programação | Planejamento e calendário | Não coberto integralmente | Testes de disponíveis versus agendados | Edição explícita no calendário afeta só o snapshot |
| PLN-08 | Solicitações atuais | Cards de grupos começam recolhidos e abrem por toque | Planejamento | Precisa validação visual | Widget test do estado inicial e expansão | Preservar conteúdo e ordem |
| PLN-09 | Solicitações atuais | Agendamento aparece imediatamente no planejamento pelo banco local | Planejamento | Relatos de ausência e lentidão | Agendar offline e observar stream local sem refresh remoto | Nuvem não bloqueia a UI |

## Calendário e execução do treino

| ID | Fonte | Exigência | Tela ou regra | Situação atual | Prova de aceite | Conflito ou padrão sugerido |
|---|---|---|---|---|---|---|
| CAL-01 | AP 23-26; PPP 78-80 | Data vazia lista apenas alunos com treinos válidos naquela semana | Calendário | Fluxo existe | Aluno sem treino não aparece | Sem conflito |
| CAL-02 | AP 24-26; PPP 79,85 | Selecionar aluno e grupo mostra todos os exercícios, sem duplicar | Calendário | Relatos de duplicação após pull | Grupo de 13 itens permanece com 13 durante e após sync | Snapshot local não pode oscilar com dados remotos parciais |
| CAL-03 | PPP 79 | Programar treino cria snapshot editável só para aquele dia | Calendário | Método existe | Programar, reiniciar offline e conferir | Alteração não afeta cadastro ou planejamento |
| CAL-04 | PPP 9,79 | Programar para um ou mais dias | Calendário | Cobertura parcial | Programar dois dias sem duplicar exercícios | AP restringe à semana disponibilizada; ver D04 |
| CAL-05 | PPP 81 | Antes de iniciar, permitir iniciar ou trocar por treino válido da semana | Calendário | Diálogo existe | Testar ambas as escolhas | Padrão: somente opções válidas da semana |
| CAL-06 | PPP 83 | Iniciar, pausar, retomar e concluir; tempo ignora pausas | Execução | Implementação existe, estabilidade não provada | Relógio controlado com duas pausas | Migrar para eventos append-only |
| CAL-07 | PPP 85 | Depois de iniciado, não editar nem excluir exercícios; pode acrescentar | Execução | Precisa cobertura | Tentar editar, excluir e adicionar | Confirmar limite após primeira série, ver D05 |
| CAL-08 | PPP 127; solicitações atuais | Datas passadas não podem ser alteradas nem iniciadas | Calendário | Guardas parciais existem | Botão inativo e chamada de domínio rejeitada | Histórico imutável |
| CAL-09 | PPP 133 | Treino programado passado e não concluído fica vermelho | Calendário | Regra visual existe | Golden de ontem pendente e concluído | Não depender só da cor; incluir estado acessível |
| CAL-10 | Solicitações atuais | Ao abrir treino, scores e percentuais começam zerados e amarelos | Execução | Precisa cobertura | Golden antes da primeira série | Depois usa comparação histórica |
| CAL-11 | Solicitações atuais | Registrar série é imediato no local e relatório surge ao concluir o exercício | Execução | Relatos de lentidão | Medir atualização local sem aguardar rede | Sync roda em segundo plano |
| CAL-12 | Solicitações atuais | Popup e lista expandida carregam última carga e repetições por série | Execução e calendário | Parcial e lento | Último treino com séries distintas preenche cada posição | Ausência de histórico usa estado “nunca registrado” |
| CAL-13 | Solicitações atuais | Relatório compara cada série atual com a correspondente anterior | Relatório do exercício | Não provado | Exibir carga, repetições, score e percentual por série | Não limitar percentual a `100+` |
| CAL-14 | Solicitações atuais | Cores: nunca registrado azul; igual amarelo; maior verde; menor vermelho | Exercício e conclusão | Inconsistente | Testes unitários e goldens para quatro estados | No início, amarelo e zero prevalecem |
| CAL-15 | Solicitações atuais | Concluir treino persiste uma vez e não reabre em andamento | Execução | Relato de regressão | Concluir offline, fechar e reabrir uma vez | Estado terminal não retrocede |
| CAL-16 | Solicitações atuais | Treino concluído não aparece momentaneamente como pausado | Execução | Relato de estado transitório | Teste de stream sem emissão “pausado” após concluir | Transação única para estado terminal |
| CAL-17 | Solicitações atuais | Modal nunca fica em loading infinito; conteúdo local aparece primeiro | Calendário | Relato de loading infinito | Simular Supabase indisponível e abrir treino | Erro remoto não esconde snapshot local |
| CAL-18 | Solicitações atuais | Percentual do topo não ultrapassa a borda com valores grandes | Modal concluída | Relato de overflow | Golden com 3 e 4 dígitos antes da vírgula | Layout responsivo, sem truncar valor real |

## Interface, desempenho e acessibilidade

| ID | Fonte | Exigência | Tela ou regra | Situação atual | Prova de aceite | Conflito ou padrão sugerido |
|---|---|---|---|---|---|---|
| UX-01 | PPP 15 | Barra inferior: Performance, Calendário, Planejamento e Cadastro da esquerda para a direita | Navegação | Ordem atual corresponde | Widget test de ordem e visibilidade | Preservar ordem |
| UX-02 | Mestre 1.1; PPP 115 | Todo modal ocupa 93% e fecha arrastando para baixo | Todas as modais | Helper usa 93%, há exceções menores | Medir todas as modais | Remover exceções somente após golden |
| UX-03 | Mestre 2; PPP 113 | Listas exigidas aparecem em ordem alfabética | Listas | Ordenação não é uniforme para acentos | Teste com A, Á, E, É e caixa mista | Chave sem acento sem mudar texto exibido |
| UX-04 | PPP 123 | Cards editáveis têm swipe à esquerda, editar e excluir com confirmação | Listas | Componente existe, cobertura parcial | Teste por lista editável | Não impor em listas somente leitura |
| UX-05 | PPP 117; solicitações atuais | Splash e carregamentos não bloqueiam indefinidamente | App e telas | Relatos de lentidão e travamento | Perfis com rede lenta e sem rede | Mostrar local imediatamente e erro recuperável |
| UX-06 | PPP 87-89 | Performance mostra rendimento, score, tempo e melhores resultados | Performance | Tela existe | Datasets vazio e populado | “Melhor treino” ainda precisa regra, ver D06 |
| UX-07 | PPP 91-96 | Configurações incluem senha, conta, logs e copiar | Configurações | Itens existem | Teste por perfil | Auditoria de saúde fica apenas no servidor |
| UX-08 | Mestre Fase 5; apple-design | Cores semânticas, Dynamic Type, contraste e alvos de toque | UI inteira | Auditoria futura | Contraste 4,5:1 texto, 3:1 ícones; 44x44 pt | Respeitar iOS e Android, sem impor aparência única |
| UX-09 | Mestre Fase 5 | Preservar duração e curva das animações | UI inteira | Linha de base ausente | Goldens e testes de animação | Fundo animado exige decisão antes de remover |
| PERF-01 | Solicitações atuais | App permanece responsivo após uso prolongado | UI e streams | Relatos de degradação | Perfil de 30 minutos, contagem de rebuilds, timers e subscriptions | Nenhum polling/rebuild desnecessário |
| PERF-02 | Solicitações atuais | Reduzir consumo de bateria e aquecimento | Sync, timers e animações | Não medido | Energy Log/Profiler em sessão representativa | Pausar trabalho quando app está em background |

## Pontuação, papéis, planos e autenticação

| ID | Fonte | Exigência | Tela ou regra | Situação atual | Prova de aceite | Conflito ou padrão sugerido |
|---|---|---|---|---|---|---|
| SCORE-01 | PPP 129 | Score da série = carga x repetições | Série | Código atual usa divisor adicional | 20 kg x 10 = 200 | Documento prevalece após aprovação |
| SCORE-02 | PPP 129 | Score do exercício = soma dos scores das séries | Exercício | Diverge do código atual | Séries 200 e 150 resultam 350 | Sem normalização não documentada |
| SCORE-03 | PPP 131 | Score do treino = soma dos scores dos exercícios dividida pelo tempo total ativo | Treino | Código atual aplica fatores adicionais | Soma 600 em 30 minutos resulta 20 | Unidade de tempo: minutos, ver D01 |
| ACL-01 | PPP 102-105; AP 72-88 | Papéis Admin, Personal e Aluno; planos são dimensão separada | Autorização | Papéis e tiers existem | Matriz papel x plano x ação | Administrador define ou altera plano |
| ACL-02 | AP 76 | Aluno Free: 30 dias; R$ 9,90 enquanto vinculado; só programa treino do personal | Plano | Cobrança não implementada | Entitlement e isolamento no servidor | Confirmar destino ao desvincular |
| ACL-03 | AP 79 | Aluno Basic: 30 dias; R$ 19,90 uma vez; cadastros próprios; sem catálogo Supabase | Plano | Cobrança não implementada | Teste de recursos e isolamento | Texto de IA é contraditório, ver D07 |
| ACL-04 | AP 82 | Aluno Premium: 30 dias; R$ 14,90 por mês; catálogo e IA | Plano | Cobrança não implementada | Expiração e downgrade no servidor | “Aluno Standard” indefinido, ver D02 |
| ACL-05 | AP 84 | Personal Starter: 30 dias; R$ 29,90 por mês; até 3 alunos; sem catálogo | Plano | Limite existe parcialmente | Quarto aluno rejeitado pelo servidor | Texto de IA é contraditório, ver D07 |
| ACL-06 | AP 86 | Personal Pro: 30 dias; R$ 59,90 por mês; até 10 alunos; sem catálogo | Plano | Limite existe parcialmente | Décimo primeiro aluno rejeitado | Texto de IA é contraditório, ver D07 |
| ACL-07 | AP 88 | Personal Pro+: 30 dias; R$ 79,90 por mês; alunos ilimitados; IA ilimitada | Plano | Código permite catálogo, documento nega | Teste de entitlement por recurso | Documento prevalece, ver D08 |
| AUTH-01 | Mestre 1.5, Fase 1; AP 90; PPP 109 | Convite e primeiro acesso seguros | Autenticação | Documentos antigos pedem senha visível | Teste de convite sem senha no cliente | Prompt mestre proíbe gerar ou mostrar senha |
| AUTH-02 | Mestre Fase 4; AP 90 | Biometria opcional, desligada por padrão | Configurações e login | Suporte parcial | Ativar, reiniciar e desativar | Não substituir credenciais do Supabase |
| AUTH-03 | Mestre Fase 4 | Universal Links/App Links, PKCE e state | Login e recuperação | Implementação parcial | Links verificados em iOS e Android | Remover `apppersonal://` do auth |

## Fase 0 e rastreabilidade

| ID | Fonte | Exigência | Situação inicial em 4 nov 2026 | Prova de aceite |
|---|---|---|---|---|
| F0-01 | Mestre 3.1 | Matriz entregue e confirmada antes de código | Este documento entrega; confirmação pendente | Aprovação explícita do usuário |
| F0-02 | Mestre 3.2 | Preservar tudo em branch, commits separados e tag | `main` 4 commits à frente; muitas alterações soltas; branch/tag ausentes | Árvore limpa na branch e tag válida |
| F0-03 | Mestre 3.3 | Exemplos sem valores reais; nenhum segredo versionado | `dart_defines.prod.example.json` contém chave de formato real | Gitleaks local e histórico retornam zero |
| F0-04 | Mestre 3.4 | Estrutura Supabase CLI e SQL legado não executável | `supabase/` ausente; SQL aberto em `scripts/` | `supabase db reset` e busca de SQL inseguro |
| F0-05 | Mestre 3.5 | Exportar cada tabela atual para JSON | Script ausente | JSON válido por tabela, sem credencial no arquivo |
| F0-06 | Mestre 3.6 | CI com formato, análise, testes, cobertura, gitleaks e bloqueio de SQL aberto | Workflows ausentes | Jobs verdes |
| F0-07 | Mestre 3.7 | Dependências necessárias com versões fixas e justificativa | `uuid` direto; `package_info_plus` transitivo; demais ausentes | Inventário e `pubspec.lock` reproduzível |
| F0-08 | Mestre 3 | Não perder o trabalho atual | Mudanças rastreadas e não rastreadas misturam áreas | Bundle, patch, arquivo dos não rastreados e hashes antes dos commits |

## Decisões pendentes

| ID | Pergunta | Padrão sugerido se não houver resposta |
|---|---|---|
| D01 | O tempo da fórmula do score do treino é contado em minutos ativos? | Sim, minutos ativos, ignorando pausas |
| D02 | Qual plano é o “Aluno Standard” citado no downgrade do Premium? | Tratar como Aluno Free, sem alterar os demais preços |
| D03 | O e-mail do aluno é opcional? | Opcional para ficha sem acesso; obrigatório para usuário convidado ao app |
| D04 | Pode programar treino que não foi disponibilizado naquela semana? | Não; usar apenas treino válido da semana |
| D05 | Pode adicionar exercício depois de registrar a primeira série? | Sim, somente no snapshot daquele treino; não editar ou excluir os existentes |
| D06 | Como definir “melhor treino” na Performance? | Maior score do treino conforme SCORE-03 |
| D07 | Basic, Starter e Pro são “sem IA”, apesar da frase sobre relatório bimestral? | Sem IA; considerar a frase de relatório um erro do documento |
| D08 | Personal Pro+ acessa o catálogo de exercícios do Supabase? | Não, conforme o texto literal do plano |
| D09 | SQL legado inseguro pode ser arquivado como `.sql.disabled`? | Sim, com aviso “NÃO EXECUTAR” e checksum; só migrations seguras permanecem `.sql` |
| D10 | Plataformas prioritárias após SQLCipher e tarefas em segundo plano? | iOS e Android; preservar web/desktop sem prometer paridade criptográfica nesta refatoração |

## Regras de ouro confirmadas nesta elaboração

1. Nenhuma tela, fluxo, modal, popup, texto ou animação foi alterado.
2. Nenhuma escrita funcional ou de banco foi feita.
3. Nenhuma decisão de conflito foi baseada no relógio do aparelho.
4. Nenhum dado existente foi apagado, movido ou sobrescrito.
5. Nenhum segredo foi adicionado ao projeto.
6. Nenhum remendo temporal foi criado.
7. A matriz não usa placeholders de conteúdo.
8. Os termos foram redigidos em português do Brasil.
9. As ambiguidades estão listadas com padrões sugeridos, sem aplicação automática.
