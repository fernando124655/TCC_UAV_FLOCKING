# Verificação formal (Apêndice C do artigo)

Modelos e saídas das verificações resumidas na tabela "Verificação e validação dos modelos" do Apêndice C. As redes de Petri foram analisadas com a **TINA 4.0.0** e o modelo de isolamento com o **NuSMV 2.7.1**. Os arquivos `saida_*.txt` são as saídas obtidas em 08/10/2026, guardadas ao lado de cada modelo para conferência.

| pasta | modelo | seção do artigo |
|---|---|---|
| `rede_petri/` | ciclo de uma geração do AG: *pool* de 6 *workers* e barreira de N candidatos | Apêndice C.1, Figura da rede de Petri e Equações dos invariantes |
| `guarda_despacho/` | guarda de *timestamp* dos arquivos de despacho, nas três variantes | Apêndice C.1, parágrafo da escrita simultânea |
| `bpmn/` | o BPMN do protocolo (seção 4.1) traduzido numa rede de fluxo de trabalho | Apêndice C.2 |
| `isolamento_workers/` | isolamento dos arquivos de parâmetros entre os 6 *workers* | Apêndice C.1 e C.2 |

---

## Como rodar

**TINA 4.0.0** — <https://projects.laas.fr/tina/download.php> (Linux, macOS e Windows). Os comandos abaixo são os mesmos nos três sistemas; no Windows, rode-os no Prompt de Comando, na pasta `bin` da TINA, com o caminho completo dos arquivos.

```
# ciclo da geração
tina -R -q -NET rede_petri/ga_n30.net
tina -R -q -NET rede_petri/ga_n28.net
tina -R -q -NET rede_petri/ga_semliberacao_n30.net
struct -NET rede_petri/ga_n30.net                 # P- e T-invariantes

# BPMN
tina -R -q -NET bpmn/bpmn_wf.net
tina -R -q -NET bpmn/bpmn_wf_curto.net

# guarda dos despachos (repita para guarda_sem_aquecimento e guarda_semaforo)
tina -R -q -NET guarda_despacho/guarda_com_aquecimento.net
tina -NET guarda_despacho/guarda_com_aquecimento.net guarda_despacho/guarda_com_aquecimento.ktz
selt -c guarda_despacho/guarda_com_aquecimento.ktz guarda_despacho/props.ltl
```

O `selt`, o verificador de fórmulas da TINA, responde TRUE ou FALSE para cada fórmula de `props.ltl`; quando a resposta é FALSE, mostra a sequência de disparos que leva à marcação proibida.

Para ver qual é a marcação morta de uma rede, rode a TINA sem `-q` (por exemplo, `tina -R -NET rede_petri/ga_semliberacao_n30.net`), procure a linha `dead marking(s):` e, na lista `MARKINGS:`, a marcação com esse número.

**NuSMV 2.7.1** — <https://nusmv.fbk.eu/downloads.html>.

```
NuSMV isolamento_workers/isolamento_workers.smv
```

---

## Resultados

| modelo | propriedade | resultado (saída) |
|---|---|---|
| `ga_n30.net` | limitada, viva, reversível, sem *deadlock* | verdadeiras: 757 marcações, nenhuma morta (`saida_tina_ga_n30.txt`) |
| `ga_n28.net` | idem, com N = 28 | verdadeiras: 701 marcações, nenhuma morta (`saida_tina_ga_n28.txt`) |
| `struct` sobre `ga_n30.net` | invariantes das duas equações do Apêndice C | reproduzidos: `EscritaConcluida + SimulacaoEmCurso + WorkerOcioso = 6` e `CandidatoPendente + EscritaConcluida + 30·GeracaoPronta + ResultadoRegistrado + SimulacaoEmCurso = 30`; um T-invariante, o ciclo de uma geração (`saida_struct_ga_n30.txt`) |
| `ga_semliberacao_n30.net` | sem *deadlock*, com o *worker* retido até o fim da geração | falsa: 1 marcação morta entre 85, `CandidatoPendente*24 ResultadoRegistrado*6 WorkerRetido*6` (`saida_tina_ga_semliberacao_n30.txt`) |
| `guarda_sem_aquecimento.net` | nenhuma escrita concorrente de um despacho | falsa: o `selt` mostra *workers* escrevendo o mesmo despacho; 35 marcações (`saida_selt_guarda_sem_aquecimento.txt`) |
| `guarda_semaforo.net` | idem, com a guarda como semáforo | verdadeira; 10 marcações (`saida_selt_guarda_semaforo.txt`) |
| `guarda_com_aquecimento.net` | idem, com aquecimento antes do *pool* (o que o código faz) | verdadeira; nenhum *worker* ativo com a guarda aberta (TRUE); `AtravessarGuarda` é transição morta; 9 marcações (`saida_selt_guarda_com_aquecimento.txt`) |
| `bpmn_wf.net` | término adequado: a única marcação morta é o fim; nenhuma tarefa morta | verdadeira: 7.348 marcações, a marcação morta é `o` (`saida_tina_bpmn_wf.txt`, `saida_marcacao_morta_bpmn_wf.txt`) |
| `bpmn_wf_curto.net` | solidez: a rede com a transição `Reinicio` (de `o` para `i`) é viva e limitada | verdadeira: limitada, viva e reversível (`saida_tina_bpmn_wf_curto.txt`) |
| `isolamento_workers.smv` | cada *worker* lê os próprios parâmetros | verdadeira com sufixos distintos; falsa com sufixo comum, com contraexemplo de 3 passos (`saida_nusmv_isolamento.txt`) |

---

## Correspondência com o código

### Ciclo da geração (`rede_petri/`)

| na rede | no código e nos *logs* |
|---|---|
| `WorkerOcioso (6)` | *pool* de 6 *workers* aberto em `codigo/producao/main_auto_tuning_production.m` (linhas 71–72) |
| `DistribuirGeracao` e `FecharGeracao` (arcos de peso N) | cada geração do AG é um `parfor` que só termina quando todos os candidatos foram avaliados (barreira) |
| `AvaliarRegistrar` devolve o *worker* | o `parfor` devolve o *worker* ao terminar cada iteração; a variante `ga_semliberacao_n30` retém o *worker* até o fim da geração |
| N = 30 e N = 28 | a população tem 30 indivíduos; os 2 de elite não são reavaliados, e o `Func-count` cresce 28 por geração a partir da segunda (`resultados/logs/log_at_couzin_v3.txt`) |

A rede devolve o *worker* a cada candidato; o `parfor` entrega as iterações em blocos. Nos dois casos, o *worker* não fica retido até a geração fechar, e a conclusão não muda. As fichas da rede são indistinguíveis: os invariantes conservam a **quantidade** de candidatos, não a identidade (Apêndice C.1).

### Guarda dos arquivos de despacho (`guarda_despacho/`)

**Aquecimento** é o nome, nos arquivos desta pasta, da regeneração em série dos arquivos de despacho no cliente, antes de abrir o *pool*: `prepare_parallel_safe(xml_list)`, na linha 68 de `main_auto_tuning_production.m`. Depois dela, os despachos ficam mais recentes que o XML, e a guarda fica fechada durante toda a avaliação paralela.

| na rede | no código |
|---|---|
| `GuardaAberta` / `GuardaFechada` | arquivo de despacho mais antigo / mais recente que o XML: as três guardas de *timestamp* de `read_parameter_xml.m`, comentadas no CoFlyers e ativadas neste trabalho (ver "Arquivos da plataforma modificados" no README principal) |
| arco de teste `GuardaAberta?1` | a guarda é um predicado: o *worker* que a lê não a consome, e vários podem atravessá-la ao mesmo tempo |
| `AtravessarGuarda` → `EscrevendoDespacho` | reescrita do arquivo de despacho |
| `ConcluirEscritaFechando` | ao terminar a escrita, o arquivo fica mais recente que o XML |
| `AquecerNoCliente` | `prepare_parallel_safe(xml_list)` (linha 68) |
| `IniciarAvaliacaoParalela` (produz `WorkerOcioso*6`) | abertura do *pool* (linhas 71–72) e início do `parfor` |
| fórmula `corrida` de `props.ltl` | dois *workers* escrevendo o mesmo despacho, ou um executando o despacho enquanto outro o escreve: a falha registrada em `resultados/logs/log_at_Couzin.txt` (linha 148, "Execution of script swarm_module_generate_desire as a function is not supported") |

### Isolamento dos arquivos de parâmetros (`isolamento_workers/`)

Cada *worker* grava os parâmetros do seu candidato num arquivo com o sufixo do índice da tarefa e depois o lê para simular. A variante `pool = threads` do modelo representa a perda desse sufixo (todos os *workers* no mesmo arquivo), e não o comportamento real sob um *pool* de *threads*: no MATLAB R2026a, sob *threads*, `getCurrentTask` lança exceção, e a falha seria explícita.

### BPMN (`bpmn/`)

Tradução pelo mapeamento de Dijkman, Dumas e Ouyang (2008):

| elemento do BPMN | na rede |
|---|---|
| evento de início / de fim | lugares `i` e `o` |
| subprocesso multi-instância paralelo (×4, um por algoritmo) | `Inicio` (`i → Instancia*4`) e `ConcluirInstancias` (`InstanciaConcluida*4 → ProntoAnalise`) |
| tarefas "Preparar e testar o módulo", "Calibrar parâmetros" e "Aplicar parâmetros ótimos" | `PrepararTestarModulo`, `CalibrarParametros`, `AplicarParametros` |
| *gateways* paralelos de divisão e de junção | `SplitParalelo` e `JoinParalelo` |
| "Prototipação rápida" e "Processamento em lote" | `PrototipacaoRapida` e `ProcessamentoLote` |
| "Alta fidelidade", com as mensagens UDP | `HF_PreVooEnvia`, `HF_Recebe`, `HF_Continua`, `HF_Encerra` e os lugares `MsgComando` e `MsgEstado` |
| *pool* caixa-preta do Simulator | `Simulator_Responde` (`MsgComando → MsgEstado`): um ambiente que sempre responde |
| "Analisar e testar hipóteses" | `AnalisarHipoteses` |

Cada tarefa corresponde a artefatos do repositório: os módulos em `codigo/modulos/`; a calibração em `main_auto_tuning_production.m`, `prepare_paired_xmls.m`, `prepare_parallel_safe.m` e `fitness_paired_configs.m`; a aplicação dos parâmetros em `xml_set_param_in_block.m`; o Monte Carlo em `main_monte_carlo_rapid_prototyping.m`; o lote em `main_batch_production.m`; a alta fidelidade em `preparar_hifi.m`, `verificar_hifi.m`, `salvar_hifi.m`, `build_hifi_launches.m` e nos lançamentos de `pc_b/`; e a análise em `codigo/analise/`. A ordem das execuções nos *logs* — as quatro calibrações entre 29/07 e 09/08/2026, o Monte Carlo em 11 e 14/08, o lote de 17 a 21/08 e a alta fidelidade depois de 20/08 — é uma das sequências que o modelo aceita.

---

## Limites

- As redes não têm tempo: provam que cada geração termina, não quanto demora.
- O Simulator entra no BPMN como um ambiente que sempre responde; a perda de pacotes UDP fica fora da verificação.
- A rede da guarda não modela uma edição do XML durante a execução, que reabriria a guarda; o efeito seria o mesmo de chamar a otimização sem o aquecimento.
- Nenhum modelo verifica se o `map3d_struct` do Commander e o mundo do Gazebo descrevem a mesma arena.
- As propriedades valem para os modelos. A correspondência com o código foi validada por rastreabilidade, nas tabelas acima.

## Referências

- BERTHOMIEU, B.; RIBET, P.-O.; VERNADAT, F. The tool TINA – construction of abstract state spaces for Petri nets and time Petri nets. *International Journal of Production Research*, v. 42, n. 14, p. 2741-2756, 2004.
- CIMATTI, A. et al. NuSMV 2: an opensource tool for symbolic model checking. In: *Computer Aided Verification (CAV 2002)*. Berlin: Springer, 2002. p. 359-364.
- DIJKMAN, R. M.; DUMAS, M.; OUYANG, C. Semantics and analysis of business process models in BPMN. *Information and Software Technology*, v. 50, n. 12, p. 1281-1294, 2008.
- VAN DER AALST, W. M. P. Verification of workflow nets. In: *Application and Theory of Petri Nets 1997*. Berlin: Springer, 1997. p. 407-426.
