classdef PopulationDashboard < handle
    % PopulationDashboard 种群数据可视化展板类
    % 创建并管理一个包含多个子图的图窗，用于展示种群模拟数据
    % 接收 PopulationState 对象数组作为历史数据，并根据数据更新图表
    % MODIFIED: Includes a UIFIGURE wrapper with a control panel and slider.
    % MODIFIED: Slider range is now decoupled via SimulationYearRange.

    properties
        Figure matlab.ui.Figure % 图窗句柄 (Now the main UIFIGURE)
        Layout matlab.graphics.layout.TiledChartLayout % 平铺图块布局句柄

        % 存储模拟历史数据
        % 注意：随着模拟年份增加，此属性内存使用会快速上升。
        % 对于非常长的模拟，可能需要考虑定期保存到文件或只存储部分历史。
        SimulationHistory PopulationState = PopulationState.empty(1, 0) % PopulationState 对象数组，存储每年的种群状态快照

        maxYear (1, 1) double = 20 % 模拟的最大年份，用于配置滑块和批量模拟

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

        % UI 组件
        MainGrid matlab.ui.container.GridLayout        % 主网格布局 (控件区 | 绘图区)
        ControlPanel matlab.ui.container.Panel         % 控件面板
        ControlGrid matlab.ui.container.GridLayout    % 控件面板内的网格布局 (标签和滑块)
        TitleLabel matlab.ui.control.Label            % 滑块标题标签
        YearSlider matlab.ui.control.Slider           % 年份选择滑块
        PlotPanel matlab.ui.container.Panel           % 绘图面板 (用于容纳 TiledChartLayout)
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
        % 依赖属性 PlotDict，用于存储 axes 句柄的字典
        PlotDict dictionary
    end

    % 定义事件，表示某个子图已首次绘制
    events
        PlotInitializedEvent
    end

    methods
        function obj = PopulationDashboard(initialHistory, maxYear)
            % POPULATIONDASHBOARD 构造一个 PopulationDashboard 对象。
            %   OBJ = POPULATIONDASHBOARD() 创建一个具有默认设置的 PopulationDashboard。
            %   OBJ = POPULATIONDASHBOARD(INITIALHISTORY) 使用提供的初始历史数据 INITIALHISTORY (PopulationState 对象数组) 初始化展板。
            %   OBJ = POPULATIONDASHBOARD(INITIALHISTORY, MAXYEAR) 使用提供的初始历史数据和最大模拟年份 MAXYEAR 初始化展板。
            %
            %   输入:
            %       initialHistory (可选) - PopulationState 对象数组，包含初始种群状态。
            %       maxYear (可选)      - double 标量，定义模拟的最大年份，用于配置滑块等。
            %
            %   输出:
            %       obj - PopulationDashboard 对象实例。
            %
            %   详细说明:
            %       此构造函数负责创建 UIFIGURE、主布局、控件面板（包含年份滑块）和绘图面板。
            %       它会初始化所有的子图 Axes，并设置必要的监听器和回调函数。
            %       如果提供了 initialHistory，它将被存储，并且滑块和图表将根据此数据进行初始更新。

            % --- 主 UI 图窗 ---
            monitorpos = get(0, "MonitorPositions");
            obj.Figure = uifigure('Name', '种群模拟展板 - UI', ...
                'NumberTitle', 'off', ...
                'Position', monitorpos(2, :), ...
                'Scrollable', 'on');

            % --- 主网格布局 ---
            obj.MainGrid = uigridlayout(obj.Figure, [2 1]);
            obj.MainGrid.RowHeight = {100, '1x'}; 
            obj.MainGrid.ColumnWidth = {'1x'};
            obj.MainGrid.Padding = [5 5 5 5];

            % --- 控件面板 ---
            obj.ControlPanel = uipanel(obj.MainGrid, 'Title', '控件区');
            obj.ControlPanel.Layout.Row = 1;
            obj.ControlPanel.Layout.Column = 1;
            
            obj.ControlGrid = uigridlayout(obj.ControlPanel, [1 2]);
            obj.ControlGrid.ColumnWidth = {'fit', '1x'}; 
            obj.ControlGrid.RowHeight = {'fit'};
            obj.ControlGrid.Padding = [10 10 10 10];
            
            % --- Title Label for Slider ---
            obj.TitleLabel = uilabel(obj.ControlGrid, 'Text', '选择年份:');
            obj.TitleLabel.Layout.Row = 1;
            obj.TitleLabel.Layout.Column = 1;
            obj.TitleLabel.HorizontalAlignment = 'right';
            obj.TitleLabel.VerticalAlignment = 'center';

            % --- Year Slider ---
            obj.YearSlider = uislider(obj.ControlGrid);
            obj.YearSlider.Layout.Row = 1;
            obj.YearSlider.Layout.Column = 2;
            obj.YearSlider.ValueChangedFcn = @obj.sliderCallback;

            % --- 绘图面板 ---
            obj.PlotPanel = uipanel(obj.MainGrid, "Title", '种群模拟数据可视化展板'); % Panel for plots
            obj.PlotPanel.Layout.Row = 2;
            obj.PlotPanel.Layout.Column = 1;
            obj.PlotPanel.BorderType = 'none'; 
            obj.PlotPanel.Scrollable = 'on';

            % 创建平铺图块布局
            obj.Layout = tiledlayout(obj.PlotPanel, obj.LayoutRows, obj.LayoutCols);
            % 调整布局的间距和边距 (可选，根据需要调整)
            obj.Layout.TileSpacing = 'none'; % 'loose', 'compact' 或 'tight', 'none'
            obj.Layout.Padding = 'tight';     % 'loose', 'compact' 或 'tight'
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

            % 初始化模拟年份范围
            % 初始化模拟历史数据
            switch nargin
                case 1
                    try
                        obj.SimulationHistory = initialHistory;
                    catch exception
                        error('初始化 PopulationDashboard 时出错: %s', exception.message);
                    end
                case 2
                    try
                        obj.maxYear = maxYear;
                    catch exception
                        error('初始化 PopulationDashboard 时出错: %s', exception.message);
                    end
                case nargin > 2
                    error('PopulationDashboard 构造函数最多接受两个参数。');
                otherwise
                    disp('使用默认值')
            end

            % 根据 maxYear 和 SimulationHistory 配置滑块
            obj.updateSliderConfiguration();

            % 初始更新所有图表
            % 调用 updateDashboard，它将使用 SimulationHistory 中的最新状态进行绘制
            % updateDashboard 会负责首次绘图和触发初始化事件
            obj.updateDashboard();
        end
        % --- PlotInitializedFlags 结构体初始化方法 ---
        function initializePlotFlags(obj)
            % INITIALIZEPLOTFLAGS 初始化 PlotInitializedFlags 结构体。
            %   INITIALIZEPLOTFLAGS(OBJ) 动态地为每个以 'Ax' 开头的 Axes 属性在 OBJ.PlotInitializedFlags 中创建一个字段，
            %   并将其初始值设置为 false。这些标志用于跟踪每个子图是否已进行首次绘制。
            %
            %   详细说明:
            %       此方法使用元类编程 (meta.class.fromName) 来检查类的属性，
            %       并识别所有代表子图 Axes 的属性 (基于名称以 'Ax' 开头且类型为 Axes)。

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
            % HANDLEPLOTINITIALIZATION PlotInitializedEvent 事件的监听器回调函数。
            %   HANDLEPLOTINITIALIZATION(OBJ, ~, ~) 在 PlotInitializedEvent 被触发时调用。
            %   它检查 OBJ.PlotInitializedFlags 中的所有标志是否都为 true。如果是，则表示所有子图都已完成首次绘制，
            %   此时会调用 initializePlotParameters 来设置静态绘图参数 (如标题、轴标签)，
            %   然后删除此监听器，因为它只需要执行一次。
            %
            %   输入:
            %       obj - PopulationDashboard 对象实例。

            % 检查所有标志是否都为 true
            allInitialized = all(structfun(@(x) x, obj.PlotInitializedFlags));

            if allInitialized
                % 所有子图都已首次绘制，初始化静态参数 table
                obj.initializePlotParameters(); % 这会触发 PlotParameters 的 setter，进而调用 applyPlotParameters
                % 可选：移除监听器，因为初始化只需要发生一次
                delete(obj.PlotInitializedListener); % 清空句柄
            end
        end

        % --- 静态绘图参数初始化方法 ---
        function initializePlotParameters(obj)
            % INITIALIZEPLOTPARAMETERS 初始化静态绘图参数表。
            %   INITIALIZEPLOTPARAMETERS(OBJ) 创建并填充 OBJ.PlotParameters 表格。
            %   此表格存储每个子图的静态参数，如默认标题、X轴标签和Y轴标签。
            %   行名对应于 PlotInitializedFlags 中的字段名 (即 Axes 属性名)。
            %   此方法在所有子图都完成首次绘制后被调用。
            %
            %   详细说明:
            %       设置此 PlotParameters 属性会触发其 setter 方法，进而调用 applyPlotParameters 将这些参数应用到实际的 Axes 对象上。

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
            % SET.PLOTPARAMETERS PlotParameters 属性的 setter 方法。
            %   SET.PLOTPARAMETERS(OBJ, VALUE) 将 OBJ.PlotParameters 设置为 VALUE (一个 table)，
            %   然后调用 applyPlotParameters 方法将这些新的参数应用到所有相关的 Axes 对象。
            %
            %   输入:
            %       obj   - PopulationDashboard 对象实例。
            %       value - table 类型，包含新的绘图参数。

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
            % APPLYPLOTPARAMETERS 将 PlotParameters 表中的静态参数应用到对应的 Axes 对象。
            %   APPLYPLOTPARAMETERS(OBJ) 遍历 OBJ.PlotParameters 表中的每一行，
            %   并将指定的标题、X轴标签和Y轴标签应用到由行名标识的 Axes 对象。
            %   此方法在 PlotParameters 的 setter 方法中被调用，确保参数更改后立即更新图表。
            %
            %   详细说明:
            %       它会检查 Axes 句柄是否有效，以避免在 Axes 尚未创建或已删除时出错。

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
        
        function updateSliderConfiguration(obj)
            % UPDATESLIDERCONFIGURATION 配置年份滑块的范围、刻度和当前值。
            %   UPDATESLIDERCONFIGURATION(OBJ) 根据 OBJ.maxYear 和 OBJ.SimulationHistory 中的数据更新滑块配置。
            %
            %   详细说明:
            %       此方法确保滑块的 Limits 与定义的最小和最大年份 (0 到 OBJ.maxYear) 一致。
            %       MajorTicks 会被设置为在年份范围内均匀分布的刻度。
            %       滑块的 Value 会尝试设置为 SimulationHistory 中的最新年份；如果历史为空或最新年份超出范围，
            %       则设置为定义的最小年份。如果年份范围无效，滑块将被禁用。
            
            if ~isvalid(obj.YearSlider) || ~isprop(obj, 'YearSlider') || isempty(obj.YearSlider)
                return; % 滑块尚未完全初始化
            end

            minDefinedYear = 0;
            maxDefinedYear = obj.maxYear;

            if isnan(minDefinedYear) || isnan(maxDefinedYear) || minDefinedYear > maxDefinedYear
                % 无效的 SimulationYearRange，禁用滑块或设置为默认非功能状态
                obj.YearSlider.Limits = [0 1];
                obj.YearSlider.Value = 0;
                obj.YearSlider.MajorTicks = [0 1];
                obj.YearSlider.Enable = 'off'; % 禁用滑块
                warning('SimulationYearRange 无效，滑块已禁用。');
                return;
            end

            obj.YearSlider.Enable = 'on'; % 确保滑块启用
            obj.YearSlider.Limits = [minDefinedYear maxDefinedYear];

            numTicks = min(10, (maxDefinedYear - minDefinedYear) + 1); 
            obj.YearSlider.MajorTicks = unique(round(linspace(minDefinedYear, maxDefinedYear, numTicks)));
                    
            % 设置滑块的当前值
            latestYearInHistory = obj.getLatestSimulatedYear(); % 从 SimulationHistory 获取最新年份
            
            if ~isnan(latestYearInHistory) && latestYearInHistory >= minDefinedYear && latestYearInHistory <= maxDefinedYear
                % 如果历史记录中的最新年份在允许的范围内，则设为滑块值
                obj.YearSlider.Value = latestYearInHistory;
            else
                % 否则，将滑块值设为允许范围的最小值
                obj.YearSlider.Value = minDefinedYear;
            end
        end

        function latestYear = getLatestSimulatedYear(obj)
            % GETLATESTSIMULATEDYEAR 获取 SimulationHistory 中存储的最新模拟年份。
            %   LATESTYEAR = GETLATESTSIMULATEDYEAR(OBJ) 返回 SimulationHistory 数组中最后一个 PopulationState 对象的年份。
            %   如果 SimulationHistory 为空，则返回 NaN。
            %
            %   输出:
            %       latestYear - double 标量，最新模拟年份；如果历史为空，则为 NaN。

            if isempty(obj.SimulationHistory)
                latestYear = NaN;
            else
                latestYear = double(obj.SimulationHistory(end).year); % 假设 PopulationState 有 year 属性
            end
        end

        function sliderCallback(obj, ~, event)
            % SLIDERCALLBACK 年份滑块值更改时的回调函数。
            %   SLIDERCALLBACK(OBJ, ~, EVENT) 在滑块值更改时触发。
            %   它获取滑块的当前值 (四舍五入到最近的整数年份)，并调用 displayYear 方法来更新图表以显示所选年份的数据。
            %
            %   输入:
            %       obj   - PopulationDashboard 对象实例。
            %       event - matlab.ui.control.ValueChangedData 对象，包含滑块事件数据，特别是 event.Value。
            selectedYear = round(event.Value); % 获取滑块选择的年份
            
            % displayYear 方法将检查选定年份的数据是否存在于 SimulationHistory 中
            obj.displayYear(selectedYear);
        end

        function displayYear(obj, targetYear)
            % DISPLAYYEAR 根据指定的年份更新图表显示。
            %   DISPLAYYEAR(OBJ, TARGETYEAR) 查找 OBJ.SimulationHistory 中与 TARGETYEAR 对应的状态快照，
            %   并使用截至该年份 (包含该年份) 的历史数据调用 updateDashboard 来更新图表。
            %   此方法主要用于响应滑块更改或以编程方式查看特定历史年份的数据。
            %
            %   输入:
            %       obj        - PopulationDashboard 对象实例。
            %       targetYear - double 标量，要显示的年份。
            %
            %   详细说明:
            %       如果找不到指定年份的数据，会发出警告。如果滑块的当前值与 targetYear 不同，
            %       并且 targetYear 在滑块的有效范围内，则会更新滑块的值。

            % 确保历史数据不为空
            if isempty(obj.SimulationHistory)
                warning('模拟历史数据为空，无法显示指定年份数据');
                return;
            end

            stateIndex = find(obj.getYearsInHistory() == targetYear, 1);
            if ~isempty(stateIndex)
                historyUpToTargetYear = obj.SimulationHistory(1:stateIndex);
                obj.updateDashboard(historyUpToTargetYear); 
                drawnow;
            else
                warning('历史记录中未找到年份 %d 的数据。图表可能不会更新或显示为空白。', targetYear);
                % 如果年份在范围内但无数据，可以考虑清除“当前年份”图表
                % obj.updateDashboardWithEmptyStateForYear(targetYear); % 示例：一个处理空状态的方法
            end
        end

        function years = getYearsInHistory(obj)
            % GETYEARSINHISTORY 获取 SimulationHistory 中所有可用年份的数组。
            %   YEARS = GETYEARSINHISTORY(OBJ) 返回一个包含 SimulationHistory 中所有 PopulationState 对象年份的数组。
            %   如果 SimulationHistory 为空，则返回一个空数组。
            %
            %   输出:
            %       years - double 数组，包含历史记录中的所有年份；如果历史为空，则为空数组。

            if isempty(obj.SimulationHistory)
                years = [];
            else
                years = [obj.SimulationHistory.year]; % 假设 PopulationState 有 year 属性
            end
        end

        % --- Getter 方法用于计算依赖属性 ---
        function dict = get.PlotDict(obj)
            % GET.PLOTDICT 获取一个包含所有 Axes 句柄的字典。
            %   DICT = GET.PLOTDICT(OBJ) 返回一个字典，其中键是 Axes 属性的名称 (例如 'AxRelRatioLifeCycle')，
            %   值是对应的 Axes 句柄。
            %
            %   输出:
            %       dict - dictionary 对象，映射 Axes 名称到其句柄。
            dict = dictionary();
            axesNames = fieldnames(obj.PlotInitializedFlags)';
            for axeName = axesNames
                dict(axeName) = obj.(string(axeName));
            end
        end

        function addStateSnapshot(obj, state)
            % ADDSTATESNAPSHOT 添加一个新的种群状态快照到历史记录并更新图表。
            %   ADDSTATESNAPSHOT(OBJ, STATE) 将单个 PopulationState 对象 STATE 添加到 OBJ.SimulationHistory 数组的末尾。
            %   然后，它会调用 updateSliderConfiguration 来调整滑块以反映新的最大年份 (如果适用)，
            %   并调用 updateDashboard 来使用最新的历史数据重新绘制所有图表。
            %
            %   输入:
            %       obj   - PopulationDashboard 对象实例。
            %       state - PopulationState 对象，表示当前年份的种群状态。

            % 验证输入是否为 PopulationState 对象
            if ~isa(state, 'PopulationState') || ~isscalar(state)
                error('输入必须是一个 PopulationState 对象');
            end

            % 将新的状态对象添加到历史记录数组
            obj.SimulationHistory = [obj.SimulationHistory, state];
            % Update slider limits and set value to new latest year
            obj.updateSliderConfiguration();

            % 调用 updateDashboard 方法更新所有图表
            % updateDashboard 将使用刚刚添加到 SimulationHistory 中的最新状态
            obj.updateDashboard();
        end

        function updateDashboard(obj, stateToDisplay)
            % UPDATEDASHBOARD 根据提供的状态数据更新所有图表。
            %   UPDATEDASHBOARD(OBJ) 使用 OBJ.SimulationHistory 中的最新状态数据更新所有图表。
            %   UPDATEDASHBOARD(OBJ, STATETODISPLAY) 使用提供的 STATETODISPLAY (PopulationState 对象数组) 更新所有图表。
            %   通常，STATETODISPLAY 是截至某个特定年份的累积历史数据。
            %
            %   输入:
            %       obj            - PopulationDashboard 对象实例。
            %       stateToDisplay (可选) - PopulationState 对象数组。如果未提供，则使用 obj.SimulationHistory。
            %                          如果提供，则会更新 obj.SimulationHistory 为此值 (如果其长度更短或相等)，
            %                          并可能根据 HistoryWindowSize 截断以用于绘图。
            %
            %   详细说明:
            %       此方法是主要的绘图更新入口点。它会确定要显示的数据子集 (考虑 HistoryWindowSize)，
            %       然后调用各个子图的特定更新方法 (如 updateLifeCycleGenderPlots, updateGlobalTimelinePlot 等)。
            %       如果历史数据为空，会发出警告并可能清空图表。

            % 确定要用于更新图表的状态
            if nargin < 2 && isempty(obj.SimulationHistory)
            % 如果未提供状态，使用历史记录中的最新状态
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

            drawnow;
        end

        % --- 添加用于更新各个子图的具体方法 ---
        % 这些方法现在接收 PopulationState 对象作为输入，并在首次绘制时触发事件

        function updateLifeCycleGenderPlots(obj, state)
            % UPDATELIFECYCLEGENDERPLOTS 更新与生命周期和性别相关的图表。
            %   UPDATELIFECYCLEGENDERPLOTS(OBJ, STATE) 使用 STATE (PopulationState 对象数组，通常是历史窗口内的数据)
            %   来更新以下图表:
            %       - AxRelRatioLifeCycle (图1): 生命周期相对比例堆叠条形图。
            %       - AxRelRatioGender    (图2): 性别相对比例堆叠条形图。
            %       - AxAbsCountLifeCycle (图3): 生命周期绝对数量分组条形图和折线图。
            %       - AxAbsCountGender    (图4): 性别绝对数量分组条形图和折线图。
            %       - AxAgeViolin         (图8): 按性别区分的年龄分布小提琴图。
            %
            %   输入:
            %       obj   - PopulationDashboard 对象实例。
            %       state - PopulationState 对象数组，用于绘图的数据。
            %
            %   详细说明:
            %       此方法从输入的 state 数组中提取必要的统计数据 (如生命周期计数/比例、性别计数/比例、年龄数据)。
            %       对于每个图表，它会检查 PlotInitializedFlags。如果是首次绘制，则创建完整的图表元素 (条形图、线条等)
            %       并设置标志为 true，然后触发 PlotInitializedEvent。
            %       如果是后续更新，则仅更新现有绘图对象 (通过其 'Tag' 属性找到) 的 XData 和 YData。

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
            ax = obj.AxRelRatioLifeCycle;
            if ~obj.PlotInitializedFlags.AxRelRatioLifeCycle
                Hdl = bar(ax, year, lifeCycleRatios, 'stacked', ...
                    'Tag', 'BarRelRatioLifeCycle');
                [Hdl.DisplayName] = deal(lifeCycleLabels{:});
                % legend
                obj.PlotInitializedFlags.AxRelRatioLifeCycle = true;
                notify(obj, 'PlotInitializedEvent');
            else % 后续更新只更新数据
                Hdl = findobj(ax, 'Tag', 'BarRelRatioLifeCycle');
                updatePlotData(Hdl, year, lifeCycleRatios)
                % Hdl.XData = year;
                % Hdl.YData = lifeCycleRatios;
            end

            % 绘制性别相对比例 (图2)
            ax = obj.AxRelRatioGender;
            if ~obj.PlotInitializedFlags.AxRelRatioGender
                Hdl = bar(ax, year, genderRatios, 'stacked', ...
                    'Tag', 'BarRelRatioGender');
                [Hdl.DisplayName] = deal(genderLabels{:});
                % legend
                obj.PlotInitializedFlags.AxRelRatioGender = true;
                notify(obj, 'PlotInitializedEvent');
            else % 后续更新只更新数据
                Hdl = findobj(ax, 'Tag', 'BarRelRatioGender');
                updatePlotData(Hdl, year, genderRatios)
                % Hdl.XData = year;
                % Hdl.YData = genderRatios;
            end
             
            % 绘制生命周期绝对数量 (图3)
            ax = obj.AxAbsCountLifeCycle;
            if ~obj.PlotInitializedFlags.AxAbsCountLifeCycle
                Hdl = bar(ax, year, lifeCycleCounts, ...
                    'Tag', 'BarAbsCountLifeCycle');
                [Hdl.DisplayName] = deal(lifeCycleLabels{:});
                % legend
                hold(ax, "on")
                plot(ax, year, lifeCycleCounts, ... % 'DisplayName', lifeCycleLabels, ...
                    'o-', 'LineWidth', 2, 'MarkerFaceColor', 'auto', ...
                    'Tag', 'LineAbsCountLifeCycle');
                hold(ax, "off")
                obj.PlotInitializedFlags.AxAbsCountLifeCycle = true;
                notify(obj, 'PlotInitializedEvent');
            else % 后续更新只更新数据
                Hdl = findobj(ax, 'Tag', 'BarAbsCountLifeCycle');
                updatePlotData(Hdl, year, lifeCycleCounts)
                % Hdl.XData = year;
                % Hdl.YData = lifeCycleCounts;
                Hdl = findobj(ax, 'Tag', 'LineAbsCountLifeCycle');
                updatePlotData(Hdl, year, lifeCycleCounts)
                % Hdl.XData = year;
                % Hdl.YData = lifeCycleCounts;
            end
            
            % 绘制性别绝对数量 (图4)
            ax = obj.AxAbsCountGender;
            if ~obj.PlotInitializedFlags.AxAbsCountGender
                Hdl = bar(ax, year, genderCounts, ...
                    'Tag', 'BarAbsCountGender');
                [Hdl.DisplayName] = deal(genderLabels{:});
                % legend
                hold(ax, "on")
                plot(ax, year, genderCounts, ... % 'DisplayName', genderLabels, ...
                    'o-', 'LineWidth', 2, 'MarkerFaceColor', 'auto', ...
                    'Tag', 'LineAbsCountGender');
                hold(ax, "off")
                obj.PlotInitializedFlags.AxAbsCountGender = true;
                notify(obj, 'PlotInitializedEvent');
            else % 后续更新只更新数据
                Hdl = findobj(ax, 'Tag', 'BarAbsCountGender');
                updatePlotData(Hdl, year, genderCounts)
                % Hdl.XData = year;
                % Hdl.YData = genderCounts;
                Hdl = findobj(ax, 'Tag', 'LineAbsCountGender');
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
            ax = obj.AxAgeViolin;
            if ~obj.PlotInitializedFlags.AxAgeViolin
                violinplot(ax, yearAlignMale, maleages, 'DensityDirection', 'positive', ...
                    'DisPlayName', 'Male', 'Tag', 'MaleViolin');
                hold(ax, "on")
                violinplot(ax, yearAlignFemale, femaleages, 'DensityDirection', 'negative', ...
                    'DisPlayName', 'Female', 'Tag', 'FemaleViolin');
                hold(ax, "off")
                legend(ax, "show")
                obj.PlotInitializedFlags.AxAgeViolin = true;
                notify(obj, 'PlotInitializedEvent');
            else % 后续更新只更新数据
                Hdl = findobj(ax, 'Tag', 'MaleViolin');
                % updatePlotData(Hdl, year, yearAlignMale)
                Hdl.XData = yearAlignMale;
                Hdl.YData = maleages;
                Hdl = findobj(ax, 'Tag', 'FemaleViolin');
                % updatePlotData(Hdl, year, yearAlignFemale)
                Hdl.XData = yearAlignFemale;
                Hdl.YData = femaleages;
            end
        end

        function updateGlobalTimelinePlot(obj, state)
            % UPDATEGLOBALTIMELINEPLOT 更新全局时间线图 (AxGlobalTimeline, 图5)。
            %   UPDATEGLOBALTIMELINEPLOT(OBJ, STATE) 使用 STATE (PopulationState 对象数组，通常是完整的 SimulationHistory)
            %   来绘制或更新显示种群总数、各性别数量、各生命周期阶段数量、出生数、死亡数和净增长随时间变化的折线图。
            %
            %   输入:
            %       obj   - PopulationDashboard 对象实例。
            %       state - PopulationState 对象数组，用于绘图的数据。
            %
            %   详细说明:
            %       此方法从输入的 state 数组中提取历年的统计数据。
            %       如果是首次绘制 (根据 PlotInitializedFlags.AxGlobalTimeline 判断)，则创建所有折线图元素，
            %       设置其 DisplayName 和 Tag，设置标志为 true，并触发 PlotInitializedEvent。
            %       如果是后续更新，则仅更新现有折线图对象 (通过 'Tag' 属性找到) 的 XData 和 YData。

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
            ax = obj.AxGlobalTimeline;
            if ~obj.PlotInitializedFlags.AxGlobalTimeline
                Hdl = plot(ax, Xdata, Ydata, ...
                    'o-', 'LineWidth', 2, ...%'MarkerFaceColor', 'auto', ...
                    'Tag', 'GlobalTimeline');
                [Hdl.DisplayName] = deal(Displaydata{:});
                obj.PlotInitializedFlags.AxGlobalTimeline = true;
                notify(obj, 'PlotInitializedEvent');
            else
                Hdl = findobj(ax, 'Tag', 'GlobalTimeline');
                updatePlotData(Hdl, Xdata, Ydata)
                % Hdl.XData = Xdata;
                % Hdl.YData = Ydata;
            end
        end

        function updateAgeDistributionPlots(obj, state)
            % UPDATEAGEDISTRIBUTIONPLOTS 更新与当前年份年龄结构相关的图表。
            %   UPDATEAGEDISTRIBUTIONPLOTS(OBJ, STATE) 使用 STATE (单个 PopulationState 对象，代表当前显示年份的数据)
            %   来更新以下图表:
            %       - AxGenderPie    (图6): 当前年份性别结构饼图。
            %       - AxAgeDonut     (图): 当前年份生命周期状态甜甜圈图。
            %       - AxAgeHistKDE   (图7): 当前年份存活个体年龄分布直方图和核密度估计(KDE)曲线。
            %
            %   输入:
            %       obj   - PopulationDashboard 对象实例。
            %       state - 单个 PopulationState 对象，代表当前要显示的年份的数据。
            %
            %   详细说明:
            %       - 对于饼图和甜甜圈图，它们通常在每次更新时完全重绘，因为其性质是显示单一时间点的数据。
            %         nexttile 用于确保它们在正确的布局位置重绘。
            %       - 对于直方图和KDE图 (AxAgeHistKDE)，如果是首次绘制，则创建直方图和KDE线，并设置标志。
            %         如果是后续更新，则更新直方图的 Data 和KDE线的 XData/YData。
            %       首次绘制时会触发 PlotInitializedEvent。

            % % 清除旧图
            % cla(obj.AxGenderPie);
            % cla(obj.AxAgeDonut);
            % cla(obj.AxAgeHistKDE);
            % cla(obj.AxAgeViolin);

            % 饼图 (图6)
            nexttile(obj.Layout, 5)
            if ~obj.PlotInitializedFlags.AxGenderPie
                obj.PlotInitializedFlags.AxGenderPie = true;
                notify(obj, 'PlotInitializedEvent');
            else % 后续更新只更新数据
                obj.AxGenderPie = piechart(obj.Layout, state.genders); 
            end

            % 甜甜圈图 (AxAgeDonut)
            nexttile(obj.Layout, 9)
            aliveStates = state.life_statuses(state.life_statuses < LifeCycleState.Dead);
            lifeCycleData = aliveStates.toCategoricalFromInstance();
            if ~obj.PlotInitializedFlags.AxAgeDonut
                obj.PlotInitializedFlags.AxAgeDonut = true;
                notify(obj, 'PlotInitializedEvent');
            else % 后续更新只更新数据
                obj.AxAgeDonut = donutchart(obj.Layout, lifeCycleData);
            end

            % 直方图和 KDE (图7)
            ax = obj.AxAgeHistKDE;
            aliveAges = state.ages(state.life_statuses < LifeCycleState.Dead);
            [Ypdf, Xage] = kde(double(aliveAges));
            if ~obj.PlotInitializedFlags.AxAgeHistKDE
                yyaxis(ax, "left")
                histogram(ax, aliveAges, "Tag", "HistAges");
                yyaxis(ax, "right")
                plot(ax, Xage, Ypdf, 'r-', "LineWidth", 2, "Tag", "LineKde")
                obj.PlotInitializedFlags.AxAgeHistKDE = true;
                notify(obj, 'PlotInitializedEvent');
            else % 后续更新只更新数据
                yyaxis(ax, "left")
                Hdl = findobj(ax, 'Tag', 'HistAges');
                Hdl.Data = aliveAges;
                yyaxis(ax, "right")
                Hdl = findobj(ax, 'Tag', 'LineKde');
                Hdl.XData = Xage;
                Hdl.YData = Ypdf;
            end

         end

         function updateGenerationPlots(obj, state)
            % UPDATEGENERATIONPLOTS 更新与世代结构相关的图表。
            %   UPDATEGENERATIONPLOTS(OBJ, STATE) 使用 STATE (PopulationState 对象数组，通常是历史窗口内的数据)
            %   来更新以下图表:
            %       - AxGenGroupedStacked (图9): 当前年份各世代内不同生命周期状态个体数量的堆叠条形图。
            %       - AxGenRelRatio       (图10): 历年各世代相对比例的堆叠条形图。
            %
            %   输入:
            %       obj   - PopulationDashboard 对象实例。
            %       state - PopulationState 对象数组，用于绘图的数据。
            %   详细说明:
            %       - AxGenGroupedStacked: 使用当前年份 (state(end)) 的数据，通过 intersectionTablulate 和 pivot 创建数据透视表，
            %         然后绘制堆叠条形图。首次绘制时创建图表元素并设置标志；后续更新则更新数据。
            %       - AxGenRelRatio: 遍历 state 数组中的每一年，使用 tabulate 统计各世代数量，然后合并为 PivotJoint 表。
            %         使用 getTemporalColors 为不同世代分配颜色。此图表通常在每次更新时完全重绘，因为世代组成和数量会随时间变化。
            %       首次绘制时会触发 PlotInitializedEvent。

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
            ax = obj.AxGenGroupedStacked;
            if ~obj.PlotInitializedFlags.AxGenGroupedStacked
                Hdl1 = bar(ax, P.Generations, P{:, 2:end}, 'stacked', ...
                    'Tag', 'BarGenGroupedStacked');
                [Hdl1.DisplayName] = deal(P.Properties.VariableNames{2:end});
                obj.PlotInitializedFlags.AxGenGroupedStacked = true;
                notify(obj, 'PlotInitializedEvent');
            else % 后续更新只更新数据
                Hdl1 = findobj(ax, 'Tag', 'BarGenGroupedStacked');
                updatePlotData(Hdl1, P.Generations, P{:, 2:end})
                % Hdl.XData = P.Generations;
                % Hdl.YData = P{:, 2:end};
            end

            % 图10: 世代相对比例 (堆叠条形图)
            % 句柄数组尺寸等同于世代数量，世代向前推进，
            % 绘图句柄可变，只能完全重绘，不能仅更新绘图数据
            % 因而也需要独立处理title等参数，暂时留空
            ax = obj.AxGenRelRatio;
            C = colororder;
            colors = getTemporalColors(PivotJoint.Generations, C);
            colorsCell = num2cell(colors, 2);
             if ~obj.PlotInitializedFlags.AxGenRelRatio
                obj.PlotInitializedFlags.AxGenRelRatio = true;
                notify(obj, 'PlotInitializedEvent');
             end
                Hdl2 = bar(ax, [state.year], PivotJoint{:, 2:end}, 'stacked', ...
                    'FaceColor', 'flat', 'Tag', 'BarGenRelRatio');
                Genchar = cellstr(string(PivotJoint.Generations));
                [Hdl2.DisplayName] = deal(Genchar{:});
                % 转换为单元数组并批量赋值
                [Hdl2.CData] = deal(colorsCell{:});
                legend(ax, "show")
         end

    end
        
    % 批处理模式相关方法
    methods
        function batchVisualize(obj, states, output_dir)
            % BATCHVISUALIZE 批量处理一系列种群状态，逐年更新仪表板并保存图像。
            %   BATCHVISUALIZE(OBJ, STATES, OUTPUT_DIR) 遍历 STATES (PopulationState 对象数组) 中的每个状态。
            %   对于每个状态 (代表一年)，它会调用 addStateSnapshot 来更新仪表板显示，
            %   然后调用 saveFigureAsImage 将当前仪表板的完整图窗和各个子图保存到 OUTPUT_DIR 指定的目录中。
            %   过程中会显示一个进度条。
            %
            %   输入:
            %       obj        - PopulationDashboard 对象实例。
            %       states     - PopulationState 对象数组，包含所有年份的种群状态。
            %       output_dir - 字符串，指定保存图像的输出目录路径。如果目录不存在，则会创建它。
            
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
            % SAVEFIGUREASIMAGE 将当前仪表板的完整图窗及各个子图分别保存为图像文件。
            %   SAVEFIGUREASIMAGE(OBJ, OUTPUT_DIR, YEAR) 将 OBJ.Figure (整个UIFigure) 保存为一个 PNG 文件，
            %   并遍历 OBJ.PlotDict 中的所有 Axes，将每个子图也分别保存为一个 PNG 文件。
            %   文件名将包含年份信息，格式为 'dashboard_year_YYYY.png' 和 'AxesName_year_YYYY.png'。
            %
            %   输入:
            %       obj        - PopulationDashboard 对象实例。
            %       output_dir - 字符串，指定保存图像的输出目录路径。
            %       year       - double 标量，当前年份，用于文件名。
            
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
    % EXTRACTSTRUCTPROPFIELDS 从同构类实例数组中提取指定属性内结构体的特定字段值。
    %   FIELDARRAY = EXTRACTSTRUCTPROPFIELDS(INSTARRAY, PROPNAME, FIELDNAME)
    %   遍历 INSTARRAY (对象数组) 中的每个对象，访问其名为 PROPNAME 的属性 (该属性应为一个标量结构体)，
    %   然后从该结构体中提取名为 FIELDNAME 的字段的值。所有提取到的字段值被横向拼接成一个数组 FIELDARRAY。
    %   这常用于从 PopulationState 对象数组中提取历年的统计数据。
    %
    %   输入:
    %       InstArray - 对象数组 (例如 PopulationState 数组)。
    %       PropName  - 字符串，对象中包含目标结构体的属性名称 (例如 'LifeCycleGenderStats')。
    %       FieldName - 字符串，目标结构体中要提取的字段名称 (例如 'LifeCycleCounts')。
    %
    %   输出:
    %       FieldArray - 数组，其中每列对应 InstArray 中的一个对象，包含提取的字段值。
    PropList = [InstArray.(PropName)];
    FieldArray = arrayfun(@(x) x.(FieldName)', PropList, "UniformOutput", false);
    FieldArray = cell2mat(FieldArray);
end

function pivottable = intersectionTablulate(CategoryVar, CountVar, Varnames)
    % INTERSECTIONTABLULATE 根据两个分类变量创建数据透视表 (交叉表)。
    %   PIVOTTABLE = INTERSECTIONTABLULATE(CATEGORYVAR, COUNTVAR, VARNAMES)
    %   首先将输入的 CATEGORYVAR 和 COUNTVAR (通常代表个体属性，如生命周期状态和世代)
    %   以及它们对应的名称 VARNAMES (例如 {'LifeCycleState', 'Generations'}) 组合成一个临时表 T。
    %   然后使用 pivot 函数，以 CATEGORYVAR 作为列，COUNTVAR 作为行，生成一个数据透视表 PIVOTTABLE，
    %   其中包含各个组合的计数。'IncludeEmptyGroups=true' 确保所有可能的类别组合都出现在结果中，即使计数为零。
    %
    %   输入:
    %       CategoryVar - 分类变量1 (例如，生命周期状态数组)。
    %       CountVar    - 分类变量2 (例如，世代ID数组)。
    %       Varnames    - 1x2 cellstr，包含两个变量的名称。
    %
    %   输出:
    %       pivottable  - table 类型，交叉统计表。
    T = table(CategoryVar', CountVar', 'VariableNames', Varnames);
    pivottable = pivot(T, Columns = Varnames(1), Rows = Varnames(2), IncludeEmptyGroups=true);
end

function colors = getTemporalColors(temporal, colorOrder)
    % GETTEMPORALCOLORS 根据时间序列数据为每个时间点分配颜色。
    %   COLORS = GETTEMPORALCOLORS(TEMPORAL, COLORORDER)
    %   根据 TEMPORAL 数组中的值 (通常是世代ID或其他随时间变化的分类数据) 和
    %   预定义的 COLORORDER (一个 N×3 的 RGB 颜色矩阵)，为 TEMPORAL 中的每个元素计算一个颜色。
    %   颜色分配是循环的：TEMPORAL 中的值通过模运算映射到 COLORORDER 中的行索引。
    %
    %   输入:
    %       temporal   - 数值数组，其值将用于确定颜色索引。
    %       colorOrder - N×3 RGB 颜色矩阵。
    %
    %   输出:
    %       colors     - M×3 RGB 颜色矩阵，其中 M 等于 TEMPORAL 中的元素数量，每行是一个颜色。
    % 计算颜色索引（基于绝对数值循环使用颜色）
    numColors = size(colorOrder, 1);
    colorIndices = mod(temporal, numColors) + 1;  % MATLAB 索引从1开始
    
    % 获取颜色
    colors = colorOrder(colorIndices, :);
end

% 自定义验证函数（保存为 mustBeClassAorB.m）
function mustBeAxesPieDonut(value)
    % MUSTBEAXESPIEDONUT 属性验证函数，确保属性值是 Axes、PieChart 或 DonutChart 对象。
    %   MUSTBEAXESPIEDONUT(VALUE) 检查 VALUE 是否是 'matlab.graphics.axis.Axes'、
    %   'matlab.graphics.chart.PieChart' 或 'matlab.graphics.chart.DonutChart' 类之一的实例。
    %   如果不是，则抛出一个错误。此函数用于类属性定义中，以强制属性类型。
    %
    %   输入:
    %       value - 待验证的属性值。
    validClasses = {'matlab.graphics.axis.Axes', ...
    'matlab.graphics.chart.PieChart', ...
    'matlab.graphics.chart.DonutChart'};
    if ~any(cellfun(@(cls) isa(value, cls), validClasses))
        error('属性必须是 Axes, PieChart, 或 DonutChart 的实例。');
    end
end

function updatePlotData(hdls, xdata, ydata)
    % UPDATEPLOTDATA 高效更新多个绘图句柄的 XData 和 YData。
    %   UPDATEPLOTDATA(HDLS, XDATA, YDATA) 更新 HDLS (绘图句柄数组) 中每个句柄的 XData 和 YData。
    %   XDATA 是一维向量 (行或列)，将作为所有句柄共享的 X 轴数据。
    %   YDATA 是一个二维矩阵，其维度需要与 XDATA 和 HDLS 的数量兼容：
    %       - 如果 XDATA 是行向量 (1×N)，则 YDATA 必须是 M×N，其中 M 是 HDLS 中的句柄数。
    %         YDATA 的每一行将成为对应句柄的 Y 轴数据。
    %       - 如果 XDATA 是列向量 (N×1)，则 YDATA 必须是 N×M，其中 M 是 HDLS 中的句柄数。
    %         YDATA 的每一列将成为对应句柄的 Y 轴数据。
    %   此函数使用 num2cell 和 deal 实现高效的数据分发。
    %
    %   输入:
    %       hdls  - 绘图对象句柄的一维数组。
    %       xdata - 一维数值向量 (行或列)，用于所有句柄的 XData。
    %       ydata - 二维数值矩阵，用于各个句柄的 YData。
    
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