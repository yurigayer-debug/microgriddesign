# microgriddesign
% ==================================================================================================
% SIMULAÇÃO OTIMIZAÇÃO LCOE E AUTONOMIA DE MICRORREDES HÍBRIDAS (ON-GRID / OFF-GRID)
% ==================================================================================================
%
% Autor: Eng. Eletricista Yuri Escobar Gayer
% Mestrando: Engenharia Eletrônica e Computação 
% yurigayer@gmail.com
% Prof. Orientador: Lizandro de Souza Oliveira 
% lizandro.oliveira@ucpel.edu.br
% ==================================================================================================

Ferramenta de Otimização de Microrredes Híbridas (Octave)

Este repositório contém um script em GNU Octave projetado para a simulação e otimização tecno-econômica de microrredes híbridas, compostas por painéis solares fotovoltaicos (PV), sistemas de armazenamento de energia por baterias (SAE) e geradores a diesel (GMG).

A ferramenta analisa milhares de configurações de sistema para encontrar as soluções com base no Custo Nivelado da Energia (LCOE), tanto para sistemas conectados à rede (On-Grid) quanto isolados (Off-Grid).

Principais Funcionalidades

    Simulação Microrrede em modo ilhado ou conectado à rede: Analisa os modos de operação On-Grid (conectado à rede) e Off-Grid (isolado).
  
    Modelagem de Componentes: Simula a interação entre painéis solares, baterias e um gerador de backup.

    Possibilita geração de Dados Sintéticos perfil de carga: Cria perfis anuais realistas de consumo de carga (8760 horas) e de irradiação solar com base em parâmetros iniciais.

    Análise Econômica: Calcula o investimento inicial (CAPEX), os custos operacionais (OPEX), o custo total do ciclo de vida (LCC) e o Custo Nivelado da Energia (LCOE) para cada configuração.

    Relatórios: Gera relatórios no console, exporta os resultados para arquivos .csv e cria um dossiê de projeto em formato .txt para as melhores soluções.

  Visualização Gráfica: Plota gráficos  para análise de dados de entrada, comparação de soluções e balanço energético anual/mensal da solução ótima.

Como Funciona

O script segue uma estrutura sequencial para realizar a análise:

    Entradas e Parâmetros (Seção 1): O usuário define todas as premissas do projeto, como o consumo médio da carga, custos dos componentes, tarifas de energia e parâmetros financeiros (vida útil do projeto, taxa de desconto).

    Geração de Perfis (Seção 2): O script gera um perfil de carga horário para um ano inteiro e um perfil de irradiação solar baseado em dados mensais para a localização (neste caso, Pelotas/RS, Brasil).

    Definição do Espaço de Busca (Seção 3): O usuário especifica os diferentes tamanhos de PV, bateria e gerador que deseja simular. O script cria todas as combinações possíveis.

    Simulação Horária (Seção 4): Este é o núcleo da ferramenta. Para cada combinação de equipamentos e para cada modo (On-Grid e Off-Grid), o script simula o balanço de energia para cada hora do ano. Ele decide se deve usar a energia solar, carregar/descarregar a bateria, acionar o gerador ou interagir com a rede elétrica.

    Análise e Pós-processamento (Seções 5 e 6): Os resultados são filtrados e classificados pelo menor LCOE. O script também identifica a configuração de menor custo para o modo Off-Grid que atende a um critério mínimo de confiabilidade.

    Geração de Saídas (Seções 7 e 8): O script gera gráficos para visualização e exporta relatórios completos em arquivos de texto e planilhas.

Como Usar

    Certifique-se de ter o GNU Octave instalado (com o pacote statistics).

    Abra o arquivo MESTRADO_valendo .m no Octave.

    Ajuste os Parâmetros:

        Na Seção 1.1 a 1.4, modifique os parâmetros de entrada de acordo com seu projeto (consumo, custos, tarifas, etc.).

        Na Seção 3, defina os vetores vetor_tamanho_pv_kw, vetor_tamanho_bateria_kwh e vetor_tamanho_gerador_kw para determinar quais tamanhos de sistema você deseja testar.

    Execute o script.

    Analise os resultados exibidos no console, os gráficos gerados e os arquivos de relatório (.csv e .txt) salvos na pasta do projeto.


-STEP BY STEP IN ENGLISH: -------------------------------------------

Hybrid Microgrid Optimization Tool (Octave)

This repository contains a GNU Octave script designed for the techno-economic simulation and optimization of hybrid microgrids, which include photovoltaic (PV) solar panels, battery energy storage systems (BESS), and diesel generators (genset).

The tool analyzes thousands of system configurations to find the most cost-effective solutions based on the Levelized Cost of Energy (LCOE) for both grid-connected (On-Grid) and standalone (Off-Grid) systems.

Key Features

    Dual-Mode Simulation: Analyzes both On-Grid (grid-connected) and Off-Grid (standalone) operation modes.

    Component Modeling: Simulates the interaction between solar panels, batteries, and a backup generator.

    Synthetic Data Generation: Creates realistic annual load consumption (8760 hours) and solar irradiation profiles based on initial parameters.

    Comprehensive Economic Analysis: Calculates the initial investment (CAPEX), operational costs (OPEX), total life-cycle cost (LCC), and the Levelized Cost of Energy (LCOE) for each configuration.

    Detailed Reporting: Generates console reports, exports results to .csv files, and creates a project summary (.txt dossier) for the best-ranked solutions.

    Graphical Visualization: Plots detailed graphs for input data analysis, solution comparison, and the annual/monthly energy balance of the optimal solution.

How It Works

The script follows a sequential structure to perform the analysis:

    Inputs and Parameters (Section 1): The user defines all project assumptions, such as average load consumption, component costs, energy tariffs, and financial parameters (project lifetime, discount rate).

    Profile Generation (Section 2): The script generates an hourly load profile for an entire year and a solar irradiation profile based on monthly data for the specified location (in this case, Pelotas/RS, Brazil).

    Search Space Definition (Section 3): The user specifies the different sizes of PV, battery, and generator systems to be simulated. The script then creates all possible combinations.

    Hourly Simulation (Section 4): This is the core of the tool. For each equipment combination and for each mode (On-Grid and Off-Grid), the script simulates the energy balance for every hour of the year. It decides whether to use solar energy, charge/discharge the battery, dispatch the generator, or interact with the utility grid.

    Analysis and Post-Processing (Sections 5 & 6): The results are filtered and ranked by the lowest LCOE. The script also identifies the lowest-cost Off-Grid configuration that meets a minimum reliability criterion.

    Output Generation (Sections 7 & 8): The script generates plots for visualization and exports comprehensive reports to text files and spreadsheets.

How to Use

    Ensure you have GNU Octave installed (with the statistics package).

    Open the MESTRADO_valendo .m file in Octave.

    Adjust the Parameters:

        In Sections 1.1 to 1.4, modify the input parameters to match your project's needs (consumption, costs, tariffs, etc.).

        In Section 3, define the vectors vetor_tamanho_pv_kw, vetor_tamanho_bateria_kwh, and vetor_tamanho_gerador_kw to determine which system sizes you want to test.

    Run the script.

    Analyze the results displayed in the console, the generated plots, and the report files (.csv and .txt) saved in the project folder.
