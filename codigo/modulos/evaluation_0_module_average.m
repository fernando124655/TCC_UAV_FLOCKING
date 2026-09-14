function values = evaluation_0_module_average(time_series, values_series)
%EVALUATION_0_MODULE_AVERAGE  Metricas medias do processo completo.
%
% MODIFICADO: v_tol passa de 0 para o valor do paper (Vasarhelyi et al.,
% 2018), necessario para que o termo de velocidade da fitness seja a
% sigmoide limitada F1 em vez de uma funcao degrau.
%
% Ordem de retorno: [F; phiCorr; phiVel; phiColl; phiWall; phiMND]

file_name_param = 'evaluation_0_module_parameters';
[~,str_core] = get_multi_core_value();
fun_params = str2func([file_name_param, str_core]);

[v_flock,...
r_coll,...
a_tol] = fun_params();

% Tolerancias conforme Vasarhelyi et al. (2018), secao "Fitness function":
%   v_tol = 1.5/4 * v_flock ; a_tol = 0.00003 ; r_tol = 2 m
% a_tol vem do XML. r_tol permanece 0 porque o termo de parede usa F3
% (que consome a_tol), nao o F2 do paper -- desvio herdado do CoFlyers.
v_tol = 1.5/4 * v_flock;
r_tol = 0;

phiCorr = mean(values_series(1,:));
phiVel  = mean(values_series(2,:));
phiColl = mean(values_series(3,:));
phiWall = mean(values_series(4,:));
phiMND  = mean(values_series(5,:));

[~,~,~,~,F] = fitness_function_combine(v_flock,a_tol,v_tol,r_tol,phiVel, ...
    phiColl,phiWall,phiCorr);

values = [F;phiCorr;phiVel;phiColl;phiWall;phiMND];
end
