function [command_upper_s, control_mode_s] = Reynolds_module_generate_desire(...
    t, states, sample_time, sensor_data_s, map3d_struct, terrain, terrain_params)
%REYNOLDS_MODULE_GENERATE_DESIRE  Reynolds Boids flocking controller.
%
% Coder-compatible version for Simulink High-fidelity Simulation.
% All loops use A:B form. No find() in loop iterators.
%
% References:
%   [R1] Reynolds (1987), ACM SIGGRAPH 21(4), 25-34.
%   [R2] Hoang et al. (2021), PeerJ Comp. Sci. 7:e388.
%   [R3] Debnath et al. (2025), Machines 13(4):255.
%   [R4] Vasarhelyi et al. (2018), Science Robotics 3(20):eaat3536.
%   [R5] Vicsek et al. (1995), Phys. Rev. Lett. 75(6), 1226.
%
% control_mode = 7 = VELOCITY_HORIZONTAL_CONTROL_TYPE

persistent fun_params
if isempty(fun_params)
    file_name_param = 'Reynolds_module_parameters';
    [~, str_core] = get_multi_core_value();
    fun_params = str2func([file_name_param, str_core]);
end

[r_com, v_flock, w_sep, w_ali, w_coh, w_shill, r_sep, r_shill, ...
 v_max, dim, height, dr_shill, pos_shill, vel_shill] = fun_params();

% Prepare shill agents XY
M_shill = size(pos_shill, 2);
if ~isempty(pos_shill) && size(pos_shill, 1) >= 2
    p_shill_x = pos_shill(1, :);
    p_shill_y = pos_shill(2, :);
else
    p_shill_x = zeros(1, 0);
    p_shill_y = zeros(1, 0);
    M_shill = 0;
end

number = size(states, 2);
command_upper_s = zeros(12, number);
command_upper_s(1:3, :) = states(1:3, :);
control_mode_s = uint8(zeros(1, number)) + 7;

% Traverse every agent
for id = 1:number
    px_i = states(1, id);
    py_i = states(2, id);
    vx_i = states(4, id);
    vy_i = states(5, id);

    % === SEPARATION, ALIGNMENT, COHESION ===
    % Computed in a single Coder-compatible loop over all agents
    f_sep_x = 0;  f_sep_y = 0;
    f_ali_x = 0;  f_ali_y = 0;
    f_coh_x = 0;  f_coh_y = 0;
    n_neighbors = 0;

    for j = 1:number
        if j ~= id
            dx = states(1, j) - px_i;
            dy = states(2, j) - py_i;
            d = sqrt(dx*dx + dy*dy);

            if d <= r_com
                % This agent is a neighbor
                n_neighbors = n_neighbors + 1;

                % ALIGNMENT [R1]: accumulate neighbor velocities
                f_ali_x = f_ali_x + states(4, j);
                f_ali_y = f_ali_y + states(5, j);

                % COHESION [R1]: accumulate neighbor positions
                f_coh_x = f_coh_x + states(1, j);
                f_coh_y = f_coh_y + states(2, j);

                % SEPARATION [R1]: repel if within r_sep
                if d < r_sep
                    d_safe = max(d, 0.01);
                    f_sep_x = f_sep_x - dx / (d_safe * d_safe);
                    f_sep_y = f_sep_y - dy / (d_safe * d_safe);
                end
            end
        end
    end

    % Finalize alignment: mean(v_neighbors) - v_i
    if n_neighbors > 0
        f_ali_x = f_ali_x / n_neighbors - vx_i;
        f_ali_y = f_ali_y / n_neighbors - vy_i;
        % Finalize cohesion: mean(x_neighbors) - x_i
        f_coh_x = f_coh_x / n_neighbors - px_i;
        f_coh_y = f_coh_y / n_neighbors - py_i;
    else
        f_ali_x = 0;  f_ali_y = 0;
        f_coh_x = 0;  f_coh_y = 0;
    end

    % === SHILL REPULSION [R4] ===
    % Uses r_shill as perception radius (independent from r_com)
    f_sh_x = 0;  f_sh_y = 0;

    for s = 1:M_shill
        dx_s = p_shill_x(s) - px_i;
        dy_s = p_shill_y(s) - py_i;
        d_s = sqrt(dx_s*dx_s + dy_s*dy_s);

        if d_s < r_shill
            d_safe_s = max(d_s, 0.01);
            f_sh_x = f_sh_x - dx_s / (d_safe_s * d_safe_s);
            f_sh_y = f_sh_y - dy_s / (d_safe_s * d_safe_s);
        end
    end

    % === COMBINE FORCES [R1, R2] ===
    fx = w_sep*f_sep_x + w_ali*f_ali_x + w_coh*f_coh_x + w_shill*f_sh_x;
    fy = w_sep*f_sep_y + w_ali*f_ali_y + w_coh*f_coh_y + w_shill*f_sh_y;

    % === SELF-PROPULSION + SPEED REGULATION [R5] ===
    current_speed = sqrt(vx_i*vx_i + vy_i*vy_i);

    if current_speed > 0.05
        % Drone is moving: current heading + steering from forces
        hx = vx_i / current_speed;
        hy = vy_i / current_speed;
        vdx = v_flock * hx + 0.3 * fx;
        vdy = v_flock * hy + 0.3 * fy;
    else
        % Drone is nearly stopped: use forces as direction
        fn = sqrt(fx*fx + fy*fy);
        if fn > 0.01
            vdx = fx;
            vdy = fy;
        else
            % Small perturbation to break symmetry
            vdx = 0.1 * v_flock;
            vdy = 0.05 * v_flock;
        end
    end

    % Normalize to v_flock [R4, Eq. 10]
    sp = sqrt(vdx*vdx + vdy*vdy);
    if sp > 0.001
        target_speed = v_flock;
        if target_speed > v_max
            target_speed = v_max;
        end
        vdx = target_speed * vdx / sp;
        vdy = target_speed * vdy / sp;
    end

    % === PACK OUTPUT ===
    pos_desired_id = [states(1:3, id); 0];
    pos_desired_id(3) = height;          % Z altitude hold via position (mode 7)
    vel_desired_id = [vdx; vdy; 0; 0];  % XY velocity; Z=0 for mode 7
    acc_desired_id = [0; 0; 0; 0];

    command_upper_s(:, id) = [pos_desired_id; vel_desired_id; acc_desired_id];
end
end