function T = tempo_de_parede(padrao, pausa_min)
%TEMPO_DE_PAREDE  Tempo de parede de uma etapa, pelos arquivos que ela gravou.
%
%   T = tempo_de_parede(PADRAO) procura os arquivos que casam com PADRAO
%   (o ** procura em subpastas) e, em cada .mat, lê o horário que o MATLAB
%   escreve no cabeçalho ao salvar ("Created on: ..."). Esse horário não
%   muda quando o arquivo é copiado, compactado ou enviado, ao contrário
%   da data do arquivo. Para os outros arquivos (logs, .launch), usa a
%   data da última gravação e, no Windows, também a de criação, que num
%   log do diary marca o início da execução.
%
%   Também mostra o que os scripts de produção já gravam:
%     - elapsed (main_batch_production, main_monte_carlo_...): duração total;
%     - t_seed (main_auto_tuning_production): duração de cada semente do AG;
%     - run_times: duração de cada execução;
%     - o início no nome do arquivo (_AAAAMMDD_HHMMSS), que esses scripts
%       geram antes de começar; com o fim do cabeçalho, dá a duração.
%
%   T = tempo_de_parede(PADRAO, PAUSA_MIN) trata como pausa um intervalo
%   maior que PAUSA_MIN minutos entre gravações seguidas (padrão: 20). O
%   tempo ativo soma os intervalos curtos e, para o primeiro arquivo de
%   cada sessão, cujo início não fica registrado, a mediana deles. Se cada
%   arquivo for um lote mais longo que a pausa (todos os intervalos com *),
%   não há intervalo curto para a mediana: rode de novo com uma pausa
%   maior que um lote, ou use a soma dos tempos gravados nos arquivos, que
%   o resumo mostra quando eles existem.
%
%   Exemplos, na pasta Prototype_Simulator:
%     tempo_de_parede('data_save/**/hifi_*.mat', 20)   % alta fidelidade
%     tempo_de_parede('**/rs_Vasarhelyi_*.mat', 40)    % ruído, 19/10
%     tempo_de_parede('**/rs19_*.mat', 40)             % ruído, 20/10
%     tempo_de_parede('data_save/tc_sweep/tc_*_cilindros.mat', 60)  % varredura de Tc
%     tempo_de_parede('data_save/auto_tuning_production/at_Vasarhelyi_*.mat')
%     tempo_de_parede('**/*.txt')                      % logs do diary
%
%   Escrito para o TCC de Fernando Souza Rodrigues (27/10/2026; revisto
%   em 28/10: resumo sem intervalos curtos e soma dos tempos gravados).

if nargin < 2 || isempty(pausa_min)
    pausa_min = 20;
end

d = dir(padrao);
d = d(~[d.isdir]);
if isempty(d)
    error('Nenhum arquivo casa com "%s" (pasta atual: %s).', padrao, pwd);
end

n = numel(d);
nome   = cell(n, 1);
fim    = zeros(n, 1);      % datenum do fim (cabeçalho do .mat ou data do arquivo)
origem = cell(n, 1);
inicio = nan(n, 1);        % datenum do início, quando o nome traz o stamp
criado = nan(n, 1);        % datenum de criação (Windows)
medida = cell(n, 1);
gravado_h = nan(n, 1);     % duração gravada no próprio arquivo, em horas
fonte_h = cell(n, 1);

for k = 1:n
    arq = fullfile(d(k).folder, d(k).name);
    nome{k} = d(k).name;
    medida{k} = '';
    [fim(k), origem{k}] = horario_gravado(arq, d(k).datenum);

    tk = regexp(d(k).name, '_(\d{8})_(\d{6})', 'tokens', 'once');
    if ~isempty(tk)
        inicio(k) = datenum([tk{1} tk{2}], 'yyyymmddHHMMSS');
    end

    if ispc
        try
            c = System.IO.File.GetCreationTime(arq);
            criado(k) = datenum(double(c.Year), double(c.Month), double(c.Day), ...
                double(c.Hour), double(c.Minute), double(c.Second));
        catch
        end
    end

    [~, ~, ext] = fileparts(arq);
    if strcmpi(ext, '.mat')
        [medida{k}, gravado_h(k), fonte_h{k}] = medidas_gravadas(arq);
    end
end

[fim, ordem] = sort(fim);
nome = nome(ordem); origem = origem(ordem); inicio = inicio(ordem);
criado = criado(ordem); medida = medida(ordem);
gravado_h = gravado_h(ordem); fonte_h = fonte_h(ordem);

intervalo = [NaN; diff(fim) * 24 * 60];          % minutos
pausa = intervalo > pausa_min;
curtos = intervalo(~isnan(intervalo) & ~pausa);
if isempty(curtos)
    mediana = NaN;
else
    mediana = median(curtos);
end
sessoes = 1 + sum(pausa);
ativo_h = (sum(curtos) + sessoes * mediana) / 60;

fprintf('\n%s\n', padrao);
fprintf('%-42s %-20s %10s  %s\n', 'arquivo', 'gravado em', 'interv.', 'outras medidas');
for k = 1:n
    if isnan(intervalo(k))
        iv = '';
    elseif pausa(k)
        iv = sprintf('%.1f min*', intervalo(k));
    else
        iv = sprintf('%.1f min', intervalo(k));
    end
    extra = medida{k};
    if ~isnan(inicio(k))
        extra = sprintf('%s início no nome %s -> %.2f h', extra, ...
            datestr(inicio(k), 'dd/mm HH:MM:SS'), (fim(k) - inicio(k)) * 24);
    end
    if ~isnan(criado(k)) && ~strcmp(origem{k}, 'cabeçalho')
        extra = sprintf('%s criado %s -> %.2f h', extra, ...
            datestr(criado(k), 'dd/mm HH:MM:SS'), (fim(k) - criado(k)) * 24);
    end
    marca = '';
    if ~strcmp(origem{k}, 'cabeçalho')
        marca = ' (data do arquivo)';
    end
    fprintf('%-42s %-20s %10s  %s%s\n', nome{k}, datestr(fim(k), 'dd/mm/yyyy HH:MM:SS'), iv, strtrim(extra), marca);
end

fprintf('\n%d arquivos, de %s a %s (%.2f h entre o primeiro e o último).\n', n, ...
    datestr(fim(1), 'dd/mm HH:MM'), datestr(fim(end), 'dd/mm HH:MM'), (fim(end) - fim(1)) * 24);
if n > 1 && ~isempty(curtos)
    fprintf('Intervalo entre gravações seguidas: mediana %.1f min (de %.1f a %.1f), sem as pausas acima de %g min (*).\n', ...
        mediana, min(curtos), max(curtos), pausa_min);
    fprintf('Sessões: %d. Tempo ativo estimado: %.2f h (intervalos curtos + 1 mediana por sessão).\n', ...
        sessoes, ativo_h);
elseif n > 1
    fprintf(['Todos os intervalos passam de %g min (*): cada arquivo parece ser um lote mais longo que a pausa.\n' ...
        'Para o tempo ativo, rode de novo com uma pausa maior que um lote, por exemplo:\n' ...
        '  tempo_de_parede(''%s'', %d)\n'], pausa_min, padrao, ceil(1.5 * median(intervalo(2:end)) / 10) * 10);
end
tem = ~isnan(gravado_h);
if any(tem)
    fontes = unique(fonte_h(tem));
    fprintf('Soma das durações gravadas nos arquivos (%s): %.2f h, em %d de %d arquivos.\n', ...
        strjoin(fontes, ', '), sum(gravado_h(tem)), sum(tem), n);
end
fprintf('O horário é o do relógio do computador que gravou o arquivo.\n\n');

if nargout > 0
    T = table(nome, cellstr(datestr(fim, 'dd/mm/yyyy HH:MM:SS')), intervalo, pausa, origem, medida, ...
        'VariableNames', {'arquivo', 'gravado_em', 'intervalo_min', 'pausa', 'origem', 'medidas'});
end
end


function [t, origem] = horario_gravado(arq, data_arquivo)
% Horário do cabeçalho de um .mat (v5, v7 ou v7.3); se não houver, a data do arquivo.
t = data_arquivo;
origem = 'data do arquivo';
fid = fopen(arq, 'r');
if fid < 0
    return
end
bytes = fread(fid, [1 116], 'uint8');   % texto do cabeçalho de um .mat
fclose(fid);
bytes(bytes < 32 | bytes > 126) = 32;    % só caracteres ASCII imprimíveis
cab = char(bytes);
tok = regexp(cab, 'Created on:\s*\w{3}\s+(\w{3})\s+(\d{1,2})\s+(\d{1,2}:\d{2}:\d{2})\s+(\d{4})', 'tokens', 'once');
if isempty(tok)
    return
end
texto = sprintf('%s %02d %s %s', tok{1}, str2double(tok{2}), tok{4}, tok{3});
try
    t = datenum(texto, 'mmm dd yyyy HH:MM:SS');
    origem = 'cabeçalho';
catch
end
end


function [s, horas, fonte] = medidas_gravadas(arq)
% Variáveis de tempo que os scripts de produção gravam. HORAS é a duração
% do arquivo, pela primeira que existir: elapsed, soma de t_seed ou soma de
% run_times (NaN se nenhuma).
s = '';
horas = NaN;
fonte = '';
try
    w = whos('-file', arq);
catch
    return
end
nomes = {w.name};
if any(strcmp(nomes, 'run_times'))
    x = load(arq, 'run_times');
    v = double(x.run_times(:));
    s = sprintf('%s %d execuções, média %.1f s, soma %.2f h;', s, numel(v), mean(v), sum(v) / 3600);
    horas = sum(v) / 3600;
    fonte = 'run_times';
end
if any(strcmp(nomes, 't_seed'))
    x = load(arq, 't_seed');
    v = double(x.t_seed(:)');
    s = sprintf('%s t_seed = [%s] min, soma %.2f h;', s, sprintf(' %.1f', v / 60), sum(v) / 3600);
    horas = sum(v) / 3600;
    fonte = 't_seed';
end
if any(strcmp(nomes, 'elapsed'))
    x = load(arq, 'elapsed');
    s = sprintf('%s elapsed = %.2f h;', s, double(x.elapsed) / 3600);
    horas = double(x.elapsed) / 3600;
    fonte = 'elapsed';
end
end
