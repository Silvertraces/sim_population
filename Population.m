classdef Population < handle
    % Population 种群类
    % 管理所有个体并实现种群动态
    
    properties
        individuals Individual % 个体对象数组
        current_year uint16 = 0 % 当前年份
        all_next_id uint32 = 1     % 下一个个体全局ID
        gen_next_ids uint32 = 1     % 每个世代的起始ID数组
    end
    
    properties (Access = private)
        params PopulationParams = PopulationParams  % 种群参数对象
    end
    
    methods
        function obj = Population(params)
            % 构造函数
            % 输入:
            %   params - PopulationParams 对象，包含种群模拟所需的所有参数

            if nargin == 1
                % 验证输入的参数对象类型
                if ~isa(params, 'PopulationParams')
                    error('输入参数必须是 PopulationParams 类的对象');
                end
                obj.params = params; % 存储参数对象
            elseif nargin > 1
                error('参数过多，应只传入一个PopulationParams参数')
            end
            
            % 初始化世代起始ID
            obj.gen_next_ids = 1;
            
            % 初始化种群
            obj.initializePopulation(obj.params.population);
        end
        
    end
    
    methods
        function initializePopulation(obj, population_size)
            % initializePopulation 初始化初始种群
            % 根据指定的种群大小和参数初始化个体数组
            % 输入:
            %   population_size - 初始种群数量
            
            % 计算雄性和雌性数量
            num_males = round(population_size * obj.params.ratio_m);
            num_females = population_size - num_males;
            
            % 使用 repmat 和 categorical 
            % 批量创建性别数组（前num_males个为雄性，其余为雌性）
            genders = [repmat(categorical("male"), 1, num_males), repmat(categorical("female"), 1, num_females)];
            
            % 创建ID数组
            all_ids = 1:population_size;
            % 初始种群属于第1代
            gen_ids = 1:population_size;
            
            % 使用createArray预分配个体数组
            obj.individuals = createArray(1, population_size, "Individual");
            % 批量设置属性
            all_idCells = num2cell(all_ids);
            gen_idCells = num2cell(gen_ids);
            % 使用num2cell将数组转换为单元格数组，然后批量赋值
            genderCells = num2cell(genders);
            
            [obj.individuals.all_id] = deal(all_idCells{:});
            [obj.individuals.gen_id] = deal(gen_idCells{:});
            [obj.individuals.gender] = deal(genderCells{:});
            
            % 批量设置其他属性
            % 初始种群代数为 1
            [obj.individuals.generation] = deal(1);
            % 初始种群出生年份为 0 (或根据需要设置为其他值)
            [obj.individuals.birth_year] = deal(0);
            
            % 设置父母ID（初始种群无父母）
            % 创建父母ID数组（全局ID和世代ID）
            % 设置父母世代数（初始种群无父母，设为0）
            parentAllIdsCells = num2cell(repmat([0, 0], population_size, 1), 2);
            parentGenIdsCells = num2cell(repmat([0, 0], population_size, 1), 2);
            parentGensCells = num2cell(repmat([0, 0], population_size, 1), 2);
            [obj.individuals.parent_all_ids] = deal(parentAllIdsCells{:});
            [obj.individuals.parent_gen_ids] = deal(parentGenIdsCells{:});
            [obj.individuals.parent_gens] = deal(parentGensCells{:});
            
            % 更新下一个全局ID和下一代起始ID
            obj.all_next_id = obj.all_next_id + population_size;
            obj.gen_next_ids(1) = obj.gen_next_ids(1) + population_size; % 更新第1代的下一个起始ID
        end
        
        function simulateYear(obj)
            % simulateYear 模拟一年的种群变化
            % 包括个体状态更新、死亡和繁殖
            
            % 更新当前年份
            obj.current_year = obj.current_year + 1;
            
            % --- 个体状态更新和死亡 ---
            % 获取所有个体的生命状态 (使用 [obj.individuals.life_status] 向量化获取枚举数组)
            life_statuses = [obj.individuals.life_status];
            
            % 找出所有非死亡个体的逻辑索引
            alive_mask = life_statuses < LifeCycleState.Dead;
            
            % 获取需要传递给个体 update 方法的参数
            death_probs = obj.params.death_probs;
            repro_range = obj.params.range_repro;
            prob_m_repro = obj.params.prob_m_repro;
            birth_period = obj.params.birth_period;
            
            % 使用 arrayfun 批量更新非死亡个体的状态
            % arrayfun 在这里是合适的，因为 Individual.update 是对象方法，处理单个个体
            arrayfun(@(ind) ind.update(obj.current_year, death_probs, repro_range), obj.individuals(alive_mask));
           
            % --- 繁殖 ---
            % 繁殖逻辑提取到单独的私有方法中
            obj.performReproduction(repro_range, repro_probs, prob_m_repro, birth_period);

            % --- 清理死亡个体 (可选，根据模拟需求决定是否立即移除) ---
            % 如果需要立即移除死亡个体以节省内存或简化后续操作，可以在这里添加逻辑
            % 例如:
            % current_life_statuses = [obj.individuals.life_status]; % 重新获取更新后的状态
            % alive_now_mask = current_life_statuses < LifeCycleState.Dead;
            % obj.individuals = obj.individuals(alive_now_mask);
        end


        function performReproduction(obj, repro_range, repro_probs, prob_m_repro, birth_period)
            % performReproduction 执行种群的繁殖过程
            % 根据成熟个体的繁殖概率和性别比例生成后代

            % 找出所有当前状态为 Mature 的个体
            % 重新获取更新后的生命状态
            current_life_statuses = [obj.individuals.life_status];
            mature_mask = current_life_statuses == LifeCycleState.Mature;
            mature_individuals = obj.individuals(mature_mask);
            
            % 如果没有成熟个体，则跳过繁殖
            if isempty(mature_individuals)
                return;
            end
            
            % 获取成熟个体的性别
            genders = [mature_individuals.gender];

            % 找出成熟的雄性和雌性
            male_mask = genders == categorical("male");
            female_mask = genders == categorical("female");
            
            mature_males = mature_individuals(male_mask);
            mature_females = mature_individuals(female_mask);
            
            % 如果没有成熟的雄性或雌性，则跳过繁殖
            if isempty(mature_males) || isempty(mature_females)
                return;
            end
            
            % 确定繁殖对数（取决于性别数量较少的一方）
            num_males = length(mature_males);
            num_females = length(mature_females);
            
            % 根据数量较少的性别确定繁殖逻辑
            if num_males <= num_females
                % 雄性是限制因素，雌性是待选择一方
                mature_limited = mature_males;
                mature_selected = mature_females;
            else
                % 雌性是限制因素，雄性是待选择一方
                mature_limited = mature_females;
                mature_selected = mature_males;
            end

            % 获取限制性别个体的年龄
            limited_ages = [mature_limited.age];
            is_male_limited = num_males <= num_females;
            
            % 计算每个限制性别个体在繁殖概率数组中的索引
            % 年龄减去繁殖起始年龄，然后加 1 (因为索引从 1 开始)
            age_indices = limited_ages - repro_range(1) + 1;
            
            % % 冗余判断，前面已判断有足够的成熟个体
            % if isempty(mature_limited)
            %     return;
            % end
            
            % 获取繁殖概率
            repro_probs_for_limited = repro_probs(age_indices);
            
            % 随机决定哪些个体繁殖 
            will_reproduce_mask = rand(size(repro_probs_for_limited)) <= repro_probs_for_limited;
            reproducing_limited = mature_limited(will_reproduce_mask);
            
            % 可能按照概率决定后，没有个体想要繁殖
            if isempty(reproducing_limited)
                return;
            end
            
            % 确定繁殖对数
            num_reproducing_pairs = length(reproducing_limited);
            
            % 随机选择另一方参与配对的个体 
            % 使用 randperm 确保每个个体最多被选择一次作为配对对象
            selected_indices = randperm(length(mature_selected), num_reproducing_pairs);
            reproducing_selected = mature_selected(selected_indices);
            
            % 根据性别限制因素，确定父母数组
            if is_male_limited
                % 雄性是限制因素，reproducing_limited 是父亲数组
                fathers = reproducing_limited;
                mothers = reproducing_selected;
            else
                % 雌性是限制因素，reproducing_limited 是母亲数组
                mothers = reproducing_limited;
                fathers = reproducing_selected;
            end
            
            % --- 创建新个体 ---
            % 确定后代性别 
            offspring_genders_logical = rand(1, num_reproducing_pairs) <= prob_m_repro;
            % 使用 categorical 数组直接表示性别
            offspring_genders = repmat(categorical("female"), 1, num_reproducing_pairs);
            offspring_genders(offspring_genders_logical) = categorical("male");
            
            % 获取父母的全局ID、世代ID和代数 
            father_all_ids = [fathers.all_id];
            mother_all_ids = [mothers.all_id];
            father_gen_ids = [fathers.gen_id];
            mother_gen_ids = [mothers.gen_id];
            father_generations = [fathers.generation];
            mother_generations = [mothers.generation];
            
            % 确定后代的代数（父母中的最大代数 + 1）
            offspring_generations = max([father_generations; mother_generations], [], 1) + 1;
            
            % 确定出生年份（当前年份 + 生育周期）
            birth_years = obj.current_year + birth_period;
            
            % 创建新个体数组使用createArray
            new_individuals = createArray(1, num_reproducing, "Individual");
            
            % --- 批量设置新个体属性 ---
            % 设置全局ID
            all_ids = obj.all_next_id : (obj.all_next_id + num_reproducing_pairs - 1);
            % 使用 num2cell 和 deal 批量赋值
            all_idCells = num2cell(all_ids);
            [new_individuals.all_id] = deal(all_idCells{:});
            
            % 设置世代ID (需要按代数分组处理，这部分向量化比较复杂，保留循环或考虑 helper 函数)
            gen_ids = zeros(1, num_reproducing_pairs);
            unique_generations = unique(offspring_generations);

            for i = 1:length(unique_generations)
                current_gen = unique_generations(i);
                % 确保 gen_next_ids 数组足够长
                if length(obj.gen_next_ids) < current_gen
                    obj.gen_next_ids(current_gen) = 1; % 新世代从 ID 1 开始
                end

                % 找出属于当前世代的新个体的逻辑索引
                gen_mask = offspring_generations == current_gen;
                num_new_in_gen = nnz(gen_mask);

                % 计算当前世代新个体的世代ID
                gen_ids(gen_mask) = obj.gen_next_ids(current_gen) : (obj.gen_next_ids(current_gen) + num_new_in_gen - 1);

                % 更新当前世代的下一个起始ID
                obj.gen_next_ids(current_gen) = obj.gen_next_ids(current_gen) + num_new_in_gen;
            end
            % 将 gen_ids 转换为元胞数组进行批量赋值
            gen_idCells = num2cell(gen_ids);
            [new_individuals.gen_id] = deal(gen_idCells{:});
            
            
            % 批量设置其他属性 (使用 num2cell 和 deal)
            genderCells = num2cell(offspring_genders);
            genCells = num2cell(offspring_generations);
            birthYearCells = num2cell(birth_years);

            [new_individuals.gender] = deal(genderCells{:});
            [new_individuals.generation] = deal(genCells{:});
            [new_individuals.birth_year] = deal(birthYearCells{:});
            
            % 设置父母全局ID、世代ID和世代数
            parentAllIdPairs = [father_all_ids; mother_all_ids]';
            parentGenIdPairs = [father_gen_ids; mother_gen_ids]';
            parentGensPairs = [father_generations; mother_generations]'; % 父母的代数

            parentAllIdCells = num2cell(parentAllIdPairs, 2);
            parentGenIdCells = num2cell(parentGenIdPairs, 2);
            parentGensCells = num2cell(parentGensPairs, 2);

            [new_individuals.parent_all_ids] = deal(parentAllIdCells{:});
            [new_individuals.parent_gen_ids] = deal(parentGenIdCells{:});
            [new_individuals.parent_gens] = deal(parentGensCells{:});
            
            % 设置生命状态为 prebirth
            [new_individuals.life_status] = deal(LifeCycleState.Prebirth);
            
            % 更新下一个全局ID
            obj.all_next_id = obj.all_next_id + num_reproducing_pairs;
            
            % 将新个体添加到种群中
            obj.individuals = [obj.individuals, new_individuals];
        end

        
        function simulateYears(obj, num_years)
            % 模拟多年的种群变化
            % 输入:
            %   num_years - 要模拟的年数
            
            for i = 1:num_years
                obj.simulateYear();
            end
        end
        
        function state = getCurrentState(obj)
            % 获取当前种群状态
            % 输出:
            %   state - PopulationState对象，包含当前种群的统计信息
            
            state = PopulationState(obj.current_year, obj.individuals);
        end
    end
end