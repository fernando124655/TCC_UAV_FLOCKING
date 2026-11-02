function main_ruido_sem_transitorio(T_SKIP, pasta_antiga)
%MAIN_RUIDO_SEM_TRANSITORIO  Refaz as 1.440 execucoes com ruido sem o transitorio da partida.
%
%   main_ruido_sem_transitorio
%   main_ruido_sem_transitorio(7, 'data_save\ruido_split')
%
% O QUE FAZ
%   Repete exatamente as execucoes dos arquivos antigos: os rs19_* de 20/10
%   (Couzin, Reynolds e Olfati-Saber) e os rs_Vasarhelyi_* de 19/10. De cada
%   arquivo ele reaproveita as combinacoes (c_sel), os niveis de ruido
%   (eta_sel), as posicoes iniciais (pos_cfg), as sementes (RNG_BASE +
%   10000*configuracao + c) e o XML de origem (xml_src). So o avaliador muda:
%   ele calcula as metricas duas vezes, na execucao inteira, como antes, e
%   a partir de T_SKIP segundos de voo, depois do transitorio de altitude.
%
%   A versao da execucao inteira confere o resultado: ela tem de reproduzir
%   o arquivo antigo. Se o primeiro lote (cerca de 8 min) nao reproduzir, o
%   script para, em vez de gastar 5 h com execucoes diferentes das antigas.
%
% ANTES DE RODAR
%   1. Copie este arquivo, resumo_ruido_sem_transitorio.m e a pasta
%      avaliador_janela (com os dois modelos .m.txt) para a pasta
%      Prototype_Simulator.
%   2. Confira que os 12 arquivos antigos estao em data_save\ruido_split
%      (ou informe a pasta no segundo argumento):
%        rs19_Couzin_<arena>.mat, rs19_Reynolds_<arena>.mat,
%        rs19_OlfatiSaber_<arena>.mat e rs_Vasarhelyi_<arena>.mat,
%        com <arena> = vazia, cubos e cilindros.
%      Os rs_Couzin_*, rs_Reynolds_* e rs_OlfatiSaber_* de 19/10 nao servem
%      (rodaram com o modulo do Vasarhelyi) e nao sao usados.
%   3. Nao rode outra execucao do CoFlyers ao mesmo tempo: as duas usariam
%      os mesmos arquivos de despacho.
%
% O avaliador instalado na pasta evaluation_0_module e copiado para
% data_save\ruido_sem_transitorio\backup_avaliador_<carimbo> e volta ao
% lugar no fim, mesmo se a execucao for interrompida (Ctrl+C) ou der erro.
% Se o MATLAB fechar no meio, copie de volta os dois arquivos dessa pasta.
%
% SAIDA (data_save\ruido_sem_transitorio)
%   rsjan_<algoritmo>_<arena>.mat  res (sem os T_SKIP s iniciais, 40x13x3),
%                                  res_completa (execucao inteira),
%                                  res_antigo, dif_max, eta_lido, t_cfg ...
%   resumo_<carimbo>.csv           execucoes com violacao por tipo
%   log_<carimbo>.txt
%   Colunas de res: 1 F, 2 phi_corr, 3 phi_vel, 4 phi_coll, 5 phi_wall,
%   6 phi_MND, 7 parede, 8 piso/teto, 9 obstaculo, 10 dentro de obstaculo,
%   11 menor distancia a obstaculo, 12 menor distancia as paredes,
%   13 checagem da uniao (zero).
%
% Se parar no meio, rode de novo: os pares algoritmo/arena ja salvos sao
% pulados.
%
% CUSTO: cerca de 5 h (as 1.080 de 20/10 levaram 3,7 h; as 360 de 19/10, 1,2 h).
%
% Escrito para o TCC de Fernando Souza Rodrigues (28/10/2026).

if nargin < 1 || isempty(T_SKIP)
    T_SKIP = 7;
end
if nargin < 2 || isempty(pasta_antiga)
    pasta_antiga = fullfile('data_save', 'ruido_split');
end

ALGS = {'Couzin', 'Reynolds', 'OlfatiSaber', 'Vasarhelyi'};
ARENAS = {'vazia', 'cubos', 'cilindros'};
N_WORKERS = 6;
TOL = 1e-9;      % diferenca aceita entre a execucao inteira e o arquivo antigo
N_SAIDA = 26;    % 13 metricas da execucao inteira + 13 da janela

if exist('model_swarm', 'file') ~= 2 || exist('read_parameter_xml', 'file') ~= 2 || ...
        ~exist('xml_config_files', 'dir')
    error('Rode na pasta Prototype_Simulator do CoFlyers (model_swarm ou xml_config_files nao encontrados).');
end

pasta_saida = fullfile('data_save', 'ruido_sem_transitorio');
if ~exist(pasta_saida, 'dir')
    mkdir(pasta_saida);
end
carimbo = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
diary(fullfile(pasta_saida, sprintf('log_%s.txt', carimbo)));
desliga_diary = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('=== Ruido sem o transitorio inicial | T_SKIP = %g s | %s ===\n', T_SKIP, datestr(now));
fprintf('Arquivos antigos em: %s\n', pasta_antiga);

% ------------------------------------------------------------ arquivos antigos
faltam = {};
for a = 1:numel(ALGS)
    for e = 1:numel(ARENAS)
        f = fullfile(pasta_antiga, nome_antigo(ALGS{a}, ARENAS{e}));
        if exist(f, 'file') ~= 2
            faltam{end+1} = f; %#ok<AGROW>
        end
    end
end
if ~isempty(faltam)
    error(['Faltam arquivos antigos:\n  %s\n' ...
        'Informe a pasta: main_ruido_sem_transitorio(%g, ''C:\\...\\pasta'')'], ...
        strjoin(faltam, '\n  '), T_SKIP);
end

% ------------------------------------------------------------ avaliador
% Os modelos ficam em avaliador_janela como .m.txt, fora do caminho do MATLAB;
% sao gravados por cima do avaliador que o MATLAB usa (o que which encontra).
pasta_aval = fileparts(which('evaluation_0_module_one'));
if isempty(pasta_aval) || ~strcmp(fileparts(which('evaluation_0_module_average')), pasta_aval)
    error('Nao achei o par evaluation_0_module_one/average na mesma pasta do caminho do MATLAB.');
end
pasta_novo = fullfile(fileparts(mfilename('fullpath')), 'avaliador_janela');
modelo_one = fullfile(pasta_novo, 'evaluation_0_module_one.m.txt');
modelo_avg = fullfile(pasta_novo, 'evaluation_0_module_average.m.txt');
if exist(modelo_one, 'file') ~= 2 || exist(modelo_avg, 'file') ~= 2
    error('Nao achei os modelos do avaliador em %s.', pasta_novo);
end
pasta_bkp = fullfile(pasta_saida, ['backup_avaliador_', carimbo]);
mkdir(pasta_bkp);
copyfile(fullfile(pasta_aval, 'evaluation_0_module_one.m'), pasta_bkp);
copyfile(fullfile(pasta_aval, 'evaluation_0_module_average.m'), pasta_bkp);
devolve_avaliador = onCleanup(@() restaura_avaliador(pasta_bkp, pasta_aval)); %#ok<NASGU>

grava_texto(fullfile(pasta_aval, 'evaluation_0_module_one.m'), fileread(modelo_one));
txt = regexprep(fileread(modelo_avg), 'T_SKIP = [0-9.]+;', sprintf('T_SKIP = %g;', T_SKIP), 'once');
grava_texto(fullfile(pasta_aval, 'evaluation_0_module_average.m'), txt);
rehash;
clear evaluation_0_module_one evaluation_0_module_average
instalado = fileread(which('evaluation_0_module_average'));
if isempty(strfind(instalado, sprintf('T_SKIP = %g;', T_SKIP))) || ...
        isempty(strfind(fileread(which('evaluation_0_module_one')), 'separa_tipos'))
    error('O avaliador com janela nao ficou ativo no caminho do MATLAB.');
end
fprintf('Avaliador com janela instalado em %s\n  (copia do anterior em %s).\n', pasta_aval, pasta_bkp);

nomes = {'F', 'phi_corr', 'phi_vel', 'phi_coll', 'phi_wall', 'phi_MND', ...
    'parede', 'piso_teto', 'obstaculo', 'dentro', 'dmin_obstaculo', 'dmin_arena', ...
    'checagem_uniao'};
param_name = "CoFlyers.noise.velocity_noise";
primeiro_lote = true;
t_total = tic;

for a = 1:numel(ALGS)
    alg = ALGS{a};
    for e = 1:numel(ARENAS)
        arena = ARENAS{e};
        arq_saida = fullfile(pasta_saida, sprintf('rsjan_%s_%s.mat', alg, arena));
        if exist(arq_saida, 'file') == 2
            S0 = load(arq_saida, 'T_SKIP', 'completo');
            if isfield(S0, 'completo') && S0.completo && S0.T_SKIP == T_SKIP
                fprintf('\n%s | %s: ja feito; pulando.\n', alg, arena);
                continue
            end
        end

        fprintf('\n================ %s | %s ================\n', alg, arena);
        arquivo_antigo = fullfile(pasta_antiga, nome_antigo(alg, arena));
        A = load(arquivo_antigo);
        if ~strcmp(char(A.alg), alg) || ~strcmp(char(A.arena), arena)
            error('%s traz %s/%s, e nao %s/%s.', arquivo_antigo, char(A.alg), char(A.arena), alg, arena);
        end
        c_sel = double(A.c_sel(:));
        eta_sel = double(A.eta_sel(:));
        k_sel = A.k_sel;
        pos_cfg = A.pos_cfg;
        CFG_SEEDS = A.CFG_SEEDS;
        RNG_BASE = double(A.RNG_BASE);
        xml_src = char(A.xml_src);
        res_antigo = A.res;
        n_sel = numel(c_sel);
        n_cfg = numel(CFG_SEEDS);

        % XMLs de trabalho: o de origem, com o algoritmo e as posicoes antigas
        xml_list = cell(1, n_cfg);
        for r = 1:n_cfg
            xml_r = fullfile('xml_config_files', sprintf('parameters_rsjan_%s_%s_r%d.xml', alg, arena, r));
            copyfile(xml_src, xml_r, 'f');
            c = fileread(xml_r);
            c = regexprep(c, '<swarm_algorithm_type\s*value\s*=\s*"''[^'']+''"\s*/>', ...
                ['<swarm_algorithm_type value="''', alg, '''"/>']);
            c = regexprep(c, '<activate_plot\s*value\s*=\s*"1"\s*/>', '<activate_plot value="0"/>');
            c = regexprep(c, '<activate_save_states\s*value\s*=\s*"1"\s*/>', '<activate_save_states value="0"/>');
            fid = fopen(xml_r, 'w');
            fwrite(fid, c);
            fclose(fid);
            escreve_posicoes(xml_r, pos_cfg{r});
            [~, ~, ~, p_chk, pos_chk] = read_parameter_xml(xml_r);
            if max(abs(pos_cfg{r}(:) - pos_chk(:))) > 1e-5
                error('Falha ao escrever as posicoes em %s.', xml_r);
            end
            if ~strcmp(p_chk.swarm_algorithm_type, alg)
                error('O algoritmo em %s e %s, e nao %s.', xml_r, p_chk.swarm_algorithm_type, alg);
            end
            xml_list{r} = xml_r;
        end

        % Cliente preparado antes de abrir o pool (o simulador le a copia sem sufixo)
        pool = gcp('nocreate');
        if ~isempty(pool)
            delete(pool);
        end
        if exist('prepare_parallel_safe', 'file') == 2
            prepare_parallel_safe(xml_list);
        else
            for r = 1:n_cfg
                read_parameter_xml(xml_list{r});
            end
        end
        rehash;
        [~, ~, ~, tc_cli, ~, ~, ~, ~, alg_cli] = setting_parameters();
        if ~strcmp(alg_cli, alg)
            error('setting_parameters.m do cliente esta com %s, e nao %s.', alg_cli, alg);
        end
        fprintf('Cliente preparado: setting_parameters.m com %s (T_c = %g s).\n', alg, tc_cli);
        parpool('Processes', min(feature('numcores'), N_WORKERS));

        res_cfg = nan(n_sel, N_SAIDA, n_cfg);
        eta_lido = nan(n_sel, n_cfg);
        tc_lido = nan(n_sel, n_cfg);
        t_cfg = zeros(1, n_cfg);
        t_par = tic;

        for r = 1:n_cfg
            xml_r = xml_list{r};
            base = RNG_BASE + 10000*r;
            combos = repmat(struct('param_name_s', param_name, 'param_value_s', string(0)), n_sel, 1);
            for i = 1:n_sel
                combos(i).param_value_s = string(eta_sel(i));
            end
            res_r = nan(n_sel, N_SAIDA);
            eta_r = nan(n_sel, 1);
            tc_r = nan(n_sel, 1);
            alg_r = strings(n_sel, 1);

            t0 = tic;
            parfor i = 1:n_sel
                rng(base + c_sel(i), 'twister');
                v = model_swarm([], [], combos(i), 1, 2, xml_r, []);
                res_r(i, :) = v(:).';
                [~, ~, ~, tc_w, ~, ~, ~, ~, alg_w] = setting_parameters();
                alg_r(i) = string(alg_w);
                tc_r(i) = tc_w;
                [~, sc] = get_multi_core_value();
                fn = str2func(['noise_module_parameters', sc]);
                eta_r(i) = fn();
            end
            t_cfg(r) = toc(t0);

            res_cfg(:, :, r) = res_r;
            eta_lido(:, r) = eta_r;
            tc_lido(:, r) = tc_r;
            n_alg = sum(alg_r == string(alg));
            fprintf(['  configuracao %d (semente %d): %.1f min | phi_wall > 0: %d de %d ' ...
                '(antes: %d) | sem os %g s iniciais: %d | algoritmo executado: %s nas %d\n'], ...
                r, CFG_SEEDS(r), t_cfg(r)/60, sum(res_r(:, 5) > 0), n_sel, ...
                sum(res_antigo(:, 5, r) > 0), T_SKIP, sum(res_r(:, 18) > 0), alg, n_alg);
            if n_alg < n_sel
                error('O algoritmo executado nao foi %s em %d execucoes.', alg, n_sel - n_alg);
            end
            if max(abs(eta_r - eta_sel)) > 1e-9
                error('O ruido lido nos workers difere do pedido (diferenca maxima %g).', max(abs(eta_r - eta_sel)));
            end

            if primeiro_lote
                d = max_dif(res_r(:, 1:13), res_antigo(:, :, r));
                fprintf('  Conferencia com o arquivo antigo, por metrica: %s\n', mat2str(d, 3));
                if any(d(1:6) > TOL)
                    error(['O primeiro lote nao reproduz o arquivo antigo (metricas nativas). ' ...
                        'O script parou para nao gastar 5 h com execucoes diferentes. ' ...
                        'Mande o log, o main_ruido_split_19_10.m e o avaliador split usado em 20/10.']);
                end
                fprintf('  O primeiro lote reproduz o arquivo antigo; seguindo.\n');
                primeiro_lote = false;
            end
        end

        res_completa = res_cfg(:, 1:13, :);
        res = res_cfg(:, 14:26, :);
        dif_max = max_dif(res_completa, res_antigo);
        reproduz = all(dif_max(1:6) <= TOL);
        elapsed = toc(t_par);
        completo = true;
        save(arq_saida, 'alg', 'arena', 'T_SKIP', 'res', 'res_completa', 'res_antigo', ...
            'dif_max', 'reproduz', 'nomes', 'c_sel', 'eta_sel', 'k_sel', 'pos_cfg', 'CFG_SEEDS', ...
            'RNG_BASE', 'xml_src', 'eta_lido', 'tc_lido', 't_cfg', 'elapsed', ...
            'completo', 'arquivo_antigo');

        fprintf('  Diferenca maxima para o arquivo antigo, por metrica: %s\n', mat2str(dif_max, 3));
        if reproduz
            fprintf('  Execucao inteira igual a do arquivo antigo.\n');
        else
            fprintf(['  ATENCAO: a execucao inteira NAO reproduz o arquivo antigo nas metricas ' ...
                'nativas; estas execucoes sao outras realizacoes do mesmo desenho.\n']);
        end
        imprime_tipos(alg, arena, eta_sel, res_completa, res, T_SKIP);
        fprintf('  Salvo em %s (%.1f min).\n', arq_saida, elapsed/60);
    end
end

pool = gcp('nocreate');
if ~isempty(pool)
    delete(pool);
end
fprintf('\nConcluido em %.2f h.\n', toc(t_total)/3600);
if exist('resumo_ruido_sem_transitorio', 'file') == 2
    resumo_ruido_sem_transitorio(pasta_saida, fullfile(pasta_saida, sprintf('resumo_%s.csv', carimbo)));
end
fprintf('=== Fim | %s ===\n', datestr(now));
end


% =====================================================================
function nome = nome_antigo(alg, arena)
if strcmp(alg, 'Vasarhelyi')
    nome = sprintf('rs_%s_%s.mat', alg, arena);      % execucao de 19/10
else
    nome = sprintf('rs19_%s_%s.mat', alg, arena);    % execucao de 20/10
end
end


function d = max_dif(X, Y)
% Maior diferenca absoluta por metrica (coluna), tratando inf igual a inf.
X = reshape(permute(X, [1 3 2]), [], size(X, 2));
Y = reshape(permute(Y, [1 3 2]), [], size(Y, 2));
D = abs(X - Y);
D(X == Y) = 0;
D(isnan(D)) = inf;
d = max(D, [], 1);
end


function imprime_tipos(alg, arena, eta_sel, res_c, res_j, T_SKIP)
fprintf('\n--- %s | %s: execucoes com violacao, por tipo (inteira -> sem os %g s iniciais) ---\n', ...
    alg, arena, T_SKIP);
fprintf('   eta  exec  colisao   phi_wall    parede  piso/teto  obstac    dentro   phi_wall_m (inteira -> janela)\n');
niveis = unique(eta_sel(:)).';
for eta = niveis
    k = eta_sel(:) == eta;
    C = reshape(permute(res_c(k, :, :), [1 3 2]), [], size(res_c, 2));
    J = reshape(permute(res_j(k, :, :), [1 3 2]), [], size(res_j, 2));
    cont = @(M, col) sum(M(:, col) > 0);
    fprintf('  %4.2f  %4d  %3d->%-3d  %3d->%-3d  %3d->%-3d  %3d->%-3d  %3d->%-3d  %3d->%-3d   %.5f -> %.5f\n', ...
        eta, size(C, 1), cont(C, 4), cont(J, 4), cont(C, 5), cont(J, 5), cont(C, 7), cont(J, 7), ...
        cont(C, 8), cont(J, 8), cont(C, 9), cont(J, 9), cont(C, 10), cont(J, 10), ...
        mean(C(:, 5)), mean(J(:, 5)));
end
end


function escreve_posicoes(xml_path, pos)
% Mesma rotina de main_batch_production.m.
content = fileread(xml_path);
idx = strfind(content, '<position__');
if isempty(idx)
    error('Tag <position__ nao encontrada em %s', xml_path);
end
s = idx(1);
rest = content(s:end);
e_rel = strfind(rest, '"/>');
if isempty(e_rel)
    error('Fim da tag <position__ nao encontrado.');
end
e = s + e_rel(1) + 1;
rows = cell(1, 3);
for r = 1:3
    rows{r} = strjoin(arrayfun(@(x) sprintf('%.6f', x), pos(r, :), 'UniformOutput', false), ' ');
end
new_tag = ['<position__ value="[', strjoin(rows, '; '), ']"/>'];
content = [content(1:s-1), new_tag, content(e+1:end)];
fid = fopen(xml_path, 'w');
fwrite(fid, content);
fclose(fid);
end


function grava_texto(arquivo, txt)
fid = fopen(arquivo, 'w');
if fid < 0
    error('Nao consegui gravar %s.', arquivo);
end
fwrite(fid, txt);
fclose(fid);
end


function restaura_avaliador(pasta_bkp, pasta_aval)
try
    copyfile(fullfile(pasta_bkp, 'evaluation_0_module_one.m'), pasta_aval, 'f');
    copyfile(fullfile(pasta_bkp, 'evaluation_0_module_average.m'), pasta_aval, 'f');
    rehash;
    clear evaluation_0_module_one evaluation_0_module_average
    fprintf('Avaliador anterior devolvido a %s.\n', pasta_aval);
catch err
    fprintf(2, ['NAO consegui devolver o avaliador anterior (%s).\n' ...
        'Copie a mao os dois arquivos de %s para %s.\n'], err.message, pasta_bkp, pasta_aval);
end
end
