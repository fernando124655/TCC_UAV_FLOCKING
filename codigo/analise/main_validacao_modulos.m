function R = main_validacao_modulos(experimentos, T_SIM)
%MAIN_VALIDACAO_MODULOS  Valida os tres modulos proprios contra os modelos originais.
%
%   main_validacao_modulos
%   main_validacao_modulos({'Couzin'})
%   main_validacao_modulos({'Couzin','OlfatiSaber','Reynolds'}, 300)
%
% O QUE FAZ (recomendacao 3 do parecer de 26/10)
%   Roda cada modulo no espaco livre, sem paredes nem obstaculos, e mede o
%   comportamento coletivo que o modelo original descreve:
%
%   Couzin et al. (2002): com Delta_r_a fixo, a largura da zona de
%     orientacao (Delta_r_o) leva o grupo de enxame (polarizacao p e
%     momento angular m baixos) a toro (p baixo, m alto) e a grupo paralelo
%     (p alto). Varre Delta_r_o com Delta_r_a = 14 e 2, r_r = 1 m, 30 drones.
%   Olfati-Saber (2006): o gradiente do potencial leva os vizinhos a
%     distancia de referencia d (rede-alfa) e o consenso iguala as
%     velocidades. Mede a distancia ao vizinho mais proximo / d, o desvio
%     das ligacoes ate 1,2 d e a polarizacao, com os parametros calibrados e
%     com os do artigo original (d = 7, r = 1,2 d, a = b = 5), 20 drones. O
%     modulo testado e a VARIANTE normalizada em velocidade usada no TCC.
%   Reynolds (1987): separacao, alinhamento e coesao produzem um bando coeso,
%     alinhado e sem colisoes; tirar cada regra tira o efeito dela. Pesos de
%     referencia (1, 1, 1) e as tres ablacoes, mais os pesos calibrados, 20
%     drones.
%
%   O espaco livre e emulado com o mapa desativado e o enxame centrado em
%   (1000, 1000) m: o modulo do Olfati-Saber tem as paredes da arena fixas
%   em +-30 m, e la elas ficam inativas. Cada execucao dura T_SIM s (padrao
%   300); as medidas sao a media dos ultimos 100 s.
%
% ANTES DE RODAR
%   - Copie este arquivo e figuras_validacao_modulos.m para Prototype_Simulator.
%   - Rode na pasta Prototype_Simulator. Nao rode outra execucao do CoFlyers
%     ao mesmo tempo.
%   - As execucoes sao em serie (cerca de 75, de 30 a 60 s cada: ~1 h). Em
%     serie, as configuracoes gerais (numero de drones, algoritmo) valem
%     para cada execucao, sem o problema da copia sem sufixo.
%
% SAIDA (data_save\validacao_modulos)
%   validacao_<carimbo>.mat   struct R (uma linha por execucao) e resumo
%   validacao_<carimbo>.csv   uma linha por execucao
%   resumo_<carimbo>.csv      media das sementes por configuracao
%   log_<carimbo>.txt
%   figuras: rode figuras_validacao_modulos (chamado no fim).
%
% Escrito para o TCC de Fernando Souza Rodrigues (29/10/2026).

if nargin < 1 || isempty(experimentos)
    experimentos = {'Couzin', 'OlfatiSaber', 'Reynolds'};
end
if ischar(experimentos)
    experimentos = {experimentos};
end
if nargin < 2 || isempty(T_SIM)
    T_SIM = 300;
end
JANELA = 100;               % s finais usados nas medidas
DT_SAVE = 0.5;              % s entre estados gravados
CENTRO = [1000; 1000];      % longe das paredes fixas do modulo do Olfati-Saber
Z0 = 1.0;                   % altitude inicial, como no estudo
XML_BASE = fullfile('xml_config_files', 'parameters_vazia_BACKUP.xml');
R_COLL = 0.4;               % raio de colisao do avaliador

if exist('model_swarm', 'file') ~= 2 || exist(XML_BASE, 'file') ~= 2
    error('Rode na pasta Prototype_Simulator (model_swarm ou %s nao encontrados).', XML_BASE);
end
pasta = fullfile('data_save', 'validacao_modulos');
if ~exist(pasta, 'dir'), mkdir(pasta); end
dir_mats = fullfile('data_save', 'batch_processing', 'mats');
if ~exist(dir_mats, 'dir'), mkdir(dir_mats); end
carimbo = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
diary(fullfile(pasta, sprintf('log_%s.txt', carimbo)));
desliga = onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('=== Validacao dos modulos | %s | T = %g s, medidas nos ultimos %g s ===\n', ...
    datestr(now), T_SIM, JANELA);

% ------------------------------------------------------------ execucoes
C = monta_execucoes(experimentos, XML_BASE);
fprintf('%d execucoes: %s\n', numel(C), strjoin(unique({C.alg}, 'stable'), ', '));

R = repmat(struct('alg', '', 'grupo', '', 'rotulo', '', 'semente', NaN, 'N', NaN, ...
    'nomes', {{}}, 'valores', [], 'p', NaN, 'm', NaN, 'raio', NaN, 'nn', NaN, ...
    'dmin', NaN, 'frac_colisao', NaN, 'frac_maior_grupo', NaN, 'nn_rel', NaN, ...
    'desvio_rel', NaN, 'energia_rel', NaN, 'r_ligacao', NaN, 'd_ref', NaN, ...
    'classe', '', 'pos_final', [], 'vel_final', [], 'traj', [], 't_traj', [], ...
    'serie_p', [], 'serie_m', [], 't_serie', [], 'duracao', NaN, 'erro', ''), numel(C), 1);

xml_run = fullfile('xml_config_files', 'parameters_validacao.xml');
t_total = tic;
for k = 1:numel(C)
    c = C(k);
    R(k).alg = c.alg; R(k).grupo = c.grupo; R(k).rotulo = c.rotulo;
    R(k).semente = c.semente; R(k).N = c.N; R(k).nomes = c.nomes; R(k).valores = c.valores;
    R(k).r_ligacao = c.r_ligacao; R(k).d_ref = c.d_ref;
    try
        % XML desta execucao: algoritmo, numero de drones, duracao, estados
        % gravados, sem mapa e sem graficos; posicoes iniciais num disco
        pos0 = posicoes_disco(c.N, CENTRO, c.R0, c.dmin, Z0, c.semente);
        prepara_xml(XML_BASE, xml_run, c.alg, c.N, T_SIM, DT_SAVE, pos0);
        ps = struct('param_name_s', string(c.nomes), 'param_value_s', string(c.valores));
        if isempty(c.nomes)
            ps = [];
        end
        apaga_antigos(dir_mats, k);
        rng(c.semente, 'twister');
        t0 = tic;
        model_swarm([], [], ps, k, 2, xml_run, []);
        R(k).duracao = toc(t0);

        % Estados gravados pelo model_swarm
        f = acha_estados(dir_mats, k);
        S = load(f, 'states_ob_series', 'interval_state_save', 'sample_time_motion', ...
            'count_data_save', 'swarm_algorithm_type');
        if ~strcmp(char(S.swarm_algorithm_type), c.alg)
            error('O model_swarm rodou %s, e nao %s.', char(S.swarm_algorithm_type), c.alg);
        end
        X = S.states_ob_series(:, :, 1:S.count_data_save);
        t = (0:size(X, 3) - 1) * S.interval_state_save * S.sample_time_motion;
        delete(f);

        R(k) = mede(R(k), X, t, T_SIM, JANELA, R_COLL);
        fprintf('[%2d/%2d] %-11s %-26s sem %d | p %.2f  m %.2f  raio %5.1f  nn %5.2f  dmin %5.2f  maior grupo %.2f%s | %.0f s\n', ...
            k, numel(C), c.alg, c.rotulo, c.semente, R(k).p, R(k).m, R(k).raio, R(k).nn, ...
            R(k).dmin, R(k).frac_maior_grupo, extra_olfati(R(k)), R(k).duracao);
    catch err
        R(k).erro = err.message;
        fprintf(2, '[%2d/%2d] %s %s sem %d: ERRO: %s\n', k, numel(C), c.alg, c.rotulo, ...
            c.semente, err.message);
    end
end
fprintf('\nConcluido em %.2f h.\n', toc(t_total)/3600);

% ------------------------------------------------------------ saida
resumo = resume(R);
arq = fullfile(pasta, sprintf('validacao_%s.mat', carimbo));
save(arq, 'R', 'resumo', 'T_SIM', 'JANELA', 'DT_SAVE', 'CENTRO', 'XML_BASE');
grava_csv(R, fullfile(pasta, sprintf('validacao_%s.csv', carimbo)));
writetable(resumo, fullfile(pasta, sprintf('resumo_%s.csv', carimbo)));
imprime_resumo(resumo);
fprintf('\nResultados em %s\n', arq);
if exist('figuras_validacao_modulos', 'file') == 2
    try
        figuras_validacao_modulos(arq);
    catch err
        fprintf(2, 'Figuras nao geradas: %s\n', err.message);
    end
end
fprintf('=== Fim | %s ===\n', datestr(now));
end


% =====================================================================
function C = monta_execucoes(experimentos, xml_base)
% Lista de execucoes: algoritmo, grupo, rotulo, parametros e condicoes iniciais.
C = struct('alg', {}, 'grupo', {}, 'rotulo', {}, 'semente', {}, 'N', {}, ...
    'nomes', {}, 'valores', {}, 'R0', {}, 'dmin', {}, 'r_ligacao', {}, 'd_ref', {});

if any(strcmp(experimentos, 'Couzin'))
    % Couzin et al. (2002): r_r = 1 como unidade; Delta_r_o e Delta_r_a nas
    % faixas da Tabela 1 deles (0 a 15). Campo de visao do estudo (300 graus).
    N = 30; r_r = 1;
    casos = {14, [0 1 2 3 4 6 8 11 14]; 2, [0 2 6 14]};
    for a = 1:size(casos, 1)
        dra = casos{a, 1};
        for dro = casos{a, 2}
            r_o = r_r + dro; r_a = r_o + dra;
            for s = 1:3
                C(end+1) = struct('alg', 'Couzin', 'grupo', sprintf('dra=%g', dra), ...
                    'rotulo', sprintf('dra=%g dro=%g', dra, dro), 'semente', s, 'N', N, ...
                    'nomes', {{'CoFlyers.swarm.Couzin.r_r', 'CoFlyers.swarm.Couzin.r_o', ...
                    'CoFlyers.swarm.Couzin.r_a'}}, 'valores', [r_r r_o r_a], ...
                    'R0', 6, 'dmin', 1.2, 'r_ligacao', r_a, 'd_ref', NaN); %#ok<AGROW>
            end
        end
    end
end

if any(strcmp(experimentos, 'OlfatiSaber'))
    % Parametros calibrados (lidos do XML) e os do artigo original.
    [~, ~, ~, p] = read_parameter_xml(xml_base);
    d_cal = p.swarm.OlfatiSaber.d_ref;
    r_cal = p.swarm.OlfatiSaber.r_com;
    N = 20;
    conjuntos = {'calibrado', {}, [], d_cal, r_cal; ...
        'artigo (d=7, r=1,2d, a=b=5)', {'CoFlyers.swarm.OlfatiSaber.d_ref', ...
        'CoFlyers.swarm.OlfatiSaber.r_com', 'CoFlyers.swarm.OlfatiSaber.a_coeff', ...
        'CoFlyers.swarm.OlfatiSaber.b_coeff'}, [7 8.4 5 5], 7, 8.4};
    for q = 1:size(conjuntos, 1)
        d = conjuntos{q, 4};
        for s = 1:5
            C(end+1) = struct('alg', 'OlfatiSaber', 'grupo', 'olfati', ...
                'rotulo', conjuntos{q, 1}, 'semente', s, 'N', N, ...
                'nomes', {conjuntos{q, 2}}, 'valores', conjuntos{q, 3}, ...
                'R0', d*sqrt(N/pi), 'dmin', 0.5*d, 'r_ligacao', conjuntos{q, 5}, ...
                'd_ref', d); %#ok<AGROW>
        end
    end
end

if any(strcmp(experimentos, 'Reynolds'))
    % Pesos de referencia (1, 1, 1) e as ablacoes de cada regra; os
    % calibrados entram como comparacao. r_com = 20 m, como no estudo.
    N = 20;
    nm = {'CoFlyers.swarm.Reynolds.w_sep', 'CoFlyers.swarm.Reynolds.w_ali', ...
        'CoFlyers.swarm.Reynolds.w_coh', 'CoFlyers.swarm.Reynolds.r_sep'};
    conjuntos = {'referencia (1,1,1)', nm, [1 1 1 5]; ...
        'sem alinhamento (1,0,1)', nm, [1 0 1 5]; ...
        'sem coesao (1,1,0)', nm, [1 1 0 5]; ...
        'sem separacao (0,1,1)', nm, [0 1 1 5]; ...
        'calibrado', {}, []};
    for q = 1:size(conjuntos, 1)
        for s = 1:5
            C(end+1) = struct('alg', 'Reynolds', 'grupo', 'reynolds', ...
                'rotulo', conjuntos{q, 1}, 'semente', s, 'N', N, ...
                'nomes', {conjuntos{q, 2}}, 'valores', conjuntos{q, 3}, ...
                'R0', 10, 'dmin', 2, 'r_ligacao', 20, 'd_ref', NaN); %#ok<AGROW>
        end
    end
end
if isempty(C)
    error('Nenhum experimento reconhecido. Use Couzin, OlfatiSaber e/ou Reynolds.');
end
end


function pos = posicoes_disco(N, centro, R0, dmin, z0, semente)
% Posicoes aleatorias num disco de raio R0, com distancia minima dmin.
rng(semente + 7000, 'twister');
pos = zeros(3, N);
pos(3, :) = z0;
n = 0; tent = 0;
while n < N
    tent = tent + 1;
    if tent > 200000
        error('Nao coube %d drones no disco de %.1f m com %.1f m de distancia.', N, R0, dmin);
    end
    rr = R0 * sqrt(rand()); th = 2*pi*rand();
    x = centro(1) + rr*cos(th); y = centro(2) + rr*sin(th);
    if n == 0 || min(hypot(pos(1, 1:n) - x, pos(2, 1:n) - y)) >= dmin
        n = n + 1;
        pos(1, n) = x; pos(2, n) = y;
    end
end
end


function prepara_xml(xml_base, xml_run, alg, N, T, dt_save, pos)
% Copia o XML da arena vazia e muda so o necessario para o espaco livre.
c = fileread(xml_base);
c = troca(c, '<number\s+value\s*=\s*"[^"]*"\s*/>', sprintf('<number value="%d"/>', N));
c = troca(c, '<time_max\s+value\s*=\s*"[^"]*"\s*/>', sprintf('<time_max value="%g"/>', T));
c = troca(c, '<activate_save_states\s+value\s*=\s*"[^"]*"\s*/>', '<activate_save_states value="1"/>');
c = troca(c, '<time_interval_save\s+value\s*=\s*"[^"]*"\s*/>', sprintf('<time_interval_save value="%g"/>', dt_save));
c = troca(c, '<swarm_algorithm_type\s+value\s*=\s*"[^"]*"\s*/>', ...
    sprintf('<swarm_algorithm_type value="''%s''"/>', alg));
c = troca(c, '<activate_plot\s+value\s*=\s*"[^"]*"\s*/>', '<activate_plot value="0"/>');
c = troca(c, '<activate\s+value\s*=\s*"[^"]*"\s*/>', '<activate value="0"/>');     % mapa
c = troca(c, '<velocity_noise\s+value\s*=\s*"[^"]*"\s*/>', '<velocity_noise value="0"/>');
% posicoes iniciais: a primeira tag <position__ (a ativa)
i1 = strfind(c, '<position__');
if isempty(i1), error('Tag <position__ nao encontrada em %s.', xml_base); end
i2 = i1(1) + strfind(c(i1(1):end), '"/>') - 1;
linhas = cell(1, 3);
for r = 1:3
    linhas{r} = strjoin(arrayfun(@(x) sprintf('%.6f', x), pos(r, :), 'UniformOutput', false), ' ');
end
c = [c(1:i1(1)-1), '<position__ value="[', strjoin(linhas, '; '), ']"/>', c(i2(1)+3:end)];
fid = fopen(xml_run, 'w');
fwrite(fid, c);
fclose(fid);
[~, ~, ~, p, pos_chk] = read_parameter_xml(xml_run);
if max(abs(pos_chk(:) - pos(:))) > 1e-5 || ~strcmp(p.swarm_algorithm_type, alg) || p.map.activate ~= 0
    error('O XML de validacao nao ficou como esperado (%s).', xml_run);
end
end


function c = troca(c, padrao, novo)
n = numel(regexp(c, padrao, 'start'));
if n ~= 1
    error('Esperava 1 ocorrencia de %s no XML e achei %d.', padrao, n);
end
c = regexprep(c, padrao, novo);
end


function apaga_antigos(dir_mats, k)
d = dir(fullfile(dir_mats, sprintf('data_*_re%d.mat', k)));
for i = 1:numel(d)
    delete(fullfile(d(i).folder, d(i).name));
end
end


function f = acha_estados(dir_mats, k)
d = dir(fullfile(dir_mats, sprintf('data_*_re%d.mat', k)));
if isempty(d)
    error('O model_swarm nao gravou os estados em %s (activate_save_states).', dir_mats);
end
[~, i] = max([d.datenum]);
f = fullfile(d(i).folder, d(i).name);
end


function r = mede(r, X, t, T, janela, r_coll)
% Medidas de comportamento coletivo nos ultimos JANELA segundos.
P = X(1:2, :, :);                     % posicoes x, y
V = X(4:5, :, :);                     % velocidades x, y
sel = find(t >= T - janela - 1e-9);
N = size(X, 2);
p = zeros(1, numel(sel)); m = p; raio = p; nn = p; dmin = p; maior = p;
nn_rel = nan(size(p)); desvio = nn_rel; energia = nn_rel;
colide = false(size(p));
for q = 1:numel(sel)
    k = sel(q);
    pos = P(:, :, k); vel = V(:, :, k);
    vu = vel ./ max(vecnorm(vel), 1e-9);
    p(q) = norm(mean(vu, 2));
    cen = mean(pos, 2);
    rc = pos - cen;
    ru = rc ./ max(vecnorm(rc), 1e-9);
    m(q) = abs(mean(ru(1, :).*vu(2, :) - ru(2, :).*vu(1, :)));
    raio(q) = mean(vecnorm(rc));
    D = sqrt((pos(1, :) - pos(1, :)').^2 + (pos(2, :) - pos(2, :)').^2);
    D(1:N+1:end) = inf;
    nnk = min(D, [], 2);
    nn(q) = mean(nnk);
    dmin(q) = min(nnk);
    colide(q) = dmin(q) < r_coll;
    maior(q) = maior_componente(D < r.r_ligacao) / N;
    if ~isnan(r.d_ref)
        d = r.d_ref;
        nn_rel(q) = mean(nnk) / d;
        lig = D < 1.2*d;                  % vizinhos da rede-alfa (kappa = 1,2)
        lig = triu(lig, 1);
        if any(lig(:))
            dij = D(lig);
            desvio(q) = mean(abs(dij - d)) / d;
            energia(q) = sum((dij - d).^2) / (nnz(lig) + 1) / d^2;
        end
    end
end
r.p = mean(p); r.m = mean(m); r.raio = mean(raio); r.nn = mean(nn);
r.dmin = min(dmin); r.frac_colisao = mean(colide); r.frac_maior_grupo = mean(maior);
r.nn_rel = mean(nn_rel); r.desvio_rel = mean(desvio, 'omitnan'); r.energia_rel = mean(energia, 'omitnan');
r.classe = classe_couzin(r.p, r.m);
% series e trajetorias para as figuras (a cada 1 s; trajetoria dos ultimos 60 s)
passo = max(1, round(1 / max(t(2) - t(1), eps)));
idx = 1:passo:numel(t);
r.t_serie = t(idx);
r.serie_p = arrayfun(@(k) norm(mean(V(:, :, k) ./ max(vecnorm(V(:, :, k)), 1e-9), 2)), idx);
r.serie_m = arrayfun(@(k) momento(P(:, :, k), V(:, :, k)), idx);
it = idx(t(idx) >= T - 60 - 1e-9);
r.traj = P(:, :, it); r.t_traj = t(it);
r.pos_final = P(:, :, end); r.vel_final = V(:, :, end);
end


function mm = momento(pos, vel)
vu = vel ./ max(vecnorm(vel), 1e-9);
rc = pos - mean(pos, 2);
ru = rc ./ max(vecnorm(rc), 1e-9);
mm = abs(mean(ru(1, :).*vu(2, :) - ru(2, :).*vu(1, :)));
end


function n = maior_componente(A)
% Tamanho da maior componente conexa do grafo de adjacencia A.
N = size(A, 1);
visto = false(1, N); n = 0;
for i = 1:N
    if visto(i), continue, end
    fila = i; visto(i) = true; tam = 0;
    while ~isempty(fila)
        j = fila(1); fila(1) = []; tam = tam + 1;
        viz = find(A(j, :) & ~visto);
        visto(viz) = true;
        fila = [fila, viz]; %#ok<AGROW>
    end
    n = max(n, tam);
end
end


function c = classe_couzin(p, m)
% Limiares usuais (Tunstrom et al., 2013): 0,35 e 0,65.
if p > 0.65 && m < 0.35
    c = 'paralelo';
elseif p < 0.35 && m > 0.65
    c = 'toro';
elseif p < 0.35 && m < 0.35
    c = 'enxame';
else
    c = 'transicao';
end
end


function s = extra_olfati(r)
if isnan(r.d_ref)
    s = '';
else
    s = sprintf(' | nn/d %.2f  desvio %.2f', r.nn_rel, r.desvio_rel);
end
end


function T = resume(R)
% Media das sementes por algoritmo e rotulo.
ok = cellfun(@isempty, {R.erro});
R = R(ok);
chaves = unique(strcat({R.alg}, '|', {R.rotulo}), 'stable');
linhas = cell(numel(chaves), 13);
for i = 1:numel(chaves)
    sel = strcmp(strcat({R.alg}, '|', {R.rotulo}), chaves{i});
    Ri = R(sel);
    linhas(i, :) = {Ri(1).alg, Ri(1).rotulo, numel(Ri), mean([Ri.p]), std([Ri.p]), ...
        mean([Ri.m]), std([Ri.m]), mean([Ri.raio]), mean([Ri.nn]), min([Ri.dmin]), ...
        mean([Ri.frac_maior_grupo]), mean([Ri.nn_rel]), mean([Ri.desvio_rel])};
end
T = cell2table(linhas, 'VariableNames', {'algoritmo', 'configuracao', 'execucoes', ...
    'p_media', 'p_dp', 'm_media', 'm_dp', 'raio', 'nn', 'dmin', 'maior_grupo', ...
    'nn_sobre_d', 'desvio_rel'});
end


function imprime_resumo(T)
fprintf('\n%-11s %-28s %3s %6s %6s %7s %6s %6s %6s %7s %6s\n', 'algoritmo', 'configuracao', ...
    'n', 'p', 'm', 'raio', 'nn', 'dmin', 'grupo', 'nn/d', 'desvio');
for i = 1:height(T)
    fprintf('%-11s %-28s %3d %6.2f %6.2f %7.1f %6.2f %6.2f %6.2f %7.2f %6.2f\n', ...
        T.algoritmo{i}, T.configuracao{i}, T.execucoes(i), T.p_media(i), T.m_media(i), ...
        T.raio(i), T.nn(i), T.dmin(i), T.maior_grupo(i), T.nn_sobre_d(i), T.desvio_rel(i));
end
end


function grava_csv(R, arq)
fid = fopen(arq, 'w');
fprintf(fid, ['algoritmo,configuracao,semente,N,p,m,raio,nn,dmin,frac_colisao,' ...
    'frac_maior_grupo,nn_sobre_d,desvio_rel,energia_rel,classe_couzin,duracao_s,erro\n']);
for k = 1:numel(R)
    r = R(k);
    fprintf(fid, '%s,"%s",%d,%d,%.6f,%.6f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.6f,%s,%.1f,"%s"\n', ...
        r.alg, r.rotulo, r.semente, r.N, r.p, r.m, r.raio, r.nn, r.dmin, r.frac_colisao, ...
        r.frac_maior_grupo, r.nn_rel, r.desvio_rel, r.energia_rel, r.classe, r.duracao, ...
        strrep(r.erro, '"', ''''));
end
fclose(fid);
end
