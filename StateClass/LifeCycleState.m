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

    % % 继承基础超类的用法与从属属性用法互斥
    % properties (Dependent)
    %     StateCN
    % end
    
    % 可以选择在此处添加与状态本身相关的可复用方法或属性
    % 例如，一个方法来获取状态的显示名称（如果与成员名不同）
    % 或者一个简单的比较方法
    methods (Static)
        function catArray = toCategorical(statusArray)
            % 提取枚举成员名称
            enumNames = arrayfun(@(x) string(x), statusArray);
            
            % 获取所有类别（按定义顺序）
            allCategories = arrayfun(@(x) string(x), enumeration('LifeCycleState'));
            
            % 生成有序 categorical 数组
            catArray = categorical(enumNames, allCategories, 'Ordinal', true, 'Protected', true);
        end
    end
end