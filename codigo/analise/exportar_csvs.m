function exportar_csvs(raiz, saida, pastas_extras)
%EXPORTAR_CSVS  Exporta para CSV os resultados de todas as etapas do estudo.
%
%   exportar_csvs
%   exportar_csvs(raiz, saida)
%   exportar_csvs(raiz, saida, {'resultados_16-10_20261017_011224', 'resultados_16-10_20261017_232159'})
%
% raiz          pasta Prototype_Simulator (padrão: a pasta atual)
% saida         pasta onde os CSVs são gravados (padrão: <raiz>\resultados_csv)
% pastas_extras pastas, relativas à raiz ou absolutas, com um data_save\ dentro,
%               onde também procurar os arquivos (as execuções de 16/10 ficaram
%               em resultados_16-10_<carimbo>\data_save\...)
%
% Gera, em <saida>:
%   metricas_high_fidelity.csv  as 60 execuções de alta fidelidade, uma por linha
%                               (o CSV antigo tinha 59: o exportar_producao perdia
%                               uma linha quando a figura falhava, e esta função
%                               não desenha figuras)
%   monte_carlo.csv             as 240 execuções do Monte Carlo (4 algoritmos x
%                               3 arenas x 20 sementes)
%   lote.csv                    o lote paralelo: 676 combinações x 3 repetições por
%                               algoritmo e arena, com o T_c pedido e o aplicado
%                               (0,1 s: a variação de T_c não chegou ao simulador)
%   varredura_tc.csv            a varredura de T_c em série, nas três arenas
%   arquivos_usados.csv         de que .mat veio cada parte, para conferência
%
% Os CSVs da calibração (melhor F por geração) e das 1.440 execuções com ruído
% já estão no repositório (resultados\csv), gerados dos logs e dos rsjan_*.mat.
%
% Escolha dos arquivos: como nos analyze_*.m, vale o .mat mais recente de cada
% algoritmo e arena; no lote, só os completos (676 combinações); arquivos com
% TESTE no nome são ignorados. A tabela arquivos_usados.csv mostra a escolha.
% Se o mais recente não for o do artigo, mova os outros para uma subpasta.
%
% Funciona no MATLAB e no Octave (não usa writetable).
%
% Escrito para o TCC de Fernando Souza Rodrigues (29/10/2026).

if nargin < 1 || isempty(raiz), raiz = pwd; end
if nargin < 2 || isempty(saida), saida = fullfile(raiz, 'resultados_csv'); end
if nargin < 3, pastas_extras = {}; end
if ischar(pastas_extras), pastas_extras = {pastas_extras}; end
if ~exist(saida, 'dir'), mkdir(saida); end

bases = {fullfile(raiz, 'data_save')};
for k = 1:numel(pastas_extras)
    p = pastas_extras{k};
    if ~exist(p, 'dir'), p = fullfile(raiz, p); end
    if exist(fullfile(p, 'data_save'), 'dir')
        bases{end+1} = fullfile(p, 'data_save'); %#ok<AGROW>
    elseif exist(p, 'dir')
        bases{end+1} = p; %#ok<AGROW>
    else
        warning('exportar_csvs:pasta', 'Pasta extra não encontrada: %s', pastas_extras{k});
    end
end

algos  = {'Couzin', 'Reynolds', 'OlfatiSaber', 'Vasarhelyi'};
usados = {};   % {etapa, algoritmo, arena, arquivo, linhas}

%% 1. Alta fidelidade -------------------------------------------------------
fprintf('\n=== Alta fidelidade ===\n');
arqs = acha(bases, 'high_fidelity', 'hifi_*.mat');
L = {};
falhas = {};
for i = 1:numel(arqs)
    [~, nome] = fileparts(arqs{i});
    p = strsplit(nome, '_');              % hifi_<alg>_<arena>_seed<N>
    try
        M = extrair_metricas_hifi(arqs{i}, false);
        L(end+1, :) = {p{2}, p{3}, str2double(strrep(p{4}, 'seed', '')), M.duracao, ...
            M.phi_corr, M.phi_vel, M.phi_coll, M.phi_wall, M.phi_MND, M.dist_min, M.F, ...
            M.forma_obstaculos}; %#ok<AGROW>
    catch err
        falhas{end+1} = sprintf('%s: %s', nome, err.message); %#ok<AGROW>
    end
end
if ~isempty(L)
    [~, ordem] = sortrows([cellfun(@(a) find(strcmpi(algos, a)), L(:, 1)), ...
        cellfun(@(e) find(strcmp({'vazia', 'cilindros', 'cubos'}, e)), L(:, 2)), cell2mat(L(:, 3))]);
    L = L(ordem, :);
end
grava_csv(fullfile(saida, 'metricas_high_fidelity.csv'), ...
    {'algoritmo', 'ambiente', 'semente', 'duracao_s', 'phi_corr', 'phi_vel', 'phi_coll', ...
     'phi_wall', 'phi_MND', 'dist_min_m', 'F', 'forma_obstaculo'}, L);
fprintf('metricas_high_fidelity.csv: %d linhas (esperadas 60).\n', size(L, 1));
for k = 1:numel(falhas), fprintf('  FALHOU %s\n', falhas{k}); end
usados(end+1, :) = {'alta fidelidade', 'todos', 'todas', sprintf('%d arquivos hifi_*.mat', numel(arqs)), size(L, 1)};

%% 2. Monte Carlo ------------------------------------------------------------
fprintf('\n=== Monte Carlo ===\n');
rotulos = {'vazia', 'vazia'; 'cilindros', 'cilindros'; 'obstaculos', 'cubos'};
cab = {}; L = {};
for a = 1:numel(algos)
    for e = 1:size(rotulos, 1)
        arq = mais_recente(acha(bases, 'monte_carlo', sprintf('mc_%s_%s_*.mat', algos{a}, rotulos{e, 1})), []);
        if isempty(arq)
            fprintf('  AUSENTE: %s / %s\n', algos{a}, rotulos{e, 2});
            continue
        end
        S = load(arq);
        [c, l] = achata(S, arq);
        [cab, L] = junta(cab, L, [{'algoritmo', 'arena'}, c], ...
            [repmat({algos{a}, rotulos{e, 2}}, size(l, 1), 1), l]);
        usados(end+1, :) = {'monte carlo', algos{a}, rotulos{e, 2}, arq, size(l, 1)}; %#ok<AGROW>
        fprintf('  %-12s %-9s <- %s (%d execuções)\n', algos{a}, rotulos{e, 2}, nome_curto(arq), size(l, 1));
    end
end
grava_csv(fullfile(saida, 'monte_carlo.csv'), cab, L);
fprintf('monte_carlo.csv: %d linhas (esperadas 240).\n', size(L, 1));

%% 3. Lote paralelo ------------------------------------------------------------
fprintf('\n=== Lote paralelo ===\n');
cab = {}; L = {};
for a = 1:numel(algos)
    for arena = {'vazia', 'cubos', 'cilindros'}
        cand = acha(bases, 'batch_production', sprintf('bp_%s_%s_*.mat', algos{a}, arena{1}));
        arq = mais_recente(cand, @(S) isfield(S, 'results') && size(S.results, 1) > 100);
        if isempty(arq)
            if ~strcmp(arena{1}, 'cilindros')
                fprintf('  AUSENTE: %s / %s\n', algos{a}, arena{1});
            end
            continue
        end
        S = load(arq);
        [c, l] = achata(S, arq);
        [cab, L] = junta(cab, L, [{'algoritmo', 'arena'}, c], ...
            [repmat({algos{a}, arena{1}}, size(l, 1), 1), l]);
        usados(end+1, :) = {'lote', algos{a}, arena{1}, arq, size(l, 1)}; %#ok<AGROW>
        fprintf('  %-12s %-9s <- %s (%d execuções)\n', algos{a}, arena{1}, nome_curto(arq), size(l, 1));
    end
end
grava_csv(fullfile(saida, 'lote.csv'), cab, L);
fprintf('lote.csv: %d linhas.\n', size(L, 1));

%% 4. Varredura de T_c em série ----------------------------------------------
fprintf('\n=== Varredura de T_c ===\n');
cab = {}; L = {};
for a = 1:numel(algos)
    for arena = {'vazia', 'cubos', 'cilindros'}
        cand = acha(bases, 'tc_sweep', sprintf('tc_%s_%s*.mat', algos{a}, arena{1}));
        arq = mais_recente(cand, []);
        if isempty(arq)
            fprintf('  AUSENTE: %s / %s\n', algos{a}, arena{1});
            continue
        end
        S = load(arq);
        [c, l] = achata(S, arq);
        if isempty(l)
            continue
        end
        [cab, L] = junta(cab, L, [{'algoritmo', 'arena'}, c], ...
            [repmat({algos{a}, arena{1}}, size(l, 1), 1), l]);
        usados(end+1, :) = {'varredura de T_c', algos{a}, arena{1}, arq, size(l, 1)}; %#ok<AGROW>
        fprintf('  %-12s %-9s <- %s (%d execuções)\n', algos{a}, arena{1}, nome_curto(arq), size(l, 1));
    end
end
grava_csv(fullfile(saida, 'varredura_tc.csv'), cab, L);
fprintf('varredura_tc.csv: %d linhas (esperadas 936).\n', size(L, 1));

%% 5. Arquivos usados --------------------------------------------------------
grava_csv(fullfile(saida, 'arquivos_usados.csv'), {'etapa', 'algoritmo', 'arena', 'arquivo', 'linhas'}, usados);
fprintf('\nCSVs gravados em %s\n', saida);
end


%% =========================================================================
function arqs = acha(bases, sub, padrao)
% Lista os arquivos que casam com o padrão em <base>\<sub>, sem os de teste.
arqs = {};
for b = 1:numel(bases)
    d = dir(fullfile(bases{b}, sub, padrao));
    for k = 1:numel(d)
        if isempty(strfind(upper(d(k).name), 'TESTE')) %#ok<STREMP>
            arqs{end+1} = fullfile(d(k).folder, d(k).name); %#ok<AGROW>
        end
    end
end
end


function arq = mais_recente(arqs, aceita)
% O mais recente pela data do arquivo; com 'aceita', só os que passam no teste.
arq = '';
melhor = -inf;
for k = 1:numel(arqs)
    info = dir(arqs{k});
    if info.datenum <= melhor
        continue
    end
    if ~isempty(aceita)
        S = load(arqs{k});
        if ~aceita(S)
            continue
        end
    end
    arq = arqs{k};
    melhor = info.datenum;
end
end


function [cab, linhas] = achata(S, arq)
% Transforma o arquivo de resultados numa tabela longa: uma linha por execução.
% Reconhece os nomes usados nos scripts do estudo; o que não reconhecer, avisa.
R = [];
for nome = {'results', 'res', 'resultados'}
    if isfield(S, nome{1}) && isnumeric(S.(nome{1})) && ndims(S.(nome{1})) <= 3
        R = S.(nome{1});
        break
    end
end
cab = {}; linhas = {};
if isempty(R)
    fprintf('  AVISO: %s não tem results nem res. Variáveis: %s\n', nome_curto(arq), ...
        strjoin(fieldnames(S)', ', '));
    return
end
[nl, nm, nr] = size(R);

% nomes das métricas
metr = {};
for nome = {'metric_names', 'nomes'}
    if isfield(S, nome{1}) && numel(S.(nome{1})) == nm
        metr = cellstr(S.(nome{1}));
        metr = metr(:)';
        break
    end
end
if isempty(metr)
    padrao = {'F', 'phi_corr', 'phi_vel', 'phi_coll', 'phi_wall', 'phi_MND'};
    metr = arrayfun(@(k) sprintf('metrica_%d', k), 1:nm, 'UniformOutput', false);
    metr(1:min(nm, 6)) = padrao(1:min(nm, 6));
end

% descritores de cada linha (combinação, semente, eta, T_c)
desc = {}; vals = {};
pares = {'SEEDS', 'semente'; 'c_sel', 'combinacao_grade'; 'k_sel', 'grupo'; ...
         'eta_sel', 'eta_m_s'; 'ETA', 'eta_m_s'; 'TC', 'tc_pedido_s'; ...
         'tc_sel', 'tc_pedido_s'; 'tc_vals', 'tc_pedido_s'; 'tc_list', 'tc_pedido_s'; 'Tc_vals', 'tc_pedido_s'};
for k = 1:size(pares, 1)
    if isfield(S, pares{k, 1}) && isnumeric(S.(pares{k, 1})) && numel(S.(pares{k, 1})) == nl ...
            && ~any(strcmp(desc, pares{k, 2}))
        desc{end+1} = pares{k, 2}; %#ok<AGROW>
        vals{end+1} = double(S.(pares{k, 1})(:)); %#ok<AGROW>
    end
end
if isfield(S, 'ETA') && isfield(S, 'TC') && numel(S.ETA) == nl && ~any(strcmp(desc, 'combinacao_grade'))
    % no lote, a linha é o índice da combinação na grade (a semente é RNG_BASE + 10000*rep + combinação)
    desc = [{'combinacao_grade'}, desc];
    vals = [{(1:nl)'}, vals];
elseif ~any(strcmp(desc, 'combinacao_grade')) && ~any(strcmp(desc, 'semente')) && nl > 1
    desc = [{'linha_no_arquivo'}, desc];
    vals = [{(1:nl)'}, vals];
end

% repetições (3a dimensão) e medidas por execução
cfg = 1:nr;
tem_cfg = nr > 1;
if isfield(S, 'CFG_SEEDS') && numel(S.CFG_SEEDS) == nr
    cfg = double(S.CFG_SEEDS(:)');
    tem_cfg = true;
end
extras = {}; xv = {};
for nome = {'eta_lido', 'tc_lido', 'tc_aplicado', 'run_times'}
    if isfield(S, nome{1}) && isnumeric(S.(nome{1})) && isequal(size(S.(nome{1})), [nl nr])
        extras{end+1} = nome{1}; %#ok<AGROW>
        xv{end+1} = double(S.(nome{1})); %#ok<AGROW>
    end
end
lote_paralelo = isfield(S, 'ETA') && isfield(S, 'TC') && ~isfield(S, 'tc_lido');

col_cfg = {};
if tem_cfg, col_cfg = {'configuracao'}; end
cab = [desc, col_cfg, extras, metr];
if lote_paralelo
    cab = [cab, {'tc_aplicado_s'}];
end
linhas = cell(nl * nr, numel(cab));
n = 0;
for r = 1:nr
    for i = 1:nl
        n = n + 1;
        lin = cell(1, numel(cab));
        for k = 1:numel(desc), lin{k} = vals{k}(i); end
        if tem_cfg, lin{numel(desc) + 1} = cfg(r); end
        for k = 1:numel(extras), lin{numel(desc) + numel(col_cfg) + k} = xv{k}(i, r); end
        base = numel(desc) + numel(col_cfg) + numel(extras);
        for m = 1:nm, lin{base + m} = R(i, m, r); end
        if lote_paralelo
            lin{end} = 0.1;   % a cópia sem sufixo das configurações gerais tinha T_c = 0,1 s
        end
        linhas(n, :) = lin;
    end
end
end


function [cab, L] = junta(cab, L, c, l)
% Junta tabelas com cabeçalhos possivelmente diferentes (une as colunas).
if isempty(cab)
    cab = c; L = l; return
end
novos = setdiff(c, cab, 'stable');
if ~isempty(novos)
    cab = [cab, novos];
    L = [L, cell(size(L, 1), numel(novos))];
end
M = cell(size(l, 1), numel(cab));
for k = 1:numel(c)
    M(:, strcmp(cab, c{k})) = l(:, k);
end
L = [L; M];
end


function grava_csv(arq, cab, L)
fid = fopen(arq, 'w');
if fid < 0, error('Não consegui gravar %s', arq); end
fprintf(fid, '%s\n', strjoin(cab, ','));
for i = 1:size(L, 1)
    partes = cell(1, size(L, 2));
    for k = 1:size(L, 2)
        v = L{i, k};
        if isempty(v)
            partes{k} = '';
        elseif ischar(v) || isstring(v)
            partes{k} = char(v);
        elseif isinf(v)
            partes{k} = sprintf('%sinf', repmat('-', 1, v < 0));
        else
            partes{k} = sprintf('%.10g', v);
        end
    end
    fprintf(fid, '%s\n', strjoin(partes, ','));
end
fclose(fid);
end


function s = nome_curto(arq)
[~, n, e] = fileparts(arq);
s = [n e];
end
