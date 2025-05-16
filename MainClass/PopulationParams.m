classdef PopulationParams < handle
    % PopulationParams 种群参数类
    % 管理种群模拟中的所有参数，提供默认值和类型验证
    % 暂时继承自handle，后续将改为继承UIPropertyControlBaseClass
    
    properties
        population (1,1) int32 = 1e4 % 初始种群数量
        ratio_m (1,1) double {mustBeInRange(ratio_m, 0, 1)} = 0.5 % 初始雄性比例
        age_expect (1,1) double = 80 % 寿命期望值
        ratio_age_dist_sigma (1,1) double {mustBePositive} = 0.05 % 寿命标准差比例
        ratio_range_repro (1,2) double {mustBeInRange(ratio_range_repro, 0, 1)} = [0.2, 0.6] % 繁殖年龄相对区间
        ratio_age_repro_mu (1,1) double {mustBeInRange(ratio_age_repro_mu, 0, 1)} = 0.4 % 繁殖概率分布均值比例
        ratio_age_repro_sigma (1,1) double {mustBePositive} = 0.1 % 繁殖概率分布标准差比例
        ratio_repro (1,1) double {mustBePositive} = 1 % 繁殖比率
        prob_m_repro (1,1) double {mustBeInRange(prob_m_repro, 0, 1)} = 0.5 % 生育雄性概率
        birth_period (1,1) int32 = 1 % 生育周期
        structure_type (1,1) string {mustBeMember(structure_type, ...
            {'pyramid', '金字塔型', 'inverted_pyramid', '倒金字塔型', 'coffin', '枣核型', ...
            'column', '柱型', 'custom', '自定义', ''})} = '' % 种群结构类型
    end
    
    properties (Dependent)
        % 繁殖年龄范围
        range_repro        % 繁殖年龄范围 [最小年龄, 最大年龄]
        % 平均生育年龄
        mean_repro_age     % 平均生育年龄（用于初始化分箱）
        % 最大年龄（死亡概率区间上限）
        max_age           % 最大年龄（死亡概率区间上限）
        % 繁殖概率数组
        repro_probs        % 每个年龄的繁殖概率
        % 死亡概率数组
        death_probs        % 每个年龄的死亡概率累积分布
    end
    
    methods
        % 修改构造函数以接受可选的结构体输入
        function obj = PopulationParams(paramsStruct)
            % 构造函数
            % 接受一个可选的结构体作为输入，用于设置非依赖属性的值
            % 未在结构体中提供的属性将使用默认值
            % 输入:
            %   paramsStruct (可选) - 包含要设置的属性及其值的结构体

            % 检查是否有输入参数
            if nargin == 1
                % 验证输入是否为大小为 1 的结构体
                if ~isstruct(paramsStruct) || ~isscalar(paramsStruct)
                    error('输入参数必须是大小为 1 的结构体');
                end

                % 获取类中所有非依赖属性的名称
                % 使用 meta.class 获取类元数据
                mc = ?PopulationParams;
                % 过滤出非依赖属性
                propList = mc.PropertyList;
                nonDependentProps = {propList(~[propList.Dependent]).Name};

                % 获取输入结构体的字段名
                inputFieldNames = fieldnames(paramsStruct);

                % 遍历输入结构体的字段
                for i = 1:length(inputFieldNames)
                    fieldName = inputFieldNames{i};

                    % 检查字段名是否是类的非依赖属性
                    if ismember(fieldName, nonDependentProps)
                        try
                            % 尝试将结构体字段的值赋给对应的属性
                            % MATLAB 会自动进行类型和属性验证
                            obj.(fieldName) = paramsStruct.(fieldName);
                        catch ME
                            % 如果赋值过程中发生错误（例如，类型不匹配或验证失败）
                            warning('无法为属性 "%s" 设置值。错误信息: %s', fieldName, ME.message);
                            % 可以选择在这里抛出错误而不是警告，取决于需求
                            % rethrow(ME);
                        end
                    else
                        % 如果字段名不是类的非依赖属性，可以选择警告或忽略
                        warning('输入结构体包含未知属性 "%s"，将被忽略。', fieldName);
                    end
                end
            elseif nargin > 1
                error('为populationparams的初始化参数过多')
            end
            % 如果没有输入参数，属性将使用其默认值进行初始化
        end
    end
    
    methods % 依赖属性的get方法
        function range = get.range_repro(obj)
            % 获取繁殖年龄范围
            % 输出:
            %   range - 繁殖年龄范围 [最小年龄, 最大年龄]
            
            % 计算繁殖年龄范围
            range = round(obj.ratio_range_repro * obj.age_expect);
        end
        
        function mean_age = get.mean_repro_age(obj)
            % 获取平均生育年龄（用于初始化分箱）
            % 输出:
            %   mean_age - 平均生育年龄
            range_repro = obj.range_repro;
            repro_range_width = range_repro(2) - range_repro(1);
            mean_age = range_repro(1) + repro_range_width * obj.ratio_age_repro_mu;
            mean_age = round(mean_age);
        end
        
        function val = get.max_age(obj)
            % 获取最大年龄（死亡概率区间上限）
            % 输出:
            %   val - 最大年龄
            age_dist_sigma = round(obj.age_expect * obj.ratio_age_dist_sigma);
            val = ceil(obj.age_expect + 5 * age_dist_sigma);
        end
        
        function probs = get.repro_probs(obj)
            % 获取繁殖概率数组
            % 输出:
            %   probs - 每个年龄的繁殖概率数组
            
            % 计算繁殖年龄范围
            range_repro = obj.range_repro; %#ok<*PROP>
            
            % 计算繁殖概率分布参数
            repro_range_width = range_repro(2) - range_repro(1);
            age_repro_mu = range_repro(1) + repro_range_width * obj.ratio_age_repro_mu;
            age_repro_mu = round(age_repro_mu);
            age_repro_sigma = round(repro_range_width * obj.ratio_age_repro_sigma);
            
            % 创建年龄范围内的每个年龄点
            ages = range_repro(1):range_repro(2);
            
            % 计算每个年龄的pdf值（截断高斯分布）
            pdf_values = exp(-0.5 * ((ages - age_repro_mu) / age_repro_sigma).^2);
            
            % 归一化，使总和为繁殖比率
            probs = pdf_values / sum(pdf_values) * obj.ratio_repro;
        end
        
        function probs = get.death_probs(obj)
            % 获取死亡概率累积分布数组
            % 输出:
            %   probs - 每个年龄的死亡概率累积分布数组
            
            % 计算繁殖年龄范围
            range_repro = obj.range_repro;
            
            % 计算寿命标准差
            age_dist_sigma = round(obj.age_expect * obj.ratio_age_dist_sigma);
            
            % 计算死亡概率区间（从繁殖期结束后到期望寿命右侧五倍标准差）
            max_age = obj.max_age;
            ages = (range_repro(2) + 1):max_age;
            
            % 计算每个年龄的pdf值（截断高斯分布）
            pdf_values = exp(-0.5 * ((ages - obj.age_expect) / age_dist_sigma).^2);
            
            % 归一化pdf值
            pdf_values = pdf_values / sum(pdf_values);
            
            % 计算累积分布函数（CDF）
            probs = cumsum(pdf_values);
        end
    end
    
%     methods (Access = protected)
%         function propNames = getPropertyNamesForControl(obj)
%             % 实现抽象方法，定义需要在UI中显示的属性列表
%             % 返回所有非依赖、非常量的属性名
%             propNames = {
%                 'population', ...
%                 'ratio_m', ...
%                 'age_expect', ...
%                 'ratio_age_dist_sigma', ...
%                 'ratio_range_repro', ...
%                 'ratio_age_repro_mu', ...
%                 'ratio_age_repro_sigma', ...
%                 'ratio_repro', ...
%                 'prob_m_repro', ...
%                 'birth_period' ...
%             };
%         end
%     end
    
%     methods (Static)
%         function mustBeInRange(value, min_val, max_val)
%             % 自定义验证函数：验证值是否在指定范围内
%             % 输入:
%             %   value - 要验证的值
%             %   min_val - 最小值
%             %   max_val - 最大值
%             if any(value < min_val) || any(value > max_val)
%                 error('值必须在 %g 和 %g 之间', min_val, max_val);
%             end
%         end
%     end
end