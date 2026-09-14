function restore_parallel_safe()
% RESTORE_PARALLEL_SAFE
% Desfaz o lock aplicado por prepare_parallel_safe: devolve a permissao de
% escrita aos arquivos de despacho, para que o CoFlyers volte a operar
% normalmente (rapid prototyping, batch, high-fidelity etc. precisam poder
% regenerar esses arquivos ao trocar de algoritmo).
%
% Chame ao FINAL do auto-tuning, ou sempre que precisar rodar o CoFlyers
% normalmente depois de um auto-tuning paralelo.

path_sim = mfilename('fullpath');
ind = strfind(path_sim, 'Prototype_Simulator') + length('Prototype_Simulator');
path_sim = path_sim(1:ind);

locked_files = {
    fullfile(path_sim, 'lower_layers', 'swarm_module', 'swarm_module_generate_desire.m')
    fullfile(path_sim, 'lower_layers', 'evaluation_module', 'evaluation_module_one.m')
    fullfile(path_sim, 'lower_layers', 'evaluation_module', 'evaluation_module_average.m')
};

n = 0;
for k = 1:numel(locked_files)
    f = locked_files{k};
    if exist(f, 'file')
        fileattrib(f, '+w');
        n = n + 1;
    end
end
fprintf('restore_parallel_safe: %d arquivos com escrita restaurada.\n', n);
end
