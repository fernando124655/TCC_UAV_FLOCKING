function M = extrair_metricas_hifi(arquivo, mostrar)
%EXTRAIR_METRICAS_HIFI  Calcula as metricas de uma execucao de alta fidelidade.
%
% Usa as MESMAS formulas de evaluation_0_module_one.m, condicao necessaria
% para que a comparacao com o Rapid Prototyping (reality gap) seja valida.
% Formulas identicas, dados de origem diferentes -- e so isso que deve
% mudar entre as duas etapas.
%
% LAYOUT DOS DADOS (out.states.Data, 17 colunas por drone):
%   17*i+1  reservado          17*i+6..8   posicao x, y, z
%   17*i+2  contador/status    17*i+9..11  velocidade vx, vy, vz
%   17*i+3  timestamp Unix     17*i+12,13  aceleracao ou atitude
%   17*i+4  flag               17*i+14     tensao da bateria
%   17*i+5  modo               17*i+15..17 taxas angulares
%
% DETECCAO DA FASE Alg: por velocidade horizontal. Em Arming, Takeoff e
% Hover ela fica proxima de zero; em Alg oscila em torno de v_flock. Mais
% robusto que janelas de tempo fixas, que variam conforme a demora entre
% os cliques de fase.
%
% ENTRADAS:
%   arquivo : caminho do .mat gerado por salvar_hifi
%   mostrar : true para gerar os graficos (padrao false)
%
% SAIDA: struct com phi_corr, phi_vel, phi_coll, phi_wall, phi_MND, F e
%        metadados da execucao.
%
% USO:
%   M = extrair_metricas_hifi('...\hifi_vasarhelyi_vazia_seed1.mat', true)

if nargin < 2; mostrar = false; end

S = load(arquivo);
D = S.out.states.Data;
t = S.out.states.Time;
N = double(S.number);

% parametros de avaliacao (mesmos do Rapid Prototyping)
v_flock = 1.0;
r_coll  = 0.4;
a_tol   = 3e-5;
if isfield(S.params, 'evaluation_0')
    e = S.params.evaluation_0;
    if isfield(e,'v_flock'); v_flock = e.v_flock; end
    if isfield(e,'r_coll');  r_coll  = e.r_coll;  end
    if isfield(e,'a_tol');   a_tol   = e.a_tol;   end
end

%% ---- extrai posicao e velocidade ----
ix = 17*(0:N-1) + 6;
iy = 17*(0:N-1) + 7;
iz = 17*(0:N-1) + 8;
iu = 17*(0:N-1) + 9;
iv = 17*(0:N-1) + 10;

X = D(:, ix);  Y = D(:, iy);  Z = D(:, iz);
U = D(:, iu);  V = D(:, iv);

%% ---- detecta a fase Alg pelo MODO DE CONTROLE ----
% A coluna 2 de cada drone em out.commands e o control_mode:
%   1 = ocioso | 2 = takeoff | 3 = hover | 4 = land | 7 = velocidade horizontal
% O modo 7 e usado EXCLUSIVAMENTE durante a fase Alg, o que torna a
% deteccao exata.
%
% (A versao anterior usava velocidade horizontal acima de um limiar, o que
% falhava: algoritmos que freiam bastante -- como o Vasarhelyi perto de
% paredes -- caem abaixo do limiar e quebram o intervalo em pedacos.)
C = S.out.commands.Data;
tc = S.out.commands.Time;
modo = C(:, 2);                       % modo do drone 0; todos compartilham
em_alg = (modo == 7);

if ~any(em_alg)
    error('Fase Alg nao encontrada: modo 7 ausente em out.commands.');
end

% maior intervalo contiguo em modo 7
d = diff([0; em_alg(:); 0]);
ini = find(d == 1);  fim = find(d == -1) - 1;
[~, j] = max(fim - ini);
ic1 = ini(j);  ic2 = fim(j);

% mapeia da base de tempo dos comandos para a dos estados
[~, i1] = min(abs(t - tc(ic1)));
[~, i2] = min(abs(t - tc(ic2)));

% descarta 2 s de transicao em cada ponta (entrada e saida do modo)
dt = median(diff(t));
marg = round(2 / dt);
i1 = min(i1 + marg, i2);
i2 = max(i2 - marg, i1);
idx = i1:i2;

M = struct();
M.arquivo   = arquivo;
M.t_ini     = t(i1);
M.t_fim     = t(i2);
M.duracao   = t(i2) - t(i1);
M.n_amostras = numel(idx);
M.N         = N;

%% ---- metricas, instante a instante ----
n = numel(idx);
phiCorr = zeros(n,1);  phiVel = zeros(n,1);
phiColl = zeros(n,1);  phiMND = zeros(n,1);  phiWall = zeros(n,1);

tem_mapa = isfield(S,'map3d_struct') && isfield(S,'map3d_faces');

% Forma dos obstaculos, inferida do nome do STL registrado em model_stls.
% O map3d_struct guarda apenas a caixa envolvente, que e 6x6 tanto para o
% cubo de lado 6 quanto para o cilindro de diametro 6 -- por isso a
% geometria nao pode ser deduzida das dimensoes.
forma_obst = 'cubo';
if isfield(S, 'model_stls') && ~isempty(S.model_stls)
    nomes = lower(string(S.model_stls));
    if any(contains(nomes, 'cylinder'))
        forma_obst = 'cilindro';
    elseif any(contains(nomes, 'sphere'))
        forma_obst = 'esfera';
    end
end

for a = 1:n
    k = idx(a);
    pos = [X(k,:); Y(k,:); Z(k,:)];
    vel = [U(k,:); V(k,:)];

    % --- phi_coll e phi_MND: distancias entre pares ---
    dm = pdist(pos(1:2,:)');
    phiColl(a) = mean(dm < r_coll);
    phiMND(a)  = r_coll / min(dm);

    % --- phi_corr: parametro de ordem de Vicsek com correcao de tamanho ---
    vv = vel + rand(size(vel))*1e-20;
    s  = vecnorm(vv, 2, 1);
    vu = vv ./ s;
    phiCorr(a) = (norm(mean(vu,2))^2 * N - 1) / (N - 1);

    % --- phi_vel ---
    phiVel(a) = mean(s) / v_flock;

    % --- phi_wall: fora do mapa OU em colisao ---
    if tem_mapa
        fora = map_module_out_of_map(pos, S.map3d_struct);
        col  = map_module_collision_detection(pos, S.map3d_faces, r_coll/2);
        phiWall(a) = sum(fora | col) / N;
    end
end

M.phi_corr = mean(phiCorr);
M.phi_vel  = mean(phiVel);
M.phi_coll = mean(phiColl);
M.phi_wall = mean(phiWall);
M.phi_MND  = mean(phiMND);
M.dist_min = r_coll / M.phi_MND;   % media harmonica temporal, em metros

[~,~,~,~,M.F] = fitness_function_combine(v_flock, a_tol, 1.5/4*v_flock, 0, ...
    M.phi_vel, M.phi_coll, M.phi_wall, M.phi_corr);

M.series = struct('t', t(idx), 'phi_corr', phiCorr, 'phi_vel', phiVel, ...
    'phi_coll', phiColl, 'phi_wall', phiWall, 'phi_MND', phiMND);
M.traj = struct('X', X(idx,:), 'Y', Y(idx,:), 'Z', Z(idx,:));

%% ---- relatorio ----
[~, nm] = fileparts(arquivo);
fprintf('\n=== %s ===\n', nm);
fprintf('fase Alg: %.1f a %.1f s (%.1f s, %d amostras)\n', ...
    M.t_ini, M.t_fim, M.duracao, M.n_amostras);
if abs(M.duracao - 250) > 25
    fprintf('  *** ATENCAO: duracao esperada ~250 s. Verifique se a fase Alg\n');
    fprintf('      foi executada por completo nesta execucao. ***\n');
end
fprintf('  phi_corr = %.4f\n', M.phi_corr);
fprintf('  phi_vel  = %.4f\n', M.phi_vel);
fprintf('  phi_coll = %.4g  (%s)\n', M.phi_coll, ...
    ternario(M.phi_coll > 0, 'HOUVE VIOLACAO', 'sem violacao'));
fprintf('  phi_wall = %.4g  (%s)\n', M.phi_wall, ...
    ternario(M.phi_wall > 0, 'HOUVE VIOLACAO', 'sem violacao'));
fprintf('  dist. min entre drones = %.2f m\n', M.dist_min);
fprintf('  F = %.6f\n', M.F);
fprintf('  altitude: %.2f a %.2f m\n', min(M.traj.Z(:)), max(M.traj.Z(:)));
n_int = sum(S.map3d_struct(7,:) < 55 & S.map3d_struct(8,:) < 55 & S.map3d_struct(7,:) > 0.1 & S.map3d_struct(8,:) > 0.1);
if n_int > 0
    fprintf('  ambiente: %d obstaculo(s) do tipo %s\n', n_int, forma_obst);
else
    fprintf('  ambiente: arena vazia\n');
end
M.forma_obstaculos = forma_obst;
M.n_obstaculos     = n_int;

%% ---- graficos ----
if mostrar
    figure('Color','w','Position',[60 60 1100 460]);

    subplot(1,2,1); hold on;
    n_obst_plot = 0;
    if tem_mapa
        for o = 1:size(S.map3d_struct,2)
            cx = S.map3d_struct(1,o);  cy = S.map3d_struct(2,o);
            sx = S.map3d_struct(7,o);  sy = S.map3d_struct(8,o);
            % filtra paredes (uma dimensao ~60 m), piso e teto
            if sx < 55 && sy < 55 && sx > 0.1 && sy > 0.1
                pos_ret = [cx-sx/2, cy-sy/2, sx, sy];
                if strcmp(forma_obst, 'cubo')
                    curv = [0 0];
                else
                    curv = [1 1];   % Curvature [1 1] desenha elipse/circulo
                end
                rectangle('Position', pos_ret, 'Curvature', curv, ...
                    'FaceColor', [0.75 0.75 0.75], 'EdgeColor', [0.4 0.4 0.4]);
                n_obst_plot = n_obst_plot + 1;
            end
        end
    end
    cores = lines(N);
    for i = 1:N
        plot(M.traj.X(:,i), M.traj.Y(:,i), '-', 'Color', [cores(i,:) 0.65], 'LineWidth', 0.8);
        plot(M.traj.X(1,i), M.traj.Y(1,i), 'o', 'Color', cores(i,:), ...
            'MarkerFaceColor', cores(i,:), 'MarkerSize', 5);
        plot(M.traj.X(end,i), M.traj.Y(end,i), 's', 'Color', cores(i,:), 'MarkerSize', 7);
    end
    rectangle('Position', [-30 -30 60 60], 'EdgeColor', 'k', 'LineWidth', 1.3);
    axis equal; xlim([-33 33]); ylim([-33 33]); grid on; box on;
    xlabel('x (m)'); ylabel('y (m)');
    if n_obst_plot > 0
        title(sprintf('Trajetorias | %d %s(s) | o = inicio, [] = fim', ...
            n_obst_plot, forma_obst));
    else
        title('Trajetorias | arena vazia | o = inicio, [] = fim');
    end
    set(gca,'FontName','Times New Roman','FontSize',11);

    subplot(2,2,2);
    plot(M.series.t, M.series.phi_corr, 'LineWidth', 1.1); grid on;
    ylabel('\phi_{corr}'); ylim([0 1.05]);
    title(sprintf('media = %.4f', M.phi_corr));
    set(gca,'FontName','Times New Roman','FontSize',10);

    subplot(2,2,4);
    plot(M.series.t, M.series.phi_vel, 'LineWidth', 1.1); grid on;
    ylabel('\phi_{vel}'); xlabel('t (s)');
    title(sprintf('media = %.4f', M.phi_vel));
    set(gca,'FontName','Times New Roman','FontSize',10);

    sgtitle(strrep(nm, '_', '\_'));
end
end

function s = ternario(c, a, b)
if c; s = a; else; s = b; end
end