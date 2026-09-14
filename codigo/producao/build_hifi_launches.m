function build_hifi_launches(seeds, out_dir)
% BUILD_HIFI_LAUNCHES
% Gera os arquivos .launch da alta fidelidade com posicoes iniciais
% PAREADAS as configuracoes do Monte Carlo.
%
% MOTIVACAO: o launch original posiciona os 10 drones numa grade fixa 4x3
% de espacamento 2.42 m junto a parede esquerda (x de -28 a -20.74). Isso
% nao corresponde a nenhuma das configuracoes usadas no Rapid Prototyping,
% o que impediria medir a reality gap como diferenca PAREADA.
%
% Este gerador substitui as expressoes $(eval ...) por coordenadas
% explicitas, reproduzindo exatamente as posicoes que
% main_monte_carlo_rapid_prototyping gera para cada semente -- mesma
% sequencia de sorteios, mesmos criterios de rejeicao.
%
% Tambem embute o mundo Gazebo correspondente em cada arquivo, dispensando
% a copia manual de my_world_*.world -> my_world.world.
%
% ENTRADAS (opcionais):
%   seeds   : vetor de sementes (padrao 1:5, pareadas com o Monte Carlo)
%   out_dir : pasta de saida (padrao 'hifi_launches')
%
% SAIDA: <out_dir>/hifi_<ambiente>_seed<N>.launch  e um resumo em texto.
%
% USO:  build_hifi_launches
%       build_hifi_launches(1:5)

if nargin < 1 || isempty(seeds);   seeds = 1:5;              end
if nargin < 2 || isempty(out_dir); out_dir = 'hifi_launches'; end
if ~exist(out_dir, 'dir'); mkdir(out_dir); end

% Parametros IDENTICOS aos do Monte Carlo
N_DRONES = 10;
D_MIN    = 5.0;
Z_INIT   = 1.0;      % usado so na geracao; no Gazebo os drones nascem em z=0
MARGEM   = 2.0;
X_RANGE  = [-30, 30];
Y_RANGE  = [-30, 30];

ambientes = {'vazia', 'cubos', 'cilindros'};
mundos    = {'my_world_vazia.world', 'my_world_cubos.world', 'my_world_cilindros.world'};
obst_list = { [], ...
              [-12 -12  12  12
               -12  12 -12  12
               4.243 4.243 4.243 4.243], ...   % cubo lado 6 -> raio circunscrito
              [-12 -12  12  12
               -12  12 -12  12
               3.000 3.000 3.000 3.000] };     % cilindro diametro 6 -> raio 3

fid_res = fopen(fullfile(out_dir, 'posicoes_iniciais.txt'), 'w');
fprintf(fid_res, 'POSICOES INICIAIS DA ALTA FIDELIDADE\n');
fprintf(fid_res, 'Pareadas com as sementes do Monte Carlo.\n');
fprintf(fid_res, 'Geradas em %s\n\n', char(datetime('now')));

for e = 1:numel(ambientes)
    for s = seeds
        pos = gera_posicoes(N_DRONES, X_RANGE, Y_RANGE, Z_INIT, D_MIN, ...
            s, obst_list{e}, MARGEM);

        arq = fullfile(out_dir, sprintf('hifi_%s_seed%d.launch', ambientes{e}, s));
        escreve_launch(arq, pos, mundos{e}, ambientes{e}, s);

        % O no ROS reconstroi a coordenada de mundo somando o ponto de
        % nascimento a posicao local do MAVROS (cada drone do PX4 SITL tem
        % origem local propria). Portanto ELE TAMBEM precisa das novas
        % coordenadas -- se ficar com a grade antiga, o Commander recebe
        % posicoes erradas e o experimento e invalidado silenciosamente.
        arq_node = fullfile(out_dir, sprintf('node_%s_seed%d.launch', ambientes{e}, s));
        escreve_launch_node(arq_node, pos, ambientes{e}, s);

        % verificacoes
        dmin_real = inf;
        for i = 1:N_DRONES
            for j = i+1:N_DRONES
                dmin_real = min(dmin_real, hypot(pos(1,i)-pos(1,j), ...
                                                 pos(2,i)-pos(2,j)));
            end
        end
        dobst = inf;
        O = obst_list{e};
        for k = 1:size(O,2)
            for i = 1:N_DRONES
                dobst = min(dobst, hypot(pos(1,i)-O(1,k), pos(2,i)-O(2,k)) - O(3,k));
            end
        end

        fprintf('%-18s seed %d | d_min drones %.2f m', ...
            ambientes{e}, s, dmin_real);
        if isfinite(dobst)
            fprintf(' | folga p/ obstaculo %.2f m', dobst);
        end
        fprintf('\n');

        fprintf(fid_res, '--- %s, semente %d ---\n', ambientes{e}, s);
        fprintf(fid_res, '  drone      x         y\n');
        for i = 1:N_DRONES
            fprintf(fid_res, '  uav%-2d %9.4f %9.4f\n', i-1, pos(1,i), pos(2,i));
        end
        fprintf(fid_res, '  distancia minima entre drones: %.3f m\n', dmin_real);
        if isfinite(dobst)
            fprintf(fid_res, '  folga minima ate obstaculo   : %.3f m\n', dobst);
        end
        fprintf(fid_res, '\n');
    end
end
fclose(fid_res);

fprintf('\n%d arquivos gerados em %s/ (%d do Gazebo + %d do no ROS)\n', ...
    2*numel(seeds)*numel(ambientes), out_dir, ...
    numel(seeds)*numel(ambientes), numel(seeds)*numel(ambientes));
fprintf('Resumo das posicoes em %s/posicoes_iniciais.txt\n\n', out_dir);
fprintf('ATENCAO: os DOIS launches devem ser da mesma semente e ambiente.\n');
fprintf('O no ROS soma o ponto de nascimento a posicao local do MAVROS;\n');
fprintf('se ele usar coordenadas diferentes das do Gazebo, o Commander\n');
fprintf('recebe posicoes erradas e o experimento e invalidado sem aviso.\n\n');
fprintf('Instalacao no PC-B:\n');
fprintf('  sudo docker cp %s coflyers_pcb:/root/\n', out_dir);
fprintf('  cp /root/%s/hifi_*.launch /root/PX4-Autopilot-v1.12/launch/\n', out_dir);
fprintf('  cp /root/%s/node_*.launch /root/CoFlyers/ros_ws/src/px4_sitl_coflyers/launch/\n', out_dir);
fprintf('\nLancamento (Terminal 1 e Terminal 2, MESMA semente):\n');
fprintf('  roslaunch px4 hifi_cubos_seed3.launch\n');
fprintf('  roslaunch px4_sitl_coflyers node_cubos_seed3.launch\n');
end


%% ============================================================
function pos = gera_posicoes(N, x_range, y_range, z, d_min, seed, obst, margem)
% Replica EXATAMENTE a logica de main_monte_carlo_rapid_prototyping:
% mesma ordem de sorteios e mesmos criterios de rejeicao, garantindo que
% a semente k produza a mesma configuracao nas duas etapas.
rng(seed, 'twister');
pos = zeros(3, N);
pos(3, :) = z;

margin = d_min;
xlo = x_range(1) + margin; xhi = x_range(2) - margin;
ylo = y_range(1) + margin; yhi = y_range(2) - margin;

n_obst = size(obst, 2);
placed = 0; tries = 0;
while placed < N
    tries = tries + 1;
    if tries > 100000
        error('Nao foi possivel posicionar %d drones (semente %d).', N, seed);
    end
    cx = xlo + (xhi - xlo) * rand();
    cy = ylo + (yhi - ylo) * rand();

    ok = true;
    for k = 1:n_obst
        if hypot(cx - obst(1,k), cy - obst(2,k)) < obst(3,k) + margem
            ok = false; break;
        end
    end
    if ok
        for j = 1:placed
            if hypot(cx - pos(1,j), cy - pos(2,j)) < d_min
                ok = false; break;
            end
        end
    end
    if ok
        placed = placed + 1;
        pos(1, placed) = cx;
        pos(2, placed) = cy;
    end
end
end

%% ============================================================
function escreve_launch_node(arq, pos, ambiente, seed)
% Launch do no ROS (px4_sitl_coflyers), que faz a ponte UDP <-> MAVROS.
% Os argumentos x e y de cada no sao o PONTO DE NASCIMENTO do drone,
% somado a posicao local do MAVROS para reconstruir a coordenada de mundo.
% Precisam ser IDENTICOS aos do launch do Gazebo.
N = size(pos, 2);
IP_LOCAL  = '192.168.1.157';   % PC-B
IP_TARGET = '192.168.1.155';   % PC-A

f = fopen(arq, 'w');
fprintf(f, '<launch>\n');
fprintf(f, '    <!-- No ROS pareado: %s, semente %d.\n', ambiente, seed);
fprintf(f, '         Pontos de nascimento IDENTICOS aos de hifi_%s_seed%d.launch.\n', ...
    ambiente, seed);
fprintf(f, '         Gerado por build_hifi_launches.m ; nao editar a mao. -->\n');
fprintf(f, '    <arg name="ipLocal_"  value="%s"/>\n', IP_LOCAL);
fprintf(f, '    <arg name="ipTarget_" value="%s"/>\n\n', IP_TARGET);

for i = 1:N
    id = i - 1;
    fprintf(f, '    <!-- UAV%d : x = %.4f  y = %.4f -->\n', id, pos(1,i), pos(2,i));
    fprintf(f, '    <group ns="uav%d">\n', id);
    fprintf(f, '        <arg name="ID" value="%d"/>\n', id);
    fprintf(f, '        <include file="$(find px4_sitl_coflyers)/launch/px4_node_single.launch">\n');
    fprintf(f, '            <arg name="x" value="%.4f"/>\n', pos(1,i));
    fprintf(f, '            <arg name="y" value="%.4f"/>\n', pos(2,i));
    fprintf(f, '            <arg name="ID" value="$(arg ID)"/>\n');
    fprintf(f, '            <arg name="ipLocal"  default="$(arg ipLocal_)"/>\n');
    fprintf(f, '            <arg name="portLocal" default="%d"/>\n', 21000 + id*2 + 1);
    fprintf(f, '            <arg name="ipTarget" default="$(arg ipTarget_)"/>\n');
    fprintf(f, '            <arg name="portTarget" default="%d"/>\n', 21000 + id*2);
    fprintf(f, '            <arg name="portTargetBat" default="%d"/>\n', 20000 + id*2);
    fprintf(f, '        </include>\n');
    fprintf(f, '    </group>\n\n');
end

fprintf(f, '</launch>\n');
fclose(f);
end

%% ============================================================
function escreve_launch(arq, pos, mundo, ambiente, seed)
N = size(pos, 2);
f = fopen(arq, 'w');

fprintf(f, '<?xml version="1.0"?>\n');
% ATENCAO: "--" e proibido dentro de comentario XML (spec do XML).
% Usar apenas hifens simples aqui.
fprintf(f, '<!-- Alta fidelidade: %s, semente %d.\n', ambiente, seed);
fprintf(f, '     Posicoes iniciais PAREADAS com a execucao %d do Monte Carlo,\n', seed);
fprintf(f, '     permitindo medir a reality gap como diferenca pareada.\n');
fprintf(f, '     Gerado por build_hifi_launches.m ; nao editar a mao. -->\n');
fprintf(f, '<launch>\n');
fprintf(f, '    <arg name="est" default="ekf2"/>\n');
fprintf(f, '    <arg name="vehicle" default="iris"/>\n');
fprintf(f, '    <arg name="world" default="$(find mavlink_sitl_gazebo)/worlds/%s"/>\n', mundo);
fprintf(f, '    <arg name="gui" default="true"/>\n');
fprintf(f, '    <arg name="debug" default="false"/>\n');
fprintf(f, '    <arg name="verbose" default="false"/>\n');
fprintf(f, '    <arg name="paused" default="false"/>\n');
fprintf(f, '    <include file="$(find gazebo_ros)/launch/empty_world.launch">\n');
fprintf(f, '        <arg name="gui" value="$(arg gui)"/>\n');
fprintf(f, '        <arg name="world_name" value="$(arg world)"/>\n');
fprintf(f, '        <arg name="debug" value="$(arg debug)"/>\n');
fprintf(f, '        <arg name="verbose" value="$(arg verbose)"/>\n');
fprintf(f, '        <arg name="paused" value="$(arg paused)"/>\n');
fprintf(f, '    </include>\n\n');

for i = 1:N
    id = i - 1;
    fprintf(f, '    <!-- UAV%d : x = %.4f  y = %.4f -->\n', id, pos(1,i), pos(2,i));
    fprintf(f, '    <group ns="uav%d">\n', id);
    fprintf(f, '        <arg name="ID" value="%d"/>\n', id);
    fprintf(f, '        <arg name="fcu_url" default="udp://:%d@localhost:%d"/>\n', ...
        14540+id, 14580+id);
    fprintf(f, '        <include file="$(find px4)/launch/single_vehicle_spawn.launch">\n');
    fprintf(f, '            <arg name="x" value="%.4f"/>\n', pos(1,i));
    fprintf(f, '            <arg name="y" value="%.4f"/>\n', pos(2,i));
    fprintf(f, '            <arg name="z" value="0"/>\n');
    fprintf(f, '            <arg name="R" value="0"/>\n');
    fprintf(f, '            <arg name="P" value="0"/>\n');
    fprintf(f, '            <arg name="Y" value="0"/>\n');
    fprintf(f, '            <arg name="vehicle" value="$(arg vehicle)"/>\n');
    fprintf(f, '            <arg name="mavlink_udp_port" value="%d"/>\n', 14560+id);
    fprintf(f, '            <arg name="mavlink_tcp_port" value="%d"/>\n', 4560+id);
    fprintf(f, '            <arg name="ID" value="$(arg ID)"/>\n');
    fprintf(f, '            <arg name="gst_udp_port" value="%d"/>\n', 5600+id);
    fprintf(f, '            <arg name="video_uri" value="%d"/>\n', 5600+id);
    fprintf(f, '            <arg name="mavlink_cam_udp_port" value="%d"/>\n', 14530+id);
    fprintf(f, '        </include>\n');
    fprintf(f, '        <include file="$(find mavros)/launch/px4.launch">\n');
    fprintf(f, '            <arg name="fcu_url" value="$(arg fcu_url)"/>\n');
    fprintf(f, '            <arg name="gcs_url" value=""/>\n');
    fprintf(f, '            <arg name="tgt_system" value="%d"/>\n', 1+id);
    fprintf(f, '            <arg name="tgt_component" value="1"/>\n');
    fprintf(f, '        </include>\n');
    fprintf(f, '    </group>\n\n');
end

fprintf(f, '</launch>\n');
fclose(f);

% Validacao: "--" dentro de comentario invalida o XML e o roslaunch recusa
% o arquivo. Checa antes de devolver o controle.
c = fileread(arq);
com = regexp(c, '<!--(.*?)-->', 'tokens');
for k = 1:numel(com)
    if contains(com{k}{1}, '--')
        error(['XML invalido em %s: comentario contem "--". ', ...
               'Corrija o gerador.'], arq);
    end
end
if count(c, '<group') ~= count(c, '</group>')
    error('XML invalido em %s: tags <group> desbalanceadas.', arq);
end
end
