classdef PopulationParams < handle
    % PopulationParams 种群参数类
    % 管理种群模拟中的所有参数，提供默认值和类型验证
    % 暂时继承自handle，后续将改为继承UIPropertyControlBaseClass
    
    properties
        population (1,1) uint32 = 1e4 % 初始种群数量
        ratio_m (1,1) double {mustBeInRange(ratio_m, 0, 1)} = 0.5 % 初始雄性比例
        age_expect (1,1) uint16 = 80 % 寿命期望值
        ratio_age_dist_sigma (1,1) double {mustBePositive} = 0.05 % 寿命标准差比例
        ratio_range_repro (1,2) double {mustBeInRange(ratio_range_repro, 0, 1)} = [0.2, 0.6] % 繁殖年龄相对区间
        ratio_age_repro_mu (1,1) double {mustBeInRange(ratio_age_repro_mu, 0, 1)} = 0.4 % 繁殖概率分布均值比例
        ratio_age_repro_sigma (1,1) double {mustBePositive} = 0.1 % 繁殖概率分布标准差比例
        ratio_repro (1,1) double {mustBePositive} = 1 % 繁殖比率
        prob_m_repro (1,1) double {mustBeInRange(prob_m_repro, 0, 1)} = 0.5 % 生育雄性概率
        birth_period (1,1) uint8 = 1 % 生育周期
    end
    
    properties (Dependent)
        % 繁殖年龄范围
        range_repro        % 繁殖年龄范围 [最小年龄, 最大年龄]
        
        % 繁殖概率数组
        repro_probs        % 每个年龄的繁殖概率
        
        % 死亡概率数组
        death_probs        % 每个年龄的死亡概率累积分布
    end
    
    methods (Access = public)
        function obj = PopulationParams()
            % 构造函数
            % 初始化参数，暂时不使用UI控件
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
        
        function probs = get.repro_probs(obj)
            % 获取繁殖概率数组
            % 输出:
            %   probs - 每个年龄的繁殖概率数组
            
            % 计算繁殖年龄范围
            range_repro = obj.range_repro;
            
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
            max_age = ceil(obj.age_expect + 5 * age_dist_sigma);
            ages = (range_repro(2) + 1):max_age;
            
            % 计算每个年龄的pdf值（截断高斯分布）
            pdf_values = exp(-0.5 * ((ages - obj.age_expect) / age_dist_sigma).^2);
            
            % 归一化pdf值
            pdf_values = pdf_values / sum(pdf_values);
            
            % 计算累积分布函数（CDF）
            probs = cumsum(pdf_values);
        end
    end
    
    methods (Access = protected)
        function propNames = getPropertyNamesForControl(obj)
            % 实现抽象方法，定义需要在UI中显示的属性列表
            % 返回所有非依赖、非常量的属性名
            propNames = {
                'population', ...
                'ratio_m', ...
                'age_expect', ...
                'ratio_age_dist_sigma', ...
                'ratio_range_repro', ...
                'ratio_age_repro_mu', ...
                'ratio_age_repro_sigma', ...
                'ratio_repro', ...
                'prob_m_repro', ...
                'birth_period' ...
            };
        end
    end
    
    methods (Static)
        function mustBeInRange(value, min_val, max_val)
            % 自定义验证函数：验证值是否在指定范围内
            % 输入:
            %   value - 要验证的值
            %   min_val - 最小值
            %   max_val - 最大值
            if any(value < min_val) || any(value > max_val)
                error('值必须在 %g 和 %g 之间', min_val, max_val);
            end
        end
    end
end