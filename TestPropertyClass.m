classdef TestPropertyClass < UIPropertyControlBaseClass
    % TestPropertyClass 测试属性控制类
    % 该类用于测试UIPropertyControlBaseClass的功能
    % 包含各种类型的属性和验证条件
    
    properties
        % 数值类型属性
        IntegerValue (1,1) int32 {mustBeInteger, mustBePositive} = 10
        DoubleValue (1,1) double {mustBeNumeric} = 3.14
        NegativeValue (1,1) double {mustBeNegative} = -5
        
        % 数组类型属性
        ArrayValue (2,3) double {mustBeNumeric} = ones(2,3)
        
        % 字符串类型属性
        StringValue (1,1) string = "测试字符串"
        CharValue char = 'test char'
        
        % 布尔类型属性
        BooleanValue (1,1) logical = true
        
        % 日期时间类型属性
        DateValue (1,1) datetime = datetime('now')
        
        % 分类类型属性
        CategoryValue (1,1) categorical {mustBeMember(CategoryValue,["选项1","选项2","选项3"])} = "选项1"
        
        % 复杂类型属性
        CellValue cell = {1, 'test', true}
    end
    
    methods
        function obj = TestPropertyClass()
            % 构造函数
            % 调用基类的initializeWithUI方法来显示UI控件
            initializeWithUI(obj)
        end
    end
    
    methods (Access = protected)
        function propertyNames = getPropertyNamesForControl(obj)
            % 实现抽象方法，返回需要在UI中显示的属性列表
            propertyNames = {
                'IntegerValue', ...
                'DoubleValue', ...
                'NegativeValue', ...
                'ArrayValue', ...
                'StringValue', ...
                'CharValue', ...
                'BooleanValue', ...
                'DateValue', ...
                'CategoryValue', ...
                'CellValue' ...
            };
        end
    end
end