# Mapa de Escrita do Artigo

*Atualizado após o fechamento da fase experimental. Todos os dados existem.*

---

## Restrição central: 25 páginas

Isso obriga três decisões antes de escrever a primeira linha.

**Uma única formalização em 4.2, não três.** O template pede UML, autômatos e redes de Petri. As três consumiriam de 6 a 8 páginas. Escolha o **autômato do Couzin**: é o único que sustenta diretamente uma hipótese, ao formalizar a descontinuidade da prioridade lexicográfica. UML e Petri viram uma menção de duas linhas em trabalhos futuros.

**Os resultados entram por hipótese, não por etapa.** Quatro etapas × três ambientes × quatro algoritmos geram dezenas de tabelas possíveis. Organize por afirmação: cada hipótese ganha uma tabela e, no máximo, uma figura.

**Nada de repetir números em texto e tabela.** Se está na tabela, o texto interpreta; não recita.

### Orçamento de páginas

| seção | páginas |
|---|---|
| 1. Introdução | 2,0 |
| 2. Fundamentação / trabalhos relacionados | 3,0 |
| 3. Solução proposta (4.1 a 4.3 do template) | 5,0 |
| 4. Avaliação experimental — projeto | 4,0 |
| 5. Avaliação experimental — resultados e discussão | 7,5 |
| 6. Considerações finais | 1,5 |
| Referências | 2,0 |
| **total** | **25,0** |

---

## As hipóteses, na forma final

A H2 desdobra-se em duas porque os dados mostram dois fenômenos distintos, com evidência de qualidade diferente.

> **H1-A.** Maior complexidade paramétrica → melhor desempenho após otimização.
> **REFUTADA**, com sinal invertido (Spearman ρ = −0,80).

> **H1-B.** Maior complexidade paramétrica → menor robustez sob perturbação.
> **SUSTENTADA** por duas fontes independentes (ρ = +0,60 na degradação entre ambientes).

> **H2-A.** A arquitetura matemática determina o **tipo de falha de segurança**, de forma estável entre ambientes e níveis de fidelidade.
> **SUSTENTADA**. Evidência mais robusta do trabalho.

> **H2-B.** A arquitetura determina a **reality gap** mais que a complexidade paramétrica.
> **SUSTENTADA por via negativa**: a complexidade não prediz de forma estável (ρ inverte de −1,00 para +0,40 conforme o ambiente), enquanto a ordenação arquitetural se repete em duas geometrias.

E um achado não previsto:

> **Gradiente de dificuldade de superfície.** A reality gap dos algoritmos com mecanismo de frenagem ordena-se em arena vazia → cilindros → cubos; os sem frenagem permanecem estáveis. Isola o mecanismo em vez de apenas observar o efeito.

---

## Seção 3 — Solução proposta (5 páginas)

### 3.1 Arquitetura (1,5 pág + 2 figuras)

**Figura 1 — visão geral.** As duas máquinas, o enlace UDP, os quatro módulos de algoritmo conectados ao mesmo ponto da arquitetura.

**Figura 2 — pipeline.** As quatro etapas com artefato de entrada e saída de cada uma.

O texto precisa cobrir: a divisão Commander/Simulator e por que ela existe (transferibilidade para hardware real); o argumento de **reuso de código** — o mesmo arquivo `.m` roda nas quatro etapas, o que é o que valida a medição de reality gap, porque a diferença observada não pode ser artefato de reimplementação; os três modos de `sim_quad`; e o mecanismo de shill agents com sua consequência (uniformiza o tratamento de obstáculos entre algoritmos, ao custo de forçar adaptação em quem foi formulado com outra representação).

### 3.2 Modelagem: autômato do Couzin (1,5 pág + 1 figura)

**Figura 3 — autômato de dois estados.** `q0` repulsão pura, `q1` modo social; transições condicionadas à presença de vizinho dentro de `r_r`.

O argumento a desenvolver: a comutação é descontínua e não existe potencial escalar cujo gradiente a produza. Três consequências decorrem disso, e é essa convergência que dá força ao modelo — impede classificar o Couzin como campo potencial; explica a fragmentação do espaço de fitness observada no multi-start; e prevê a sensibilidade a latência, já que o atraso do PX4 faz o drone ultrapassar `r_r` e dispara transições espúrias.

Contraste explícito: os outros três são somas ponderadas contínuas e não admitem representação por autômato.

Declarar que a verificação foi analítica e empírica, não por *model checking*.

### 3.3 Ambiente de desenvolvimento (1 pág)

Tabela com ferramenta, versão e papel. PC-A com Windows 11 e MATLAB R2026a; PC-B com Ubuntu 24.04, Docker, PX4-SITL v1.12.3, Gazebo Classic 11, ROS Noetic e MAVROS. A cadeia de comunicação em um parágrafo.

### 3.4 Algoritmos e adaptações (1 pág)

Tabela: algoritmo, referência, parâmetros otimizados (5, 6, 7, 11), classe arquitetural.

As adaptações em três categorias, cada uma com precedente: compatibilidade computacional (sintaxe do Coder, neutra); interface (empacotamento, lógica interna inalterada); domínio físico (autopropulsão no Reynolds, β-agents no Olfati-Saber, conversão da taxa de virada no Couzin).

Ponto forte a incluir: a remoção do agente γ é decisão **estrutural**, não apenas matemática — mantê-lo tornaria o Olfati-Saber *leader-follower* enquanto os demais são *behavior-based*, confundindo arquitetura com estrutura.

---

## Seção 4 — Projeto de avaliação (4 páginas)

### 4.1 Questões e hipóteses (0,5 pág)
As duas questões de pesquisa e as quatro afirmações testáveis acima.

### 4.2 Posicionamento taxonômico (0,5 pág)
Os quatro compartilham esquema (pseudo-distribuído), estrutura (*behavior-based*) e estratégia (tradicional). Com as três dimensões fixas, a complexidade paramétrica fica isolada como única variável livre — é a justificativa formal do desenho de condições idênticas. A sub-classificação arquitetural é a granularidade que o trabalho acrescenta.

### 4.3 Desenho experimental (1,5 pág)

Ambiente: arena de 60×60 m, 10 drones, v_flock = 1,0 m/s. Três ambientes: vazio, 4 cilindros de 6 m e 4 cubos de 6 m em (±12, ±12), com corredores de 18 m.

**Calibração feita apenas na arena vazia.** Os ambientes obstruídos são teste de generalização — isso precisa estar em destaque, porque muda a interpretação de tudo.

Volume: auto-tuning com 5 sementes × (população 30 × 30 gerações), Nr = 3; Monte Carlo com 20 execuções em 3 ambientes; batch em grade 26×26 com 3 repetições em 2 ambientes; alta fidelidade com 5 execuções em 3 ambientes.

Tabela mapeando etapa → hipótese.

### 4.4 Reprodutibilidade (0,75 pág)

Regra semente = número da execução. Conjuntos disjuntos: treino 101–103, teste 1–20, batch 201–203, alta fidelidade 1–5 pareadas com o Monte Carlo. Sementes fixadas a priori, protegendo contra seleção *post hoc*. Determinismo da função-objetivo comprovado experimentalmente.

Limitação a declarar: na alta fidelidade as sementes controlam apenas as posições iniciais; Gazebo e PX4 têm estocasticidade própria.

### 4.5 Métricas e tratamento estatístico (0,75 pág)

Definir as métricas **como implementadas**, não como no paper. Três divergências a declarar: φ_corr é o parâmetro de ordem de Vicsek com correção de tamanho finito, não a correlação por cluster; φ_wall é fração de agentes em violação, não profundidade de penetração; a fitness usa F₃ para parede em vez de F₂, e não tem os termos de agentes desconectados e tamanho de cluster.

Testes: Wilcoxon pareado como principal (normalidade rejeitada), t pareado como confirmação, Bonferroni para 6 pares, d de Cohen.

Justificar em duas frases por que o F composto não é reportado como estatística: distribuição bimodal quando há violações, e saturação em 1 quando elas são sistemáticas.

---

## Seção 5 — Resultados e discussão (7,5 páginas)

### 5.1 Desempenho após otimização — H1-A (1,5 pág)

**Tabela 1.** Algoritmo, parâmetros, melhor F do auto-tuning, φ_corr do Monte Carlo com IC 95%.

Números: Couzin (5) 0,948; Reynolds (6) **0,975**; Olfati-Saber (7) 0,937; Vasárhelyi (11) 0,922.

Interpretação: não-monotônico. O de 6 parâmetros vence, o de 11 fica em último. Spearman ρ = −0,80, com a ressalva de que n = 4 torna o valor descritivo. **H1-A refutada com sinal invertido.**

### 5.2 Robustez — H1-B (1,5 pág + Figura 4)

**Tabela 2.** Degradação de φ_corr da arena vazia para os ambientes obstruídos, mais amplitude na grade do batch.

Ranking de robustez: Reynolds (−4,7 pp), Couzin (−14,2), Vasárhelyi (−25,3), Olfati-Saber (−36,4). Os dois mais simples são os dois mais robustos. ρ = +0,60.

**H1-B sustentada.** Combinada com 5.1: complexidade paramétrica não traz benefício e traz custo.

### 5.3 Perfil de falha por arquitetura — H2-A (1,5 pág + Figura 5)

**Tabela 3.** Contagem de execuções com violação, por algoritmo, tipo e ambiente, nas duas etapas.

Couzin colide entre drones; Reynolds sai da arena; Olfati-Saber penetra fronteiras; Vasárhelyi não viola nada em **100 execuções**. O padrão é estável em três geometrias e dois níveis de fidelidade. McNemar pareado.

Mecanismo de cada caso: prioridade lexicográfica torna a parede absoluta mas não impede aproximação transitória; repulsão 1/d² diverge e garante anticolisão, mas o peso de parede otimizado quase a zero desprotege a fronteira; φ_β é limitada (|φ_β| ≤ 1) e não impõe barreira dura; a curva de frenagem garante ambas ao custo de velocidade.

**Achado central: suavidade e barreira dura são incompatíveis.**

### 5.4 Reality gap — H2-B (2 pág + Figura 6)

**Tabela 4.** Reality gap por algoritmo nos três ambientes, com p de Wilcoxon e d de Cohen.

Na arena vazia os quatro degradam entre 6,4 e 8,8 pontos. Com obstáculos separam-se: Couzin e Olfati-Saber permanecem em ~8; Reynolds e Vasárhelyi saltam para 23,8 e 27,0.

**O gradiente de superfície**, em um parágrafo: vazia → cilindros → cubos dá 8,7 → 19,4 → 23,8 no Reynolds e 6,4 → 25,0 → 27,0 no Vasárhelyi, enquanto Couzin e Olfati-Saber ficam estáveis. Os dois que degradam são exatamente os que freiam — φ_vel cai para 0,758 e 0,648 com cubos contra ~0,96 dos outros. Faces planas exigem frenagem frontal sem guia lateral; superfícies curvas oferecem componente tangencial.

Spearman contra complexidade: −1,00 na arena vazia, +0,40 nas obstruídas. **Inverte de sinal** — não há relação estável. A ordenação arquitetural, essa se repete.

Declarar: com n = 5 o menor p possível no Wilcoxon é 0,0625; a leitura é por tamanho de efeito e consistência de sinal.

### 5.5 Limitações (1 pág)

Quatro pontos no eixo de complexidade não sustentam regressão; a análise é ordinal. Validação por simulação de alta fidelidade, não por voo real. Conclusões válidas no escopo da plataforma com as adaptações documentadas. Esquema pseudo-distribuído. φ_vel não é comparável entre algoritmos, porque três receberam normalização de Vicsek e o Vasárhelyi não — a leitura válida é dentro de cada um. Percepção idealizada, sem oclusão nem ruído sensorial. Tolerância de colisão herdada de estudo com 100 agentes, 110× mais sensível com 10.

---

## Seção 6 — Considerações finais (1,5 pág)

**Contribuições.** Metodológica: conjunto documentado de adaptações para generalizar o pipeline da plataforma a novas famílias algorítmicas, mais o protocolo de reprodutibilidade. Empírica: primeiro conjunto comparativo de quatro arquiteturas em quatro etapas e três ambientes. Analítica: caracterização dos compromissos entre complexidade, desempenho, robustez e reality gap, com identificação de mecanismos.

**Trabalhos futuros.** Voo com aeronaves reais; percepção embarcada com LiDAR; comparação entre métodos de otimização; verificação formal; algoritmos de cobertura.

---

## Ordem de escrita sugerida

Comece pelo que não depende de interpretação: 3.3 ambiente, 3.4 algoritmos, 3.1 arquitetura. Depois a seção 4 inteira, que é onde está o grosso do que foi construído. Resultados e discussão por último, com o resto de pé.

## Cortes possíveis, se estourar

Nesta ordem: reduzir 3.2 a uma página; fundir 5.1 e 5.2 numa seção de H1; mover parte das limitações para nota de rodapé; cortar a Figura 4 e deixar a Tabela 2 falar sozinha.
