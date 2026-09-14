function exportar_producao(dest_base)
%EXPORTAR_PRODUCAO  Gera os graficos de todas as execucoes e organiza os
% arquivos do PC-A para o repositorio.
%
% O QUE FAZ:
%   1. Percorre data_save/high_fidelity, gera o painel de cada execucao
%      (trajetorias + phi_corr + phi_vel) e salva em .fig e .png
%   2. Monta uma tabela CSV com as metricas das 60 execucoes
%   3. Copia os arquivos que devem ir para o repositorio: scripts, XMLs,
%      modulos dos algoritmos, launches e logs
%
% O QUE NAO COPIA: os .mat de dados. Sao grandes e regeneraveis a partir
% do codigo e das sementes documentadas. Se quiser versiona-los, use
% Git LFS.
%
% ENTRADA (opcional):
%   dest_base : pasta de destino
%               (padrao 'C:\Users\PCMALOCA\Downloads\fernando(Pessoais)\simulacao_producao')
%
% USO:  exportar_producao

if nargin < 1 || isempty(dest_base)
    dest_base = 'C:\Users\PCMALOCA\Downloads\fernando(Pessoais)\simulacao_producao';
end

raiz = 'C:\Users\PCMALOCA\Documents\CoFlyers\matlab_simulink_ws\Prototype_Simulator';
dir_hf = fullfile(raiz, 'data_save', 'high_fidelity');

d_graf = fullfile(dest_base, 'graficos');
d_cod  = fullfile(dest_base, 'codigo');
d_xml  = fullfile(dest_base, 'xml_config');
d_mod  = fullfile(dest_base, 'modulos_algoritmos');
d_lau  = fullfile(dest_base, 'pc_b_launches');
d_log  = fullfile(dest_base, 'logs');
d_doc  = fullfile(dest_base, 'docs');
for p = {d_graf, d_cod, d_xml, d_mod, d_lau, d_log, d_doc}
    if ~exist(p{1}, 'dir'); mkdir(p{1}); end
end

%% ============ 1. GRAFICOS ============
arqs = dir(fullfile(dir_hf, 'hifi_*.mat'));
fprintf('=== GERANDO GRAFICOS (%d execucoes) ===\n\n', numel(arqs));

n = numel(arqs);
T = cell(n, 12);
falhas = {};

for i = 1:n
    caminho = fullfile(arqs(i).folder, arqs(i).name);
    [~, nome] = fileparts(arqs(i).name);
    try
        M = extrair_metricas_hifi(caminho, true);

        set(gcf, 'Position', [60 60 1150 470]);
        savefig(gcf, fullfile(d_graf, [nome '.fig']));
        exportgraphics(gcf, fullfile(d_graf, [nome '.png']), 'Resolution', 200);
        close(gcf);

        % decompoe o nome: hifi_<alg>_<amb>_seed<N>
        p = strsplit(nome, '_');
        T(i,:) = {p{2}, p{3}, str2double(erase(p{4},'seed')), M.duracao, ...
                  M.phi_corr, M.phi_vel, M.phi_coll, M.phi_wall, M.phi_MND, ...
                  M.dist_min, M.F, M.forma_obstaculos};
        fprintf('  [%2d/%2d] %s\n', i, n, nome);
    catch ME
        falhas{end+1} = sprintf('%s: %s', nome, ME.message); %#ok<AGROW>
        fprintf('  [%2d/%2d] %s -- FALHOU\n', i, n, nome);
    end
end

if ~isempty(falhas)
    fprintf('\nFALHAS:\n');
    fprintf('  %s\n', falhas{:});
end

%% ============ 2. TABELA DE METRICAS ============
ok = ~cellfun(@isempty, T(:,1));
Tab = cell2table(T(ok,:), 'VariableNames', ...
    {'algoritmo','ambiente','semente','duracao_s','phi_corr','phi_vel', ...
     'phi_coll','phi_wall','phi_MND','dist_min_m','F','forma_obstaculo'});
csv = fullfile(dest_base, 'metricas_high_fidelity.csv');
writetable(Tab, csv);
fprintf('\nTabela: %s (%d linhas)\n', csv, height(Tab));

%% ============ 3. ARQUIVOS PARA O REPOSITORIO ============
fprintf('\n=== COPIANDO ARQUIVOS ===\n');

scripts = {'main_auto_tuning_production.m','main_batch_production.m', ...
    'main_monte_carlo_rapid_prototyping.m','fitness_paired_configs.m', ...
    'prepare_paired_xmls.m','prepare_parallel_safe.m','restore_parallel_safe.m', ...
    'xml_set_param_in_block.m','build_obstacle_xml.m','build_hifi_launches.m', ...
    'preparar_hifi.m','verificar_hifi.m','salvar_hifi.m', ...
    'extrair_metricas_hifi.m','visualizar_hifi.m','exportar_producao.m', ...
    'analyze_monte_carlo.m','analyze_generalization.m','analyze_batch.m', ...
    'analyze_hifi.m','gerar_relatorio_parcial.m'};
copiar(raiz, d_cod, scripts, 'scripts');

xmls = {'parameters.xml','parameters_vazia_BACKUP.xml', ...
        'parameters_obst_cubo.xml','parameters_obst_cilindro.xml'};
copiar(fullfile(raiz,'xml_config_files'), d_xml, xmls, 'XMLs');

% modulos dos algoritmos (so a logica; os *_parameters.m sao gerados)
mods = {'Couzin','Reynolds','OlfatiSaber','Vasarhelyi'};
nm = 0;
for k = 1:numel(mods)
    f = fullfile(raiz,'lower_layers','swarm_module', [mods{k} '_module'], ...
        [mods{k} '_module_generate_desire.m']);
    if exist(f,'file'); copyfile(f, d_mod); nm = nm + 1; end
end
f = fullfile(raiz,'lower_layers','evaluation_module','utils','fitness_function_combine.m');
if exist(f,'file'); copyfile(f, d_mod); nm = nm + 1; end
f = fullfile(raiz,'lower_layers','evaluation_module','evaluation_0_module','evaluation_0_module_average.m');
if exist(f,'file'); copyfile(f, d_mod); nm = nm + 1; end
fprintf('  modulos: %d arquivos\n', nm);

if exist(fullfile(raiz,'hifi_launches'),'dir')
    copyfile(fullfile(raiz,'hifi_launches','*'), d_lau);
    fprintf('  launches: %d arquivos\n', numel(dir(fullfile(d_lau,'*.launch'))));
end

logs = dir(fullfile(raiz, 'log_*.txt'));
for i = 1:numel(logs)
    copyfile(fullfile(logs(i).folder, logs(i).name), d_log);
end
fprintf('  logs: %d arquivos\n', numel(logs));

%% ============ 4. INVENTARIO ============
fid = fopen(fullfile(d_doc,'inventario.txt'), 'w');
fprintf(fid, 'INVENTARIO DA SIMULACAO DE PRODUCAO\n');
fprintf(fid, 'Gerado em %s\n\n', char(datetime('now')));
fprintf(fid, 'MATLAB: %s\n', version);
fprintf(fid, 'Execucoes de alta fidelidade: %d\n\n', height(Tab));
fprintf(fid, 'Por algoritmo e ambiente:\n');
for a = ["Couzin","Reynolds","OlfatiSaber","Vasarhelyi"]
    for e = ["vazia","cubos","cilindros"]
        c = sum(strcmpi(Tab.algoritmo, a) & strcmpi(Tab.ambiente, e));
        fprintf(fid, '  %-13s %-10s %d execucoes\n', a, e, c);
    end
end
fprintf(fid, '\nSEMENTES (fixadas a priori, conjuntos disjuntos):\n');
fprintf(fid, '  treino do auto-tuning : 101, 102, 103\n');
fprintf(fid, '  teste do Monte Carlo  : 1 a 20\n');
fprintf(fid, '  repeticoes do batch   : 201, 202, 203\n');
fprintf(fid, '  multi-start do GA     : 1 a 5\n');
fprintf(fid, '  alta fidelidade       : 1 a 5 (pareadas com o Monte Carlo)\n');
fprintf(fid, '\nNAO INCLUIDO: arquivos .mat de dados brutos (regeneraveis a\n');
fprintf(fid, 'partir do codigo e das sementes). Para versiona-los, use Git LFS.\n');
fclose(fid);

fprintf('\n=== CONCLUIDO ===\n');
fprintf('Destino: %s\n', dest_base);
f = dir(fullfile(dest_base, '**', '*'));
f = f(~[f.isdir]);
fprintf('%d arquivos, %.1f MB\n', numel(f), sum([f.bytes])/1e6);
end


function copiar(origem, destino, lista, rotulo)
n = 0;
for k = 1:numel(lista)
    f = fullfile(origem, lista{k});
    if exist(f, 'file')
        copyfile(f, destino);
        n = n + 1;
    end
end
fprintf('  %s: %d de %d arquivos\n', rotulo, n, numel(lista));
end