% 修改 Individual 类以使用状态模式和枚举类，并添加死亡事件
classdef Individual < handle
    % Individual 个体类
    % 存储种群模拟中每个个体的属性和方法
    
    properties
        all_id int32         % 个体全局编号
        gen_id int32         % 个体世代编号
        age int32 = 0     % 年龄，prebirth阶段可为负数
        generation int32  % 代数
        birth_year int32 % 出生年份
        parent_all_ids (1, 2) int32 % 亲代全局编号 [父亲ID, 母亲ID]
        parent_gen_ids (1, 2) int32 % 亲代世代编号 [父亲ID, 母亲ID]
        parent_gens (1, 2) int32 % 亲代世代数 [父亲ID, 母亲ID]
        gender categorical % 性别 (male:雄性, female:雌性)
        % life_status 属性类型改为 LifeCycleState 枚举类型
        life_status LifeCycleState = LifeCycleState.Premature % 生命周期状态 (与 currentState 同步)
    end

    properties (Access = private)
        currentState LifeState = PrematureState() % 当前状态对象
    end
    
    properties (Constant)
        gender_set = ["male", "female"] % 性别选项
        % life_status_set 已被 LifeCycleState 枚举类取代
        % life_status_set = ["prebirth", "premature", "mature", "old", "dead"] % 生命周期状态选项
    end

    % 定义死亡事件
    events
        DeathEvent % 当个体状态转换为 DeadState 时触发此事件
    end
    
    methods (Access = protected)
        % convertToCategorical 方法只保留 gender 相关的逻辑
        function catArray = convertToCategorical(~, inputValue, validCategories, isOrdinal)
            % 通用转换方法：将字符串或数值输入转换为分类数组 (仅用于 gender)
            % 输入:
            %   inputValue - 原始输入值（字符串、字符数组或分类数组）
            %   validCategories - 允许的类别集合（字符串数组）
            %   isOrdinal - 是否有序（逻辑值）
            % 输出:
            %   catArray - 转换后的分类数组
            
            % 如果输入是字符串/字符数组，转换为分类数组
            if isstring(inputValue) || ischar(inputValue)
                inputValue = categorical(inputValue, validCategories, 'Ordinal', isOrdinal);
            end
            
            % 验证类别合法性
            if ~all(ismember(categories(inputValue), validCategories))
                error('输入值包含非法类别，允许的类别为: %s', strjoin(validCategories, ', '));
            end
            
            % % 验证有序性 (如果需要严格验证有序性可以取消注释)
            % if isOrdinal && ~isordinal(inputValue)
            %     error('输入值必须是有序分类数组');
            % end
            
            catArray = inputValue;
        end
    end

    methods
        % 构造函数
        function obj = Individual()
            % 初始化个体处于 prebirth 状态对应的状态对象
            % obj.currentState = PrebirthState();
            % life_status 属性已在 properties 中初始化为 LifeCycleState.Prebirth
            % 无需在此处再次设置，除非需要根据外部输入初始化
        end

        % life_status 的 Setter
        % 现在 life_status 是 LifeCycleState 类型
        function set.life_status(obj, value)
            % 验证输入值是否为有效的 LifeCycleState 枚举成员
            if ~isa(value, 'LifeCycleState')
                 error('life_status 属性必须是 LifeCycleState 枚举类型');
            end
            obj.life_status = value;

            % --- 可选: 如果需要根据外部设置的 life_status 更新 currentState ---
            % 这部分取决于你是否打算从 update 方法外部直接设置 life_status。
            % 如果不需要，可以删除此部分。
            switch value
                case LifeCycleState.Prebirth
                    obj.currentState = PrebirthState();
                case LifeCycleState.Premature
                    obj.currentState = PrematureState();
                case LifeCycleState.Mature
                    obj.currentState = MatureState();
                case LifeCycleState.Old
                    obj.currentState = OldState();
                case LifeCycleState.Dead
                    obj.currentState = DeadState();
            end
            % ----------------------------------------------------------------------------
        end
        
        function set.gender(obj, value)
            % 调用通用转换方法设置 gender
            validCategories = obj.gender_set;
            % gender 不是有序的
            obj.gender = obj.convertToCategorical(value, validCategories, false);
        end
        
        function update(obj, current_year, death_probs, repro_range)
            % 使用状态模式更新个体的状态
            % 当前状态对象处理转换逻辑

            % 存储更新前的生命状态
            last_life_status = obj.life_status;

            % 将更新逻辑委托给当前状态对象
            % 状态对象内部会根据个体属性和输入参数决定下一个状态
            nextState = obj.currentState.updateState(obj, current_year, death_probs, repro_range);

            % 更新当前状态对象
            obj.currentState = nextState;
            % 同步 life_status 属性，使用新状态对象返回的枚举成员
            obj.life_status = obj.currentState.getEnumState();

            % 检查状态是否转换为 DeadState
            % 如果个体之前不是 Dead 状态，并且现在是 Dead 状态，则触发死亡事件
            if last_life_status ~= LifeCycleState.Dead && obj.life_status == LifeCycleState.Dead
                % 触发 DeathEvent
                notify(obj, 'DeathEvent');
            end
        end
    end
end
