function analyze_batch()
% ANALYZE_BATCH
% Analise dos dados de batch processing: robustez a perturbacoes do sistema
% de controle e sensoriamento.
%
% O QUE MEDE: como o desempenho degrada ao variar o tempo de amostragem do
% controle (Tc) e o ruido de velocidade (eta), sobre uma grade 26x26.
% E a segunda fonte de evidencia para a H1-B (complexidade vs robustez);
% a primeira e a analise de generalizacao entre ambientes.
%
% METRICAS DE ROBUSTEZ:
%   1. Amplitude       : max - min de phi_corr na grade. Simples, mas
%                        sensivel a valores extremos nos cantos.
%   2. Sensibilidade   : coeficientes de um ajuste linear
%                        phi_corr ~ b0 + b_tc*Tc + b_eta*eta.
%                        Reportados como QUEDA TOTAL ao longo de cada eixo,
%                        o que torna os dois diretamente comparaveis apesar
%                        das unidades diferentes.
%   3. Regiao operacional : fracao da grade em que phi_corr se mantem acima
%                        de 90% do melhor valor do proprio algoritmo.
%   4. Violacoes       : fracao da grade com phi_coll > 0 ou phi_wall > 0,
%                        estendendo o perfil de falha a dimensao de
%                        perturbacao.
%
% USO:  analyze_batch

clc;
algos   = {'Couzin','Reynolds','OlfatiSaber','Vasarhelyi'};
nparams = [5, 6, 7, 11];
n_alg   = numel(algos);
ambientes = {'vazia','cubos'};
rot_amb   = {'arena vazia','com cubos'};

D = struct();
for e = 1:2
    for a = 1:n_alg
        d = dir(sprintf('data_save/batch_production/bp_%s_%s_*.mat', ...
            algos{a}, ambientes{e}));
        % descarta arquivos de teste (grade reduzida)
        ok = [];
        for i = 1:numel(d)
            S = load(fullfile(d(i).folder, d(i).name), 'res_mean');
            if isfield(S,'res_mean') && size(S.res_mean,1) > 100
                ok(end+1) = i; %#ok<AGROW>
            end
        end
        if isempty(ok)
            fprintf('AUSENTE: %s / %s\n', algos{a}, ambientes{e});
            continue;
        end
        [~, k] = max([d(ok).datenum]);
        i = ok(k);
        D.(ambientes{e}).(algos{a}) = load(fullfile(d(i).folder, d(i).name));
        fprintf('%-12s [%-6s] <- %s\n', algos{a}, ambientes{e}, d(i).name);
    end
end

%% ============ POR AMBIENTE ============
sens_tc  = nan(n_alg, 2);
sens_eta = nan(n_alg, 2);
amplit   = nan(n_alg, 2);

for e = 1:2
    if ~isfield(D, ambientes{e}); continue; end
    fprintf('\n================================================================\n');
    fprintf(' AMBIENTE: %s\n', upper(rot_amb{e}));
    fprintf('================================================================\n\n');

    fprintf('--- Robustez de phi_corr na grade (Tc, eta) ---\n');
    fprintf('%-13s %4s %8s %8s %10s %11s %11s %9s\n', ...
        'algoritmo','par','min','max','amplitude','queda p/Tc','queda p/eta','reg.op.');
    fprintf('%s\n', repmat('-',1,82));

    for a = 1:n_alg
        if ~isfield(D.(ambientes{e}), algos{a}); continue; end
        S = D.(ambientes{e}).(algos{a});
        y  = S.res_mean(:,2);
        tc = S.TC(:);
        et = S.ETA(:);

        amplit(a,e) = max(y) - min(y);

        % ajuste linear: quanto phi_corr cai ao percorrer cada eixo inteiro
        X = [ones(numel(y),1), tc, et];
        b = X \ y;
        sens_tc(a,e)  = -b(2) * (max(tc) - min(tc));
        sens_eta(a,e) = -b(3) * (max(et) - min(et));

        % regiao operacional: acima de 90% do melhor valor do proprio algoritmo
        lim = 0.90 * max(y);
        frac_op = 100 * mean(y >= lim);

        fprintf('%-13s %4d %8.4f %8.4f %10.4f %11.4f %11.4f %8.0f%%\n', ...
            algos{a}, nparams(a), min(y), max(y), amplit(a,e), ...
            sens_tc(a,e), sens_eta(a,e), frac_op);
    end

    fprintf('\n  amplitude   : max - min de phi_corr na grade\n');
    fprintf('  queda p/Tc  : reducao de phi_corr ao ir de Tc=%.2f a Tc=%.2f s\n', ...
        min(D.(ambientes{e}).(algos{1}).tc_vals), ...
        max(D.(ambientes{e}).(algos{1}).tc_vals));
    fprintf('  queda p/eta : reducao ao ir de eta=%.2f a eta=%.2f m/s\n', ...
        min(D.(ambientes{e}).(algos{1}).eta_vals), ...
        max(D.(ambientes{e}).(algos{1}).eta_vals));
    fprintf('  reg.op.     : %% da grade com phi_corr >= 90%% do melhor do algoritmo\n');

    % --- violacoes de seguranca na grade ---
    fprintf('\n--- Violacoes de seguranca na grade (%% de %d combinacoes) ---\n', ...
        size(D.(ambientes{e}).(algos{1}).res_mean, 1));
    fprintf('%-13s %4s %14s %14s\n','algoritmo','par','colisao','parede');
    fprintf('%s\n', repmat('-',1,50));
    for a = 1:n_alg
        if ~isfield(D.(ambientes{e}), algos{a}); continue; end
        S = D.(ambientes{e}).(algos{a});
        pc = 100*mean(S.res_mean(:,4) > 0);
        pw = 100*mean(S.res_mean(:,5) > 0);
        fprintf('%-13s %4d %13.1f%% %13.1f%%\n', algos{a}, nparams(a), pc, pw);
    end

    % --- variabilidade entre repeticoes ---
    fprintf('\n--- Variabilidade entre as 3 repeticoes (desv.pad. medio) ---\n');
    fprintf('%-13s %12s %12s\n','algoritmo','phi_corr','phi_vel');
    fprintf('%s\n', repmat('-',1,40));
    for a = 1:n_alg
        if ~isfield(D.(ambientes{e}), algos{a}); continue; end
        S = D.(ambientes{e}).(algos{a});
        fprintf('%-13s %12.5f %12.5f\n', algos{a}, ...
            mean(S.res_std(:,2),'omitnan'), mean(S.res_std(:,3),'omitnan'));
    end
end

%% ============ H1-B ============
fprintf('\n================================================================\n');
fprintf(' H1-B: COMPLEXIDADE PARAMETRICA vs ROBUSTEZ A PERTURBACAO\n');
fprintf('================================================================\n\n');

for e = 1:2
    if all(isnan(amplit(:,e))); continue; end
    v = ~isnan(amplit(:,e));
    fprintf('%s:\n', rot_amb{e});
    fprintf('  Spearman (parametros x amplitude)      : rho = %+.2f\n', ...
        corr(nparams(v)', amplit(v,e), 'type','Spearman'));
    fprintf('  Spearman (parametros x sensib. a Tc)   : rho = %+.2f\n', ...
        corr(nparams(v)', sens_tc(v,e), 'type','Spearman'));
    fprintf('  Spearman (parametros x sensib. a ruido): rho = %+.2f\n\n', ...
        corr(nparams(v)', sens_eta(v,e), 'type','Spearman'));
end

fprintf('ATENCAO: n = 4 nao permite inferencia estatistica. Para n = 4, a\n');
fprintf('significancia a 5%% exigiria |rho| = 1.00. Valores DESCRITIVOS,\n');
fprintf('a serem interpretados como tendencia, nao como teste.\n\n');

fprintf('Ranking de robustez por amplitude (menor = mais robusto):\n');
for e = 1:2
    if all(isnan(amplit(:,e))); continue; end
    [~, ord] = sort(amplit(:,e));
    ord = ord(~isnan(amplit(ord,e)));
    fprintf('  %-12s: ', rot_amb{e});
    for k = 1:numel(ord)
        fprintf('%s (%.3f)  ', algos{ord(k)}, amplit(ord(k),e));
    end
    fprintf('\n');
end

%% ============ FIGURAS ============
for e = 1:2
    if ~isfield(D, ambientes{e}); continue; end
    figure('Color','w','Position',[60 60 1100 700]);
    for a = 1:n_alg
        if ~isfield(D.(ambientes{e}), algos{a}); continue; end
        S = D.(ambientes{e}).(algos{a});
        Z = reshape(S.res_mean(:,2), size(S.ETA));
        subplot(2,2,a);
        surf(S.TC, S.ETA, Z, 'EdgeAlpha', 0.2);
        xlabel('T_c (s)'); ylabel('\eta (m/s)'); zlabel('\phi_{corr}');
        title(sprintf('%s (%d par.)', algos{a}, nparams(a)));
        zlim([0 1]); caxis([0 1]); view([-40 30]); colorbar;
        set(gca,'FontName','Times New Roman','FontSize',10);
    end
    sgtitle(sprintf('Robustez a T_c e \\eta - %s', rot_amb{e}));
    saveas(gcf, sprintf('batch_superficies_%s.png', ambientes{e}));
end

% comparacao direta das sensibilidades
figure('Color','w','Position',[80 80 900 380]);
subplot(1,2,1);
bar(1:n_alg, sens_tc);
set(gca,'XTick',1:n_alg,'XTickLabel', arrayfun(@(a) ...
    sprintf('%s\n(%d)',algos{a},nparams(a)),1:n_alg,'UniformOutput',false));
ylabel('queda de \phi_{corr}'); grid on; box on;
legend(rot_amb,'Location','northwest');
title('Sensibilidade ao tempo de amostragem');

subplot(1,2,2);
bar(1:n_alg, sens_eta);
set(gca,'XTick',1:n_alg,'XTickLabel', arrayfun(@(a) ...
    sprintf('%s\n(%d)',algos{a},nparams(a)),1:n_alg,'UniformOutput',false));
ylabel('queda de \phi_{corr}'); grid on; box on;
legend(rot_amb,'Location','northwest');
title('Sensibilidade ao ruido de velocidade');
saveas(gcf, 'batch_sensibilidades.png');

fprintf('\nFiguras salvas: batch_superficies_*.png e batch_sensibilidades.png\n');
end
