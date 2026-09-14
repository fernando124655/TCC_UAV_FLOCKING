# Guia de Estudo: Estatística Aplicada na Análise Comparativa

*Cada teste usado, por que foi escolhido, o que responde, e o que estudar para defendê-lo.*

---

## Parte 1 — A decisão que estrutura tudo: desenho pareado

Antes de qualquer teste, é preciso entender por que o desenho experimental permite testes mais poderosos que o usual.

**Amostras independentes** ocorrem quando dois grupos são compostos por unidades diferentes — por exemplo, comparar o desempenho de dois algoritmos executados em cenários sorteados independentemente para cada um.

**Amostras pareadas** (ou dependentes) ocorrem quando cada observação de um grupo tem uma correspondente no outro. É o caso aqui: os quatro algoritmos foram avaliados sobre **exatamente as mesmas 20 configurações iniciais** (sementes 1 a 20).

Por que isso importa: a variação entre cenários (alguns são intrinsecamente mais difíceis) é uma fonte de ruído que, no desenho pareado, **se cancela**. Em vez de comparar duas distribuições, analisa-se a distribuição das *diferenças* dentro de cada par. Isso reduz a variância do estimador e aumenta o poder estatístico — a capacidade de detectar diferenças reais.

Consequência prática: com apenas 20 execuções por algoritmo, diferenças de 1 a 3 pontos percentuais tornaram-se detectáveis. Num desenho independente, seriam necessárias muito mais execuções.

**Para estudar:** desenho de blocos completos; correlação intraclasse; o conceito de poder estatístico e como o pareamento o aumenta.

---

## Parte 2 — Os testes aplicados

### 2.1 Teste t pareado

**O que faz.** Calcula a diferença entre os dois grupos em cada par, e testa se a média dessas diferenças é significativamente distinta de zero.

**Estatística de teste.** Sendo d̄ a média das diferenças, s_d o desvio-padrão delas e n o número de pares:

    t = d̄ / (s_d / √n)

Compara-se com a distribuição t de Student com n−1 graus de liberdade.

**Pressupostos.** As diferenças devem ser aproximadamente normais. Não é necessário que os dados originais sejam normais — apenas as diferenças. Também assume independência entre pares (satisfeita: cada execução usa semente distinta).

**Quando usar.** Comparação de duas condições sobre as mesmas unidades experimentais, com variável contínua e diferenças aproximadamente normais.

**Onde foi aplicado.** Comparações de φ_corr e φ_vel entre pares de algoritmos, e comparação vazia × obstáculos dentro de cada algoritmo.

**Limitação observada nos dados.** Na degradação do Reynolds, o teste t não detectou significância (p = 0,103) enquanto o Wilcoxon detectou (p = 0,0012). A causa é uma execução com φ_corr = 0,508, muito distante das demais, que infla s_d e reduz a estatística t. Testes paramétricos são sensíveis a valores extremos.

**Para estudar:** distribuição t de Student e sua origem histórica (Gosset, 1908); graus de liberdade; robustez do teste t a violações de normalidade.

---

### 2.2 Teste de Wilcoxon dos postos sinalizados

**O que faz.** Alternativa não paramétrica ao t pareado. Ordena as diferenças por magnitude absoluta, atribui postos, e testa se a soma dos postos positivos difere da dos negativos.

**Pressupostos.** Apenas que a distribuição das diferenças seja simétrica em torno da mediana. Não exige normalidade.

**Quando usar.** Amostras pequenas, distribuições assimétricas, presença de valores extremos, ou quando testes de normalidade rejeitam a hipótese de normalidade.

**Onde foi aplicado.** Todas as comparações pareadas, em paralelo ao teste t. Como os testes de normalidade rejeitaram normalidade em vários pares, o Wilcoxon é o resultado principal e o teste t serve como confirmação.

**Vantagem observada.** Por trabalhar com postos e não com valores, é imune a valores extremos. Detectou a degradação do Reynolds que o teste t não capturou.

**Custo.** Menor poder quando os dados são de fato normais — descarta informação sobre a magnitude das diferenças.

**Para estudar:** testes baseados em postos; eficiência relativa assintótica (o Wilcoxon retém cerca de 95% da eficiência do teste t sob normalidade); tratamento de empates.

---

### 2.3 Teste de Lilliefors (normalidade)

**O que faz.** Variante do teste de Kolmogorov-Smirnov que testa se uma amostra provém de distribuição normal com média e variância **estimadas dos próprios dados** (o KS clássico exige parâmetros conhecidos a priori).

**Hipótese nula.** Os dados provêm de distribuição normal. Portanto p < 0,05 **rejeita** normalidade.

**Onde foi aplicado.** Sobre as diferenças de φ_corr entre cada par de algoritmos, para decidir entre teste t e Wilcoxon.

**Cuidado na interpretação.** Um p-valor alto não prova normalidade — apenas indica ausência de evidência contra ela. Com n = 20, o teste tem poder limitado, então falhar em rejeitar é fraco como evidência.

**Alternativa mais poderosa.** O teste de Shapiro-Wilk tem poder superior para amostras pequenas e seria preferível se disponível.

**Para estudar:** função de distribuição empírica; teste de Kolmogorov-Smirnov; Shapiro-Wilk; gráficos Q-Q como alternativa visual (frequentemente mais informativos que o p-valor).

---

### 2.4 Teste de McNemar

**O que faz.** Testa mudança em variáveis **binárias pareadas**. Constrói uma tabela 2×2 com as quatro combinações possíveis e verifica se as discordâncias são simétricas.

**Estrutura da tabela.**

|  | B: sim | B: não |
|---|---|---|
| **A: sim** | n11 | n10 |
| **A: não** | n01 | n00 |

O teste ignora as concordâncias (n11 e n00) e examina apenas n10 e n01. Sob a hipótese nula, cada discordância tem probabilidade 1/2 de ir para cada lado.

**Versão exata.** Com poucas discordâncias, usa-se o teste binomial exato em vez da aproximação qui-quadrado — foi o caso aqui, com números pequenos.

**Quando usar.** Desfechos binários (ocorreu / não ocorreu) medidos nas mesmas unidades sob duas condições. É a versão pareada do teste qui-quadrado.

**Onde foi aplicado.** Comparação de violações de segurança (colisão ou parede) entre algoritmos e entre ambientes. Necessário porque φ_coll e φ_wall são zero na maioria das execuções — média e intervalo de confiança não fazem sentido para variáveis assim.

**Resultado notável.** Na comparação vazia × obstáculos do Olfati-Saber: 19 execuções passaram de segura para violação e nenhuma no sentido inverso, dando p < 0,00001.

**Para estudar:** tabelas de contingência; teste qui-quadrado e sua versão pareada; distribuição binomial; testes exatos versus aproximações assintóticas.

---

### 2.5 Correção de Bonferroni

**O problema que resolve.** Ao realizar múltiplos testes, a probabilidade de ao menos um falso positivo cresce. Com m testes independentes ao nível α, essa probabilidade é 1 − (1−α)^m. Com 6 comparações a 5%, chega a cerca de 26%.

**A correção.** Divide-se o nível de significância pelo número de comparações:

    α_corrigido = α / m

Com 6 pares: α_c = 0,05/6 ≈ 0,0083. Com 4 algoritmos na análise de generalização: α_c = 0,0125.

**Propriedade.** Controla a taxa de erro por família (FWER) — a probabilidade de cometer *qualquer* erro tipo I no conjunto de testes.

**Custo.** É conservadora: reduz o poder e aumenta a chance de falsos negativos. Assume independência entre testes, o que não vale aqui (as comparações compartilham dados), tornando-a ainda mais conservadora.

**Alternativas.** Holm-Bonferroni (sequencial, uniformemente mais poderosa); Benjamini-Hochberg (controla a taxa de descobertas falsas em vez do FWER, mais adequada quando há muitos testes exploratórios).

**Para estudar:** erro tipo I e tipo II; taxa de erro por família versus taxa de descobertas falsas; procedimento de Holm; quando cada abordagem é apropriada.

---

### 2.6 Tamanho de efeito: d de Cohen pareado

**O que faz.** Quantifica a **magnitude** da diferença, independentemente do tamanho da amostra:

    d_z = d̄ / s_d

**Por que é necessário.** Significância estatística responde "a diferença é real?" mas não "a diferença importa?". Com amostras grandes, diferenças triviais tornam-se significativas. O tamanho de efeito separa as duas perguntas.

**Convenção de interpretação** (Cohen, 1988): 0,2 pequeno; 0,5 médio; 0,8 grande. São referências, não regras — o que é "grande" depende do domínio.

**Onde foi aplicado.** Junto de cada teste pareado. Valores observados foram notavelmente altos: até 3,18 em φ_corr (Couzin vs Olfati-Saber com obstáculos) e 8,45 em φ_vel.

**Cuidado.** Valores muito altos de d costumam indicar não apenas diferença real, mas variância intragrupo muito pequena — que é o caso aqui, por causa do pareamento. Vale mencionar isso ao reportar.

**Para estudar:** famílias de tamanho de efeito (d, g de Hedges, r); relação entre tamanho de efeito, poder e tamanho amostral; análise de poder a priori.

---

### 2.7 Intervalos de confiança

**Construção.**

    IC 95% = x̄ ± t(0,975; n−1) × s/√n

Com n = 20, o valor crítico é t = 2,093.

**Interpretação correta.** Se o procedimento fosse repetido muitas vezes, 95% dos intervalos construídos conteriam o valor verdadeiro. O parâmetro é fixo; o intervalo é que varia entre amostras.

**Interpretação incorreta comum.** "Há 95% de probabilidade de o valor verdadeiro estar neste intervalo" — sob a ótica frequentista, isso não é o que o intervalo significa.

**Uso comparativo e sua armadilha.** Intervalos que não se sobrepõem indicam diferença significativa. Mas a recíproca **não vale**: intervalos que se sobrepõem podem ainda corresponder a diferença significativa, especialmente em desenhos pareados. Por isso a comparação formal deve usar testes de hipótese, não inspeção visual de barras de erro.

**Distinção fundamental.** Desvio-padrão mede a variabilidade das observações individuais; erro-padrão (s/√n) mede a precisão da estimativa da média. Aumentar n não reduz o desvio-padrão, mas reduz o erro-padrão.

**Para estudar:** interpretação frequentista versus bayesiana; intervalos de credibilidade; por que intervalos sobrepostos não implicam ausência de diferença.

---

## Parte 3 — Decisões metodológicas que a banca pode questionar

### Por que não ANOVA de medidas repetidas?

Seria a alternativa natural para comparar quatro grupos simultaneamente, seguida de teste post hoc. A opção por comparações pareadas com Bonferroni foi tomada por três razões: a ANOVA exige esfericidade (homogeneidade das variâncias das diferenças), pressuposto que não foi verificado; os testes de normalidade rejeitaram normalidade em vários pares; e as comparações par a par respondem diretamente às perguntas de interesse.

**Alternativa não paramétrica** que valeria mencionar: teste de Friedman, seguido de Nemenyi como post hoc.

### Por que a fitness composta não é reportada como estatística

Três evidências independentes sustentam essa decisão:

Primeira, **bimodalidade**. Quando há violações de segurança, a distribuição do F se separa em dois grupos, e o desvio-padrão supera a média (Couzin na arena vazia: média 0,344, desvio 0,359).

Segunda, **saturação**. Com violações sistemáticas, o F satura em 1 e perde toda capacidade de discriminar (Olfati-Saber com obstáculos: 0,99989 ± 0,00008, apesar de φ_corr variar de 0,468 a 0,761).

Terceira, **desproporção de escala**. A tolerância λ = 3×10⁻⁵ foi herdada de um estudo com 100 agentes; com 10 agentes, a resolução da métrica de colisão é cerca de 110 vezes mais grosseira, tornando a penalidade desproporcionalmente sensível a eventos transitórios.

Conclusão a declarar na metodologia: funções de fitness compostas com penalidades multiplicativas são adequadas como função-objetivo de otimização e inadequadas como estatística descritiva.

### Por que contagem em vez de média nas métricas de segurança

φ_coll e φ_wall são zero na maioria das execuções. Média e intervalo de confiança não são informativos para distribuições assim concentradas em zero, e a média é facilmente dominada por um único valor extremo.

Exemplo concreto: com obstáculos, o Reynolds tem média de φ_wall maior que a do Olfati-Saber (0,0044 contra 0,0025), mas viola em 2 de 20 execuções contra 20 de 20. A média do Reynolds é inflada por uma única execução com 0,0876. Reportar médias inverteria a conclusão.

### Limitação: quatro pontos não sustentam regressão

A H1 propõe relação entre complexidade paramétrica e desempenho, mas há apenas quatro algoritmos — quatro pontos no eixo de complexidade. Isso não permite análise de regressão nem coeficiente de correlação com interpretação confiável.

A análise é **ordinal**: verifica-se se a ordenação observada corresponde à prevista. Declarar isso explicitamente antecipa a crítica e demonstra compreensão dos limites do desenho.

---

## Parte 4 — Roteiro de estudo sugerido

**Nível 1 — fundamentos.** População e amostra; estatística descritiva; distribuições de probabilidade; teorema central do limite; distribuição normal e t de Student.

**Nível 2 — inferência.** Hipótese nula e alternativa; erro tipo I e tipo II; p-valor (e suas interpretações incorretas mais comuns); poder estatístico; intervalos de confiança.

**Nível 3 — testes específicos.** Teste t em suas três formas (uma amostra, duas amostras independentes, pareado); Wilcoxon dos postos sinalizados; Mann-Whitney (versão independente); McNemar; qui-quadrado.

**Nível 4 — questões avançadas.** Múltiplas comparações e controle de erro; tamanhos de efeito; verificação de pressupostos; testes não paramétricos e quando preferi-los.

**Referências.** Field, *Discovering Statistics Using IBM SPSS Statistics* (didático, com forte ênfase em interpretação); Montgomery, *Design and Analysis of Experiments* (desenho experimental, blocos, ANOVA); Wasserstein & Lazar (2016), declaração da American Statistical Association sobre p-valores — leitura curta e valiosa para evitar interpretações equivocadas.

---

## Parte 5 — Perguntas prováveis em banca

**"Por que 20 execuções?"** Segue o protocolo de Vasárhelyi et al. (2018) e de trabalhos recentes em flocking de robôs. É suficiente para o teorema central do limite operar sobre a média, e a largura do intervalo decresce com √n — quadruplicar o número apenas reduziria a largura pela metade.

**"Por que Bonferroni e não Holm?"** Bonferroni é mais conservadora e mais simples de justificar. Como as diferenças detectadas foram robustas mesmo sob o critério mais rigoroso, o conservadorismo não prejudicou as conclusões.

**"Os pressupostos foram verificados?"** Sim: normalidade das diferenças testada por Lilliefors, com rejeição em vários pares. Por isso o Wilcoxon é reportado como resultado principal e o teste t como confirmação — e ambos concordam em todos os casos.

**"Por que testes pareados?"** Porque o desenho experimental é pareado por construção: os quatro algoritmos foram avaliados sobre as mesmas configurações iniciais, geradas a partir das mesmas sementes. Ignorar o pareamento descartaria informação e reduziria o poder estatístico.

**"Como garantir que os resultados são reproduzíveis?"** Todas as sementes foram fixadas a priori (1 a 20 para avaliação, 101 a 103 para treino, conjuntos disjuntos), a função-objetivo foi verificada como determinística, e todos os parâmetros e resultados foram registrados por execução.
