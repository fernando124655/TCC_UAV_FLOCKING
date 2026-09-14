# Sequência de Execução — Alta Fidelidade (Produção)

**40 execuções:** 4 algoritmos × 2 ambientes × 5 sementes
**Tempo estimado:** 15 a 20 min por execução → 10 a 13 h no total

Diferenças em relação à fase de validação:

- **dois** launches pareados por semente — um do Gazebo, outro do nó ROS
- o mundo Gazebo vem embutido no launch; não se copia mais `my_world_*.world`
- verificação obrigatória no PC-A antes de cada bloco de cinco
- verificação visual do pareamento na fase de Arming de cada execução
- nome de arquivo padronizado por algoritmo, ambiente e semente

> **Por que dois launches.** No PX4 SITL multi-veículo cada drone tem origem local própria, e o MAVROS reporta posição relativa a ela. O nó ROS soma o ponto de nascimento para reconstruir a coordenada de mundo. Se o Gazebo nascer os drones num lugar e o nó ROS assumir outro, o Commander recebe posições erradas — **sem erro, sem aviso, apenas dados inválidos**. Foi o que aconteceu na primeira tentativa.

---

## A. Setup — uma vez só

### A.1 — Transferir os launches

No PC-A a pasta é `Prototype_Simulator\hifi_launches`, com **20 arquivos**: 10 `hifi_*.launch` e 10 `node_*.launch`. Transfira para o PC-B e então:

```bash
sudo docker cp hifi_launches coflyers_sim:/root/
sudo docker exec -it coflyers_sim bash

# Gazebo + PX4 SITL
cp /root/hifi_launches/hifi_*.launch /root/PX4-Autopilot-v1.12/launch/

# ponte ROS  <<< PASTA DIFERENTE
cp /root/hifi_launches/node_*.launch \
   /root/CoFlyers/ros_ws/src/px4_sitl_coflyers/launch/

ls /root/PX4-Autopilot-v1.12/launch/hifi_*.launch | wc -l                    # 10
ls /root/CoFlyers/ros_ws/src/px4_sitl_coflyers/launch/node_*.launch | wc -l  # 10

# se o workspace precisar enxergar os novos launches
cd /root/CoFlyers/ros_ws && catkin_make 2>&1 | tail -3 && source devel/setup.bash
exit
```

> **Nome do container:** confirme com `sudo docker ps -a`. Nas anotações antigas aparece `coflyers_pcb`; se você renomeou para `coflyers_sim`, use este.

### A.2 — Utilitário de gravação

No PC-A, crie `Prototype_Simulator\salvar_hifi.m`:

```matlab
function salvar_hifi(algoritmo, ambiente, seed)
% Grava os dados da execucao com nome padronizado e caminho absoluto.
% Absoluto porque a execucao roda a partir de Simulink_Module.
    raiz = 'C:\Users\PCMALOCA\Documents\CoFlyers\matlab_simulink_ws\Prototype_Simulator';
    dest = fullfile(raiz, 'data_save', 'high_fidelity');
    if ~exist(dest, 'dir'); mkdir(dest); end

    vars = {'out','sample_time_base','sample_time_control_bottom', ...
            'number_real','number','params','map3d_faces','map3d_struct', ...
            'model_stls','terrain','terrain_params'};

    S = struct();
    faltando = {};
    for k = 1:numel(vars)
        if evalin('base', ['exist(''' vars{k} ''',''var'')']) == 1
            S.(vars{k}) = evalin('base', vars{k});
        else
            faltando{end+1} = vars{k};
        end
    end

    if ~isfield(S, 'out')
        error('Variavel "out" ausente. A simulacao chegou ao fim?');
    end
    if ~isempty(faltando)
        warning('Ausentes: %s', strjoin(faltando, ', '));
    end

    nome = fullfile(dest, sprintf('hifi_%s_%s_seed%d.mat', ...
        lower(algoritmo), ambiente, seed));
    save(nome, '-struct', 'S');

    d = dir(nome);
    fprintf('\n>>> SALVO: %s (%.1f MB)\n\n', nome, d.bytes/1e6);
end
```

### A.3 — Liberar o display (a cada reinício do PC-B)

```bash
xhost +local:
xhost
sudo docker start coflyers_sim
```

---

## B. Por bloco — a cada troca de algoritmo ou ambiente

**No PC-A**, a partir do `Prototype_Simulator`:

```matlab
cd('C:\Users\PCMALOCA\Documents\CoFlyers\matlab_simulink_ws\Prototype_Simulator');
addpath(genpath(pwd));
preparar_hifi('<algoritmo>', '<ambiente>');
```

Os sete itens devem aparecer como OK. **Não prossiga com nenhuma pendência.**

**No PC-B**, confirme o IP (é DHCP e já mudou uma vez):

```bash
ip -4 addr show | grep 192.168
```

Deve mostrar 192.168.1.157.

---

## C. Por execução

### C.1 — PC-B, Terminal 1: Gazebo + PX4 SITL

```bash
sudo docker exec -it coflyers_sim bash
export DISPLAY=:0
export LIBGL_ALWAYS_SOFTWARE=1
export QT_X11_NO_MITSHM=1
source ~/.bashrc
cd ~/PX4-Autopilot-v1.12
roslaunch px4 hifi_vazia_seed1.launch
```

Confirme visualmente: dez drones **espalhados**, não em grade 4×3 junto à parede esquerda. No ambiente com cubos, os quatro obstáculos em (±12, ±12).

Aguarde os dez inicializarem.

### C.2 — PC-B, Terminal 2: ponte ROS

```bash
sudo docker exec -it coflyers_sim bash
export DISPLAY=:0
source ~/.bashrc
roslaunch px4_sitl_coflyers node_vazia_seed1.launch
```

> **A semente tem que ser a mesma do Terminal 1.** `hifi_vazia_seed1` com `node_vazia_seed3` produz dados inválidos silenciosamente.

### C.3 — PC-B, Terminal 3: monitor de tráfego (opcional)

```bash
sudo docker exec -it coflyers_sim bash
sudo tcpdump -i any -n udp portrange 20000-21020
```

### C.4 — PC-A: executar o voo

```matlab
cd('C:\Users\PCMALOCA\Documents\CoFlyers\matlab_simulink_ws\Simulink_Module');
addpath(genpath('C:\Users\PCMALOCA\Documents\CoFlyers\matlab_simulink_ws\Prototype_Simulator'));
addpath(genpath(pwd));

init_condition;
disp(['sim_quad    = ', num2str(sim_quad)]);
disp(['number_real = ', num2str(number_real)]);
disp(['local_ip    = ', local_ip]);
disp(['algoritmo   = ', char(flag_alg)]);

open('testControlWithDroneSwarm.slx');
```

Esperado: `sim_quad = 0`, `number_real = 10`, `local_ip = 192.168.1.155`.

Clique em **Run**.

### C.4b — VERIFICAÇÃO DO PAREAMENTO (fase de Arming)

Ainda durante os 15 s de Arming, olhe a janela de visualização do MATLAB.

**Ela deve mostrar o enxame espalhado, na mesma configuração do Gazebo.**

Se mostrar uma grade compacta junto à parede esquerda, **pare imediatamente** — um dos dois launches é o antigo, ou as sementes não coincidem. Encerre tudo e recomece.

Esses trinta segundos de atenção evitam perder cinco minutos de voo e uma execução inteira.

### C.5 — Sequência de voo

**Arming (15 s) → Takeoff (30 s) → Alg (250 s) → Hover (10 s) → Land → Stop**

### C.6 — SALVAR ANTES DE PLOTAR

```matlab
salvar_hifi('Vasarhelyi', 'vazia', 1);
```

> **Crítico.** O `plot_hifi_paper_style.m` começa com `clear`. Plotar antes de salvar destrói os dados.

### C.7 — Verificação numérica (só na primeira execução de cada ambiente)

```matlab
S = load(fullfile('C:\Users\PCMALOCA\Documents\CoFlyers\matlab_simulink_ws', ...
    'Prototype_Simulator\data_save\high_fidelity\hifi_vasarhelyi_vazia_seed1.mat'));
D = S.out.states.Data;
k = find(S.out.states.Time > 50, 1);
fprintf('drone      x        y\n');
for i = 0:9
    fprintf('uav%-2d %8.2f %8.2f\n', i, D(k,17*i+6), D(k,17*i+7));
end
```

Compare com `hifi_launches\posicoes_iniciais.txt`. Os valores devem estar dispersos pela arena, **nunca** numa grade em x ≈ −28 com espaçamento 2,42.

### C.8 — Encerrar

`Ctrl+C` nos Terminais 1 e 2. Se algo ficar pendurado:

```bash
pkill -f gzserver; pkill -f gzclient; pkill -f px4
```

---

## D. Ordem dos oito blocos

Arena vazia primeiro: é a condição com auto-tuning, Monte Carlo e batch completos, então a *reality gap* medida ali é a mais bem contextualizada.

| # | algoritmo | ambiente | preparação |
|---|---|---|---|
| 1 | Vasárhelyi | vazia | `preparar_hifi('Vasarhelyi','vazia')` |
| 2 | Reynolds | vazia | `preparar_hifi('Reynolds','vazia')` |
| 3 | Couzin | vazia | `preparar_hifi('Couzin','vazia')` |
| 4 | Olfati-Saber | vazia | `preparar_hifi('OlfatiSaber','vazia')` |
| 5 | Vasárhelyi | cubos | `preparar_hifi('Vasarhelyi','cubos')` |
| 6 | Reynolds | cubos | `preparar_hifi('Reynolds','cubos')` |
| 7 | Couzin | cubos | `preparar_hifi('Couzin','cubos')` |
| 8 | Olfati-Saber | cubos | `preparar_hifi('OlfatiSaber','cubos')` |

**Por que Vasárhelyi primeiro:** não registrou violação alguma em 60 execuções de Rapid Prototyping. Se aparecer colisão ou saída de arena com ele, suspeite do setup antes do algoritmo.

---

## E. Registro

| bloco | algoritmo | ambiente | s1 | s2 | s3 | s4 | s5 | observações |
|:---:|---|---|---|---|---|---|---|---|
| 1 | Vasárhelyi | vazia | ☐ | ☐ | ☐ | ☐ | ☐ | |
| 2 | Reynolds | vazia | ☐ | ☐ | ☐ | ☐ | ☐ | |
| 3 | Couzin | vazia | ☐ | ☐ | ☐ | ☐ | ☐ | |
| 4 | Olfati-Saber | vazia | ☐ | ☐ | ☐ | ☐ | ☐ | |
| 5 | Vasárhelyi | cubos | ☐ | ☐ | ☐ | ☐ | ☐ | |
| 6 | Reynolds | cubos | ☐ | ☐ | ☐ | ☐ | ☐ | |
| 7 | Couzin | cubos | ☐ | ☐ | ☐ | ☐ | ☐ | |
| 8 | Olfati-Saber | cubos | ☐ | ☐ | ☐ | ☐ | ☐ | |

---

## F. Problemas comuns

**MATLAB mostra grade, Gazebo mostra dispersão.** O mais perigoso, porque não gera erro. Causas: o `node_*.launch` não foi copiado para `/root/CoFlyers/ros_ws/src/px4_sitl_coflyers/launch/`, ou as sementes dos dois terminais diferem. Confira os dois comandos de `roslaunch`.

**Drones nascem em grade compacta no Gazebo.** O `hifi_*.launch` antigo foi carregado.

**Nenhum tráfego no tcpdump.** O Terminal 2 não está rodando, ou o IP do PC-B mudou.

**Gazebo não abre.** O `xhost +local:` roda no host, não no container, e se perde ao reiniciar.

**Um drone não arma.** Encerre e relance. Registre a ocorrência.

**Obstáculos no Gazebo mas os drones os atravessam.** O XML do PC-A é o da arena vazia — sem shill agents. Rode a verificação.
