classdef DeadState < LifeState
    % 代表 'dead' (死亡) 状态

    properties (Constant)
        % 定义该状态的规范名称
        StateName = "dead";
    end

    methods
        function nextState = updateState(~, ~, ~, ~, ~)
            % 一旦进入 dead 状态，个体将保持死亡状态
            nextState = DeadState();
        end
    end
end
