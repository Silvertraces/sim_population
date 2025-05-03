% 种群模拟主程序
% 初始化参数、创建种群对象并实现交互式可视化

% 清除工作区和关闭所有图窗
clear;
close all;
clc;

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

% 创建种群对象
population = Population(PopulationParams(params));

% 设置最大模拟年份
max_years = 1000;
% 开始前快照
dashBoard = PopulationDashboard(population.getCurrentState());

% 开始计时
tic

while population.current_year <= max_years
    population.simulateYear()
    dashBoard.addStateSnapshot(population.getCurrentState());
    toc
end
% 计算总耗时
total_time = toc;