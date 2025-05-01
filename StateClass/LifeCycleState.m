% 定义生命周期状态的枚举类
% 将此代码保存在名为 LifeCycleState.m 的文件中
classdef LifeCycleState < uint8
    % 生命周期状态枚举

    enumeration
        Prebirth    (0) % 出生前
        Premature   (1) % 未成熟
        Mature      (2) % 成熟
        Old         (3) % 老年
        Dead        (4) % 死亡
    end

    properties (Dependent)
        StateCN
    end
    
    % 可以选择在此处添加与状态本身相关的可复用方法或属性
    % 例如，一个方法来获取状态的显示名称（如果与成员名不同）
    % 或者一个简单的比较方法
    methods
        % isBefore: 检查当前状态是否在另一个状态之前
        function tf = isBefore(obj, otherState)
            tf = obj < otherState;
        end

        % isAfter: 检查当前状态是否在另一个状态之后
        function tf = isAfter(obj, otherState)
            tf = obj > otherState;
        end

        % get.StateCN: 获取状态的显示名称 (如果需要)
        function name = get.StateCN(obj)
            switch obj
                case LifeCycleState.Prebirth
                    name = '出生前';
                case LifeCycleState.Premature
                    name = '未成熟';
                case LifeCycleState.Mature
                    name = '成熟';
                case LifeCycleState.Old
                    name = '老年';
                case LifeCycleState.Dead
                    name = '死亡';
                otherwise
                    name = char(obj); % 默认使用成员名
            end
        end
    end
end
