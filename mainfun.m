% 种群模拟主程序
% 初始化参数、创建种群对象并实现交互式可视化或批处理模式

% 清除工作区和关闭所有图窗
clear;
close all;
clc;
% profile clear
% profile -historysize 1e8 on
% 设置默认参数
params = struct();
params.population = 10000;           % 初始种群数量
params.ratio_m = 0.5;              % 初始雄性比例
params.age_expect = 80;            % 寿命期望值
params.ratio_age_dist_sigma = 0.05; % 寿命标准差比例
params.ratio_range_repro = [0.2 0.6]; % 繁殖年龄相对区间
params.ratio_age_repro_mu = 0.6;   % 繁殖概率分布均值比例
params.ratio_age_repro_sigma = 0.1; % 繁殖概率分布标准差比例
params.ratio_repro = 2;            % 繁殖比率
params.prob_m_repro = 0.5;         % 生育雄性概率
params.birth_period = 1;           % 生育周期
params.structure_type = "coffin";  % 种群结构类型
% 设置最大模拟年份
max_years = 20; % 可根据需要调整

% 选择运行模式
mode_options = {'交互式模式', '批处理模式'};
mode = questdlg('请选择运行模式：', '运行模式选择', ...
    '交互式模式', '批处理模式', '交互式模式');

% 如果用户取消选择，默认使用交互式模式
switch mode
    case '交互式模式'
        mode_idx = 1;
    case '批处理模式'
        mode_idx = 2;
    case ''
        mode_idx = 1;
end

% 创建种群对象
population = Population(PopulationParams(params));

% 根据选择的模式运行模拟
if mode_idx == 1
    % 交互式模式
    % 开始前快照
    dashBoard = PopulationDashboard(population.getCurrentState());
    
    % 开始计时
    tic
    
    while population.current_year <= max_years
        population.simulateYear()
        dashBoard.addStateSnapshot(population.getCurrentState());
        drawnow
        % 每10年显示一次进度
        if mod(population.current_year, 10) == 0
            disp(['已完成 ' num2str(population.current_year) ' 年模拟...']);
        end
    end
    % 计算总耗时
    total_time = toc;
    disp(['模拟完成，总耗时: ' num2str(total_time) ' 秒']);
    
else
    % 批处理模式
    % 创建时间戳文件夹
    timestamp = datetime("now", "Format", "yyyyMMdd_HHmmss");
    figures_dir = fullfile("figures", string(timestamp));
    if ~exist(figures_dir, 'dir')
        mkdir(figures_dir);
    end
    
    % 开始计时
    tic
    
    % 批量模拟
    disp('开始批量模拟...');
    states = population.batchSimulate(max_years);
    
    % 计算模拟总耗时
    sim_time = toc;
    disp(['模拟完成，耗时: ' num2str(sim_time) ' 秒']);
    
    % 开始可视化并保存图像
    disp('开始生成并保存可视化结果...');
    tic
    
    % 创建仪表板对象
    dashBoard = PopulationDashboard(states(1));
    
    % 批量可视化并保存图像
    dashBoard.batchVisualize(states, figures_dir);
    
    % 计算可视化总耗时
    vis_time = toc;
    disp(['可视化完成，耗时: ' num2str(vis_time) ' 秒']);
    
    % 计算总耗时
    total_time = sim_time + vis_time;
    disp(['总耗时: ' num2str(total_time) ' 秒']);
    
    % 保存模拟结果
    save(fullfile(figures_dir, "simulation_results.mat"), 'states', 'params', 'sim_time', 'vis_time', 'total_time');
    disp(['结果已保存至: ' figures_dir]);
end

% profile viewer