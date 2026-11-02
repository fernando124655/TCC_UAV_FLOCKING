function figuras_validacao_modulos(arq)
%FIGURAS_VALIDACAO_MODULOS  Figura da validacao dos modulos (Apendice D do artigo).
%
%   figuras_validacao_modulos                         % o validacao_*.mat mais recente
%   figuras_validacao_modulos('data_save\validacao_modulos\validacao_<carimbo>.mat')
%
% Gera fig_validacao_modulos.pdf e .png na pasta do arquivo, com os dois
% paineis da Figura 8 do artigo:
%   (a) Couzin: polarizacao p e momento angular m em funcao de Delta_r_o,
%       com Delta_r_a = 14 m e 2 m (media das sementes; barras: minimo e maximo);
%   (b) Olfati-Saber: distancia de cada drone ao vizinho mais proximo, em
%       unidades de d, ao fim das execucoes (parametros calibrados e do artigo).
%
% Versao de 02/11/2026: fundo claro mesmo com o tema escuro do MATLAB
% (R2025a ou mais nova), dois paineis com titulos que nao se sobrepoem e
% legendas maiores, fora das curvas. Roda tambem no GNU Octave (8.4 ou mais
% novo), sem tiledlayout, histogram e xline/yline; o exportgraphics so e usado no MATLAB.
%
% O arquivo e UTF-8 (rotulos com acentos, Delta e >=), o padrao do MATLAB
% desde a R2020a.
%
% Escrito para o TCC de Fernando Souza Rodrigues (29/10/2026; revisto em 02/11/2026).

if nargin < 1 || isempty(arq)
    d = dir(fullfile('data_save', 'validacao_modulos', 'validacao_*.mat'));
    if isempty(d), error('Nenhum validacao_*.mat em data_save\validacao_modulos.'); end
    [~, i] = max([d.datenum]);
    arq = fullfile(d(i).folder, d(i).name);
end
S = load(arq, 'R');
R = S.R(cellfun(@isempty, {S.R.erro}));
[pasta, base] = fileparts(arq);

% ------------------------------------------------------------ aparencia
AZUL    = [42 120 214] / 255;    % Delta_r_a = 14 m; parametros calibrados
LARANJA = [235 104 52] / 255;    % Delta_r_a = 2 m; parametros do artigo
TINTA   = [0.13 0.13 0.13];      % textos
EIXO    = [0.40 0.40 0.40];      % eixos e marcas
GRADE   = [0.88 0.88 0.88];
FONTE   = 'Times New Roman';     % a fonte do artigo
TAM     = 9;                     % eixos e legendas, em pontos
TAM_TIT = 10;                    % titulos dos paineis
LARG = 16; ALT = 7.8;            % cm: a largura do texto do artigo

fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 LARG ALT], ...
    'PaperUnits', 'centimeters', 'PaperSize', [LARG ALT], 'PaperPosition', [0 0 LARG ALT], ...
    'InvertHardcopy', 'off');
if isprop(fig, 'Theme')
    try, set(fig, 'Theme', 'light'); catch, end   % R2025a+: ignora o tema escuro
end
% paineis; as legendas ficam abaixo deles, fora das curvas
ax_a = axes('Parent', fig, 'Position', [0.085 0.355 0.385 0.565]);
ax_b = axes('Parent', fig, 'Position', [0.600 0.355 0.385 0.565]);

% ---------------------------------------------------------------- (a) Couzin
C = R(strcmp({R.alg}, 'Couzin'));
axes(ax_a); hold on
grupos = {'dra=14', 'dra=2'}; dras = [14 2]; cores = {AZUL, LARANJA};
h = []; rot = {};
for g = 1:2
    Cg = C(strcmp({C.grupo}, grupos{g}));
    if isempty(Cg), continue; end
    dro = arrayfun(@(r) r.valores(2) - r.valores(1), Cg);
    ux = unique(dro);
    [pm, pl, ph, mm, ml, mh] = deal(zeros(size(ux)));
    for i = 1:numel(ux)
        s = abs(dro - ux(i)) < 1e-9;
        pv = [Cg(s).p]; mv = [Cg(s).m];
        pm(i) = mean(pv); pl(i) = min(pv); ph(i) = max(pv);
        mm(i) = mean(mv); ml(i) = min(mv); mh(i) = max(mv);
    end
    hp = errorbar(ux, pm, pm - pl, ph - pm, 'o-');
    hm = errorbar(ux, mm, mm - ml, mh - mm, 's--');
    set(hp, 'Color', cores{g}, 'LineWidth', 1.4, 'MarkerSize', 5, 'MarkerFaceColor', cores{g});
    set(hm, 'Color', cores{g}, 'LineWidth', 1.4, 'MarkerSize', 5.5, 'MarkerFaceColor', 'w');
    if isprop(hp, 'CapSize'), set([hp hm], 'CapSize', 3); end
    h = [h hp hm]; %#ok<AGROW>
    rot = [rot, {sprintf('\\itp\\rm, Δr_a = %d m', dras(g)), sprintf('\\itm\\rm, Δr_a = %d m', dras(g))}]; %#ok<AGROW>
end
xlim([-0.5 14.5]); ylim([-0.03 1.05]);
set(ax_a, 'XTick', [0 2 4 6 8 10 12 14], 'YTick', 0:0.2:1, 'YTickLabel', virgula(0:0.2:1));
xlabel('Δr_o (m)'); ylabel('\itp\rm e \itm');
lg_a = legend(ax_a, h, rot);
set(lg_a, 'NumColumns', 2);
titulo(ax_a, '(a) Couzin: zona de orientação');
estilo(ax_a, lg_a);

% ------------------------------------------------------------ (b) Olfati-Saber
O = R(strcmp({R.alg}, 'OlfatiSaber'));
axes(ax_b); hold on
centros = 0:0.25:8;
bordas = [centros - 0.125, centros(end) + 0.125];
conjuntos = {'calibrado', 'artigo (d=7, r=1,2d, a=b=5)'};
nomes = {'parâmetros calibrados', 'parâmetros do artigo'};
F = zeros(numel(centros), 2);
for q = 1:2
    Oq = O(strcmp({O.rotulo}, conjuntos{q}));
    v = [];
    for k = 1:numel(Oq)
        P = Oq(k).pos_final;
        D = sqrt((P(1, :) - P(1, :)').^2 + (P(2, :) - P(2, :)').^2);
        D(1:size(D, 1)+1:end) = inf;
        v = [v, min(D, [], 2)' / Oq(k).d_ref]; %#ok<AGROW>
    end
    v = min(v, 7.95);                          % a ultima classe e ">= 8"
    for j = 1:numel(centros)                   % contagem por classe (MATLAB e Octave)
        F(j, q) = sum(v >= bordas(j) & v < bordas(j + 1)) / max(numel(v), 1);
    end
end
hb = bar(centros, F, 1, 'grouped');
set(hb(1), 'FaceColor', AZUL, 'EdgeColor', 'none');
set(hb(2), 'FaceColor', LARANJA, 'EdgeColor', 'none');
yl = [0 1.08 * max(F(:))];
plot([1 1], yl, ':', 'Color', EIXO, 'LineWidth', 1);
xlim([-0.2 8.3]); ylim(yl);
set(ax_b, 'XTick', [0 1 2 4 6 8], 'XTickLabel', {'0', '1', '2', '4', '6', '≥8'}, ...
    'YTick', 0:0.2:1, 'YTickLabel', virgula(0:0.2:1));
xlabel('vizinho mais próximo / \itd'); ylabel('fração dos drones');
lg_b = legend(ax_b, hb, nomes);
titulo(ax_b, '(b) Olfati-Saber: espaçamento final');
estilo(ax_b, lg_b);

% legendas centradas abaixo de cada painel
abaixo(ax_a, lg_a); abaixo(ax_b, lg_b);

% ------------------------------------------------------------ gravacao
saida = fullfile(pasta, 'fig_validacao_modulos');
if exist('OCTAVE_VERSION', 'builtin') == 0     % MATLAB
    exportgraphics(fig, [saida '.pdf'], 'ContentType', 'vector', 'BackgroundColor', 'w');
    exportgraphics(fig, [saida '.png'], 'Resolution', 300, 'BackgroundColor', 'w');
else                                            % GNU Octave
    print(fig, '-dpdf', [saida '.pdf']);
    print(fig, '-dpng', '-r600', [saida '.png']);
end
fprintf('Figura gravada em %s.pdf e .png (de %s).\n', saida, base);

    % ---------------------------------------------- funcoes internas
    function titulo(ax, txt)
        % Titulo alinhado a esquerda, acima do painel (nao invade o vizinho).
        text(ax, 0, 1.035, txt, 'Units', 'normalized', 'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'bottom', 'FontName', FONTE, 'FontSize', TAM_TIT, 'Color', TINTA);
    end

    function estilo(ax, lg)
        set(ax, 'Color', 'w', 'Box', 'off', 'FontName', FONTE, 'FontSize', TAM, ...
            'XColor', EIXO, 'YColor', EIXO, 'LineWidth', 0.7, 'TickDir', 'out', ...
            'XGrid', 'on', 'YGrid', 'on', 'Layer', 'bottom');
        if isprop(ax, 'GridColor'), set(ax, 'GridColor', GRADE); end
        if isprop(ax, 'GridAlpha'), set(ax, 'GridAlpha', 1); end
        set(get(ax, 'XLabel'), 'Color', TINTA, 'FontName', FONTE, 'FontSize', TAM + 0.5);
        set(get(ax, 'YLabel'), 'Color', TINTA, 'FontName', FONTE, 'FontSize', TAM + 0.5);
        set(lg, 'FontName', FONTE, 'FontSize', TAM, 'Color', 'w', 'EdgeColor', [0.75 0.75 0.75], 'Box', 'on');
        if isprop(lg, 'TextColor'), set(lg, 'TextColor', TINTA); end
        if isprop(lg, 'ItemTokenSize'), set(lg, 'ItemTokenSize', [20 12]); end
    end

    function c = virgula(v)
        % Rotulos com virgula decimal, como no texto do artigo.
        c = strrep(arrayfun(@(x) sprintf('%g', x), v, 'UniformOutput', false), '.', ',');
    end

    function abaixo(ax, lg)
        % Poe a legenda centrada sob o painel, abaixo do rotulo do eixo x.
        drawnow;
        set(lg, 'Units', 'normalized');
        pa = get(ax, 'Position'); pl = get(lg, 'Position');
        set(lg, 'Position', [pa(1) + (pa(3) - pl(3)) / 2, 0.015, pl(3), pl(4)]);
    end
end
