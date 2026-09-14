## Resumo Completo das Modificações Implementadas no Projeto

### Contexto e Objetivo

A pesquisa tem como tema "Análise Comparativa de Algoritmos Bioinspirados e Evolutivos para Cobertura de Área por Enxames de UAVs em Ambientes Indoor Obstruídos", utilizando a plataforma CoFlyers (Huang et al., IROS 2023) como base de simulação. O prazo de entrega é de 40 dias. A plataforma CoFlyers integra MATLAB/Simulink como Commander centralizado, PX4-SITL como controlador de voo, Gazebo Classic 11 como simulador de física 3D, e ROS Noetic como middleware de comunicação, todos interligados por uma interface UDP proprietária.

---

### Fase 1 — Configuração do Ambiente de Desenvolvimento

A primeira fase consistiu em montar o ambiente completo dentro de um container Docker, necessário porque o CoFlyers exige Ubuntu 18.04/20.04 com ROS Noetic, mas a máquina disponível rodava Ubuntu 24.04 via WSL2 no Windows 11. O container foi construído a partir da imagem `px4io/px4-dev-ros-noetic:latest` e recebeu instalações sequenciais do PX4 v1.12.3, ROS Noetic, Gazebo Classic 11, MAVROS, MATLAB R2025b (licença trial) e o repositório CoFlyers completo. O endereço MAC do container foi fixado em `00:d7:6d:ba:1d:96` para manter a licença MATLAB estável entre reinicializações.

Foram necessárias cinco correções de compatibilidade porque a versão trial do MATLAB não incluía todas as toolboxes que o CoFlyers assume como disponíveis. O arquivo `get_multi_core_value.m` foi modificado para retornar `false` e string vazia, eliminando a dependência da Parallel Computing Toolbox que não estava presente no trial. A função `heaviside()` no `fitness_function_combine.m` foi substituída por `double(x >= 0)` porque a Symbolic Math Toolbox estava ausente. Todas as barras invertidas (`\`) nos caminhos de arquivos `.m` foram trocadas por barras normais (`/`) para compatibilidade com o sistema de arquivos Linux. O `getCurrentTask()` no `model_swarm_repeat.m` foi envolvido em um bloco try-catch para não lançar exceção na ausência da Parallel Computing Toolbox. E três toolboxes adicionais foram instaladas via `mpm` (MATLAB Package Manager) dentro do container: Aerospace Blockset (necessário para o bloco Simulation Pace do Simulink), DSP System Toolbox (necessário para blocos dspindex) e Signal Processing Toolbox (dependência do DSP). Quatro imagens Docker de backup foram salvas progressivamente ao longo dessas configurações: v2_matlab (9.75GB), v3_10drones (10.2GB), v4_toolboxes (12.1GB) e v5_display.

---

### Fase 2 — Validação Completa da Plataforma CoFlyers

A segunda fase reproduziu as quatro etapas descritas no paper original do CoFlyers (Seções III-A a III-D) para validar que a plataforma funcionava corretamente antes de introduzir qualquer algoritmo novo.

**Etapa III-A (Rapid Prototyping)** foi executada com o script `main_rapid_prototyping.m` usando 10 drones e o algoritmo Vasarhelyi no Prototype Simulator (simulador ponto-massa MATLAB puro, sem Gazebo). O display virtual Xvfb foi usado para renderizar as figuras em modo headless. Os resultados confirmaram o funcionamento correto: φ_corr ≈ 0.97, φ_vel ≈ 0.97, zero colisões (φ_coll = 0, φ_wall = 0).

**Etapa III-B (Parameter Auto-tuning)** foi validada criando o script `run_auto_tuning_save.m` com configuração mínima do GA (PopulationSize=5, MaxGenerations=3, aproximadamente 15 avaliações) para testar o pipeline de otimização sem esperar horas. O GA completou em cerca de 29 minutos. Como os valores resultantes divergiam dos publicados no paper devido ao número insuficiente de gerações, registramos separadamente os parâmetros ótimos do paper (r_rep_0=2.42, p_rep=0.34, etc.) para uso nas etapas seguintes. Tanto `ga` quanto `particleswarm` da Global Optimization Toolbox funcionaram nativamente no trial.

**Etapa III-C (Batch Processing)** foi executada criando o script `run_batch_processing_save.m` que primeiro injetou os parâmetros ótimos do paper no XML e depois varreu 5×5=25 combinações de Tc (tempo de amostragem de controle, de 0.01 a 1.0s) e η (ruído de velocidade, de 0 a 0.5 m/s). O processamento completou em 49 minutos e gerou um gráfico de superfície 3D mostrando φ_corr e φ_vel em função das duas variáveis, com padrão consistente com o paper: degradação abrupta quando Tc ultrapassa 0.5 segundos.

**Etapa III-D (Distributed High-fidelity Simulation)** foi a mais complexa e passou por três fases distintas. Na primeira tentativa, tudo foi executado dentro do mesmo container Docker no WSL, mas o Simulink travava com deadlock UDP porque o Commander e o px4_node competiam pelas mesmas portas no mesmo namespace de rede. Na segunda tentativa, corrigimos o display do container para usar o WSLg do Windows 11 (`DISPLAY=:0` em vez de `:99`) e conseguimos abrir a janela do Gazebo com os 10 drones no ambiente 3D — confirmando que o display X11 funcionava. Na terceira tentativa e definitiva, usamos dois computadores separados como o paper descreve: PC-A (Windows 11, MATLAB/Simulink R2025b nativo, IP 192.168.1.155) como Commander e PC-B (Ubuntu 24.04, Docker com PX4+Gazebo+ROS usando `--network=host`, IP 192.168.1.156) como Simulador. A imagem Docker v4_toolboxes foi transferida para o PC-B via `docker save/load`. Os IPs foram configurados em quatro pontos: `local_ip='192.168.1.155'` e `target_ip=ones(1,CoFlyers.number)*156` no `parameters.xml` do PC-A, e `ipLocal_=192.168.1.156` e `ipTarget_=192.168.1.155` no `px4_node_multiple_10.launch` do PC-B. Regras de firewall foram criadas para liberar as portas UDP 20000-21020 em ambas as máquinas. A comunicação bidirecional funcionou corretamente e os 10 drones armaram, decolaram, executaram o algoritmo Vasarhelyi no modo "Alg" do seletor do Simulink, e pousaram — tudo controlado remotamente do PC-A via rede local.

Durante a validação desta etapa, descobrimos e corrigimos dois problemas de parâmetros. O primeiro foi que `v_flock=0.2` e `r_com=8` estavam configurados para a arena experimental de 4×6m com Tello drones, não para a arena de simulação. Corrigimos para `v_flock=1.0` e `r_com=20`. O segundo foi que a arena de 30×30m era pequena demais para os parâmetros do paper, causando velocidades explosivas e perda de coerência. Ampliamos para 60×60m (`x_range=[-30;30]`, `y_range=[-30;30]`).

Para gerar as figuras equivalentes à Figura 5(b) e 5(c) do paper, descobrimos que os autores usam um script de pós-processamento (`visualization.m`) que lê os dados gravados pelo Simulink após clicar Stop. Os dados brutos do Simulink têm 17 features por drone, onde as primeiras 5 são metadados (ID, sequência, timestamp Unix, e dois flags de estado) e as features 6-17 contêm posição (6-8), velocidade (9-11), aceleração (12-14) e orientação (15-17). Criamos o script `plot_hifi_paper_style.m` que extrai os dados corretamente aplicando o offset de 5 colunas, identifica o período do modo Alg pelo `command_id=7` no vetor de comandos, calcula φ_corr e φ_vel, e gera os dois painéis (trajetórias 3D coloridas por velocidade com centróide em preto, e métricas temporais) no mesmo estilo da Figura 5 do paper.

---

### Fase 3 — Evolução da Direção da Pesquisa

A direção da pesquisa passou por três mudanças conceituais ao longo do projeto, cada uma refinando o escopo com base no feedback do orientador.

Na **primeira versão**, propusemos usar ACO, GA, GWO e ABC como controladores diretos de enxame substituindo o Vasarhelyi. Chegamos a criar arquivos preliminares para o ACO e um módulo de cobertura, mas revertemos essas mudanças quando decidimos primeiro validar completamente a plataforma.

Na **segunda versão**, propusemos usar PSO e GA como meta-otimizadores dos parâmetros comportamentais do Vasarhelyi, adicionando uma camada de cobertura baseada em Potential Fields com 4 parâmetros novos (peso de fronteira, peso de dispersão, raio de dispersão, decaimento de interesse). Essa abordagem foi fundamentada com pesquisa abrangente cobrindo Kareem et al. (2025/2026), Tran et al. (2024), Bansal et al. (2023), e geramos um relatório extenso com formulação do problema, métricas (CR, RR, TTFD), baselines, e plano de execução em 6 estágios.

Na **terceira versão (atual)**, após orientação do orientador dizendo que "será mais complicado aplicar melhoramento via meta-otimização do que encontrar algoritmos com a mesma aplicação do Vasarhelyi", a pesquisa voltou para a comparação de algoritmos de flocking/coordenação de enxame aplicados diretamente como alternativas ao Vasarhelyi. Geramos um levantamento comparativo abrangente avaliando Reynolds Boids, Olfati-Saber, Couzin, Vicsek, PSO direto, ACO/Feromônios, ABC, Lévy Flight+APF, Frontier-Led Swarming e Voronoi/Lloyd. A recomendação final é implementar o conjunto Vasarhelyi (baseline) + Reynolds + Olfati-Saber + Couzin + opcionalmente FLS.

---

### Fase 4 — Engenharia Reversa do Vasarhelyi no CoFlyers

A quarta fase respondeu à pergunta do orientador: "quais alterações o algoritmo existente eu tenho de implementar para poder aplicar outro?" Analisamos o código real do CoFlyers usando as saídas de `Vasarhelyi_module_generate_desire.m`, `swarm_module_generate_desire.m`, `model_swarm.m`, `Vasarhelyi_module_parameters.m` e a seção `<swarm>` do XML.

O contrato de interface foi mapeado com precisão. A entrada da função de enxame consiste em 7 argumentos: tempo `t`, matrix de estados `states` (12×N com posição nas linhas 1-3, velocidade nas linhas 4-6, aceleração nas linhas 7-9 e orientação nas linhas 10-12), `sample_time`, `sensor_data_s`, `map3d_struct`, `terrain` e `terrain_params`. A saída consiste em `command_upper_s` (matrix 12×N com posDesired nas linhas 1-4, velDesired nas linhas 5-8 e accDesired nas linhas 9-12) e `control_mode_s` (uint8, valor 7 para modo velocidade).

O sistema de parâmetros funciona via XML: cada algoritmo tem um sub-bloco dentro de `<swarm>`, e o `read_parameter_xml()` gera automaticamente o arquivo `XXX_module_parameters.m` com os valores e atualiza o switch-case do `swarm_module_generate_desire.m`. O Vasarhelyi usa um parâmetro especial `pos_shill-vel_shill` que é computado pela função `map_module_generate_shill_agent()` — essa função projeta agentes virtuais sobre as superfícies dos obstáculos para implementar repulsão de paredes.

A conclusão foi que Reynolds, Olfati-Saber e Couzin não exigem nenhuma mudança na plataforma (apenas novos módulos MATLAB e blocos XML), enquanto algoritmos de cobertura (FLS) e métricas de cobertura (CR, RR, TTFD) exigiriam extensões ao evaluation module.

---

### Fase 5 — Fundamentação Científica e Implementação do Reynolds Boids

Antes de implementar, realizamos pesquisa científica para fundamentar cada decisão de design do módulo Reynolds. As referências principais foram: Reynolds (1987) como formulação original, Hoang et al. (2021, PeerJ Computer Science) para pesos adaptativos em enxames de UAVs, Debnath et al. (2025, MDPI Machines) para integração de Boids com desvio de obstáculos em UAVs, Heß et al. (2025, Springer) para comparação de modelos de flocking, e Vasarhelyi et al. (2018, Science Robotics) para a técnica de saturação de velocidade e shill agents reutilizada. As referências de Hoang (2021) e Debnath (2025) foram escolhidas estrategicamente para satisfazer a regra de 5 anos do departamento, citando Reynolds (1987) apenas como origem histórica.

A narrativa da contribuição foi definida: como o Vasarhelyi é o baseline, a pesquisa investiga quais deficiências do Vasarhelyi os outros algoritmos resolvem. Três deficiências foram identificadas na literatura: complexidade paramétrica excessiva (11-17 parâmetros vs. 6 do Reynolds), dependência de informação global pré-computada para obstáculos (shill agents requerem mapa prévio completo), e ausência de garantia formal de estabilidade (ao contrário do Olfati-Saber com prova de Lyapunov).

Sobre a relação entre o ruído sensorial descrito por Heß et al. (2025) e o Batch Processing do CoFlyers, concluímos que o parâmetro η (velocity noise) e Tc (tempo de amostragem) do CoFlyers capturam parcialmente o "ruído sensorial" da literatura, e que o Reynolds Boids deve ser mais sensível a essas perturbações que o Vasarhelyi — o que seria um resultado interessante para a dissertação.

A implementação do módulo Reynolds consistiu em três arquivos criados e um trecho XML.

O primeiro arquivo, `Reynolds_module_generate_desire.m`, segue exatamente o padrão do Vasarhelyi: carrega parâmetros via persistent function handle chamando `Reynolds_module_parameters()`, itera sobre cada drone, encontra vizinhos dentro de `r_com` por distância euclidiana, e chama a função per-drone. A estrutura de saída é idêntica ao Vasarhelyi: matrix 12×N e `control_mode_s = uint8(7)`. Este arquivo inclui um bloco de reshape para os shill agents que converte o formato serializado pelo XML (que achata matrizes em vetores 1D) de volta para o formato matricial correto. Especificamente, quando `dim=2`, `pos_shill` chega como `[2 × M]` e precisa ser expandido para `[3 × M]` adicionando uma linha de Z constante igual a `height`.

O segundo arquivo, `Reynolds_module_generate_desire_i.m`, é o coração do algoritmo — a função per-drone que calcula a velocidade desejada usando quatro forças. A Separação (Force 1) repele vizinhos mais próximos que `r_sep` com magnitude inversamente proporcional ao quadrado da distância. O Alinhamento (Force 2) corrige a velocidade em direção à média das velocidades dos vizinhos dentro de `r_com`. A Coesão (Force 3) atrai o drone em direção ao centróide local dos vizinhos. E a Repulsão de Shill (Force 4) reutiliza a mesma infraestrutura `pos_shill`/`vel_shill` do Vasarhelyi para evitar obstáculos e paredes.

O terceiro arquivo foi o trecho XML `Reynolds_XML_section.xml` com os parâmetros iniciais calibrados para a arena de 60×60m com 10 drones: `r_com=10`, `v_flock=1.0`, `w_sep=1.5`, `w_ali=1.0`, `w_coh=0.8`, `w_shill=2.0`, `r_sep=3.0`, `v_max=1.2`, `dim=2`, `height=0.7`, `dr_shill=0.1`, e a chamada `map_module_generate_shill_agent()` para gerar os shill agents automaticamente.

---

### Fase 6 — Depuração do Módulo Reynolds

A implementação do Reynolds enfrentou três bugs que foram diagnosticados e corrigidos iterativamente.

O **primeiro bug** foi "Too many output arguments" — o `read_parameter_xml()` gerou `Reynolds_module_parameters.m` com apenas 12 outputs porque o parâmetro `w_coh` estava faltando no XML. A causa foi que a tag `<w_coh value="0.8"/>` não havia sido inserida corretamente na seção `<Reynolds>` do `parameters.xml`. A correção foi adicionar manualmente a tag ao XML e rodar `read_parameter_xml()` novamente, o que regenerou o arquivo de parâmetros com os 13 outputs corretos na ordem esperada.

O **segundo bug** foi "Arrays have incompatible sizes" na linha `diff_shill = pos_shill - pos_i` dentro do `_i.m`. A causa foi que `pos_shill` chegava como `[2 × 2404]` (formato `dim × M` gerado pelo `map_module_generate_shill_agent()` para `dim=2`) enquanto `pos_i` era `[3 × 1]`. A operação `[2×2404] - [3×1]` é impossível porque as dimensões das linhas não coincidem. A correção foi adicionar um bloco no `Reynolds_module_generate_desire.m` que verifica se `pos_shill` tem apenas 2 linhas e, nesse caso, adiciona uma terceira linha com `z = height` para torná-lo `[3 × 2404]`, compatível com a subtração por `pos_i`.

O **terceiro bug** (sendo corrigido atualmente) é comportamental, não de código: os drones Reynolds colapsaram para um único ponto e pararam de se mover, produzindo φ_corr = -0.02 e φ_vel = 0.003. A causa raiz é que o Reynolds Boids, diferentemente do Vasarhelyi, não possui um mecanismo de autolocomoção. O Vasarhelyi tem o termo de "friction" (Eq. 4 do paper de 2018) que inclui `v_flock * ê_ij` — uma força que ativamente empurra cada drone para manter a velocidade preferida. O Reynolds tem apenas Alignment, que iguala velocidades entre vizinhos: se todos começam parados, o Alignment retorna zero e o sistema converge para equilíbrio estático. A observação de drones "subindo muito" nos primeiros 2 segundos revelou um segundo sub-problema: as forças estavam sendo computadas em 3D incluindo componente Z mesmo quando `dim=2`, causando velocidades verticais espúrias. A correção implementa duas mudanças fundamentais: quando `dim=2`, todas as forças são calculadas exclusivamente com componentes XY (eliminando forças Z espúrias), e um mecanismo de autolocomoção trata as forças Reynolds como determinantes da direção do voo enquanto fixa a magnitude em `v_flock`, seguindo o modelo de velocidade constante de Vicsek (1995). Essa versão corrigida está aguardando validação no Rapid Prototyping.

---

### Relatórios e Artefatos Gerados

Ao longo do projeto foram gerados quatro relatórios de pesquisa. O primeiro, "Bioinspired Meta-Optimizers for UAV Swarm Coverage in Indoor Environments", cobre o estado da arte sobre meta-otimização com PSO/GA sobre parâmetros de flocking, incluindo formulação do problema de cobertura, métricas, baselines, plano de execução e 10 caveats metodológicos. O segundo, "Distributed CoFlyers Setup Across Two Computers via UDP", é um guia operacional detalhando a configuração de rede, IPs, portas, firewall, Docker `--network=host`, e diagnóstico de problemas para a simulação distribuída. O terceiro, "Flocking and Swarm Coordination Algorithms for CoFlyers: Comparative Analysis as Alternatives to the Vasarhelyi", é o levantamento comparativo abrangente avaliando 12 algoritmos candidatos com formulação matemática, número de parâmetros, tempo de implementação e adequação a ambientes indoor. O quarto, "Reynolds Boids (1987) as a Swarm UAV Controller: Scientific Foundation and MATLAB Implementation", fornece a fundamentação científica completa para a implementação do Reynolds com equações prontas para MATLAB, parâmetros recomendados, e análise comparativa com Vasarhelyi.

Foram geradas figuras de validação de todas as etapas do paper: trajetórias e métricas do Rapid Prototyping, gráfico de superfície do Batch Processing, figura com dados ROS dos 10 drones online a 31 Hz, e figuras no estilo da Figura 5(b)(c) do paper com trajetórias 3D coloridas por velocidade e métricas φ_corr/φ_vel ao longo do tempo para a simulação High-fidelity.

---

### Estado Atual

A plataforma CoFlyers está completamente validada nas 4 etapas do paper original com dois computadores físicos em rede. O módulo Reynolds Boids foi implementado, registrado no XML, e está em fase de depuração do mecanismo de autolocomoção — a versão corrigida com separação dimensional (2D) e regulação de velocidade à la Vicsek está aguardando validação no Rapid Prototyping. Após essa validação, os próximos passos são validar o Reynolds no High-fidelity com Gazebo, implementar o Olfati-Saber seguindo o mesmo padrão, e executar as comparações estatísticas com Monte Carlo de 20 runs.