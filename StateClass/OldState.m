classdef OldState < LifeState
    % 代表 'old' (老年) 状态

    % 移除 StateName 属性
    % properties (Constant)
    %     % 定义该状态的规范名称
    %     StateName = "old";
    % end

    methods
        function nextState = updateState(~, individual, current_year, death_probs, repro_range)
            % 计算当前年龄
            individual.age = current_year - individual.birth_year;

            % 根据超出繁殖范围最大年龄的年龄，计算死亡概率数组中的索引
            death_idx = individual.age - repro_range(2);

            % 检查是否死亡
            if death_idx >= 1 && death_idx <= length(death_probs)
                % 根据概率随机决定是否死亡
                if rand() <= death_probs(death_idx)
                    nextState = DeadState();
                    return; % 个体死亡
                end
            elseif death_idx > length(death_probs)
                % 年龄超过 death_probs 数组覆盖的最大年龄，个体必然死亡
                nextState = DeadState();
                return; % 个体死亡
            end

            % 如果个体没有死亡，保持在 old 状态
            nextState = OldState();
        end

        function enumState = getEnumState(~)
            % 返回对应的枚举成员
            enumState = LifeCycleState.Old;
        end
    end
end

