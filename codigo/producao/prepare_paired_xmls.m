function xml_list = prepare_paired_xmls(algorithm_name, cfg_seeds, d_min, z_init)
% PREPARE_PAIRED_XMLS
% Gera um XML de trabalho por configuracao inicial, para uso como conjunto
% PAREADO de avaliacao no auto-tuning de producao.
%
% Todos os candidatos do GA sao avaliados sobre EXATAMENTE as mesmas
% configuracoes iniciais (uma por XML), o que torna a comparacao entre
% candidatos pareada e a funcao de fitness deterministica.
%
% As configuracoes dependem SO das sementes, nunca do algoritmo -> os
% quatro algoritmos sao otimizados sobre os mesmos cenarios de treino.
%
% ENTRADAS:
%   algorithm_name : 'Couzin' | 'Reynolds' | 'OlfatiSaber' | 'Vasarhelyi'
%   cfg_seeds      : vetor de sementes (padrao [101 102 103] - TREINO,
%                    disjunto das sementes 1..20 usadas no Monte Carlo)
%   d_min          : distancia minima entre drones (padrao 5.0 m)
%   z_init         : altitude inicial (padrao 1.0 m, valor nativo do XML)
%
% SAIDA:
%   xml_list : cell array com os caminhos dos XMLs gerados
%
% Os XMLs gerados sao SOMENTE-LEITURA durante a otimizacao: varios workers
% podem le-los simultaneamente sem conflito.

if nargin < 2 || isempty(cfg_seeds); cfg_seeds = [101 102 103]; end
if nargin < 3 || isempty(d_min);     d_min     = 5.0;           end
if nargin < 4 || isempty(z_init);    z_init    = 1.0;           end

xml_original = 'xml_config_files\parameters.xml';
Nr = numel(cfg_seeds);
xml_list = cell(1, Nr);

% Le arena e numero de drones do XML original
[~, ~, ~, params, position0_default] = read_parameter_xml(xml_original);
N_DRONES = size(position0_default, 2);
x_range  = params.map.x_range(:)';
y_range  = params.map.y_range(:)';

fprintf('Gerando %d XMLs pareados para %s (sementes de treino: %s)\n', ...
    Nr, algorithm_name, mat2str(cfg_seeds));

for i = 1:Nr
    xml_path = sprintf('xml_config_files\\parameters_at_%s_cfg%d.xml', ...
        algorithm_name, i);
    copyfile(xml_original, xml_path);

    % Ativa o algoritmo alvo e desliga a visualizacao
    content = fileread(xml_path);
    content = regexprep(content, ...
        '<swarm_algorithm_type\s*value\s*=\s*"''[^'']+''"\s*/>', ...
        ['<swarm_algorithm_type value="''', algorithm_name, '''"/>']);
    content = regexprep(content, ...
        '<activate_plot\s*value\s*=\s*"1"\s*/>', ...
        '<activate_plot value="0"/>');
    fid = fopen(xml_path, 'w'); fwrite(fid, content); fclose(fid);

    % Gera e escreve a configuracao inicial desta repeticao
    pos = gen_positions(N_DRONES, x_range, y_range, z_init, d_min, cfg_seeds(i));
    write_positions(xml_path, pos);

    % Verificacao: o CoFlyers le o que foi escrito?
    [~, ~, ~, p_chk, pos_chk] = read_parameter_xml(xml_path);
    err = max(abs(pos(:) - pos_chk(:)));
    if err > 1e-5
        error('Falha ao escrever posicoes em %s (erro %.2e).', xml_path, err);
    end
    if ~strcmp(p_chk.swarm_algorithm_type, algorithm_name)
        error('Algoritmo ativo em %s e "%s", esperado "%s".', ...
            xml_path, p_chk.swarm_algorithm_type, algorithm_name);
    end

    xml_list{i} = xml_path;
    fprintf('  cfg%d (seed %3d): %s  [ok]\n', i, cfg_seeds(i), xml_path);
end
end


%% ============================================================
function pos = gen_positions(N, x_range, y_range, z, d_min, seed)
% Identica a usada no Monte Carlo: mesma logica, mesma semente -> mesma
% configuracao. Amostragem com rejeicao para respeitar d_min.
rng(seed, 'twister');
pos = zeros(3, N);
pos(3, :) = z;

margin = d_min;
xlo = x_range(1) + margin; xhi = x_range(2) - margin;
ylo = y_range(1) + margin; yhi = y_range(2) - margin;

max_tries = 100000;
placed = 0; tries = 0;
while placed < N
    tries = tries + 1;
    if tries > max_tries
        error('Nao foi possivel posicionar %d drones com d_min=%.1f m.', N, d_min);
    end
    cx = xlo + (xhi - xlo) * rand();
    cy = ylo + (yhi - ylo) * rand();
    ok = true;
    for j = 1:placed
        if hypot(cx - pos(1,j), cy - pos(2,j)) < d_min
            ok = false; break;
        end
    end
    if ok
        placed = placed + 1;
        pos(1, placed) = cx;
        pos(2, placed) = cy;
    end
end
end

%% ============================================================
function write_positions(xml_path, pos)
% Substitui a PRIMEIRA tag <position__ ... "/> pela matriz numerica.
content = fileread(xml_path);
idx = strfind(content, '<position__');
if isempty(idx)
    error('Tag <position__ nao encontrada em %s', xml_path);
end
s = idx(1);
rest  = content(s:end);
e_rel = strfind(rest, '"/>');
if isempty(e_rel)
    error('Fim da tag <position__ nao encontrado.');
end
e = s + e_rel(1) + 1;

[nr, ~] = size(pos);
rows = cell(1, nr);
for r = 1:nr
    vals = arrayfun(@(x) sprintf('%.6f', x), pos(r,:), 'UniformOutput', false);
    rows{r} = strjoin(vals, ' ');
end
new_tag = ['<position__ value="[', strjoin(rows, '; '), ']"/>'];

content = [content(1:s-1), new_tag, content(e+1:end)];
fid = fopen(xml_path, 'w'); fwrite(fid, content); fclose(fid);
end
