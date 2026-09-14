function preparar_hifi(algoritmo, ambiente)
%PREPARAR_HIFI  Configura o parameters.xml para um bloco de alta fidelidade.
%
% Copia o XML do ambiente escolhido sobre parameters.xml, ativa o algoritmo
% e roda a verificacao pre-voo.
%
% Escrito SEM continuacoes de linha (...), que se perdem no copiar-e-colar.
%
% ENTRADAS:
%   algoritmo : 'Couzin' | 'Reynolds' | 'OlfatiSaber' | 'Vasarhelyi'
%   ambiente  : 'vazia' | 'cubos' | 'cilindros'
%
% USO:  preparar_hifi('Vasarhelyi', 'cilindros')

d = 'xml_config_files\';

switch lower(ambiente)
    case 'vazia'
        origem = [d 'parameters_vazia_BACKUP.xml'];
    case 'cubos'
        origem = [d 'parameters_obst_cubo.xml'];
    case 'cilindros'
        origem = [d 'parameters_obst_cilindro.xml'];
    otherwise
        error('ambiente deve ser ''vazia'', ''cubos'' ou ''cilindros''.');
end

if ~exist(origem, 'file')
    error('XML de origem ausente: %s', origem);
end

copyfile(origem, [d 'parameters.xml']);

c = fileread([d 'parameters.xml']);
c = regexprep(c, '<swarm_algorithm_type\s*value\s*=\s*"''[^'']+''"\s*/>', ['<swarm_algorithm_type value="''' algoritmo '''"/>']);
fid = fopen([d 'parameters.xml'], 'w'); fwrite(fid, c); fclose(fid);

fprintf('XML preparado a partir de %s\n', origem);
verificar_hifi(algoritmo, ambiente);
end
