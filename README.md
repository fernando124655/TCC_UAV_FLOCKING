# Análise Comparativa de Algoritmos de Flocking para Enxames de Drones em Arenas Confinadas

Código, configuração e resultados do TCC 2 (formato de artigo) do Bacharelado em Ciência da Computação da UFRR. O trabalho compara quatro algoritmos de *flocking*, calibrados pelo mesmo procedimento, na plataforma CoFlyers.

---

## O estudo

### Questões de pesquisa

- **QP1.** O número de parâmetros calibrados prediz a ordenação de desempenho, segurança e robustez de quatro algoritmos de *flocking* calibrados pelo mesmo procedimento e orçamento, em arenas confinadas com obstáculos?
- **QP2.** Como cada algoritmo se degrada na passagem da simulação idealizada para a de alta fidelidade? (análise exploratória)

### Hipótese (formulada antes dos experimentos, para a QP1)

- **H1-A.** Mais parâmetros elevam o alinhamento após a calibração.
- **H1-B.** Mais parâmetros aumentam a perda de alinhamento sob obstáculos, ruído de velocidade e variação do período de controle.

Com um algoritmo por nível de complexidade, a hipótese é decidida como previsão de ordenação dos quatro, e não como relação entre complexidade e desempenho:

- a H1-A é refutada se, em algum par de níveis adjacentes (5 e 6, 6 e 7, 7 e 11 parâmetros), o algoritmo com mais parâmetros tiver φ<sub>corr</sub> significativamente menor no Monte Carlo da arena vazia (Wilcoxon pareado, α<sub>c</sub> = 0,0083, d<sub>z</sub> ≥ 0,5);
- H1-B é refutada se, em alguma perturbação e arena, a ordem das quedas de φ<sub>corr</sub> não seguir a do número de parâmetros (no período de controle, a ordem do período crítico T<sub>c</sub>\* é a inversa).

Esses critérios foram explicitados depois dos experimentos; a hipótese é anterior a eles. As conclusões valem para estas quatro formulações e as suas implementações.

### Limitações conhecidas dos módulos

Estas escolhas de implementação fazem parte do que se compara e estão declaradas no artigo (seções 4.1 e 5.2.5). Quem reaproveitar os módulos deve conhecê-las:
 
- **Velocidade constante em três módulos.** O Couzin (como no modelo original), o Reynolds e o Olfati-Saber (por escolha de implementação) normalizam o comando na velocidade de referência e só mudam de direção (`Couzin_module_generate_desire.m`, linhas 237-259; `Reynolds_module_generate_desire.m`, linhas 118-148; `OlfatiSaber_module_generate_desire.m`, linhas 266-294). Só o Vásárhelyi, pela curva de frenagem, reduz a velocidade: no Monte Carlo, o seu φ<sub>vel</sub> é de 0,97, 0,80 e 0,72 nas arenas vazia, com cilindros e com cubos, contra 0,99 a 1,02 nos outros três. A frenagem é uma explicação alternativa para a ausência de violações do Vásárhelyi, que este desenho não separa do número de parâmetros.
- **Arena fixa no código do Olfati-Saber.** As paredes (x e y em ±30 m) e os centros dos obstáculos ((±12, ±12) m) estão nas linhas 76 a 98 de `OlfatiSaber_module_generate_desire.m`, e não vêm do `map3d_struct` que a interface entrega. O módulo usa esses valores para separar os *shill agents* de cada obstáculo e para calcular a distância exata a cada parede; os outros três só percebem as paredes pelos *shills*. Em outra arena, essas linhas precisam ser trocadas (ou derivadas do `map3d_struct`).
- **Voo depois da violação.** O simulador protótipo não interrompe o drone que colide ou atravessa uma parede ou um obstáculo, e o φ<sub>corr</sub> do avaliador conta esse voo. O `main_alinhamento_pos_violacao.m` refaz o Monte Carlo e mede o φ<sub>corr</sub> sem ele (ver Reprodução).

### Algoritmos comparados

| algoritmo | referência | parâmetros calibrados | formulação |
|---|---|---|---|
| Couzin | Couzin et al. (2002) | 5 | zonas de repulsão, orientação e atração, com prioridade da repulsão |
| Reynolds | Reynolds (1987) | 6 | soma ponderada de separação, alinhamento e coesão |
| Olfati-Saber | Olfati-Saber (2006) | 7 | potencial entre pares e consenso de velocidade (variante normalizada em velocidade) |
| Vásárhelyi | Vásárhelyi et al. (2018) | 11 | autopropulsão, repulsão e alinhamento pela curva de frenagem |

O módulo do Olfati-Saber integra a aceleração em um passo de T<sub>c</sub> e normaliza o comando na velocidade de referência: o drone não freia. Os resultados sobre ele valem para essa variante, e não para o integrador duplo original. Os ganhos de mescla do Reynolds (0,3) e do Couzin (0,5) são fixos.

---

## Arquitetura experimental

Dois computadores, que se comunicam por UDP em rede local:

- **PC-A (Commander):** executa, em MATLAB/Simulink, os algoritmos de *flocking*, o módulo de ruído e o módulo de avaliação, e envia os comandos de velocidade.
- **PC-B (Simulator):** executa o PX4-SITL e o Gazebo num contêiner Docker, com a dinâmica dos quadricópteros e o controle de baixo nível.

O protocolo foi projetado para que a origem das diferenças fosse identificável: o mesmo arquivo `.m` de cada algoritmo roda em todas as etapas, todos os módulos usam a mesma interface do CoFlyers e paredes e obstáculos são representados pelos mesmos *shill agents*. Há exceções declaradas no artigo (seção 4.1): o Olfati-Saber usa um agente-β por parede e por obstáculo, com as paredes e os centros dos obstáculos fixados no código; o alcance de percepção é calibrado no Couzin e no Olfati-Saber e fixo nos outros dois; os ganhos de mescla diferem; e só o Vásárhelyi pode reduzir a velocidade (ver "Limitações conhecidas dos módulos").

---

## Etapas e execuções

| etapa | o que mede | execuções |
|---|---|---|
| Calibração (algoritmo genético, arena vazia) | parâmetros ótimos de cada algoritmo, com o mesmo orçamento | 5 sementes do AG × 872 avaliações × 4 algoritmos, 3 configurações iniciais por avaliação |
| Monte Carlo (prototipação rápida) | desempenho e perfil de falha nas três arenas | 20 × 4 algoritmos × 3 arenas = 240 |
| Lote paralelo | robustez ao ruído de velocidade η | grade 26 × 26 × 3 repetições = 2.028 por algoritmo e arena, nas arenas vazia e com cubos |
| Varredura de T<sub>c</sub> em série | robustez ao período de controle | 26 valores × 3 configurações × 4 algoritmos × 3 arenas = 936 |
| Ruído na arena com cilindros | robustez ao ruído com cilindros | η = 0 e 0,5 m/s, 156 por algoritmo |
| Ruído por tipo de violação | origem das violações com ruído | 1.440 execuções do lote refeitas (η = 0; 0,02; 0,1 e 0,5 m/s; 30 por algoritmo, arena e nível), avaliadas inteiras e sem os 7 s iniciais |
| Alta fidelidade (PX4-SITL e Gazebo) | lacuna *sim-to-sim* (exploratória) | 5 × 4 algoritmos × 3 arenas = 60 |
| Verificação do orçamento (Vásárhelyi) | se o orçamento igual prejudicou o algoritmo de mais parâmetros | a execução do AG da semente 3 estendida até 67 gerações (parou na 60, com 1.712 avaliações) e Monte Carlo com os parâmetros novos, 20 × 3 arenas |
| Couzin com alcance limitado | efeito do alcance de percepção | Couzin recalibrado com r<sub>o</sub> e r<sub>a</sub> ≤ 20 m (5 sementes do AG × 872 avaliações) e Monte Carlo, 20 × 3 arenas = 60 |
| Validação dos módulos | se os módulos próprios do Couzin, do Reynolds e do Olfati-Saber reproduzem os modelos originais | 74 execuções de 300 s no espaço livre: Couzin com Δr<sub>o</sub> de 0 a 14 m e Δr<sub>a</sub> de 14 m (9 valores) ou de 2 m (4 valores), 3 sementes; Olfati-Saber com os parâmetros calibrados e com os do artigo original, 5 sementes; Reynolds com os pesos de referência, sem cada uma das regras e calibrado, 5 sementes |

**Defeito do lote paralelo.** No lote, a variação de T<sub>c</sub> não chegou ao simulador: cada *worker* grava a sua cópia das configurações gerais com o sufixo da tarefa, mas o simulador protótipo lê a cópia sem sufixo, com T<sub>c</sub> = 0,1 s. O ruído foi aplicado normalmente. A grade paralela mede, por isso, só a robustez ao ruído, com 78 execuções por nível de η, e a robustez a T<sub>c</sub> vem da varredura em série, em que cada execução confere o período aplicado.

**Transitório de altitude.** Os drones partem a 1 m e descem aos 0,7 m de cruzeiro. Com ruído, nesse transitório (até 6,5 s de voo), parte deles passa abaixo do piso, que o simulador protótipo não trata como sólido. Nas 1.440 execuções, as violações de piso ou teto foram contadas também sem os 7 s iniciais (`resultados/csv/ruido_1440_*.csv`).

### Arenas

Arena de 60 × 60 m com 10 drones e `v_flock` = 1 m/s, em três versões: **vazia**; com **4 cilindros** de 6 m de diâmetro; e com **4 cubos** de 6 m de lado. Os obstáculos ficam em (±12, ±12) m e deixam corredores de 18 m.

**A calibração foi feita só na arena vazia.** As arenas com obstáculos testam a generalização dos parâmetros calibrados, sem nova otimização.

---

## Sementes

Toda a aleatoriedade é controlada por sementes fixadas antes dos experimentos, em conjuntos disjuntos:

| conjunto | valores | função |
|---|---|---|
| treino da calibração | 101, 102, 103 | configurações iniciais em que o AG avalia cada candidato |
| Monte Carlo | 1 a 20 | configurações de avaliação |
| lote, varredura de T<sub>c</sub> e ruído | 201, 202, 203 | configurações das três repetições |
| execuções do lote | 50000 + 10000 × repetição + combinação | ruído de cada execução (mesma regra nas 1.440 refeitas) |
| AG | 1 a 5 | população inicial e operadores genéticos |
| alta fidelidade | 1 a 5 | posições iniciais, pareadas com o Monte Carlo |

O determinismo da função-objetivo foi conferido: o mesmo vetor de parâmetros, avaliado quatro vezes, devolveu o mesmo F.

*Limitação:* na alta fidelidade, as sementes controlam só as posições iniciais. O Gazebo e o PX4 têm fontes próprias de aleatoriedade.

---

## Estrutura do repositório

```
codigo/
├── modulos/       os quatro módulos de flocking e o avaliador usados no estudo
├── producao/      scripts de produção (calibração, Monte Carlo, lote, alta fidelidade)
├── analise/       scripts de análise e de exportação dos CSVs
├── complementares/ scripts das etapas de outubro de 2026 (varredura de Tc, ruído, validação)
└── xml/           configurações das três arenas
dados/
├── auto_tuning/   resultados da calibração (at_*.mat)
├── monte_carlo/   Monte Carlo (mc_*.mat) e monte_carlo_log.csv
├── batch/         lote paralelo (bp_*.mat)
├── tc_sweep/      varredura de Tc em série (tc_*.mat)
├── ruido/         ruído por tipo de violação (rs19_*, rs_Vasarhelyi_* e rsjan_*.mat)
├── couzin_ra20/   Couzin com r_o e r_a ≤ 20 m: calibração, Monte Carlo e logs
├── validacao_modulos/ validação dos módulos: duas execuções com medidas idênticas (validacao_*.mat), resumos e logs
└── high_fidelity/ as 60 execuções de alta fidelidade (hifi_*.mat)
resultados/
├── csv/           métricas de todas as etapas em CSV (ver abaixo)
├── figuras/       painéis das execuções de alta fidelidade
├── logs/          saída textual das execuções
└── metricas_high_fidelity.csv
docs/              documentação de metodologia e histórico
pc_b/PC-B/
├── launch_gazebo/ lançamentos do Gazebo, pareados por semente
├── launch_ros/    lançamentos da ponte ROS, pareados por semente
├── worlds/        mundos do Gazebo das três arenas
└── docs/          inventário do ambiente do PC-B
```

### Dados brutos (.mat)

Os arquivos `.mat` estão versionados com **Git LFS**. Depois de clonar:

```
git lfs install
git lfs pull
```

Sem o `git lfs pull`, os `.mat` ficam como ponteiros de texto de poucos bytes.

### Métricas em CSV (`resultados/csv/`)

| arquivo | conteúdo |
|---|---|
| `calibracao_por_geracao.csv` | melhor F e F médio de cada geração, nas 20 execuções do AG (dos logs da calibração) |
| `calibracao_por_execucao.csv` | F final, melhora entre as gerações 20 e 30 e estagnação de cada execução do AG |
| `couzin_ra20_comparacao.csv` | Couzin com r<sub>o</sub> e r<sub>a</sub> ≤ 20 m contra o original, por arena: F, φ<sub>corr</sub>, φ<sub>vel</sub>, execuções com colisão e comparação com os outros três algoritmos |
| `validacao_modulos.csv` | as 74 execuções da validação dos módulos: p, m, raio do grupo, vizinho mais próximo, d<sub>min</sub>, fração das amostras com colisão, maior grupo e, no Olfati-Saber, vizinho em unidades de d e desvio das ligações |
| `validacao_modulos_resumo.csv` | o resumo da validação por configuração (médias das sementes e desvio-padrão de p e m) |
| `arquivos_usados.csv` | o arquivo `.mat` de origem de cada parte dos CSVs gerados por `exportar_csvs.m` |
| `monte_carlo.csv` | as 240 execuções do Monte Carlo |
| `lote.csv` | o lote paralelo, com o T<sub>c</sub> pedido e o aplicado (0,1 s) |
| `varredura_tc.csv` | as 936 execuções da varredura de T<sub>c</sub> em série |
| `ruido_1440_por_execucao.csv` | as 1.440 execuções com ruído, por tipo de violação, inteiras e sem os 7 s iniciais |
| `ruido_1440_resumo.csv` | o resumo das 1.440 por algoritmo, arena e nível de ruído |
| `../metricas_high_fidelity.csv` | as 60 execuções de alta fidelidade |

 Os CSVs da calibração saem dos logs (`codigo/analise/ler_logs_calibracao.py`); os das 1.440, dos `rsjan_*.mat`; o da comparação do Couzin, de `main_couzin_ra20.m`; os da validação, de `main_validacao_modulos.m`; os demais, de `exportar_csvs.m`, que lê os `.mat` e grava também `arquivos_usados.csv`, com o arquivo de origem de cada parte.

---

## Reprodução

```matlab
% 1. Calibração (arena vazia), de 7 a 8,5 h por semente do AG
main_auto_tuning_production('Couzin', 1:5)

% 2. Aplicar os parâmetros encontrados
xml_set_param_in_block('xml_config_files\parameters.xml', 'Couzin', ...
    {'r_r','r_o','r_a','r_shill','w_shill'}, x_final);

% 3. Monte Carlo
main_monte_carlo_rapid_prototyping('Couzin', 'xml_config_files\parameters_vazia_BACKUP.xml')

% 4. Lote paralelo (mede só o ruído; ver "Defeito do lote paralelo")
main_batch_production('Couzin', 'vazia')

% 5. Alta fidelidade (exige os dois computadores)
preparar_hifi('Couzin', 'cubos')     % conferência antes do voo, no PC-A
% no PC-B: roslaunch px4 hifi_cubos_seed1.launch
%          roslaunch px4_sitl_coflyers node_cubos_seed1.launch
salvar_hifi('Couzin', 'cubos', 1)

% 6. Análises e CSVs
analyze_monte_carlo('vazia')
analyze_generalization()
analyze_batch()
analyze_hifi()
exportar_csvs()

% 7. Sensibilidade ao alcance de percepção (Couzin com r_o e r_a <= 20 m), cerca de 45 h
main_couzin_ra20          % calibração, Monte Carlo e comparação com o original

% 8. Validação dos módulos no espaço livre (74 execuções de 300 s), cerca de 0,5 h
main_validacao_modulos    % grava validacao_*.mat, os CSVs e o log em data_save\validacao_modulos
% A Figura 8 do artigo (Apêndice D) sai de figuras_validacao_modulos, chamada no fim;
% para refazê-la sozinha: figuras_validacao_modulos('data_save\validacao_modulos\validacao_20261101_121846.mat')

% 9. Testes da H1-A (pares adjacentes) e do perfil de falha (McNemar e Clopper-Pearson), a partir dos CSVs
inferencia_monte_carlo('resultados/csv')   % codigo/analise; roda também no GNU Octave

% 10. Alinhamento sem o voo depois das violações (240 execuções do Monte Carlo refeitas), cerca de 2 h
main_alinhamento_pos_violacao             % codigo/complementares, com a pasta avaliador_intactos
% troca o avaliador temporariamente, confere as métricas nativas com os mc_*.mat originais
% e grava data_save\alinhamento_pos_violacao\alinhamento_pos_violacao.csv

```

O `verificar_hifi` confere sete itens antes de cada bloco de execuções de alta fidelidade: algoritmo ativo, mapa, geração dos *shill agents*, modo de simulação, endereçamento de rede, parâmetros aplicados e número de drones.

---

## Síntese dos resultados

- **H1-A refutada.** No par de 6 para 7 parâmetros, o Olfati-Saber tem φ<sub>corr</sub> 0,039 menor que o Reynolds na arena vazia (p = 7,1 × 10<sup>-4</sup>, d<sub>z</sub> = 1,00), também sem as execuções com violação (13 pares, p = 2,4 × 10<sup>-4</sup>, d<sub>z</sub> = 2,15). O Reynolds (6) teve o maior alinhamento nas três arenas, e o Vásárhelyi (11) não difere do Olfati-Saber (p = 0,090). Na prática, a calibração otimizou o alinhamento: como F é a média das três configurações de treino, uma violação em uma só já penaliza o candidato, e o melhor indivíduo de cada algoritmo não teve violações no treino.
- **H1-B refutada.** Nenhuma perturbação ordena os algoritmos pelo número de parâmetros, e o mais frágil muda com a perturbação: o Olfati-Saber na mudança de ambiente e no período de controle; o Reynolds no ruído. O Couzin, o mais simples, é o mais robusto ao ruído e ao período de controle.
- **Perfil de falha.** Com 20 execuções por algoritmo e arena, só dois perfis se distinguem dos demais (McNemar exato, α<sub>c</sub> = 0,0083): as colisões do Couzin, em cada arena (p ≤ 3,9 × 10<sup>-3</sup>), e as invasões de obstáculo da variante do Olfati-Saber (p ≤ 7,6 × 10<sup>-6</sup>). As saídas da arena do Reynolds só se distinguem das do Couzin e das do Vásárhelyi no lote, com η = 0,02 e 0,1 m/s. O Vásárhelyi, o único que reduz a velocidade, não registrou violações: a taxa real é de até 6,0% no Monte Carlo (0 em 60) e de até 1,0% no lote (nenhuma colisão nem violação de parede ou de obstáculo em 360), pelo intervalo de Clopper-Pearson de 95%.
- **Período de controle.** Na variante do Olfati-Saber, a integração da aceleração num único passo seguida da normalização impõe T<sub>c</sub> < v<sub>ref</sub>/a<sub>max</sub> = 0,2 s; acima disso, o enxame oscila em vez de se alinhar.
- **QP2 (exploratória).** Sem obstáculos, a degradação na alta fidelidade foi parecida nos quatro algoritmos; com obstáculos, foi maior nos dois mais sensíveis ao ruído (Reynolds e Vásárhelyi). Com cinco execuções por condição e posições estimadas pelo PX4, isso fica como hipótese.
- **Alcance de percepção.** Com o Couzin recalibrado com r<sub>o</sub> e r<sub>a</sub> ≤ 20 m, o alcance do Reynolds e do Vásárhelyi, os vereditos da H1-A e da H1-B e o tipo de falha do Couzin não mudam. Mudam a vantagem dele sobre o Vásárhelyi na arena vazia, que deixa de ser significativa, e o alinhamento com obstáculos, que cai 0,05 a 0,07; as colisões caem de 9, 12 e 13 para 1, 8 e 7 das 20 execuções, sem diferença significativa após a correção.
- **Validação dos módulos.** No espaço livre, os três módulos próprios reproduzem o comportamento dos modelos originais, com uma exceção: o do Couzin forma o enxame e o grupo paralelo, mas não o toro. O do Olfati-Saber mantém os vizinhos à distância d e, sem agente-γ, se fragmenta, como o primeiro algoritmo do artigo original; no do Reynolds, tirar cada regra tira o seu efeito.

Os números, os testes e as limitações estão no artigo.

---

## Ambiente de software

**PC-A:** Windows 11; MATLAB R2026a com Simulink, Global Optimization Toolbox, Parallel Computing Toolbox e Statistics and Machine Learning Toolbox.

**PC-B:** Ubuntu 24.04; Docker; PX4-Autopilot SITL v1.12.3; Gazebo Classic 11; ROS Noetic; MAVROS.

**Plataforma:** CoFlyers v3.1.3 (Huang, Wang e Hu, IROS 2023), licença GPL-3.0. Repositório original: https://github.com/micros-uav/CoFlyers

## Arquivos da plataforma modificados

Este trabalho usa o CoFlyers v3.1.3 (ramo `main`, commit `ac9e6e5`). Os arquivos abaixo são da plataforma e foram alterados; os demais estão como no repositório original. Os arquivos criados neste trabalho (módulos dos algoritmos, scripts de produção e de análise) estão em `codigo/`.

Caminhos relativos a `matlab_simulink_ws/Prototype_Simulator/`:

| arquivo | alteração | motivo | registro |
|---|---|---|---|
| `utils/xml_read/read_parameter_xml.m` | ativadas as três guardas de *timestamp*, que vêm comentadas no original, em `write_swarm_module_generate_desire`, `write_evaluation_module_one` e `write_evaluation_module_average` | impedir a reescrita concorrente dos arquivos de despacho na calibração paralela; usada com `prepare_parallel_safe.m`, que regenera esses arquivos no cliente antes de abrir o *pool* | `resultados/logs/log_at_couzin_resume.txt`; cópia de segurança `read_parameter_xml_BACKUP.m` |
| `lower_layers/evaluation_module/evaluation_0_module/utils/fitness_function_combine.m` | termo de velocidade da função-objetivo: `heaviside(phiVel)*phiVel` → `fitness_function_1(phiVel, vFlock, vTol)` | restaurar a forma limitada F1 de Vásárhelyi et al. (2018), que satura em 1 | `resultados/logs/log_at_couzin_v2.txt` (29/07/2026); cópia de segurança `fitness_function_combine_BACKUP.m` |
| `lower_layers/evaluation_module/evaluation_0_module/evaluation_0_module_average.m` | `v_tol = 0` → `v_tol = 1.5/4 * v_flock` | tolerância de velocidade de Vásárhelyi et al. (2018), exigida pela F1 | cópia modificada em `codigo/modulos/`; cópia de segurança `evaluation_0_module_average_BACKUP.m` |
| `xml_config_files/parameters*.xml` | blocos `<Couzin>`, `<Reynolds>` e `<OlfatiSaber>`; parâmetros calibrados; arena, obstáculos e posições iniciais | configuração do estudo | cópias em `codigo/xml/` |

Conferidos contra o original e **não** modificados: `lower_layers/swarm_module/Vasarhelyi_module/Vasarhelyi_module_generate_desire.m` e `lower_layers/evaluation_module/evaluation_0_module/evaluation_0_module_one.m` (as cópias em `codigo/modulos/` são idênticas às do CoFlyers v3.1.3).

No PC-B, o nó `px4_node.cpp` do pacote `px4_sitl_coflyers` não foi alterado. Os arquivos de lançamento gerados para cada semente estão em `pc_b/`.

## Arquivos de configuração das arenas (leia antes de rodar)

**O `parameters.xml` não é a arena vazia.** O `preparar_hifi.m` copia o XML da arena escolhida sobre o `xml_config_files/parameters.xml` antes de cada bloco de alta fidelidade. O último bloco foi o dos cilindros, em 03/09/2026. Desde então, o `parameters.xml` contém os quatro cilindros, e é essa a versão que está em `codigo/xml/parameters.xml`.

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

A varredura de T<sub>c</sub> em série já faz essa conferência sozinha: ela para com erro se o número de obstáculos do XML não corresponder à arena pedida.

### Modelo de movimento do simulador protótipo

Todos os XMLs usam `<motion_model_type value="'quadcopter'"/>`, que é o padrão do CoFlyers. A calibração, o Monte Carlo, o lote e a varredura rodaram com o modelo de quadricóptero do simulador protótipo, e não com o de ponto-massa:
- dinâmica de corpo rígido em 6 graus de liberdade, com resposta de primeira ordem dos motores;
- malhas PID de posição e de velocidade e controlador PD de atitude;
- controladores atuando sobre o estado verdadeiro do veículo, sem sensores nem estimação de estado.

---

## Referências

- Reynolds, C. W. (1987). Flocks, Herds, and Schools: A Distributed Behavioral Model. *SIGGRAPH '87*, 21(4), 25–34.
- Vicsek, T. et al. (1995). Novel type of phase transition in a system of self-driven particles. *Physical Review Letters*, 75(6), 1226–1229.
- Couzin, I. D. et al. (2002). Collective Memory and Spatial Sorting in Animal Groups. *Journal of Theoretical Biology*, 218(1), 1–11.
- Olfati-Saber, R. (2006). Flocking for Multi-Agent Dynamic Systems: Algorithms and Theory. *IEEE Transactions on Automatic Control*, 51(3), 401–420.
- Vásárhelyi, G. et al. (2018). Optimized flocking of autonomous drones in confined environments. *Science Robotics*, 3(20), eaat3536.
- Soria, E., Schiano, F., Floreano, D. (2020). SwarmLab: a MATLAB Drone Swarm Simulator. *IROS 2020*, 8005–8011.
- Huang, J., Wang, F., Hu, T. (2023). CoFlyers: A Universal Platform for Collective Flying of Swarm Drones. *IROS 2023*, 8808–8813.

---

## Autoria e licença

Fernando Souza Rodrigues, TCC 2 do Bacharelado em Ciência da Computação (DCC/UFRR), orientado pelo Prof. Dr. Herbert Oliveira Rocha. Boa Vista, Roraima.

Código sob a licença GPL-3.0 (arquivo `LICENSE`), a mesma do CoFlyers.
