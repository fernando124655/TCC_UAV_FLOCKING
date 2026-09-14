# Guia de Referência: Pipeline Experimental e Fundamentação Estatística

*Documento de apoio para a redação da seção de metodologia ("solução proposta")*

---

## Parte 1 — Onde estamos

### 1.1 A distinção fundamental: validação × produção

Tudo o que foi feito até agora divide-se em duas fases com propósitos diferentes. Confundi-las é o erro mais comum ao escrever a metodologia.

**Fase de validação de implementação (concluída).** Objetivo: demonstrar que os quatro algoritmos foram corretamente implementados no CoFlyers e que cada etapa do pipeline funciona para cada um. Cada experimento rodou **uma vez**, sem controle de semente, a partir de uma configuração inicial em grade fixa. Resultado: sabemos que Reynolds, Olfati-Saber, Couzin e Vasárhelyi funcionam, que o auto-tuning encontra parâmetros razoáveis, que o batch revela padrões de robustez e que o high-fidelity completa o ciclo.

**Fase de produção científica (em curso).** Objetivo: gerar dados estatisticamente robustos que sustentem afirmações comparativas. Múltiplas repetições, sementes controladas, intervalos de confiança. A analogia clínica: a fase anterior foi o estudo-piloto; esta é o ensaio propriamente dito.

Na dissertação, a fase de validação aparece como *desenvolvimento e verificação da implementação*; a fase de produção aparece como *desenho experimental*. Os resultados reportados devem vir da segunda.

### 1.2 As quatro etapas do pipeline e o que cada uma mede

O pipeline do CoFlyers tem quatro etapas encadeadas. Cada uma responde a uma pergunta diferente, e a ordem não é arbitrária.

**Etapa 1 — Rapid Prototyping.** Uma simulação isolada em modelo ponto-massa idealizado. Pergunta: *dado um conjunto de parâmetros, como o enxame se comporta?* É a etapa mais barata (~28 s por execução) e serve de bloco de construção para todas as outras. Na fase de produção, ela é executada 20 vezes por algoritmo (análise de Monte Carlo) para gerar a distribuição das métricas.

**Etapa 2 — Auto-tuning.** Um algoritmo genético busca, no espaço de parâmetros, a combinação que minimiza a função de fitness. Pergunta: *qual é o melhor conjunto de parâmetros para este algoritmo neste ambiente?* Cada avaliação do GA é uma (ou várias) execução da Etapa 1. É a etapa mais cara.

**Etapa 3 — Batch Processing.** Varredura sistemática de dois parâmetros ambientais — tempo de amostragem de controle (Tc) e ruído de velocidade (η) — em grade 26×26 = 676 combinações. Pergunta: *quão robusto é o desempenho quando as condições do ambiente se degradam?* Aqui os parâmetros do algoritmo ficam fixos (os ótimos da Etapa 2) e o ambiente varia.

**Etapa 4 — High-fidelity.** Simulação com PX4 + Gazebo, dinâmica de quadrotor real, latência de comunicação UDP. Pergunta: *o desempenho medido no simulador idealizado se mantém sob dinâmica realista?* A diferença entre Etapa 1 e Etapa 4 é a **reality gap**.

**Por que esta ordem.** A Etapa 2 depende da 1 (o GA precisa avaliar simulações). As Etapas 3 e 4 dependem da 2 (precisam dos parâmetros ótimos). Rodar Monte Carlo antes do auto-tuning mediria parâmetros que serão substituídos.

### 1.3 Status atual, item por item

| Componente | Estado |
|---|---|
| Reformulação de tema, objetivo, perguntas, hipóteses | Concluído |
| Posicionamento taxonômico (esquema/estrutura/estratégia) | Concluído |
| Correção da contaminação de parâmetros Couzin→Reynolds | Concluído |
| Script de Monte Carlo (`main_monte_carlo_rapid_prototyping.m`) | Validado |
| Utilitário de escrita segura no XML (`xml_set_param_in_block.m`) | Validado |
| Geração de configurações pareadas (`prepare_paired_xmls.m`) | Validado |
| Função de fitness pareada (`fitness_paired_configs.m`) | Validado, **determinismo comprovado** |
| Driver do auto-tuning de produção (`main_auto_tuning_production.m`) | Validado em teste reduzido |
| **Auto-tuning de produção (4 algoritmos)** | **← próximo passo** |
| Monte Carlo de produção (4 algoritmos) | Aguarda auto-tuning |
| Batch de produção (3 repetições × 4 algoritmos) | Aguarda auto-tuning |
| High-fidelity de produção (5 execuções × 4 algoritmos) | Aguarda auto-tuning |
| Análise estatística comparativa | Aguarda todos os dados |

O Monte Carlo do Couzin já foi executado uma vez, mas como teste de fumaça do script — com os parâmetros antigos. Será refeito após o auto-tuning.

### 1.4 O valor de referência que você deve guardar

**F = 0.095482**

É o fitness do Couzin com os parâmetros do auto-tuning anterior (r_r = 4.805168, r_o = 23.161807, r_a = 32.780239, r_shill = 4.134955, w_shill = 3.408409), medido sobre as três configurações iniciais de treino (sementes 101, 102, 103).

Serve para duas coisas. Primeiro, é o *benchmark* contra o qual o auto-tuning de produção será julgado: se ele encontrar F menor, os novos parâmetros substituem os antigos; se não encontrar, você mantém os antigos e reporta que a busca ampliada confirmou o ótimo anterior — o que também é resultado publicável. Segundo, ele já demonstra generalização: 0.0954 medido em configurações aleatórias novas é ligeiramente melhor que os 0.103 medidos na grade fixa original, ou seja, os parâmetros não estavam sobreajustados à configuração de treino antiga.

---

## Parte 2 — As duas hipóteses: status e como são testadas

### 2.1 Elas continuam válidas

Nenhuma das duas foi alterada. Ambas continuam sendo o eixo argumentativo da dissertação.

> **Hipótese 1.** Algoritmos de flocking com maior complexidade paramétrica atingem desempenho superior em ambientes confinados após otimização, mas pagam um preço em robustez sob perturbações de tempo de amostragem e ruído de sensor.

> **Hipótese 2.** A arquitetura matemática de um algoritmo (regras heurísticas ponderadas × potenciais suaves × prioridade lexicográfica) determina a reality gap entre simulador idealizado e simulador realista de forma mais significativa que a complexidade paramétrica isolada.

### 2.2 Como cada etapa testa cada hipótese

Esta tabela é o esqueleto lógico do seu desenho experimental — vale reproduzi-la (adaptada) na metodologia.

| Etapa | Mede | Testa |
|---|---|---|
| Auto-tuning | Melhor fitness alcançável por cada algoritmo | H1, primeira metade (desempenho após otimização) |
| Monte Carlo (Rapid Prototyping) | Distribuição das métricas sob configurações iniciais variadas | H1, primeira metade, com rigor estatístico |
| Batch Processing | Degradação das métricas sob variação de Tc e η | H1, segunda metade (robustez sob perturbação) |
| Rapid Prototyping × High-fidelity | Diferença entre as duas condições | H2 (reality gap) |

A H1 é uma afirmação sobre **correlação entre número de parâmetros e duas quantidades opostas**: desempenho ótimo (esperado crescente com a complexidade) e robustez (esperada decrescente). Você tem quatro pontos no eixo da complexidade: 5 (Couzin), 6 (Reynolds), 8 (Olfati-Saber), 11 (Vasárhelyi). Com quatro pontos não se faz regressão confiável, então a análise será qualitativa e ordinal — verificar se a ordenação observada corresponde à prevista — e não um coeficiente de correlação com p-valor. Isso precisa estar claro na metodologia, sob pena de a banca cobrar o teste estatístico que quatro pontos não sustentam.

A H2 é uma afirmação sobre **qual fator explica melhor a reality gap**. Ela é testável porque as duas ordenações candidatas são diferentes: pela complexidade paramétrica, a ordem seria Couzin (5) < Reynolds (6) < Olfati-Saber (8) < Vasárhelyi (11); pela arquitetura, a previsão é que a prioridade lexicográfica do Couzin sofra mais com latência (porque um atraso faz o drone ultrapassar a fronteira r_r e disparar a repulsão desnecessariamente) e que a integração de aceleração do Olfati-Saber sofra em manutenção de velocidade. Os dados de validação já apontam nessa direção — o Couzin, o *menos* complexo, teve a *maior* reality gap em φ_corr, o que contraria a ordenação por complexidade e apoia a ordenação por arquitetura.

### 2.3 O que se fortaleceu desde a formulação original

**Primeiro reforço — o vazio taxonômico.** Ao aplicar a taxonomia de Ali et al. (2024) e Pita-Romero et al. (2025), verificou-se que os quatro algoritmos caem na mesma célula em todas as três dimensões: esquema pseudo-distribuído, estrutura *behavior-based*, estratégia tradicional. Isso tem duas consequências. A primeira é metodológica: com as três dimensões fixas, a complexidade paramétrica fica isolada como única variável livre, o que é a justificativa formal do desenho de condições idênticas. A segunda é que a taxonomia publicada é grossa demais para distinguir os quatro algoritmos — e a sub-classificação arquitetural da H2 (heurística ponderada / potencial suave / prioridade lexicográfica) é exatamente a granularidade que falta. A H2 deixa de ser só uma hipótese sobre reality gap e passa a ser uma **proposta de refinamento taxonômico**.

**Segundo reforço — a arquitetura afeta a própria otimização.** No auto-tuning do Couzin, o GA oscilou entre F ≈ 0.072 e F ≈ 0.098 sem convergência suave, diferente do Reynolds e do Olfati-Saber. A explicação é que a prioridade lexicográfica cria descontinuidades no espaço de fitness: uma mudança infinitesimal em r_r pode alternar o comportamento entre "só repulsão" e "orientação + atração", produzindo saltos. Isso é a mesma propriedade matemática que impede o Couzin de ser classificado como campo potencial (não existe função potencial cujo gradiente produza um *switch* descontínuo).

Ou seja: a arquitetura matemática afeta o desempenho, afeta a reality gap, **e afeta a topologia do problema de otimização**. Três manifestações da mesma causa. Se o auto-tuning de produção confirmar CV mais alto no Couzin que nos demais, você terá evidência quantitativa dessa terceira manifestação — algo que não estava previsto na formulação original da H2 e que a amplia.

---

## Parte 3 — Fundamentação estatística

Esta seção explica cada conceito na ordem em que ele aparece no pipeline, usando os seus próprios dados como exemplo.

### 3.1 Por que estatística, afinal

Considere duas afirmações:

> (a) O Reynolds tem fitness 0.006 e o Vasárhelyi tem 0.014.
> (b) O Reynolds tem fitness médio 0.006 (IC 95%: 0.005–0.007) e o Vasárhelyi 0.014 (IC 95%: 0.012–0.016).

A primeira descreve duas execuções. Se você repetir os experimentos, os números serão outros, e você não tem como saber se a diferença observada é real ou acaso. A segunda descreve o comportamento *típico* de cada algoritmo com uma medida explícita da incerteza — e como os intervalos não se sobrepõem, a diferença é sustentável.

Toda a fase de produção existe para transformar afirmações do tipo (a) em afirmações do tipo (b).

### 3.2 Números pseudoaleatórios e sementes

Computadores não geram números verdadeiramente aleatórios. Geram sequências **pseudoaleatórias**: produzidas por uma função determinística que, a partir de um valor inicial, gera uma sequência que passa nos testes estatísticos de aleatoriedade mas é perfeitamente reproduzível.

Esse valor inicial é a **semente** (*seed*). O MATLAB usa por padrão o gerador Mersenne Twister, invocado por `rng(seed, 'twister')`. A propriedade essencial: **mesma semente → mesma sequência, sempre, em qualquer máquina**.

É isso que torna reprodutibilidade possível. Sem controle de semente, cada execução usa uma sequência diferente e nenhum resultado individual pode ser recuperado.

**A regra que adotamos:** semente = número da execução. A execução 1 usa `rng(1)`, a execução 2 usa `rng(2)`, e assim por diante. Isso resolve simultaneamente dois requisitos que parecem opostos:

- as execuções precisam ser *diferentes* entre si (senão não haveria variabilidade a medir);
- o conjunto precisa ser *reproduzível* (senão nada pode ser verificado).

**Integridade científica.** As sementes foram fixadas *antes* de rodar os experimentos (1 a 20 para avaliação, 101 a 103 para treino). Isso não é detalhe burocrático: rodar, olhar os resultados, trocar as sementes e rodar de novo até obter números favoráveis é uma forma de *p-hacking*. Declarar as sementes de antemão e reportá-las é o que protege o trabalho dessa acusação.

### 3.3 Análise de Monte Carlo

O método nasceu nos anos 1940, no Projeto Manhattan, com Stanislaw Ulam e Nicholas Metropolis. O nome é uma referência ao cassino de Monte Carlo, onde o tio de Ulam jogava. A ideia central: quando um problema não tem solução analítica, amostre-o repetidamente e estude a distribuição dos resultados.

No seu caso, a pergunta sem solução analítica é: *dado que o enxame pode começar em qualquer configuração inicial, qual é o desempenho típico do algoritmo, e quanto ele varia?* Não há fórmula fechada. A resposta vem de simular 20 configurações diferentes e observar a distribuição das métricas.

**Por que 20.** É o número usado no artigo de flocking de robôs publicado em *Sensors* (2023) que serve de precedente metodológico recente, e é suficiente para que o teorema central do limite comece a operar sobre a média. Aumentar para 50 ou 100 estreitaria os intervalos, mas com retorno decrescente (a largura do intervalo cai com √n: quadruplicar o número de execuções apenas divide a largura pela metade).

**O que varia entre execuções (Decisão A).** Apenas a configuração inicial dos drones: posições X e Y sorteadas uniformemente dentro da arena de 60×60 m, com distância mínima de 5 m entre pares, altitude fixa em 1,0 m. O ruído de velocidade permanece em zero e os parâmetros do algoritmo são idênticos. Isolar uma única fonte de variação é o que permite atribuir a dispersão observada a ela.

**Sementes pareadas (Decisão B).** A geração das posições depende exclusivamente da semente, nunca do nome do algoritmo. Portanto a execução 7 do Couzin e a execução 7 do Reynolds partem *exatamente* da mesma configuração inicial. Os quatro algoritmos enfrentam os mesmos 20 cenários.

Isso não é preciosismo. Se cada algoritmo enfrentasse cenários diferentes, parte da diferença observada entre eles seria atribuível à sorte do sorteio. Com pareamento, essa fonte de variação é eliminada por construção — o que, além de tornar a comparação mais justa, aumenta o poder estatístico dos testes (ver §3.9).

### 3.4 Média

A média aritmética de *n* observações:

$$\bar{x} = \frac{1}{n}\sum_{i=1}^{n} x_i$$

É a estimativa central. No Monte Carlo do Couzin, φ_corr teve média 0.89178 sobre as 20 execuções.

### 3.5 Desvio-padrão

Mede quanto as observações *individuais* se espalham em torno da média:

$$s = \sqrt{\frac{1}{n-1}\sum_{i=1}^{n}(x_i - \bar{x})^2}$$

**Por que n−1 e não n.** Chama-se correção de Bessel. A intuição: você está estimando a dispersão em torno de uma média que também foi estimada a partir dos mesmos dados. As observações estão, por construção, um pouco mais próximas da média amostral do que da média verdadeira (desconhecida), o que faria a divisão por *n* subestimar sistematicamente a dispersão. Dividir por *n−1* corrige esse viés. Diz-se que se "gastou um grau de liberdade" ao estimar a média.

No Couzin, φ_corr teve desvio-padrão 0.01828. Interpretação concreta: execuções individuais tipicamente ficam a cerca de 0.018 da média — o que bate com o observado (valores entre 0.857 e 0.925).

### 3.6 Erro-padrão da média

Este é o conceito mais confundido de todos, e a distinção importa para escrever corretamente.

$$SEM = \frac{s}{\sqrt{n}}$$

**Desvio-padrão** responde: *quanto uma execução individual varia?*
**Erro-padrão** responde: *com que precisão eu conheço a média?*

São perguntas diferentes com respostas diferentes. Repare na consequência prática: aumentar o número de execuções **não reduz o desvio-padrão** — a variabilidade do fenômeno é o que é, e medi-lo mais vezes não o torna menos variável. Mas aumentar *n* **reduz o erro-padrão**, porque a média de muitas observações é mais estável que uma observação isolada.

É exatamente por isso que se roda Monte Carlo: não para reduzir a variabilidade do algoritmo, mas para reduzir a incerteza sobre o seu comportamento médio.

No Couzin: SEM de φ_corr = 0.01828 / √20 = 0.01828 / 4.4721 = **0.004088**. A média é conhecida com precisão cerca de 4,5 vezes melhor que uma execução individual.

### 3.7 Distribuição t de Student e o intervalo de confiança

**Por que não a distribuição normal.** Se você conhecesse o desvio-padrão verdadeiro da população, usaria a normal e o fator 1,96 para 95%. Mas você não conhece — estimou-o da amostra, e essa estimativa tem incerteza própria. Ignorar isso produziria intervalos otimistas demais (estreitos demais).

A solução foi publicada em 1908 por William Sealy Gosset, químico da cervejaria Guinness, sob o pseudônimo "Student" (a empresa proibia publicações dos funcionários). A distribuição t tem caudas mais pesadas que a normal, compensando a incerteza sobre *s*. Quanto menor a amostra, mais pesadas as caudas. Quando *n* cresce, a t converge para a normal.

**Graus de liberdade.** Para uma média amostral, são *n−1* — pelo mesmo motivo da correção de Bessel. Com *n* = 20, são 19 graus de liberdade, e o valor crítico bilateral a 95% é:

$$t_{0.975,\,19} = 2{,}093$$

Compare com o 1,96 da normal: o intervalo fica cerca de 7% mais largo. É esse o preço pago por não conhecer σ.

**A fórmula do intervalo:**

$$IC_{95\%} = \bar{x} \pm t_{0.975,\,n-1} \cdot \frac{s}{\sqrt{n}}$$

**Exemplo completo com os seus dados** (φ_corr do Couzin):

$$0{,}89178 \pm 2{,}093 \times \frac{0{,}01828}{\sqrt{20}} = 0{,}89178 \pm 2{,}093 \times 0{,}004088 = 0{,}89178 \pm 0{,}00856$$

$$IC_{95\%} = [0{,}88323;\ 0{,}90033]$$

que é exatamente o que o script reportou.

**O que o intervalo significa — e o que não significa.** A interpretação incorreta mais comum é "há 95% de probabilidade de o valor verdadeiro estar neste intervalo". A interpretação correta é frequentista: *se o procedimento inteiro fosse repetido muitas vezes, 95% dos intervalos assim construídos conteriam o valor verdadeiro*. O valor verdadeiro é fixo; o que varia de amostra para amostra é o intervalo.

Na prática, o uso comparativo é o que importa: **se os intervalos de dois algoritmos não se sobrepõem, a diferença entre eles é sustentável**. A recíproca, porém, não vale — intervalos que se sobrepõem *não* implicam ausência de diferença significativa. Essa é uma sutileza que uma banca rigorosa pode conhecer, e por isso a comparação formal deve ser feita com testes de hipótese (§3.9), não apenas por inspeção visual de intervalos.

### 3.8 Quando o intervalo de confiança não deve ser usado: o caso do F

O Monte Carlo do Couzin produziu, para a métrica F:

| | valor |
|---|---|
| média | 0.14370 |
| desvio-padrão | 0.17605 |
| IC 95% | [0.06130; 0.22609] |

**O desvio-padrão é maior que a média.** Isso é sinal de alarme. A causa está na execução 14: F = 0.8871, contra valores entre 0.068 e 0.142 em todas as outras 19.

O que houve nessa execução: φ_corr = 0.9089 (acima da média, portanto *melhor* alinhamento) e φ_vel normal. O que a diferencia é φ_coll = 5.54 × 10⁻⁵ — um instante brevíssimo em que dois drones se aproximaram além do limiar de 3 m.

Essa colisão minúscula inflou o F de ~0.10 para ~0.89, porque a Equação 6 penaliza colisões de forma **multiplicativa e quadrática**:

$$F = 1 - \frac{\text{Sat}(\varphi_{vel}) \cdot \varphi_{corr}}{(\varphi_{wall}/\lambda + 1)^2 \cdot (\varphi_{coll}/\lambda + 1)^2}$$

Isso é comportamento *projetado*, não defeito: a penalidade é deliberadamente íngreme para que o otimizador fuja de qualquer região que colida. Vásárhelyi et al. (2018) discutem exatamente esse ponto ao justificar por que a penalidade precisa ser contínua mas não suave demais.

**A consequência estatística.** A distribuição do F é **bimodal**: 19 valores agrupados em torno de 0.10 e 1 valor isolado em 0.89. O intervalo de confiança de Student pressupõe que a distribuição amostral da média seja aproximadamente normal, o que não vale aqui — a média foi puxada para 0.144 por um único ponto, e o intervalo resultante ([0.061; 0.226]) não contém nem sequer os valores típicos observados de forma representativa.

**A recomendação, que é um achado metodológico legítimo para a dissertação:**

- Use o **F como alvo de otimização** — é onde a penalidade íngreme faz exatamente o que deve.
- **Reporte as quatro métricas componentes separadamente** (φ_corr, φ_vel, φ_coll, φ_wall), cada uma com sua média e IC 95%. Todas elas são bem-comportadas: φ_corr, por exemplo, tem desvio-padrão de 0.018 e intervalo apertado.
- Se quiser reportar o F, use **mediana e intervalo interquartil** (estatísticas robustas a valores extremos) em vez de média e IC.

A formulação para a dissertação: *funções de fitness compostas com penalidades multiplicativas são adequadas como função-objetivo de busca e inadequadas como estatística descritiva, pois a penalidade íngreme produz distribuições fortemente assimétricas que violam os pressupostos dos intervalos de confiança paramétricos.*

### 3.9 Testes de hipótese para a comparação final

Os intervalos de confiança descrevem cada algoritmo isoladamente. Para afirmar que um difere de outro, é preciso um teste formal. Como as sementes são pareadas, você tem **dados emparelhados** — cada cenário inicial foi enfrentado pelos quatro algoritmos —, o que abre acesso a testes mais poderosos.

**Comparando dois algoritmos:**

- *Teste t pareado.* Calcula-se a diferença entre os dois algoritmos em cada um dos 20 cenários, e testa-se se a média dessas diferenças difere de zero. Pressupõe que as diferenças sejam aproximadamente normais. É mais poderoso que o teste t independente justamente porque o pareamento elimina a variação entre cenários.
- *Teste de Wilcoxon dos postos sinalizados.* Alternativa não paramétrica, sem pressuposto de normalidade. Use quando a distribuição das diferenças for claramente assimétrica — provavelmente o caso do F.

**Comparando os quatro simultaneamente:**

- *ANOVA de medidas repetidas.* Extensão do t pareado para mais de dois grupos. Se o resultado for significativo, aplica-se um teste *post hoc* (Tukey, ou Bonferroni) para identificar quais pares diferem.
- *Teste de Friedman.* Alternativa não paramétrica à ANOVA de medidas repetidas, seguida do teste de Nemenyi como *post hoc*.

**Correção para múltiplas comparações.** Com quatro algoritmos há seis pares possíveis. Testar todos ao nível de 5% cada eleva a probabilidade de pelo menos um falso positivo para cerca de 26%. A correção de Bonferroni resolve isso dividindo o nível pelo número de comparações (0,05 / 6 ≈ 0,008). Mencionar essa correção na metodologia demonstra rigor.

**Tamanho de efeito.** Significância estatística não é o mesmo que relevância prática — com amostras grandes, diferenças triviais tornam-se significativas. Reporte também o *d* de Cohen (diferença das médias dividida pelo desvio-padrão combinado), que quantifica *quão grande* é a diferença. Convenção usual: 0,2 pequeno, 0,5 médio, 0,8 grande.

### 3.10 Conceitos do auto-tuning

**Determinismo da função-objetivo.** Foi comprovado experimentalmente: o mesmo vetor de parâmetros avaliado duas vezes retornou F = 0.914894 nas duas, dígito por dígito. Isso decorre de três garantias combinadas: as posições iniciais estão fixadas nos XMLs de treino, o `rng` interno é fixado antes de cada repetição, e o ruído de velocidade é zero.

A importância disso: o algoritmo genético é estocástico (população inicial, seleção, cruzamento e mutação usam números aleatórios), mas com `UseParallel` esses operadores rodam no processo cliente — só as *avaliações* vão para os workers. Se a avaliação é determinística, então `rng(seed)` no cliente controla integralmente toda a estocasticidade do processo. **Você pode afirmar reprodutibilidade completa do auto-tuning, mesmo sob paralelismo.**

**Multi-start.** Algoritmos genéticos podem convergir para **ótimos locais**: pontos que são melhores que toda a sua vizinhança, mas piores que o ótimo global. A defesa padrão é executar a otimização várias vezes a partir de populações iniciais diferentes e comparar os resultados. Se todas convergirem para valores próximos, há evidência de que o ótimo é global; se divergirem, o espaço tem múltiplos ótimos locais.

Precedente direto: Vásárhelyi et al. (2018) rodaram pelo menos três otimizações independentes com inicialização aleatória, encontraram soluções muito similares, e reportaram a de maior fitness.

**Coeficiente de variação (CV).**

$$CV = \frac{s}{|\bar{x}|} \times 100\%$$

É o desvio-padrão expresso como percentual da média. Serve para comparar dispersão entre grandezas de escalas ou unidades diferentes: r_a (~30 m) e w_shill (adimensional, ~3) não têm desvios-padrão comparáveis diretamente, mas seus CVs sim.

Na análise de estabilidade, CV baixo (abaixo de ~20%) indica que as execuções independentes convergiram para o mesmo ponto — ótimo robusto. CV alto indica múltiplos ótimos locais, o que é resultado científico legítimo e deve ser discutido, não escondido.

**Avaliação pareada de candidatos (Nr = 3).** Cada candidato do GA é avaliado sobre as mesmas três configurações iniciais de treino, e o fitness reportado é a média. Isso tem dois efeitos: o GA busca parâmetros que funcionem bem *em geral* em vez de parâmetros ajustados a uma configuração particular (reduzindo sobreajuste); e a comparação entre candidatos é justa, já que todos enfrentam os mesmos cenários.

**Separação treino/teste.** Conceito emprestado do aprendizado de máquina. Os parâmetros são otimizados sobre um conjunto de configurações (treino: sementes 101, 102, 103) e avaliados sobre um conjunto disjunto (teste: sementes 1 a 20). Se os conjuntos se sobrepusessem, parte da avaliação estaria medindo desempenho nos próprios cenários de treino, o que superestima a qualidade. Com a separação, você pode afirmar que os parâmetros generalizam para configurações nunca vistas.

**Restrições lineares.** O GA busca dentro de uma região definida por limites inferiores e superiores. Restrições lineares adicionais, na forma A·x ≤ b, restringem ainda mais a região a combinações válidas. No Couzin, as zonas são concêntricas por definição, o que exige r_r ≤ r_o ≤ r_a; sem essa restrição, o GA pode gerar r_r = 4,8 e r_o = 3,5, invertendo as zonas. O código não acusa erro — a zona de orientação simplesmente nunca é acionada, e o algoritmo degrada silenciosamente. No Olfati-Saber, a função de ação exige a ≤ b para que a normalização (a+b)/√(4ab) faça sentido.

**Ótimos na fronteira.** Quando um parâmetro ótimo se acomoda no limite da faixa de busca, não é possível distinguir se aquele é o ótimo real ou apenas o melhor valor permitido pela restrição. No auto-tuning anterior, r_r do Couzin terminou a 96% da faixa e r_o a 92%, o que motivou o alargamento dos limites superiores. O script de produção sinaliza automaticamente qualquer parâmetro que termine acima de 90% ou abaixo de 10% da faixa.

---

## Parte 4 — Roteiro das próximas etapas

### 4.1 Orçamento de tempo de máquina

Estimativas baseadas na taxa medida no teste de fumaça: ~36 s por avaliação do GA com 6 workers, ~28 s por simulação isolada.

| Etapa | Configuração | Por algoritmo | **Total (4 algoritmos)** |
|---|---|---|---|
| Auto-tuning | 5 sementes × (pop 30 × ger 30) | ~44 h | **~176 h** |
| Monte Carlo | 20 execuções | ~10 min | **~40 min** |
| Batch Processing | 26×26 × 3 repetições | ~7 h | **~27 h** |
| High-fidelity | 5 execuções (**presencial**) | ~3,5 h | **~14 h** |
| | | | **~217 h** |

Cerca de 9 dias de máquina contínua. O auto-tuning sozinho representa 81% do total.

Duas observações. Primeira: se o cronograma apertar, o corte de 5 para 3 sementes no multi-start derruba o auto-tuning para ~106 h (total ~147 h) sem afetar a qualidade da busca — apenas o tamanho da amostra de estabilidade —, e o precedente de Vasárhelyi (≥3) cobre a escolha. Segunda: o high-fidelity é a única etapa que exige presença humana no console, para a sequência Arming → Takeoff → Alg → Hover → Land → Stop. As demais rodam desacompanhadas.

### 4.2 Sequência de execução

**Passo 1 — Auto-tuning de produção.** Restaure `POP_SIZE = 30` e `N_GEN = 30` no arquivo (estavam em 6 e 2 para o teste). Rode um algoritmo por vez, preferencialmente à noite, com `diary` ativo para preservar a saída:

```matlab
diary('log_at_couzin.txt');
main_auto_tuning_production('Couzin', 1:5);
diary off;
```

Ao final de cada algoritmo, examine três coisas na tabela de estabilidade: a coluna CV (acima de 20% indica múltiplos ótimos locais), a marcação "na fronteira" (indica limite restringindo a busca), e o `f_best_all` comparado ao benchmark do algoritmo.

**Passo 2 — Aplicação dos parâmetros.** Se o auto-tuning melhorou, aplique os novos valores. **Sempre** com o utilitário de escopo por bloco:

```matlab
xml_set_param_in_block('xml_config_files\parameters.xml', 'Couzin', ...
    {'r_r','r_o','r_a','r_shill','w_shill'}, x_final);
```

Nunca use `regexprep` global — foi o que contaminou `r_shill` e `w_shill` entre os blocos Couzin e Reynolds. Depois de aplicar, reexecute a verificação dos quatro blocos e confirme que apenas o bloco alvo mudou.

**Passo 3 — Monte Carlo de produção.** Barato (~40 min no total) e gera os intervalos de confiança que sustentam a comparação:

```matlab
main_monte_carlo_rapid_prototyping('Couzin')
main_monte_carlo_rapid_prototyping('Reynolds')
main_monte_carlo_rapid_prototyping('OlfatiSaber')
main_monte_carlo_rapid_prototyping('Vasarhelyi')
```

**Passo 4 — Batch de produção.** Requer adaptar o script de batch existente para três repetições com sementes controladas — a ser construído.

**Passo 5 — High-fidelity de produção.** Cinco execuções por algoritmo, presencial. Verifique o IP do PC-B com `ip -4 addr show` antes de cada sessão (é DHCP dinâmico).

**Passo 6 — Análise estatística comparativa.** Testes pareados, correção para múltiplas comparações, tamanhos de efeito, gráficos com barras de erro.

### 4.3 Decisão pendente sobre o Vasárhelyi

Nos experimentos de validação, os três algoritmos alternativos foram calibrados pelo GA do CoFlyers, enquanto o Vasárhelyi rodou com os parâmetros publicados (obtidos por CMA-ES pelos autores originais). Isso é uma assimetria de tratamento.

A decisão registrada é reotimizar o Vasárhelyi com o mesmo GA, o que uniformiza o tratamento e remove a assimetria. Os onze valores publicados estão todos dentro dos limites de busca configurados, então o GA pode reencontrá-los ou superá-los. Guardar os dois conjuntos rende uma discussão adicional: quanto do desempenho depende da calibração específica do ambiente.

---

## Parte 5 — O que escrever na seção de metodologia

Sugestão de estrutura para a "solução proposta", com os elementos que cada subseção deve conter.

**Plataforma e implementação.** CoFlyers como ambiente unificado; justificativa da escolha (única plataforma que oferece simulação idealizada e validação em alta fidelidade num pipeline unificado); contrato de interface padronizado que permite a comparação; as adaptações realizadas em cada algoritmo, categorizadas em compatibilidade computacional, interface e domínio físico, cada uma com seu precedente na literatura.

**Posicionamento taxonômico.** Classificação dos quatro algoritmos nas três dimensões de Ali et al. (2024) e Pita-Romero et al. (2025); demonstração de que os quatro compartilham esquema, estrutura e estratégia, o que isola a complexidade paramétrica como única variável livre; proposta da sub-classificação arquitetural como refinamento.

**Desenho experimental.** As quatro etapas do pipeline e o que cada uma mede; a escolha por condições idênticas em vez de condições ideais individuais, com sua justificativa; a tabela que mapeia etapas a hipóteses.

**Protocolo de reprodutibilidade.** Controle de sementes com a regra semente = número da execução; pareamento entre algoritmos; separação treino/teste; determinismo da função-objetivo comprovado experimentalmente; registro de todas as sementes e parâmetros.

**Tratamento estatístico.** Análise de Monte Carlo com 20 execuções; média, desvio-padrão e intervalos de confiança de 95% via distribuição t; justificativa para reportar métricas componentes em vez do fitness composto; testes de hipótese pareados com correção para múltiplas comparações; tamanhos de efeito.

**Limitações declaradas.** Quatro pontos no eixo de complexidade não sustentam regressão, apenas análise ordinal; a validação é por simulação de alta fidelidade, não por voo real; as conclusões são válidas dentro do escopo da plataforma CoFlyers com as adaptações documentadas.

---

## Referências metodológicas centrais

- Vásárhelyi, G. et al. (2018). Optimized flocking of autonomous drones in confined environments. *Science Robotics*, 3(20), eaat3536. — Fonte das métricas, da função de fitness e do procedimento de avaliação estocástica com otimizações independentes múltiplas.
- Huang, J., Wang, F., Hu, T. (2023). CoFlyers: A Universal Platform for Collective Flying of Swarm Drones. *IROS 2023*, 8808–8813. — A plataforma e seu pipeline de quatro etapas.
- Ali, Z.A., Alkhammash, E.H., Hasan, R. (2024). State-of-the-Art Flocking Strategies for the Collective Motion of Multi-Robots. *Machines*, 12(10), 739. — Taxonomia esquema/estrutura/estratégia.
- Pita-Romero, J. et al. (2025). Flocking behavior for dynamic and complex swarm structures. *ICUAS 2025*. — Adoção e refinamento da taxonomia; precedente de auto-classificação.
- Soria, E., Schiano, F., Floreano, D. (2020). SwarmLab: A Matlab Drone Swarm Simulator. *IROS 2020*. — Precedente de comparação controlada entre Olfati-Saber e Vasárhelyi numa plataforma comum.
- Reynolds, C.W. (1987); Vicsek, T. et al. (1995); Couzin, I.D. et al. (2002); Olfati-Saber, R. (2006). — Fontes primárias dos algoritmos.
