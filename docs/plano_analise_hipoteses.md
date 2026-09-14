# Plano de Análise: Dados Estatísticos por Hipótese

*Qual evidência sustenta ou refuta cada afirmação, com que teste, e o que já existe.*

---

## Parte 1 — Decompondo as hipóteses em afirmações testáveis

As duas hipóteses, como formuladas, contêm **quatro afirmações distintas**, cada uma exigindo dado e teste diferentes. Separá-las é o primeiro passo para uma análise honesta.

> **H1.** Algoritmos de flocking com maior complexidade paramétrica atingem desempenho superior em ambientes confinados após otimização, mas pagam um preço em robustez sob perturbações de tempo de amostragem e ruído de sensor.

**H1-A:** maior complexidade → melhor desempenho após otimização.
**H1-B:** maior complexidade → menor robustez sob perturbação.

> **H2.** A arquitetura matemática (regras heurísticas ponderadas × potenciais suaves × prioridade lexicográfica) determina a *reality gap* entre simulador idealizado e realista de forma mais significativa que a complexidade paramétrica isolada.

**H2-A:** a arquitetura determina a magnitude da *reality gap*.
**H2-B:** a arquitetura explica melhor que a complexidade paramétrica.

---

## Parte 2 — Inventário de dados

| conjunto | conteúdo | status |
|---|---|---|
| Auto-tuning | 4 algoritmos × 5 sementes; melhor F, estabilidade dos parâmetros | **completo** |
| Monte Carlo — arena vazia | 4 × 20 execuções pareadas; 6 métricas | **completo** |
| Monte Carlo — cilindros | 4 × 20 execuções pareadas | **completo** |
| Monte Carlo — cubos | 4 × 20 execuções pareadas | **completo** |
| Análise de generalização | degradação vazia → obstruído | **completo** |
| Batch processing | 4 × 2 ambientes × 676 combinações × 3 repetições | em execução |
| Alta fidelidade | 4 × 2 ambientes × 5 execuções | **não iniciado** |

---

## Parte 3 — H1-A: complexidade e desempenho

### Dados

**Tabela 1 — Desempenho após otimização (arena vazia)**

| algoritmo | parâmetros | melhor F (auto-tuning) | φ_corr, média (IC 95%) |
|---|---|---|---|
| Couzin | 5 | 0,0315 | 0,948 [0,942 – 0,953] |
| Reynolds | 6 | **0,0112** | **0,975 [0,960 – 0,991]** |
| Olfati-Saber | 7 | 0,0533 | 0,937 [0,928 – 0,945] |
| Vasárhelyi | 11 | 0,0275 | 0,922 [0,905 – 0,939] |

### Testes

**Correlação ordinal.** Spearman entre número de parâmetros e φ_corr: **ρ = −0,80**. A associação é negativa — mais parâmetros, pior alinhamento. Com n = 4, o valor crítico para significância a 5% é ρ = 1,0, portanto o resultado é **descritivo, não inferencial**. Declarar essa limitação explicitamente.

**Comparações pareadas.** Wilcoxon dos postos sinalizados, com correção de Bonferroni (α_c = 0,0083). Na arena vazia, 4 dos 6 pares são significativos; no ambiente com cubos, todos os 6. Reportar diferença média, p-valor e d de Cohen pareado.

### Veredito

**H1-A refutada**, e com sinal invertido em relação ao previsto. O algoritmo com mais parâmetros (11) fica em último no alinhamento; o melhor tem 6. A ordenação observada não é monotônica em direção alguma.

---

## Parte 4 — H1-B: complexidade e robustez

Há **duas fontes independentes** de evidência, e é importante distingui-las: uma mede robustez a mudança de ambiente, a outra a perturbação do sistema de controle.

### Fonte 1 — Robustez a mudança de ambiente (completo)

**Tabela 2 — Degradação de φ_corr, arena vazia → cubos**

| algoritmo | parâmetros | vazia | cubos | queda (pp) | p (Wilcoxon) |
|---|---|---|---|---|---|
| Reynolds | 6 | 0,975 | 0,928 | **−4,7** | 0,0013 |
| Couzin | 5 | 0,948 | 0,806 | −14,2 | 0,0001 |
| Vasárhelyi | 11 | 0,922 | 0,670 | −25,3 | 0,0001 |
| Olfati-Saber | 7 | 0,937 | 0,573 | **−36,4** | 0,0001 |

Spearman entre parâmetros e degradação: **ρ = +0,60**, tendência na direção prevista, novamente sem poder inferencial com n = 4.

Vale reportar também a mesma tabela para os cilindros, mostrando que a ordenação se mantém sob variação de geometria — Reynolds −4,3; Couzin −9,4; Vasárhelyi −11,6; Olfati-Saber −33,6.

### Fonte 2 — Robustez a perturbação de Tc e η (batch, pendente)

Métrica proposta: **amplitude de φ_corr** sobre a grade 26×26, ou seja, max − min. Amplitude maior indica maior sensibilidade.

Análise complementar recomendada: ajustar uma superfície de degradação e comparar os gradientes ∂φ_corr/∂Tc e ∂φ_corr/∂η entre algoritmos. Isso separa sensibilidade a latência de sensibilidade a ruído — possivelmente dimensões distintas por arquitetura.

Como o batch tem 3 repetições por combinação, também é possível reportar a variabilidade entre repetições em cada ponto da grade, indicando onde o comportamento é instável.

### Veredito preliminar

**H1-B parcialmente sustentada** pela Fonte 1. Aguarda a Fonte 2 para fechamento.

### A síntese que emerge

H1-A refutada com ρ = −0,80 e H1-B sustentada com ρ = +0,60 produzem, juntas, uma afirmação mais forte que qualquer uma isolada: **no cenário estudado, a complexidade paramétrica adicional não traz benefício de desempenho e está associada a maior perda de robustez.** É um resultado contraintuitivo e defensável.

---

## Parte 5 — H2: arquitetura e reality gap

### O problema de estado

A *reality gap* exige comparar Rapid Prototyping com High-Fidelity nas **mesmas condições**. Os dados de alta fidelidade da fase de validação não servem, por três razões documentadas: o mundo Gazebo continha um cilindro de 4,5 m e uma barreira em V ausentes do mapa CoFlyers; as paredes físicas estavam 0,5 m à frente da fronteira que o algoritmo enxergava; e os parâmetros eram os da validação, não os de produção.

**H2 não tem dado até que a alta fidelidade de produção seja executada.**

### Testes previstos

**Medida da reality gap.** Para cada algoritmo e ambiente: diferença pareada entre φ_corr no Rapid Prototyping e no High-Fidelity, sobre as mesmas configurações iniciais. Teste de Wilcoxon pareado; d de Cohen para magnitude.

**Comparação entre algoritmos.** Ordenar as *gaps* e verificar se a ordenação corresponde à classe arquitetural ou à complexidade paramétrica. Com quatro algoritmos, análise ordinal.

**Mecanismos a verificar.** Cada arquitetura gera uma previsão específica sobre *como* a latência degrada o comportamento: a prioridade lexicográfica do Couzin deve sofrer com transições espúrias quando o atraso faz o drone ultrapassar r_r; a integração de aceleração do Olfati-Saber deve acumular erro de discretização; a curva de frenagem do Vasárhelyi deve reduzir ainda mais a velocidade. Verificar cada previsão fortalece muito mais o argumento que apenas ordenar as *gaps*.

### Evidência já disponível para uma versão mais ampla da H2

Independentemente da *reality gap*, há um resultado completo e robusto sobre arquitetura:

**Tabela 3 — Perfil de falha por arquitetura (execuções com violação, de 20)**

| algoritmo | mecanismo de obstáculo | colisão (vazia / cubos) | parede (vazia / cubos) |
|---|---|---|---|
| Couzin | ZOR lexicográfica | **9 / 13** | 0 / 0 |
| Reynolds | repulsão 1/d² | 0 / 0 | **6 / 2** |
| Olfati-Saber | φ_β limitada | 0 / 0 | 1 / **20** |
| Vasárhelyi | curva de frenagem | 0 / 0 | 0 / 0 |

Cada arquitetura mantém seu tipo característico de falha ao mudar de ambiente e de geometria. Teste de McNemar pareado confirma que apenas o Olfati-Saber muda de comportamento significativamente entre ambientes (19 discordâncias unânimes, p < 0,00001); Couzin (p = 0,39) e Reynolds (p = 0,29) mantêm o perfil.

O mecanismo é identificável em cada caso: a prioridade lexicográfica torna a evitação de parede absoluta mas não impede aproximação transitória entre drones; a repulsão 1/d² diverge quando d → 0 e garante anticolisão, mas o peso de parede otimizado quase a zero deixa a fronteira desprotegida; a função φ_β é limitada (|φ_β| ≤ 1, força máxima ≈ c_arena = 6,04 m/s² contra max_a = 5,0) e não impõe barreira dura; a curva de frenagem garante ambas ao custo de velocidade.

**Sugestão:** considerar desdobrar a H2 em duas — uma sobre perfil de falha (dados completos, resultado forte) e outra sobre *reality gap* (a formulação original, aguardando dados). A primeira é possivelmente o achado mais robusto do trabalho.

---

## Parte 6 — Métricas: o que reportar e o que evitar

**φ_corr** é a métrica principal. Bem-comportada, desvios de 0,01 a 0,12, intervalos de confiança estreitos. Reportar média e IC 95%.

**φ_vel** exige ressalva obrigatória. Reynolds, Couzin e Olfati-Saber receberam normalização de velocidade constante (adaptação de Vicsek), que fixa φ_vel ≈ 1 por construção; o Vasárhelyi mantém autopropulsão nativa. Comparações entre algoritmos medem a adaptação, não a arquitetura. A leitura válida é **dentro** de cada algoritmo: o Vasárhelyi cai de 0,966 para 0,722 com cubos, uma perda de 25%, que é o mecanismo de frenagem trocando velocidade por segurança.

**φ_coll e φ_wall** devem ser reportadas como **contagem de execuções com violação**, nunca como média. Justificativa concreta: com cubos, o Reynolds tem média de φ_wall maior que a do Olfati-Saber (0,0079 contra 0,0041), mas viola em 2 de 20 contra 20 de 20 — a média do Reynolds é inflada por uma única execução extrema. Comparação por McNemar pareado.

**φ_MND** deve ser convertida para distância física: min(d) = r_coll/φ_MND, com r_coll = 0,4 m. Descrever corretamente como **média harmônica temporal da distância mínima entre pares** — a conversão do valor médio produz média harmônica, não aritmética.

| algoritmo | vazia (m) | cubos (m) |
|---|---|---|
| Couzin | 2,72 | 2,60 |
| Reynolds | 6,60 | 6,23 |
| Olfati-Saber | 7,16 | 5,18 |
| Vasárhelyi | 5,50 | 5,04 |

**F (fitness composta)** só é reportável quando não há violações. Três evidências independentes: distribuição bimodal quando há violações (Couzin na arena vazia, média 0,344 e desvio 0,359); saturação em 1 quando as violações são sistemáticas (Olfati-Saber com cubos, 0,99996 ± 0,00003, apesar de φ_corr variar de 0,468 a 0,761); e escala de tolerância herdada de um estudo com 100 agentes, cerca de 110 vezes mais sensível com 10 agentes. Usar como função-objetivo, não como estatística descritiva.

---

## Parte 7 — Figuras e tabelas do artigo

**Figura 1.** Barras de φ_corr com IC 95% por algoritmo, agrupadas por ambiente. Eixo horizontal ordenado por complexidade paramétrica, tornando visível a não-monotonicidade.

**Figura 2.** Contagem de violações por algoritmo e ambiente, separando colisão de parede. É a evidência visual do perfil de falha arquitetural.

**Figura 3.** Superfícies de φ_corr sobre a grade (Tc, η), uma por algoritmo. Do batch, pendente.

**Figura 4.** Comparação Rapid Prototyping × High-Fidelity por algoritmo, com a *reality gap* explícita. Pendente.

**Tabela 1.** Desempenho após otimização, com parâmetros e IC.
**Tabela 2.** Matriz de comparações pareadas — diferença, p de Wilcoxon, d de Cohen, significância pós-Bonferroni.
**Tabela 3.** Degradação por ambiente e ranking de robustez.
**Tabela 4.** Perfil de falha por arquitetura.
**Tabela 5.** Estabilidade dos parâmetros no multi-start — média, desvio, CV por parâmetro.

---

## Parte 8 — Decisões em aberto

**Pareamento na alta fidelidade.** Com 5 execuções, é preciso definir quais configurações iniciais serão usadas. Recomendação: usar as sementes 1 a 5, permitindo pareamento direto com as 5 primeiras execuções do Monte Carlo. Isso torna a *reality gap* uma diferença pareada com n = 5 — amostra pequena, mas com efeitos grandes esperados e ganho de poder pelo pareamento.

**Terceiro ambiente.** Os cilindros já têm Monte Carlo completo. Estender batch e alta fidelidade a eles custa +39 h de máquina e +14 h presenciais. Decisão a tomar no fim de setembro, conforme a folga.

**Reformulação da H2.** Se o desdobramento em duas hipóteses fizer sentido, vale ajustar o texto antes de escrever a seção de resultados.

---

## Parte 9 — O que já pode ser escrito

Com os dados completos, é possível redigir agora: toda a seção de metodologia; os resultados de auto-tuning com estabilidade de parâmetros; os resultados de Monte Carlo nos três ambientes com testes pareados; a análise de generalização; a discussão sobre perfil de falha arquitetural; e a discussão metodológica sobre limitações da fitness composta.

Aguardam dados apenas: a seção de robustez a Tc e η, a seção de *reality gap*, e a conclusão.
