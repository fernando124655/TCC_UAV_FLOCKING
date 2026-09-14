function xml_set_param_in_block(xml_path, block_name, tags, values)
% XML_SET_PARAM_IN_BLOCK
% Escreve parametros no XML do CoFlyers RESTRITOS a um bloco de algoritmo.
%
% Motivacao: regexprep aplicado ao arquivo inteiro substitui TODAS as
% ocorrencias de uma tag. Como blocos diferentes compartilham nomes de
% parametros (ex.: r_shill e w_shill existem em <Couzin> e <Reynolds>),
% escrever sem delimitar o bloco contamina os outros algoritmos.
%
% ENTRADAS:
%   xml_path   : caminho do XML (ex.: 'xml_config_files\parameters.xml')
%   block_name : nome do bloco (ex.: 'Reynolds', 'Couzin', 'OlfatiSaber')
%   tags       : cell array com nomes dos parametros
%   values     : vetor numerico com os valores (mesma ordem de tags)
%
% EXEMPLO:
%   xml_set_param_in_block('xml_config_files\parameters.xml', 'Reynolds', ...
%       {'w_sep','w_ali','w_coh','w_shill','r_sep','r_shill'}, ...
%       [4.1013, 2.8086, 1.2974, 0.6871, 4.6921, 5.5857]);

if numel(tags) ~= numel(values)
    error('tags e values devem ter o mesmo numero de elementos.');
end

content = fileread(xml_path);

% Delimita o bloco
i1 = strfind(content, ['<' block_name '>']);
i2 = strfind(content, ['</' block_name '>']);
if isempty(i1) || isempty(i2)
    error('Bloco <%s> nao encontrado em %s.', block_name, xml_path);
end
i1 = i1(1); i2 = i2(1);
if i2 <= i1
    error('Bloco <%s> mal formado (fechamento antes da abertura).', block_name);
end

seg = content(i1:i2-1);   % conteudo do bloco, sem a tag de fechamento

% Substitui cada parametro DENTRO do segmento
for k = 1:numel(tags)
    tag = tags{k};
    % tolerante a espacos: <tag value = "..." />
    pat = ['<' tag '\s*value\s*=\s*"[^"]*"\s*/>'];
    rep = ['<' tag ' value="' num2str(values(k), '%.6f') '"/>'];

    n_match = numel(regexp(seg, pat, 'start'));
    if n_match == 0
        warning('Parametro <%s> nao encontrado no bloco <%s>.', tag, block_name);
        continue
    elseif n_match > 1
        warning('Parametro <%s> aparece %d vezes no bloco <%s>.', ...
            tag, n_match, block_name);
    end
    seg = regexprep(seg, pat, rep);
end

% Reconstroi o arquivo
content = [content(1:i1-1), seg, content(i2:end)];
fid = fopen(xml_path, 'w'); fwrite(fid, content); fclose(fid);

fprintf('Bloco <%s> atualizado em %s (%d parametros).\n', ...
    block_name, xml_path, numel(tags));
end