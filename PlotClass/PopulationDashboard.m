classdef PopulationDashboard < handle
    % PopulationDashboard 种群数据可视化展板类
    % 创建并管理一个包含多个子图的图窗，用于展示种群模拟数据
    % 接收 PopulationState 对象数组作为历史数据，并根据数据更新图表

    properties
        Figure matlab.ui.Figure % 图窗句柄
        Layout matlab.graphics.layout.TiledChartLayout % 平铺图块布局句柄

        % 存储模拟历史数据
        % 注意：随着模拟年份增加，此属性内存使用会快速上升。
        % 对于非常长的模拟，可能需要考虑定期保存到文件或只存储部分历史。
        SimulationHistory PopulationState % PopulationState 对象数组，存储每年的种群状态快照

        % 子图 axes 句柄 (用于后续更新数据)
        AxRelRatioLifeCycle matlab.graphics.axis.Axes % 生命周期相对比例堆叠条形图 axes 1
        AxRelRatioGender matlab.graphics.axis.Axes     % 性别相对比例堆叠条形图 axes 2
        AxAbsCountLifeCycle matlab.graphics.axis.Axes  % 生命周期绝对数量分组条形图 axes 3
        AxAbsCountGender matlab.graphics.axis.Axes      % 性别绝对数量分组条形图 axes 4
        AxGlobalTimeline matlab.graphics.axis.Axes     % 全局时间线折线图 axes 5
        AxGenderPie matlab.graphics.axis.Axes             % 当前年份性别结构饼图 axes 6
        AxAgeDonut matlab.graphics.axis.Axes           % 当前年份年龄结构甜甜圈图 axes
        AxAgeHistKDE matlab.graphics.axis.Axes         % 当前年份年龄结构直方图+核密度估计 axes 7
        AxAgeViolin matlab.graphics.axis.Axes          % 当前年份年龄结构小提琴图 axes 8
        AxGenGroupedStacked matlab.graphics.axis.Axes  % 世代分组堆叠条形图 axes 9
        AxGenRelRatio matlab.graphics.axis.Axes        % 世代相对比例堆叠条形图 axes 10
    end

    properties (Access = private)
        % 存储需要细粒度更新的绘图元素的句柄
        GlobalTimelineLine matlab.graphics.chart.primitive.Line % 全局时间线折线图的线条句柄

        % 存储需要连年数据的图所需的历史窗口大小 (方案 3)
        % 例如：HistoryWindowSize = 100; % 只显示最近 100 年的数据
        % HistoryWindowSize double = Inf; % 默认显示所有历史数据
    end

    properties (Constant, Access = private)
        LayoutRows = 4 % 布局行数
        LayoutCols = 4 % 布局列数 % 修改为 4x4 布局
    end

    methods
        function obj = PopulationDashboard(initialHistory)
            % 构造函数
            % 创建图窗和子图布局，并初始化模拟历史数据
            % 输入:
            %   initialHistory (可选) - 包含初始 PopulationState 对象的数组

            % 创建一个新的图窗
            obj.Figure = figure('Name', '种群模拟展板', 'NumberTitle', 'off', 'Units', 'normalized', 'Position', [0.1, 0.1, 0.8, 0.8]); % 设置图窗大小和位置

            % 创建平铺图块布局
            obj.Layout = tiledlayout(obj.Figure, obj.LayoutRows, obj.LayoutCols);

            % 调整布局的间距和边距 (可选，根据需要调整)
            obj.Layout.TileSpacing = 'compact'; % 或 'tight', 'none'
            obj.Layout.Padding = 'compact';     % 或 'tight', 'none'
            % 设置图块索引顺序为列优先
            obj.Layout.TileIndexing = 'columnmajor';


            % --- 创建并放置子图 axes ---

            % 左侧 4 个布局 (生命周期/性别 比例和数量) - 占据第 1 列
            obj.AxRelRatioLifeCycle = nexttile(obj.Layout); % (1,1)
            title(obj.AxRelRatioLifeCycle, '生命周期相对比例 (图1)'); % 占位标题
            ylabel(obj.AxRelRatioLifeCycle, '比例');

            obj.AxRelRatioGender = nexttile(obj.Layout); % (2,1)
            title(obj.AxRelRatioGender, '性别相对比例 (图2)'); % 占位标题
            ylabel(obj.AxRelRatioGender, '比例');

            obj.AxAbsCountLifeCycle = nexttile(obj.Layout); % (3,1)
            title(obj.AxAbsCountLifeCycle, '生命周期绝对数量 (图3)'); % 占位标题
            ylabel(obj.AxAbsCountLifeCycle, '数量');

            obj.AxAbsCountGender = nexttile(obj.Layout); % (4,1)
            title(obj.AxAbsCountGender, '性别绝对数量 (图4)'); % 占位标题
            ylabel(obj.AxAbsCountGender, '数量');


            % 性别结构饼图 - 占据 (1,2) 位置
            obj.AxGenderPie = nexttile(obj.Layout); % (1,2)
            title(obj.AxGenderPie, '当前年份性别结构饼图 (图6)'); % 占位标题
            

            % 年龄结构直方图+核密度估计 - 占据 (2,2) 位置，跨 1 行 2 列
            obj.AxAgeHistKDE = nexttile(obj.Layout, [1 2]); % 从 (2,2) 开始，跨 1 行 2 列 (占据 6, 7)
            title(obj.AxAgeHistKDE, '当前年份年龄分布 (图7)'); % 占位标题
            xlabel(obj.AxAgeHistKDE, '年龄');
            ylabel(obj.AxAgeHistKDE, '密度/计数');
            grid(obj.AxAgeHistKDE, 'on');

            % 年龄结构小提琴图 - 占据 (3,2) 位置，跨 1 行 2 列
            obj.AxAgeViolin = nexttile(obj.Layout, [1 2]); % 从 (3,2) 开始，跨 1 行 2 列 (占据 10, 11)
            title(obj.AxAgeViolin, '当前年份年龄分布小提琴图 (图8)'); % 占位标题
            ylabel(obj.AxAgeViolin, '年龄');

            % 全局时间线折线图 - 占据 (4,2) 位置，跨 1 行 3 列
            obj.AxGlobalTimeline = nexttile(obj.Layout, [1 3]); % 从 (4,2) 开始，跨 1 行 2 列 (占据 8, 12)
            title(obj.AxGlobalTimeline, '种群总数量时间线 (图5)'); % 占位标题
            xlabel(obj.AxGlobalTimeline, '年份');
            ylabel(obj.AxGlobalTimeline, '总数量');
            grid(obj.AxGlobalTimeline, 'on'); % 添加网格线

            % 年龄结构甜甜圈图 - 占据 (1,3) 位置
            obj.AxAgeDonut = nexttile(obj.Layout); % (1,3)
            title(obj.AxAgeDonut, '当前年份年龄结构甜甜圈图'); % 占位标题
            

            % 世代分组堆叠条形图 - 占据 (1,4) 位置
            obj.AxGenGroupedStacked = nexttile(obj.Layout); % (1,4)
            title(obj.AxGenGroupedStacked, '世代分组数量 (图9)'); % 占位标题
            ylabel(obj.AxGenGroupedStacked, '数量');
            grid(obj.AxGenGroupedStacked, 'on');


            % 世代相对比例堆叠条形图 - 占据 (2,4) 位置，跨 2 行 1 列
            obj.AxGenRelRatio = nexttile(obj.Layout, [2 1]); % 从 (2,4) 开始，跨 2 行 1 列 (占据 14, 15)
            title(obj.AxGenRelRatio, '世代相对比例 (图10)'); % 占位标题
            ylabel(obj.AxGenRelRatio, '比例');
            grid(obj.AxGenRelRatio, 'on');

            % 可以选择添加一个总标题
            title(obj.Layout, '种群模拟数据可视化展板');

            % 确保图窗可见
            figure(obj.Figure);

            % 初始化模拟历史数据
            if nargin > 0 && ~isempty(initialHistory)
                 % 验证输入是否为 PopulationState 对象的向量
                 if ~isa(initialHistory, 'PopulationState') || ~ismatrix(initialHistory) || min(size(initialHistory)) > 1
                     error('输入参数必须是 PopulationState 对象的向量');
                 end
                 obj.SimulationHistory = initialHistory;
            else
                 % 初始化为空的 PopulationState 对象数组
                 obj.SimulationHistory = PopulationState.empty(1, 0);
            end

            % 初始化需要细粒度更新的绘图元素句柄 (例如全局时间线)
            % 在这里进行初始绘图，并存储句柄
            if ~isempty(obj.SimulationHistory)
                 years = [obj.SimulationHistory.year];
                 totalPopulations = [obj.SimulationHistory.num_individuals]; % 假设 PopulationState 有 num_individuals 属性
                 % 绘制初始线条并存储句柄
                 obj.GlobalTimelineLine = plot(obj.AxGlobalTimeline, years, totalPopulations, '-o');
                 % 设置 x 轴范围
                 if ~isempty(years)
                     xlim(obj.AxGlobalTimeline, [min(years), max(years)]);
                 end
            else
                 % 如果初始历史为空，先绘制一个空的线条对象，以便后续更新
                 obj.GlobalTimelineLine = plot(obj.AxGlobalTimeline, NaN, NaN, '-o');
                 % 设置初始 x 轴范围，例如从 0 开始
                 xlim(obj.AxGlobalTimeline, [0, 1]);
            end

             % 初始更新所有图表
             % 调用 updateDashboard，它将使用 SimulationHistory 中的最新状态进行绘制
             obj.updateDashboard();

        end

        function addStateSnapshot(obj, state)
            % addStateSnapshot 添加一个新的种群状态快照到历史记录并更新图表
            % 输入:
            %   state - PopulationState 对象，表示当前年份的种群状态

            % 验证输入是否为 PopulationState 对象
            if ~isa(state, 'PopulationState') || ~isscalar(state)
                error('输入必须是一个 PopulationState 对象');
            end

            % 将新的状态对象添加到历史记录数组
            obj.SimulationHistory = [obj.SimulationHistory, state];

            % 立即更新全局时间线图 (细粒度更新 - 方案 1)
            % 假设 PopulationState 有 year 和 num_individuals 属性
            if isprop(state, 'year') && isprop(state, 'num_individuals')
                 newYear = state.year;
                 newTotalPopulation = state.num_individuals;

                 % 获取当前线条数据
                 xdata = get(obj.GlobalTimelineLine, 'XData');
                 ydata = get(obj.GlobalTimelineLine, 'YData');

                 % 追加新数据点
                 if isnan(xdata(1)) % 处理初始为空的情况
                     set(obj.GlobalTimelineLine, 'XData', newYear, 'YData', newTotalPopulation);
                 else
                     set(obj.GlobalTimelineLine, 'XData', [xdata, newYear], 'YData', [ydata, newTotalPopulation]);
                 end

                 % 更新 x 轴范围
                 current_years = get(obj.GlobalTimelineLine, 'XData');
                 if ~isempty(current_years) && ~isnan(current_years(1))
                     xlim(obj.AxGlobalTimeline, [min(current_years), max(current_years)]);
                 else
                      % 如果数据仍然为空，保持初始范围或根据需要调整
                      xlim(obj.AxGlobalTimeline, [0, 1]);
                 end

            else
                 warning('新添加的 PopulationState 对象缺少年份或总个体数量属性，无法更新全局时间线图');
            end

            % 调用 updateDashboard 方法更新其他图表
            % updateDashboard 将使用刚刚添加到 SimulationHistory 中的最新状态
            obj.updateDashboard();

            % 刷新图窗显示
            drawnow;
        end

        function updateDashboard(obj, stateToDisplay)
            % updateDashboard 根据提供的状态更新所有图表
            % 如果未提供状态，则使用 SimulationHistory 中的最新状态
            % 输入:
            %   stateToDisplay (可选) - PopulationState 对象，要显示的特定年份的种群状态

            % 确定要用于更新图表的状态
            if nargin < 2 || isempty(stateToDisplay)
                % 如果未提供状态，使用历史记录中的最新状态
                if isempty(obj.SimulationHistory)
                    warning('模拟历史数据为空，无法更新图表');
                    % 清空所有 axes (可选)
                    cla(obj.AxRelRatioLifeCycle); cla(obj.AxRelRatioGender);
                    cla(obj.AxAbsCountLifeCycle); cla(obj.AxAbsCountGender);
                    % AxGlobalTimeline 由 addStateSnapshot 处理
                    cla(obj.AxGenderPie); cla(obj.AxAgeDonut); % 清空饼图和甜甜圈图 axes
                    cla(obj.AxAgeHistKDE); cla(obj.AxAgeViolin);
                    cla(obj.AxGenGroupedStacked); cla(obj.AxGenRelRatio);
                    return;
                end
                stateToDisplay = obj.SimulationHistory(end);
            else
                % 如果提供了状态，验证其类型
                 if ~isa(stateToDisplay, 'PopulationState') || ~isscalar(stateToDisplay)
                     error('stateToDisplay 必须是一个 PopulationState 对象');
                 end
            end


            % --- 调用各个子图的更新方法 ---
            % 这些方法现在接收 stateToDisplay 对象

            % 更新生命周期和性别比例/数量图 (使用 stateToDisplay)
            obj.updateLifeCycleRatioPlots(stateToDisplay);
            obj.updateAbsCountPlots(stateToDisplay);

            % 全局时间线图的更新已在 addStateSnapshot 中处理 (细粒度)
            % 如果需要在此处进行全量重绘（例如 displayYear 调用），可以在 displayYear 中单独处理
            % 或者修改 updateGlobalTimelinePlotFull 方法并在这里调用

            % 更新性别结构饼图和甜甜圈图 (图6)
            % 注意：这些图需要 PopulationState 存储原始年龄数据或年龄分布统计
            % 假设 PopulationState 有一个 ages 属性
            if isprop(stateToDisplay, 'ages') && ~isempty(stateToDisplay.ages)
                 % 调用更新饼图和甜甜圈图的方法
                 obj.updatePieDonutPlots(stateToDisplay.ages, stateToDisplay.year); % 传递年龄数据和年份
            else
                 warning('PopulationState 对象不包含年龄数据，跳过饼图和甜甜圈图更新');
                 cla(obj.AxGenderPie); cla(obj.AxAgeDonut);
            end

            % 更新年龄结构直方图和小提琴图 (图7, 图8)
            % 注意：这些图需要 PopulationState 存储原始年龄数据或年龄分布统计
            % 假设 PopulationState 有一个 ages 属性
            if isprop(stateToDisplay, 'ages') && ~isempty(stateToDisplay.ages)
                 obj.updateAgeStructurePlots(stateToDisplay.ages); % 传递年龄数据
            else
                 warning('PopulationState 对象不包含年龄数据，跳过年龄结构图更新');
                 cla(obj.AxAgeHistKDE); cla(obj.AxAgeViolin);
            end


            % 更新世代相关的图 (使用 stateToDisplay - 方案 3 的简化应用)
            % 假设 PopulationState 存储 generations 和 life_statuses
             if isprop(stateToDisplay, 'generations') && isprop(stateToDisplay, 'life_statuses')
                 % 如果世代图需要连年数据，可以在这里根据需要从 obj.SimulationHistory 提取子集
                 % 并将历史子集传递给 updateGenerationPlots
                 % 例如：
                 % if isprop(obj, 'HistoryWindowSize') && isfinite(obj.HistoryWindowSize)
                 %     % 找到 stateToDisplay 在历史中的索引
                 %     [~, latestIdx] = ismember(stateToDisplay.year, [obj.SimulationHistory.year]);
                 %     if latestIdx > 0
                 %          historySubset = obj.SimulationHistory(max(1, latestIdx - obj.HistoryWindowSize + 1):latestIdx);
                 %          obj.updateGenerationPlots(historySubset); % 将历史子集传递给更新方法
                 %     else
                 %          warning('无法在历史记录中找到 stateToDisplay 的年份');
                 %          cla(obj.AxGenGroupedStacked); cla(obj.AxGenRelRatio);
                 %     end
                 % else
                 %     % 显示所有历史 (如果 updateGenerationPlots 支持)
                 %     obj.updateGenerationPlots(obj.SimulationHistory);
                 % end

                 % 目前假设世代图只需要当前年份数据
                 obj.updateGenerationPlots(stateToDisplay);

             else
                 warning('PopulationState 对象不包含世代或生命状态数据，跳过世代图更新');
                 cla(obj.AxGenGroupedStacked);
                 cla(obj.AxGenRelRatio);
             end

            % drawnow; % 已在 addStateSnapshot 中调用
        end

        function displayYear(obj, targetYear)
            % displayYear 根据指定的年份更新图表显示
            % 用于滑块拖拽等手动查看历史数据的情况
            % 输入:
            %   targetYear - 要显示的年份

            % 确保历史数据不为空
            if isempty(obj.SimulationHistory)
                warning('模拟历史数据为空，无法显示指定年份数据');
                return;
            end

            % 在历史记录中查找指定年份的 PopulationState
            yearsInHistory = [obj.SimulationHistory.year];
            stateIndex = find(yearsInHistory == targetYear, 1);

            % 如果找到对应年份的数据
            if ~isempty(stateIndex)
                stateToDisplay = obj.SimulationHistory(stateIndex);
                % 调用 updateDashboard 方法更新图表
                % updateDashboard 将使用找到的特定年份的状态进行绘制
                obj.updateDashboard(stateToDisplay);

                % 刷新图窗显示
                drawnow;
            else
                warning('历史记录中未找到年份 %d 的数据', targetYear);
                % 可以选择在此处清空图表或显示提示信息
            end
        end

        function latestYear = getLatestSimulatedYear(obj)
            % getLatestSimulatedYear 获取 SimulationHistory 中存储的最新年份
            % 输出:
            %   latestYear - 最新模拟年份，如果历史为空则返回 NaN

            if isempty(obj.SimulationHistory)
                latestYear = NaN;
            else
                latestYear = obj.SimulationHistory(end).year; % 假设 PopulationState 有 year 属性
            end
        end

        function years = getYearsInHistory(obj)
            % getYearsInHistory 获取 SimulationHistory 中所有可用年份的数组
            % 输出:
            %   years - 历史记录中的年份数组，如果历史为空则返回空数组

            if isempty(obj.SimulationHistory)
                years = [];
            else
                years = [obj.SimulationHistory.year]; % 假设 PopulationState 有 year 属性
            end
        end


        % --- updateGlobalTimelinePlotFull 方法用于全量重绘全局时间线图 (可选) ---
        % function updateGlobalTimelinePlotFull(obj, history)
        %     % updateGlobalTimelinePlotFull 全量重绘全局时间线图 (图5)
        %     % history: PopulationState 对象的历史记录数组
        %     % 此方法在初始绘制或需要全量刷新时调用

        %     cla(obj.AxGlobalTimeline); % 清除旧图

        %     if isempty(history) || ~isprop(history, 'year') || ~isprop(history, 'num_individuals')
        %          title(obj.AxGlobalTimeline, '种群总数量时间线 (无数据)');
        %          xlabel(obj.AxGlobalTimeline, '年份');
        %          ylabel(obj.AxGlobalTimeline, '总数量');
        %          grid(obj.AxGlobalTimeline, 'on');
        %          % 绘制空的线条对象
        %          obj.GlobalTimelineLine = plot(obj.AxGlobalTimeline, NaN, NaN, '-o');
        %          xlim(obj.AxGlobalTimeline, [0, 1]);
        %          return;
        %     end

        %     years = [history.year];
        %     totalPopulations = [history.SimulationHistory.num_individuals]; % Fix: Access num_individuals from history elements
        %     if isempty(totalPopulations)
        %          title(obj.AxGlobalTimeline, '种群总数量时间线 (无数据)');
        %          xlabel(obj.AxGlobalTimeline, '年份');
        %          ylabel(obj.AxGlobalTimeline, '总数量');
        %          grid(obj.AxGlobalTimeline, 'on');
        %          % 绘制空的线条对象
        %          obj.GlobalTimelineLine = plot(obj.AxGlobalTimeline, NaN, NaN, '-o');
        %          xlim(obj.AxGlobalTimeline, [0, 1]);
        %          return;
        %     end


        %     % 绘制线条并存储句柄
        %     obj.GlobalTimelineLine = plot(obj.AxGlobalTimeline, years, totalPopulations, '-o');
        %     title(obj.AxGlobalTimeline, '种群总数量时间线');
        %     xlabel(obj.AxGlobalTimeline, '年份');
        %     ylabel(obj.AxGlobalTimeline, '总数量');
        %     grid(obj.AxGlobalTimeline, 'on');
        %     % 设置 x 轴范围
        %     xlim(obj.AxGlobalTimeline, [min(years), max(years)]);
        % end


        % --- 添加用于更新各个子图的具体方法 ---
        % 这些方法现在会从传入的 PopulationState 对象或数据中获取数据

        function updateLifeCycleRatioPlots(obj, state)
            % updateLifeCycleRatioPlots 更新生命周期比例相关的图 (图1, 图2)
            % state: 当前年份的 PopulationState 对象

            % 假设 PopulationState 有 num_premature, num_mature, num_old, num_dead, num_males, num_females 属性
            if isprop(state, 'num_premature') && isprop(state, 'num_males')
                % 计算总已出生个体数量 (排除 prebirth)
                total_born = state.num_premature + state.num_mature + state.num_old + state.num_dead;

                if total_born > 0
                    % 生命周期比例
                    life_cycle_counts = [state.num_premature, state.num_mature, state.num_old, state.num_dead];
                    life_cycle_ratios = life_cycle_counts / total_born;
                    % 假设您想绘制堆叠条形图，这里只是一个占位示例
                    cla(obj.AxRelRatioLifeCycle); % 清除旧图
                    bar(obj.AxRelRatioLifeCycle, life_cycle_ratios, 'stacked');
                    title(obj.AxRelRatioLifeCycle, sprintf('生命周期相对比例 (年份: %d)', state.year));
                    ylabel(obj.AxRelRatioLifeCycle, '比例');
                    % 设置 x 轴标签或图例，取决于具体绘图方式

                    % 性别比例
                    gender_counts = [state.num_males, state.num_females];
                    gender_ratios = gender_counts / total_born;
                     cla(obj.AxRelRatioGender); % 清除旧图
                    bar(obj.AxRelRatioGender, gender_ratios, 'stacked');
                     title(obj.AxRelRatioGender, sprintf('性别相对比例 (年份: %d)', state.year));
                     ylabel(obj.AxRelRatioGender, '比例');
                     % 设置 x 轴标签或图例
                else
                     cla(obj.AxRelRatioLifeCycle);
                     cla(obj.AxRelRatioGender);
                     title(obj.AxRelRatioLifeCycle, sprintf('生命周期相对比例 (年份: %d)', state.year));
                     title(obj.AxRelRatioGender, sprintf('性别相对比例 (年份: %d)', state.year));
                end
            else
                warning('PopulationState 对象缺少生命周期或性别统计属性，无法更新比例图');
                 cla(obj.AxRelRatioLifeCycle);
                 cla(obj.AxRelRatioGender);
                 title(obj.AxRelRatioLifeCycle, sprintf('生命周期相对比例 (年份: %d)', state.year));
                 title(obj.AxRelRatioGender, sprintf('性别相对比例 (年份: %d)', state.year));
            end
        end

         function updateAbsCountPlots(obj, state)
            % updateAbsCountPlots 更新绝对数量相关的图 (图3, 图4)
            % state: 当前年份的 PopulationState 对象

            % 假设 PopulationState 有 num_premature, num_mature, num_old, num_dead, num_males, num_females 属性
             if isprop(state, 'num_premature') && isprop(state, 'num_males')
                 % 生命周期绝对数量
                 life_cycle_counts = [state.num_premature, state.num_mature, state.num_old, state.num_dead];
                 cla(obj.AxAbsCountLifeCycle); % 清除旧图
                 bar(obj.AxAbsCountLifeCycle, life_cycle_counts); % 假设是分组条形图
                 title(obj.AxAbsCountLifeCycle, sprintf('生命周期绝对数量 (年份: %d)', state.year));
                 ylabel(obj.AxAbsCountLifeCycle, '数量');
                 % 设置 x 轴标签或图例

                 % 性别绝对数量
                 gender_counts = [state.num_males, state.num_females];
                 cla(obj.AxAbsCountGender); % 清除旧图
                 bar(obj.AxAbsCountGender, gender_counts); % 假设是分组条形图
                 title(obj.AxAbsCountGender, sprintf('性别绝对数量 (年份: %d)', state.year));
                 ylabel(obj.AxAbsCountGender, '数量');
                 % 设置 x 轴标签或图例
             else
                 warning('PopulationState 对象缺少生命周期或性别统计属性，无法更新绝对数量图');
                 cla(obj.AxAbsCountLifeCycle);
                 cla(obj.AxAbsCountGender);
                 title(obj.AxAbsCountLifeCycle, sprintf('生命周期绝对数量 (年份: %d)', state.year));
                 title(obj.AxAbsCountGender, sprintf('性别绝对数量 (年份: %d)', state.year));
             end
         end


         function updateAgeStructurePlots(obj, ages)
            % updateAgeStructurePlots 更新年龄结构相关的图 (图7, 图8)
            % ages: 当前年份所有已出生个体的年龄数组
            % 注意：饼图和甜甜圈图的更新逻辑已移至 updatePieDonutPlots

            % 清除旧图
            cla(obj.AxAgeHistKDE);
            cla(obj.AxAgeViolin);

            if isempty(ages)
                 title(obj.AxAgeHistKDE, '当前年份年龄分布 (无数据)');
                 title(obj.AxAgeViolin, '当前年份年龄分布小提琴图 (无数据)');
                 return;
            end

            % 直方图和 KDE
            histogram(obj.AxAgeHistKDE, ages, 'Normalization', 'probability');
            hold(obj.AxAgeHistKDE, 'on');
            % 假设您有 'kde' 函数或使用 fitdist/ksdensity
            % 示例使用 ksdensity
            [f, xi] = ksdensity(ages);
            plot(obj.AxAgeHistKDE, xi, f, 'LineWidth', 1.5);
            hold(obj.AxAgeHistKDE, 'off');
            title(obj.AxAgeHistKDE, sprintf('当前年份年龄分布 (%d)', obj.SimulationHistory(end).year));
            xlabel(obj.AxAgeHistKDE, '年龄');
            ylabel(obj.AxAgeHistKDE, '密度/计数');
             grid(obj.AxAgeHistKDE, 'on');

            % 小提琴图 (需要一个分组变量，如果没有，可以简单绘制分布)
            % 假设使用 violinplot 函数 (需要安装 File Exchange 中的工具箱)
            % 如果没有 violinplot，可以考虑 boxplot 或其他分布图
            % 示例使用 boxplot 作为替代
            boxplot(obj.AxAgeViolin, ages, 'Orientation', 'horizontal');
            title(obj.AxAgeViolin, sprintf('当前年份年龄分布 (%d)', obj.SimulationHistory(end).year));
            xlabel(obj.AxAgeViolin, '年龄');
            ylabel(obj.AxAgeViolin, ''); % 小提琴图通常 x 轴是分组，y 轴是值
            % 调整 y 轴刻度，例如显示年龄范围
            % ylim(obj.AxAgeViolin, [min(ages), max(ages)]); % 可能需要调整

         end

         function updatePieDonutPlots(obj, ages, year)
            % updatePieDonutPlots 更新性别结构饼图和甜甜圈图 (图6)
            % ages: 当前年份所有已出生个体的年龄数组 (假设这里仍然绘制年龄分布)
            % year: 当前年份

            % 清除旧图
            cla(obj.AxGenderPie);
            cla(obj.AxAgeDonut);

            if isempty(ages)
                 title(obj.AxGenderPie, '饼图 (无数据)');
                 title(obj.AxAgeDonut, '甜甜圈图 (无数据)');
                 return;
            end

            % 饼图 (需要将年龄分组)
            % 示例年龄分组 (您可以根据需要调整)
            age_group_edges = [0, 10, 20, 30, 40, 50, 60, 70, Inf];
            age_group_labels = {'0-9', '10-19', '20-29', '30-39', '40-49', '50-59', '60-69', '70+'};
            [counts, ~, bin_indices] = histcounts(ages, age_group_edges);
            % 过滤掉计数为零的组，避免饼图切片不显示
            valid_counts = counts(counts > 0);
            valid_labels = age_group_labels(counts > 0);

            if ~isempty(valid_counts)
                % 绘制饼图 (在 AxGenderPie)
                pie(obj.AxGenderPie, valid_counts);
                title(obj.AxGenderPie, '饼图'); % 子图标题
                legend(obj.AxGenderPie, valid_labels, 'Location', 'southoutside', 'Orientation', 'horizontal'); % 添加图例

                % 绘制甜甜圈图 (在 AxAgeDonut, 需要 R2023b 或更高版本)
                 try
                     donut(obj.AxAgeDonut, valid_counts);
                     title(obj.AxAgeDonut, '甜甜圈图'); % 子图标题
                     % 甜甜圈图通常自带标签或图例，根据需要调整
                 catch
                     warning('当前 MATLAB 版本不支持 donutchart，跳过甜甜圈图绘制');
                     title(obj.AxAgeDonut, '甜甜圈图 (不支持)');
                 end

            else
                 title(obj.AxGenderPie, '饼图 (无数据)');
                 title(obj.AxAgeDonut, '甜甜圈图 (无数据)');
            end

            % Removed panel title update as panel is removed
            % obj.AgePieDonutPanel.Title = sprintf('图表面板 1 (图6, 年份: %d)', year);

         end


         function updateGenerationPlots(obj, state)
            % updateGenerationPlots 更新世代相关的图 (图9, 图10)
            % state: 当前年份的 PopulationState 对象 (假设只需要最新年份的世代分布)

            % 清除旧图
            cla(obj.AxGenGroupedStacked);
            cla(obj.AxGenRelRatio);

            if isempty(state.generations) || isempty(state.life_statuses)
                 title(obj.AxGenGroupedStacked, '世代分组数量 (无数据)');
                 title(obj.AxGenRelRatio, '世代相对比例 (无数据)');
                 return;
            end

            % 获取最新的世代和生命状态数据
            generations = state.generations; % 假设 PopulationState 存储 generations
            lifeStatuses = state.life_statuses; % 假设 PopulationState 存储 life_statuses

            if isempty(generations) || isempty(lifeStatuses)
                 title(obj.AxGenGroupedStacked, '世代分组数量 (无数据)');
                 title(obj.AxGenRelRatio, '世代相对比例 (无数据)');
                 return;
            end


            % 图9: 世代分组数量 (堆叠条形图)
            % 需要按世代和生命状态分组计数
            uniqueGens = unique(generations);
            lifeCycleStates = categories(LifeCycleState.Prebirth); % 获取所有生命状态的字符串名称 (排除 Prebirth 如果不需要)
            % 如果需要排除 Prebirth 和 Dead，可以这样做:
            % lifeCycleStates = categories(LifeCycleState.Premature:LifeCycleState.Old);

            countsMatrix = zeros(length(uniqueGens), length(lifeCycleStates));

            for i = 1:length(uniqueGens)
                currentGen = uniqueGens(i);
                genMask = generations == currentGen;
                genLifeStatuses = lifeStatuses(genMask);

                for j = 1:length(lifeCycleStates)
                    currentStateStr = lifeCycleStates{j};
                    % 将字符串转换为枚举成员进行比较
                    currentStateEnum = LifeCycleState.(currentStateStr);
                    countsMatrix(i, j) = nnz(genLifeStatuses == currentStateEnum);
                end
            end

            % 绘制堆叠条形图
            bar(obj.AxGenGroupedStacked, uniqueGens, countsMatrix, 'stacked');
            title(obj.AxGenGroupedStacked, sprintf('世代分组数量 (%d)', state.year));
            xlabel(obj.AxGenGroupedStacked, '世代');
            ylabel(obj.AxGenGroupedStacked, '数量');
            legend(obj.AxGenGroupedStacked, lifeCycleStates, 'Location', 'northwest'); % 添加图例
            grid(obj.AxGenGroupedStacked, 'on');


            % 图10: 世代相对比例 (堆叠条形图)
            % 需要按世代计算各生命状态的比例
            ratiosMatrix = zeros(length(uniqueGens), length(lifeCycleStates));

             for i = 1:length(uniqueGens)
                currentGen = uniqueGens(i);
                genMask = generations == currentGen;
                genLifeStatuses = lifeStatuses(genMask);
                totalInGen = length(genLifeStatuses);

                if totalInGen > 0
                    for j = 1:length(lifeCycleStates)
                        currentStateStr = lifeCycleStates{j};
                        currentStateEnum = LifeCycleState.(currentStateStr);
                        ratiosMatrix(i, j) = nnz(genLifeStatuses == currentStateEnum) / totalInGen;
                    end
                end
             end

            % 绘制堆叠条形图
            bar(obj.AxGenRelRatio, uniqueGens, ratiosMatrix, 'stacked');
            title(obj.AxGenRelRatio, sprintf('世代相对比例 (%d)', state.year));
            xlabel(obj.AxGenRelRatio, '世代');
            ylabel(obj.AxGenRelRatio, '比例');
            legend(obj.AxGenRelRatio, lifeCycleStates, 'Location', 'northwest'); % 添加图例
            grid(obj.AxGenRelRatio, 'on');

         end

        % --- 添加其他辅助方法 (可选) ---

        % function ax = getAxes(obj, plotName)
        %     % getAxes 根据名称获取子图 axes 句柄
        %     % plotName: 字符串，例如 'AxGlobalTimeline'
        %     % 返回对应的 axes 句柄
        %     if isprop(obj, plotName)
        %         ax = obj.(plotName);
        %     else
        %         error('未知子图名称: %s', plotName);
        %     end
        % end
    end
end
