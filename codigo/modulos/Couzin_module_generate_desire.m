function [command_upper_s, control_mode_s] = Couzin_module_generate_desire(...
    t, states, sample_time, sensor_data_s, map3d_struct, terrain, terrain_params)
%COUZIN_MODULE_GENERATE_DESIRE  Couzin (2002) three-zone flocking controller.
%
% Implements the Couzin model with three concentric zones and
% lexicographic priority: if ANY neighbor is in the Zone of Repulsion,
% ONLY repulsion is applied. Otherwise, orientation and attraction
% are combined. This priority rule guarantees collision avoidance
% without needing to tune relative weights.
%
% Zones (2D, centered on each drone):
%   ZOR: 0 < d < r_r       — Zone of Repulsion (highest priority)
%   ZOO: r_r <= d < r_o     — Zone of Orientation (velocity alignment)
%   ZOA: r_o <= d < r_a     — Zone of Attraction (flock centering)
%
% Obstacle avoidance: shill agents within r_shill are treated as
% neighbors in the Zone of Repulsion, preserving the lexicographic
% priority (safety always overrides social forces).
%
% Self-propulsion: constant-speed model (Vicsek 1995) — the Couzin
% forces determine DIRECTION, speed is normalized to v_flock.
% Same architecture validated for Reynolds and Olfati-Saber.
%
% References:
%   [CZ1] Couzin et al. (2002), J. Theor. Biol. 218(1), 1-11.
%   [CZ2] Couzin et al. (2005), Nature 433, 513-516.
%   [CZ3] Keysberg & Wakamiya (2025), Artif. Life Robot. 30:219-226.
%   [CZ4] Verdoucq et al. (2025), arXiv:2512.21196.
%   [CZ5] Vicsek et al. (1995), Phys. Rev. Lett. 75(6), 1226.
%   [CZ6] Vasarhelyi et al. (2018), Science Robotics 3(20):eaat3536.

persistent fun_params
if isempty(fun_params)
    file_name_param = 'Couzin_module_parameters';
    [~, str_core] = get_multi_core_value();
    fun_params = str2func([file_name_param, str_core]);
end

% Load all 12 parameters (order matches auto-generated file)
[r_r, ...           % 1.  Zone of Repulsion radius (m) [CZ1]
 r_o, ...           % 2.  Zone of Orientation outer radius (m) [CZ1]
 r_a, ...           % 3.  Zone of Attraction outer radius (m) [CZ1]
 alpha_couzin, ...  % 4.  Field of view angle (degrees) [CZ1]
 v_flock, ...       % 5.  Constant speed (m/s) [CZ5]
 r_shill, ...       % 6.  Shill perception radius (m) [CZ6]
 w_shill, ...       % 7.  Shill repulsion weight [CZ6]
 dim, ...           % 8.  Dimensionality (2=indoor XY)
 height, ...        % 9.  Reference altitude (m)
 dr_shill, ...      % 10. Shill spacing (m)
 pos_shill, ...     % 11. Shill positions [2 x M]
 vel_shill ...      % 12. Shill velocities [2 x M]
] = fun_params();

% Precompute cosine of half field-of-view for blind volume check
% Visible if: dot(heading, dir_to_neighbor) > cos(alpha/2)
% alpha=300 deg → half=150 deg → cos(150)=-0.866 → almost full vision
cos_half_alpha = cos(alpha_couzin * pi / 360);  % degrees to radians, halved

% Prepare shill agents XY
M_shill = size(pos_shill, 2);
if ~isempty(pos_shill) && size(pos_shill, 1) >= 2
    p_sh_x = pos_shill(1, :);
    p_sh_y = pos_shill(2, :);
else
    p_sh_x = zeros(1, 0);
    p_sh_y = zeros(1, 0);
    M_shill = 0;
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

    % Current heading (unit vector of velocity) for blind volume check
    speed_i = sqrt(vx_i*vx_i + vy_i*vy_i);
    if speed_i > 0.01
        hx_i = vx_i / speed_i;
        hy_i = vy_i / speed_i;
    else
        % Nearly stopped: assume heading in +X (arbitrary but consistent)
        hx_i = 1.0;
        hy_i = 0.0;
    end

    % Accumulators for the three zone contributions
    % ZOR: repulsion direction (away from too-close neighbors)
    dr_x = 0; dr_y = 0; n_zor = 0;
    % ZOO: orientation direction (average heading of medium-range neighbors)
    do_x = 0; do_y = 0; n_zoo = 0;
    % ZOA: attraction direction (toward far-range neighbors)
    da_x = 0; da_y = 0; n_zoa = 0;

    %% ============================================================
    %  SCAN ALL OTHER DRONES — classify into zones [CZ1, Eq. 1-3]
    %  ============================================================
    for j = 1:number
        if j == id
            continue;
        end

        % Vector from i to j
        dx = states(1, j) - px_i;
        dy = states(2, j) - py_i;
        d = sqrt(dx*dx + dy*dy);

        if d < 1e-6 || d >= r_a
            continue;  % Too close (overlapping) or too far
        end

        % Blind volume check [CZ1]: is neighbor j visible?
        % Visible if angle between heading and direction to j < alpha/2
        % Equivalent: dot(heading, dir_to_j) > cos(alpha/2)
        dir_x = dx / d;
        dir_y = dy / d;
        dot_val = hx_i * dir_x + hy_i * dir_y;

        if dot_val < cos_half_alpha
            continue;  % Neighbor is in the blind volume behind the drone
        end

        % Classify neighbor into zone [CZ1]
        if d < r_r
            % ZONE OF REPULSION: accumulate direction AWAY from neighbor
            % d_r = -sum(r_ij / |r_ij|) [CZ1, Eq. 1]
            dr_x = dr_x - dir_x;
            dr_y = dr_y - dir_y;
            n_zor = n_zor + 1;

        elseif d < r_o
            % ZONE OF ORIENTATION: accumulate neighbor heading
            % d_o = sum(v_j / |v_j|) [CZ1, Eq. 2]
            speed_j = sqrt(states(4,j)^2 + states(5,j)^2);
            if speed_j > 0.01
                do_x = do_x + states(4, j) / speed_j;
                do_y = do_y + states(5, j) / speed_j;
            else
                do_x = do_x + hx_i;  % Stationary neighbor: use own heading
                do_y = do_y + hy_i;
            end
            n_zoo = n_zoo + 1;

        else  % d < r_a (guaranteed by the continue above)
            % ZONE OF ATTRACTION: accumulate direction TOWARD neighbor
            % d_a = sum(r_ij / |r_ij|) [CZ1, Eq. 3]
            da_x = da_x + dir_x;
            da_y = da_y + dir_y;
            n_zoa = n_zoa + 1;
        end
    end

    %% ============================================================
    %  SHILL AGENTS — treated as ZOR neighbors [CZ6, adapted]
    %  Shill agents on obstacle/wall surfaces enter the Zone of
    %  Repulsion, preserving the lexicographic priority: obstacle
    %  avoidance always overrides orientation and attraction.
    %  Uses r_shill as perception radius (independent from r_r).
    %  ============================================================
    for s = 1:M_shill
        dx_s = p_sh_x(s) - px_i;
        dy_s = p_sh_y(s) - py_i;
        d_s = sqrt(dx_s*dx_s + dy_s*dy_s);

        if d_s < r_shill && d_s > 1e-6
            % Shill agents always contribute to ZOR (repulsion)
            % with additional weight w_shill for stronger wall avoidance
            dr_x = dr_x - w_shill * dx_s / d_s;
            dr_y = dr_y - w_shill * dy_s / d_s;
            n_zor = n_zor + 1;
        end
    end

    %% ============================================================
    %  LEXICOGRAPHIC PRIORITY — the core of Couzin [CZ1]
    %
    %  "If there are any neighbors in ZOR, the individual attempts
    %  to move away from them [...] If there are no neighbors in
    %  ZOR, the individual responds to those in ZOO and ZOA."
    %
    %  This priority rule is what makes Couzin fundamentally
    %  different from Reynolds (weighted sum) and Olfati-Saber
    %  (smooth potential): safety is NEVER compromised by social
    %  forces, regardless of parameter values.
    %  ============================================================
    dx_desired = 0;
    dy_desired = 0;

    if n_zor > 0
        % PRIORITY: repulsion only — ignore orientation and attraction
        dx_desired = dr_x;
        dy_desired = dr_y;

    else
        % No immediate collision threat: combine orientation and attraction
        has_zoo = (n_zoo > 0);
        has_zoa = (n_zoa > 0);

        if has_zoo && has_zoa
            % Both zones active: average of orientation and attraction [CZ1]
            dx_desired = 0.5 * (do_x + da_x);
            dy_desired = 0.5 * (do_y + da_y);
        elseif has_zoo
            % Only orientation
            dx_desired = do_x;
            dy_desired = do_y;
        elseif has_zoa
            % Only attraction
            dx_desired = da_x;
            dy_desired = da_y;
        else
            % No neighbors visible: maintain current heading [CZ1]
            dx_desired = hx_i;
            dy_desired = hy_i;
        end
    end

    %% ============================================================
    %  SELF-PROPULSION — Constant speed model [CZ1, CZ5]
    %
    %  "Each individual moves at a constant speed s" (Couzin 2002).
    %  The desired direction is normalized and multiplied by v_flock.
    %  Same architecture validated for Reynolds and Olfati-Saber.
    %
    %  When starting from rest: use desired direction as initial kick.
    %  When moving: blend current heading with desired direction
    %  for smooth transitions (equivalent to theta_dot_max limiting).
    %  ============================================================
    steering_gain = 0.5;  % How quickly drone turns toward desired direction
                          % Higher = more responsive, Lower = smoother

    if speed_i > 0.05
        % Moving: blend current heading with desired direction
        vdx = v_flock * hx_i + steering_gain * dx_desired;
        vdy = v_flock * hy_i + steering_gain * dy_desired;
    else
        % Nearly stopped: use desired direction as velocity
        d_norm = sqrt(dx_desired*dx_desired + dy_desired*dy_desired);
        if d_norm > 0.01
            vdx = v_flock * dx_desired / d_norm;
            vdy = v_flock * dy_desired / d_norm;
        else
            % Absolute fallback: small push
            vdx = v_flock * 0.7;
            vdy = v_flock * 0.3;
        end
    end

    % Normalize to constant speed v_flock [CZ1, CZ5]
    sp = sqrt(vdx*vdx + vdy*vdy);
    if sp > 0.001
        vdx = v_flock * vdx / sp;
        vdy = v_flock * vdy / sp;
    end

    %% PACK OUTPUT (same format as Reynolds and Olfati-Saber)
    pos_desired_id = [states(1:3, id); 0];
    pos_desired_id(3) = height;          % Z altitude hold (mode 7)
    vel_desired_id = [vdx; vdy; 0; 0];  % XY velocity command
    acc_desired_id = [0; 0; 0; 0];
    command_upper_s(:, id) = [pos_desired_id; vel_desired_id; acc_desired_id];
end
end