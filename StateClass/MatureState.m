classdef MatureState < LifeState
    % 代表 'mature' (成熟) 状态

    % 移除 StateName 属性
    % properties (Constant)
    %     % 定义该状态的规范名称
    %     StateName = "mature";
    % end

    methods
        function nextState = updateState(~, individual, current_year, death_probs, repro_range)
            % 计算当前年龄
            individual.age = current_year - individual.birth_year;

            % 检查是否转换为 old 状态
            if individual.age > repro_range(2)
                nextState = OldState();
                return; % 已经转换，无需检查此状态下的死亡
            end

            % --- 如果需要为 mature 状态添加死亡概率逻辑，请在此处添加 ---
            % 示例:
            % mature_death_prob = 0.01; % 定义 mature 状态的死亡概率
            % if rand() <= mature_death_prob
            %     nextState = DeadState();
            %     return;
            % end
            % --------------------------------------------------------------

            % 如果没有发生转换，保持在 mature 状态
            nextState = MatureState();
        end

        function enumState = getEnumState(~)
            % 返回对应的枚举成员
            enumState = LifeCycleState.Mature;
        end
    end
end
