Vou consultar o histórico completo da nossa conversa para fazer um resumo preciso e abrangente.Aqui está o resumo completo e organizado de tudo o que fizemos neste projeto até agora.

---

## Resumo Completo do Projeto — CoFlyers UAV Swarm Simulation Research

### Contexto e Objetivo Inicial

A pesquisa parte do tema "Análise Comparativa de Algoritmos Bioinspirados e Evolutivos para Cobertura de Área por Enxames de UAVs em Ambientes Indoor Obstruídos". A plataforma escolhida para as simulações foi o CoFlyers (Huang et al., IROS 2023), um framework open-source baseado em MATLAB/Simulink que integra PX4, Gazebo e ROS para simulação de enxames de drones. O prazo de entrega da pesquisa é de 40 dias.

O primeiro passo foi validar completamente a plataforma CoFlyers, reproduzindo as quatro etapas descritas no paper original (Seções III-A a III-D), antes de introduzir qualquer modificação para a pesquisa comparativa.

---

### Fase 1 — Configuração do Ambiente (WSL + Docker)

O CoFlyers exige Ubuntu 18.04/20.04 com ROS Noetic, mas a máquina disponível tinha Ubuntu 24.04 via WSL2. Para resolver a incompatibilidade, optamos por uma abordagem com **container Docker** usando a imagem `px4io/px4-dev-ros-noetic:latest`. Dentro do container foram instalados o PX4 v1.12.3, ROS Noetic, Gazebo Classic 11, MAVROS, MATLAB R2025b (trial) e o próprio CoFlyers. O MAC do container foi fixado em `00:d7:6d:ba:1d:96` para manter a licença MATLAB estável entre reinicializações.

Foram necessárias várias **correções de compatibilidade** dentro do container porque o trial do MATLAB não incluía todas as toolboxes necessárias. O arquivo `get_multi_core_value.m` foi modificado para retornar `false` e string vazia, eliminando a dependência da Parallel Computing Toolbox. A função `heaviside()` no `fitness_function_combine.m` foi substituída por `double(x >= 0)` porque a Symbolic Math Toolbox estava ausente. Todas as barras invertidas (`\`) nos caminhos de arquivos `.m` foram trocadas por barras normais (`/`) para compatibilidade Linux. E o `getCurrentTask()` no `model_swarm_repeat.m` foi envolvido em try-catch para não lançar exceção na ausência da Parallel Computing Toolbox. Ao longo do projeto, **quatro imagens Docker de backup** foram salvas progressivamente: v2_matlab (9.75GB), v3_10drones (10.2GB), v4_toolboxes (12.1GB) e v5_display.

---

### Fase 2 — Validação da Plataforma CoFlyers (4 Etapas do Paper)

**Etapa III-A — Rapid Prototyping.** Rodamos o `main_rapid_prototyping.m` com Xvfb (display virtual) e 10 drones usando o algoritmo Vasarhelyi. A simulação gerou com sucesso a figura mostrando trajetórias 3D e métricas de desempenho, com φ_corr ≈ 0.97, φ_vel ≈ 0.97 e zero colisões (φ_coll = 0, φ_wall = 0). Isso confirmou que o Prototype Simulator do CoFlyers funcionava corretamente no container.

**Etapa III-B — Parameter Auto-tuning.** Criamos o script `run_auto_tuning_save.m` com configuração mínima do GA (PopulationSize=5, MaxGenerations=3, ~15 avaliações) para validar o pipeline de otimização sem esperar horas. O GA rodou em aproximadamente 29 minutos e produziu um conjunto de parâmetros. Como os valores resultantes divergiam dos publicados no paper (por causa das poucas gerações), registramos os parâmetros ótimos do paper (r_rep_0=2.42, p_rep=0.34, etc.) para uso nas etapas seguintes. A toolbox Global Optimization Toolbox estava disponível no trial, então tanto `ga` quanto `particleswarm` funcionaram nativamente.

**Etapa III-C — Batch Processing.** Criamos o script `run_batch_processing_save.m` que primeiro injetou os parâmetros ótimos do paper no XML e depois varreu 5×5=25 combinações de Tc (tempo de amostragem de controle, 0.01 a 1.0s) e η (ruído de velocidade, 0 a 0.5 m/s). O processamento completou em 49 minutos e gerou um gráfico de superfície 3D mostrando φ_corr e φ_vel em função das duas variáveis. O padrão observado foi consistente com o paper: degradação abrupta do desempenho quando Tc ultrapassa 0.5 segundos.

**Etapa III-D — Distributed High-fidelity Simulation.** Esta etapa foi a mais complexa e passou por três fases distintas.

Na primeira tentativa, rodamos tudo dentro do mesmo container Docker no WSL. O Simulink travava com deadlock UDP porque o Commander e o px4_node competiam pelas mesmas portas no mesmo namespace de rede. Identificamos que o problema era causado por conflito de bind de sockets no localhost.

Na segunda tentativa, configuramos o display do container para usar o WSLg (`DISPLAY=:0` em vez de `:99`) e conseguimos abrir a janela do Gazebo com os 10 drones no ambiente 3D com obstáculos — a primeira evidência visual da simulação high-fidelity funcionando.

Na terceira tentativa (e definitiva), usamos **dois computadores separados** como o paper descreve: PC-A (Windows 11, IP 192.168.1.155) como Commander com MATLAB/Simulink nativo, e PC-B (Ubuntu 24.04, IP 192.168.1.156) como Simulador com PX4+Gazebo+ROS em container Docker com `--network=host`. A imagem Docker v4_toolboxes foi transferida para o PC-B. Os IPs foram configurados em quatro pontos: `local_ip` e `target_ip` no `parameters.xml` do PC-A, e `ipLocal_` e `ipTarget_` no `px4_node_multiple_10.launch` do PC-B. Com essa configuração, a comunicação UDP bidirecional funcionou corretamente. Os 10 drones armaram, decolaram, executaram o algoritmo Vasarhelyi no modo "Alg" do seletor do Simulink, e pousaram — tudo controlado remotamente do PC-A.

Durante a validação da Etapa III-D, descobrimos que os parâmetros `v_flock=0.2` e `r_com=8` no XML estavam configurados para a arena experimental de 4×6m (Tello drones), não para a arena de simulação. Corrigimos para `v_flock=1.0`, `r_com=20` e ampliamos a arena para 60×60m (`x_range=[-30;30]`, `y_range=[-30;30]`), que são os valores usados no paper para simulação. Isso melhorou significativamente o desempenho do enxame.

Para gerar as figuras equivalentes à Figura 5(b) e 5(c) do paper, descobrimos que os autores usam um script de pós-processamento (`visualization.m`) que lê os dados gravados pelo Simulink (variável `out` com `out.states` e `out.commands`) após clicar Stop. Os dados brutos têm 17 features por drone, onde as primeiras 5 são metadados (ID, sequência, timestamp, flags) e as features 6-17 contêm posição, velocidade, aceleração e orientação. Criamos o script `plot_hifi_paper_style.m` que extrai os dados corretamente, identifica o período do modo Alg (command_id=7), calcula φ_corr e φ_vel, e gera os dois painéis (trajetórias 3D coloridas por velocidade + métricas temporais) no mesmo estilo da Figura 5 do paper.

---

### Fase 3 — Instalação de Toolboxes Adicionais

Durante as tentativas de rodar o modelo Simulink `testControlWithDroneSwarm.slx`, encontramos erros por falta de toolboxes. Usamos o `mpm` (MATLAB Package Manager) para instalar dentro do container: **Aerospace Blockset** (necessário para o bloco Simulation Pace), **DSP System Toolbox** (necessário para blocos dspindex) e **Signal Processing Toolbox** (dependência do DSP). O bloco Simulation Pace foi removido do modelo para evitar bloqueio na versão headless, e documentamos que ele pode ser restaurado do modelo original `testControlWithDroneSwarm_r2021b.slx`.

---

### Fase 4 — Evolução da Direção da Pesquisa

A direção da pesquisa passou por três mudanças conceituais ao longo do projeto, cada uma refinando o escopo.

Na primeira versão, propusemos usar ACO, GA, GWO e ABC como **controladores diretos** de enxame substituindo o Vasarhelyi. Chegamos a criar arquivos preliminares para o ACO (`ACO_module_generate_desire.m`) e um módulo de cobertura (`coverage_module_one.m`, `coverage_module_average.m`, `coverage_module_parameters.m`), mas revertemos essas mudanças quando decidimos primeiro validar completamente a plataforma com o Vasarhelyi original.

Na segunda versão, propusemos usar PSO e GA como **meta-otimizadores** dos parâmetros comportamentais do Vasarhelyi, adicionando uma camada de cobertura baseada em Potential Fields. Essa abordagem foi fundamentada no estado da arte (Kareem et al. 2025/2026, Tran et al. 2024, Bansal et al. 2023) e geramos um relatório extenso de pesquisa cobrindo a formulação do problema, métricas (CR, RR, TTFD), baselines (Vasarhelyi puro, PSO, boustrophedon), e um plano de execução em 6 estágios.

Na terceira versão (atual), após orientação do orientador, a pesquisa voltou para a comparação de **algoritmos de flocking/coordenação de enxame aplicados diretamente** como alternativas ao Vasarhelyi. Geramos um levantamento comparativo abrangente que avalia Reynolds Boids, Olfati-Saber, Couzin, Vicsek, PSO direto, ACO/Feromônios, ABC, Lévy Flight+APF, Frontier-Led Swarming e Voronoi/Lloyd. A recomendação final é implementar 3-4 algoritmos (Reynolds + Olfati-Saber + Couzin + opcionalmente FLS) como módulos MATLAB compatíveis com a interface do CoFlyers, e compará-los com o Vasarhelyi usando métricas híbridas de flocking (φ_corr, φ_vel, φ_coll, φ_wall) e cobertura (CR, RR, TTFD).

---

### Artefatos Gerados

Ao longo do projeto foram gerados três relatórios de pesquisa: "Bioinspired Meta-Optimizers for UAV Swarm Coverage in Indoor Environments" (estado da arte sobre meta-otimização), "Distributed CoFlyers Setup Across Two Computers via UDP" (guia operacional para simulação distribuída), e "Flocking and Swarm Coordination Algorithms for CoFlyers: Comparative Analysis as Alternatives to the Vasarhelyi" (levantamento comparativo de algoritmos candidatos).

Foram geradas figuras de validação de todas as etapas: trajetórias e métricas do Rapid Prototyping, gráfico de superfície do Batch Processing, figura com dados ROS dos 10 drones online, e figuras no estilo da Figura 5(b)(c) do paper com trajetórias 3D coloridas por velocidade e métricas φ_corr/φ_vel ao longo do tempo.

---

### Estado Atual e Próximos Passos

A plataforma CoFlyers está **completamente validada** nas 4 etapas do paper original, com dois computadores físicos funcionando em rede. A pesquisa agora precisa definir quais algoritmos de flocking serão implementados como alternativas ao Vasarhelyi. A busca por fundamentação científica para cada mudança foi solicitada e o levantamento comparativo já está pronto, aguardando a decisão sobre quais algoritmos priorizar dentro do prazo de 40 dias. A implementação de cada algoritmo será como um novo módulo MATLAB seguindo a interface `XXX_module_generate_desire(...)` do CoFlyers, registrado no XML via `<swarm>` e gerado automaticamente pelo `read_parameter_xml.m`.