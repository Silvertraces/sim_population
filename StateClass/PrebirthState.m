classdef PrebirthState < LifeState
    % 代表 'prebirth' (出生前) 状态

    % 移除 StateName 属性
    % properties (Constant)
    %     % 定义该状态的规范名称
    %     StateName = "prebirth";
    % end

    methods
        function nextState = updateState(~, individual, current_year, ~, ~)
            % 计算当前年龄
            individual.age = current_year - individual.birth_year;

            % 如果年龄大于等于 0，从 prebirth 转换为 premature
            if individual.age >= 0
                nextState = PrematureState();
            else
                % 否则，保持在 prebirth 状态
                nextState = PrebirthState();
            end
        end

        function enumState = getEnumState(~)
            % 返回对应的枚举成员
            enumState = LifeCycleState.Prebirth;
        end
    end
end

