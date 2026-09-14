function analyze_generalization()
% ANALYZE_GENERALIZATION
% Compara o desempenho de cada algoritmo entre os dois ambientes:
% arena vazia (onde os parametros foram calibrados) e arena com obstaculos
% (nunca vista durante a otimizacao).
%
% PERGUNTA: os parametros calibrados em arena vazia generalizam para um
% ambiente com obstaculos internos?
%
% DESENHO: pareado por semente DENTRO de cada algoritmo. A execucao k nos
% dois ambientes parte da mesma semente, embora as posicoes iniciais
% difiram (no ambiente obstruido, posicoes dentro dos obstaculos foram
% rejeitadas). O pareamento e portanto APROXIMADO -- adequado para medir
% degradacao, nao para diferencas finas.
%
% Converte tambem phi_MND para distancia fisica:
%   phi_MND = r_coll / min(dist)  =>  min(dist) = r_coll / phi_MND
% Valor ALTO de phi_MND significa drones MAIS PROXIMOS (maior risco).
%
% USO:
%   analyze_generalization

algos   = {'Couzin','Reynolds','OlfatiSaber','Vasarhelyi'};
nparams = [5, 6, 7, 11];
dir_mc  = 'data_save/monte_carlo';
R_COLL  = 0.4;    % metros -- conferir com evaluation_0_module_parameters

n_alg = numel(algos);
V = struct(); O = struct();

for a = 1:n_alg
    V.(algos{a}) = carrega(dir_mc, algos{a}, 'vazia');
    O.(algos{a}) = carrega(dir_mc, algos{a}, 'obstaculos');
end

metric_names = V.(algos{1}).metric_names;
n = numel(V.(algos{1}).SEEDS);
fprintf('\nn = %d execucoes por algoritmo por ambiente\n', n);

%% ============ DEGRADACAO DO ALINHAMENTO ============
fprintf('\n===== DEGRADACAO DE phi_corr (vazia -> obstaculos) =====\n');
fprintf('alpha = 0.05 ; Bonferroni p/ %d algoritmos => alpha_c = %.4f\n', ...
    n_alg, 0.05/n_alg);
fprintf('%-12s %4s %9s %9s %9s %7s %9s %9s %s\n', ...
    'algoritmo','par','vazia','obst.','queda(pp)','%rel','p(t par)','p(Wilc)','signif');

deg = zeros(1, n_alg);
for a = 1:n_alg
    xv = V.(algos{a}).results(:,2);
    xo = O.(algos{a}).results(:,2);
    d  = xv - xo;
    deg(a) = mean(d);
    [~, pt] = ttest(d);
    pw = signrank(xv, xo);
    rel = 100 * mean(d) / mean(xv);
    if pt < 0.05/n_alg; sig = 'SIM'; else; sig = 'nao'; end
    fprintf('%-12s %4d %9.4f %9.4f %9.2f %6.1f%% %9.5f %9.5f %s\n', ...
        algos{a}, nparams(a), mean(xv), mean(xo), 100*mean(d), rel, pt, pw, sig);
end

[~, ord] = sort(deg);
fprintf('\nRanking de robustez (menor degradacao primeiro):\n');
for k = 1:n_alg
    fprintf('  %d. %-12s  %+.2f pp\n', k, algos{ord(k)}, 100*deg(ord(k)));
end

%% ============ DEGRADACAO DA VELOCIDADE ============
fprintf('\n===== DEGRADACAO DE phi_vel (vazia -> obstaculos) =====\n');
fprintf('ATENCAO: Reynolds, Couzin e OlfatiSaber receberam normalizacao de\n');
fprintf('velocidade constante (adaptacao de Vicsek); Vasarhelyi mantem\n');
fprintf('autopropulsao nativa. Comparacoes de phi_vel ENTRE algoritmos\n');
fprintf('medem essa adaptacao, nao a arquitetura original.\n\n');
fprintf('%-12s %9s %9s %9s %9s\n', 'algoritmo','vazia','obst.','variacao','p(Wilc)');
for a = 1:n_alg
    xv = V.(algos{a}).results(:,3);
    xo = O.(algos{a}).results(:,3);
    pw = signrank(xv, xo);
    fprintf('%-12s %9.4f %9.4f %9.4f %9.5f\n', ...
        algos{a}, mean(xv), mean(xo), mean(xo)-mean(xv), pw);
end

%% ============ SEGURANCA POR AMBIENTE ============
fprintf('\n===== VIOLACOES DE SEGURANCA POR AMBIENTE =====\n');
fprintf('%-12s %-22s %-22s\n', '', '--- arena vazia ---', '--- com obstaculos ---');
fprintf('%-12s %8s %8s %5s %8s %8s %5s\n', ...
    'algoritmo','colisao','parede','tot','colisao','parede','tot');
for a = 1:n_alg
    cv = sum(V.(algos{a}).results(:,4) > 0);
    wv = sum(V.(algos{a}).results(:,5) > 0);
    co = sum(O.(algos{a}).results(:,4) > 0);
    wo = sum(O.(algos{a}).results(:,5) > 0);
    fprintf('%-12s %6d/%d %6d/%d %5d %6d/%d %6d/%d %5d\n', ...
        algos{a}, cv,n, wv,n, cv+wv, co,n, wo,n, co+wo);
end
fprintf(['\nNOTA: reportar CONTAGEM, nao media. A media de phi_wall e\n', ...
         'enganosa: com obstaculos, Reynolds tem media maior que\n', ...
         'OlfatiSaber (0.0044 vs 0.0025) mas viola em 2/20 contra 20/20 --\n', ...
         'a media do Reynolds e inflada por uma unica execucao extrema.\n']);

% McNemar: violacao mudou com o ambiente?
fprintf('\n--- McNemar: violacao (colisao OU parede) mudou de ambiente? ---\n');
fprintf('%-12s %8s %8s %10s\n','algoritmo','so vazia','so obst.','p');
for a = 1:n_alg
    vv = (V.(algos{a}).results(:,4)>0) | (V.(algos{a}).results(:,5)>0);
    vo = (O.(algos{a}).results(:,4)>0) | (O.(algos{a}).results(:,5)>0);
    n10 = sum( vv & ~vo);
    n01 = sum(~vv &  vo);
    if (n01+n10) > 0
        p = min(2*binocdf(min(n01,n10), n01+n10, 0.5), 1);
    else
        p = NaN;
    end
    fprintf('%-12s %8d %8d %10.5f\n', algos{a}, n10, n01, p);
end

%% ============ DISTANCIA MINIMA FISICA ============
fprintf('\n===== DISTANCIA MINIMA ENTRE DRONES (m) =====\n');
fprintf('Convertida de phi_MND: min(dist) = r_coll / phi_MND, r_coll = %.2f m\n', R_COLL);
fprintf('Valor de phi_MND ALTO => drones MAIS PROXIMOS => maior risco.\n\n');
fprintf('%-12s %4s %12s %12s %10s\n', ...
    'algoritmo','par','vazia (m)','obst. (m)','variacao');
for a = 1:n_alg
    dv = R_COLL ./ V.(algos{a}).results(:,6);
    do = R_COLL ./ O.(algos{a}).results(:,6);
    fprintf('%-12s %4d %12.2f %12.2f %+10.2f\n', ...
        algos{a}, nparams(a), mean(dv), mean(do), mean(do)-mean(dv));
end

%% ============ GRAFICO ============
figure('Color','w','Position',[80 80 1000 400]);

subplot(1,2,1); hold on;
mv = zeros(1,n_alg); cv_ = zeros(1,n_alg);
mo = zeros(1,n_alg); co_ = zeros(1,n_alg);
tc = tinv(0.975, n-1);
for a = 1:n_alg
    xv = V.(algos{a}).results(:,2); xo = O.(algos{a}).results(:,2);
    mv(a) = mean(xv); cv_(a) = tc*std(xv)/sqrt(n);
    mo(a) = mean(xo); co_(a) = tc*std(xo)/sqrt(n);
end
b = bar(1:n_alg, [mv; mo]');
b(1).FaceColor = [0.45 0.65 0.80];
b(2).FaceColor = [0.85 0.55 0.40];
errorbar((1:n_alg)-0.15, mv, cv_, 'k','LineStyle','none','LineWidth',1.1);
errorbar((1:n_alg)+0.15, mo, co_, 'k','LineStyle','none','LineWidth',1.1);
set(gca,'XTick',1:n_alg,'XTickLabel', ...
    arrayfun(@(a) sprintf('%s\n(%d)',algos{a},nparams(a)), 1:n_alg, ...
    'UniformOutput',false));
ylabel('\phi_{corr}'); ylim([0 1.05]); grid on; box on;
legend({'arena vazia','com obstaculos'},'Location','southwest');
title('Alinhamento por ambiente (IC 95%)');

subplot(1,2,2); hold on;
viol_v = zeros(1,n_alg); viol_o = zeros(1,n_alg);
for a = 1:n_alg
    viol_v(a) = sum((V.(algos{a}).results(:,4)>0) | (V.(algos{a}).results(:,5)>0));
    viol_o(a) = sum((O.(algos{a}).results(:,4)>0) | (O.(algos{a}).results(:,5)>0));
end
b2 = bar(1:n_alg, [viol_v; viol_o]');
b2(1).FaceColor = [0.45 0.65 0.80];
b2(2).FaceColor = [0.85 0.55 0.40];
set(gca,'XTick',1:n_alg,'XTickLabel', ...
    arrayfun(@(a) sprintf('%s\n(%d)',algos{a},nparams(a)), 1:n_alg, ...
    'UniformOutput',false));
ylabel(sprintf('execucoes com violacao (de %d)', n));
ylim([0 n+1]); grid on; box on;
legend({'arena vazia','com obstaculos'},'Location','northwest');
title('Violacoes de seguranca por ambiente');

sgtitle('Generalizacao: parametros calibrados em arena vazia');

fprintf('\nAnalise concluida.\n');
end


%% ============================================================
function R = carrega(dir_mc, alg, ambiente)
d = dir(sprintf('%s/mc_%s_%s_*.mat', dir_mc, alg, ambiente));
if isempty(d)
    error('Nenhum arquivo para %s no ambiente "%s".', alg, ambiente);
end
[~, i] = max([d.datenum]);
R = load(fullfile(d(i).folder, d(i).name));
fprintf('%-12s [%-10s] <- %s\n', alg, ambiente, d(i).name);
end