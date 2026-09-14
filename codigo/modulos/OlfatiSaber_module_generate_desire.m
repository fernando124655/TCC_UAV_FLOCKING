function [command_upper_s, control_mode_s] = OlfatiSaber_module_generate_desire(...
    t, states, sample_time, sensor_data_s, map3d_struct, terrain, terrain_params)
%OLFATISABER_MODULE_GENERATE_DESIRE  Olfati-Saber (2006) flocking controller.
%
% Arquitetura: integracao de aceleracao (preservando a dinamica de
% potenciais suaves de Olfati-Saber) + normalizacao de velocidade constante
% pos-integracao (Vicsek 1995).
%
% MUDANCA NESTA VERSAO -- repulsao de parede por BETA-AGENTS:
% A versao anterior tratava as paredes somando repulsao 1/d^2 sobre os
% ~2400 shill agents da arena. Isso se afasta do paper, que representa
% obstaculos por UM beta-agent virtual por obstaculo: a projecao
% perpendicular do alpha-agent sobre a superficie (Lemma 4, parte i, para
% fronteiras planas). Para as quatro paredes da arena a projecao e trivial,
% e a formulacao original phi_beta pode ser recuperada integralmente.
%
% Isso resolve o problema que motivou a substituicao original: phi_beta e
% PURAMENTE REPULSIVA (nao tem zona atrativa como phi_alpha), entao nao ha
% atracao cumulativa para dentro da parede. E o termo de amortecimento de
% velocidade, antes inviavel por somar sobre centenas de shills, volta a
% ser bem-comportado com no maximo 2 paredes ativas.
%
% O laco de shill agents e mantido apenas para OBSTACULOS INTERNOS (os
% shills de parede sao filtrados). Numa arena vazia esse laco fica inativo.
%
% Referencias:
%   [OS1] Olfati-Saber (2006), IEEE TAC 51(3), 401-420.
%         - Eq. 10  : bump function rho_h
%         - Eq. 56  : action function phi_beta
%         - Eq. 59  : termo beta do Algoritmo 3
%         - Lemma 4 : projecao do beta-agent em fronteira plana
%         - Sec.VIII: h = 0.9 para phi_beta ; c_2 = 2*sqrt(c_1)
%   [OS2] Soria et al. (2020), IROS, pp. 8005-8011.
%   [OS5] Vicsek et al. (1995), Phys. Rev. Lett. 75(6), 1226.

persistent fun_params
if isempty(fun_params)
    file_name_param = 'OlfatiSaber_module_parameters';
    [~, str_core] = get_multi_core_value();
    fun_params = str2func([file_name_param, str_core]);
end

[r_com, d_ref, v_ref, u_ref_x, u_ref_y, ...
 a_coeff, b_coeff, delta, k_exp, c_vm, ...
 c_pm_obs, c_vm_obs, r0_obs, max_v, max_a, ...
 c_arena, d_arena, dim, height, dr_shill, ...
 pos_shill, vel_shill] = fun_params();

c_sig = abs(a_coeff - b_coeff) / (2 * sqrt(max(a_coeff * b_coeff, 1e-9)));

% Ganho de amortecimento da parede por amortecimento critico [OS1, Sec.VIII]
c_vm_wall = 2 * sqrt(max(c_arena, 1e-9));
H_BETA    = 0.9;    % parametro h da bump function de phi_beta [OS1]

% Alcance de interacao com OBSTACULOS, distinto do de paredes.
% [OS1, Sec. VIII] prescreve d' = 0.6*d e r' = 1.2*d' para obstaculos,
% ou seja, alcance = 0.72*d_ref -- menor que o das paredes.
% Motivo de manter separado: d_arena foi otimizado para paredes PLANAS na
% arena vazia (11.2 m). Aplicado a cilindros de raio 3 m, esse alcance faz
% a zona de influencia chegar a 14.2 m do centro; obstaculos vizinhos (24 m
% de separacao) passam a ter zonas sobrepostas e sobra ~1% da arena livre
% de forca beta, o que impede o bando (diametro ~3.6*d_ref) de se organizar.
% Com 0.72*d_ref a influencia vai a ~8.9 m do centro, sem sobreposicao.
d_obst = 0.72 * d_ref;

M_shill = size(pos_shill, 2);
if ~isempty(pos_shill) && size(pos_shill, 1) >= 2
    p_sh_x = pos_shill(1, :);
    p_sh_y = pos_shill(2, :);
else
    p_sh_x = zeros(1, 0);
    p_sh_y = zeros(1, 0);
    M_shill = 0;
end

x_min = -30; x_max = 30;
y_min = -30; y_max = 30;
WALL_TOL = 1.0;     % tolerancia para identificar shill de parede

% Obstaculos internos: apenas os CENTROS sao necessarios. A atribuicao de
% cada shill ao seu obstaculo usa o criterio do centro mais proximo, que e
% AGNOSTICO A FORMA -- funciona para cilindros, cubos ou qualquer geometria
% convexa. DEVE corresponder aos centros usados em build_obstacle_xml.
% Numa arena vazia estes valores sao irrelevantes (nao ha shill interno).
OBST_X = [-12, -12,  12,  12];
OBST_Y = [-12,  12, -12,  12];
N_OBST = 4;

% Pre-classificacao dos shills (feita UMA vez, nao por drone):
%   shill_group(s) = 0  -> parede da arena (tratada pelos beta-agents fixos)
%   shill_group(s) = g  -> pertence ao obstaculo g
shill_group = zeros(1, M_shill);
for s = 1:M_shill
    is_wall = false;
    if abs(p_sh_x(s) - x_min) < WALL_TOL; is_wall = true; end
    if abs(p_sh_x(s) - x_max) < WALL_TOL; is_wall = true; end
    if abs(p_sh_y(s) - y_min) < WALL_TOL; is_wall = true; end
    if abs(p_sh_y(s) - y_max) < WALL_TOL; is_wall = true; end

    if ~is_wall
        g_best = 1;
        d_best = 1e9;
        for g = 1:N_OBST
            dgx = p_sh_x(s) - OBST_X(g);
            dgy = p_sh_y(s) - OBST_Y(g);
            dg = sqrt(dgx*dgx + dgy*dgy);
            if dg < d_best
                d_best = dg;
                g_best = g;
            end
        end
        shill_group(s) = g_best;
    end
end

number = size(states, 2);
command_upper_s = zeros(12, number);
command_upper_s(1:3, :) = states(1:3, :);
control_mode_s = uint8(zeros(1, number)) + 7;

for id = 1:number
    px_i = states(1, id);
    py_i = states(2, id);
    vx_i = states(4, id);
    vy_i = states(5, id);

    acc_grad_x = 0; acc_grad_y = 0;   % potencial gradiente (alpha)
    acc_cons_x = 0; acc_cons_y = 0;   % consenso de velocidade (alpha)
    acc_obs_x  = 0; acc_obs_y  = 0;   % obstaculos internos (shill)
    acc_wall_x = 0; acc_wall_y = 0;   % paredes da arena (beta-agents)

    %% ALPHA: gradiente do potencial + consenso [OS1, Eq. 21]
    for j = 1:number
        if j == id
            continue;
        end
        dx = states(1, j) - px_i;
        dy = states(2, j) - py_i;
        d = sqrt(dx*dx + dy*dy);

        if d < r_com && d > 1e-6
            ux = dx / d;
            uy = dy / d;

            rho_val   = compute_rho_raw(d, delta, r_com, k_exp);
            rho_d_val = compute_rho_der_raw(d, delta, r_com, k_exp);

            psi_arg = d - d_ref + c_sig;
            psi_val = ((a_coeff + b_coeff) * ...
                (sqrt(1 + psi_arg^2) - sqrt(1 + c_sig^2)) + ...
                (a_coeff - b_coeff) * (d - d_ref)) / 2;
            psi_d_val = (a_coeff + b_coeff) / 2 * psi_arg / ...
                sqrt(1 + psi_arg^2) + (a_coeff - b_coeff) / 2;

            phi_val = (1 / r_com) * rho_d_val * psi_val + rho_val * psi_d_val;

            acc_grad_x = acc_grad_x + phi_val * ux;
            acc_grad_y = acc_grad_y + phi_val * uy;

            acc_cons_x = acc_cons_x + c_vm * rho_val * (states(4, j) - vx_i);
            acc_cons_y = acc_cons_y + c_vm * rho_val * (states(5, j) - vy_i);
        end
    end

    %% ============================================================
    %  BETA-AGENTS: paredes da arena [OS1, Sec. VII, Eq. 59, Lemma 4]
    %
    %  Para uma parede plana, o beta-agent e a projecao perpendicular do
    %  drone sobre ela, e a distancia ao beta-agent e simplesmente a
    %  distancia perpendicular a parede.
    %
    %  Termo de posicao : c_arena * phi_beta(dw) * n_hat
    %      n_hat aponta do drone PARA a parede; phi_beta <= 0, logo a
    %      forca resultante aponta para longe da parede (repulsiva).
    %  Termo de velocidade : c_vm_wall * b_ik * (p_hat - p)
    %      p_hat = P*p projeta a velocidade no plano da parede, entao
    %      (p_hat - p) cancela a componente perpendicular -- amortece a
    %      velocidade de aproximacao.
    %  ============================================================

    % Parede x = x_min : normal interna (+1,0), n_hat = (-1,0)
    dw = px_i - x_min;
    if dw < d_arena && dw > 1e-6
        pb = compute_phi_beta(dw, d_arena, H_BETA);
        bk = compute_rho_h(dw / d_arena, H_BETA);
        acc_wall_x = acc_wall_x - c_arena * pb;      % pb<=0 => empurra +x
        acc_wall_x = acc_wall_x - c_vm_wall * bk * vx_i;
    end

    % Parede x = x_max : normal interna (-1,0), n_hat = (+1,0)
    dw = x_max - px_i;
    if dw < d_arena && dw > 1e-6
        pb = compute_phi_beta(dw, d_arena, H_BETA);
        bk = compute_rho_h(dw / d_arena, H_BETA);
        acc_wall_x = acc_wall_x + c_arena * pb;      % pb<=0 => empurra -x
        acc_wall_x = acc_wall_x - c_vm_wall * bk * vx_i;
    end

    % Parede y = y_min : normal interna (0,+1), n_hat = (0,-1)
    dw = py_i - y_min;
    if dw < d_arena && dw > 1e-6
        pb = compute_phi_beta(dw, d_arena, H_BETA);
        bk = compute_rho_h(dw / d_arena, H_BETA);
        acc_wall_y = acc_wall_y - c_arena * pb;
        acc_wall_y = acc_wall_y - c_vm_wall * bk * vy_i;
    end

    % Parede y = y_max : normal interna (0,-1), n_hat = (0,+1)
    dw = y_max - py_i;
    if dw < d_arena && dw > 1e-6
        pb = compute_phi_beta(dw, d_arena, H_BETA);
        bk = compute_rho_h(dw / d_arena, H_BETA);
        acc_wall_y = acc_wall_y + c_arena * pb;
        acc_wall_y = acc_wall_y - c_vm_wall * bk * vy_i;
    end

    %% ============================================================
    %  OBSTACULOS INTERNOS por BETA-AGENT [OS1, Lemma 4, parte ii]
    %
    %  O paper gera UM beta-agent POR OBSTACULO dentro do alcance e soma as
    %  contribuicoes. Aqui, para cada obstaculo, toma-se o shill mais
    %  proximo do drone entre os pertencentes aquele obstaculo -- o que
    %  aproxima a projecao perpendicular sobre a superficie.
    %
    %  Usa os MESMOS ganhos das paredes (c_arena), como no paper, onde
    %  todos os beta-agents compartilham c_1^beta e c_2^beta. O ALCANCE,
    %  porem, e o prescrito para obstaculos (d_obst = 0.72*d_ref), menor
    %  que o das paredes.
    %
    %  Uma unica passada sobre os shills, usando shill_group pre-computado.
    %  Numa arena vazia nao ha shill interno e este bloco fica inativo.
    %  ============================================================
    d_near_g = zeros(1, N_OBST) + 1e9;
    nx_g     = zeros(1, N_OBST);
    ny_g     = zeros(1, N_OBST);

    for s = 1:M_shill
        g = shill_group(s);
        if g > 0
            dx_s = p_sh_x(s) - px_i;
            dy_s = p_sh_y(s) - py_i;
            d_s = sqrt(dx_s*dx_s + dy_s*dy_s);
            if d_s < d_near_g(g) && d_s > 1e-6
                d_near_g(g) = d_s;
                nx_g(g) = dx_s / d_s;
                ny_g(g) = dy_s / d_s;
            end
        end
    end

    for g = 1:N_OBST
        if d_near_g(g) < d_obst
            pb = compute_phi_beta(d_near_g(g), d_obst, H_BETA);
            bk = compute_rho_h(d_near_g(g) / d_obst, H_BETA);
            % n_hat aponta do drone PARA a superficie; pb <= 0 => repulsivo
            acc_obs_x = acc_obs_x + c_arena * pb * nx_g(g);
            acc_obs_y = acc_obs_y + c_arena * pb * ny_g(g);
            % amortece a componente da velocidade rumo ao obstaculo
            v_perp = vx_i * nx_g(g) + vy_i * ny_g(g);
            acc_obs_x = acc_obs_x - c_vm_wall * bk * v_perp * nx_g(g);
            acc_obs_y = acc_obs_y - c_vm_wall * bk * v_perp * ny_g(g);
        end
    end

    %% SOMA, INTEGRACAO E NORMALIZACAO [OS1 + OS5]
    acc_x = acc_grad_x + acc_cons_x + acc_obs_x + acc_wall_x;
    acc_y = acc_grad_y + acc_cons_y + acc_obs_y + acc_wall_y;

    acc_norm = sqrt(acc_x*acc_x + acc_y*acc_y);
    if acc_norm > max_a
        acc_x = max_a * acc_x / acc_norm;
        acc_y = max_a * acc_y / acc_norm;
    end

    vdx = vx_i + acc_x * sample_time;
    vdy = vy_i + acc_y * sample_time;

    v_cand = sqrt(vdx*vdx + vdy*vdy);
    if v_cand > 0.05
        target_speed = v_ref;
        if target_speed > max_v
            target_speed = max_v;
        end
        vdx = target_speed * vdx / v_cand;
        vdy = target_speed * vdy / v_cand;
    else
        if acc_norm > 0.01
            vdx = v_ref * acc_x / acc_norm;
            vdy = v_ref * acc_y / acc_norm;
        else
            vdx = v_ref * 0.7;
            vdy = v_ref * 0.3;
        end
    end

    %% SAIDA
    pos_desired_id = [states(1:3, id); 0];
    pos_desired_id(3) = height;
    vel_desired_id = [vdx; vdy; 0; 0];
    acc_desired_id = [0; 0; 0; 0];
    command_upper_s(:, id) = [pos_desired_id; vel_desired_id; acc_desired_id];
end
end


%% ================= FUNCOES AUXILIARES =================

function y = compute_rho_raw(z, delta, r, k)
    if z < delta * r
        y = 1;
    elseif z < r
        y = (1 / 2^k) * (1 + cos(pi * (z / r - delta) / (1 - delta)))^k;
    else
        y = 0;
    end
end

function y = compute_rho_der_raw(z, delta, r, k)
    if z < delta * r
        y = 0;
    elseif z < r
        arg = pi * (z / r - delta) / (1 - delta);
        y = -pi / (1 - delta) * k / (2^k) * (1 + cos(arg))^(k - 1) * sin(arg);
    else
        y = 0;
    end
end

function y = compute_rho_h(z, h)
% Bump function do paper [OS1, Eq. 10]. Argumento z ja normalizado.
    if z < h
        y = 1;
    elseif z <= 1
        y = 0.5 * (1 + cos(pi * (z - h) / (1 - h)));
    else
        y = 0;
    end
end

function y = compute_phi_beta(z, d_beta, h)
% Funcao de acao repulsiva [OS1, Eq. 56]:
%   phi_beta(z) = rho_h(z/d_beta) * (sigma_1(z - d_beta) - 1)
% com sigma_1(z) = z/sqrt(1+z^2). Vale phi_beta <= 0, anula-se suavemente
% em z = d_beta e permanece zero para z >= d_beta (cut-off finito).
    if z >= d_beta
        y = 0;
    else
        rho = compute_rho_h(z / d_beta, h);
        w   = z - d_beta;
        s1  = w / sqrt(1 + w*w);
        y   = rho * (s1 - 1);
    end
end