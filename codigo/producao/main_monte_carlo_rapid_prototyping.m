function main_monte_carlo_rapid_prototyping(algorithm_name, xml_original, obstaculos)
% MAIN_MONTE_CARLO_RAPID_PROTOTYPING
% Analise de Monte Carlo do Rapid Prototyping para um algoritmo de flocking.
%
% Roda N_RUNS simulacoes do CoFlyers, cada uma com uma configuracao INICIAL
% de drones gerada aleatoriamente mas REPRODUTIVEL (semente = numero da
% execucao). As sementes sao PAREADAS entre algoritmos: a execucao k de
% qualquer algoritmo parte da mesma configuracao inicial, isolando o efeito
% do algoritmo. Ao final, calcula media, desvio-padrao e intervalo de
% confianca de 95% (t de Student) para cada uma das 6 metricas.
%
% MECANISMO DE INJECAO: as posicoes sao escritas diretamente na tag
% <position__ .../> de uma COPIA de trabalho do XML (parameters_mc.xml).
% O ps_mofify NAO funciona para 'position__' porque esse campo so e criado
% tardiamente no read_parameter_xml (avaliacao diferida da expressao), e a
% verificacao de existencia do campo falha. O XML original nao e modificado.
%
% Fonte de variabilidade (Decisao A): posicao inicial do enxame (X e Y).
% Pareamento de sementes (Decisao B): mesmas sementes p/ os 4 algoritmos.
%
% USO (a partir de Prototype_Simulator, com addpath(genpath(pwd)) feito):
%   main_monte_carlo_rapid_prototyping('Couzin')
%   main_monte_carlo_rapid_prototyping('Reynolds')
%   main_monte_carlo_rapid_prototyping('OlfatiSaber')
%   main_monte_carlo_rapid_prototyping('Vasarhelyi')

clc; close all;

%% ====================== CONFIGURACAO ======================
if nargin < 1
    error('Informe o algoritmo. Ex: main_monte_carlo_rapid_prototyping(''Couzin'')');
end
if nargin < 2 || isempty(xml_original)
    xml_original = 'xml_config_files\parameters.xml';       % arena vazia
end
if nargin < 3
    obstaculos = [];   % 3xM: [x; y; raio] -- posicoes iniciais os evitam
end

N_RUNS   = 20;      % execucoes de Monte Carlo
D_MIN    = 5.0;     % distancia minima entre drones na config inicial (m)
Z_INIT   = 1.0;     % altitude inicial (m) - IGUAL ao valor nativo do XML
SEEDS    = 1:N_RUNS;% sementes fixadas A PRIORI (evita p-hacking) e pareadas
MARGEM   = 2.0;     % folga entre drone e superficie do obstaculo (m)

if isempty(obstaculos)
    rotulo = 'vazia';
else
    rotulo = 'obstaculos';
end
xml_work = sprintf('xml_config_files\\parameters_mc_%s.xml', rotulo);

% Ordem das metricas em evaluation_0_module_average:
% values = [F; phiCorr; phiVel; phiColl; phiWall; phiMND]
metric_names = {'F','phi_corr','phi_vel','phi_coll','phi_wall','phi_MND'};
N_METRICS = numel(metric_names);

fprintf('=== Monte Carlo Rapid Prototyping: %s ===\n', algorithm_name);
fprintf('Execucoes: %d | d_min: %.1f m | z_init: %.1f m | sementes: %d..%d\n', ...
    N_RUNS, D_MIN, Z_INIT, SEEDS(1), SEEDS(end));

%% ============ PREPARAR COPIA DE TRABALHO DO XML ============
copyfile(xml_original, xml_work);

content = fileread(xml_work);
content = regexprep(content, ...
    '<swarm_algorithm_type value="''[^'']+''"/>', ...
    ['<swarm_algorithm_type value="''', algorithm_name, '''"/>']);
content = strrep(content, '<activate_plot value="1"/>', '<activate_plot value="0"/>');
fid = fopen(xml_work, 'w'); fwrite(fid, content); fclose(fid);

% Le arena e numero de drones da copia (sem alterar nada)
[~, ~, ~, params, position0_default] = read_parameter_xml(xml_work);
N_DRONES = size(position0_default, 2);
x_range  = params.map.x_range(:)';
y_range  = params.map.y_range(:)';
fprintf('Algoritmo ativo confirmado: %s\n', params.swarm_algorithm_type);
fprintf('Arena X:[%.1f, %.1f] Y:[%.1f, %.1f] | drones: %d\n', ...
    x_range(1), x_range(2), y_range(1), y_range(2), N_DRONES);

%% ==================== LACO DE MONTE CARLO ====================
results        = zeros(N_RUNS, N_METRICS);
init_positions = cell(N_RUNS, 1);
run_times      = zeros(N_RUNS, 1);

t_start = tic;
for k = 1:N_RUNS
    seed = SEEDS(k);

    % Config inicial reproduzivel e sem colisao. Depende SO da semente,
    % nunca do algoritmo -> garante pareamento entre os 4 algoritmos.
    pos0 = generate_initial_positions(N_DRONES, x_range, y_range, ...
        Z_INIT, D_MIN, seed, obstaculos, MARGEM);
    init_positions{k} = pos0;

    % Escreve as posicoes na tag <position__> da copia de trabalho
    write_positions_to_xml(xml_work, pos0);

    % Fixa a semente global para a perturbacao nativa das velocidades
    % iniciais (rand em initialize_states) tambem ser reproduzivel.
    rng(seed, 'twister');

    t_run = tic;
    values = model_swarm([], [], [], 1, 0, xml_work, []);
    run_times(k) = toc(t_run);

    results(k, :) = values(:)';
    fprintf('  run %2d (seed %2d): F=%.4f corr=%.4f vel=%.4f coll=%.4g wall=%.4g MND=%.3f  [%.1fs]\n', ...
        k, seed, values(1), values(2), values(3), values(4), values(5), ...
        values(6), run_times(k));
end
elapsed = toc(t_start);
fprintf('Concluido em %.1f min (media %.1f s/execucao)\n', ...
    elapsed/60, mean(run_times));

%% ==================== ESTATISTICAS ====================
mean_vals = mean(results, 1);
std_vals  = std(results, 0, 1);          % desvio-padrao amostral (N-1)
sem_vals  = std_vals / sqrt(N_RUNS);     % erro-padrao da media
t_crit    = tinv(0.975, N_RUNS - 1);     % t critico bilateral, 95%
ci_half   = t_crit * sem_vals;

fprintf('\n===== RESUMO ESTATISTICO (%s, n=%d) =====\n', algorithm_name, N_RUNS);
fprintf('%-10s %12s %12s %26s\n', 'metrica', 'media', 'desv.pad.', 'IC 95%');
for m = 1:N_METRICS
    fprintf('%-10s %12.5f %12.5f   [%10.5f, %10.5f]\n', ...
        metric_names{m}, mean_vals(m), std_vals(m), ...
        mean_vals(m) - ci_half(m), mean_vals(m) + ci_half(m));
end

%% ==================== SALVAR ====================
out_dir = 'data_save/monte_carlo';
if ~exist(out_dir, 'dir'); mkdir(out_dir); end
stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
out_file = sprintf('%s/mc_%s_%s_%s.mat', out_dir, algorithm_name, rotulo, stamp);
save(out_file, 'algorithm_name', 'results', 'metric_names', 'SEEDS', ...
    'init_positions', 'mean_vals', 'std_vals', 'ci_half', 'D_MIN', ...
    'Z_INIT', 'x_range', 'y_range', 'N_DRONES', 'elapsed', 'run_times', ...
    'obstaculos', 'rotulo', 'xml_original');
fprintf('\nResultados salvos em: %s\n', out_file);

log_monte_carlo_csv(out_dir, [algorithm_name '_' rotulo], N_RUNS, D_MIN, ...
    mean_vals, std_vals, ci_half, metric_names, stamp);

fprintf('XML original preservado. Copia de trabalho: %s\n', xml_work);

end % ================= fim da funcao principal =================


%% ============================================================
function pos = generate_initial_positions(N, x_range, y_range, z, d_min, seed, obst, margem)
% Gera N posicoes (3xN) dentro da arena com distancia minima d_min entre
% pares, por amostragem com rejeicao. Determinada UNICAMENTE pela semente.
%
% Se 'obst' (3xM: [x; y; raio]) for fornecido, rejeita tambem posicoes a
% menos de (raio + margem) de qualquer obstaculo.
%
% NOTA METODOLOGICA: com obstaculos, as configuracoes geradas para uma dada
% semente DIFEREM das do ambiente vazio, pois algumas posicoes sao
% rejeitadas. O pareamento ENTRE ALGORITMOS se preserva (a geracao depende
% so da semente e da geometria, nunca do algoritmo); o que se perde e o
% pareamento entre ambientes -- aceitavel para um teste de generalizacao.
if nargin < 7; obst = []; end
if nargin < 8; margem = 2.0; end

rng(seed, 'twister');
pos = zeros(3, N);
pos(3, :) = z;

margin = d_min;
xlo = x_range(1) + margin; xhi = x_range(2) - margin;
ylo = y_range(1) + margin; yhi = y_range(2) - margin;

n_obst = size(obst, 2);
max_tries = 100000;
placed = 0; tries = 0;
while placed < N
    tries = tries + 1;
    if tries > max_tries
        error(['Nao foi possivel posicionar %d drones com d_min=%.1f m ', ...
               'apos %d tentativas. Reduza d_min, a margem ou N.'], ...
               N, d_min, max_tries);
    end
    cx = xlo + (xhi - xlo) * rand();
    cy = ylo + (yhi - ylo) * rand();

    ok = true;

    % rejeita se dentro (ou proximo demais) de algum obstaculo
    for k = 1:n_obst
        if hypot(cx - obst(1,k), cy - obst(2,k)) < obst(3,k) + margem
            ok = false; break;
        end
    end

    % rejeita se perto demais de outro drone
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
function write_positions_to_xml(xml_path, pos)
% Substitui a PRIMEIRA tag <position__ ... "/> do XML pela matriz numerica.
% A primeira ocorrencia e a tag ativa; a segunda esta dentro de <!-- -->.
content = fileread(xml_path);

idx = strfind(content, '<position__');
if isempty(idx)
    error('Tag <position__ nao encontrada em %s', xml_path);
end
s = idx(1);

rest  = content(s:end);
e_rel = strfind(rest, '"/>');
if isempty(e_rel)
    error('Nao foi possivel localizar o fim da tag <position__.');
end
e = s + e_rel(1) + 1;   % indice do ultimo caractere de '"/>'

new_tag = ['<position__ value="', matrix_to_matlab_string(pos), '"/>'];
content = [content(1:s-1), new_tag, content(e+1:end)];

fid = fopen(xml_path, 'w'); fwrite(fid, content); fclose(fid);
end

%% ============================================================
function s = matrix_to_matlab_string(M)
% Converte matriz numerica em string avaliavel: [a b c; d e f; g h i]
[nr, ~] = size(M);
rows = cell(1, nr);
for r = 1:nr
    vals = arrayfun(@(x) sprintf('%.6f', x), M(r, :), 'UniformOutput', false);
    rows{r} = strjoin(vals, ' ');
end
s = ['[', strjoin(rows, '; '), ']'];
end

%% ============================================================
function log_monte_carlo_csv(out_dir, alg, n_runs, d_min, mu, sd, ci, names, stamp)
% Anexa uma linha por metrica a um CSV mestre, para rastreabilidade total.
csv_path = fullfile(out_dir, 'monte_carlo_log.csv');
new_file = ~exist(csv_path, 'file');
fid = fopen(csv_path, 'a');
if new_file
    fprintf(fid, 'timestamp,algorithm,n_runs,d_min,metric,mean,std,ci95_low,ci95_high\n');
end
for m = 1:numel(names)
    fprintf(fid, '%s,%s,%d,%.2f,%s,%.6f,%.6f,%.6f,%.6f\n', ...
        stamp, alg, n_runs, d_min, names{m}, mu(m), sd(m), ...
        mu(m) - ci(m), mu(m) + ci(m));
end
fclose(fid);
end