function visualizar_hifi(arquivo)
%VISUALIZAR_HIFI  Visualizador interativo de uma execucao de alta fidelidade.
%
% Exibe tres paineis sincronizados por um controle deslizante de tempo:
%   - trajetorias no plano, com rastro que cresce ate o instante escolhido
%   - phi_corr em funcao do tempo
%   - phi_vel em funcao do tempo
%
% Controles:
%   deslizante  : varre de t = 0 ate o fim da fase Alg
%   Reproduzir  : avanca sozinho ate o fim (clique de novo para parar)
%   Reiniciar   : volta ao inicio
%   Salvar video: exporta MP4 da animacao completa
%
% USO:
%   visualizar_hifi('data_save\high_fidelity\hifi_couzin_cubos_seed3.mat')

if nargin < 1
    error('Informe o arquivo. Ex: visualizar_hifi(''...\\hifi_couzin_cubos_seed3.mat'')');
end

% Reaproveita a extracao ja validada (metricas, series e trajetorias).
% NAO usar evalc aqui: ele executa em escopo proprio e nao devolve as
% variaveis criadas. O relatorio de texto aparece uma vez, e serve de
% confirmacao de que o arquivo carregado e o esperado.
M = extrair_metricas_hifi(arquivo, false);
S = load(arquivo);

X = M.traj.X;  Y = M.traj.Y;
t = M.series.t;
n_t = numel(t);
N   = size(X, 2);
[~, nome] = fileparts(arquivo);

%% ---- obstaculos ----
obst = [];  forma = 'cubo';
if isfield(M, 'forma_obstaculos'); forma = M.forma_obstaculos; end
if isfield(S, 'map3d_struct')
    ms = S.map3d_struct;
    for o = 1:size(ms,2)
        sx = ms(7,o);  sy = ms(8,o);
        if sx < 55 && sy < 55 && sx > 0.1 && sy > 0.1
            obst(end+1,:) = [ms(1,o), ms(2,o), sx, sy]; %#ok<AGROW>
        end
    end
end

%% ---- figura ----
f = figure('Color','w','Position',[80 60 1180 620],'Name',nome,'NumberTitle','off');

ax1 = axes('Parent',f,'Position',[0.05 0.22 0.44 0.70]);
ax2 = axes('Parent',f,'Position',[0.57 0.60 0.40 0.32]);
ax3 = axes('Parent',f,'Position',[0.57 0.22 0.40 0.32]);

% --- painel de trajetorias: elementos estaticos ---
hold(ax1,'on');
for o = 1:size(obst,1)
    if strcmp(forma,'cubo'); curv = [0 0]; else; curv = [1 1]; end
    rectangle('Parent',ax1,'Position',[obst(o,1)-obst(o,3)/2, obst(o,2)-obst(o,4)/2, obst(o,3), obst(o,4)], 'Curvature',curv,'FaceColor',[0.78 0.78 0.78],'EdgeColor',[0.4 0.4 0.4]);
end
rectangle('Parent',ax1,'Position',[-30 -30 60 60],'EdgeColor','k','LineWidth',1.3);
axis(ax1,'equal'); xlim(ax1,[-33 33]); ylim(ax1,[-33 33]); grid(ax1,'on'); box(ax1,'on');
xlabel(ax1,'x (m)'); ylabel(ax1,'y (m)');
set(ax1,'FontName','Times New Roman','FontSize',11);

cores = lines(N);
h_rastro = gobjects(N,1);
h_atual  = gobjects(N,1);
for i = 1:N
    h_rastro(i) = plot(ax1, NaN, NaN, '-', 'Color', [cores(i,:) 0.55], 'LineWidth', 0.9);
    h_atual(i)  = plot(ax1, NaN, NaN, 'o', 'Color', cores(i,:), 'MarkerFaceColor', cores(i,:), 'MarkerSize', 6);
end
h_tit1 = title(ax1, '');

% --- series temporais ---
plot(ax2, t, M.series.phi_corr, '-', 'Color', [0.8 0.8 0.85], 'LineWidth', 0.8);
hold(ax2,'on');
h_corr = plot(ax2, NaN, NaN, '-', 'Color', [0.15 0.35 0.65], 'LineWidth', 1.4);
h_cursor2 = xline(ax2, t(1), 'r-', 'LineWidth', 1);
ylabel(ax2,'\phi_{corr}'); ylim(ax2,[0 1.05]); xlim(ax2,[t(1) t(end)]);
grid(ax2,'on'); box(ax2,'on');
set(ax2,'FontName','Times New Roman','FontSize',10);
h_tit2 = title(ax2, '');

plot(ax3, t, M.series.phi_vel, '-', 'Color', [0.85 0.85 0.8], 'LineWidth', 0.8);
hold(ax3,'on');
h_vel = plot(ax3, NaN, NaN, '-', 'Color', [0.75 0.4 0.15], 'LineWidth', 1.4);
h_cursor3 = xline(ax3, t(1), 'r-', 'LineWidth', 1);
ylabel(ax3,'\phi_{vel}'); xlabel(ax3,'t (s)'); xlim(ax3,[t(1) t(end)]);
ylim(ax3,[0 max(1.15, max(M.series.phi_vel)*1.05)]);
grid(ax3,'on'); box(ax3,'on');
set(ax3,'FontName','Times New Roman','FontSize',10);
h_tit3 = title(ax3, '');

%% ---- controles ----
sld = uicontrol(f,'Style','slider','Units','normalized','Position',[0.05 0.09 0.62 0.035], 'Min',1,'Max',n_t,'Value',n_t, 'SliderStep',[1/(n_t-1), 20/(n_t-1)]);
uicontrol(f,'Style','text','Units','normalized','Position',[0.05 0.045 0.62 0.03], 'String','tempo','BackgroundColor','w','FontName','Times New Roman');

btn_play = uicontrol(f,'Style','pushbutton','Units','normalized','Position',[0.70 0.085 0.09 0.045],'String','Reproduzir','FontName','Times New Roman');
btn_rst  = uicontrol(f,'Style','pushbutton','Units','normalized','Position',[0.80 0.085 0.09 0.045],'String','Reiniciar','FontName','Times New Roman');
btn_vid  = uicontrol(f,'Style','pushbutton','Units','normalized','Position',[0.90 0.085 0.09 0.045],'String','Salvar video','FontName','Times New Roman');

estado = struct('tocando', false);
guidata(f, estado);

set(sld,      'Callback', @(s,~) atualizar(round(get(s,'Value'))));
set(btn_play, 'Callback', @(s,~) reproduzir(s));
set(btn_rst,  'Callback', @(~,~) reiniciar());
set(btn_vid,  'Callback', @(~,~) salvar_video());

atualizar(n_t);

%% ================= funcoes aninhadas =================
    function atualizar(k)
        k = max(1, min(n_t, k));
        for ii = 1:N
            set(h_rastro(ii), 'XData', X(1:k,ii), 'YData', Y(1:k,ii));
            set(h_atual(ii),  'XData', X(k,ii),   'YData', Y(k,ii));
        end
        set(h_corr, 'XData', t(1:k), 'YData', M.series.phi_corr(1:k));
        set(h_vel,  'XData', t(1:k), 'YData', M.series.phi_vel(1:k));
        set(h_cursor2, 'Value', t(k));
        set(h_cursor3, 'Value', t(k));

        set(h_tit1, 'String', sprintf('%s  |  t = %.1f s  (%.0f%%)', strrep(nome,'_','\_'), t(k), 100*k/n_t));
        set(h_tit2, 'String', sprintf('media ate aqui = %.4f  (total %.4f)', mean(M.series.phi_corr(1:k)), M.phi_corr));
        set(h_tit3, 'String', sprintf('media ate aqui = %.4f  (total %.4f)', mean(M.series.phi_vel(1:k)), M.phi_vel));
        drawnow limitrate;
    end

    function reproduzir(botao)
        e = guidata(f);
        if e.tocando
            e.tocando = false;  guidata(f, e);
            set(botao, 'String', 'Reproduzir');
            return;
        end
        e.tocando = true;  guidata(f, e);
        set(botao, 'String', 'Parar');
        k0 = round(get(sld,'Value'));
        if k0 >= n_t; k0 = 1; end
        passo = max(1, round(n_t/400));
        for k = k0:passo:n_t
            e = guidata(f);
            if ~e.tocando || ~isvalid(f); break; end
            set(sld, 'Value', k);
            atualizar(k);
            pause(0.01);
        end
        if isvalid(f)
            e = guidata(f); e.tocando = false; guidata(f, e);
            set(botao, 'String', 'Reproduzir');
        end
    end

    function reiniciar()
        e = guidata(f); e.tocando = false; guidata(f, e);
        set(btn_play, 'String', 'Reproduzir');
        set(sld, 'Value', 1);
        atualizar(1);
    end

    function salvar_video()
        arq_v = sprintf('%s_animacao.mp4', nome);
        v = VideoWriter(arq_v, 'MPEG-4');
        v.FrameRate = 25;  v.Quality = 95;
        open(v);
        passo = max(1, round(n_t/500));
        set(btn_vid, 'String', 'Gravando...', 'Enable', 'off');
        for k = 1:passo:n_t
            set(sld, 'Value', k);
            atualizar(k);
            writeVideo(v, getframe(f));
        end
        close(v);
        set(btn_vid, 'String', 'Salvar video', 'Enable', 'on');
        fprintf('Video salvo: %s\n', fullfile(pwd, arq_v));
    end
end