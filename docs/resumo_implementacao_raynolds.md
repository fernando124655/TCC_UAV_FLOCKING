## Resumo Completo — Implementação e Validação do Algoritmo Reynolds Boids na Plataforma CoFlyers

### Contexto e Motivação

A implementação do algoritmo Reynolds Boids no CoFlyers surgiu da necessidade de comparar algoritmos de flocking/coordenação de enxame aplicados diretamente como alternativas ao Vasarhelyi (2018), que é o algoritmo nativo da plataforma. Após orientação do orientador, a pesquisa definiu que a contribuição principal seria demonstrar como algoritmos de complexidade variável (Reynolds com 6 parâmetros vs. Vasarhelyi com 11) se comportam quando submetidos ao mesmo pipeline de avaliação — Rapid Prototyping, Auto-tuning, Batch Processing e High-fidelity Simulation — em um cenário indoor com obstáculos.

A escolha do Reynolds como primeiro algoritmo alternativo foi fundamentada cientificamente em cinco referências: Reynolds (1987) como formulação original do modelo de três regras (separação, alinhamento, coesão), Hoang et al. (2021, PeerJ Computer Science) como adaptação moderna com pesos para enxames de UAVs, Debnath et al. (2025, MDPI Machines) como aplicação recente de Boids integrado com desvio de obstáculos em UAVs, Heß et al. (2025, Springer) como comparação de complexidade entre modelos de flocking, e Vicsek et al. (1995, Physical Review Letters) como base teórica do modelo de partículas autopropulsionadas que justifica o mecanismo de regulação de velocidade. As referências de Hoang (2021) e Debnath (2025) foram escolhidas estrategicamente para satisfazer a regra de 5 anos do departamento, citando Reynolds (1987) apenas como origem histórica do modelo.

A narrativa da contribuição foi construída invertendo a perspectiva usual da literatura: em vez de perguntar "o que falta no Reynolds?", a pesquisa investiga quais deficiências do Vasarhelyi o Reynolds resolve. Três deficiências foram identificadas: complexidade paramétrica excessiva (11-17 parâmetros requerem otimização evolutiva para calibração), dependência de informação global pré-computada para obstáculos (shill agents assumem mapa prévio completo), e ausência de garantia formal de estabilidade (validação puramente empírica).

---

### Engenharia Reversa da Plataforma

Antes de implementar qualquer código, analisamos o contrato de interface que o CoFlyers impõe a qualquer algoritmo de enxame, respondendo à pergunta do orientador: "quais alterações na plataforma são necessárias antes de poder inserir outro algoritmo?" A análise examinou cinco arquivos-fonte: `Vasarhelyi_module_generate_desire.m`, `swarm_module_generate_desire.m`, `model_swarm.m`, `Vasarhelyi_module_parameters.m` e a seção `<swarm>` do `parameters.xml`.

O contrato de entrada consiste em sete argumentos: tempo `t`, matrix de estados `states` (12×N com posição nas linhas 1-3, velocidade nas 4-6, aceleração nas 7-9 e orientação nas 10-12 para cada um dos N drones), `sample_time`, `sensor_data_s`, `map3d_struct`, `terrain` e `terrain_params`. O contrato de saída consiste em `command_upper_s` (matrix 12×N com posDesired nas linhas 1-4, velDesired nas 5-8 e accDesired nas 9-12) e `control_mode_s` (vetor uint8 de N elementos). O modo 7 (`VELOCITY_HORIZONTAL_CONTROL_TYPE`) controla velocidade XY via velDesired e altitude Z via posDesired(3) — uma distinção crucial que só descobrimos quando analisamos o template auto-gerado pela plataforma.

A conclusão principal foi que Reynolds, Olfati-Saber e Couzin não exigem nenhuma mudança na plataforma (apenas novos módulos MATLAB e blocos XML), enquanto algoritmos de cobertura como FLS exigiriam extensões ao evaluation module. Essa análise permitiu que a implementação do Reynolds fosse feita inteiramente como um novo módulo plugável, sem tocar em nenhum arquivo existente do CoFlyers.

---

### Implementação do Módulo Reynolds

A implementação seguiu rigorosamente o procedimento documentado pelos autores do CoFlyers no README do repositório GitHub e na Seção II-A do paper (IROS 2023). O procedimento consiste em três passos: adicionar o sub-módulo no XML dentro da seção `<swarm>`, rodar `read_parameter_xml()` para gerar automaticamente os arquivos de parâmetros e o template da função principal, e então inserir a lógica do algoritmo dentro do template gerado.

O bloco XML `<Reynolds>` foi criado com 13 parâmetros organizados em quatro grupos conceituais. O grupo de percepção contém `r_com = 10m` (raio de comunicação entre drones). O grupo de forças de interação contém os quatro pesos `w_sep`, `w_ali`, `w_coh` e `w_shill` mais os dois raios de ativação `r_sep` (separação entre drones) e `r_shill` (percepção de obstáculos). O grupo de limitação contém `v_max = v_flock * 1.2` (velocidade máxima) e `v_flock = 1.0 m/s` (velocidade preferida). E o grupo de ambiente contém `dim = 2` (operação 2D com altitude fixa), `height = 0.7m` (altitude de referência) e `dr_shill = 0.1m` (espaçamento dos shill agents), com a chamada `map_module_generate_shill_agent()` para pré-computar os agentes virtuais de parede a partir do mapa 3D — reutilizando exatamente a mesma infraestrutura que o Vasarhelyi usa para evitação de obstáculos.

Um aspecto importante da implementação foi a descoberta de que o `read_parameter_xml()` gera o arquivo `Reynolds_module_generate_desire.m` apenas uma vez (como template) e nunca o sobrescreve em execuções subsequentes, enquanto o `Reynolds_module_parameters.m` é regenerado a cada execução. Essa assimetria é intencional: o arquivo de parâmetros reflete o XML e muda automaticamente, enquanto o arquivo do algoritmo é onde o usuário implementa sua lógica e deve ser preservado.

---

### Depuração Iterativa — Cinco Bugs Resolvidos

A implementação passou por cinco bugs que foram diagnosticados e corrigidos iterativamente, cada um revelando um aspecto da arquitetura do CoFlyers que não era documentado explicitamente.

O primeiro bug foi "Too many output arguments" — o `read_parameter_xml()` gerou a função de parâmetros com 12 outputs, mas nosso código esperava 13. A causa foi que o tag `<w_coh>` não havia sido inserido corretamente no XML. A correção foi adicionar manualmente a tag e regenerar.

O segundo bug foi "Arrays have incompatible sizes" na operação `pos_shill - pos_i`. A causa foi que `pos_shill` chegava como matrix `[2 × 2404]` (formato dim×M gerado pelo `map_module_generate_shill_agent` para `dim=2`) enquanto `pos_i` era `[3 × 1]`. A correção foi adicionar um bloco de verificação dimensional que expande `pos_shill` de 2 linhas para 3 quando `dim=2`, adicionando uma linha de Z constante igual a `height`.

O terceiro bug foi comportamental: os drones colapsaram para um único ponto e pararam de se mover (φ_corr = -0.02, φ_vel = 0.003). A causa raiz é que o Reynolds Boids não possui mecanismo de autolocomoção — diferentemente do Vasarhelyi que tem o termo de "friction" (Eq. 4 do paper de 2018) incluindo `v_flock × ê_ij`, o Reynolds tem apenas Alignment que iguala velocidades entre vizinhos. Se todos começam parados, o Alignment retorna zero e o sistema converge para equilíbrio estático. A correção implementou um mecanismo de autolocomoção baseado no modelo de partículas autopropulsionadas de Vicsek (1995): as forças Reynolds determinam a direção do voo, enquanto a magnitude da velocidade é regulada para v_flock.

O quarto bug revelou que nossas primeiras versões calculavam forças em 3D (incluindo componente Z) mesmo quando `dim=2`, causando velocidades verticais espúrias que faziam os drones subir muito acima da arena nos primeiros segundos de simulação. Além disso, descobrimos que o `control_mode = 7` (`VELOCITY_HORIZONTAL_CONTROL_TYPE`) controla a altitude via posição Z (posDesired(3)), não via velocidade Z — uma distinção que só ficou clara quando analisamos o template auto-gerado pela plataforma. A correção separou completamente os cálculos XY e Z, e configurou `pos_desired_id(3) = height` para o controle de altitude, exatamente como o template oficial faz.

O quinto bug surgiu na transição para o High-fidelity Simulation: "FOR loop index expressions of unknown size are only supported if they are of the form A:B or A:B:C". A causa é que o bloco Commander do Simulink compila as funções MATLAB usando o MATLAB Coder (tradução para C/C++), que tem restrições sintáticas mais rígidas que o MATLAB puro. Expressões como `for k = nb` onde `nb = find(dists <= r_com)` violam essa restrição porque o tamanho do iterador só é conhecido em tempo de execução. A correção substituiu todos os loops por formas `for j = 1:number` com condicionais `if` internos, todas as chamadas a `find()`, `vecnorm()` e `mean()` por cálculos escalares explícitos, e o `randn()` por valores fixos — tornando o código 100% Coder-compatível.

---

### Validação — Etapa III-A: Rapid Prototyping

A primeira validação usou o Prototype Simulator (simulador ponto-massa MATLAB puro, sem Gazebo) com 10 drones na arena de 60×60m usando os parâmetros iniciais fixados manualmente (w_sep=1.5, w_ali=1.0, w_coh=0.8, w_shill=2.0, r_sep=3.0, r_shill=5.0). Os resultados foram F = 0.9954, φ_corr = 0.9294, φ_vel = 1.0042, φ_coll = 0.0004, φ_wall = 0. As trajetórias mostraram o enxame voando coletivamente dentro da arena com transições de parede periódicas, confirmando que o módulo Reynolds estava funcionando corretamente como controlador de enxame. A simulação completou em 56.6 segundos — tempo comparável ao Vasarhelyi (54.6 segundos), indicando que a complexidade computacional é similar.

---

### Validação — Etapa III-B: Auto-tuning

O auto-tuning usou o Algoritmo Genético (GA) com PopulationSize=10 e MaxGenerations=20 para otimizar os 6 parâmetros comportamentais do Reynolds (w_sep, w_ali, w_coh, w_shill, r_sep, r_shill), mantendo fixos v_flock=1.0 e r_com=10 — seguindo a mesma metodologia do paper que fixa v_flock e r_com e otimiza apenas os parâmetros de interação. O GA foi executado com 6 workers paralelos e visualization desativada (`activate_plot = 0` no XML) para evitar criação de centenas de janelas de figuras que consumiriam toda a memória do MATLAB. A função de fitness utilizada é a Equação 6 do paper: `F = 1 - Sat(φ̃_vel) × φ̃_corr / ((φ̃_wall/λ + 1)² × (φ̃_coll/λ + 1)²)`, onde F → 0 representa o enxame ideal (seguro e coerente).

O GA completou 210 avaliações ao longo de 18 gerações, distribuídas entre 6 workers paralelos. A convergência foi clara e consistente: geração 1 teve melhor F = 0.0647, geração 7 atingiu F = 0.0120, geração 11 chegou a F = 0.0104, e geração 14 alcançou o mínimo global de F = 0.0100. Os parâmetros ótimos foram recuperados dos arquivos de log dos workers paralelos (salvos automaticamente em `data_save/auto_tuning/Optimize_*_w*.txt`): w_sep = 4.1013, w_ali = 2.8086, w_coh = 1.2974, w_shill = 0.6871, r_sep = 4.6921, r_shill = 5.5857.

A validação com os parâmetros ótimos aplicados produziu F = 0.0062, φ_corr = 0.9851, φ_vel = 1.0088, φ_coll = 0, φ_wall = 0. Esse resultado é cientificamente significativo porque o Reynolds com 6 parâmetros otimizados atingiu fitness melhor (F = 0.006) que o Vasarhelyi com 11 parâmetros otimizados (F = 0.014), sugerindo que a complexidade adicional do Vasarhelyi pode não ser necessária para o cenário de arena aberta com paredes. Os parâmetros ótimos revelaram que o GA preferiu separação forte (w_sep = 4.1, o maior peso), alinhamento médio-alto (w_ali = 2.8), coesão moderada (w_coh = 1.3), e repulsão de obstáculos surpreendentemente sutil (w_shill = 0.69, o menor peso), com raio de separação grande (r_sep = 4.7m) e raio de percepção de paredes moderado (r_shill = 5.6m).

---

### Validação — Etapa III-C: Batch Processing

O batch processing analisou a robustez dos parâmetros ótimos do Reynolds sob variação sistemática do tempo de amostragem de controle (Tc) e do ruído de velocidade (η), usando exatamente a mesma grade 26×26 = 676 combinações do paper: Tc de 0.01s a 1.01s e η de 0 a 0.5 m/s. A execução com 6 workers paralelos e visualization desativada completou em 133.5 minutos.

Os resultados mostraram que φ_corr variou entre 0.9542 e 0.9896 e φ_vel entre 0.9186 e 1.0096 ao longo das 676 combinações. A maioria das combinações (com Tc < 0.5s e η < 0.25 m/s) produziu desempenho excelente com F < 0.1, φ_coll = 0 e φ_wall = 0. A degradação ocorreu nas combinações com Tc alto (próximo de 1 segundo), onde os drones não conseguem reagir às paredes a tempo — o mesmo padrão que o paper documenta para o Vasarhelyi. Os gráficos de superfície 3D foram salvos em `data_save/reynolds_batch_phi_corr.png` e `data_save/reynolds_batch_phi_vel.png`, diretamente comparáveis com as Figuras 4(c) e 4(d) do paper.

---

### Validação — Etapa III-D: High-fidelity Simulation

A validação de alta fidelidade usou dois computadores em rede: PC-A (Windows 11, IP 192.168.1.155) com MATLAB/Simulink R2025b como Commander, e PC-B (Ubuntu 24.04, IP 192.168.1.157) com container Docker (`--network=host`) rodando PX4-SITL v1.12.3, Gazebo Classic 11, ROS Noetic e MAVROS com 10 drones. Os IPs foram configurados em quatro pontos: `local_ip='192.168.1.155'` e `target_ip=ones(1,CoFlyers.number)*157` no `parameters.xml` do PC-A, e `ipLocal_=192.168.1.157` e `ipTarget_=192.168.1.155` no `px4_node_multiple_10.launch` do PC-B. O display do Gazebo foi habilitado com `DISPLAY=:0`, `LIBGL_ALWAYS_SOFTWARE=1` e `xhost +local:` no host do PC-B.

Durante a transição do Prototype Simulator para o High-fidelity, descobrimos que o Simulink compila as funções MATLAB via Coder, exigindo a versão Coder-compatível do `Reynolds_module_generate_desire.m` (sem `find()` em iteradores de loop, sem `vecnorm()` com tamanhos dinâmicos, sem `randn()`). Após aplicar a versão Coder-compatível, a simulação foi executada com sucesso: os 10 drones armaram, decolaram, voaram no modo Alg por 250 segundos com o algoritmo Reynolds otimizado, e pousaram. A figura de pós-processamento no estilo da Fig. 5(b)(c) do paper foi gerada com o script `plot_hifi_paper_style.m`, e os dados brutos foram salvos em `data_save/hifi_reynolds_optimized.mat`. A visualização no Gazebo mostrou o enxame Reynolds mantendo coesão durante o voo, separando-se ao encontrar o obstáculo cilíndrico central, e reformando a formação após o desvio — comportamento qualitativamente consistente com o Vasarhelyi no mesmo cenário.

---

### Pipeline Estabelecido para Próximos Algoritmos

A implementação e validação do Reynolds estabeleceu um pipeline replicável para cada algoritmo subsequente (Olfati-Saber, Couzin, e opcionalmente FLS). O pipeline consiste em seis etapas sequenciais: fundamentação científica (pesquisa de referências e formulação matemática), implementação (criar bloco XML + arquivo .m seguindo o template auto-gerado + tornar Coder-compatível), Rapid Prototyping com parâmetros fixos (validar que o algoritmo funciona como enxame), Auto-tuning (otimizar parâmetros via GA com visualization desativada e workers paralelos), Batch Processing (analisar robustez sob variação de Tc e η com a mesma grade 26×26), e High-fidelity Simulation (validar em PX4+Gazebo com dois computadores em rede). Cada etapa produz artefatos específicos (figuras, arquivos .mat, logs) que serão usados na comparação final entre algoritmos na dissertação.