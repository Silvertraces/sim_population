% TestPropertyClassDemo 测试脚本
% 该脚本用于测试TestPropertyClass的功能

% 清除工作区和关闭所有图形窗口
clear;
close all;

% 创建TestPropertyClass实例
disp('创建TestPropertyClass实例...');
testObj = TestPropertyClass();

% 调用initializeWithUI方法显示属性设置界面
disp('调用initializeWithUI方法显示属性设置界面...');
newObj = testObj.initializeWithUI();

% 检查用户是否取消了操作
if isempty(newObj)
    disp('用户取消了操作，未创建新对象。');
else
    % 显示设置后的属性值
    disp('成功创建新对象！属性值如下：');
    
    % 获取所有属性名
    props = properties(newObj);
    
    % 显示每个属性的值
    for i = 1:length(props)
        propName = props{i};
        propValue = newObj.(propName);
        
        % 根据属性类型格式化显示
        if isnumeric(propValue)
            if isscalar(propValue)
                disp([propName, ': ', num2str(propValue)]);
            else
                disp([propName, ': 数组，维度 ', mat2str(size(propValue))]);
                disp(propValue);
            end
        elseif islogical(propValue)
            if propValue
                disp([propName, ': true']);
            else
                disp([propName, ': false']);
            end
        elseif ischar(propValue)
            disp([propName, ': ''', propValue, '''']);
        elseif isstring(propValue)
            disp([propName, ': "', char(propValue), '"']);
        elseif isdatetime(propValue)
            disp([propName, ': ', datestr(propValue)]);
        elseif iscategorical(propValue)
            disp([propName, ': ', char(propValue)]);
        elseif iscell(propValue)
            disp([propName, ': 元胞数组，长度 ', num2str(length(propValue))]);
        else
            disp([propName, ': ', class(propValue), ' 类型']);
        end
    end
    
    % 清理
    clear newObj;
end

% 清理
clear testObj;