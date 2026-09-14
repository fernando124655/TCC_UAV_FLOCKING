function main_batch_production(algorithm_name, ambiente)
% MAIN_BATCH_PRODUCTION
% Batch processing de producao: varredura de robustez com repeticoes e
% reprodutibilidade completa.
%
% O QUE MEDE: como o desempenho degrada sob perturbacao do SISTEMA DE
% CONTROLE E SENSORIAMENTO -- tempo de amostragem do controle (Tc) e ruido
% de velocidade (eta). Testa a segunda metade da H1: algoritmos de maior
% complexidade paramétrica seriam menos robustos a perturbacoes.
%
% DESENHO:
%   - Grade 26x26 = 676 combinacoes de (eta, Tc), como no paper do CoFlyers.
%   - 3 repeticoes, cada uma com configuracao inicial distinta.
%   - Sementes das configuracoes: 201-203, DISJUNTAS das de treino do
%     auto-tuning (101-103) e das de teste do Monte Carlo (1-20).
%   - Dentro do parfor, rng() e fixado pelo indice da combinacao, o que
%     torna a realizacao do RUIDO reproduzivel independentemente de qual
%     worker executa cada iteracao.
%
% ENTRADAS:
%   algorithm_name : 'Couzin' | 'Reynolds' | 'OlfatiSaber' | 'Vasarhelyi'
%   ambiente       : 'vazia' (padrao) ou 'cubos'
%
% CUSTO: ~7 h por algoritmo na arena vazia, ~10 h com cubos.
%
% USO:
%   main_batch_production('Couzin', 'vazia')
%   main_batch_production('Couzin', 'cubos')

clc; close all;

if nargin < 1
    error('Informe o algoritmo. Ex: main_batch_production(''Couzin'')');
end
if nargin < 2 || isempty(ambiente); ambiente = 'vazia'; end

%% ====================== CONFIGURACAO ======================
N_REP     = 3;
CFG_SEEDS = [201 202 203];   % disjuntas de treino (101-103) e teste (1-20)
D_MIN     = 5.0;
Z_INIT    = 1.0;
N_WORKERS = 6;
RNG_BASE  = 50000;

% Grade de varredura (mesma do paper do CoFlyers)
ETA_RANGE = [0.0,  0.5];     % ruido de velocidade (m/s)
TC_RANGE  = [0.01, 1.01];    % tempo de amostragem do controle (s)
N_GRID    = [26, 26];

switch lower(ambiente)
    case 'vazia'
        xml_src = 'xml_config_files\parameters.xml';
        obst    = [];
    case 'cubos'
        xml_src = 'xml_config_files\parameters_obst_cubo.xml';
        obst    = [-12 -12  12  12;
                   -12  12 -12  12;
                   4.243 4.243 4.243 4.243];   % raio circunscrito do cubo
    otherwise
        error('ambiente deve ser ''vazia'' ou ''cubos''.');
end
MARGEM = 2.0;

metric_names = {'F','phi_corr','phi_vel','phi_coll','phi_wall','phi_MND'};
N_METRICS = numel(metric_names);

fprintf('=== Batch Processing de Producao ===\n');
fprintf('Algoritmo: %s | Ambiente: %s\n', algorithm_name, ambiente);
fprintf('Grade: %dx%d = %d combinacoes | Repeticoes: %d\n', ...
    N_GRID(1), N_GRID(2), prod(N_GRID), N_REP);
fprintf('eta: [%.2f, %.2f] m/s | Tc: [%.2f, %.2f] s\n', ...
    ETA_RANGE(1), ETA_RANGE(2), TC_RANGE(1), TC_RANGE(2));
fprintf('Sementes das configuracoes iniciais: %s\n', mat2str(CFG_SEEDS));
fprintf('Total de simulacoes: %d\n', prod(N_GRID)*N_REP);

%% ============ XMLs DE TRABALHO (um por repeticao) ============
[~, ~, ~, params, pos0_default] = read_parameter_xml(xml_src);
N_DRONES = size(pos0_default, 2);
x_range  = params.map.x_range(:)';
y_range  = params.map.y_range(:)';

xml_list = cell(1, N_REP);
init_positions = cell(1, N_REP);
for r = 1:N_REP
    xml_r = sprintf('xml_config_files\\parameters_bp_%s_%s_r%d.xml', ...
        algorithm_name, ambiente, r);
    copyfile(xml_src, xml_r);

    c = fileread(xml_r);
    c = regexprep(c, '<swarm_algorithm_type\s*value\s*=\s*"''[^'']+''"\s*/>', ...
        ['<swarm_algorithm_type value="''', algorithm_name, '''"/>']);
    c = regexprep(c, '<activate_plot\s*value\s*=\s*"1"\s*/>', ...
        '<activate_plot value="0"/>');
    fid = fopen(xml_r, 'w'); fwrite(fid, c); fclose(fid);

    pos = gera_posicoes(N_DRONES, x_range, y_range, Z_INIT, D_MIN, ...
        CFG_SEEDS(r), obst, MARGEM);
    escreve_posicoes(xml_r, pos);
    init_positions{r} = pos;

    % verificacao
    [~, ~, ~, p_chk, pos_chk] = read_parameter_xml(xml_r);
    if max(abs(pos(:) - pos_chk(:))) > 1e-5
        error('Falha ao escrever posicoes em %s.', xml_r);
    end
    if ~strcmp(p_chk.swarm_algorithm_type, algorithm_name)
        error('Algoritmo em %s e "%s", esperado "%s".', ...
            xml_r, p_chk.swarm_algorithm_type, algorithm_name);
    end
    xml_list{r} = xml_r;
    fprintf('  rep %d (seed %d): %s [ok]\n', r, CFG_SEEDS(r), xml_r);
end

%% ============ BLINDAGEM CONTRA CORRIDA DE I/O ============
prepare_parallel_safe(xml_list);

% O CoFlyers exige pool baseado em PROCESSOS: get_multi_core_value usa
% getCurrentTask, que nao existe em pool 'Threads'. Na R2026a o perfil
% padrao pode ser 'Threads', entao o perfil e forcado aqui.
pool = gcp('nocreate');
if ~isempty(pool) && ~isa(pool, 'parallel.ProcessPool')
    fprintf('Pool atual e %s; encerrando para abrir um de processos.\n', ...
        class(pool));
    delete(pool);
    pool = [];
end
if isempty(pool)
    parpool('Processes', min(feature('numcores'), N_WORKERS));
end

%% ============ COMBINACOES DA GRADE ============
eta_vals = linspace(ETA_RANGE(1), ETA_RANGE(2), N_GRID(1));
tc_vals  = linspace(TC_RANGE(1),  TC_RANGE(2),  N_GRID(2));
[ETA, TC] = ndgrid(eta_vals, tc_vals);
n_combo = numel(ETA);

param_name = ["CoFlyers.noise.velocity_noise", ...
              "CoFlyers.sample_time_control_upper"];

% Struct array construido INLINE (workers paralelos nao acessam
% funcoes locais definidas apos o corpo principal de forma confiavel)
combos = repmat(struct('param_name_s', param_name, 'param_value_s', ...
    {[string(0), string(0)]}), 1, n_combo);
for c = 1:n_combo
    combos(c).param_value_s = [string(ETA(c)), string(TC(c))];
end

%% ==================== EXECUCAO ====================
out_dir = 'data_save/batch_production';
if ~exist(out_dir, 'dir'); mkdir(out_dir); end
stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));

results = nan(n_combo, N_METRICS, N_REP);
t_total = tic;

for r = 1:N_REP
    fprintf('\n--- Repeticao %d/%d (config seed %d) ---\n', r, N_REP, CFG_SEEDS(r));
    xml_r = xml_list{r};
    res_r = nan(n_combo, N_METRICS);
    base  = RNG_BASE + 10000*r;

    t_rep = tic;
    parfor c = 1:n_combo
        % Semente determinada pelo indice da combinacao: reproduzivel
        % independentemente de qual worker executa esta iteracao.
        rng(base + c, 'twister');
        v = model_swarm([], [], combos(c), 1, 2, xml_r, []);
        res_r(c, :) = v(:)';
    end
    results(:, :, r) = res_r;

    dt = toc(t_rep);
    fprintf('Repeticao %d concluida em %.1f h (%.1f s/simulacao)\n', ...
        r, dt/3600, dt/n_combo);

    % Salvamento incremental
    save(sprintf('%s/bp_%s_%s_%s.mat', out_dir, algorithm_name, ambiente, stamp), ...
        'algorithm_name','ambiente','results','metric_names','eta_vals', ...
        'tc_vals','ETA','TC','CFG_SEEDS','N_REP','init_positions','r');
end

elapsed = toc(t_total);
fprintf('\nConcluido em %.1f h\n', elapsed/3600);

%% ==================== AGREGACAO ====================
res_mean = mean(results, 3, 'omitnan');
res_std  = std(results, 0, 3, 'omitnan');

fprintf('\n===== RESUMO (%s, %s) =====\n', algorithm_name, ambiente);
fprintf('%-10s %12s %12s %12s\n', 'metrica','min','max','amplitude');
for m = 2:N_METRICS
    v = res_mean(:, m);
    fprintf('%-10s %12.5f %12.5f %12.5f\n', ...
        metric_names{m}, min(v), max(v), max(v)-min(v));
end

fprintf('\nVariabilidade entre repeticoes (desv.pad. medio):\n');
for m = 2:N_METRICS
    fprintf('  %-10s %.5f\n', metric_names{m}, mean(res_std(:, m), 'omitnan'));
end

%% ==================== SALVAR ====================
save(sprintf('%s/bp_%s_%s_%s.mat', out_dir, algorithm_name, ambiente, stamp), ...
    'algorithm_name','ambiente','results','res_mean','res_std', ...
    'metric_names','eta_vals','tc_vals','ETA','TC','CFG_SEEDS','N_REP', ...
    'init_positions','elapsed','xml_src');
fprintf('\nSalvo em: %s/bp_%s_%s_%s.mat\n', out_dir, algorithm_name, ambiente, stamp);

%% ==================== SUPERFICIES ====================
for m = [2 3]
    Z  = reshape(res_mean(:, m), N_GRID);
    ZS = reshape(res_std(:, m),  N_GRID);

    figure('Color','w','Position',[80 80 900 380]);

    subplot(1,2,1);
    surf(TC, ETA, Z, 'EdgeAlpha', 0.25);
    xlabel('T_c (s)'); ylabel('\eta (m/s)');
    zlabel(strrep(metric_names{m},'_','\_'));
    title(sprintf('%s - %s (media de %d rep.)', ...
        algorithm_name, strrep(metric_names{m},'_','\_'), N_REP));
    colorbar; view([-40 30]);
    set(gca,'FontName','Times New Roman','FontSize', 11);

    subplot(1,2,2);
    surf(TC, ETA, ZS, 'EdgeAlpha', 0.25);
    xlabel('T_c (s)'); ylabel('\eta (m/s)');
    zlabel('desv. padrao');
    title('Variabilidade entre repeticoes');
    colorbar; view([-40 30]);
    set(gca,'FontName','Times New Roman','FontSize', 11);

    saveas(gcf, sprintf('%s/bp_%s_%s_%s.png', ...
        out_dir, algorithm_name, ambiente, metric_names{m}));
end

fprintf('Figuras salvas em %s/\n', out_dir);
end


%% ============================================================
function pos = gera_posicoes(N, x_range, y_range, z, d_min, seed, obst, margem)
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
        error('Nao foi possivel posicionar %d drones com d_min=%.1f m.', N, d_min);
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
function escreve_posicoes(xml_path, pos)
content = fileread(xml_path);
idx = strfind(content, '<position__');
if isempty(idx); error('Tag <position__ nao encontrada em %s', xml_path); end
s = idx(1);
rest  = content(s:end);
e_rel = strfind(rest, '"/>');
if isempty(e_rel); error('Fim da tag <position__ nao encontrado.'); end
e = s + e_rel(1) + 1;

rows = cell(1, 3);
for r = 1:3
    rows{r} = strjoin(arrayfun(@(x) sprintf('%.6f', x), pos(r,:), ...
        'UniformOutput', false), ' ');
end
new_tag = ['<position__ value="[', strjoin(rows, '; '), ']"/>'];
content = [content(1:s-1), new_tag, content(e+1:end)];
fid = fopen(xml_path, 'w'); fwrite(fid, content); fclose(fid);
end