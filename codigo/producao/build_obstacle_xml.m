function raio_efetivo = build_obstacle_xml(forma, dimensao, posicoes, rotacao_deg, xml_saida)
% BUILD_OBSTACLE_XML
% Gera um XML identico ao parameters.xml (mesma arena, mesmos blocos de
% algoritmo calibrados) acrescido de obstaculos internos.
%
% A unica diferenca entre o ambiente vazio e o obstruido sao os obstaculos
% -- requisito para que o teste de generalizacao isole essa variavel.
%
% ENTRADAS (todas opcionais):
%   forma      : 'cubo' (padrao) ou 'cilindro'
%   dimensao   : lado do cubo ou diametro do cilindro, em metros (padrao 6)
%   posicoes   : matriz 2xM com [x; y] de cada obstaculo
%                (padrao: 4 obstaculos em (+-12, +-12))
%   rotacao_deg: rotacao em torno de z, em graus (padrao 0).
%                45 graus apresenta as quinas do cubo ao escoamento,
%                cenario mais severo.
%   xml_saida  : caminho do arquivo gerado
%
% SAIDA:
%   raio_efetivo : raio circunscrito, para uso na rejeicao de posicoes
%                  iniciais do Monte Carlo. Cubo: lado/sqrt(2).
%                  Cilindro: diametro/2.
%
% JUSTIFICATIVA DA FORMA (cubo como padrao):
%   - Precedente na literatura: SwarmLab (Soria et al., 2020) compara
%     Olfati-Saber e Vasarhelyi atravessando um campo de 14 obstaculos
%     PARALELEPIPEDOS. E o precedente metodologico mais direto desta
%     pesquisa -- mesma comparacao, mesma classe de plataforma.
%   - Cenario mais severo que o circular: numa face plana, aproximacao
%     perpendicular gera repulsao pura, sem componente tangencial que
%     guie o contorno; numa superficie curva ha sempre guia lateral.
%     Alem disso, quinas concentram shill agents, produzindo picos
%     locais de forca.
%
% NOTA SOBRE COMPARABILIDADE: mantendo lado = diametro, a largura dos
% corredores e IDENTICA entre as duas formas (fator dominante da
% dificuldade). A area ocupada difere: cubo de lado 6 tem 36 m2 contra
% 28.3 m2 do cilindro de diametro 6 (27% maior). Declarar.

if nargin < 1 || isempty(forma);       forma = 'cubo';    end
if nargin < 2 || isempty(dimensao);    dimensao = 6.0;    end
if nargin < 3 || isempty(posicoes)
    posicoes = [-12 -12  12  12;
                -12  12 -12  12];
end
if nargin < 4 || isempty(rotacao_deg); rotacao_deg = 0;   end
if nargin < 5 || isempty(xml_saida)
    xml_saida = sprintf('xml_config_files\\parameters_obst_%s.xml', forma);
end

switch lower(forma)
    case 'cubo'
        stl = 'cube.stl';
        raio_efetivo = dimensao / sqrt(2);      % circunscrito
        area_unit    = dimensao^2;
    case 'cilindro'
        stl = 'cylinder_rough.stl';
        raio_efetivo = dimensao / 2;
        area_unit    = pi * (dimensao/2)^2;
    otherwise
        error('forma deve ser ''cubo'' ou ''cilindro''.');
end

xml_base = 'xml_config_files\parameters.xml';
Z_CENTRO = 1.0;
Z_ESCALA = 2.5;     % cobre z em [-0.25, 2.25], toda a faixa util da arena

%% Verifica se o STL e unitario (a escala vira dimensao fisica direta)
d_stl = dir(fullfile('**', stl));
if ~isempty(d_stl)
    try
        TR = stlread(fullfile(d_stl(1).folder, d_stl(1).name));
        P = TR.Points;
        ex = max(P(:,1))-min(P(:,1));
        ey = max(P(:,2))-min(P(:,2));
        fprintf('%s: extensao base X=%.3f Y=%.3f\n', stl, ex, ey);
        if abs(ex-1) > 0.05 || abs(ey-1) > 0.05
            warning(['%s NAO e unitario. A escala nao correspondera ', ...
                     'diretamente a dimensao fisica.'], stl);
        end
    catch
        fprintf('(nao foi possivel ler %s para verificar escala)\n', stl);
    end
end

copyfile(xml_base, xml_saida);
content = fileread(xml_saida);

%% Monta os blocos <model>
M = size(posicoes, 2);
blocos = '';
for k = 1:M
    blocos = [blocos, sprintf([ ...
        '\n<model>\n', ...
        '<stl value="%s"/>\n', ...
        '<position value="[[%.3f;%.3f;%.3f;]]"/>\n', ...
        '<rotation value="[[0.000;0.000;%.3f;]]"/>\n', ...
        '<scale value="[[%.3f;%.3f;%.3f;]]"/>\n', ...
        '<color value="[[0.400;0.400;0.400;]]"/>\n', ...
        '<alpha value="[[0.800;]]"/>\n', ...
        '<static value="[[1;]]"/>\n', ...
        '<id value="[[-1;]]"/>\n', ...
        '</model>\n'], ...
        stl, posicoes(1,k), posicoes(2,k), Z_CENTRO, ...
        rotacao_deg * pi/180, ...
        dimensao, dimensao, Z_ESCALA)]; %#ok<AGROW>
end

i_fim = strfind(content, '</map>');
if isempty(i_fim)
    error('Tag </map> nao encontrada em %s', xml_base);
end
i_fim = i_fim(1);
content = [content(1:i_fim-1), blocos, content(i_fim:end)];

fid = fopen(xml_saida, 'w'); fwrite(fid, content); fclose(fid);

fprintf('\nGerado: %s\n', xml_saida);
fprintf('  %d %s(s), dimensao %.1f m, rotacao %.0f graus\n', ...
    M, forma, dimensao, rotacao_deg);
fprintf('  raio circunscrito (p/ rejeicao no Monte Carlo): %.3f m\n', raio_efetivo);

%% Verificacao
[~, ms, ~, p] = read_parameter_xml(xml_saida);
ps = p.swarm.Couzin.pos_shill;
borda = (abs(abs(ps(1,:))-30) < 1) | (abs(abs(ps(2,:))-30) < 1);

fprintf('\n--- verificacao ---\n');
fprintf('arena X:[%.1f %.1f] Y:[%.1f %.1f]\n', ...
    p.map.x_range(1), p.map.x_range(2), p.map.y_range(1), p.map.y_range(2));
fprintf('blocos de algoritmo: ');
fprintf('%s ', string(fieldnames(p.swarm))); fprintf('\n');
fprintf('map3d_struct: %s  (arena vazia era 17x6)\n', mat2str(size(ms)));
fprintf('shill total: %d | paredes: %d | internos: %d\n', ...
    size(ps,2), sum(borda), sum(~borda));
fprintf('ocupacao: %.1f m2 de 3600 m2 (%.1f%%)\n', ...
    M*area_unit, 100*M*area_unit/3600);

if M > 1
    dmin = inf;
    for i = 1:M
        for j = i+1:M
            dmin = min(dmin, hypot(posicoes(1,i)-posicoes(1,j), ...
                                   posicoes(2,i)-posicoes(2,j)));
        end
    end
    fprintf('corredor entre obstaculos: %.1f m\n', dmin - dimensao);
end

fprintf('\nATUALIZE o modulo do OlfatiSaber com estes centros:\n');
fprintf('  OBST_X = [%s];\n', strjoin(arrayfun(@(v)sprintf('%g',v), ...
    posicoes(1,:), 'UniformOutput', false), ', '));
fprintf('  OBST_Y = [%s];\n', strjoin(arrayfun(@(v)sprintf('%g',v), ...
    posicoes(2,:), 'UniformOutput', false), ', '));
fprintf('  N_OBST = %d;\n', M);

fprintf('\nPara o Monte Carlo, use:\n');
fprintf('  obst = [%s; ...\n          %s; ...\n          %s];\n', ...
    strjoin(arrayfun(@(v)sprintf('%g',v), posicoes(1,:), 'UniformOutput', false), ' '), ...
    strjoin(arrayfun(@(v)sprintf('%g',v), posicoes(2,:), 'UniformOutput', false), ' '), ...
    strjoin(repmat({sprintf('%.3f', raio_efetivo)}, 1, M), ' '));

figure('Color','w');
plot(ps(1,~borda), ps(2,~borda), '.', 'MarkerSize', 5, 'Color', [0.8 0.2 0.2]);
hold on;
plot(ps(1,borda), ps(2,borda), '.', 'MarkerSize', 2, 'Color', [0.4 0.4 0.4]);
axis equal; xlim([-32 32]); ylim([-32 32]); grid on;
xlabel('x (m)'); ylabel('y (m)');
title(sprintf('%d %s(s), dim %.1f m, rot %.0f graus', ...
    M, forma, dimensao, rotacao_deg));
legend('obstaculos','paredes','Location','eastoutside');
end