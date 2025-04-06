% 种群模拟主程序
% 初始化参数、创建种群对象并实现交互式可视化

% 清除工作区和关闭所有图窗
clear;
close all;
clc;

% 设置默认参数
params = struct();
params.population = 1e4;           % 初始种群数量
params.ratio_m = 0.5;              % 初始雄性比例
params.age_expect = 80;            % 寿命期望值
params.ratio_age_dist_sigma = 0.05; % 寿命标准差比例
params.ratio_range_repro = [0.2, 0.6]; % 繁殖年龄相对区间
params.ratio_age_repro_mu = 0.4;   % 繁殖概率分布均值比例
params.ratio_age_repro_sigma = 0.1; % 繁殖概率分布标准差比例
params.ratio_repro = 1;            % 繁殖比率
params.prob_m_repro = 0.5;         % 生育雄性概率
params.birth_period = 1;           % 生育周期

% 创建种群对象
population = Population(params);

% 设置最大模拟年份
max_years = 1000;

% 预先模拟所有年份
disp('正在模拟种群演化，请稍候...');
all_stats = cell(max_years + 1, 1);

% 存储初始状态统计信息
[~, stats] = population.getStats();
all_stats{1} = stats;
disp(['初始种群: ', num2str(stats.total), ' 个体 (雄性: ', num2str(stats.num_males), ', 雌性: ', num2str(stats.num_females), ')']);

% 开始计时
tic;

% 模拟每一年并存储统计信息
for year = 1:max_years
    % 模拟一年
    population.simulateYear();
    [~, stats] = population.getStats();
    all_stats{year + 1} = stats;
    
    % 显示进度
    if mod(year, 50) == 0
        elapsed_time = toc;
        estimated_total = elapsed_time / year * max_years;
        remaining_time = estimated_total - elapsed_time;
        
        disp(['年份: ', num2str(year), '/', num2str(max_years), ...
              ' (', num2str(year/max_years*100, '%.1f'), '%) | ', ...
              '种群: ', num2str(stats.total), ' | ', ...
              '性别比(雄:雌): ', num2str(stats.ratio_males, '%.2f'), ':', num2str(stats.ratio_females, '%.2f'), ' | ', ...
              '平均年龄: ', num2str(stats.age_mean, '%.1f'), ' | ', ...
              '平均代数: ', num2str(stats.gen_mean, '%.1f'), ' | ', ...
              '已用时间: ', num2str(elapsed_time/60, '%.1f'), '分钟 | ', ...
              '预计剩余: ', num2str(remaining_time/60, '%.1f'), '分钟']);
    end
end

% 计算总耗时
total_time = toc;
disp(['模拟完成！总耗时: ', num2str(total_time/60, '%.1f'), ' 分钟']);
disp(['最终种群: ', num2str(stats.total), ' 个体 (雄性: ', num2str(stats.num_males), ...
      ', 雌性: ', num2str(stats.num_females), ')']);
disp(['最大代数: ', num2str(stats.gen_max), ', 平均代数: ', num2str(stats.gen_mean, '%.1f')]);
disp(['年龄范围: ', num2str(stats.age_min), '-', num2str(stats.age_max), ', 平均年龄: ', num2str(stats.age_mean, '%.1f')]);


% 创建图形界面
fig = figure('Name', '种群模拟可视化', 'Position', [100, 100, 1200, 800]);

% 创建年份滑块
slider_year = uicontrol('Style', 'slider', ...
                        'Min', 0, 'Max', max_years, 'Value', 0, ...
                        'Position', [300, 20, 600, 20], ...
                        'Callback', @updatePlots);
                    
% 创建年份文本标签
text_year = uicontrol('Style', 'text', ...
                     'Position', [500, 45, 200, 20], ...
                     'String', '当前年份: 0');

% 创建绘图区域
subplot_handles = zeros(4, 4);
plot_titles = {'性别分布', '世代分布', '年龄分布', '生命阶段分布'};
plot_types = {'pie', 'bar', 'histogram', 'boxplot'};

% 初始化绘图区域
for row = 1:4
    for col = 1:3
        subplot_handles(row, col) = subplot(4, 3, (row-1)*3 + col);
    end
 end

% 定义颜色映射
colors = lines(10);

% 更新绘图的回调函数
function updatePlots(source, ~)
    % 获取当前年份
    current_year = round(source.Value);
    
    % 更新年份文本
    text_year.String = ['当前年份: ', num2str(current_year)];
    
    % 获取当前年份的统计信息
    stats = all_stats{current_year + 1};
    
    % 清空所有子图
    for i = 1:numel(subplot_handles)
        if subplot_handles(i) > 0
            cla(subplot_handles(i));
        end
    end
    
    % 1. 性别分布
    % 饼图
    axes(subplot_handles(1, 1));
    pie([stats.num_males, stats.num_females], {'雄性', '雌性'});
    title('性别分布 (饼图)');
    colormap(subplot_handles(1, 1), colors(1:2, :));
    
    % 柱状图
    axes(subplot_handles(2, 1));
    bar([stats.ratio_males, stats.ratio_females], 'FaceColor', 'flat');
    colororder(colors(1:2, :));
    set(gca, 'XTickLabel', {'雄性', '雌性'});
    title('性别比例 (柱状图)');
    ylim([0, 1]);
    
    % 2. 世代分布
    if isfield(stats, 'generations_count')
        % 柱状图
        axes(subplot_handles(2, 2));
        generations = stats.generations_count(:, 1);
        counts = stats.generations_count(:, 2);
        bar(generations, counts, 'FaceColor', 'flat');
        colororder(colors);
        title('世代分布 (柱状图)');
        xlabel('世代');
        ylabel('数量');
        
        % 箱线图
        axes(subplot_handles(4, 2));
        boxplot(stats.all_generations);
        title('世代分布 (箱线图)');
        ylabel('世代');
    else
        % 如果没有世代统计信息，显示基本统计数据
        axes(subplot_handles(2, 2));
        text(0.5, 0.5, ['平均世代: ', num2str(stats.gen_mean), '\n', ...
                       '最小世代: ', num2str(stats.gen_min), '\n', ...
                       '最大世代: ', num2str(stats.gen_max)], ...
             'HorizontalAlignment', 'center');
        axis off;
    end
    
    % 3. 年龄分布
    % 直方图
    axes(subplot_handles(3, 3));
    if isfield(stats, 'all_ages')
        histogram(stats.all_ages, 20);
        title('年龄分布 (直方图)');
        xlabel('年龄');
        ylabel('数量');
    end
    
    % 箱线图
    axes(subplot_handles(4, 3));
    if isfield(stats, 'all_ages')
        boxplot(stats.all_ages);
        title('年龄分布 (箱线图)');
        ylabel('年龄');
    end
    
    % 4. 种群总量
    axes(subplot_handles(1, 3));
    text(0.5, 0.5, ['总数: ', num2str(stats.total), '\n', ...
                   '雄性: ', num2str(stats.num_males), '\n', ...
                   '雌性: ', num2str(stats.num_females)], ...
         'HorizontalAlignment', 'center', 'FontSize', 12);
    axis off;
    title('种群统计');
    
    % 更新图形
    drawnow;
end

% 初始调用一次更新函数
updatePlots(slider_year);