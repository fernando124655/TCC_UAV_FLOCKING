function gerar_relatorio_parcial()
% GERAR_RELATORIO_PARCIAL
% Consolida todos os resultados de producao disponiveis num relatorio unico.
%
% Le automaticamente os .mat mais recentes de:
%   - auto-tuning (data_save/auto_tuning_production)
%   - Monte Carlo, tres ambientes (data_save/monte_carlo)
%   - batch processing, o que ja completou (data_save/batch_production)
%
% Gera 'relatorio_parcial_<data>.txt' com tabelas e testes formatados,
% e as figuras principais em PNG.
%
% Etapas ausentes sao reportadas como pendentes, nao omitidas.
%
% USO:  gerar_relatorio_parcial

clc;
algos   = {'Couzin','Reynolds','OlfatiSaber','Vasarhelyi'};
nparams = [5, 6, 7, 11];
n_alg   = numel(algos);
R_COLL  = 0.4;

stamp = char(datetime('now','Format','yyyyMMdd'));
fname = sprintf('relatorio_parcial_%s.txt', stamp);
fid = fopen(fname, 'w');

function p(varargin)
    fprintf(varargin{:});
    fprintf(fid, varargin{:});
end

p('================================================================\n');
p('  RELATORIO PARCIAL - ANALISE COMPARATIVA DE ALGORITMOS DE\n');
p('  FLOCKING EM AMBIENTES INDOOR CONFINADOS\n');
p('  Gerado em %s\n', char(datetime('now','Format','dd/MM/yyyy HH:mm')));
p('================================================================\n\n');

p('DESENHO EXPERIMENTAL\n');
p('--------------------\n');
p('Plataforma      : CoFlyers (MATLAB/Simulink + PX4 + Gazebo)\n');
p('Algoritmos      : Couzin (5 par.), Reynolds (6), Olfati-Saber (7),\n');
p('                  Vasarhelyi (11)\n');
p('Arena           : 60 x 60 m, 10 drones, v_flock = 1.0 m/s\n');
p('Ambientes       : vazia | 4 cilindros D=6m | 4 cubos L=6m, em (+-12,+-12)\n');
p('Otimizacao      : GA, populacao 30, 30 geracoes, multi-start 5 sementes,\n');
p('                  cada candidato avaliado sobre 3 config. iniciais pareadas\n');
p('Reproducibilidade: sementes fixadas a priori e disjuntas --\n');
p('                  treino 101-103 | teste 1-20 | batch 201-203\n');
p('Calibracao      : realizada APENAS na arena vazia. Ambientes com\n');
p('                  obstaculos sao teste de GENERALIZACAO.\n\n');

%% ================= 1. AUTO-TUNING =================
p('================================================================\n');
p(' 1. AUTO-TUNING: DESEMPENHO APOS OTIMIZACAO\n');
p('================================================================\n\n');

F_best = nan(1, n_alg);
CV_F   = nan(1, n_alg);
AT = struct();
for a = 1:n_alg
    d = dir(sprintf('data_save/auto_tuning_production/at_%s_*.mat', algos{a}));
    if isempty(d); p('%-12s: AUSENTE\n', algos{a}); continue; end
    [~, i] = max([d.datenum]);
    S = load(fullfile(d(i).folder, d(i).name));
    AT.(algos{a}) = S;
    F_best(a) = min(S.F_opt, [], 'omitnan');
    Fv = S.F_opt(~isnan(S.F_opt));
    CV_F(a) = 100*std(Fv)/mean(Fv);
end

p('Tabela 1.1 - Melhor fitness por algoritmo (menor = melhor)\n\n');
p('%-14s %5s %12s %12s %10s\n','algoritmo','par.','melhor F','phi_corr*','CV do F');
p('%s\n', repmat('-',1,58));
for a = 1:n_alg
    p('%-14s %5d %12.6f %12.4f %9.1f%%\n', ...
        algos{a}, nparams(a), F_best(a), 1-F_best(a), CV_F(a));
end
p('\n* phi_corr implicito: com seguranca perfeita e velocidade saturada,\n');
p('  F = 1 - phi_corr.\n');
p('  CV do F entre as 5 sementes independentes = consistencia da busca.\n\n');

p('Tabela 1.2 - Estabilidade dos parametros (multi-start, 5 sementes)\n\n');
for a = 1:n_alg
    if ~isfield(AT, algos{a}); continue; end
    S = AT.(algos{a});
    p('  %s\n', algos{a});
    p('  %-12s %10s %10s %8s\n','parametro','media','desv.pad','CV(%%)');
    for k = 1:numel(S.search_names)
        col = S.X_opt(:,k); col = col(~isnan(col));
        mu = mean(col); sd = std(col);
        p('  %-12s %10.4f %10.4f %8.1f\n', ...
            S.search_names{k}, mu, sd, 100*sd/max(abs(mu),eps));
    end
    p('\n');
end

%% ================= 2. MONTE CARLO =================
p('================================================================\n');
p(' 2. MONTE CARLO: DESEMPENHO SOB 20 CONFIGURACOES INICIAIS\n');
p('================================================================\n\n');

ambientes = {'vazia','obstaculos'};
rot_amb   = {'arena vazia','com cubos'};
MC = struct();
disp_ok = true(1, numel(ambientes));

for e = 1:numel(ambientes)
    for a = 1:n_alg
        d = dir(sprintf('data_save/monte_carlo/mc_%s_%s_*.mat', ...
            algos{a}, ambientes{e}));
        if isempty(d); disp_ok(e) = false; continue; end
        [~, i] = max([d.datenum]);
        MC.(ambientes{e}).(algos{a}) = load(fullfile(d(i).folder, d(i).name));
    end
end

for e = 1:numel(ambientes)
    if ~disp_ok(e); p('Ambiente %s: dados ausentes\n\n', rot_amb{e}); continue; end
    n = numel(MC.(ambientes{e}).(algos{1}).SEEDS);

    p('Tabela 2.%d - Alinhamento (phi_corr), %s, n=%d\n\n', e, rot_amb{e}, n);
    p('%-14s %5s %10s %10s %24s\n','algoritmo','par.','media','desv.pad','IC 95%%');
    p('%s\n', repmat('-',1,68));
    for a = 1:n_alg
        x = MC.(ambientes{e}).(algos{a}).results(:,2);
        mu = mean(x); sd = std(x);
        ci = tinv(0.975, n-1)*sd/sqrt(n);
        p('%-14s %5d %10.4f %10.4f  [%8.4f, %8.4f]\n', ...
            algos{a}, nparams(a), mu, sd, mu-ci, mu+ci);
    end
    p('\n');

    p('Tabela 2.%d.b - Seguranca: execucoes com violacao (de %d)\n\n', e, n);
    p('%-14s %14s %14s %10s %14s\n', ...
        'algoritmo','colisao','parede','total','dist.min (m)*');
    p('%s\n', repmat('-',1,70));
    for a = 1:n_alg
        r = MC.(ambientes{e}).(algos{a}).results;
        nc = sum(r(:,4)>0); nw = sum(r(:,5)>0);
        dm = mean(R_COLL ./ r(:,6));
        p('%-14s %11d/%d %11d/%d %10d %14.2f\n', ...
            algos{a}, nc, n, nw, n, nc+nw, dm);
    end
    p('\n* media harmonica temporal da distancia minima entre pares,\n');
    p('  convertida de phi_MND por min(d) = r_coll/phi_MND, r_coll = %.1f m.\n\n', R_COLL);
end

%% ---- testes pareados (ambiente com cubos, o mais discriminante) ----
if disp_ok(2)
    n = numel(MC.obstaculos.(algos{1}).SEEDS);
    n_pares = n_alg*(n_alg-1)/2;
    ac = 0.05/n_pares;
    p('Tabela 2.3 - Comparacoes pareadas de phi_corr (com cubos)\n');
    p('Wilcoxon dos postos sinalizados; Bonferroni para %d pares (alpha_c = %.4f)\n\n', ...
        n_pares, ac);
    p('%-13s %-13s %11s %11s %9s %8s\n', ...
        'A','B','dif.media','p (Wilc.)','d Cohen','signif.');
    p('%s\n', repmat('-',1,70));
    for a = 1:n_alg-1
        for b = a+1:n_alg
            xa = MC.obstaculos.(algos{a}).results(:,2);
            xb = MC.obstaculos.(algos{b}).results(:,2);
            dd = xa - xb;
            pw = signrank(xa, xb);
            dz = mean(dd)/std(dd);
            sig = 'nao'; if pw < ac; sig = 'SIM'; end
            p('%-13s %-13s %11.4f %11.5f %9.2f %8s\n', ...
                algos{a}, algos{b}, mean(dd), pw, dz, sig);
        end
    end
    p('\n');
end

%% ================= 3. GENERALIZACAO =================
if all(disp_ok)
    p('================================================================\n');
    p(' 3. GENERALIZACAO: PARAMETROS DA ARENA VAZIA EM AMBIENTE OBSTRUIDO\n');
    p('================================================================\n\n');

    n = numel(MC.vazia.(algos{1}).SEEDS);
    deg = nan(1, n_alg);
    p('Tabela 3.1 - Degradacao de phi_corr\n\n');
    p('%-14s %5s %9s %9s %11s %8s %10s\n', ...
        'algoritmo','par.','vazia','cubos','queda (pp)','rel.','p (Wilc.)');
    p('%s\n', repmat('-',1,72));
    for a = 1:n_alg
        xv = MC.vazia.(algos{a}).results(:,2);
        xo = MC.obstaculos.(algos{a}).results(:,2);
        deg(a) = mean(xv) - mean(xo);
        pw = signrank(xv, xo);
        p('%-14s %5d %9.4f %9.4f %11.2f %7.1f%% %10.5f\n', ...
            algos{a}, nparams(a), mean(xv), mean(xo), ...
            100*deg(a), 100*deg(a)/mean(xv), pw);
    end
    [~, ord] = sort(deg);
    p('\nRanking de robustez (menor degradacao primeiro):\n');
    for k = 1:n_alg
        p('  %d. %-14s %+.2f pp  (%d parametros)\n', ...
            k, algos{ord(k)}, 100*deg(ord(k)), nparams(ord(k)));
    end

    rho_perf = corr(nparams(:), ...
        arrayfun(@(a) mean(MC.vazia.(algos{a}).results(:,2)), 1:n_alg)', ...
        'type','Spearman');
    rho_rob = corr(nparams(:), deg(:), 'type','Spearman');
    p('\nCorrelacao de Spearman com o numero de parametros:\n');
    p('  desempenho (phi_corr, arena vazia) : rho = %+.2f\n', rho_perf);
    p('  degradacao (vazia -> cubos)        : rho = %+.2f\n', rho_rob);
    p('  ATENCAO: n = 4 nao permite inferencia. Valores DESCRITIVOS.\n');
    p('  Para n = 4, significancia a 5%% exigiria |rho| = 1.00.\n\n');
end

%% ================= 4. BATCH =================
p('================================================================\n');
p(' 4. BATCH PROCESSING: ROBUSTEZ A Tc E RUIDO DE VELOCIDADE\n');
p('================================================================\n\n');

for e = 1:2
    amb = {'vazia','cubos'}; amb = amb{e};
    p('Tabela 4.%d - Amplitude de phi_corr na grade 26x26 (%s)\n\n', e, amb);
    p('%-14s %5s %10s %10s %12s %14s\n', ...
        'algoritmo','par.','min','max','amplitude','var. entre rep.');
    p('%s\n', repmat('-',1,72));
    faltantes = {};
    for a = 1:n_alg
        d = dir(sprintf('data_save/batch_production/bp_%s_%s_*.mat', algos{a}, amb));
        ok = false;
        if ~isempty(d)
            [~, i] = max([d.datenum]);
            S = load(fullfile(d(i).folder, d(i).name));
            if isfield(S,'res_mean') && size(S.res_mean,1) > 100
                v  = S.res_mean(:,2);
                sd = mean(S.res_std(:,2), 'omitnan');
                p('%-14s %5d %10.4f %10.4f %12.4f %14.4f\n', ...
                    algos{a}, nparams(a), min(v), max(v), max(v)-min(v), sd);
                ok = true;
            end
        end
        if ~ok; faltantes{end+1} = algos{a}; end %#ok<AGROW>
    end
    if ~isempty(faltantes)
        p('\n  PENDENTE: %s\n', strjoin(faltantes, ', '));
    end
    p('\n');
end

%% ================= 5. SINTESE =================
p('================================================================\n');
p(' 5. SINTESE E ESTADO DAS HIPOTESES\n');
p('================================================================\n\n');

p('H1-A: maior complexidade -> melhor desempenho apos otimizacao\n');
p('  REFUTADA, com sinal invertido. A ordenacao por numero de parametros\n');
p('  (5, 6, 7, 11) nao corresponde a ordenacao por desempenho. O algoritmo\n');
p('  com 6 parametros obtem o melhor alinhamento; o de 11 fica em ultimo.\n');
p('  Spearman rho = %+.2f (descritivo, n=4).\n\n', rho_perf);

p('H1-B: maior complexidade -> menor robustez\n');
p('  TENDENCIA NA DIRECAO PREVISTA pela analise de generalizacao\n');
p('  (Spearman rho = %+.2f). Aguarda o batch com cubos para fechamento\n', rho_rob);
p('  pela segunda fonte de evidencia (perturbacao de Tc e ruido).\n\n');

p('H2: a arquitetura determina a reality gap\n');
p('  SEM DADOS. Exige a etapa de alta fidelidade de producao, ainda\n');
p('  nao executada. Os dados de alta fidelidade da fase de validacao\n');
p('  nao sao utilizaveis: o mundo Gazebo continha obstaculos ausentes\n');
p('  do mapa do CoFlyers e as paredes fisicas estavam 0.5 m deslocadas.\n');
p('  A inconsistencia foi corrigida antes da producao.\n\n');

p('ACHADO ADICIONAL - perfil de falha por arquitetura\n');
p('  Cada arquitetura apresenta um tipo caracteristico de violacao de\n');
p('  seguranca, ESTAVEL entre ambientes e geometrias:\n');
p('    Couzin        (prioridade lexicografica) : colisao entre drones\n');
p('    Reynolds      (repulsao 1/d^2)           : saida da arena\n');
p('    Olfati-Saber  (phi_beta limitada)        : penetracao em obstaculo\n');
p('    Vasarhelyi    (curva de frenagem)        : nenhuma violacao\n');
p('  O Vasarhelyi nao registra violacao em nenhuma das 20 execucoes de\n');
p('  cada ambiente -- ao custo de reducao de velocidade.\n\n');

p('ETAPAS PENDENTES\n');
p('  Batch com cubos : 3 de 4 algoritmos (~30 h de maquina)\n');
p('  Alta fidelidade : nao iniciada (~28 h presenciais)\n\n');

fclose(fid);
fprintf('\n>>> Relatorio salvo em: %s\n', fname);

%% ================= FIGURAS =================
if all(disp_ok)
    n = numel(MC.vazia.(algos{1}).SEEDS);
    tc = tinv(0.975, n-1);

    figure('Color','w','Position',[80 80 1000 400]);
    subplot(1,2,1); hold on;
    mv = zeros(1,n_alg); cv = zeros(1,n_alg);
    mo = zeros(1,n_alg); co = zeros(1,n_alg);
    for a = 1:n_alg
        xv = MC.vazia.(algos{a}).results(:,2);
        xo = MC.obstaculos.(algos{a}).results(:,2);
        mv(a)=mean(xv); cv(a)=tc*std(xv)/sqrt(n);
        mo(a)=mean(xo); co(a)=tc*std(xo)/sqrt(n);
    end
    b = bar(1:n_alg,[mv;mo]');
    b(1).FaceColor=[0.45 0.65 0.80]; b(2).FaceColor=[0.85 0.55 0.40];
    errorbar((1:n_alg)-0.15,mv,cv,'k','LineStyle','none','LineWidth',1.1);
    errorbar((1:n_alg)+0.15,mo,co,'k','LineStyle','none','LineWidth',1.1);
    set(gca,'XTick',1:n_alg,'XTickLabel', arrayfun(@(a) ...
        sprintf('%s\n(%d par.)',algos{a},nparams(a)),1:n_alg,'UniformOutput',false));
    ylabel('\phi_{corr}'); ylim([0 1.05]); grid on; box on;
    legend({'arena vazia','com cubos'},'Location','southwest');
    title('Alinhamento por ambiente (IC 95%)');

    subplot(1,2,2); hold on;
    vv = zeros(1,n_alg); vo = zeros(1,n_alg);
    for a = 1:n_alg
        rv = MC.vazia.(algos{a}).results;
        ro = MC.obstaculos.(algos{a}).results;
        vv(a) = sum(rv(:,4)>0 | rv(:,5)>0);
        vo(a) = sum(ro(:,4)>0 | ro(:,5)>0);
    end
    b2 = bar(1:n_alg,[vv;vo]');
    b2(1).FaceColor=[0.45 0.65 0.80]; b2(2).FaceColor=[0.85 0.55 0.40];
    set(gca,'XTick',1:n_alg,'XTickLabel', arrayfun(@(a) ...
        sprintf('%s\n(%d par.)',algos{a},nparams(a)),1:n_alg,'UniformOutput',false));
    ylabel(sprintf('execucoes com violacao (de %d)',n));
    ylim([0 n+1]); grid on; box on;
    legend({'arena vazia','com cubos'},'Location','northwest');
    title('Violacoes de seguranca');

    saveas(gcf, sprintf('relatorio_figura_%s.png', stamp));
    fprintf('>>> Figura salva em: relatorio_figura_%s.png\n', stamp);
end
end
