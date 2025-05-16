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
        AxGenderPie {mustBeAxesPieDonut} = matlab.graphics.axis.Axes            % 当前年份性别结构饼图 axes 6
        AxAgeDonut {mustBeAxesPieDonut} = matlab.graphics.axis.Axes           % 当前年份年龄结构甜甜圈图 axes
        AxAgeHistKDE matlab.graphics.axis.Axes         % 当前年份年龄结构直方图+核密度估计 axes 7
        AxAgeViolin matlab.graphics.axis.Axes          % 当前年份年龄结构小提琴图 axes 8
        AxGenGroupedStacked matlab.graphics.axis.Axes  % 世代分组堆叠条形图 axes 9
        AxGenRelRatio matlab.graphics.axis.Axes        % 世代相对比例堆叠条形图 axes 10
    end

    properties (Constant, Access = private)
        % 存储需要连年数据的图所需的历史窗口大小 (方案 3)
        % 例如：HistoryWindowSize = 100; % 只显示最近 100 年的数据
        HistoryWindowSize = 20; % 默认窗口20年
        LayoutRows = 4 % 布局行数
        LayoutCols = 4 % 布局列数 % 修改为 4x4 布局
    end

    properties (Access = private)
        % 指示每个子图是否已首次绘制（用于触发静态参数初始化）
        % 此结构体将在 initializePlotFlags 方法中动态初始化
        PlotInitializedFlags struct;

        % 静态绘图参数：使用 table 存放，rowname 为 axes 句柄名称，变量为参数类型 (Title, XLabel, YLabel)
        % 初始值将在 axes 初始化完成后设置
        PlotParameters table

        % 存储 PlotInitializedEvent 监听器的句柄
        PlotInitializedListener event.listener;
    end

    properties (Dependent)
        PlotDict dictionary
    end

    % 定义事件，表示某个子图已首次绘制
    events
        PlotInitializedEvent
    end

    methods
        function obj = PopulationDashboard(initialHistory)
            % 构造函数
            % 创建图窗和子图布局，并初始化模拟历史数据
            % 输入:
            %   initialHistory (可选) - 包含初始 PopulationState 对象的数组

            % 创建一个新的图窗
            monitorpos = get(0, "MonitorPositions");
            obj.Figure = figure('Name', '种群模拟展板', ...
            'NumberTitle', 'off', 'Position', monitorpos(2, :)); % 设置图窗大小和位置

            % 创建平铺图块布局
            obj.Layout = tiledlayout(obj.Figure, obj.LayoutRows, obj.LayoutCols);

            % 调整布局的间距和边距 (可选，根据需要调整)
            obj.Layout.TileSpacing = 'none'; % 'loose', 'compact' 或 'tight', 'none'
            obj.Layout.Padding = 'compact';     % 'loose', 'compact' 或 'tight'
            % 设置图块索引顺序为列优先
            obj.Layout.TileIndexing = 'columnmajor';


            % --- 创建并放置子图 axes ---

            % 左侧 4 个布局 (生命周期/性别 比例和数量) - 占据第 1 列
            obj.AxRelRatioLifeCycle = nexttile(obj.Layout); % (1,1)

            obj.AxRelRatioGender = nexttile(obj.Layout); % (2,1)

            obj.AxAbsCountLifeCycle = nexttile(obj.Layout); % (3,1)

            obj.AxAbsCountGender = nexttile(obj.Layout); % (4,1)


            % 性别结构饼图 - 占据 (1,2) 位置
            obj.AxGenderPie = nexttile(obj.Layout); % (1,2)


            % 年龄结构直方图+核密度估计 - 占据 (2,2) 位置，跨 1 行 2 列
            obj.AxAgeHistKDE = nexttile(obj.Layout, [1 2]);
            grid(obj.AxAgeHistKDE, 'on');

            % 年龄结构小提琴图 - 占据 (3,2) 位置，跨 1 行 2 列
            obj.AxAgeViolin = nexttile(obj.Layout, [1 2]);


            % 全局时间线折线图 - 占据 (4,2) 位置，跨 1 行 3 列
            obj.AxGlobalTimeline = nexttile(obj.Layout, [1 3]);
            grid(obj.AxGlobalTimeline, 'on'); % 添加网格线

            % 年龄结构甜甜圈图 - 占据 (1,3) 位置
            obj.AxAgeDonut = nexttile(obj.Layout); % (1,3)


            % 世代分组堆叠条形图 - 占据 (1,4) 位置
            obj.AxGenGroupedStacked = nexttile(obj.Layout); % (1,4)
            grid(obj.AxGenGroupedStacked, 'on');


            % 世代相对比例堆叠条形图 - 占据 (2,4) 位置，跨 2 行 1 列
            obj.AxGenRelRatio = nexttile(obj.Layout, [2 1]);
            grid(obj.AxGenRelRatio, 'on');

            % % 可以选择添加一个总标题
            % title(obj.Layout, '种群模拟数据可视化展板');

            % 初始化 PlotInitializedFlags 结构体
            obj.initializePlotFlags();

            % 添加 PlotInitializedEvent 监听器
            % 注意：这里监听器被添加到 obj 对象本身，事件也由 obj 触发
            obj.PlotInitializedListener = addlistener(...
                obj, 'PlotInitializedEvent', @obj.handlePlotInitialization);


            % 确保图窗可见
            figure(obj.Figure);

            % 初始化模拟历史数据
            if nargin > 0 && ~isempty(initialHistory)
                 obj.SimulationHistory = initialHistory;
            else
                 % 初始化为空的 PopulationState 对象数组
                 obj.SimulationHistory = PopulationState.empty(1, 0);
            end

            % 初始更新所有图表
            % 调用 updateDashboard，它将使用 SimulationHistory 中的最新状态进行绘制
            % updateDashboard 会负责首次绘图和触发初始化事件
            obj.updateDashboard();
        end

        % --- Getter 方法用于计算依赖属性 ---
        function dict = get.PlotDict(obj)
            dict = dictionary();
            axesNames = fieldnames(obj.PlotInitializedFlags)';
            for axeName = axesNames
                dict(axeName) = obj.(string(axeName));
            end
        end

        % --- PlotInitializedFlags 结构体初始化方法 ---
        function initializePlotFlags(obj)
            % initializePlotFlags 动态初始化 PlotInitializedFlags 结构体
            % 根据类中 axes 属性的名称创建字段并设置为 false

            mc = meta.class.fromName(class(obj));
            propList = mc.PropertyList;

            % 过滤出 axes 属性
            axesProps = propList(arrayfun(@(p) startsWith(p.Name, 'Ax') ...
             && contains(p.Type.Name, 'Axes'), propList));
            axesNames = {axesProps.Name};

            % 初始化 PlotInitializedFlags 结构体
            obj.PlotInitializedFlags = struct();
            for i = 1:length(axesNames)
                obj.PlotInitializedFlags.(axesNames{i}) = false;
            end
        end

        % --- PlotInitializedEvent 回调函数 ---
        function handlePlotInitialization(obj, ~, ~)
            % handlePlotInitialization 在 PlotInitializedEvent 触发时调用
            % 检查所有子图是否已首次绘制，如果是，则初始化静态参数 table

            % 检查所有标志是否都为 true
            allInitialized = all(structfun(@(x) x, obj.PlotInitializedFlags));

            if allInitialized
                % 所有子图都已首次绘制，初始化静态参数 table
                obj.initializePlotParameters(); % 这会触发 PlotParameters 的 setter，进而调用 applyPlotParameters
                % 可选：移除监听器，因为初始化只需要发生一次
                delete(obj.PlotInitializedListener);
                obj.PlotInitializedListener = []; % 清空句柄
            end
        end

        % --- 静态绘图参数初始化方法 ---
        function initializePlotParameters(obj)
            % initializePlotParameters 初始化静态绘图参数 table
            % 在所有子图首次绘制完成后触发

            obj.PlotParameters = table(...
                {'生命周期相对比例 (图1)'; '性别相对比例 (图2)'; 
                '生命周期绝对数量 (图3)'; '存活个体性别数量 (图4)'; 
                '种群总数量时间线 (图5)'; '当前年份年龄结构饼图 (图6)'; 
                '当前年份年龄结构甜甜圈图'; '当前年份年龄分布 (图7)'; 
                '当前年份年龄分布小提琴图 (图8)'; '世代分组数量 (图9)'; 
                '世代相对比例 (图10)'}, ... % Title
                {''; ''; ''; ''; '年份'; ''; ''; '年龄'; '年龄'; '世代'; '世代'}, ... % XLabel
                {'比例'; '比例'; '数量'; '数量'; '总数量'; ''; ''; '密度/计数'; ''; '数量'; '比例'}, ... % YLabel
                'VariableNames', {'Title', 'XLabel', 'YLabel'}, ...
                'RowNames', fieldnames(obj.PlotInitializedFlags) ...
            );
            % PlotParameters 的 setter 方法会自动调用 applyPlotParameters
        end

        % --- Setter 方法用于实时更新参数 ---
        function set.PlotParameters(obj, value)
            % set.PlotParameters 设置 PlotParameters 属性并应用更改
            % 输入:
            %   value - 新的 PlotParameters table

            obj.PlotParameters = value;

            % 应用新的参数到 axes，只有在 axes 句柄已初始化后才执行
            % PlotInitializedFlags每次变为True后证明axes已经创建，触发监听方法
            % 监听方法判断为AllInitialized后才触发InitializePlotParameters
            % 最后触发该setter，因而还检查axes已创建是多余的
            % 直接调用applyPlotParameters
            obj.applyPlotParameters();
        end

        % --- 静态绘图参数应用方法 ---
        function applyPlotParameters(obj)
            % applyPlotParameters 将静态绘图参数应用到 axes
            % 在 PlotParameters 属性的 setter 中调用

            % 只有在 axes 句柄已初始化后才应用参数
            axesNames = fieldnames(obj.PlotInitializedFlags);
            if isempty(axesNames) || ~isvalid(obj.(axesNames{1}))
                 return; % Axes not yet created or invalid
            end

            % axesNames = obj.PlotParameters.RowNames;

            for i = 1:length(axesNames)
                axesName = axesNames{i};
                % 获取对应的 axes 句柄
                % 使用 try-catch 避免在 axes 句柄不存在时出错
                try
                    axesHandle = obj.(axesName);
                    if isvalid(axesHandle)
                        % 应用标题 (只设置基本标题，年份在 update 方法中添加)
                        if ~isempty(obj.PlotParameters{axesName, 'Title'})
                             title(axesHandle, obj.PlotParameters{axesName, 'Title'});
                        end

                        % 应用X轴标签
                        if ~isempty(obj.PlotParameters{axesName, 'XLabel'})
                             xlabel(axesHandle, obj.PlotParameters{axesName, 'XLabel'});
                        end

                        % 应用Y轴标签
                        if ~isempty(obj.PlotParameters{axesName, 'YLabel'})
                             ylabel(axesHandle, obj.PlotParameters{axesName, 'YLabel'});
                        end
                    end
                catch
                    % 如果 axes 句柄不存在或无效，忽略错误
                    warning('无法应用参数到 axes: %s', axesName);
                end
            end
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

            % 调用 updateDashboard 方法更新所有图表
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
            if nargin < 2 || isempty(obj.SimulationHistory)
                % 如果未提供状态，使用历史记录中的最新状态
                if isempty(obj.SimulationHistory)
                    warning('模拟历史数据为空，无法更新图表');
                    % 清空所有 axes (可选)
                    cla(obj.AxRelRatioLifeCycle); cla(obj.AxRelRatioGender);
                    cla(obj.AxAbsCountLifeCycle); cla(obj.AxAbsCountGender);
                    cla(obj.AxGlobalTimeline); % 清空全局时间线图
                    cla(obj.AxGenderPie); cla(obj.AxAgeDonut); % 清空饼图和甜甜圈图 axes
                    cla(obj.AxAgeHistKDE); cla(obj.AxAgeViolin);
                    cla(obj.AxGenGroupedStacked); cla(obj.AxGenRelRatio);
                    return;
                end
            end
            if ~exist("stateToDisplay", "var")
                stateToDisplay = PopulationState.empty;
            end
            if length(obj.SimulationHistory) > length(stateToDisplay)
                stateToDisplay = obj.SimulationHistory;
            else
                obj.SimulationHistory = stateToDisplay;
            end
            if length(stateToDisplay) > obj.HistoryWindowSize
                stateToDisplay = stateToDisplay(...
                    length(stateToDisplay) - obj.HistoryWindowSize + 1:end);
            end

            % --- 调用各个子图的更新方法，传递 PopulationState 对象 ---
            % 这些方法内部会处理首次绘制和触发初始化事件

            % 更新生命周期和性别比例/数量图和小提琴图
            obj.updateLifeCycleGenderPlots(stateToDisplay); % 传递 PopulationState 对象

            % 更新全局时间线图
            obj.updateGlobalTimelinePlot(obj.SimulationHistory); % 传递 PopulationState 对象

            % 更新年龄结构饼图、甜甜圈图、直方图
            obj.updateAgeDistributionPlots(stateToDisplay(end)); % 传递 PopulationState 对象


            % 更新世代相关的图
            obj.updateGenerationPlots(stateToDisplay); % 传递 PopulationState 对象


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
            % yearsInHistory = [obj.SimulationHistory.year];
            stateIndex = find(obj.getYearsInHistory() == targetYear, 1);

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

        % --- 添加用于更新各个子图的具体方法 ---
        % 这些方法现在接收 PopulationState 对象作为输入，并在首次绘制时触发事件

        function updateLifeCycleGenderPlots(obj, state)
            % updateLifeCycleGenderPlots 更新生命周期和性别相关的图 (图1, 图2, 图3, 图4)
            % state: 当前年份的 PopulationState 对象

            % 从 PopulationState 的依赖属性获取统计数据
            lifeCycleCounts = extractStructPropFields(state, 'LifeCycleGenderStats', 'LifeCycleCounts');
            genderCounts = extractStructPropFields(state, 'LifeCycleGenderStats', 'GenderCounts');
            lifeCycleRatios = extractStructPropFields(state, 'LifeCycleGenderStats', 'LifeCycleRatios');
            genderRatios = extractStructPropFields(state, 'LifeCycleGenderStats', 'GenderRatios');
            lifeCycleLabels = state(1).LifeCycleGenderStats.LifeCycleLabels;
            genderLabels = state(1).LifeCycleGenderStats.GenderLabels;
            year = [state.year]; % 从 PopulationState 对象获取年份
            % ages = cell2mat({state.ages}'); % 连年年龄矩阵，每年一行

            % % 清除旧图
            % cla(obj.AxRelRatioLifeCycle);
            % cla(obj.AxRelRatioGender);
            % cla(obj.AxAbsCountLifeCycle);
            % cla(obj.AxAbsCountGender);

            % 绘制生命周期相对比例 (图1)
            axes(obj.AxRelRatioLifeCycle)
            if ~obj.PlotInitializedFlags.AxRelRatioLifeCycle
                Hdl = bar(year, lifeCycleRatios, 'stacked', ...
                    'Tag', 'BarRelRatioLifeCycle');
                [Hdl.DisplayName] = deal(lifeCycleLabels{:});
                % legend
                obj.PlotInitializedFlags.AxRelRatioLifeCycle = true;
                notify(obj, 'PlotInitializedEvent');
            else % 后续更新只更新数据
                Hdl = findobj(gca, 'Tag', 'BarRelRatioLifeCycle');
                updatePlotData(Hdl, year, lifeCycleRatios)
                % Hdl.XData = year;
                % Hdl.YData = lifeCycleRatios;
            end

            % 绘制性别相对比例 (图2)
            axes(obj.AxRelRatioGender)
            if ~obj.PlotInitializedFlags.AxRelRatioGender
                Hdl = bar(year, genderRatios, 'stacked', ...
                    'Tag', 'BarRelRatioGender');
                [Hdl.DisplayName] = deal(genderLabels{:});
                % legend
                obj.PlotInitializedFlags.AxRelRatioGender = true;
                notify(obj, 'PlotInitializedEvent');
            else % 后续更新只更新数据
                Hdl = findobj(gca, 'Tag', 'BarRelRatioGender');
                updatePlotData(Hdl, year, genderRatios)
                % Hdl.XData = year;
                % Hdl.YData = genderRatios;
            end
             
            % 绘制生命周期绝对数量 (图3)
            axes(obj.AxAbsCountLifeCycle)
            if ~obj.PlotInitializedFlags.AxAbsCountLifeCycle
                Hdl = bar(year, lifeCycleCounts, ...
                    'Tag', 'BarAbsCountLifeCycle');
                [Hdl.DisplayName] = deal(lifeCycleLabels{:});
                % legend
                hold on
                plot(year, lifeCycleCounts, ... % 'DisplayName', lifeCycleLabels, ...
                    'o-', 'LineWidth', 2, 'MarkerFaceColor', 'auto', ...
                    'Tag', 'LineAbsCountLifeCycle');
                hold off
                obj.PlotInitializedFlags.AxAbsCountLifeCycle = true;
                notify(obj, 'PlotInitializedEvent');
            else % 后续更新只更新数据
                Hdl = findobj(gca, 'Tag', 'BarAbsCountLifeCycle');
                updatePlotData(Hdl, year, lifeCycleCounts)
                % Hdl.XData = year;
                % Hdl.YData = lifeCycleCounts;
                Hdl = findobj(gca, 'Tag', 'LineAbsCountLifeCycle');
                updatePlotData(Hdl, year, lifeCycleCounts)
                % Hdl.XData = year;
                % Hdl.YData = lifeCycleCounts;
            end
            
            % 绘制性别绝对数量 (图4)
            axes(obj.AxAbsCountGender)
            if ~obj.PlotInitializedFlags.AxAbsCountGender
                Hdl = bar(year, genderCounts, ...
                    'Tag', 'BarAbsCountGender');
                [Hdl.DisplayName] = deal(genderLabels{:});
                % legend
                hold on
                plot(year, genderCounts, ... % 'DisplayName', genderLabels, ...
                    'o-', 'LineWidth', 2, 'MarkerFaceColor', 'auto', ...
                    'Tag', 'LineAbsCountGender');
                hold off
                obj.PlotInitializedFlags.AxAbsCountGender = true;
                notify(obj, 'PlotInitializedEvent');
            else % 后续更新只更新数据
                Hdl = findobj(gca, 'Tag', 'BarAbsCountGender');
                updatePlotData(Hdl, year, genderCounts)
                % Hdl.XData = year;
                % Hdl.YData = genderCounts;
                Hdl = findobj(gca, 'Tag', 'LineAbsCountGender');
                updatePlotData(Hdl, year, genderCounts)
                % Hdl.XData = year;
                % Hdl.YData = genderCounts;
            end

            allstateAges = [state.ages];
            maleages = allstateAges([state.genders] == "male");
            femaleages = allstateAges([state.genders] == "female");
            maleNumPerYear = arrayfun(@(state) numel(state.genders(state.genders == "male")), state);
            yearAlignMale = repelem(year, maleNumPerYear);
            femaleNumPerYear = arrayfun(@(state) numel(state.genders(state.genders == "female")), state);
            yearAlignFemale = repelem(year, femaleNumPerYear);
            
            % 小提琴图 (图8)
            axes(obj.AxAgeViolin)
            if ~obj.PlotInitializedFlags.AxAgeViolin
                violinplot(yearAlignMale, maleages, 'DensityDirection', 'positive', ...
                    'DisPlayName', 'Male', 'Tag', 'MaleViolin');
                hold on
                violinplot(yearAlignFemale, femaleages, 'DensityDirection', 'negative', ...
                    'DisPlayName', 'Female', 'Tag', 'FemaleViolin');
                hold off
                legend
                obj.PlotInitializedFlags.AxAgeViolin = true;
                notify(obj, 'PlotInitializedEvent');
            else % 后续更新只更新数据
                Hdl = findobj(gca, 'Tag', 'MaleViolin');
                % updatePlotData(Hdl, year, yearAlignMale)
                Hdl.XData = yearAlignMale;
                Hdl.YData = maleages;
                Hdl = findobj(gca, 'Tag', 'FemaleViolin');
                % updatePlotData(Hdl, year, yearAlignFemale)
                Hdl.XData = yearAlignFemale;
                Hdl.YData = femaleages;
            end
        end

        function updateGlobalTimelinePlot(obj, state)
            % updateGlobalTimelinePlot 更新全局时间线图 (图5)
            % state: 当前年份的 PopulationState 对象

            % 从 PopulationState 的依赖属性获取统计数据
            stats = [state.LifeCycleGenderStats];
            Xdata = [state.year];
            Ydata = [[stats.TotalAlive]
                    cell2mat(cellfun(@(x) x', {stats.GenderCounts}, ...
                    'UniformOutput', false))
                    % [stats.GenderCounts(1)]
                    % [stats.GenderCounts(2)]
                    cell2mat(cellfun(@(x) x', {stats.LifeCycleCounts}, ...
                    'UniformOutput', false))
                    % [stats.LifeCycleCounts(1)]
                    % [stats.LifeCycleCounts(2)]
                    % [stats.LifeCycleCounts(3)]
                    [stats.CurrentYearBirthsCount]
                    [state.currentYearDeathsCount]
                    [stats.NetGrowth]
                    ];
            Displaydata = cellstr(["Alive", stats(1).GenderLabels, ...
                            stats(1).LifeCycleLabels, ...
                            "Birth", "Death", "NetGrowth"]);
            % 绘制或更新线条
            axes(obj.AxGlobalTimeline)
            if ~obj.PlotInitializedFlags.AxGlobalTimeline
                Hdl = plot(Xdata, Ydata, ...
                    'o-', 'LineWidth', 2, ...%'MarkerFaceColor', 'auto', ...
                    'Tag', 'GlobalTimeline');
                [Hdl.DisplayName] = deal(Displaydata{:});
                obj.PlotInitializedFlags.AxGlobalTimeline = true;
                notify(obj, 'PlotInitializedEvent');
            else
                Hdl = findobj(gca, 'Tag', 'GlobalTimeline');
                updatePlotData(Hdl, Xdata, Ydata)
                % Hdl.XData = Xdata;
                % Hdl.YData = Ydata;
            end
        end

        function updateAgeDistributionPlots(obj, state)
            % updateAgeDistributionPlots 更新年龄结构相关的图 (图6, 图7, 图8)
            % state: 当前年份的 PopulationState 对象

            % % 清除旧图
            % cla(obj.AxGenderPie);
            % cla(obj.AxAgeDonut);
            % cla(obj.AxAgeHistKDE);
            % cla(obj.AxAgeViolin);

            % 饼图 (图6)
            axes(obj.AxGenderPie)
            if ~obj.PlotInitializedFlags.AxGenderPie
                obj.AxGenderPie = piechart(state.genders); % Note: Plotting on AxGenderPie based on user's layout
                notify(obj, 'PlotInitializedEvent');
            else % 后续更新只更新数据
                obj.AxGenderPie.Data = state.genders;
            end

            % 甜甜圈图 (AxAgeDonut)
            axes(obj.AxAgeDonut)
            lifeCycleData = LifeCycleState.toCategorical(state.life_statuses);
            if ~obj.PlotInitializedFlags.AxAgeDonut
                obj.AxAgeDonut = donutchart(lifeCycleData);
                obj.PlotInitializedFlags.AxAgeDonut = true;
                notify(obj, 'PlotInitializedEvent');
            else % 后续更新只更新数据
                obj.AxAgeDonut.Data = lifeCycleData;
            end

            % 直方图和 KDE (图7)
            axes(obj.AxAgeHistKDE)
            aliveAges = state.ages(state.life_statuses < LifeCycleState.Dead);
            [Ypdf, Xage] = kde(double(aliveAges));
            if ~obj.PlotInitializedFlags.AxAgeHistKDE
                yyaxis left
                histogram(aliveAges, "Tag", "HistAges");
                yyaxis right
                plot(Xage, Ypdf, 'r-', "LineWidth", 2, "Tag", "LineKde")
                obj.PlotInitializedFlags.AxAgeHistKDE = true;
                notify(obj, 'PlotInitializedEvent');
            else % 后续更新只更新数据
                yyaxis left
                Hdl = findobj(gca, 'Tag', 'HistAges');
                Hdl.Data = aliveAges;
                yyaxis right
                Hdl = findobj(gca, 'Tag', 'LineKde');
                Hdl.XData = Xage;
                Hdl.YData = Ypdf;
            end

         end

         function updateGenerationPlots(obj, state)
            % updateGenerationPlots 更新世代相关的图 (图9, 图10)
            % state: 当前年份的 PopulationState 对象

            % 从 PopulationState 的依赖属性获取世代统计结构体
            nowState = state(end);
            P = intersectionTablulate(LifeCycleState.toCategorical(nowState.life_statuses), ...
                nowState.generations, {'LifeCycleState', 'Generations'});
            PivotJoint = table(int32(zeros(0, 1)), 'VariableNames', "Generations");
            for perstate = state
                pivotToJoin = array2table(tabulate(perstate.generations), ...
                    "VariableNames", {'Generations', ['Count_', char(string(perstate.year))], 'Freq'});
                pivotToJoin = removevars(pivotToJoin, 'Freq');
                PivotJoint = outerjoin(PivotJoint, pivotToJoin, 'MergeKeys', true);
            end
            % % 清除旧图
            % cla(obj.AxGenGroupedStacked);
            % cla(obj.AxGenRelRatio);

            % 图9: 世代分组数量 (堆叠条形图)
            % 要确保句柄不随绘图改变而增加，启用pivot函数的includeemptygroup选项
            axes(obj.AxGenGroupedStacked)
            if ~obj.PlotInitializedFlags.AxGenGroupedStacked
                Hdl1 = bar(P.Generations, P{:, 2:end}, 'stacked', ...
                    'Tag', 'BarGenGroupedStacked');
                [Hdl1.DisplayName] = deal(P.Properties.VariableNames{2:end});
                obj.PlotInitializedFlags.AxGenGroupedStacked = true;
                notify(obj, 'PlotInitializedEvent');
            else % 后续更新只更新数据
                Hdl1 = findobj(gca, 'Tag', 'BarGenGroupedStacked');
                updatePlotData(Hdl1, P.Generations, P{:, 2:end})
                % Hdl.XData = P.Generations;
                % Hdl.YData = P{:, 2:end};
            end

            % 图10: 世代相对比例 (堆叠条形图)
            % 句柄数组尺寸等同于世代数量，世代向前推进，
            % 绘图句柄可变，只能完全重绘，不能仅更新绘图数据
            % 因而也需要独立处理title等参数，暂时留空
            axes(obj.AxGenRelRatio)
            C = colororder;
            colors = getTemporalColors(PivotJoint.Generations, C);
            colorsCell = num2cell(colors, 2);
             if ~obj.PlotInitializedFlags.AxGenRelRatio
                obj.PlotInitializedFlags.AxGenRelRatio = true;
                notify(obj, 'PlotInitializedEvent');
             end
                cla
                Hdl2 = bar([state.year], PivotJoint{:, 2:end}, 'stacked', ...
                    'FaceColor', 'flat', 'Tag', 'BarGenRelRatio');
                Genchar = cellstr(string(PivotJoint.Generations));
                [Hdl2.DisplayName] = deal(Genchar{:});
                % 转换为单元数组并批量赋值
                [Hdl2.CData] = deal(colorsCell{:});
                legend
         end

    end
        
    % 批处理模式相关方法
    methods
        function batchVisualize(obj, states, output_dir)
            % batchVisualize 批量可视化并保存图像
            % 输入:
            %   states - PopulationState 对象数组，包含所有年份的种群状态
            %   output_dir - 输出目录路径，用于保存图像
            
            % 验证输入
            if ~isa(states, 'PopulationState')
                error('states 必须是 PopulationState 对象数组');
            end
            
            % 确保输出目录存在
            if ~exist(output_dir, 'dir')
                mkdir(output_dir);
            end
            
            % 获取状态数量
            num_states = length(states);
            
            % 创建进度条
            progress_bar = waitbar(0, '开始批量可视化, 正在处理初值快照(第0年)...');
            obj.saveFigureAsImage(output_dir, states(1).year);

            % 遍历所有状态
            for i = 2:num_states
                % 更新进度条
                waitbar((i-1)/(num_states-1), progress_bar, sprintf('正在处理第 %d/%d 年...', i-1, num_states-1));
                
                % 更新仪表板
                obj.addStateSnapshot(states(i));
                
                % % 创建年份子目录
                % year_dir = fullfile(output_dir, sprintf('Year_%04d', states(i).year));
                % if ~exist(year_dir, 'dir')
                %     mkdir(year_dir);
                % end
                
                % 保存图像
                obj.saveFigureAsImage(output_dir, states(i).year);
            end
            
            % 关闭进度条
            close(progress_bar);
        end
        
        function saveFigureAsImage(obj, output_dir, year)
            % saveFigureAsImage 将当前图窗保存为图像
            % 输入:
            %   output_dir - 输出目录路径
            %   year - 当前年份，用于命名文件
            
            % 保存整个图窗
            filename = fullfile(output_dir, sprintf('dashboard_year_%04d.png', year));
            exportgraphics(obj.Figure, filename);
            % saveas(obj.Figure, filename);
            
            % 保存各个子图
            plotStruct = entries(obj.PlotDict, "struct");
            for i = 1:length(plotStruct)
                keyname = plotStruct(i).Key;
                ax = plotStruct(i).Value;
                filename = fullfile(output_dir, sprintf('%s_year_%04d.png', string(keyname), year));
                exportgraphics(ax, filename); % vector only, 'BackgroundColor', 'none'); % Online only, 'Padding', 'figure');
                % saveas(ax, filename);
            end
        end
    end

end

function FieldArray = extractStructPropFields(InstArray, PropName, FieldName)
    % 从同构类实例数组中取出同构属性数组
    % 属性需要是标量结构体
    % 随后从结构体数组中取出字段数组，每列横向拼接为结果，与year行向量对应
    PropList = [InstArray.(PropName)];
    FieldArray = arrayfun(@(x) x.(FieldName)', PropList, "UniformOutput", false);
    FieldArray = cell2mat(FieldArray);
end

function pivottable = intersectionTablulate(CategoryVar, CountVar, Varnames)
    T = table(CategoryVar', CountVar', 'VariableNames', Varnames);
    pivottable = pivot(T, Columns = Varnames(1), Rows = Varnames(2), IncludeEmptyGroups=true);
end

function colors = getTemporalColors(temporal, colorOrder)
    % 计算颜色索引（基于绝对数值循环使用颜色）
    numColors = size(colorOrder, 1);
    colorIndices = mod(temporal, numColors) + 1;  % MATLAB 索引从1开始
    
    % 获取颜色
    colors = colorOrder(colorIndices, :);
end

% 自定义验证函数（保存为 mustBeClassAorB.m）
function mustBeAxesPieDonut(value)
    validClasses = {'matlab.graphics.axis.Axes', ...
    'matlab.graphics.chart.PieChart', ...
    'matlab.graphics.chart.DonutChart'};
    if ~any(cellfun(@(cls) isa(value, cls), validClasses))
        error('属性必须是 ClassA 或 ClassB 的实例。');
    end
end

function updatePlotData(hdls, xdata, ydata)
    % updatePlotData 隐式维度对齐的数据更新工具
    % 输入：
    %   hdls   - 绘图句柄数组（一维）
    %   xdata  - 一维向量（行或列），所有句柄共享
    %   ydata  - 二维矩阵，尺寸需满足：
    %            若 xdata 为行向量 (1×N)，则 ydata 为 M×N（M=句柄数）
    %            若 xdata 为列向量 (N×1)，则 ydata 为 N×M（M=句柄数）
    
    % 核心逻辑：根据 xdata 维度确定切片方向
    if isrow(xdata)
        % xdata 行向量 → 按行切片 ydata
        y_slices = num2cell(ydata, 2);  % 每行转为元胞元素
    else
        % xdata 列向量 → 按列切片 ydata
        y_slices = num2cell(ydata, 1);  % 每列转为元胞元素
    end
    
    % 批量分发数据（deal 高效操作）
    [hdls.XData] = deal(xdata);      % 所有句柄共享同一 XData
    [hdls.YData] = deal(y_slices{:}); % 分发 YData 切片
    end