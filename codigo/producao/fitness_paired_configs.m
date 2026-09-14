function F = fitness_paired_configs(x, param_name_s, xml_list, rng_base, txt_base)
% FITNESS_PAIRED_CONFIGS
% Funcao objetivo do auto-tuning de producao.
%
% Avalia o candidato x sobre TODAS as configuracoes iniciais de xml_list
% (as mesmas para todo candidato -> avaliacao pareada) e retorna a media
% do fitness F (primeiro elemento do vetor de metricas).
%
% DETERMINISMO: cada repeticao fixa rng(rng_base+i) antes de simular, o que
% torna reprodutivel a perturbacao nativa das velocidades iniciais
% (rand em initialize_states). Com posicoes fixas nos XMLs e ruido zero, a
% funcao passa a ser deterministica dado x -- condicao necessaria para que
% rng(seed) no cliente controle integralmente a estocasticidade do GA,
% inclusive com UseParallel.
%
% ENTRADAS:
%   x            : vetor de parametros candidato
%   param_name_s : string array com os nomes completos dos parametros
%   xml_list     : cell array de XMLs (um por configuracao inicial)
%   rng_base     : base das sementes internas (padrao 1000)
%   txt_base     : prefixo do arquivo de log (opcional; um por worker)
%
% SAIDA:
%   F : fitness medio (a ser MINIMIZADO pelo GA)

if nargin < 4 || isempty(rng_base); rng_base = 1000; end
if nargin < 5; txt_base = ''; end

Nr = numel(xml_list);
vals = zeros(6, Nr);

% Estrutura de sobrescrita de parametros (mesmo formato do run_auto_tuning)
ps = struct("param_name_s", param_name_s, ...
            "param_value_s", {arrayfun(@(v) string(v), x)});

for i = 1:Nr
    rng(rng_base + i, 'twister');
    v = model_swarm([], ps, [], i, 1, xml_list{i}, []);
    vals(:, i) = v(:);
end

v_mean = mean(vals, 2);
F = v_mean(1);   % elemento 1 = fitness da Eq. 6

%% Log por worker (evita condicao de corrida: um arquivo por worker)
if ~isempty(txt_base)
    tk = getCurrentTask();
    wid = 1;
    if ~isempty(tk); wid = tk.ID; end
    fname = sprintf('%s_w%d.txt', txt_base, wid);

    first = isempty(dir(fname));
    fid = fopen(fname, 'a');
    if fid > 0
        if first
            for k = 1:numel(param_name_s)
                fprintf(fid, '%s\t', param_name_s{k});
            end
            fprintf(fid, 'F\tphi_corr\tphi_vel\tphi_coll\tphi_wall\tphi_MND\n');
        end
        for k = 1:numel(x)
            fprintf(fid, '%.6f\t', x(k));
        end
        fprintf(fid, '%.6f\t%.6f\t%.6f\t%.6g\t%.6g\t%.6f\n', ...
            v_mean(1), v_mean(2), v_mean(3), v_mean(4), v_mean(5), v_mean(6));
        fclose(fid);
    end
end
end
