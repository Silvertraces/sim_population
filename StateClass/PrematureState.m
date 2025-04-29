classdef PrematureState < LifeState
    % 代表 'premature' (未成熟) 状态

    % 移除 StateName 属性
    % properties (Constant)
    %     % 定义该状态的规范名称
    %     StateName = "premature";
    % end

    methods
        function nextState = updateState(~, individual, current_year, ~, repro_range)
            % 计算当前年龄
            individual.age = current_year - individual.birth_year;

            % 如果年龄达到繁殖范围的起始年龄，从 premature 转换为 mature
            if individual.age >= repro_range(1)
                nextState = MatureState();
            else
                % 否则，保持在 premature 状态
                nextState = PrematureState();
            end
        end

        function enumState = getEnumState(~)
            % 返回对应的枚举成员
            enumState = LifeCycleState.Premature;
        end
    end
end

