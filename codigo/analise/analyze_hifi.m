function analyze_hifi()
%ANALYZE_HIFI  Agrega as execucoes de alta fidelidade e calcula a reality gap.
%
% Processa todos os hifi_*.mat, extrai as metricas com as MESMAS formulas do
% Rapid Prototyping, e compara as duas etapas de forma PAREADA por semente.
%
% PAREAMENTO: as execucoes de alta fidelidade usam as sementes 1 a 5, que
% sao as cinco primeiras do Monte Carlo. A comparacao e portanto feita
% execucao a execucao, sobre as MESMAS posicoes iniciais -- o que elimina a
% variacao entre cenarios e da poder estatistico apesar de n = 5.
%
% RESSALVA: o pareamento e das POSICOES INICIAIS, nao das condicoes
% completas. No ponto-massa os drones partem ja em regime; no Gazebo eles
% decolam do solo. Essa diferenca e parte do que a reality gap mede.
%
% TESTE: Wilcoxon pareado (n = 5 nao sustenta pressuposto de normalidade).
% Com n = 5 o menor p-valor possivel e 0.0625, entao NENHUMA comparacao
% individual atinge 0.05. A leitura tem de ser por tamanho de efeito e
% consistencia de sinal, nao por significancia.
%
% USO:  analyze_hifi

clc;
algos   = {'Couzin','Reynolds','OlfatiSaber','Vasarhelyi'};
nparams = [5, 6, 7, 11];
n_alg   = numel(algos);
ambientes = {'vazia','cubos','cilindros'};
amb_mc    = {'vazia','obstaculos','cilindros'};   % rotulo correspondente no Monte Carlo
SEEDS   = 1:5;
dir_hf  = 'data_save/high_fidelity';
dir_mc  = 'data_save/monte_carlo';

%% ============ EXTRACAO ============
fprintf('=== EXTRAINDO METRICAS DAS EXECUCOES DE ALTA FIDELIDADE ===\n\n');
HF = struct();
faltando = {};
for e = 1:numel(ambientes)
    for a = 1:n_alg
        vals = nan(numel(SEEDS), 6);   % corr, vel, coll, wall, MND, F
        durs = nan(numel(SEEDS), 1);
        for s = SEEDS
            arq = fullfile(dir_hf, sprintf('hifi_%s_%s_seed%d.mat', ...
                lower(algos{a}), ambientes{e}, s));
            if ~exist(arq, 'file')
                faltando{end+1} = sprintf('%s/%s/seed%d', algos{a}, ambientes{e}, s); %#ok<AGROW>
                continue;
            end
            M = extrair_metricas_hifi(arq, false);
            vals(s,:) = [M.phi_corr, M.phi_vel, M.phi_coll, M.phi_wall, M.phi_MND, M.F];
            durs(s)   = M.duracao;
        end
        HF.(ambientes{e}).(algos{a}).vals = vals;
        HF.(ambientes{e}).(algos{a}).durs = durs;
        n_ok = sum(~isnan(vals(:,1)));
        fprintf('%-13s [%-6s] %d/%d execucoes | duracao media %.1f s\n', ...
            algos{a}, ambientes{e}, n_ok, numel(SEEDS), mean(durs,'omitnan'));
    end
end
if ~isempty(faltando)
    fprintf('\nAUSENTES: %s\n', strjoin(faltando, ', '));
end

%% ============ DESCRITIVAS ============
for e = 1:numel(ambientes)
    fprintf('\n================================================================\n');
    fprintf(' ALTA FIDELIDADE - ambiente: %s (n = %d)\n', ambientes{e}, numel(SEEDS));
    fprintf('================================================================\n\n');
    fprintf('%-13s %4s %10s %10s %22s %12s\n', ...
        'algoritmo','par','phi_corr','desv.pad','IC 95%','phi_vel');
    fprintf('%s\n', repmat('-',1,78));
    for a = 1:n_alg
        v = HF.(ambientes{e}).(algos{a}).vals;
        x = v(~isnan(v(:,1)), 1);
        if isempty(x); continue; end
        mu = mean(x); sd = std(x);
        ci = tinv(0.975, numel(x)-1) * sd / sqrt(numel(x));
        fprintf('%-13s %4d %10.4f %10.4f  [%8.4f, %8.4f] %12.4f\n', ...
            algos{a}, nparams(a), mu, sd, mu-ci, mu+ci, mean(v(:,2),'omitnan'));
    end

    fprintf('\n%-13s %14s %14s %14s\n', 'algoritmo','colisao','parede','dist.min (m)');
    fprintf('%s\n', repmat('-',1,60));
    for a = 1:n_alg
        v = HF.(ambientes{e}).(algos{a}).vals;
        n = sum(~isnan(v(:,1)));
        if n == 0; continue; end
        fprintf('%-13s %11d/%d %11d/%d %14.2f\n', algos{a}, ...
            sum(v(:,3) > 0), n, sum(v(:,4) > 0), n, mean(0.4./v(:,5),'omitnan'));
    end
end

%% ============ REALITY GAP ============
fprintf('\n================================================================\n');
fprintf(' REALITY GAP: RAPID PROTOTYPING -> ALTA FIDELIDADE\n');
fprintf('================================================================\n\n');

gap = nan(n_alg, numel(ambientes));
for e = 1:numel(ambientes)
    fprintf('--- ambiente: %s ---\n', ambientes{e});
    fprintf('%-13s %4s %9s %9s %10s %8s %10s %9s\n', ...
        'algoritmo','par','RP','HiFi','gap (pp)','rel.','p (Wilc.)','d Cohen');
    fprintf('%s\n', repmat('-',1,80));
    for a = 1:n_alg
        % Monte Carlo, mesmas sementes 1-5
        d = dir(sprintf('%s/mc_%s_%s_*.mat', dir_mc, algos{a}, amb_mc{e}));
        if isempty(d)
            fprintf('%-13s  SEM Monte Carlo correspondente (mc_%s_%s_*.mat)\n', ...
                algos{a}, algos{a}, amb_mc{e});
            continue;
        end
        [~, i] = max([d.datenum]);
        R = load(fullfile(d(i).folder, d(i).name));
        rp = R.results(SEEDS, 2);

        v = HF.(ambientes{e}).(algos{a}).vals;
        hf = v(SEEDS, 1);
        ok = ~isnan(hf);
        if sum(ok) < 3; continue; end

        dif = rp(ok) - hf(ok);
        gap(a,e) = mean(dif);
        pw = signrank(rp(ok), hf(ok));
        dz = mean(dif) / std(dif);

        fprintf('%-13s %4d %9.4f %9.4f %10.2f %7.1f%% %10.4f %9.2f\n', ...
            algos{a}, nparams(a), mean(rp(ok)), mean(hf(ok)), ...
            100*mean(dif), 100*mean(dif)/mean(rp(ok)), pw, dz);
    end
    fprintf('\n');
end

fprintf('NOTA SOBRE OS p-VALORES: com n = 5, o menor p possivel no teste de\n');
fprintf('Wilcoxon pareado e 0.0625. Nenhuma comparacao individual pode\n');
fprintf('atingir 0.05. Interpretar por TAMANHO DE EFEITO (d de Cohen) e\n');
fprintf('consistencia de sinal entre as 5 execucoes, nao por significancia.\n\n');

%% ============ H2 ============
fprintf('================================================================\n');
fprintf(' H2: ARQUITETURA vs COMPLEXIDADE PARAMETRICA\n');
fprintf('================================================================\n\n');

arq_classe = {'prioridade lexicografica','heuristica ponderada', ...
              'potencial suave','curva de frenagem'};

for e = 1:numel(ambientes)
    if all(isnan(gap(:,e))); continue; end
    v = ~isnan(gap(:,e));
    fprintf('--- %s ---\n', ambientes{e});
    [~, ord] = sort(gap(v,e));
    idx = find(v); idx = idx(ord);
    fprintf('Ranking por reality gap (menor primeiro):\n');
    for k = 1:numel(idx)
        fprintf('  %d. %-13s %+6.2f pp  | %2d par. | %s\n', k, algos{idx(k)}, ...
            100*gap(idx(k),e), nparams(idx(k)), arq_classe{idx(k)});
    end
    rho = corr(nparams(v)', gap(v,e), 'type','Spearman');
    fprintf('\nSpearman (parametros x reality gap): rho = %+.2f\n', rho);
    fprintf('  n = 4: valor DESCRITIVO. Significancia a 5%% exigiria |rho| = 1.00.\n');
    fprintf('  H2 preve que a ordenacao siga a ARQUITETURA, nao a complexidade.\n\n');
end

%% ============ GRAFICO ============
n_amb = numel(ambientes);
figure('Color','w','Position',[40 40 460*n_amb 430]);
for e = 1:n_amb
    subplot(1,n_amb,e); hold on;
    mrp = nan(1,n_alg); mhf = nan(1,n_alg);
    crp = nan(1,n_alg); chf = nan(1,n_alg);
    for a = 1:n_alg
        d = dir(sprintf('%s/mc_%s_%s_*.mat', dir_mc, algos{a}, amb_mc{e}));
        if isempty(d); continue; end
        [~, i] = max([d.datenum]);
        R = load(fullfile(d(i).folder, d(i).name));
        rp = R.results(SEEDS, 2);
        v  = HF.(ambientes{e}).(algos{a}).vals;
        hf = v(SEEDS, 1); hf = hf(~isnan(hf));
        if isempty(hf); continue; end
        tc = tinv(0.975, numel(rp)-1);
        mrp(a) = mean(rp); crp(a) = tc*std(rp)/sqrt(numel(rp));
        mhf(a) = mean(hf); chf(a) = tinv(0.975,numel(hf)-1)*std(hf)/sqrt(numel(hf));
    end
    b = bar(1:n_alg, [mrp; mhf]');
    b(1).FaceColor = [0.45 0.65 0.80];
    b(2).FaceColor = [0.85 0.55 0.40];
    errorbar((1:n_alg)-0.15, mrp, crp, 'k','LineStyle','none','LineWidth',1.1);
    errorbar((1:n_alg)+0.15, mhf, chf, 'k','LineStyle','none','LineWidth',1.1);
    set(gca,'XTick',1:n_alg);
    set(gca,'XTickLabel', arrayfun(@(a) sprintf('%s (%d)', algos{a}, nparams(a)), 1:n_alg, 'UniformOutput', false));
    set(gca,'XTickLabelRotation', 30);
    xlim([0.4, n_alg+0.6]);
    ylabel('\phi_{corr}'); ylim([0 1.05]); grid on; box on;
    legend({'Rapid Prototyping','Alta fidelidade'},'Location','southwest','FontSize',8);
    title(sprintf('Reality gap - %s (n = %d)', ambientes{e}, numel(SEEDS)));
    set(gca,'FontName','Times New Roman','FontSize',10);
end
saveas(gcf, 'reality_gap.png');
fprintf('Figura salva: reality_gap.png\n');
end