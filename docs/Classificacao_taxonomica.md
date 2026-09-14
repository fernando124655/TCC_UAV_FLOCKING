A classificação do algoritmo de **Vásárhelyi (2018)** como uma estratégia de controle **Híbrida** justifica-se pela forma como o modelo é construído e validado na literatura técnica, especialmente sob a ótica da taxonomia de Ali et al. (2024) e Pita-Romero et al. (2025).

Embora você esteja correto ao afirmar que o algoritmo evolutivo (GA ou CMA-ES) calibra os parâmetros **offline** e não atua em tempo real na lei de controle, a estratégia é considerada híbrida pelos seguintes motivos:

### 1. Integração Metodológica (Modelo + Otimização)
Para os autores da taxonomia, a "estratégia" de um algoritmo de flocking engloba não apenas o que é executado a bordo, mas a **metodologia utilizada para guiar o movimento e garantir a formação**.
*   **Base Tradicional (Reynolds):** O motor do algoritmo são as leis de força clássicas de Reynolds (repulsão, alinhamento/fricção e autopropulsão).
*   **Base Moderna (Swarm Intelligence):** Vásárhelyi defende que "um modelo vale tanto quanto sua melhor instância", tornando a otimização evolutiva (uma técnica central da Inteligência de Enxame ou SI) uma **parte essencial da geração do modelo**. Na visão de Ali et al. (2024), abordagens modernas usam algoritmos bio-inspirados (como SI) para melhorar a flexibilidade e eficiência de métodos tradicionais, o que define o paradigma híbrido.

### 2. Otimização de Parâmetros como Diferencial Estratégico
Diferente de modelos de Reynolds "puros", onde os parâmetros são ajustados manualmente por tentativa e erro, o algoritmo de Vásárhelyi é indissociável de sua estrutura de otimização:
*   O uso de **CMA-ES** (ou GA na plataforma CoFlyers) é classificado por Ali et al. (2024) dentro da categoria de **Swarm Intelligence/Bio-inspired**.
*   Como Vásárhelyi utiliza essa técnica de SI para resolver o "problema de otimização altamente não trivial" de 11 parâmetros simultâneos, a estratégia resultante é o produto da união entre física de forças e computação evolutiva.

### 3. Tratamento Explícito de Restrições Cinéticas
A classificação híbrida também reflete a modificação que Vásárhelyi faz na regra de alinhamento de Reynolds. Ele substitui a função de decaimento de potência tradicional por uma **curva de frenagem ideal** baseada na aceleração máxima permitida. 
*   Essa abordagem aproxima o algoritmo de métodos de **planejamento de movimento**, que são frequentemente combinados com regras reativas em paradigmas híbridos para aumentar a robustez no mundo real.

Com base na taxonomia de estratégias de controle de *flocking* apresentada nos artigos de **Ali et al. (2024)** e **Pita-Romero et al. (2025)**, os algoritmos de Reynolds (1987), de Couzin (2002) e de Olfati-Saber (2006) são classificados da seguinte forma:

### 1. Algoritmo de Reynolds (1987)
*   **Tipo de Estratégia:** **Tradicional / Regras de Reynolds**.
*   **Justificativa:** É a base histórica do *flocking* computacional, fundamentada em três regras heurísticas simples: **coesão, separação e alinhamento**. Os autores classificam essa abordagem como "tradicional" por focar em comportamentos reativos básicos sem a necessidade de modelos matemáticos complexos ou otimizações modernas de inteligência artificial.

### 2. Algoritmo de Couzin (2002)
*   **Tipo de Estratégia:** **Bio-inspirada / Swarm Intelligence (Inteligência de Enxame)**.
*   **Justificativa:** O modelo de Couzin é uma estratégia estritamente bio-inspirada que mimetiza o comportamento coletivo observado em sistemas biológicos (como cardumes de peixes e bandos de aves) através de **zonas comportamentais** (repulsão, orientação e atração) e prioridades lexicográficas. Na taxonomia de Ali et al. (2024), abordagens que utilizam algoritmos inspirados em comportamentos naturais para coordenar o movimento coletivo entram na categoria de **Swarm Intelligence bio-inspired**.

### 3. Algoritmo de Olfati-Saber (2006)
*   **Tipo de Estratégia:** **Artificial Potential Fields (APF - Campos de Potencial Artificial)**.
*   **Justificativa:** Embora incorpore as regras de Reynolds, a estratégia de Olfati-Saber é baseada no rigor matemático de **funções de potencial coletivo** e termos baseados em gradiente. O movimento dos agentes é guiado por forças atrativas e repulsivas geradas por essas funções, o que o coloca como a referência teórica central para a estratégia de **Campos de Potencial (APF)** na literatura técnica.