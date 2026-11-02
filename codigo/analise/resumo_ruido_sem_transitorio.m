function T = resumo_ruido_sem_transitorio(pasta, arq_csv)
%RESUMO_RUIDO_SEM_TRANSITORIO  Resume os rsjan_*.mat de main_ruido_sem_transitorio.
%
%   resumo_ruido_sem_transitorio
%   T = resumo_ruido_sem_transitorio('data_save\ruido_sem_transitorio', 'resumo.csv')
%
% Para cada algoritmo e nivel de ruido, conta as execucoes (de 90, somadas
% as tres arenas) com cada tipo de violacao, na execucao inteira e sem os
% T_SKIP segundos iniciais, e mostra o phi_wall e o phi_corr medios. Sao os
% numeros que o artigo usa na secao 5.2.2. Com o segundo argumento, grava a
% tabela por algoritmo, arena e ruido num CSV.
%
% Escrito para o TCC de Fernando Souza Rodrigues (28/10/2026).

if nargin < 1 || isempty(pasta)
    pasta = fullfile('data_save', 'ruido_sem_transitorio');
end
d = dir(fullfile(pasta, 'rsjan_*.mat'));
if isempty(d)
    error('Nenhum rsjan_*.mat em %s.', pasta);
end

linhas = {};
for k = 1:numel(d)
    S = load(fullfile(d(k).folder, d(k).name));
    janelas = {'inteira', S.res_completa; sprintf('sem_%gs', S.T_SKIP), S.res};
    for j = 1:2
        R = janelas{j, 2};
        for eta = unique(S.eta_sel(:)).'
            sel = S.eta_sel(:) == eta;
            M = reshape(permute(R(sel, :, :), [1 3 2]), [], size(R, 2));
            linhas(end+1, :) = {char(S.alg), char(S.arena), eta, janelas{j, 1}, size(M, 1), ...
                sum(M(:, 4) > 0), sum(M(:, 5) > 0), sum(M(:, 7) > 0), sum(M(:, 8) > 0), ...
                sum(M(:, 9) > 0), sum(M(:, 10) > 0), mean(M(:, 5)), mean(M(:, 2)), ...
                min(M(:, 12)), S.reproduz}; %#ok<AGROW>
        end
    end
end
T = cell2table(linhas, 'VariableNames', {'algoritmo', 'arena', 'eta', 'janela', 'execucoes', ...
    'colisao', 'phi_wall', 'parede', 'piso_teto', 'obstaculo', 'dentro', ...
    'phi_wall_medio', 'phi_corr_medio', 'dmin_arena', 'reproduz_antigo'});

algs = unique(T.algoritmo, 'stable');
fprintf('\nExecucoes com violacao, somadas as tres arenas (inteira -> sem o transitorio)\n');
for a = 1:numel(algs)
    fprintf('\n%s\n', algs{a});
    fprintf('   eta  exec   colisao    parede  piso/teto   obstac    dentro   phi_wall medio        phi_corr medio\n');
    Ta = T(strcmp(T.algoritmo, algs{a}), :);
    for eta = unique(Ta.eta).'
        I = Ta(Ta.eta == eta & strcmp(Ta.janela, 'inteira'), :);
        J = Ta(Ta.eta == eta & ~strcmp(Ta.janela, 'inteira'), :);
        n = sum(I.execucoes);
        fprintf('  %4.2f  %4d  %3d->%-3d  %3d->%-3d  %3d->%-3d  %3d->%-3d  %3d->%-3d   %.5f->%.5f   %.4f->%.4f\n', ...
            eta, n, sum(I.colisao), sum(J.colisao), sum(I.parede), sum(J.parede), ...
            sum(I.piso_teto), sum(J.piso_teto), sum(I.obstaculo), sum(J.obstaculo), ...
            sum(I.dentro), sum(J.dentro), ...
            sum(I.phi_wall_medio .* I.execucoes)/n, sum(J.phi_wall_medio .* J.execucoes)/n, ...
            sum(I.phi_corr_medio .* I.execucoes)/n, sum(J.phi_corr_medio .* J.execucoes)/n);
    end
end
if ~all(T.reproduz_antigo)
    fprintf(['\nATENCAO: em %s, a execucao inteira nao reproduziu o arquivo antigo; ' ...
        'as contagens sao de outras realizacoes do mesmo desenho.\n'], ...
        strjoin(unique(strcat(T.algoritmo(~T.reproduz_antigo), '/', T.arena(~T.reproduz_antigo))), ', '));
end

if nargin >= 2 && ~isempty(arq_csv)
    writetable(T, arq_csv);
    fprintf('\nTabela gravada em %s\n', arq_csv);
end
end
