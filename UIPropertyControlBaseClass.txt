classdef (Abstract) UIPropertyControlBaseClass < handle
    % UIPropertyControlBaseClass 属性控制抽象基类
    % 该抽象基类提供了一种机制，允许子类在实例化时通过UI控件方便地设置属性值
    % 基类能够自动解析子类中的属性定义（包括默认值、类型验证和维度规定），
    % 根据这些信息生成相应的输入控件
    
    properties (Access = protected)
        % 用于存储UI控件的属性
        UIFigure            % 主窗口
        UIGrid              % 网格布局
        PropertyControls    % 属性控件映射
        PropertyValidators  % 属性验证函数映射
        ApplyButton         % 应用按钮
        CancelButton        % 取消按钮
    end
    
    methods (Abstract, Access = protected)
        propertyNames = getPropertyNamesForControl(obj)
        % 子类必须实现此方法，返回需要在UI中显示的属性名称列表
    end
    
    methods
        function initializeWithUI(obj)
            % 初始化UI并显示属性控件
            % 创建主窗口
            obj.UIFigure = uifigure('Name', class(obj), 'Position', [100, 100, 800, 600]);
            
            % 获取需要显示的属性列表
            propertyNames = obj.getPropertyNamesForControl();
            
            % 计算所需的行数（每个属性一行，加上按钮行）
            numRows = length(propertyNames) + 1;
            
            % 创建自适应网格布局
            obj.UIGrid = uigridlayout(obj.UIFigure, [numRows, 2]);
            obj.UIGrid.RowHeight = repmat({30}, 1, numRows);
            obj.UIGrid.ColumnWidth = {'1x', '3x'};
            
            % 初始化控件映射
            obj.PropertyControls = containers.Map();
            obj.PropertyValidators = containers.Map();
            
            % 为每个属性创建控件
            for i = 1:length(propertyNames)
                propName = propertyNames{i};
                
                % 创建属性标签
                label = uilabel(obj.UIGrid);
                label.Text = propName;
                label.Layout.Row = i;
                label.Layout.Column = 1;
                label.HorizontalAlignment = 'right';
                label.Tooltip = propName; % 添加工具提示，显示完整属性名
                
                % 获取属性信息
                propInfo = obj.getPropertyInfo(propName);
                
                % 根据属性类型创建相应的控件
                [control, validator] = obj.createControlForProperty(obj.UIGrid, propInfo);
                control.Layout.Row = i;
                control.Layout.Column = 2;
                
                % 存储控件和验证函数
                obj.PropertyControls(propName) = control;
                obj.PropertyValidators(propName) = validator;
                
                % 如果是数组类型，可能需要调整行高
                if ~isempty(propInfo.size) && (isa(control, 'matlab.ui.control.Table') || isa(control, 'matlab.ui.control.TextArea'))
                    % 根据数组大小调整行高
                    rows = propInfo.size(1);
                    rowHeight = max(30, min(200, rows * 20)); % 限制最大高度
                    obj.UIGrid.RowHeight{i} = rowHeight;
                end
            end
            
            % 创建应用和取消按钮
            buttonPanel = uipanel(obj.UIGrid, 'BorderType', 'none');
            buttonPanel.Layout.Row = numRows;
            buttonPanel.Layout.Column = [1, 2];
            
            buttonLayout = uigridlayout(buttonPanel, [1, 2]);
            buttonLayout.ColumnWidth = {'1x', '1x'};
            buttonLayout.Padding = [10 10 10 10]; % 添加内边距
            
            obj.ApplyButton = uibutton(buttonLayout, 'Text', '应用');
            obj.ApplyButton.Layout.Column = 1;
            obj.ApplyButton.ButtonPushedFcn = @(src, event) obj.onApplyButtonClicked();
            
            obj.CancelButton = uibutton(buttonLayout, 'Text', '取消');
            obj.CancelButton.Layout.Column = 2;
            obj.CancelButton.ButtonPushedFcn = @(src, event) obj.onCancelButtonClicked();
            
            % 设置窗口大小自适应
            obj.UIFigure.AutoResizeChildren = 'on';
            drawnow; % 强制更新UI
        end
        
        function onApplyButtonClicked(obj)
            % 应用按钮点击事件处理
            % 获取所有属性值并验证
            propertyNames = keys(obj.PropertyControls);
            validationFailed = false;
            
            for i = 1:length(propertyNames)
                propName = propertyNames{i};
                control = obj.PropertyControls(propName);
                validator = obj.PropertyValidators(propName);
                
                % 获取控件值
                value = obj.getValueFromControl(control, propName);
                
                % 验证值
                if ~validator(value)
                    validationFailed = true;
                    uialert(obj.UIFigure, sprintf('属性 %s 的值无效', propName), '验证失败');
                    break;
                end
            end
            
            % 如果验证通过，设置属性值并关闭窗口
            if ~validationFailed
                for i = 1:length(propertyNames)
                    propName = propertyNames{i};
                    control = obj.PropertyControls(propName);
                    value = obj.getValueFromControl(control, propName);
                    obj.(propName) = value;
                end
                
                % 关闭窗口
                close(obj.UIFigure);
            end
        end
        
        function onCancelButtonClicked(obj)
            % 取消按钮点击事件处理
            % 直接关闭窗口
            close(obj.UIFigure);
        end
        
        function value = getValueFromControl(obj, control, propName)
            % 从控件获取值
            % 根据控件类型获取值
            if isa(control, 'matlab.ui.control.NumericEditField')
                % 数值编辑框
                value = control.Value;
            elseif isa(control, 'matlab.ui.control.EditField')
                % 文本编辑框
                value = control.Value;
            elseif isa(control, 'matlab.ui.control.CheckBox')
                % 复选框
                value = control.Value;
            elseif isa(control, 'matlab.ui.control.DatePicker')
                % 日期选择器
                value = control.Value;
            elseif isa(control, 'matlab.ui.control.DropDown')
                % 下拉列表
                value = control.Value;
            elseif isa(control, 'matlab.ui.control.Table')
                % 表格
                value = control.Data;
            elseif isa(control, 'matlab.ui.control.TextArea')
                % 文本区域
                % 根据属性类型转换值
                propInfo = obj.getPropertyInfo(propName);
                if ~isempty(propInfo.class)
                    switch propInfo.class
                        case 'cell'
                            % 元胞数组
                            value = obj.stringToCell(control.Value);
                        case 'table'
                            % 表格
                            value = obj.stringToTable(control.Value);
                        otherwise
                            value = control.Value;
                    end
                else
                    value = control.Value;
                end
            else
                % 默认返回空值
                value = [];
            end
        end
    end
    
    methods (Access = protected)
        function propInfo = getPropertyInfo(obj, propName)
            % 获取属性信息
            % 返回包含属性类型、默认值、验证条件等信息的结构体
            propInfo = struct();
            propInfo.name = propName;
            propInfo.class = '';
            propInfo.size = [];
            propInfo.defaultValue = [];
            propInfo.validation = {};
            propInfo.layoutSettings = [];
            
            % 获取类的元数据
            metaClass = metaclass(obj);
            
            % 查找属性元数据
            propMeta = UIPropertyControlBaseClass.findPropertyMeta(metaClass, propName);
            
            if ~isempty(propMeta)
                % 解析属性元数据
                propInfo = obj.parsePropertyMetadata(propMeta, propInfo);
                
                % 获取属性默认值
                propInfo.defaultValue = obj.(propName);
            end
            
            % 设置布局信息
            propInfo.layoutSettings = struct('Row', 1, 'Column', 2);
        end
        
        function propInfo = parsePropertyMetadata(obj, propMeta, propInfo)
            % 解析属性元数据
            % 处理属性的类型、维度和验证条件
            % 输入:
            %   propMeta - 属性元数据
            %   propInfo - 属性信息结构体
            % 输出:
            %   propInfo - 更新后的属性信息结构体
            
            % 处理属性类型
            if ~isempty(propMeta.Type)
                propInfo.class = propMeta.Type.Name;
            end
            
            % 处理属性维度
            if ~isempty(propMeta.Dimensions)
                propInfo.size = propMeta.Dimensions;
            end
            
            % 处理属性验证条件
            if ~isempty(propMeta.Validation)
                propInfo.validation = propMeta.Validation;
                
                % 特殊处理分类数组的验证条件
                if strcmp(propInfo.class, 'categorical')
                    for i = 1:length(propMeta.Validation)
                        validation = propMeta.Validation{i};
                        validationStr = func2str(validation);
                        
                        % 检查是否包含mustBeMember验证函数
                        if contains(validationStr, 'mustBeMember')
                            % 已在getPossibleCategoricalValues方法中处理
                            % 不需要break，继续检查其他验证条件
                        end
                    end
                end
            end
        end
        
        function [control, validator] = createControlForProperty(obj, parent, propInfo)
            % 根据属性信息创建相应的控件
            % 使用switch/case结构根据属性类型选择合适的控件创建函数
            
            % 如果没有类型信息，使用默认文本控件
            if isempty(propInfo.class)
                [control, validator] = obj.createStringControl(parent, propInfo.layoutSettings, '');
                return;
            end
            
            % 根据属性类型创建相应的控件
            switch propInfo.class
                case {'double', 'single', 'int8', 'int16', 'int32', 'int64', 'uint8', 'uint16', 'uint32', 'uint64'}
                    % 数值类型
                    if isempty(propInfo.defaultValue) || isscalar(propInfo.defaultValue)
                        [control, validator] = obj.createNumericScalarControl(parent, propInfo.layoutSettings, propInfo);
                    else
                        [control, validator] = obj.createNumericArrayControl(parent, propInfo.layoutSettings, propInfo);
                    end
                    
                case {'char', 'string'}
                    % 字符串类型
                    [control, validator] = obj.createStringControl(parent, propInfo.layoutSettings, propInfo.defaultValue);
                    
                case 'logical'
                    % 布尔类型
                    [control, validator] = obj.createBooleanControl(parent, propInfo.layoutSettings, propInfo.defaultValue);
                    
                case 'datetime'
                    % 日期时间类型
                    [control, validator] = obj.createDateTimeControl(parent, propInfo.layoutSettings, propInfo.defaultValue);
                    
                case 'categorical'
                    % 分类类型
                    [control, validator] = obj.createCategoricalControl(parent, propInfo.layoutSettings, propInfo);
                    
                case 'cell'
                    % 元胞数组类型
                    [control, validator] = obj.createComplexControl(parent, propInfo.layoutSettings, propInfo);
                    
                case 'table'
                    % 表格类型
                    [control, validator] = obj.createComplexControl(parent, propInfo.layoutSettings, propInfo);
                    
                otherwise
                    % 默认使用文本控件
                    [control, validator] = obj.createStringControl(parent, propInfo.layoutSettings, '');
            end
        end
        
        function [control, validator] = createNumericScalarControl(obj, parent, layoutSettings, propInfo)
            % 创建数值标量控件
            control = uieditfield(parent, 'numeric');
            control.Layout = layoutSettings;
            
            % 设置默认值
            if ~isempty(propInfo.defaultValue)
                control.Value = propInfo.defaultValue;
            else
                control.Value = 0;
            end
            
            % 根据属性类型设置限制
            if ~isempty(propInfo.class)
                switch propInfo.class
                    case {'int8', 'int16', 'int32', 'int64', 'uint8', 'uint16', 'uint32', 'uint64'}
                        control.RoundFractionalValues = 'on';
                end
            end
            
            % 验证函数
            validator = @(x) isnumeric(x) && isscalar(x);
        end
        
        function [control, validator] = createDateTimeControl(obj, parent, layoutSettings, defaultValue)
            % 创建日期时间控件
            control = uidatepicker(parent);
            control.Layout = layoutSettings;
            
            % 设置默认值
            if ~isempty(defaultValue) && isdatetime(defaultValue)
                control.Value = defaultValue;
            else
                control.Value = datetime('now');
            end
            
            % 验证函数
            validator = @(x) isdatetime(x);
        end
        
        function [control, validator] = createStringControl(obj, parent, layoutSettings, defaultValue)
            % 创建字符串控件
            control = uieditfield(parent, 'text');
            control.Layout = layoutSettings;
            
            % 设置默认值
            if ~isempty(defaultValue)
                if isstring(defaultValue)
                    control.Value = char(defaultValue);
                else
                    control.Value = defaultValue;
                end
            else
                control.Value = '';
            end
            
            % 验证函数
            validator = @(x) ischar(x) || isstring(x);
        end
        
        function [control, validator] = createBooleanControl(obj, parent, layoutSettings, defaultValue)
            % 创建布尔控件
            control = uicheckbox(parent);
            control.Layout = layoutSettings;
            
            % 设置默认值
            if ~isempty(defaultValue)
                control.Value = defaultValue;
            else
                control.Value = false;
            end
            
            % 验证函数
            validator = @(x) islogical(x) || (isnumeric(x) && (x == 0 || x == 1));
        end
        
        function [control, validator] = createCategoricalControl(obj, parent, layoutSettings, propInfo)
            % 创建分类控件
            control = uidropdown(parent);
            control.Layout = layoutSettings;
            
            % 获取可能的分类值
            possibleValues = obj.getPossibleCategoricalValues(propInfo);
            control.Items = possibleValues;
            
            % 设置默认值
            if ~isempty(propInfo.defaultValue) && iscategorical(propInfo.defaultValue)
                % 找到默认值在可能值列表中的索引
                defaultIndex = find(strcmp(possibleValues, char(propInfo.defaultValue)), 1);
                if ~isempty(defaultIndex)
                    control.Value = possibleValues{defaultIndex};
                elseif ~isempty(possibleValues)
                    control.Value = possibleValues{1};
                end
            else
                % 如果没有默认值或默认值不是分类类型，使用第一个可能值
                if ~isempty(possibleValues)
                    control.Value = possibleValues{1};
                end
            end
            
            % 验证函数
            validator = @(x) ischar(x) || isstring(x) || iscategorical(x);
        end
        
        function [control, validator] = createNumericArrayControl(obj, parent, layoutSettings, propInfo)
            % 创建数值数组控件
            % 使用表格控件来显示和编辑数值数组
            
            % 确定数组维度
            if ~isempty(propInfo.size)
                rows = propInfo.size(1);
                if length(propInfo.size) > 1
                    cols = propInfo.size(2);
                else
                    cols = 1;
                end
            else
                % 如果没有指定维度，使用默认值的维度
                if ~isempty(propInfo.defaultValue)
                    [rows, cols] = size(propInfo.defaultValue);
                else
                    % 默认为1x1
                    rows = 1;
                    cols = 1;
                end
            end
            
            % 创建表格控件
            control = uitable(parent);
            control.Layout = layoutSettings;
            
            % 设置表格列宽和行高
            control.ColumnWidth = repmat({50}, 1, cols);
            
            % 设置默认值
            if ~isempty(propInfo.defaultValue) && isnumeric(propInfo.defaultValue)
                % 确保默认值的维度与指定维度一致
                defaultValue = propInfo.defaultValue;
                [defaultRows, defaultCols] = size(defaultValue);
                
                % 如果默认值维度小于指定维度，扩展默认值
                if defaultRows < rows || defaultCols < cols
                    expandedValue = zeros(rows, cols);
                    expandedValue(1:min(defaultRows, rows), 1:min(defaultCols, cols)) = ...
                        defaultValue(1:min(defaultRows, rows), 1:min(defaultCols, cols));
                    defaultValue = expandedValue;
                % 如果默认值维度大于指定维度，截断默认值
                elseif defaultRows > rows || defaultCols > cols
                    defaultValue = defaultValue(1:rows, 1:cols);
                end
                
                control.Data = defaultValue;
            else
                % 如果没有默认值，使用零矩阵
                control.Data = zeros(rows, cols);
            end
            
            % 设置表格可编辑
            control.ColumnEditable = true(1, cols);
            
            % 验证函数
            validator = @(x) isnumeric(x) && all(size(x) == [rows, cols]);
        end
        
        function [control, validator] = createComplexControl(obj, parent, layoutSettings, propInfo)
            % 创建复杂类型控件（元胞数组、表格等）
            % 使用文本区域控件，用户可以输入符合特定格式的文本来表示复杂数据结构
            
            control = uitextarea(parent);
            control.Layout = layoutSettings;
            
            % 根据属性类型设置默认值和提示文本
            if ~isempty(propInfo.class)
                switch propInfo.class
                    case 'cell'
                        % 元胞数组
                        if ~isempty(propInfo.defaultValue) && iscell(propInfo.defaultValue)
                            try
                                % 将元胞数组转换为字符串表示
                                control.Value = obj.cellToString(propInfo.defaultValue);
                            catch
                                % 如果转换失败，使用默认示例
                                control.Value = '{1, ''text'', true}';
                            end
                        else
                            control.Value = '{1, ''text'', true}';
                        end
                        control.Tooltip = '输入元胞数组，格式如：{1, ''text'', true}。使用逗号分隔元素，字符串用单引号。';
                        % 更新验证函数，允许空值
                        validator = @(x) isempty(x) || iscell(x);
                    case 'table'
                        % 表格
                        if ~isempty(propInfo.defaultValue) && istable(propInfo.defaultValue)
                            try
                                % 将表格转换为字符串表示
                                control.Value = obj.tableToString(propInfo.defaultValue);
                            catch
                                % 如果转换失败，使用默认示例
                                control.Value = 'table(''VariableNames'', {''Var1'', ''Var2''}, ''Data'', {1, 2})';
                            end
                        else
                            control.Value = 'table(''VariableNames'', {''Var1'', ''Var2''}, ''Data'', {1, 2})';
                        end
                        control.Tooltip = '输入表格，格式如：table(''VariableNames'', {''Var1''}, ''Data'', {1})';
                        % 更新验证函数，允许空值
                        validator = @(x) isempty(x) || istable(x);
                    otherwise
                        control.Value = '';
                        validator = @(x) true;
                end
            else
                control.Value = '';
                validator = @(x) true;
            end
        end
        
        function possibleValues = getPossibleCategoricalValues(obj, propInfo)
            % 获取分类属性的可能值
            % 从属性验证条件中提取可能的分类值
            
            possibleValues = {};
            
            % 检查属性验证条件
            if ~isempty(propInfo.validation)
                for i = 1:length(propInfo.validation)
                    validation = propInfo.validation{i};
                    
                    % 检查是否是mustBeMember验证函数
                    if contains(func2str(validation), 'mustBeMember')
                        % 尝试从验证函数中提取可能值
                        try
                            % 获取验证函数的字符串表示
                            validationStr = func2str(validation);
                            
                            % 检查是否包含方括号形式的参数
                            if contains(validationStr, '[')
                                % 提取方括号内的参数（可能值列表）
                                startIdx = strfind(validationStr, '[') + 1;
                                endIdx = strfind(validationStr, ']') - 1;
                                
                                if ~isempty(startIdx) && ~isempty(endIdx) && startIdx(1) < endIdx(end)
                                    valuesStr = validationStr(startIdx(1):endIdx(end));
                                    
                                    % 解析值列表
                                    valuesList = strsplit(valuesStr, ',');
                                    
                                    % 清理值（去除引号和空格）
                                    for j = 1:length(valuesList)
                                        value = strtrim(valuesList{j});
                                        if startsWith(value, '"') && endsWith(value, '"')
                                            value = value(2:end-1);
                                        elseif startsWith(value, '''') && endsWith(value, '''')
                                            value = value(2:end-1);
                                        end
                                        possibleValues{end+1} = value;
                                    end
                                end
                            % 检查是否包含引号形式的参数（如"选项1","选项2"）
                            elseif contains(validationStr, '"') || contains(validationStr, '''')
                                % 提取所有引号内的内容
                                pattern = '([''"]).+?\1';
                                matches = regexp(validationStr, pattern, 'match');
                                
                                for j = 1:length(matches)
                                    value = matches{j};
                                    % 去除引号
                                    value = value(2:end-1);
                                    possibleValues{end+1} = value;
                                end
                            end
                        catch
                            % 如果解析失败，继续检查其他验证条件
                            continue;
                        end
                    end
                end
            end
            
            % 如果没有从验证条件中找到可能值，检查默认值
            if isempty(possibleValues) && ~isempty(propInfo.defaultValue) && iscategorical(propInfo.defaultValue)
                % 从默认值的类别中获取可能值
                try
                    cats = categories(propInfo.defaultValue);
                    possibleValues = cellstr(cats);
                catch
                    % 如果获取类别失败，使用默认选项
                    possibleValues = {'选项1', '选项2', '选项3'};
                end
            end
            
            % 如果仍然没有找到可能值，使用一些默认选项
            if isempty(possibleValues)
                possibleValues = {'选项1', '选项2', '选项3'};
            end
        end
        
        function cellStr = cellToString(obj, cellArray)
            % 将元胞数组转换为字符串表示
            % 输入:
            %   cellArray - 元胞数组
            % 输出:
            %   cellStr - 元胞数组的字符串表示
            
            % 检查输入是否为元胞数组
            if ~iscell(cellArray)
                cellStr = '{}';
                return;
            end
            
            % 初始化结果字符串
            cellStr = '{';
            
            % 处理每个元素
            for i = 1:numel(cellArray)
                try
                    element = cellArray{i};
                    
                    % 根据元素类型添加适当的字符串表示
                    if ischar(element)
                        % 字符数组用单引号括起来
                        % 处理字符串中的单引号，需要转义
                        element = strrep(element, '''', '''''');
                        cellStr = [cellStr, '''', element, ''''];
                    elseif isstring(element)
                        % 字符串用单引号括起来
                        % 处理字符串中的单引号，需要转义
                        charElement = char(element);
                        charElement = strrep(charElement, '''', '''''');
                        cellStr = [cellStr, '''', charElement, ''''];
                    elseif isnumeric(element)
                        if isscalar(element)
                            % 标量数值直接转换为字符串
                            cellStr = [cellStr, num2str(element)];
                        else
                            % 非标量数值使用方括号表示
                            cellStr = [cellStr, '[']; 
                            for j = 1:numel(element)
                                cellStr = [cellStr, num2str(element(j))];
                                if j < numel(element)
                                    cellStr = [cellStr, ', '];
                                end
                            end
                            cellStr = [cellStr, ']'];
                        end
                    elseif islogical(element)
                        if isscalar(element)
                            % 逻辑值转换为true/false
                            if element
                                cellStr = [cellStr, 'true'];
                            else
                                cellStr = [cellStr, 'false'];
                            end
                        else
                            % 非标量逻辑值使用方括号表示
                            cellStr = [cellStr, '[']; 
                            for j = 1:numel(element)
                                if element(j)
                                    cellStr = [cellStr, 'true'];
                                else
                                    cellStr = [cellStr, 'false'];
                                end
                                if j < numel(element)
                                    cellStr = [cellStr, ', '];
                                end
                            end
                            cellStr = [cellStr, ']'];
                        end
                    elseif iscell(element)
                        % 嵌套元胞数组递归处理
                        cellStr = [cellStr, obj.cellToString(element)];
                    elseif istable(element)
                        % 表格类型使用简化表示
                        cellStr = [cellStr, 'table()'];
                    elseif isdatetime(element)
                        % 日期时间类型转换为字符串
                        cellStr = [cellStr, 'datetime(''', char(string(element)), ''')'];
                    elseif iscategorical(element)
                        % 分类类型转换为字符串
                        cellStr = [cellStr, '''', char(element), ''''];
                    else
                        % 其他类型用空数组表示
                        cellStr = [cellStr, '[]'];
                    end
                catch
                    % 如果处理元素时出错，使用空数组表示
                    cellStr = [cellStr, '[]'];
                end
                
                % 如果不是最后一个元素，添加逗号和空格
                if i < numel(cellArray)
                    cellStr = [cellStr, ', '];
                end
            end
            
            % 添加结束括号
            cellStr = [cellStr, '}'];
        end
        
        function tableStr = tableToString(obj, tableObj)
            % 将表格对象转换为字符串表示
            % 输入:
            %   tableObj - 表格对象
            % 输出:
            %   tableStr - 表格的字符串表示
            
            % 检查输入是否为表格
            if ~istable(tableObj)
                tableStr = 'table()';
                return;
            end
            
            try
                % 初始化结果字符串
                tableStr = 'table(';
                
                % 添加变量名
                varNames = tableObj.Properties.VariableNames;
                if ~isempty(varNames)
                    tableStr = [tableStr, '''VariableNames'', {'];
                    for i = 1:length(varNames)
                        % 处理变量名中的单引号，需要转义
                        escapedName = strrep(varNames{i}, '''', '''''');
                        tableStr = [tableStr, '''', escapedName, ''''];
                        if i < length(varNames)
                            tableStr = [tableStr, ', '];
                        end
                    end
                    tableStr = [tableStr, '}, '];
                end
                
                % 添加行名（如果有）
                if ~isempty(tableObj.Properties.RowNames)
                    rowNames = tableObj.Properties.RowNames;
                    tableStr = [tableStr, '''RowNames'', {'];
                    for i = 1:length(rowNames)
                        % 处理行名中的单引号，需要转义
                        escapedName = strrep(rowNames{i}, '''', '''''');
                        tableStr = [tableStr, '''', escapedName, ''''];
                        if i < length(rowNames)
                            tableStr = [tableStr, ', '];
                        end
                    end
                    tableStr = [tableStr, '}, '];
                end
                
                % 添加数据
                % 尝试提取表格的一部分数据作为示例
                [rows, cols] = size(tableObj);
                maxSampleSize = 3; % 最多显示3行3列的数据
                sampleRows = min(rows, maxSampleSize);
                sampleCols = min(cols, maxSampleSize);
                
                tableStr = [tableStr, '''Data'', {'];
                
                % 添加数据样本
                for i = 1:sampleRows
                    for j = 1:sampleCols
                        % 获取单元格数据
                        try
                            cellData = tableObj{i,j};
                            % 根据数据类型添加适当的字符串表示
                            if isnumeric(cellData) && isscalar(cellData)
                                tableStr = [tableStr, num2str(cellData)];
                            elseif islogical(cellData) && isscalar(cellData)
                                if cellData
                                    tableStr = [tableStr, 'true'];
                                else
                                    tableStr = [tableStr, 'false'];
                                end
                            elseif ischar(cellData)
                                escapedData = strrep(cellData, '''', '''''');
                                tableStr = [tableStr, '''', escapedData, ''''];
                            elseif isstring(cellData)
                                escapedData = strrep(char(cellData), '''', '''''');
                                tableStr = [tableStr, '''', escapedData, ''''];
                            else
                                tableStr = [tableStr, '[]'];
                            end
                        catch
                            tableStr = [tableStr, '[]'];
                        end
                        
                        % 添加分隔符
                        if j < sampleCols
                            tableStr = [tableStr, ', '];
                        end
                    end
                    
                    % 如果不是最后一行，添加分号
                    if i < sampleRows
                        tableStr = [tableStr, '; '];
                    end
                end
                
                % 如果表格比样本大，添加省略号
                if rows > sampleRows || cols > sampleCols
                    tableStr = [tableStr, '... (省略部分数据)'];
                end
                
                tableStr = [tableStr, '}'];
                
                % 添加结束括号
                tableStr = [tableStr, ')'];
            catch
                % 如果处理过程中出错，返回简化的表格字符串
                tableStr = 'table(''VariableNames'', {''Var1''}, ''Data'', {[]})';
            end
        end
        
        function cell = stringToCell(obj, str)
            % 将字符串转换为元胞数组
            % 输入:
            %   str - 元胞数组的字符串表示，格式如：{1, 'text', true}
            % 输出:
            %   cell - 转换后的元胞数组
            
            % 检查输入是否为空
            if isempty(str)
                cell = {};
                return;
            end
            
            % 检查输入格式是否正确
            if ~startsWith(str, '{') || ~endsWith(str, '}')
                % 如果格式不正确，尝试修复
                if ~startsWith(str, '{')
                    str = ['{' str];
                end
                if ~endsWith(str, '}')
                    str = [str '}'];
                end
            end
            
            % 尝试使用eval函数将字符串转换为元胞数组
            try
                cell = eval(str);
                if ~iscell(cell)
                    % 如果结果不是元胞数组，创建一个包含该结果的元胞数组
                    cell = {cell};
                end
            catch
                % 如果转换失败，返回空元胞数组并显示警告
                warning('无法将字符串转换为元胞数组：%s', str);
                cell = {};
            end
        end
        
        function table = stringToTable(obj, str)
            % 将字符串转换为表格
            % 输入:
            %   str - 表格的字符串表示，格式如：table('VariableNames', {'Var1'}, 'Data', {1})
            % 输出:
            %   table - 转换后的表格
            
            % 检查输入是否为空
            if isempty(str)
                table = table();
                return;
            end
            
            % 检查输入格式是否正确
            if ~startsWith(str, 'table(')
                % 如果格式不正确，尝试修复
                str = ['table(' str];
                if ~endsWith(str, ')')
                    str = [str ')'];
                end
            end
            
            % 尝试使用eval函数将字符串转换为表格
            try
                table = eval(str);
                if ~istable(table)
                    % 如果结果不是表格，创建一个空表格
                    warning('转换结果不是表格类型');
                    table = table();
                end
            catch e
                % 如果转换失败，返回空表格并显示警告
                warning('无法将字符串转换为表格：%s\n错误：%s', str, e.message);
                table = table();
            end
        end
    end
    
    methods (Static, Access = protected)
        function propMeta = findPropertyMeta(metaClass, propName)
            % 在类的元数据中查找指定属性的元数据
            % 输入:
            %   metaClass - 类的元数据
            %   propName - 属性名称
            % 输出:
            %   propMeta - 属性的元数据，如果未找到则为空
            
            % 初始化结果
            propMeta = [];
            
            % 在当前类中查找属性
            for i = 1:length(metaClass.PropertyList)
                if strcmp(metaClass.PropertyList(i).Name, propName)
                    propMeta = metaClass.PropertyList(i);
                    return;
                end
            end
            
            % 如果在当前类中未找到，在父类中查找
            if ~isempty(metaClass.SuperclassList)
                for i = 1:length(metaClass.SuperclassList)
                    % 递归查找父类
                    propMeta = UIPropertyControlBaseClass.findPropertyMeta(metaClass.SuperclassList(i), propName);
                    if ~isempty(propMeta)
                        return;
                    end
                end
            end
        end
    end
end