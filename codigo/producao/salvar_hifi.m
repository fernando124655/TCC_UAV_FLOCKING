function salvar_hifi(algoritmo, ambiente, seed)
%SALVAR_HIFI  Grava os dados de uma execucao de alta fidelidade.
%
% Nome padronizado e caminho ABSOLUTO -- absoluto porque a execucao roda a
% partir de Simulink_Module, e um caminho relativo gravaria na pasta errada.
%
% NOTA: escrito SEM continuacoes de linha (...) de proposito. Continuacoes
% se perdem ao copiar e colar de texto formatado, e dentro de { } cada
% quebra de linha vira uma nova LINHA da matriz, causando erro de vertcat.
%
% USO:  salvar_hifi('Vasarhelyi', 'vazia', 1)

raiz = 'C:\Users\PCMALOCA\Documents\CoFlyers\matlab_simulink_ws\Prototype_Simulator';
dest = fullfile(raiz, 'data_save', 'high_fidelity');
if ~exist(dest, 'dir'); mkdir(dest); end

vars = {'out','sample_time_base','sample_time_control_bottom','number_real','number','params','map3d_faces','map3d_struct','model_stls','terrain','terrain_params'};

S = struct();
faltando = {};
for k = 1:numel(vars)
    if evalin('base', ['exist(''' vars{k} ''',''var'')']) == 1
        S.(vars{k}) = evalin('base', vars{k});
    else
        faltando{end+1} = vars{k};
    end
end

if ~isfield(S, 'out')
    error('Variavel "out" ausente no workspace. A simulacao chegou ao fim?');
end
if ~isempty(faltando)
    warning('Variaveis ausentes: %s', strjoin(faltando, ', '));
end

nome = fullfile(dest, sprintf('hifi_%s_%s_seed%d.mat', lower(algoritmo), ambiente, seed));
save(nome, '-struct', 'S');

d = dir(nome);
fprintf('\n>>> SALVO: %s (%.1f MB)\n\n', nome, d.bytes/1e6);
end
