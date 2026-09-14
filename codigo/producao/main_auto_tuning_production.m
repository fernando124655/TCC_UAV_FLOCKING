function main_auto_tuning_production(algorithm_name, ga_seeds)
% MAIN_AUTO_TUNING_PRODUCTION
% Auto-tuning de producao com multi-start e reprodutibilidade completa.
%
% DESENHO:
%   - GA com PopulationSize=30, MaxGenerations=30 (fixo p/ os 4 algoritmos).
%   - Nr=3: cada candidato avaliado sobre 3 configuracoes iniciais PAREADAS.
%   - Multi-start com 5 sementes independentes; reporta-se a melhor.
%   - Separacao treino/teste: treino = sementes 101-103; teste (Monte Carlo)
%     = sementes 1-20, disjuntas.
%   - Retomada automatica via resume_<algoritmo>.mat.
%
% REPARAMETRIZACAO (Couzin): o GA busca em (r_r, k_o, k_a), onde k_o e k_a
% sao as LARGURAS das zonas em unidades de r_r, exatamente como em Couzin
% et al. (2002), Tabela 1, que explora Delta_r_o e Delta_r_a em [0, 15] com
% r_r = 1 como unidade de comprimento. A conversao para os parametros que o
% CoFlyers espera e:
%       r_o = r_r * (1 + k_o)
%       r_a = r_r * (1 + k_o + k_a)
% Vantagens: (i) limites ancorados no paper original; (ii) o aninhamento
% r_r <= r_o <= r_a e automatico, eliminando as restricoes lineares e o
% @gacreationlinearfeasible (que colapsava a populacao inicial nas
% fronteiras); (iii) busca em caixa, geometria limpa.
%
% USO:
%   main_auto_tuning_production('Couzin')
%   main_auto_tuning_production('Reynolds', 1:5)

clc; close all;

if nargin < 1
    error('Informe o algoritmo. Ex: main_auto_tuning_production(''Couzin'')');
end
if nargin < 2 || isempty(ga_seeds); ga_seeds = 1:5; end

%% ====================== CONFIGURACAO ======================
POP_SIZE  = 30;
N_GEN     = 30;
CFG_SEEDS = [101 102 103];   % configuracoes de TREINO
D_MIN     = 5.0;
Z_INIT    = 1.0;
N_WORKERS = 6;
RNG_BASE  = 1000;

[param_names, search_names, lb, ub, A, b, transform] = ...
    get_algorithm_config(algorithm_name);
n_params = numel(lb);

fprintf('=== Auto-Tuning de Producao: %s ===\n', algorithm_name);
fprintf('Parametros: %d | Populacao: %d | Geracoes: %d | Nr: %d\n', ...
    n_params, POP_SIZE, N_GEN, numel(CFG_SEEDS));
fprintf('Sementes GA (multi-start): %s\n', mat2str(ga_seeds));
fprintf('Sementes das config. de treino: %s\n', mat2str(CFG_SEEDS));
fprintf('Espaco de busca:\n');
for k = 1:n_params
    fprintf('  %-10s [%8.3f, %8.3f]\n', search_names{k}, lb(k), ub(k));
end
if isempty(A)
    fprintf('Restricoes lineares: nenhuma\n');
else
    fprintf('Restricoes lineares: %d\n', size(A,1));
end

%% ============ CONFIGURACOES INICIAIS PAREADAS ============
xml_list = prepare_paired_xmls(algorithm_name, CFG_SEEDS, D_MIN, Z_INIT);

%% ============ BLINDAGEM CONTRA CORRIDA DE I/O ============
prepare_parallel_safe(xml_list);

%% ==================== POOL PARALELO ====================
if isempty(gcp('nocreate'))
    parpool(min(feature('numcores'), N_WORKERS));
end

%% ============ RETOMADA DE SEMENTES CONCLUIDAS ============
out_dir = 'data_save/auto_tuning_production';
if ~exist(out_dir, 'dir'); mkdir(out_dir); end
stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));

n_seeds = numel(ga_seeds);
X_opt   = nan(n_seeds, n_params);   % espaco de BUSCA
F_opt   = nan(n_seeds, 1);
t_seed  = nan(n_seeds, 1);
seed_done = false(1, n_seeds);

resume_file = fullfile(out_dir, sprintf('resume_%s.mat', algorithm_name));
if exist(resume_file, 'file')
    R = load(resume_file);
    if isfield(R,'ga_seeds') && isequal(R.ga_seeds, ga_seeds) ...
            && size(R.X_opt,2) == n_params
        X_opt = R.X_opt; F_opt = R.F_opt;
        t_seed = R.t_seed; seed_done = R.seed_done;
        fprintf('Retomando: %d de %d sementes ja concluidas (%s)\n', ...
            sum(seed_done), n_seeds, mat2str(ga_seeds(seed_done)));
    else
        fprintf('Arquivo de retomada incompativel; recomecando do zero.\n');
    end
end

%% ==================== MULTI-START ====================
for s = 1:n_seeds
    seed = ga_seeds(s);

    if seed_done(s)
        fprintf('\n--- Multi-start %d/%d (semente %d) JA CONCLUIDA, pulando ---\n', ...
            s, n_seeds, seed);
        continue
    end

    fprintf('\n--- Multi-start %d/%d (semente GA = %d) ---\n', s, n_seeds, seed);
    txt_base = sprintf('%s/prod_%s_seed%d_%s', out_dir, algorithm_name, seed, stamp);

    rng(seed, 'twister');

    % transform() converte do espaco de BUSCA para os parametros do CoFlyers
    fun = @(x) fitness_paired_configs(transform(x), param_names, ...
        xml_list, RNG_BASE, txt_base);

    options = optimoptions('ga', ...
        'Display',           'iter', ...
        'UseParallel',       true, ...
        'PopulationSize',    POP_SIZE, ...
        'MaxGenerations',    N_GEN, ...
        'FunctionTolerance', 1e-4);

    tt = tic;
    [x_best, f_best] = ga(fun, n_params, A, b, [], [], lb, ub, [], options);
    t_seed(s) = toc(tt);

    X_opt(s, :)  = x_best(:)';
    F_opt(s)     = f_best;
    seed_done(s) = true;

    fprintf('Semente %d: F = %.6f  (%.1f min)\n', seed, f_best, t_seed(s)/60);
    fprintf('  busca    : %s\n', mat2str(x_best, 6));
    fprintf('  CoFlyers : %s\n', mat2str(transform(x_best), 6));

    save(resume_file, 'algorithm_name','param_names','search_names', ...
        'lb','ub','A','b','ga_seeds','CFG_SEEDS','POP_SIZE','N_GEN', ...
        'D_MIN','Z_INIT','X_opt','F_opt','t_seed','seed_done');
    save(sprintf('%s/at_%s_%s.mat', out_dir, algorithm_name, stamp), ...
        'algorithm_name','param_names','search_names','lb','ub','A','b', ...
        'ga_seeds','CFG_SEEDS','POP_SIZE','N_GEN','D_MIN','Z_INIT', ...
        'X_opt','F_opt','t_seed','seed_done','s');
end

%% ============ ANALISE DE ESTABILIDADE ============
if all(isnan(F_opt))
    error('Nenhuma semente concluida; nada a analisar.');
end
[f_best_all, idx_best] = min(F_opt, [], 'omitnan');
x_final_search = X_opt(idx_best, :);
x_final        = transform(x_final_search);   % valores para o CoFlyers
n_done         = sum(seed_done);

fprintf('\n===== ESTABILIDADE NO ESPACO DE BUSCA (%s, %d de %d) =====\n', ...
    algorithm_name, n_done, n_seeds);
fprintf('%-10s %10s %10s %8s %10s\n', ...
    'parametro', 'media', 'desv.pad.', 'CV(%)', 'pos.faixa');
for k = 1:n_params
    col = X_opt(:,k); col = col(~isnan(col));
    mu = mean(col); sd = std(col);
    cv = 100 * sd / max(abs(mu), eps);
    pos = 100 * (x_final_search(k) - lb(k)) / max(ub(k) - lb(k), eps);
    flag = '';
    if pos > 90 || pos < 10; flag = ' <-- na fronteira'; end
    fprintf('%-10s %10.4f %10.4f %8.1f %9.0f%%%s\n', ...
        search_names{k}, mu, sd, cv, pos, flag);
end

fprintf('\nFitness por semente: %s\n', mat2str(F_opt', 5));
fprintf('MELHOR: semente %d, F = %.6f\n', ga_seeds(idx_best), f_best_all);

fprintf('\nParametros para aplicar no XML (espaco CoFlyers):\n');
for k = 1:numel(param_names)
    nm = param_names{k};
    nm = extractAfter(nm, max(strfind(nm, '.')));
    fprintf('  %-10s = %.6f\n', nm, x_final(k));
end

fprintf(['\nLEITURA: CV > 20%% indica multiplos otimos locais (resultado ', ...
         'valido).\n         "na fronteira" indica limite possivelmente ', ...
         'restringindo o otimo.\n']);

save(sprintf('%s/at_%s_%s.mat', out_dir, algorithm_name, stamp), ...
    'algorithm_name','param_names','search_names','lb','ub','A','b', ...
    'ga_seeds','CFG_SEEDS','POP_SIZE','N_GEN','D_MIN','Z_INIT', ...
    'X_opt','F_opt','t_seed','seed_done','x_final_search','x_final', ...
    'f_best_all','idx_best','xml_list');

fprintf('\nResultados salvos em: %s/at_%s_%s.mat\n', out_dir, algorithm_name, stamp);
fprintf(['\nPROXIMO PASSO: aplicar x_final com xml_set_param_in_block ', ...
         '(escopo por bloco).\n']);
end


%% ============================================================
function [param_names, search_names, lb, ub, A, b, transform] = ...
    get_algorithm_config(alg)
% Retorna:
%   param_names  : nomes CoFlyers (notacao de ponto) na ordem de escrita
%   search_names : rotulos do espaco de BUSCA (podem diferir)
%   lb, ub       : limites no espaco de BUSCA
%   A, b         : restricoes lineares no espaco de BUSCA (A*x <= b)
%   transform    : funcao do espaco de busca -> parametros CoFlyers

switch alg

    case 'Couzin'
        % Busca em (r_r, k_o, k_a, r_shill, w_shill), com k = larguras das
        % zonas em unidades de r_r -- parametrizacao de Couzin et al. (2002).
        param_names = ["CoFlyers.swarm.Couzin.r_r", ...
                       "CoFlyers.swarm.Couzin.r_o", ...
                       "CoFlyers.swarm.Couzin.r_a", ...
                       "CoFlyers.swarm.Couzin.r_shill", ...
                       "CoFlyers.swarm.Couzin.w_shill"];
        search_names = {'r_r','k_o','k_a','r_shill','w_shill'};

        % k_o, k_a em [0, 15]: intervalo explorado no paper (Tabela 1).
        % r_r em [0.5, 3.5]: escala fisica de seguranca; o teto mantem
        % r_a <= ~3.5*31 = 108 m, ordem da diagonal da arena (85 m).
        % r_shill, w_shill: sem equivalente em Couzin; limites empiricos.
        lb = [0.5,  0.0,  0.0,  1.0, 0.1];
        ub = [3.5, 15.0, 15.0, 15.0, 8.0];

        % Aninhamento automatico (k >= 0) -> sem restricoes lineares.
        A = []; b = [];

        transform = @(x) [ x(1), ...                    % r_r
                           x(1)*(1 + x(2)), ...         % r_o
                           x(1)*(1 + x(2) + x(3)), ...  % r_a
                           x(4), ...                    % r_shill
                           x(5) ];                      % w_shill

    case 'Reynolds'
        param_names = ["CoFlyers.swarm.Reynolds.w_sep", ...
                       "CoFlyers.swarm.Reynolds.w_ali", ...
                       "CoFlyers.swarm.Reynolds.w_coh", ...
                       "CoFlyers.swarm.Reynolds.w_shill", ...
                       "CoFlyers.swarm.Reynolds.r_sep", ...
                       "CoFlyers.swarm.Reynolds.r_shill"];
        search_names = {'w_sep','w_ali','w_coh','w_shill','r_sep','r_shill'};
        % r_com PADRONIZADO em 20 (igual ao Vasarhelyi), para remover o
        % confundidor de alcance de percepcao entre algoritmos.
        % r_sep opera aninhado dentro de r_com -> teto 19.0 (limite fisico).
        lb = [0.1,  0.1, 0.0,  0.1,  0.5,  1.0];
        ub = [10.0, 10.0, 5.0, 10.0, 19.0, 20.0];
        A = []; b = [];
        transform = @(x) x;

    case 'OlfatiSaber'
        % r_com OTIMIZADO (nao mais derivado por kappa = 1.2).
        %
        % Motivo: a razao do alpha-lattice kappa = r/d = 1.2 adotada por
        % Olfati-Saber (2006) pressupoe um bando JA AGREGADO -- o paper
        % inicializa os agentes numa regiao compacta. Sob o protocolo desta
        % pesquisa (configuracoes iniciais aleatorias dispersas na arena),
        % impor kappa = 1.2 remove um grau de liberdade que importa: teste
        % de sensibilidade mostrou F = 0.2145 em r_com = 7.96 (kappa = 1.2)
        % contra F = 0.0947 em r_com = 12 (kappa = 1.81), mantidos fixos os
        % demais parametros. A razao resultante deve ser REPORTADA.
        %
        % Alcance grande tambem degrada: com r_com = 50 numa arena de 60 m
        % todo drone ve todos, a agregacao inicial fica violenta e o
        % overshoot atinge as paredes (F = 0.987).
        %
        % Repulsao de parede por BETA-AGENTS [OS1, Sec. VII, Lemma 4]:
        %   c_arena -> ganho de posicao c_1^beta
        %   d_arena -> distancia de interacao d_beta
        % O ganho de velocidade c_2^beta e derivado no modulo por
        % amortecimento critico: c_2 = 2*sqrt(c_1), conforme o paper.
        %
        % c_pm_obs e r0_obs seguem no modulo para OBSTACULOS INTERNOS
        % (shills de parede sao filtrados), inativos na arena vazia.
        param_names = ["CoFlyers.swarm.OlfatiSaber.d_ref", ...
                       "CoFlyers.swarm.OlfatiSaber.c_vm", ...
                       "CoFlyers.swarm.OlfatiSaber.a_coeff", ...
                       "CoFlyers.swarm.OlfatiSaber.b_coeff", ...
                       "CoFlyers.swarm.OlfatiSaber.c_arena", ...
                       "CoFlyers.swarm.OlfatiSaber.d_arena", ...
                       "CoFlyers.swarm.OlfatiSaber.r_com"];
        search_names = {'d_ref','c_vm','a','b','c_arena','d_arena','r_com'};

        % d_ref: limitado por geometria (10 agentes ocupam ~3.6*d_ref).
        % a, b: o paper adota a = b = 5; faixas centradas nesse valor.
        % c_vm: teto elevado de 20 para 30 -- na execucao anterior a media
        %       das 5 sementes ficou a 98% da faixa (provavel restricao).
        % r_com: faixa em torno do otimo local observado (~12), coberta com
        %        margem para os dois lados.
        lb = [ 4.0,  0.5,  0.5,  1.0,  1.0,  2.0,  6.0];
        ub = [13.0, 30.0, 10.0, 10.0, 60.0, 12.0, 25.0];

        % (1) funcao de acao exige 0 < a <= b
        % (2) alcance nao pode ser menor que a distancia desejada: d <= r
        A = [0 0 1 -1 0 0  0;
             1 0 0  0 0 0 -1];
        b = [0; 0];

        transform = @(x) x;

    case 'Vasarhelyi'
        param_names = ["CoFlyers.swarm.Vasarhelyi.r_rep_0", ...
                       "CoFlyers.swarm.Vasarhelyi.p_rep", ...
                       "CoFlyers.swarm.Vasarhelyi.r_frict_0", ...
                       "CoFlyers.swarm.Vasarhelyi.c_frict", ...
                       "CoFlyers.swarm.Vasarhelyi.v_frict", ...
                       "CoFlyers.swarm.Vasarhelyi.p_frict", ...
                       "CoFlyers.swarm.Vasarhelyi.a_frict", ...
                       "CoFlyers.swarm.Vasarhelyi.r_shill_0", ...
                       "CoFlyers.swarm.Vasarhelyi.v_shill", ...
                       "CoFlyers.swarm.Vasarhelyi.p_shill", ...
                       "CoFlyers.swarm.Vasarhelyi.a_shill"];
        search_names = {'r_rep_0','p_rep','r_frict_0','c_frict','v_frict', ...
                        'p_frict','a_frict','r_shill_0','v_shill', ...
                        'p_shill','a_shill'};
        % LIMITES DERIVADOS DO PAPER: faixas de trabalho da Tabela S1
        % (v_flock = 4 m/s, arena 250 m) escaladas pelo fator 0.25, que
        % corresponde simultaneamente a razao de velocidade (1/4), de arena
        % (60/250) e de alcance (20/80). Parametros com dimensao de tempo
        % (p_rep, p_frict, p_shill) e adimensionais (C_frict) nao escalam.
        % Margem de ~30% aplicada as faixas para permitir exploracao.
        lb = [ 3.0, 0.05,  8.0, 0.01, 0.010, 0.0, 0.0, 0.0, 1.5,  0.2, 0.2];
        ub = [ 9.0, 0.50, 25.0, 0.40, 0.600, 12.0, 3.0, 5.0, 5.0, 12.0, 3.0];
        A = []; b = [];
        transform = @(x) x;

    otherwise
        error('Algoritmo desconhecido: %s', alg);
end
end