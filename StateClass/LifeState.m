% 定义状态的抽象基类
classdef (Abstract) LifeState
    % 个体生命状态的抽象基类

    % 移除 StateName 属性，状态名称由枚举类提供
    % properties (Abstract, Constant)
    %     % StateName: 定义该状态的规范名称字符串
    %     StateName string
    % end

    % 移除 life_status_set 属性，状态集合由枚举类提供
    % properties (Constant)
    %     % life_status_set: 所有可能的生命状态名称集合
    %     % 将此集合定义在基类中，表示整个状态空间
    %     life_status_set = ["prebirth", "premature", "mature", "old", "dead"];
    % end

    methods (Abstract)
        % updateState: 处理状态转换逻辑并返回下一个状态对象
        % 输入:
        %   obj - 当前状态对象
        %   individual - 正在更新的 Individual 对象
        %   current_year - 当前仿真年份
        %   death_probs - 'old' 状态的累积死亡概率数组
        %   repro_range - 繁殖年龄范围 [最小年龄, 最大年龄]
        % 输出:
        %   nextState - 下一个状态对象
        nextState = updateState(obj, individual, current_year, death_probs, repro_range);

        % getEnumState: 返回该状态对应的枚举成员
        % 输出:
        %   enumState - LifeCycleState 枚举成员
        enumState = getEnumState(obj);
    end

    % 移除 getStateName 方法
    % methods
    %     % getStateName: 返回状态的名称 (类名)
    %     function name = getStateName(obj)
    %         name = string(class(obj));
    %     end
    % end
end

% 定义继承自 LifeState 的具体状态类