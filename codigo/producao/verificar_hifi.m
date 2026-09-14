function verificar_hifi(algoritmo_esperado, ambiente_esperado)
% VERIFICAR_HIFI
% Checagem pre-voo da configuracao do PC-A antes de um bloco de execucoes
% de alta fidelidade.
%
% MOTIVACAO: cada sessao exige seis coisas simultaneamente corretas, e
% errar qualquer uma invalida as cinco execucoes do bloco -- sem que os
% dados salvos deem qualquer indicio do erro. O caso mais grave e o mapa:
% se o XML for o da arena vazia e o mundo Gazebo tiver cubos, os drones
% voam contra obstaculos invisiveis, exatamente o problema encontrado nos
% dados de alta fidelidade da fase de validacao.
%
% ENTRADAS:
%   algoritmo_esperado : 'Couzin' | 'Reynolds' | 'OlfatiSaber' | 'Vasarhelyi'
%   ambiente_esperado  : 'vazia' | 'cubos'
%
% USO:  verificar_hifi('Couzin', 'cubos')

if nargin < 2
    error('Uso: verificar_hifi(''Couzin'', ''cubos'')');
end

xml = 'xml_config_files\parameters.xml';
fprintf('\n================================================================\n');
fprintf(' VERIFICACAO PRE-VOO -- %s / %s\n', algoritmo_esperado, ambiente_esperado);
fprintf('================================================================\n\n');

[~, ms, ~, p] = read_parameter_xml(xml);
ok = true;

% 1. algoritmo ativo
v = strcmp(p.swarm_algorithm_type, algoritmo_esperado);
ok = ok && v;
fprintf('[%s] algoritmo ativo: %s\n', marca(v), p.swarm_algorithm_type);

% 2. mapa (numero de objetos revela se ha obstaculos)
n_obj = size(ms, 2);
tem_obst = n_obj > 6;
esperado_obst = ismember(lower(ambiente_esperado), {'cubos','cilindros'});
v = (tem_obst == esperado_obst);
ok = ok && v;
if tem_obst
    fprintf('[%s] mapa: %d objetos (4 paredes + piso + teto + %d obstaculos)\n', ...
        marca(v), n_obj, n_obj-6);
else
    fprintf('[%s] mapa: %d objetos (arena vazia)\n', marca(v), n_obj);
end
if ~v
    fprintf('     >>> copie o XML correto sobre parameters.xml:\n');
    switch lower(ambiente_esperado)
        case 'cubos'
            fprintf('     >>> copy xml_config_files\\parameters_obst_cubo.xml %s\n', xml);
        case 'cilindros'
            fprintf('     >>> copy xml_config_files\\parameters_obst_cilindro.xml %s\n', xml);
        otherwise
            fprintf('     >>> restaure parameters_vazia_BACKUP.xml\n');
    end
end

% 3. shill agents gerados
ps = p.swarm.(algoritmo_esperado).pos_shill;
borda = (abs(abs(ps(1,:))-30) < 1) | (abs(abs(ps(2,:))-30) < 1);
n_int = sum(~borda);
v = (n_int > 0) == esperado_obst;
ok = ok && v;
fprintf('[%s] shill agents: %d total, %d internos\n', ...
    marca(v), size(ps,2), n_int);

% 4. modo de simulacao
v = isfield(p, 'sim_quad') && p.sim_quad == 0;
if ~isfield(p, 'sim_quad')
    c = fileread(xml);
    v = contains(c, '<sim_quad value="0"/>');
end
ok = ok && v;
fprintf('[%s] sim_quad = 0 (alta fidelidade)\n', marca(v));
if ~v
    fprintf('     >>> ajuste <sim_quad value="0"/> no XML\n');
end

% 5. enderecamento de rede
c = fileread(xml);
tok = regexp(c, '<local_ip value="''([^'']+)''"/>', 'tokens', 'once');
lip = ''; if ~isempty(tok); lip = tok{1}; end
v = contains(lip, '192.168.1.155');
ok = ok && v;
fprintf('[%s] local_ip (PC-A): %s\n', marca(v), lip);

v = contains(c, '*157');
ok = ok && v;
fprintf('[%s] target_ip (PC-B): %s\n', marca(v), ...
    ternario(v, 'aponta para 157', 'NAO aponta para 157'));

% 6. parametros otimizados aplicados
otimos = struct( ...
  'Couzin',      struct('campos', {{'r_r','r_o','r_a','r_shill','w_shill'}}, ...
                        'vals', [2.575509 24.755188 31.764138 1.528322 0.231689]), ...
  'Reynolds',    struct('campos', {{'w_sep','w_ali','w_coh','w_shill','r_sep','r_shill'}}, ...
                        'vals', [7.062978 9.965462 0.117671 0.202745 14.972985 6.129293]), ...
  'OlfatiSaber', struct('campos', {{'d_ref','c_vm','a_coeff','b_coeff','c_arena','d_arena','r_com'}}, ...
                        'vals', [8.241152 17.122448 3.978261 6.820284 6.037115 11.223216 16.305144]), ...
  'Vasarhelyi',  struct('campos', {{'r_rep_0','p_rep','r_frict_0','c_frict','v_frict', ...
                                    'p_frict','a_frict','r_shill_0','v_shill','p_shill','a_shill'}}, ...
                        'vals', [5.740999 0.484115 19.084570 0.389118 0.048157 6.169780 ...
                                 1.550353 1.210154 2.014933 3.152230 0.967394]));

if isfield(otimos, algoritmo_esperado)
    E = otimos.(algoritmo_esperado);
    difs = {};
    for k = 1:numel(E.campos)
        atual = p.swarm.(algoritmo_esperado).(E.campos{k});
        if abs(atual - E.vals(k)) > 1e-4
            difs{end+1} = sprintf('%s: %.4f (esperado %.4f)', ...
                E.campos{k}, atual, E.vals(k)); %#ok<AGROW>
        end
    end
    v = isempty(difs);
    ok = ok && v;
    fprintf('[%s] parametros otimizados (%d verificados)\n', marca(v), numel(E.campos));
    for k = 1:numel(difs)
        fprintf('     >>> %s\n', difs{k});
    end
end

% 7. numero de drones
v = p.number == 10;
ok = ok && v;
fprintf('[%s] numero de drones: %d\n', marca(v), p.number);

fprintf('\n----------------------------------------------------------------\n');
if ok
    fprintf(' RESULTADO: CONFIGURACAO OK -- pode iniciar as execucoes.\n\n');
    fprintf(' No PC-B, lance (uma semente por execucao):\n');
    for s = 1:5
        fprintf('   roslaunch px4 hifi_%s_seed%d.launch\n', ambiente_esperado, s);
    end
    fprintf('\n Sequencia: Arming -> Takeoff -> Alg (250 s) -> Hover -> Land -> Stop\n');
    fprintf(' Ao parar, SALVE ANTES de plotar (o script de plot tem clear):\n');
    fprintf('   save(''data_save\\hifi_%s_%s_seedN.mat'', ''out'', ...\n', ...
        lower(algoritmo_esperado), ambiente_esperado);
    fprintf('        ''sample_time_base'', ''sample_time_control_bottom'', ...\n');
    fprintf('        ''number_real'', ''number'', ''params'', ''map3d_faces'', ...\n');
    fprintf('        ''map3d_struct'', ''model_stls'', ''terrain'', ''terrain_params'');\n');
else
    fprintf(' RESULTADO: HA PENDENCIAS -- corrija antes de iniciar.\n');
end
fprintf('----------------------------------------------------------------\n\n');
end

function s = marca(v)
if v; s = ' OK '; else; s = 'FALHA'; end
end

function s = ternario(c, a, b)
if c; s = a; else; s = b; end
end
