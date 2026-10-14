# Análise Comparativa de Algoritmos de Flocking para Enxames de UAVs em Ambientes Indoor Confinados

Repositório de código, configuração e resultados de uma dissertação de conclusão de curso que compara quatro algoritmos canônicos de flocking sob condições experimentais idênticas, usando a plataforma CoFlyers.

---

## O estudo

### Pergunta de pesquisa

Como o desempenho de algoritmos de flocking varia em função da complexidade paramétrica e da arquitetura matemática, em ambientes indoor confinados, e como esse desempenho se transfere da simulação idealizada para a simulação de alta fidelidade?

### Algoritmos comparados

| algoritmo | referência | parâmetros otimizados | classe arquitetural |
|---|---|---|---|
| Couzin | Couzin et al. (2002) | 5 | prioridade lexicográfica |
| Reynolds | Reynolds (1987) | 6 | heurística ponderada |
| Olfati-Saber | Olfati-Saber (2006) | 7 | potencial suave |
| Vasárhelyi | Vasárhelyi et al. (2018) | 11 | curva de frenagem |

### Hipóteses

- **H1-A** — maior complexidade paramétrica leva a melhor desempenho após otimização.
- **H1-B** — maior complexidade paramétrica leva a menor robustez sob perturbação.
- **H2-A** — a arquitetura matemática determina o tipo de falha de segurança.
- **H2-B** — a arquitetura determina a *reality gap* mais que a complexidade paramétrica.

---

## Arquitetura experimental

Dois computadores, comunicando por UDP em rede local.

**PC-A (Commander)** executa a camada superior de controle — algoritmos de flocking, módulo de ruído e módulo de avaliação — em MATLAB/Simulink, e envia comandos de alto nível.

**PC-B (Simulador)** executa PX4-SITL e Gazebo dentro de um contêiner Docker, simulando a dinâmica dos quadrotores e o controle de baixo nível.

A propriedade central dessa divisão é o **reuso de código**: o mesmo arquivo `.m`, que contém a lógic de cada algoritmo, roda nas quatro etapas do pipeline, da prototipagem rápida à alta fidelidade. Isso dá validade à medição de *reality gap* — a diferença observada entre etapas não pode ser artefato de reimplementação, porque não há duas lógicas implementadas.

---

## Pipeline de quatro etapas

| etapa | o que mede | volume executado |
|---|---|---|
| **Rapid Prototyping** | comportamento sob configuração inicial dada | 20 execuções × 4 algoritmos × 3 ambientes |
| **Auto-tuning** | melhor conjunto de parâmetros por algoritmo | 5 sementes × (população 30 × 30 gerações), Nr = 3 |
| **Batch Processing** | robustez a tempo de amostragem e ruído | grade 26×26 × 3 repetições × 4 algoritmos × 2 ambientes |
| **High-Fidelity** | desempenho sob dinâmica realista de quadrotor | 5 execuções × 4 algoritmos × 3 ambientes |

### Ambientes

Arena de 60 × 60 m com 10 drones, `v_flock` = 1,0 m/s, em três configurações: **vazia**; com **4 cilindros** de 6 m de diâmetro; e com **4 cubos** de 6 m de lado. Os obstáculos ficam em (±12, ±12), deixando corredores de 18 m.

**A calibração foi feita apenas na arena vazia.** Os ambientes com obstáculos constituem teste de generalização — nenhum parâmetro foi reotimizado neles.

---

## Protocolo de reprodutibilidade

Toda a estocasticidade é controlada por sementes fixadas **antes** da execução dos experimentos, em conjuntos **disjuntos**:

| conjunto | valores | função |
|---|---|---|
| treino do auto-tuning | 101, 102, 103 | configurações sobre as quais o GA otimiza |
| teste do Monte Carlo | 1 a 20 | configurações de avaliação |
| repetições do batch | 201, 202, 203 | configurações das três repetições |
| multi-start do GA | 1 a 5 | população inicial e operadores genéticos |
| alta fidelidade | 1 a 5 | posições iniciais, pareadas com o Monte Carlo |

Três propriedades decorrem disso. **Reprodutibilidade**: mesma semente, mesmo resultado. **Pareamento**: as configurações dependem só da semente, nunca do algoritmo, então os quatro enfrentam os mesmos cenários e os testes estatísticos podem ser pareados. **Separação treino/teste**: nenhuma configuração de calibração aparece na avaliação.

O determinismo da função-objetivo foi verificado empiricamente: o mesmo vetor de parâmetros avaliado duas vezes retorna valor idêntico até o último dígito.

*Limitação:* na etapa de alta fidelidade, as sementes controlam apenas as posições iniciais. Gazebo e PX4 possuem fontes próprias de estocasticidade que não passam pelo gerador do MATLAB (normrnd).

---

## Estrutura do repositório

```
pc_a/
├── codigo/                    scripts de produção e de análise
├── xml_config/                configurações dos três ambientes
├── modulos_algoritmos/        implementação dos quatro algoritmos
├── logs/                      saída textual de todas as execuções
├── graficos/                  60 painéis das execuções de alta fidelidade
├── docs/                      inventário e documentação de metodologia
└── metricas_high_fidelity.csv  métricas das 60 execuções

pc_b/
├── launch_gazebo/             launches do Gazebo, pareados por semente
├── launch_ros/                launches da ponte ROS, pareados por semente
├── worlds/                    mundos Gazebo dos três ambientes
└── docs/                      inventário do ambiente de execução
```

### Sobre os dados brutos

Os arquivos `.mat` das simulações **não** estão versionados. São cerca de 160 MB e **regeneráveis**: com o código, as configurações e as sementes documentadas acima. O arquivo `metricas_high_fidelity.csv` contém os resultados extraídos.

Disponíveis mediante solicitação, ou versionáveis via Git LFS se necessário.

---

## Reprodução

```matlab
% 1. Calibração (arena vazia), ~36 h por algoritmo
main_auto_tuning_production('Couzin', 1:5)

% 2. Aplicar os parâmetros encontrados
xml_set_param_in_block('xml_config_files\parameters.xml', 'Couzin', ...
    {'r_r','r_o','r_a','r_shill','w_shill'}, x_final);

% 3. Avaliação estatística, ~10 min por algoritmo
main_monte_carlo_rapid_prototyping('Couzin')

% 4. Robustez a perturbações, ~8 h por algoritmo
main_batch_production('Couzin', 'vazia')

% 5. Alta fidelidade — requer os dois computadores
preparar_hifi('Couzin', 'cubos')     % verificação pré-voo no PC-A
% no PC-B: roslaunch px4 hifi_cubos_seed1.launch
%          roslaunch px4_sitl_coflyers node_cubos_seed1.launch
salvar_hifi('Couzin', 'cubos', 1)

% 6. Análises
analyze_monte_carlo('vazia')
analyze_generalization()
analyze_batch()
analyze_hifi()
```

O `verificar_hifi` confere sete itens de configuração antes de cada bloco de execuções presenciais — algoritmo ativo, mapa correspondente, geração de shill agents, modo de simulação, endereçamento de rede, parâmetros aplicados e número de drones.

---

## Síntese dos resultados

**H1-A refutada, com sinal invertido.** O algoritmo de 6 parâmetros obtém o melhor alinhamento; o de 11 fica em último. Correlação de Spearman entre número de parâmetros e φ_corr: ρ = −0,80.

**H1-B sustentada.** Os dois algoritmos mais simples são os mais robustos à mudança de ambiente. ρ = +0,60.

**H2-A sustentada.** Cada arquitetura apresenta um tipo característico de violação de segurança, estável entre três geometrias e dois níveis de fidelidade: Couzin colide entre drones, Reynolds sai da arena, Olfati-Saber penetra fronteiras, Vasárhelyi não viola nada em 100 execuções.

**H2-B sustentada por via negativa.** A complexidade paramétrica não prediz a *reality gap* de forma estável — a correlação inverte de sinal conforme o ambiente. A ordenação arquitetural, por outro lado, repete-se entre geometrias.

**Achado adicional.** A *reality gap* dos algoritmos com mecanismo de frenagem ordena-se segundo a geometria da superfície (arena vazia → cilindros → cubos), enquanto os demais permanecem estáveis. Faces planas exigem frenagem frontal sem guia lateral; superfícies curvas oferecem componente tangencial que permite contornar sem desacelerar.

---

## Ambiente de software

**PC-A** — Windows 11; MATLAB R2026a com Simulink, Global Optimization Toolbox, Parallel Computing Toolbox e Statistics and Machine Learning Toolbox.

**PC-B** — Ubuntu 24.04; Docker; PX4-Autopilot SITL v1.12.3; Gazebo Classic 11; ROS Noetic; MAVROS.

**Plataforma** — CoFlyers v3.0.0 (Huang, Wang & Hu, IROS 2023), licença GPL-3.0. Repositório original: github.com/micros-uav/CoFlyers

## Arquivos da plataforma modificados

Este trabalho usa o CoFlyers v3.1.3 (ramo `main`, commit `ac9e6e5`). Os arquivos abaixo são da plataforma e foram alterados. Os demais arquivos da plataforma estão como no repositório original. Os arquivos criados neste trabalho (módulos dos algoritmos, scripts de produção e de análise) estão em `codigo/`.

Caminhos relativos a `matlab_simulink_ws/Prototype_Simulator/`:

| arquivo | alteração | motivo | registro |
|---|---|---|---|
| `utils/xml_read/read_parameter_xml.m` | ativadas as três guardas de *timestamp*, que vêm comentadas no original, em `write_swarm_module_generate_desire`, `write_evaluation_module_one` e `write_evaluation_module_average` | impedir a reescrita concorrente dos arquivos de despacho no auto-tuning paralelo; usada com `prepare_parallel_safe.m`, que regenera esses arquivos no cliente antes de abrir o *pool* | `resultados/logs/log_at_couzin_resume.txt`; cópia de segurança `read_parameter_xml_BACKUP.m` |
| `lower_layers/evaluation_module/evaluation_0_module/utils/fitness_function_combine.m` | termo de velocidade da *fitness*: `heaviside(phiVel)*phiVel` → `fitness_function_1(phiVel, vFlock, vTol)` | restaurar a forma limitada F1 de Vásárhelyi et al. (2018), que satura em 1 | `resultados/logs/log_at_couzin_v2.txt` (29/07/2026); cópia de segurança `fitness_function_combine_BACKUP.m` |
| `lower_layers/evaluation_module/evaluation_0_module/evaluation_0_module_average.m` | `v_tol = 0` → `v_tol = 1.5/4 * v_flock` | tolerância de velocidade de Vásárhelyi et al. (2018), exigida pela F1 | cópia modificada em `codigo/modulos/`; cópia de segurança `evaluation_0_module_average_BACKUP.m` |
| `xml_config_files/parameters*.xml` | blocos `<Couzin>`, `<Reynolds>` e `<OlfatiSaber>`; parâmetros calibrados; arena, obstáculos e posições iniciais | configuração do estudo | cópias em `codigo/xml/` |

Conferidos contra o original e **não** modificados: `lower_layers/swarm_module/Vasarhelyi_module/Vasarhelyi_module_generate_desire.m` e `lower_layers/evaluation_module/evaluation_0_module/evaluation_0_module_one.m` (as cópias em `codigo/modulos/` são idênticas às do CoFlyers v3.1.3).

No PC-B, o nó `px4_node.cpp` do pacote `px4_sitl_coflyers` não foi alterado. Os arquivos de lançamento gerados para cada semente estão em `pc_b/`.

<!--
==========================================================================
COMO USAR ESTE ARQUIVO (apague este bloco depois)

1. No GitHub, abra o README.md do repositório TCC_UAV_FLOCKING.
2. Clique no lápis ("Edit this file").
3. Cole a seção acima logo depois da seção "## Ambiente de software".
4. Confira a última pendência abaixo e clique em "Commit changes".

Pendência que só você confirma:
- Você alterou o testControlWithDroneSwarm.slx (comandante Simulink) ou
  algum outro arquivo da plataforma que não aparece na tabela? Se sim,
  acrescente uma linha.

Sugestão: copie os três arquivos .m modificados para uma pasta
codigo/plataforma_modificada/. Hoje o fitness_function_combine.m e o
read_parameter_xml.m modificados só existem na sua instalação, e a
reprodução depende deles.

Outras correções que encontrei no README:
- "Plataforma — CoFlyers v3.0.0" → v3.1.3 (a interface com terrain e
  terrain_params só existe no ramo main).
- A seção "Estrutura do repositório" descreve pastas que não existem
  (pc_a/, xml_config/, modulos_algoritmos/, graficos/). As reais são
  codigo/, dados/, resultados/, docs/ e pc_b/.
- "Sobre os dados brutos" diz que os .mat não estão versionados, mas eles
  estão no repositório via Git LFS (pasta dados/).
- metricas_high_fidelity.csv tem 59 linhas de dados, não 60: falta
  couzin, cilindros, semente 4 (o .mat existe). Reexporte o CSV.
- "Vasárhelyi não viola nada em 100 execuções": são 75 (60 no Monte
  Carlo e 15 na alta fidelidade).
- A "Síntese dos resultados" diz que a H1-B foi sustentada. Os dados do
  lote mudam essa leitura (ver o roteiro da seção 5 de 12/10).
==========================================================================
-->

## Arquivos de configuração das arenas (leia antes de rodar)

**O `parameters.xml` não é a arena vazia.** O `preparar_hifi.m` copia o XML do ambiente escolhido sobre o `xml_config_files/parameters.xml` antes de cada bloco de alta fidelidade. O último bloco foi o dos cilindros, em 03/09/2026. Desde então, o `parameters.xml` contém os quatro cilindros, e é essa a versão que está em `codigo/xml/parameters.xml`.

Os scripts de produção abaixo leem o `parameters.xml` e o tratam como arena vazia. Se rodados sem ajuste, eles executam na arena com cilindros, sem nenhum aviso:

| script | onde lê o `parameters.xml` |
|---|---|
| `main_monte_carlo_rapid_prototyping.m` | valor padrão de `xml_original` (linha 34) |
| `main_batch_production.m` | `ambiente = 'vazia'` (linha 52) |
| `prepare_paired_xmls.m` (calibração) | linha 30 |

### Qual XML corresponde a cada arena

| arena | XML | obstáculos ativos |
|---|---|---|
| vazia | `parameters_vazia_BACKUP.xml` | nenhum |
| cilindros | `parameters_obst_cilindro.xml` | 4 × `cylinder_rough.stl` em (±12, ±12) m |
| cubos | `parameters_obst_cubo.xml` | 4 × `cube.stl` em (±12, ±12) m |

O `parameters_vazia_BACKUP.xml` é idêntico à configuração usada na calibração, no Monte Carlo e no lote de agosto. A comparação foi feita com as cópias de trabalho que o lote gravou (`parameters_bp_<algoritmo>_vazia_r<n>.xml`, de 17 a 19/08). As únicas diferenças são o algoritmo ativo, as posições iniciais e `activate_plot`, que os scripts sobrescrevem em toda execução.

### Para reproduzir a calibração, o Monte Carlo ou o lote na arena vazia

Restaure a arena vazia no `parameters.xml` antes de rodar, a partir da pasta `Prototype_Simulator`:

```matlab
copyfile('xml_config_files\parameters_vazia_BACKUP.xml', 'xml_config_files\parameters.xml');
```

No Monte Carlo, também dá para passar o XML de forma explícita:

```matlab
main_monte_carlo_rapid_prototyping('Vasarhelyi', 'xml_config_files\parameters_vazia_BACKUP.xml');
```

Depois de rodar a alta fidelidade, repita a restauração, porque o `preparar_hifi.m` volta a sobrescrever o `parameters.xml`.

**Conferência rápida:** fora dos comentários, o `parameters.xml` da arena vazia não pode ter nenhuma tag `<stl value=...>`:

```matlab
c = regexprep(fileread('xml_config_files\parameters.xml'), '<!--.*?-->', '');
n = numel(regexp(c, '<stl\s+value', 'match'))   % deve ser 0 na arena vazia
```

A varredura de T<sub>c</sub> em série (`main_tc_sweep_serial.m`) já faz essa conferência sozinha. Ela usa o `parameters_vazia_BACKUP.xml` e o `parameters_obst_cubo.xml`, e para com erro se o número de obstáculos do XML não corresponder à arena pedida.

### Modelo de movimento do simulador protótipo

Todos os XMLs usam `<motion_model_type value="'quadcopter'"/>`, que é o padrão do CoFlyers. A calibração, o Monte Carlo e o lote rodaram com o modelo de quadricóptero do simulador protótipo, e não com o de ponto-massa:
- dinâmica de corpo rígido em 6 graus de liberdade, com resposta de primeira ordem dos motores;
- malhas PID de posição e de velocidade e controlador PD de atitude;
- controladores atuando sobre o estado verdadeiro do veículo, sem sensores nem estimação de estado.
---

## Referências

- Reynolds, C. W. (1987). Flocks, Herds, and Schools: A Distributed Behavioral Model. *SIGGRAPH '87*, 21(4), 25–34.
- Vicsek, T. et al. (1995). Novel type of phase transition in a system of self-driven particles. *Physical Review Letters*, 75(6), 1226–1229.
- Couzin, I. D. et al. (2002). Collective Memory and Spatial Sorting in Animal Groups. *Journal of Theoretical Biology*, 218(1), 1–11.
- Olfati-Saber, R. (2006). Flocking for Multi-Agent Dynamic Systems: Algorithms and Theory. *IEEE Transactions on Automatic Control*, 51(3), 401–420.
- Vasárhelyi, G. et al. (2018). Optimized flocking of autonomous drones in confined environments. *Science Robotics*, 3(20), eaat3536.
- Soria, E., Schiano, F., Floreano, D. (2020). SwarmLab: a MATLAB Drone Swarm Simulator. *IROS 2020*, 8005–8011.
- Huang, J., Wang, F., Hu, T. (2023). CoFlyers: A Universal Platform for Collective Flying of Swarm Drones. *IROS 2023*, 8808–8813.
- Ali, Z. A., Alkhammash, E. H., Hasan, R. (2024). State-of-the-Art Flocking Strategies for the Collective Motion of Multi-Robots. *Machines*, 12(10), 739.

---

## Autoria

Fernando — dissertação de conclusão de curso. Boa Vista, Roraima, Brasil.
