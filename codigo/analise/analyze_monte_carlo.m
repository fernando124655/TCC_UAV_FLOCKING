function analyze_monte_carlo(ambiente)
% ANALYZE_MONTE_CARLO
% Analise estatistica comparativa dos resultados de Monte Carlo.
%
% Desenho PAREADO: os quatro algoritmos foram avaliados sobre as MESMAS 20
% configuracoes iniciais (sementes 1-20). Isso permite testes de amostras
% dependentes, que eliminam a variacao entre cenarios e tem poder
% estatistico maior que testes independentes.
%
% Testes aplicados:
%   - t pareado          : parametrico, pressupoe diferencas ~normais
%   - Wilcoxon signed-rank: nao parametrico, sem pressuposto de normalidade
%   - Bonferroni          : correcao para 6 comparacoes (4 algoritmos 2 a 2)
%   - d de Cohen pareado  : tamanho de efeito
%
% ENTRADA:
%   ambiente : 'vazia' (padrao) ou 'obstaculos'
%
% USO:
%   analyze_monte_carlo            % arena vazia
%   analyze_monte_carlo('obstaculos')

if nargin < 1 || isempty(ambiente); ambiente = 'vazia'; end

algos = {'Couzin','Reynolds','OlfatiSaber','Vasarhelyi'};
nparams = [5, 6, 7, 11];
dir_mc = 'data_save/monte_carlo';

%% Carrega o .mat mais recente de cada algoritmo
n_alg = numel(algos);
DATA = struct();
for a = 1:n_alg
    d = dir(sprintf('%s/mc_%s_%s_*.mat', dir_mc, algos{a}, ambiente));
    if isempty(d)
        error('Nenhum arquivo para %s no ambiente "%s".', algos{a}, ambiente);
    end
    [~, i] = max([d.datenum]);
    R = load(fullfile(d(i).folder, d(i).name));
    DATA.(algos{a}) = R;
    fprintf('%-12s <- %s\n', algos{a}, d(i).name);
end

metric_names = DATA.(algos{1}).metric_names;
SEEDS = DATA.(algos{1}).SEEDS;
n = numel(SEEDS);

% Confere o pareamento
for a = 2:n_alg
    if ~isequal(DATA.(algos{a}).SEEDS, SEEDS)
        error('Sementes diferentes entre algoritmos: pareamento invalido.');
    end
end
fprintf('\nPareamento confirmado: %d configuracoes identicas (sementes %d-%d)\n', ...
    n, SEEDS(1), SEEDS(end));

%% ============ TABELA DESCRITIVA ============
fprintf('\n===== ESTATISTICAS DESCRITIVAS (ambiente: %s, n=%d) =====\n', ambiente, n);
idx_rep = [2 3 4 5 6];   % phi_corr, phi_vel, phi_coll, phi_wall, phi_MND
for m = idx_rep
    fprintf('\n--- %s ---\n', metric_names{m});
    fprintf('%-12s %4s %10s %10s %22s %s\n', ...
        'algoritmo','par','media','desv.pad','IC 95%','violacoes');
    for a = 1:n_alg
        x = DATA.(algos{a}).results(:, m);
        mu = mean(x); sd = std(x);
        ci = tinv(0.975, n-1) * sd / sqrt(n);
        nv = sum(x > 0);
        if m == 4 || m == 5   % coll e wall: contar violacoes
            extra = sprintf('%d/%d', nv, n);
        else
            extra = '-';
        end
        fprintf('%-12s %4d %10.5f %10.5f  [%8.5f, %8.5f] %s\n', ...
            algos{a}, nparams(a), mu, sd, mu-ci, mu+ci, extra);
    end
end

%% ============ NORMALIDADE DAS DIFERENCAS ============
fprintf('\n===== NORMALIDADE DAS DIFERENCAS (Shapiro-Wilk via Lilliefors) =====\n');
fprintf('phi_corr, todos os pares. p < 0.05 => rejeita normalidade => usar Wilcoxon\n');
for a = 1:n_alg-1
    for b = a+1:n_alg
        d = DATA.(algos{a}).results(:,2) - DATA.(algos{b}).results(:,2);
        try
            [h, p] = lillietest(d);
        catch
            h = NaN; p = NaN;   % toolbox ausente
        end
        if isnan(h)
            veredito = 'n/d';
        elseif h == 1
            veredito = 'NAO normal';
        else
            veredito = 'normal';
        end
        fprintf('  %-12s vs %-12s  p = %.4f  %s\n', ...
            algos{a}, algos{b}, p, veredito);
    end
end

%% ============ TESTES PAREADOS ============
n_pares = n_alg*(n_alg-1)/2;
alpha_bonf = 0.05 / n_pares;

for m = [2 3]    % phi_corr e phi_vel (as continuas bem-comportadas)
    fprintf('\n===== TESTES PAREADOS: %s =====\n', metric_names{m});
    fprintf('alpha = 0.05 ; Bonferroni p/ %d comparacoes => alpha_c = %.4f\n', ...
        n_pares, alpha_bonf);
    fprintf('%-12s %-12s %10s %10s %10s %8s %s\n', ...
        'A','B','dif.media','p (t par.)','p (Wilc.)','d Cohen','signif.');
    for a = 1:n_alg-1
        for b = a+1:n_alg
            xa = DATA.(algos{a}).results(:, m);
            xb = DATA.(algos{b}).results(:, m);
            d  = xa - xb;

            [~, p_t] = ttest(d);                    % t pareado
            p_w = signrank(xa, xb);                 % Wilcoxon pareado
            dz  = mean(d) / std(d);                 % d de Cohen pareado

            if p_t < alpha_bonf; sig = 'SIM'; else; sig = 'nao'; end
            fprintf('%-12s %-12s %10.5f %10.5f %10.5f %8.2f %s\n', ...
                algos{a}, algos{b}, mean(d), p_t, p_w, dz, sig);
        end
    end
end

%% ============ SEGURANCA: TESTE EXATO ============
fprintf('\n===== SEGURANCA: contagem de violacoes =====\n');
fprintf('%-12s %12s %12s %12s\n', 'algoritmo','colisao','parede','total');
for a = 1:n_alg
    nc = sum(DATA.(algos{a}).results(:,4) > 0);
    nw = sum(DATA.(algos{a}).results(:,5) > 0);
    fprintf('%-12s %9d/%d %9d/%d %12d\n', algos{a}, nc, n, nw, n, nc+nw);
end
fprintf(['\nNOTA: metricas de seguranca sao quase sempre zero, entao media e\n', ...
         'IC nao sao informativos. Reportar CONTAGEM de execucoes com\n', ...
         'violacao e comparar com teste de McNemar (pareado, binario).\n']);

% McNemar par a par sobre "houve alguma violacao"
fprintf('\n--- McNemar sobre violacao (colisao OU parede) ---\n');
fprintf('%-12s %-12s %6s %6s %10s\n','A','B','A>B','B>A','p');
for a = 1:n_alg-1
    for b = a+1:n_alg
        va = (DATA.(algos{a}).results(:,4) > 0) | (DATA.(algos{a}).results(:,5) > 0);
        vb = (DATA.(algos{b}).results(:,4) > 0) | (DATA.(algos{b}).results(:,5) > 0);
        n01 = sum(~va &  vb);
        n10 = sum( va & ~vb);
        if (n01 + n10) > 0
            % teste binomial exato (McNemar exato)
            p = 2 * binocdf(min(n01,n10), n01+n10, 0.5);
            p = min(p, 1);
        else
            p = NaN;
        end
        fprintf('%-12s %-12s %6d %6d %10.5f\n', algos{a}, algos{b}, n10, n01, p);
    end
end

%% ============ GRAFICO ============
figure('Color','w','Position',[100 100 900 400]);
for k = 1:2
    m = k + 1;   % phi_corr, phi_vel
    subplot(1,2,k); hold on;
    mus = zeros(1,n_alg); cis = zeros(1,n_alg);
    for a = 1:n_alg
        x = DATA.(algos{a}).results(:, m);
        mus(a) = mean(x);
        cis(a) = tinv(0.975, n-1) * std(x) / sqrt(n);
    end
    bar(1:n_alg, mus, 'FaceColor', [0.45 0.6 0.75]);
    errorbar(1:n_alg, mus, cis, 'k', 'LineStyle','none', 'LineWidth', 1.2);
    set(gca, 'XTick', 1:n_alg, 'XTickLabel', ...
        arrayfun(@(a) sprintf('%s\n(%d)', algos{a}, nparams(a)), 1:n_alg, ...
        'UniformOutput', false));
    ylabel(strrep(metric_names{m},'_','\_'));
    title(sprintf('%s  (n=%d, IC 95%%)', strrep(metric_names{m},'_','\_'), n));
    grid on; box on;
    ylim([min(mus-cis)*0.98, max(mus+cis)*1.02]);
end
sgtitle(sprintf('Monte Carlo - ambiente: %s', ambiente));

fprintf('\nAnalise concluida.\n');
end