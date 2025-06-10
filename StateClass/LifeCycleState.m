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

    methods
        function catArray = toCategoricalFromInstance(objArray)
            % toCategoricalFromInstance 根据当前 LifeCycleState 实例数组创建 categorical 数组
            %
            %   catArray = objArray.toCategoricalFromInstance()
            %
            %   该方法接受一个 LifeCycleState 枚举数组作为输入，并返回一个
            %   categorical 数组。与静态方法 toCategorical 不同，此方法
            %   仅使用输入数组中存在的枚举状态作为 categorical 数组的类别。
            %   生成的 categorical 数组将是有序的，并保留 LifeCycleState
            %   枚举中定义的顺序。

            % 提取枚举成员名称
            enumNames = arrayfun(@(x) string(x), objArray);
            
            % 获取输入数组中存在的唯一类别，并保持 LifeCycleState 定义的顺序
            % 先转换为双精度数组，然后排序，再转换回 LifeCycleState 枚举，最后提取唯一值
            uniqueEnumValues = unique(objArray);
            [~, sortedIdx] = sort(uniqueEnumValues);
            sortedUniqueEnumValues = uniqueEnumValues(sortedIdx);
            
            % 将数值转换回 LifeCycleState 枚举，然后转换为字符串
            instanceCategories = arrayfun(@(x) string(LifeCycleState(x)), sortedUniqueEnumValues);
            
            % 生成有序 categorical 数组
            catArray = categorical(enumNames, instanceCategories, 'Ordinal', true, 'Protected', true);
        end
    end
end