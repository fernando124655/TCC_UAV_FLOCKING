function main_couzin_ra20(etapa, opcao)
%MAIN_COUZIN_RA20  Couzin com o alcance de percepcao limitado a 20 m (recomendacao 4).
%
%   main_couzin_ra20                 % tudo: AG (5 sementes), Monte Carlo e comparacao
%   main_couzin_ra20('ag')           % so a calibracao (retoma se for interrompida)
%   main_couzin_ra20('mc')           % so o Monte Carlo, com o melhor vetor do AG
%   main_couzin_ra20('compara')      % so a comparacao com o Couzin original
%   main_couzin_ra20('ag', 'sem_conferencia')   % pula a conferencia inicial
%
% O QUE MUDA EM RELACAO A CALIBRACAO ORIGINAL
%   Uma coisa so: r_o e r_a ficam limitados a 20 m, o alcance fixo do
%   Reynolds e do Vasarhelyi (o r calibrado do Olfati-Saber ja e 16,3 m).
%   O AG busca no mesmo espaco (r_r, k_o, k_a, r_shill, w_shill), com os
%   mesmos limites, o mesmo orcamento (populacao 30, 30 geracoes, 872
%   avaliacoes), as mesmas sementes do AG (1 a 5) e as mesmas configuracoes
%   de treino (sementes 101 a 103); so a conversao para o CoFlyers passa a
%   ser
%       r_o = min(r_r (1 + k_o), 20)      r_a = min(r_r (1 + k_o + k_a), 20)
%   O modulo do Couzin nao muda.
%
% CONFERENCIAS
%   - Antes do AG: o melhor vetor da calibracao original, avaliado nas
%     configuracoes de treino refeitas aqui, tem de dar o mesmo F*.
%   - Antes do Monte Carlo: as posicoes iniciais tem de ser as do Monte
%     Carlo original, e a semente 1 com os parametros originais tem de
%     reproduzir o resultado original, em cada arena.
%   Se alguma falhar, o script para.
%
% CUSTO
%   AG: cerca de 7 a 8,5 h por semente, 35 a 42 h no total (como na
%   calibracao original). Monte Carlo: 63 execucoes, cerca de 40 min.
%
% SAIDA (data_save\couzin_ra20; nada e gravado em data_save\monte_carlo,
% para nao mudar o que analyze_monte_carlo le)
%   at_Couzin_ra20_<carimbo>.mat, resume_Couzin_ra20.mat, prod_*_w<k>.txt
%   mc_Couzin_ra20_<arena>_<carimbo>.mat
%   comparacao_<carimbo>.csv, log_<etapa>_<carimbo>.txt
%
% Escrito para o TCC de Fernando Souza Rodrigues (29/10/2026).

if nargin < 1 || isempty(etapa), etapa = 'tudo'; end
if nargin < 2, opcao = ''; end
confere = ~strcmpi(opcao, 'sem_conferencia');

if exist('model_swarm', 'file') ~= 2 || exist('fitness_paired_configs', 'file') ~= 2 || ...
        exist('prepare_parallel_safe', 'file') ~= 2
    error(['Rode na pasta Prototype_Simulator, com os scripts de producao no caminho ' ...
        '(model_swarm, fitness_paired_configs e prepare_parallel_safe).']);
end
P = config();
if ~exist(P.pasta, 'dir'), mkdir(P.pasta); end
confere_avaliador();

switch lower(etapa)
    case 'ag'
        roda_ag(P, confere);
    case 'mc'
        roda_mc(P, confere);
    case 'compara'
        compara(P);
    case 'tudo'
        roda_ag(P, confere);
        roda_mc(P, confere);
        compara(P);
    otherwise
        error('Etapa desconhecida: %s (use ag, mc, compara ou tudo).', etapa);
end
end


% =====================================================================
function P = config()
P.R_MAX = 20;
P.pasta = fullfile('data_save', 'couzin_ra20');
P.ga_seeds = 1:5;
P.POP_SIZE = 30; P.N_GEN = 30;
P.CFG_SEEDS = [101 102 103]; P.D_MIN = 5.0; P.Z_INIT = 1.0;
P.N_WORKERS = 6; P.RNG_BASE = 1000;
P.param_names = ["CoFlyers.swarm.Couzin.r_r", "CoFlyers.swarm.Couzin.r_o", ...
    "CoFlyers.swarm.Couzin.r_a", "CoFlyers.swarm.Couzin.r_shill", "CoFlyers.swarm.Couzin.w_shill"];
P.tags = {'r_r', 'r_o', 'r_a', 'r_shill', 'w_shill'};
P.search_names = {'r_r', 'k_o', 'k_a', 'r_shill', 'w_shill'};
P.lb = [0.5, 0.0, 0.0, 1.0, 0.1];
P.ub = [3.5, 15.0, 15.0, 15.0, 8.0];
R = P.R_MAX;
P.transform = @(x) [x(1), min(x(1)*(1 + x(2)), R), min(x(1)*(1 + x(2) + x(3)), R), x(4), x(5)];
P.transform_original = @(x) [x(1), x(1)*(1 + x(2)), x(1)*(1 + x(2) + x(3)), x(4), x(5)];
P.xml_vazia = fullfile('xml_config_files', 'parameters_vazia_BACKUP.xml');
% arena, rotulo do Monte Carlo original (como no analyze_monte_carlo), XML
P.arenas = {'vazia', 'vazia', fullfile('xml_config_files', 'parameters_vazia_BACKUP.xml');
    'cubos', 'obstaculos', fullfile('xml_config_files', 'parameters_obst_cubo.xml');
    'cilindros', 'cilindros', fullfile('xml_config_files', 'parameters_obstacles_prod.xml')};
end


function inicia_log(P, nome)
carimbo = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
diary(fullfile(P.pasta, sprintf('log_%s_%s.txt', nome, carimbo)));
fprintf('=== Couzin com r_o e r_a <= %g m | %s | %s ===\n', P.R_MAX, nome, datestr(now));
end


function confere_avaliador()
% Mais de uma copia do avaliador no caminho: tem de ser identicas.
for nome = {'evaluation_0_module_one', 'evaluation_0_module_average'}
    w = cellstr(which(nome{1}, '-all'));
    if numel(w) > 1
        txt = cellfun(@fileread, w, 'UniformOutput', false);
        if ~all(strcmp(txt, txt{1}))
            error(['Ha copias diferentes de %s no caminho do MATLAB:\n  %s\n' ...
                'Tire as pastas extras do caminho (ex.: rmpath(genpath(''data_save''))).'], ...
                nome{1}, strjoin(w, '\n  '));
        end
        warning('Ha %d copias identicas de %s no caminho; o resultado nao muda.', numel(w), nome{1});
    end
end
end


% =====================================================================
function roda_ag(P, confere)
inicia_log(P, 'ag');
desliga = onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('Espaco de busca (igual ao original):\n');
for k = 1:numel(P.lb)
    fprintf('  %-8s [%6.2f, %6.2f]\n', P.search_names{k}, P.lb(k), P.ub(k));
end
fprintf('Conversao: r_o = min(r_r(1+k_o), %g); r_a = min(r_r(1+k_o+k_a), %g)\n', P.R_MAX, P.R_MAX);

xml_list = prepara_xmls_treino(P);

if confere
    [x0, f0, arq0] = vetor_original();
    if isempty(x0)
        error(['Nao achei o at_Couzin_*.mat da calibracao original em ' ...
            'data_save\\auto_tuning_production. Para seguir sem a conferencia: ' ...
            'main_couzin_ra20(''ag'', ''sem_conferencia'')']);
    end
    fprintf('\nConferencia: melhor vetor original (%s) nas configuracoes de treino refeitas...\n', arq0);
    f_chk = fitness_paired_configs(P.transform_original(x0), P.param_names, xml_list, P.RNG_BASE, '');
    fprintf('  F* original = %.9f | refeito = %.9f\n', f0, f_chk);
    if abs(f_chk - f0) > 1e-9
        error(['As configuracoes de treino refeitas nao reproduzem o F* original. ' ...
            'Confira o parameters_vazia_BACKUP.xml.']);
    end
    fprintf('  Reproduz; seguindo.\n');
end

prepare_parallel_safe(xml_list);
pool = gcp('nocreate');
if isempty(pool)
    parpool('Processes', min(feature('numcores'), P.N_WORKERS));
end

n_seeds = numel(P.ga_seeds); n_params = numel(P.lb);
X_opt = nan(n_seeds, n_params); F_opt = nan(n_seeds, 1);
t_seed = nan(n_seeds, 1); seed_done = false(1, n_seeds);
resume_file = fullfile(P.pasta, 'resume_Couzin_ra20.mat');
if exist(resume_file, 'file')
    Rr = load(resume_file);
    if isequal(Rr.ga_seeds, P.ga_seeds) && size(Rr.X_opt, 2) == n_params
        X_opt = Rr.X_opt; F_opt = Rr.F_opt; t_seed = Rr.t_seed; seed_done = Rr.seed_done;
        fprintf('Retomando: %d de %d sementes concluidas.\n', sum(seed_done), n_seeds);
    end
end
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
ga_seeds = P.ga_seeds; R_MAX = P.R_MAX; lb = P.lb; ub = P.ub; %#ok<NASGU>
param_names = P.param_names; search_names = P.search_names; %#ok<NASGU>
CFG_SEEDS = P.CFG_SEEDS; POP_SIZE = P.POP_SIZE; N_GEN = P.N_GEN; %#ok<NASGU>

for s = 1:n_seeds
    if seed_done(s)
        fprintf('\nSemente %d ja concluida; pulando.\n', P.ga_seeds(s));
        continue
    end
    seed = P.ga_seeds(s);
    fprintf('\n--- Semente do AG %d (%d de %d) | %s ---\n', seed, s, n_seeds, datestr(now));
    txt_base = sprintf('%s/prod_Couzin_ra20_seed%d_%s', P.pasta, seed, stamp);
    rng(seed, 'twister');
    tr = P.transform; pn = P.param_names; xl = xml_list; rb = P.RNG_BASE;
    fun = @(x) fitness_paired_configs(tr(x), pn, xl, rb, txt_base);
    options = optimoptions('ga', 'Display', 'iter', 'UseParallel', true, ...
        'PopulationSize', P.POP_SIZE, 'MaxGenerations', P.N_GEN, 'FunctionTolerance', 1e-4);
    tt = tic;
    [x_best, f_best] = ga(fun, n_params, [], [], [], [], P.lb, P.ub, [], options);
    t_seed(s) = toc(tt);
    X_opt(s, :) = x_best(:)'; F_opt(s) = f_best; seed_done(s) = true;
    fprintf('Semente %d: F = %.6f (%.1f min)\n  busca: %s\n  CoFlyers: %s\n', seed, f_best, ...
        t_seed(s)/60, mat2str(x_best, 6), mat2str(P.transform(x_best), 6));
    save(resume_file, 'ga_seeds', 'X_opt', 'F_opt', 't_seed', 'seed_done', 'R_MAX');
    save(fullfile(P.pasta, sprintf('at_Couzin_ra20_%s.mat', stamp)), 'ga_seeds', 'X_opt', ...
        'F_opt', 't_seed', 'seed_done', 'R_MAX', 'lb', 'ub', 'param_names', 'search_names', ...
        'CFG_SEEDS', 'POP_SIZE', 'N_GEN', 's');
end

[f_best_all, idx_best] = min(F_opt, [], 'omitnan');
x_final_search = X_opt(idx_best, :);
x_final = P.transform(x_final_search);
fprintf('\nF por semente: %s\nMELHOR: semente %d, F = %.6f\n', mat2str(F_opt', 5), ...
    P.ga_seeds(idx_best), f_best_all);
fprintf('%-8s %10s %10s %10s\n', 'param', 'melhor', 'media', 'pos.faixa');
for k = 1:n_params
    pos = 100 * (x_final_search(k) - P.lb(k)) / (P.ub(k) - P.lb(k));
    fprintf('%-8s %10.4f %10.4f %9.0f%%\n', P.search_names{k}, x_final_search(k), ...
        mean(X_opt(:, k), 'omitnan'), pos);
end
fprintf('No CoFlyers: r_r = %.4f, r_o = %.4f, r_a = %.4f, r_shill = %.4f, w_shill = %.4f\n', x_final);
save(fullfile(P.pasta, sprintf('at_Couzin_ra20_%s.mat', stamp)), 'ga_seeds', 'X_opt', 'F_opt', ...
    't_seed', 'seed_done', 'R_MAX', 'lb', 'ub', 'param_names', 'search_names', 'CFG_SEEDS', ...
    'POP_SIZE', 'N_GEN', 'x_final_search', 'x_final', 'f_best_all', 'idx_best', 'xml_list');
fprintf('Salvo em %s\n', fullfile(P.pasta, sprintf('at_Couzin_ra20_%s.mat', stamp)));
end


function xml_list = prepara_xmls_treino(P)
% Mesmas configuracoes de treino da calibracao original (prepare_paired_xmls),
% a partir da arena vazia.
[~, ~, ~, params, pos_default] = read_parameter_xml(P.xml_vazia);
N = size(pos_default, 2);
xr = params.map.x_range(:)'; yr = params.map.y_range(:)';
xml_list = cell(1, numel(P.CFG_SEEDS));
for i = 1:numel(P.CFG_SEEDS)
    xml_path = sprintf('xml_config_files\\parameters_at_CouzinRa20_cfg%d.xml', i);
    copyfile(P.xml_vazia, xml_path, 'f');
    c = fileread(xml_path);
    c = regexprep(c, '<swarm_algorithm_type\s*value\s*=\s*"''[^'']+''"\s*/>', ...
        '<swarm_algorithm_type value="''Couzin''"/>');
    c = regexprep(c, '<activate_plot\s*value\s*=\s*"1"\s*/>', '<activate_plot value="0"/>');
    grava(xml_path, c);
    pos = posicoes_treino(N, xr, yr, P.Z_INIT, P.D_MIN, P.CFG_SEEDS(i));
    escreve_posicoes(xml_path, pos);
    [~, ~, ~, p_chk, pos_chk] = read_parameter_xml(xml_path);
    if max(abs(pos(:) - pos_chk(:))) > 1e-5 || ~strcmp(p_chk.swarm_algorithm_type, 'Couzin')
        error('Falha ao preparar %s.', xml_path);
    end
    xml_list{i} = xml_path;
    fprintf('  treino %d (semente %d): %s\n', i, P.CFG_SEEDS(i), xml_path);
end
end


function [x0, f0, arq] = vetor_original()
% Melhor vetor (espaco de busca) e F* da calibracao original do Couzin.
x0 = []; f0 = NaN; arq = '';
d = dir(fullfile('data_save', 'auto_tuning_production', 'at_Couzin_*.mat'));
[~, ordem] = sort([d.datenum], 'descend');
for i = ordem
    w = whos('-file', fullfile(d(i).folder, d(i).name));
    if all(ismember({'x_final_search', 'f_best_all'}, {w.name}))
        S = load(fullfile(d(i).folder, d(i).name), 'x_final_search', 'f_best_all');
        x0 = S.x_final_search; f0 = S.f_best_all; arq = d(i).name;
        return
    end
end
end


% =====================================================================
function roda_mc(P, confere)
inicia_log(P, 'mc');
desliga = onCleanup(@() diary('off')); %#ok<NASGU>
d = dir(fullfile(P.pasta, 'at_Couzin_ra20_*.mat'));
x_final = [];
[~, ordem] = sort([d.datenum], 'descend');
for i = ordem
    w = whos('-file', fullfile(d(i).folder, d(i).name));
    if ismember('x_final', {w.name})
        S = load(fullfile(d(i).folder, d(i).name), 'x_final', 'f_best_all');
        x_final = S.x_final; arq_ag = d(i).name;
        break
    end
end
if isempty(x_final)
    error('Nenhum at_Couzin_ra20_*.mat com x_final em %s: rode a etapa ag primeiro.', P.pasta);
end
fprintf('Parametros novos (%s): r_r %.4f, r_o %.4f, r_a %.4f, r_shill %.4f, w_shill %.4f\n', ...
    arq_ag, x_final);

for a = 1:size(P.arenas, 1)
    arena = P.arenas{a, 1}; rot = P.arenas{a, 2}; xml_arena = P.arenas{a, 3};
    fprintf('\n================ %s ================\n', arena);
    O = mc_original(rot);
    fprintf('Monte Carlo original: %s (%d execucoes)\n', O.arquivo, size(O.results, 1));
    % XML da arena: o do Monte Carlo original, se existir e nao for o
    % parameters.xml (que hoje tem cilindros); senao, o da tabela.
    if ~isempty(O.xml_original) && exist(O.xml_original, 'file') == 2 && ...
            isempty(strfind(O.xml_original, 'parameters.xml'))
        xml_arena = O.xml_original;
    end
    fprintf('XML da arena: %s\n', xml_arena);
    xml_orig = fullfile('xml_config_files', sprintf('parameters_mc_orig_%s.xml', arena));
    xml_novo = fullfile('xml_config_files', sprintf('parameters_mc_ra20_%s.xml', arena));
    prepara_xml_mc(xml_arena, xml_orig);
    prepara_xml_mc(xml_arena, xml_novo);
    define_bloco(xml_novo, 'Couzin', P.tags, x_final);
    [~, ~, ~, params, pos_default] = read_parameter_xml(xml_novo);
    N = size(pos_default, 2);
    xr = params.map.x_range(:)'; yr = params.map.y_range(:)';

    if confere
        pos1 = posicoes_mc(N, xr, yr, O.Z_INIT, O.D_MIN, O.SEEDS(1), O.obstaculos, 2.0);
        if max(abs(pos1(:) - O.init_positions{1}(:))) > 1e-9
            error('As posicoes iniciais da semente %d nao sao as do Monte Carlo original.', O.SEEDS(1));
        end
        escreve_posicoes(xml_orig, pos1);
        rng(O.SEEDS(1), 'twister');
        v = model_swarm([], [], [], 1, 0, xml_orig, []);
        dif = max(abs(v(:)' - O.results(1, :)));
        fprintf('Conferencia (semente %d, parametros originais): diferenca maxima %.2e\n', O.SEEDS(1), dif);
        if dif > 1e-9
            error('O Monte Carlo original nao foi reproduzido em %s; confira o XML %s.', arena, xml_arena);
        end
    end

    n = numel(O.SEEDS);
    results = nan(n, 6); init_positions = cell(n, 1); run_times = nan(n, 1);
    t0 = tic;
    for k = 1:n
        seed = O.SEEDS(k);
        pos0 = posicoes_mc(N, xr, yr, O.Z_INIT, O.D_MIN, seed, O.obstaculos, 2.0);
        if max(abs(pos0(:) - O.init_positions{k}(:))) > 1e-9
            error('Semente %d: posicoes diferentes das do Monte Carlo original.', seed);
        end
        init_positions{k} = pos0;
        escreve_posicoes(xml_novo, pos0);
        rng(seed, 'twister');
        tr = tic;
        v = model_swarm([], [], [], 1, 0, xml_novo, []);
        run_times(k) = toc(tr);
        results(k, :) = v(:)';
        fprintf('  semente %2d: F %.4f  corr %.4f  vel %.4f  coll %.3g  wall %.3g  MND %.3f  [%.0f s]\n', ...
            seed, v(1), v(2), v(3), v(4), v(5), v(6), run_times(k));
    end
    elapsed = toc(t0);
    SEEDS = O.SEEDS; arquivo_original = O.arquivo; results_original = O.results; %#ok<NASGU>
    obstaculos = O.obstaculos; metric_names = {'F', 'phi_corr', 'phi_vel', 'phi_coll', 'phi_wall', 'phi_MND'}; %#ok<NASGU>
    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    arq = fullfile(P.pasta, sprintf('mc_Couzin_ra20_%s_%s.mat', arena, stamp));
    save(arq, 'arena', 'x_final', 'results', 'results_original', 'SEEDS', 'init_positions', ...
        'run_times', 'elapsed', 'obstaculos', 'metric_names', 'arquivo_original', 'xml_arena', 'arq_ag');
    fprintf('Salvo em %s (%.1f min)\n', arq, elapsed/60);
end
end


function O = mc_original(rot)
% Monte Carlo original mais recente do Couzin, como no analyze_monte_carlo.
d = dir(fullfile('data_save', 'monte_carlo', sprintf('mc_Couzin_%s_*.mat', rot)));
if isempty(d)
    error('Nenhum mc_Couzin_%s_*.mat em data_save\\monte_carlo.', rot);
end
[~, i] = max([d.datenum]);
S = load(fullfile(d(i).folder, d(i).name));
O.arquivo = d(i).name;
O.results = S.results; O.SEEDS = S.SEEDS; O.init_positions = S.init_positions;
O.obstaculos = []; if isfield(S, 'obstaculos'), O.obstaculos = S.obstaculos; end
O.D_MIN = 5.0; if isfield(S, 'D_MIN'), O.D_MIN = S.D_MIN; end
O.Z_INIT = 1.0; if isfield(S, 'Z_INIT'), O.Z_INIT = S.Z_INIT; end
O.xml_original = ''; if isfield(S, 'xml_original'), O.xml_original = char(S.xml_original); end
end


function prepara_xml_mc(xml_arena, xml_saida)
copyfile(xml_arena, xml_saida, 'f');
c = fileread(xml_saida);
c = regexprep(c, '<swarm_algorithm_type\s*value\s*=\s*"''[^'']+''"\s*/>', ...
    '<swarm_algorithm_type value="''Couzin''"/>');
c = strrep(c, '<activate_plot value="1"/>', '<activate_plot value="0"/>');
grava(xml_saida, c);
end


function define_bloco(xml_path, bloco, tags, valores)
% Como xml_set_param_in_block: muda os parametros so dentro do bloco.
c = fileread(xml_path);
i1 = strfind(c, ['<' bloco '>']); i2 = strfind(c, ['</' bloco '>']);
if isempty(i1) || isempty(i2), error('Bloco <%s> nao encontrado em %s.', bloco, xml_path); end
seg = c(i1(1):i2(1)-1);
for k = 1:numel(tags)
    pat = ['<' tags{k} '\s*value\s*=\s*"[^"]*"\s*/>'];
    if numel(regexp(seg, pat, 'start')) ~= 1
        error('Parametro <%s> nao aparece uma vez no bloco <%s>.', tags{k}, bloco);
    end
    seg = regexprep(seg, pat, ['<' tags{k} ' value="' num2str(valores(k), '%.6f') '"/>']);
end
grava(xml_path, [c(1:i1(1)-1), seg, c(i2(1):end)]);
end


% =====================================================================
function compara(P)
inicia_log(P, 'compara');
desliga = onCleanup(@() diary('off')); %#ok<NASGU>
algs = {'Couzin', 'Reynolds', 'OlfatiSaber', 'Vasarhelyi'};
linhas = {};
for a = 1:size(P.arenas, 1)
    arena = P.arenas{a, 1}; rot = P.arenas{a, 2};
    d = dir(fullfile(P.pasta, sprintf('mc_Couzin_ra20_%s_*.mat', arena)));
    if isempty(d)
        fprintf('%s: sem Monte Carlo novo; pulando.\n', arena);
        continue
    end
    [~, i] = max([d.datenum]);
    Nw = load(fullfile(d(i).folder, d(i).name));
    O = mc_original(rot);
    if ~isequal(O.SEEDS(:), Nw.SEEDS(:))
        error('%s: sementes diferentes entre o Monte Carlo novo e o original.', arena);
    end
    fprintf('\n================ %s (n = %d) ================\n', arena, numel(Nw.SEEDS));
    fprintf('%-16s %18s %18s %8s\n', 'metrica', 'original', 'r_a <= 20 m', 'p (Wilc.)');
    for m = 1:3
        a0 = O.results(:, m); a1 = Nw.results(:, m);
        p = signrank(a1, a0, 'method', 'exact');
        fprintf('%-16s %8.4f +- %6.4f %8.4f +- %6.4f %8.3g\n', Nw.metric_names{m}, mean(a0), ...
            ic(a0), mean(a1), ic(a1), p);
        linhas(end+1, :) = {arena, Nw.metric_names{m}, mean(a0), ic(a0), mean(a1), ic(a1), p}; %#ok<AGROW>
    end
    fprintf('%-16s %18d %18d\n', 'com colisao', sum(O.results(:, 4) > 0), sum(Nw.results(:, 4) > 0));
    fprintf('%-16s %18d %18d\n', 'com phi_wall>0', sum(O.results(:, 5) > 0), sum(Nw.results(:, 5) > 0));
    linhas(end+1, :) = {arena, 'execucoes_com_colisao', sum(O.results(:, 4) > 0), NaN, ...
        sum(Nw.results(:, 4) > 0), NaN, NaN}; %#ok<AGROW>
    linhas(end+1, :) = {arena, 'execucoes_com_phi_wall', sum(O.results(:, 5) > 0), NaN, ...
        sum(Nw.results(:, 5) > 0), NaN, NaN}; %#ok<AGROW>

    % Ordenacao e comparacoes pareadas com os outros tres (Bonferroni, 6 pares)
    phi = nan(numel(Nw.SEEDS), numel(algs));
    for k = 1:numel(algs)
        if k == 1
            phi(:, k) = Nw.results(:, 2);
        else
            dd = dir(fullfile('data_save', 'monte_carlo', sprintf('mc_%s_%s_*.mat', algs{k}, rot)));
            if isempty(dd), continue, end
            [~, j] = max([dd.datenum]);
            Sk = load(fullfile(dd(j).folder, dd(j).name), 'results', 'SEEDS');
            if isequal(Sk.SEEDS(:), Nw.SEEDS(:))
                phi(:, k) = Sk.results(:, 2);
            end
        end
    end
    [~, ordem] = sort(mean(phi, 1, 'omitnan'), 'descend');
    fprintf('Ordem em phi_corr, com o Couzin novo: %s\n', strjoin(algs(ordem), ' > '));
    for k = 2:numel(algs)
        if all(isnan(phi(:, k))), continue, end
        p = signrank(phi(:, 1), phi(:, k), 'method', 'exact');
        fprintf('  Couzin (r_a <= 20) x %-11s: %.4f x %.4f, p = %.3g%s\n', algs{k}, ...
            mean(phi(:, 1)), mean(phi(:, k)), p, ternario(p < 0.05/6, ' (significativo, Bonferroni)', ''));
        linhas(end+1, :) = {arena, ['phi_corr_vs_' algs{k}], mean(phi(:, k)), NaN, mean(phi(:, 1)), NaN, p}; %#ok<AGROW>
    end
end
if isempty(linhas)
    error('Nada a comparar: rode as etapas ag e mc.');
end
T = cell2table(linhas, 'VariableNames', {'arena', 'medida', 'original', 'ic_original', ...
    'ra20', 'ic_ra20', 'p_wilcoxon'});
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
writetable(T, fullfile(P.pasta, sprintf('comparacao_%s.csv', stamp)));
fprintf('\nTabela gravada em %s\n', fullfile(P.pasta, sprintf('comparacao_%s.csv', stamp)));
end


function h = ic(x)
x = x(:); n = numel(x);
h = tinv(0.975, n - 1) * std(x) / sqrt(n);
end


function s = ternario(c, a, b)
if c, s = a; else, s = b; end
end


% =====================================================================
function pos = posicoes_treino(N, x_range, y_range, z, d_min, seed)
% Identica a gen_positions de prepare_paired_xmls.m.
rng(seed, 'twister');
pos = zeros(3, N); pos(3, :) = z;
xlo = x_range(1) + d_min; xhi = x_range(2) - d_min;
ylo = y_range(1) + d_min; yhi = y_range(2) - d_min;
placed = 0; tries = 0;
while placed < N
    tries = tries + 1;
    if tries > 100000, error('Nao foi possivel posicionar %d drones.', N); end
    cx = xlo + (xhi - xlo) * rand(); cy = ylo + (yhi - ylo) * rand();
    ok = true;
    for j = 1:placed
        if hypot(cx - pos(1, j), cy - pos(2, j)) < d_min, ok = false; break; end
    end
    if ok
        placed = placed + 1; pos(1, placed) = cx; pos(2, placed) = cy;
    end
end
end


function pos = posicoes_mc(N, x_range, y_range, z, d_min, seed, obst, margem)
% Identica a generate_initial_positions de main_monte_carlo_rapid_prototyping.m.
rng(seed, 'twister');
pos = zeros(3, N); pos(3, :) = z;
xlo = x_range(1) + d_min; xhi = x_range(2) - d_min;
ylo = y_range(1) + d_min; yhi = y_range(2) - d_min;
n_obst = size(obst, 2);
placed = 0; tries = 0;
while placed < N
    tries = tries + 1;
    if tries > 100000, error('Nao foi possivel posicionar %d drones.', N); end
    cx = xlo + (xhi - xlo) * rand(); cy = ylo + (yhi - ylo) * rand();
    ok = true;
    for k = 1:n_obst
        if hypot(cx - obst(1, k), cy - obst(2, k)) < obst(3, k) + margem, ok = false; break; end
    end
    if ok
        for j = 1:placed
            if hypot(cx - pos(1, j), cy - pos(2, j)) < d_min, ok = false; break; end
        end
    end
    if ok
        placed = placed + 1; pos(1, placed) = cx; pos(2, placed) = cy;
    end
end
end


function escreve_posicoes(xml_path, pos)
% Substitui a primeira tag <position__ ... "/> (a ativa).
c = fileread(xml_path);
i1 = strfind(c, '<position__');
if isempty(i1), error('Tag <position__ nao encontrada em %s.', xml_path); end
i2 = i1(1) + strfind(c(i1(1):end), '"/>') - 1;
linhas = cell(1, size(pos, 1));
for r = 1:size(pos, 1)
    linhas{r} = strjoin(arrayfun(@(x) sprintf('%.6f', x), pos(r, :), 'UniformOutput', false), ' ');
end
grava(xml_path, [c(1:i1(1)-1), '<position__ value="[', strjoin(linhas, '; '), ']"/>', c(i2(1)+3:end)]);
end


function grava(arq, txt)
fid = fopen(arq, 'w');
if fid < 0, error('Nao consegui gravar %s.', arq); end
fwrite(fid, txt);
fclose(fid);
end
