function prepare_parallel_safe(xml_list)
% PREPARE_PARALLEL_SAFE
% Prepara o ambiente para o auto-tuning paralelo, eliminando a corrida de
% I/O na geracao dos arquivos de despacho.
%
% ESTRATEGIA (warm-up puro, sem lock):
% As guardas de timestamp em read_parameter_xml.m (blocos "if exist(
% file_fullpath) ... if ctime_file > ctime_xml, return") foram ATIVADAS.
% Com elas, o read_parameter_xml so reescreve os arquivos de logica se eles
% forem MAIS ANTIGOS que o XML. Este warm-up gera esses arquivos no CLIENTE,
% com timestamp atual (posterior ao XML), ANTES do parfor. Quando os workers
% rodarem, encontrarao os arquivos atualizados e pularao a reescrita -- sem
% escrita concorrente, sem corrida.
%
% NAO ha lock de arquivos: as guardas tornam o lock desnecessario, e um lock
% causaria falha de fopen('w') caso alguma guarda liberasse a reescrita.
%
% Chame uma vez, no cliente, depois de prepare_paired_xmls e ANTES de abrir
% o pool paralelo.
%
% ENTRADA:
%   xml_list : cell array de XMLs de trabalho (os mesmos do auto-tuning)

fprintf('Warm-up: gerando arquivos de logica no cliente...\n');

for i = 1:numel(xml_list)
    read_parameter_xml(xml_list{i});
end

fprintf('  %d XML(s) processado(s). Arquivos de despacho atualizados.\n', numel(xml_list));
fprintf(['  As guardas de timestamp faram os workers pularem a reescrita ', ...
         '(sem corrida de I/O).\n']);
end
