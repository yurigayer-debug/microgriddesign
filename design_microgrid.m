% ==================================================================================================
% SIMULAÇÃO OTIMIZAÇÃO LCOE E AUTONOMIA DE MICRORREDES HÍBRIDAS (ON-GRID / OFF-GRID)
% ==================================================================================================
%
% Autor: Eng. Eletricista Yuri Escobar Gayer
  Mestrando: Engenharia Eletrônica e Computação - yurigayer@gmail.com
  Prof. Orientador: Lizandro de Souza Oliveira % lizandro.oliveira@ucpel.edu.br
% ==================================================================================================
% SEÇÃO 1: INICIALIZAÇÃO E PARÂMETROS DE ENTRADA
% ==================================================================================================
clear all;
close all;
clc;
format short g; % Define o formato de exibição dos números.
pkg load statistics; % Carrega o pacote de estatísticas.

% --- 1.1: Perfil de Carga (ENTRADAS PRINCIPAIS DA CARGA) ---
consumo_medio_mensal_kwh = 720; % [kWh/mês] Defina aqui o consumo médio mensal da carga.
pico_carga_kw_informado =2;  % [kW] Defina aqui o pico de carga esperado (para referência).

% --- 1.2: Parâmetros Financeiros ---
vida_util_projeto = 25; % [anos]
taxa_desconto = 0.08;   % [fração]

% --- 1.3: Parâmetros da Rede Elétrica (Grid) ---
tarifa_compra_energia = 0.85; % [R$/kWh]
tarifa_venda_energia = 0.75;  % [R$/kWh]

% --- 1.4: Parâmetros dos Componentes ---
custo_pv_por_kw = 3500; custo_om_pv_anual = 500; fator_derating_pv = 0.85; vida_util_pv = 25;
custo_bateria_por_kwh = 1200; custo_om_bateria_anual = 300; vida_util_bateria_ciclos = 6000;
profundidade_max_descarga = 0.80; eficiencia_bateria = 0.90;
custo_gerador_por_kw = 1300; custo_om_gerador_horario = 2.0; vida_util_gerador_horas = 15000;
custo_combustivel = 6.5; consumo_curva_A = 0.240; consumo_curva_B = 0.060;
fator_carga_otima_gerador = 0.80;

% ==================================================================================================
% SEÇÃO 2: GERAÇÃO E ANÁLISE DOS DADOS DE ENTRADA
% ==================================================================================================
horas_no_ano = 8760;
vetor_tempo = (1:horas_no_ano)';
disp('Gerando perfil de carga realista baseado no padrão residencial...');
perfil_diario_tipico_residencial = [0.35; 0.30; 0.28; 0.25; 0.28; 0.45; 0.65; 0.70; 0.60; 0.55; 0.50; 0.55; 0.58; 0.55; 0.50; 0.55; 0.65; 0.85; 1.00; 0.95; 0.80; 0.70; 0.55; 0.45];
consumo_medio_diario = consumo_medio_mensal_kwh / 30.42;
fator_escala_potencia = pico_carga_kw_informado / max(perfil_diario_tipico_residencial);
perfil_diario_base_kw = perfil_diario_tipico_residencial * fator_escala_potencia;
carga_horaria_base_anual = repmat(perfil_diario_base_kw, 365, 1);
carga_horaria_base_anual = [carga_horaria_base_anual; carga_horaria_base_anual(1:(horas_no_ano - 365*24))];
carga_horaria_base_anual = carga_horaria_base_anual(1:horas_no_ano);
fator_sazonal = 1.1 + 0.15*cos(2*pi*vetor_tempo/horas_no_ano);
fator_aleatorio = 1 + 0.1*(rand(horas_no_ano, 1) - 0.5);
carga_horaria_kW = carga_horaria_base_anual .* fator_sazonal .* fator_aleatorio;

consumo_total_anual_calc = sum(carga_horaria_kW);
consumo_medio_mensal_calc = consumo_total_anual_calc / 12;
demanda_maxima_kw_calc = max(carga_horaria_kW);
demanda_media_kw_calc = mean(carga_horaria_kW);
fator_de_carga_calc = demanda_media_kw_calc / demanda_maxima_kw_calc;

disp('Gerando perfil de irradiação solar realista para Pelotas/RS...');
media_ghi_mensal_kwh_m2_dia = [5.5, 5.1, 4.3, 3.3, 2.5, 2.1, 2.3, 2.9, 3.6, 4.5, 5.2, 5.6];
dias_no_mes = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
vetor_dia_do_ano = floor((vetor_tempo-1)/24) + 1;
irradiacao_horaria_W_m2 = zeros(horas_no_ano, 1);
dia_atual = 0;
for mes = 1:12
    ghi_diario_mes = media_ghi_mensal_kwh_m2_dia(mes);
    pico_irradiacao_W_m2 = (ghi_diario_mes * pi / 24) * 1000;
    for dia = 1:dias_no_mes(mes)
        dia_atual = dia_atual + 1;
        if dia_atual > 365, continue; end
        horas_do_dia = find(vetor_dia_do_ano == dia_atual);
        for hora_indice = 1:24
            hora_atual = horas_do_dia(hora_indice);
            hora_do_dia = mod(hora_indice - 1, 24);
            if (hora_do_dia >= 6 && hora_do_dia < 18), irradiacao_horaria_W_m2(hora_atual) = pico_irradiacao_W_m2 * sin(pi * (hora_do_dia - 6) / 12);
            else, irradiacao_horaria_W_m2(hora_atual) = 0; end
        end
    end
end
irradiacao_horaria_W_m2(irradiacao_horaria_W_m2 < 0) = 0;
disp('SEÇÃO 1 e 2: Parâmetros e dados carregados e analisados.');
disp(' ');

% ==================================================================================================
% SEÇÃO 3: DEFINIÇÃO DO ESPAÇO DE BUSCA
% ==================================================================================================
vetor_tamanho_pv_kw = [10.64];
vetor_tamanho_bateria_kwh = [10,15,20,25,30,35,40];
vetor_tamanho_gerador_kw = [12];
[P, B, G] = ndgrid(vetor_tamanho_pv_kw, vetor_tamanho_bateria_kwh, vetor_tamanho_gerador_kw);
combinacoes = [P(:), B(:), G(:)];
num_combinacoes = size(combinacoes, 1);
disp(['SEÇÃO 3: Espaço de busca definido. Serão simuladas ' num2str(num_combinacoes) ' configurações em 2 modos de operação.']);
disp(' ');

% ==================================================================================================
% SEÇÃO 4: LOOP PRINCIPAL DE SIMULAÇÃO E ANÁLISE
% ==================================================================================================
resultados_grid = []; resultados_offgrid = [];
custo_marginal_gerador = consumo_curva_A * custo_combustivel;
for modo_operacao = 1:2
    if modo_operacao == 1, conectado_a_rede = true; disp('SEÇÃO 4: Iniciando simulação para MODO CONECTADO À REDE...');
    else, conectado_a_rede = false; disp('SEÇÃO 4: Iniciando simulação para MODO ILHADO (OFF-GRID)...'); end
    resultados_modo_atual = zeros(num_combinacoes, 16);
    tic;
    for i = 1:num_combinacoes
        fprintf('... Progresso: %d/%d (%.0f%%)\r', i, num_combinacoes, 100*i/num_combinacoes);
        pv_kw = combinacoes(i, 1); bateria_kwh = combinacoes(i, 2); gerador_kw = combinacoes(i, 3);
        energia_pv_gerada_kwh=zeros(horas_no_ano,1); energia_bateria_descarga_kwh=zeros(horas_no_ano,1);
        energia_bateria_carga_kwh=zeros(horas_no_ano,1); energia_gerador_kwh=zeros(horas_no_ano,1);
        energia_nao_atendida_kwh=zeros(horas_no_ano,1); energia_curtailment_pv_kwh=zeros(horas_no_ano,1);
        combustivel_consumido_litros=zeros(horas_no_ano,1); horas_operacao_gerador=0;
        soc_bateria=ones(horas_no_ano+1,1); energia_importada_grid_kwh=zeros(horas_no_ano,1);
        energia_exportada_grid_kwh=zeros(horas_no_ano,1);

     for h = 1:horas_no_ano
            soc_bateria(h) = soc_bateria(h);
            energia_pv_gerada_kwh(h) = (irradiacao_horaria_W_m2(h) / 1000) * pv_kw * fator_derating_pv;
            balanco_kwh = energia_pv_gerada_kwh(h) - carga_horaria_kW(h);
            if conectado_a_rede
                if balanco_kwh >= 0, energia_para_carga_max = (1 - soc_bateria(h)) * bateria_kwh / eficiencia_bateria; energia_bateria_carga_kwh(h) = min(balanco_kwh, energia_para_carga_max); energia_exportada_grid_kwh(h) = balanco_kwh - energia_bateria_carga_kwh(h);
                else, deficit_kwh = -balanco_kwh; energia_disponivel_bateria = max(0, (soc_bateria(h) - (1-profundidade_max_descarga)) * bateria_kwh * eficiencia_bateria); energia_bateria_descarga_kwh(h) = min(deficit_kwh, energia_disponivel_bateria); deficit_restante_kwh = deficit_kwh - energia_bateria_descarga_kwh(h);
                    if deficit_restante_kwh > 0.01
                        if gerador_kw > 0 && custo_marginal_gerador < tarifa_compra_energia, potencia_gerador_despachada = gerador_kw * fator_carga_otima_gerador; energia_gerador_kwh(h) = potencia_gerador_despachada; energia_excedente_gerador = energia_gerador_kwh(h) - deficit_restante_kwh; if energia_excedente_gerador > 0, energia_para_carga_max = (soc_bateria(h) < 1) * (1 - soc_bateria(h)) * bateria_kwh / eficiencia_bateria; energia_bateria_carga_kwh(h) += min(energia_excedente_gerador, energia_para_carga_max); end, horas_operacao_gerador++; combustivel_consumido_litros(h) = consumo_curva_A * potencia_gerador_despachada + consumo_curva_B * gerador_kw;
                        else, energia_importada_grid_kwh(h) = deficit_restante_kwh; end
                    end
                end
            else
                if balanco_kwh >= 0, energia_para_carga_max = (1 - soc_bateria(h)) * bateria_kwh / eficiencia_bateria; energia_bateria_carga_kwh(h) = min(balanco_kwh, energia_para_carga_max); energia_curtailment_pv_kwh(h) = balanco_kwh - energia_bateria_carga_kwh(h);
                else, deficit_kwh = -balanco_kwh; energia_disponivel_bateria = max(0, (soc_bateria(h) - (1-profundidade_max_descarga)) * bateria_kwh * eficiencia_bateria); energia_bateria_descarga_kwh(h) = min(deficit_kwh, energia_disponivel_bateria); deficit_restante_kwh = deficit_kwh - energia_bateria_descarga_kwh(h);
                    if deficit_restante_kwh > 0.01 && gerador_kw > 0, potencia_gerador_despachada = gerador_kw * fator_carga_otima_gerador; energia_gerador_kwh(h) = potencia_gerador_despachada; energia_excedente_gerador = energia_gerador_kwh(h) - deficit_restante_kwh; if energia_excedente_gerador > 0, energia_para_carga_max = (soc_bateria(h) < 1) * (1 - soc_bateria(h)) * bateria_kwh / eficiencia_bateria; energia_bateria_carga_kwh(h) += min(energia_excedente_gerador, energia_para_carga_max); end, energia_nao_atendida_kwh(h) = 0; horas_operacao_gerador++; combustivel_consumido_litros(h) = consumo_curva_A * potencia_gerador_despachada + consumo_curva_B * gerador_kw;
                    else, energia_nao_atendida_kwh(h) = deficit_restante_kwh; end
                end
            end
            if bateria_kwh > 0, soc_bateria(h+1) = soc_bateria(h) + (energia_bateria_carga_kwh(h) * eficiencia_bateria / bateria_kwh) - (energia_bateria_descarga_kwh(h) / eficiencia_bateria / bateria_kwh); else, soc_bateria(h+1) = soc_bateria(h); end
        end
        custo_capital_total = (custo_pv_por_kw * pv_kw) + (custo_bateria_por_kwh * bateria_kwh) + (custo_gerador_por_kw * gerador_kw);
        custo_anual_combustivel = sum(combustivel_consumido_litros) * custo_combustivel;
        custo_om_anual = (custo_om_pv_anual*pv_kw) + (custo_om_bateria_anual*bateria_kwh) + (custo_om_gerador_horario*horas_operacao_gerador);
        if conectado_a_rede, custo_compra_grid_anual = sum(energia_importada_grid_kwh) * tarifa_compra_energia; receita_venda_grid_anual = sum(energia_exportada_grid_kwh) * tarifa_venda_energia; custo_operacional_anual_total = custo_om_anual + custo_anual_combustivel + custo_compra_grid_anual - receita_venda_grid_anual;
        else, custo_operacional_anual_total = custo_om_anual + custo_anual_combustivel; end
        ciclos_anuais = sum(energia_bateria_descarga_kwh) / max(1, bateria_kwh); vida_util_bateria_anos = vida_util_bateria_ciclos / max(1, ciclos_anuais); num_substituicoes_bateria = floor(vida_util_projeto / max(1, vida_util_bateria_anos));
        vida_util_gerador_anos = vida_util_gerador_horas / max(1, horas_operacao_gerador); num_substituicoes_gerador = floor(vida_util_projeto / max(1, vida_util_gerador_anos));
        custo_substituicao_presente = 0;
        if vida_util_bateria_anos > 0, for s = 1:num_substituicoes_bateria, custo_substituicao_presente += (custo_bateria_por_kwh*bateria_kwh) / ((1 + taxa_desconto)^(s * vida_util_bateria_anos)); end, end
        if vida_util_gerador_anos > 0, for s = 1:num_substituicoes_gerador, custo_substituicao_presente += (custo_gerador_por_kw*gerador_kw) / ((1 + taxa_desconto)^(s * vida_util_gerador_anos)); end, end
        fator_vp_anuidade = ((1+taxa_desconto)^vida_util_projeto - 1) / (taxa_desconto * (1+taxa_desconto)^vida_util_projeto);
        custo_operacional_presente = custo_operacional_anual_total * fator_vp_anuidade;
        custo_ciclo_vida_total = custo_capital_total + custo_substituicao_presente + custo_operacional_presente;
        energia_total_entregue_anual = sum(carga_horaria_kW) - sum(energia_nao_atendida_kwh);
        if energia_total_entregue_anual > 0, lcoe = custo_ciclo_vida_total / (energia_total_entregue_anual * fator_vp_anuidade); else, lcoe = inf; end
        energia_renovavel_total = sum(energia_pv_gerada_kwh) - sum(energia_curtailment_pv_kwh);
        penetracao_renovavel = (energia_renovavel_total / max(1, sum(carga_horaria_kW))) * 100;
        autonomia_horas = bateria_kwh * profundidade_max_descarga / max(0.001, mean(carga_horaria_kW));
        autoconsumo_perc = (consumo_total_anual_calc - sum(energia_importada_grid_kwh)) / max(1, consumo_total_anual_calc) * 100;
        resultados_modo_atual(i, :) = [pv_kw, bateria_kwh, gerador_kw, lcoe, penetracao_renovavel, autonomia_horas, custo_capital_total, custo_operacional_anual_total, custo_ciclo_vida_total, sum(combustivel_consumido_litros), horas_operacao_gerador, sum(energia_curtailment_pv_kwh), sum(energia_nao_atendida_kwh), sum(energia_importada_grid_kwh), sum(energia_exportada_grid_kwh), autoconsumo_perc];
    end
    fprintf('\n');
    tempo_total_simulacao = toc;
    disp(['... Simulação concluída em ' num2str(tempo_total_simulacao) ' segundos.']); disp(' ');
    if conectado_a_rede, resultados_grid = resultados_modo_atual; else, resultados_offgrid = resultados_modo_atual; end
end

% ==================================================================================================
% SEÇÃO 5: ANÁLISE DE CONFIGURAÇÃO MÍNIMA OFF-GRID
% ==================================================================================================
disp('SEÇÃO 5: Analisando a configuração mínima para operação Off-Grid...');
disp(' ');
limite_confiabilidade = 0.999;
max_energia_nao_atendida = (1 - limite_confiabilidade) * consumo_total_anual_calc;
indice_confiaveis = resultados_offgrid(:, 13) <= max_energia_nao_atendida;
resultados_confiaveis = resultados_offgrid(indice_confiaveis, :);
disp('------------------------------------------------------------------------------------------');
disp('                  RELATÓRIO DE CONFIGURAÇÃO MÍNIMA VIÁVEL (OFF-GRID)');
disp('------------------------------------------------------------------------------------------');
if isempty(resultados_confiaveis)
    disp('NENHUMA configuração no espaço de busca atingiu a meta de fiabilidade de 99.9%.');
else
    [~, idx_ordenado_capex] = sort(resultados_confiaveis(:, 7));
    configuracao_minima = resultados_confiaveis(idx_ordenado_capex(1), :);
    disp(['Analisando a configuração de menor CAPEX que atende a carga com >= ' num2str(limite_confiabilidade*100) '% de confiabilidade.']);
    disp(' ');
    fprintf('  >> Configuração Mínima Encontrada: %.1f kWp SFV | %.1f kWh SAE | %.1f kW GMG\n', configuracao_minima(1), configuracao_minima(2), configuracao_minima(3));
    fprintf('     - Custo de Capital (CAPEX): R$ %.0f\n', configuracao_minima(7));
    fprintf('     - Custo da Energia (LCOE):  R$ %.4f / kWh\n', configuracao_minima(4));
    fprintf('     - Energia Nao Atendida:     %.2f kWh/ano\n', configuracao_minima(13));
end
disp('------------------------------------------------------------------------------------------');
disp(' ');

% ==================================================================================================
% SEÇÃO 6: PÓS-PROCESSAMENTO E APRESENTAÇÃO DOS RESULTADOS NO CONSOLE
% ==================================================================================================
disp('SEÇÃO 6: Processando e apresentando relatórios comparativos no console...');
disp(' ');
autonomia_minima_desejada = 0; autonomia_maxima_desejada = 24;
penetracao_minima_desejada = 60; penetracao_maxima_desejada = 150;

% --- Processamento e Exibição MODO ON-GRID ---
resultados_atuais = resultados_grid;
resultados_atuais(isinf(resultados_atuais(:,4)) | isnan(resultados_atuais(:,4)),:) = [];
indice_validos = resultados_atuais(:, 6) >= autonomia_minima_desejada & resultados_atuais(:, 6) <= autonomia_maxima_desejada & resultados_atuais(:, 5) >= penetracao_minima_desejada & resultados_atuais(:, 5) <= penetracao_maxima_desejada;
resultados_finais_on_grid = resultados_atuais(indice_validos, :);
[~, idx_ordenado] = sort(resultados_finais_on_grid(:, 4));
resultados_finais_on_grid = resultados_finais_on_grid(idx_ordenado, :);
disp('==========================================================================================================================================');
disp('                                   RELATÓRIO DE OTIMIZAÇÃO - MODO CONECTADO À REDE (ON-GRID)');
disp('==========================================================================================================================================');
disp(sprintf('%-8s|%-10s|%-14s|%-14s|%-16s|%-20s|%-20s', 'PV(kWp)', 'Bat(kWh)', 'LCOE(R$/kWh)', 'OPEX Anual(R$)', 'Autoconsumo(%)', 'Energia Import.(kWh)', 'Energia Export.(kWh)'));
disp('------------------------------------------------------------------------------------------------------------------------------------------');
num_resultados_a_exibir = min(15, size(resultados_finais_on_grid, 1));
if num_resultados_a_exibir == 0, disp('NENHUMA CONFIGURAÇÃO ATENDEU AOS CRITÉRIOS DE FILTRAGEM PARA ESTE MODO.');
else
    for k = 1:num_resultados_a_exibir
        linha = resultados_finais_on_grid(k, :);
        disp(sprintf('%-8.1f|%-10.0f|%-14.4f|%-14.0f|%-16.1f|%-20.0f|%-20.0f', linha(1), linha(2), linha(4), linha(8), linha(16), linha(14), linha(15)));
    end
end
disp('=========================================================================================================================================='); disp(' ');

% --- Processamento e Exibição MODO OFF-GRID ---
resultados_atuais = resultados_offgrid;
resultados_atuais(isinf(resultados_atuais(:,4)) | isnan(resultados_atuais(:,4)),:) = [];
indice_validos = resultados_atuais(:, 6) >= autonomia_minima_desejada & resultados_atuais(:, 6) <= autonomia_maxima_desejada & resultados_atuais(:, 5) >= penetracao_minima_desejada & resultados_atuais(:, 5) <= penetracao_maxima_desejada;
resultados_finais_off_grid = resultados_atuais(indice_validos, :);
[~, idx_ordenado] = sort(resultados_finais_off_grid(:, 4));
resultados_finais_off_grid = resultados_finais_off_grid(idx_ordenado, :);
disp('=====================================================================================================================================');
disp('                                   RELATÓRIO DE OTIMIZAÇÃO - MODO ILHADO (OFF-GRID)');
disp('=====================================================================================================================================');
disp(sprintf('%-8s|%-10s|%-10s|%-14s|%-15s|%-18s|%-22s', 'PV(kWp)', 'Bat(kWh)', 'Ger(kW)', 'LCOE(R$/kWh)', 'Autonomia(h)', 'Penetr.Renov(%)', 'Carga Nao Atendida(kWh)'));
disp('-------------------------------------------------------------------------------------------------------------------------------------');
num_resultados_a_exibir = min(15, size(resultados_finais_off_grid, 1));
if num_resultados_a_exibir == 0, disp('NENHUMA CONFIGURAÇÃO ATENDEU AOS CRITÉRIOS DE FILTRAGEM PARA ESTE MODO.');
else
    for k = 1:num_resultados_a_exibir
        linha = resultados_finais_off_grid(k, :);
        disp(sprintf('%-8.1f|%-10.0f|%-10.0f|%-14.4f|%-15.1f|%-18.1f|%-22.2f', linha(1), linha(2), linha(3), linha(4), linha(6), linha(5), linha(13)));
    end
end
disp('====================================================================================================================================='); disp(' ');

% ==================================================================================================
% SEÇÃO 7: GERAÇÃO DE GRÁFICOS DE ANÁLISE ANUAL
% ==================================================================================================


disp('SEÇÃO 7: Gerando gráficos de análise...');

% --- GRÁFICOS DE CARACTERIZAÇÃO DA CARGA ---
figure('Name', 'Dados de Entrada Anuais (Carga e Recurso Solar)');
[ax, h1, h2] = plotyy(vetor_tempo, carga_horaria_kW, vetor_tempo, irradiacao_horaria_W_m2);
set(h1, 'Color', 'b', 'LineStyle', '-'); set(h2, 'Color', 'r', 'LineStyle', '-');
ylabel(ax(1), 'Consumo da Carga (kW)'); ylim(ax(1), [0, max(carga_horaria_kW)*1.2]);
ylabel(ax(2), 'Irradiacao Solar (W/m^2)'); ylim(ax(2), [0, max(irradiacao_horaria_W_m2)*1.2]);
grid on; title('Perfil Anual de Carga e Irradiacao Solar (8760 horas)');
xlabel('Hora do Ano'); legend([h1, h2], {'Carga', 'Irradiacao'}, 'Location', 'northwest');

figure('Name', 'Perfil Diario Tipico de Carga');
carga_diaria_matrix = reshape(carga_horaria_kW, 24, floor(horas_no_ano/24));
perfil_diario_medio = mean(carga_diaria_matrix, 2);
plot(0:23, perfil_diario_medio, 'b-', 'LineWidth', 2);
grid on; title('Perfil Diario Medio de Consumo'); xlabel('Hora do Dia');
ylabel('Consumo Medio (kW)'); xticks(0:2:23);

figure('Name', 'Consumo Mensal de Energia');
consumo_mensal_kwh = zeros(12, 1); hora_inicial = 1;
for mes = 1:12
    hora_final = hora_inicial + dias_no_mes(mes) * 24 - 1; if hora_final > horas_no_ano, hora_final = horas_no_ano; end
    consumo_mensal_kwh(mes) = sum(carga_horaria_kW(hora_inicial:hora_final));
    hora_inicial = hora_final + 1;
end
bar(consumo_mensal_kwh);
grid on; title('Consumo Total de Energia por Mes'); xlabel('Mes'); ylabel('Consumo Mensal Total (kWh)');
set(gca, 'XTickLabel', {'Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'});

% --- GRÁFICOS DE ANÁLISE DE OTIMIZAÇÃO E BALANÇO ENERGÉTICO ---
for m = 1:2
    if m == 1, resultados_atuais = resultados_finais_on_grid; modo_str = 'On-Grid';
    else, resultados_atuais = resultados_finais_off_grid; modo_str = 'Off-Grid'; end
    if isempty(resultados_atuais), disp(['Nenhum dado viável para plotar para o modo ' modo_str]); continue; end

    solucao_otima_plot = resultados_atuais(1,:);
    figure('Name', ['LCOE vs Penetr. Renovavel (' modo_str ')']);
    plot(resultados_atuais(:,4), resultados_atuais(:,5), 'o', 'MarkerSize', 6, 'DisplayName', 'Soluções Viáveis');
    hold on;
    h_otimo = plot(solucao_otima_plot(4), solucao_otima_plot(5), 'r*', 'MarkerSize', 12, 'LineWidth', 2, 'DisplayName', 'Solução Ótima');
    grid on; title(['LCOE vs. Penetração Renovável (' modo_str ')']); xlabel('LCOE (R$/kWh)'); ylabel('Penetração Renovável (%)');

    disp(' '); disp(['GRÁFICO INTERATIVO: ' modo_str]);
    disp('  - Clique num ponto no gráfico para ver a sua configuração.');
    disp('  - Clique fora da área de plotagem para continuar.');
    texto_info = [];
    while (waitforbuttonpress () == 0)
      ponto_clicado = get(gca, 'CurrentPoint');
      x_clique = ponto_clicado(1,1); y_clique = ponto_clicado(1,2);
      if x_clique < min(xlim) || x_clique > max(xlim) || y_clique < min(ylim) || y_clique > max(ylim), break; end
      distancias = sqrt((resultados_atuais(:,4) - x_clique).^2 + (resultados_atuais(:,5) - y_clique).^2);
      [~, idx_proximo] = min(distancias);
      ponto_selecionado = resultados_atuais(idx_proximo,:);
      if ~isempty(texto_info), delete(texto_info); end
      texto_str = sprintf('PV: %.1fkWp | Bat: %.0fkWh | Ger: %.0fkW', ponto_selecionado(1), ponto_selecionado(2), ponto_selecionado(3));
      texto_info = text(ponto_selecionado(4), ponto_selecionado(5), texto_str, 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'left', 'FontSize', 9, 'BackgroundColor', 'w');
    end
    if ~isempty(texto_info), delete(texto_info); end
    legend(h_otimo, 'Solução Ótima', 'Location', 'northwest');
    hold off;

    % --- Bloco de Re-simulação para Gráficos de Balanço Energético ---
    pv_kw_otimo = solucao_otima_plot(1); bateria_kwh_otimo = solucao_otima_plot(2); gerador_kw_otimo = solucao_otima_plot(3);
    energia_pv_otimo=zeros(horas_no_ano,1); energia_bateria_descarga_otimo=zeros(horas_no_ano,1);
    energia_bateria_carga_otimo=zeros(horas_no_ano,1); energia_gerador_otimo=zeros(horas_no_ano,1);
    energia_importada_otimo=zeros(horas_no_ano,1); energia_exportada_otimo=zeros(horas_no_ano,1); soc_bateria_otimo=ones(horas_no_ano+1,1);
    for h = 1:horas_no_ano
        soc_bateria_otimo(h) = soc_bateria_otimo(h);
        energia_pv_otimo(h) = (irradiacao_horaria_W_m2(h) / 1000) * pv_kw_otimo * fator_derating_pv;
        balanco_kwh = energia_pv_otimo(h) - carga_horaria_kW(h);
        if m == 1 % On-Grid
            if balanco_kwh >= 0, energia_para_carga_max = (1 - soc_bateria_otimo(h)) * bateria_kwh_otimo / eficiencia_bateria; energia_bateria_carga_otimo(h) = min(balanco_kwh, energia_para_carga_max); energia_exportada_otimo(h) = balanco_kwh - energia_bateria_carga_otimo(h);
            else, deficit_kwh = -balanco_kwh; energia_disponivel_bateria = max(0, (soc_bateria_otimo(h) - (1-profundidade_max_descarga)) * bateria_kwh_otimo * eficiencia_bateria); energia_bateria_descarga_otimo(h) = min(deficit_kwh, energia_disponivel_bateria); deficit_restante_kwh = deficit_kwh - energia_bateria_descarga_otimo(h); if deficit_restante_kwh > 0.01, if gerador_kw_otimo > 0 && custo_marginal_gerador < tarifa_compra_energia, potencia_gerador_despachada = gerador_kw_otimo * fator_carga_otima_gerador; energia_gerador_otimo(h) = potencia_gerador_despachada; energia_excedente_gerador = energia_gerador_otimo(h) - deficit_restante_kwh; if energia_excedente_gerador > 0, energia_para_carga_max_gen = (1 - soc_bateria_otimo(h)) * bateria_kwh_otimo / eficiencia_bateria; energia_bateria_carga_otimo(h) += min(energia_excedente_gerador, energia_para_carga_max_gen); end, else, energia_importada_otimo(h) = deficit_restante_kwh; end, end, end
        else % Off-Grid
            if balanco_kwh >= 0, energia_para_carga_max = (1 - soc_bateria_otimo(h)) * bateria_kwh_otimo / eficiencia_bateria; energia_bateria_carga_otimo(h) = min(balanco_kwh, energia_para_carga_max);
            else, deficit_kwh = -balanco_kwh; energia_disponivel_bateria = max(0, (soc_bateria_otimo(h) - (1-profundidade_max_descarga)) * bateria_kwh_otimo * eficiencia_bateria); energia_bateria_descarga_otimo(h) = min(deficit_kwh, energia_disponivel_bateria); deficit_restante_kwh = deficit_kwh - energia_bateria_descarga_otimo(h); if deficit_restante_kwh > 0.01 && gerador_kw_otimo > 0, potencia_gerador_despachada = gerador_kw_otimo * fator_carga_otima_gerador; energia_gerador_otimo(h) = potencia_gerador_despachada; energia_excedente_gerador = energia_gerador_otimo(h) - deficit_restante_kwh; if energia_excedente_gerador > 0, energia_para_carga_max_gen = (1 - soc_bateria_otimo(h)) * bateria_kwh_otimo / eficiencia_bateria; energia_bateria_carga_otimo(h) += min(energia_excedente_gerador, energia_para_carga_max_gen); end, end, end
        end
        if bateria_kwh_otimo > 0, soc_bateria_otimo(h+1) = soc_bateria_otimo(h) + (energia_bateria_carga_otimo(h) * eficiencia_bateria / bateria_kwh_otimo) - (energia_bateria_descarga_otimo(h) / eficiencia_bateria / bateria_kwh_otimo); else, soc_bateria_otimo(h+1) = soc_bateria_otimo(h); end
    end

    % --- Gráficos de Balanço Energético ---
    figure('Name', ['Balanco Anual de Energia (' modo_str ')']);
    fontes = [sum(energia_pv_otimo), sum(energia_bateria_descarga_otimo), sum(energia_gerador_otimo), sum(energia_importada_otimo)];
    usos = [sum(carga_horaria_kW), sum(energia_bateria_carga_otimo), sum(energia_exportada_otimo)];
    bar_data = [fontes, 0, 0, 0; 0, 0, 0, 0, usos];
    bar(bar_data', 'stacked');
    grid on; title(['Balanço Anual de Energia (' modo_str ')']); ylabel('Energia Total (kWh)');
    set(gca, 'XTickLabel', {'Fontes de Energia', 'Usos da Energia'});
    legend({'Energia PV', 'Descarga Bateria', 'Geração Gerador', 'Importado da Rede', 'Atendimento à Carga', 'Carga Bateria', 'Exportado para a Rede'}, 'Location', 'northwest');

    consumo_mensal = zeros(12,1); geracao_solar_mensal = zeros(12,1); descarga_bateria_mensal = zeros(12,1); geracao_gerador_mensal = zeros(12,1); energia_importada_mensal = zeros(12,1);
    hora_inicial = 1;
    for mes = 1:12, hora_final = hora_inicial + dias_no_mes(mes) * 24 - 1; if hora_final > horas_no_ano, hora_final = horas_no_ano; end
    consumo_mensal(mes) = sum(carga_horaria_kW(hora_inicial:hora_final));
    geracao_solar_mensal(mes) = sum(energia_pv_otimo(hora_inicial:hora_final));
    descarga_bateria_mensal(mes) = sum(energia_bateria_descarga_otimo(hora_inicial:hora_final));
    geracao_gerador_mensal(mes) = sum(energia_gerador_otimo(hora_inicial:hora_final));
    energia_importada_mensal(mes) = sum(energia_importada_otimo(hora_inicial:hora_final));
    hora_inicial = hora_final + 1; end
    figure('Name', ['Balanco Mensal de Energia (' modo_str ')']);
    bar([consumo_mensal, geracao_solar_mensal, descarga_bateria_mensal, geracao_gerador_mensal, energia_importada_mensal]);
    grid on; title(['Balanço Mensal de Energia (' modo_str ')']); xlabel('Mês'); ylabel('Energia (kWh)');
    set(gca, 'XTickLabel', {'Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'});
    legend({'Consumo', 'Geração Solar', 'Descarga Bateria', 'Geração Gerador', 'Importado da Rede'}, 'Location', 'northwest');

    figure('Name', ['Operacao Diaria (Semana Exemplo) (' modo_str ')']);
    horas_plot = (24*180):(24*187-1);
    [ax, h1, h2] = plotyy(horas_plot, carga_horaria_kW(horas_plot), horas_plot, soc_bateria_otimo(horas_plot)*100);
    hold(ax(1), 'on');
    area(ax(1), horas_plot, energia_pv_otimo(horas_plot), 'FaceColor', [1 0.9 0.4], 'EdgeColor', 'none', 'DisplayName', 'Geração PV');
    area(ax(1), horas_plot, energia_importada_otimo(horas_plot), 'FaceColor', [0.7 0.7 0.7], 'EdgeColor', 'none', 'DisplayName', 'Importado Rede');
    area(ax(1), horas_plot, energia_gerador_otimo(horas_plot), 'FaceColor', [0.9 0.5 0.5], 'EdgeColor', 'none', 'DisplayName', 'Geração Gerador');
    bar(ax(1), horas_plot, energia_bateria_descarga_otimo(horas_plot), 'FaceColor', [0.4 0.4 0.8], 'EdgeColor', 'none', 'BarWidth', 1, 'DisplayName', 'Descarga Bateria');
    bar(ax(1), horas_plot, -energia_bateria_carga_otimo(horas_plot), 'FaceColor', [0.4 0.8 0.4], 'EdgeColor', 'none', 'BarWidth', 1, 'DisplayName', 'Carga Bateria');
    bar(ax(1), horas_plot, -energia_exportada_otimo(horas_plot), 'FaceColor', [0.4 0.8 1.0], 'EdgeColor', 'none', 'BarWidth', 1, 'DisplayName', 'Exportação Rede');
    plot(ax(1), horas_plot, carga_horaria_kW(horas_plot), 'k-', 'LineWidth', 2, 'DisplayName', 'Carga');
    hold(ax(1), 'off');
    set(h1, 'Visible', 'off');
    set(h2, 'Color', 'm', 'LineStyle', '--', 'LineWidth', 2, 'DisplayName', 'SOC Bateria (%)');
    ylabel(ax(1), 'Potência (kW)'); ylim(ax(1), [-max(carga_horaria_kW(horas_plot))*0.8, max(carga_horaria_kW(horas_plot))*1.5]);
    ylabel(ax(2), 'Estado de Carga da Bateria (%)'); ylim(ax(2), [0 100]);
    grid on; title(['Operação Diária Detalhada (' modo_str ')']); xlabel('Hora do Ano');
    legend(ax(1), 'Location', 'northwest');
end
disp('Gráficos de balanço energético gerados com sucesso.'); disp(' ');

% ==================================================================================================
% SEÇÃO 8: GERAÇÃO DE FICHEIROS DE RELATÓRIO
% ==================================================================================================
disp('SEÇÃO 8: Iniciando exportação de relatórios...');
try, fileID = fopen('perfil_carga_e_solar.csv', 'w'); fprintf(fileID, 'Hora,Carga_kW,Irradiacao_W_m2\n'); fclose(fileID); csvwrite('perfil_carga_e_solar.csv', [vetor_tempo, carga_horaria_kW, irradiacao_horaria_W_m2], '-append'); disp('- Ficheiro de perfil de carga e solar salvo com sucesso.');
catch, disp('- ERRO ao salvar o ficheiro de perfil de carga.'); end

for m = 1:2
    if m == 1, resultados_finais_export = resultados_finais_on_grid; modo_str = 'on_grid';
    else, resultados_finais_export = resultados_finais_off_grid; modo_str = 'off_grid'; end
    if isempty(resultados_finais_export), disp(['Nenhum resultado viável para exportar para o modo ' modo_str]); continue; end
    solucao_otima = resultados_finais_export(1,:);
    nome_csv = ['relatorio_completo_' modo_str '.csv'];
    try
        header = {'PV_kWp','Bateria_kWh','Gerador_kW','LCOE_R$_kWh','Penetracao_Ren_%','Autonomia_h','CAPEX_R$','OPEX_Anual_R$','LCC_R$','Combustivel_Anual_L','Horas_Gerador_h','Curtailment_kWh','Carga_Nao_Atendida_kWh','Energia_Importada_kWh','Energia_Exportada_kWh', 'Autoconsumo_%'};
        fileID = fopen(nome_csv, 'w'); fprintf(fileID, '%s\n', strjoin(header, ',')); fclose(fileID);
        csvwrite(nome_csv, resultados_finais_export, '-append');
        disp(['- Relatorio CSV para modo ' modo_str ' salvo com sucesso.']);
    catch, disp(['- ERRO ao salvar relatorio CSV para modo ' modo_str]); end
    nome_txt = ['dossie_projeto_' modo_str '.txt'];
    try
        fileID = fopen(nome_txt, 'w');
        fprintf(fileID, '================================================================\n');
        fprintf(fileID, '          DOSSIE COMPLETO DO PROJETO - MODO %s\n', upper(modo_str));
        fprintf(fileID, '================================================================\n\n');
        fprintf(fileID, '--- PREMISSAS DE ENTRADA DO PROJETO ---\n\n');
        fprintf(fileID, ' PERFIL DE CARGA (SINTETICO):\n');
        fprintf(fileID, '   - Consumo Medio Mensal (Informado): %.0f kWh/mes\n', consumo_medio_mensal_kwh);
        fprintf(fileID, '   - Pico de Carga (Informado): %.2f kW\n', pico_carga_kw_informado);
        fprintf(fileID, '   - Consumo Total Anual (Calculado): %.0f kWh/ano\n', consumo_total_anual_calc);
        fprintf(fileID, '   - Demanda Maxima (Pico Calculado): %.2f kW\n', demanda_maxima_kw_calc);
        fprintf(fileID, '   - Demanda Media (Calculada): %.2f kW\n', demanda_media_kw_calc);
        fprintf(fileID, '   - Fator de Carga (Calculado): %.2f\n\n', fator_de_carga_calc);
        fprintf(fileID, ' CRITERIOS DE OTIMIZACAO (FILTROS):\n');
        fprintf(fileID, '   - Autonomia Desejada: Entre %.1f e %.1f horas\n', autonomia_minima_desejada, autonomia_maxima_desejada);
        fprintf(fileID, '   - Penetracao Renovavel Desejada: Entre %.0f%% e %.0f%%\n\n', penetracao_minima_desejada, penetracao_maxima_desejada);
        fprintf(fileID, ' FINANCEIRO:\n');
        fprintf(fileID, '   - Vida Util do Projeto: %d anos\n', vida_util_projeto);
        fprintf(fileID, '   - Taxa de Desconto: %.1f %%\n\n', taxa_desconto*100);
        if m==1, fprintf(fileID, ' REDE ELETRICA:\n   - Tarifa de Compra: R$ %.2f/kWh\n   - Tarifa de Venda: R$ %.2f/kWh\n\n', tarifa_compra_energia, tarifa_venda_energia); end
        fprintf(fileID, ' COMPONENTES:\n');
        fprintf(fileID, '   - PV: Custo=R$%.0f/kWp, O&M=R$%.0f/kWp/ano, Perdas=%.0f%%, Vida=%danos\n', custo_pv_por_kw, custo_om_pv_anual, (1-fator_derating_pv)*100, vida_util_pv);
        fprintf(fileID, '   - Bateria: Custo=R$%.0f/kWh, O&M=R$%.0f/kWh/ano, DoD=%.0f%%, Efic=%.0f%%, Vida=%dciclos\n', custo_bateria_por_kwh, custo_om_bateria_anual, profundidade_max_descarga*100, eficiencia_bateria*100, vida_util_bateria_ciclos);
        fprintf(fileID, '   - Gerador: Custo=R$%.0f/kW, O&M=R$%.2f/h, Vida=%dhoras, Combustivel=R$%.2f/L\n\n', custo_gerador_por_kw, custo_om_gerador_horario, vida_util_gerador_horas, custo_combustivel);
        fprintf(fileID, '--- RESULTADOS DA SOLUCAO OTIMA ---\n\n');
        fprintf(fileID, ' CONFIGURACAO:\n');
        fprintf(fileID, '   - PV: %.1f kWp | Bateria: %.1f kWh | Gerador: %.1f kW\n\n', solucao_otima(1), solucao_otima(2), solucao_otima(3));
        fprintf(fileID, ' METRICAS TECNICO-ECONOMICAS ANUAIS:\n');
        fprintf(fileID, '   - LCOE: R$ %.4f / kWh\n', solucao_otima(4));
        fprintf(fileID, '   - CAPEX: R$ %.0f\n', solucao_otima(7));
        fprintf(fileID, '   - OPEX Anual: R$ %.0f\n', solucao_otima(8));
        fprintf(fileID, '   - Custo Ciclo de Vida (LCC): R$ %.0f\n', solucao_otima(9));
        fprintf(fileID, '   - Penetracao Renovavel: %.1f %%\n', solucao_otima(5));
        fprintf(fileID, '   - Autoconsumo (On-Grid): %.1f %%\n', solucao_otima(16));
        fprintf(fileID, '   - Autonomia (Off-Grid): %.1f horas\n\n', solucao_otima(6));
        fprintf(fileID, ' BALANCO DE ENERGIA ANUAL (kWh):\n');
        fprintf(fileID, '   - Consumo Total da Carga: %.0f\n', consumo_total_anual_calc);
        fprintf(fileID, '   - Energia Importada da Rede: %.0f\n', solucao_otima(14));
        fprintf(fileID, '   - Energia Exportada para a Rede: %.0f\n', solucao_otima(15));
        fprintf(fileID, '   - Energia Desperdicada (Curtailment): %.0f\n', solucao_otima(12));
        fprintf(fileID, '   - Energia Nao Atendida (Corte de Carga): %.2f\n\n', solucao_otima(13));
        fprintf(fileID, ' OPERACAO DO GERADOR (ANUAL):\n');
        fprintf(fileID, '   - Horas de Operacao: %.0f horas\n', solucao_otima(11));
        fprintf(fileID, '   - Consumo de Combustivel: %.0f Litros\n', solucao_otima(10));
        fprintf(fileID, '================================================================\n');
        fclose(fileID);
        disp(['- Dossie do projeto ' modo_str ' salvo com sucesso.']);
    catch, disp(['- ERRO ao salvar dossie do projeto para modo ' modo_str]); end
end
disp(' '); disp('Processo finalizado.');

% --- FIM DO CÓDIGO ---


