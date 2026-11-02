function figuras_validacao_modulos(arq)
%FIGURAS_VALIDACAO_MODULOS  Figura da validacao dos modulos (Apendice B).
%
%   figuras_validacao_modulos                         % o validacao_*.mat mais recente
%   figuras_validacao_modulos('data_save\validacao_modulos\validacao_<carimbo>.mat')
%
% Gera fig_validacao_modulos.pdf e .png na pasta do arquivo:
%   (a) Couzin: polarizacao p e momento angular m em funcao de Delta_r_o
%       (Delta_r_a = 14 e 2; media e amplitude das sementes);
%   (b) e (c) Couzin: trajetorias dos ultimos 60 s, no menor e no maior
%       Delta_r_o (e no maior m, se houver toro);
%   (d) Olfati-Saber: distancia ao vizinho mais proximo / d no fim;
%   (e) Olfati-Saber: posicoes finais (parametros calibrados);
%   (f) Reynolds: polarizacao e menor distancia por configuracao.
%
% Os rotulos da figura tem acentos: o arquivo e UTF-8, o padrao do MATLAB
% desde a R2020a.
%
% Escrito para o TCC de Fernando Souza Rodrigues (29/10/2026).

if nargin < 1 || isempty(arq)
    d = dir(fullfile('data_save', 'validacao_modulos', 'validacao_*.mat'));
    if isempty(d), error('Nenhum validacao_*.mat em data_save\validacao_modulos.'); end
    [~, i] = max([d.datenum]);
    arq = fullfile(d(i).folder, d(i).name);
end
S = load(arq, 'R');
R = S.R(cellfun(@isempty, {S.R.erro}));
[pasta, base] = fileparts(arq);

fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 24 15]);
tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

% ---------------------------------------------------------------- Couzin
C = R(strcmp({R.alg}, 'Couzin'));
nexttile(tl, 1);
if ~isempty(C)
    hold on
    grupos = unique({C.grupo}, 'stable');
    estilos = {'-', '--'};
    for g = 1:numel(grupos)
        Cg = C(strcmp({C.grupo}, grupos{g}));
        dro = arrayfun(@(r) r.valores(2) - r.valores(1), Cg);
        ux = unique(dro);
        [pm, pl, ph, mm, ml, mh] = deal(zeros(size(ux)));
        for i = 1:numel(ux)
            s = dro == ux(i);
            pv = [Cg(s).p]; mv = [Cg(s).m];
            pm(i) = mean(pv); pl(i) = min(pv); ph(i) = max(pv);
            mm(i) = mean(mv); ml(i) = min(mv); mh(i) = max(mv);
        end
        est = estilos{min(g, 2)};
        errorbar(ux, pm, pm - pl, ph - pm, ['o' est], 'Color', [0 0.35 0.7], 'MarkerSize', 4, ...
            'DisplayName', sprintf('p (%s)', strrep(grupos{g}, 'dra', '\Deltar_a')));
        errorbar(ux, mm, mm - ml, mh - mm, ['s' est], 'Color', [0.8 0.3 0], 'MarkerSize', 4, ...
            'DisplayName', sprintf('m (%s)', strrep(grupos{g}, 'dra', '\Deltar_a')));
    end
    yline(0.35, ':', 'HandleVisibility', 'off'); yline(0.65, ':', 'HandleVisibility', 'off');
    xlabel('\Deltar_o (m)'); ylabel('p, m'); ylim([0 1.05]); box on
    legend('Location', 'best', 'FontSize', 6);
    title('(a) Couzin: p e m', 'FontWeight', 'normal');
    % exemplos: menor Delta_r_o, maior m e maior Delta_r_o, com Delta_r_a = 14
    C14 = C(strcmp({C.grupo}, grupos{1}));
    dro14 = arrayfun(@(r) r.valores(2) - r.valores(1), C14);
    [~, i_min] = min(dro14 + 1e-3*[C14.semente]);
    [~, i_max] = max(dro14 - 1e-3*[C14.semente]);
    [mmax, i_m] = max([C14.m]);
    nexttile(tl, 2); desenha(C14(i_min), sprintf('(b) Couzin, \\Deltar_o = %g: %s', dro14(i_min), C14(i_min).classe));
    if mmax > 0.65
        nexttile(tl, 3); desenha(C14(i_m), sprintf('(c) Couzin, \\Deltar_o = %g: %s', dro14(i_m), C14(i_m).classe));
    else
        nexttile(tl, 3); desenha(C14(i_max), sprintf('(c) Couzin, \\Deltar_o = %g: %s', dro14(i_max), C14(i_max).classe));
    end
else
    axis off; text(0.1, 0.5, 'sem execucoes do Couzin');
end

% ---------------------------------------------------------- Olfati-Saber
O = R(strcmp({R.alg}, 'OlfatiSaber'));
nexttile(tl, 4);
if ~isempty(O)
    hold on
    rot = unique({O.rotulo}, 'stable');
    cores = [0 0.45 0.2; 0.55 0.2 0.6];
    for q = 1:numel(rot)
        Oq = O(strcmp({O.rotulo}, rot{q}));
        v = [];
        for k = 1:numel(Oq)
            P = Oq(k).pos_final;
            D = sqrt((P(1, :) - P(1, :)').^2 + (P(2, :) - P(2, :)').^2);
            D(1:size(D, 1)+1:end) = inf;
            v = [v, min(D, [], 2)' / Oq(k).d_ref]; %#ok<AGROW>
        end
        histogram(v, 0:0.1:2.5, 'Normalization', 'probability', 'FaceColor', cores(min(q, 2), :), ...
            'FaceAlpha', 0.5, 'DisplayName', char(acentua(rot(q))));
    end
    xline(1, 'k--', 'HandleVisibility', 'off');
    xlabel('vizinho mais próximo / d'); ylabel('fração dos drones'); box on
    legend('Location', 'northeast', 'FontSize', 6);
    title('(d) Olfati-Saber: espaçamento final', 'FontWeight', 'normal');
    nexttile(tl, 5);
    Oc = O(strcmp({O.rotulo}, rot{1}));
    desenha(Oc(1), sprintf('(e) Olfati-Saber (%s), d = %.1f m', char(acentua(rot(1))), Oc(1).d_ref));
else
    axis off; text(0.1, 0.5, 'sem execucoes do Olfati-Saber');
    nexttile(tl, 5); axis off
end

% -------------------------------------------------------------- Reynolds
Y = R(strcmp({R.alg}, 'Reynolds'));
nexttile(tl, 6);
if ~isempty(Y)
    rot = unique({Y.rotulo}, 'stable');
    pm = zeros(1, numel(rot)); dm = pm;
    for q = 1:numel(rot)
        Yq = Y(strcmp({Y.rotulo}, rot{q}));
        pm(q) = mean([Yq.p]);
        dm(q) = min([Yq.dmin]);
    end
    yyaxis left
    bar((1:numel(rot)) - 0.18, pm, 0.35, 'FaceColor', [0 0.35 0.7]);
    ylabel('polarização p'); ylim([0 1.05]);
    yyaxis right
    bar((1:numel(rot)) + 0.18, dm, 0.35, 'FaceColor', [0.8 0.3 0]);
    ylabel('menor distância (m)');
    set(gca, 'XTick', 1:numel(rot), 'XTickLabel', strrep(acentua(rot), ' (', '\newline('), 'FontSize', 6);
    title('(f) Reynolds: regras e ablações', 'FontWeight', 'normal');
    box on
else
    axis off; text(0.1, 0.5, 'sem execucoes do Reynolds');
end

saida = fullfile(pasta, 'fig_validacao_modulos');
exportgraphics(fig, [saida '.pdf'], 'ContentType', 'vector');
exportgraphics(fig, [saida '.png'], 'Resolution', 200);
fprintf('Figura gravada em %s.pdf e .png (de %s).\n', saida, base);
end


function c = acentua(c)
% Rotulos com acento para a figura (os do .mat ficam em ASCII).
c = strrep(c, 'referencia', 'referência');
c = strrep(c, 'coesao', 'coesão');
c = strrep(c, 'separacao', 'separação');
end


function desenha(r, titulo)
% Trajetorias dos ultimos 60 s e posicoes finais, com a velocidade.
hold on
T = r.traj;
for i = 1:size(T, 2)
    plot(squeeze(T(1, i, :)), squeeze(T(2, i, :)), '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 0.5);
end
P = r.pos_final; V = r.vel_final;
Vu = V ./ max(vecnorm(V), 1e-9);
esc = max(1, 0.06 * max(max(P(1, :)) - min(P(1, :)), max(P(2, :)) - min(P(2, :))));
quiver(P(1, :), P(2, :), esc*Vu(1, :), esc*Vu(2, :), 0, 'Color', [0 0.35 0.7], 'MaxHeadSize', 0.8);
plot(P(1, :), P(2, :), 'k.', 'MarkerSize', 8);
axis equal; box on
xlabel('x (m)'); ylabel('y (m)');
title(titulo, 'FontWeight', 'normal', 'FontSize', 8);
end
