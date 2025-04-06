classdef Population < handle
    % Population 种群类
    % 管理所有个体并实现种群动态
    
    properties
        individuals     % 个体对象数组
        current_year uint16 = 0 % 当前年份
        all_next_id uint32 = 1     % 下一个个体全局ID
        gen_next_ids uint32 = 1     % 每个世代的起始ID数组
    end
    
    properties (Constant)
        params = PopulationParams   % 种群参数对象
    end
    
    methods
        function obj = Population()
            % 构造函数

            % 初始化世代起始ID
            obj.gen_next_ids = 1;
            
            % 初始化种群
            obj.initializePopulation(obj.params.population);
        end
        
    end
    
    methods
        function initializePopulation(obj, population_size)
            % 初始化种群
            % 输入:
            %   population_size - 初始种群数量
            
            % 计算雄性和雌性数量
            num_males = round(population_size * obj.params.ratio_m);
            num_females = population_size - num_males;
            
            % 使用createArray预分配个体数组
            obj.individuals = createArray(1, population_size, "Individual");
            
            % 创建性别数组（前num_males个为雄性，其余为雌性）
            genders = [repmat("male", 1, num_males), repmat("female", 1, num_females)];
            
            % 创建ID数组
            all_ids = 1:population_size;
            gen_ids = 1:population_size;
            
            % 批量设置属性
            all_idCells = num2cell(all_ids);
            gen_idCells = num2cell(gen_ids);
            [obj.individuals.all_id] = deal(all_idCells{:});
            [obj.individuals.gen_id] = deal(gen_idCells{:});
            
            % 使用num2cell将数组转换为单元格数组，然后批量赋值
            genderCells = num2cell(genders);
            [obj.individuals.gender] = deal(genderCells{:});
            
            % 设置其他属性
            [obj.individuals.generation] = deal(1);
            [obj.individuals.birth_year] = deal(0);
            
            % 设置父母ID（初始种群无父母）
            % 创建父母ID数组（全局ID和世代ID）
            parentAllIds = num2cell(repmat([0, 0], population_size, 1), 2);
            parentGenIds = num2cell(repmat([0, 0], population_size, 1), 2);
            [obj.individuals.parent_all_ids] = deal(parentAllIds{:});
            [obj.individuals.parent_gen_ids] = deal(parentGenIds{:});
            
            % 设置父母世代数（初始种群无父母，设为0）
            parentGens = num2cell(repmat([0, 0], population_size, 1), 2);
            [obj.individuals.parent_gens] = deal(parentGens{:});
            
            % 更新next_id
            obj.all_next_id = population_size + 1;
            obj.gen_next_ids(1) = population_size + 1;
        end
        
        function simulateYear(obj)
            % 模拟一年的种群变化
            
            % 更新当前年份
            obj.current_year = obj.current_year + 1;
            
            % 获取非死亡个体的逻辑索引
            life_statuses = [obj.individuals.life_status];
            alive_mask = life_statuses ~= categorical("dead");
            
            % 计算繁殖年龄范围
            range_repro = obj.params.range_repro;
            
            % 只更新非死亡个体
            arrayfun(@(ind) ind.update(obj.current_year, obj.params.death_probs, range_repro), obj.individuals(alive_mask));
            
            % 获取所有个体的生命状态
            life_statuses = [obj.individuals.life_status];
            
            % 找出成熟的个体
            mature_mask = life_statuses == categorical("mature");
            mature_individuals = obj.individuals(mature_mask);
            
            % 如果没有成熟个体，则跳过繁殖
            if isempty(mature_individuals)
                return;
            end
            
            % 获取成熟个体的性别
            genders = [mature_individuals.gender];
            male_mask = genders == categorical("male");
            female_mask = genders == categorical("female");
            
            % 找出成熟的雄性和雌性
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
                % 雄性是限制因素
                mature_limited = mature_males;
                mature_selected = mature_females;
                limited_ages = [mature_limited.age];
                is_male_limited = true;
            else
                % 雌性是限制因素
                mature_limited = mature_females;
                mature_selected = mature_males;
                limited_ages = [mature_limited.age];
                is_male_limited = false;
            end
            
            % 计算每个限制性别个体的繁殖概率
            age_indices = limited_ages - range_repro(1) + 1;
            
            if isempty(mature_limited)
                return;
            end
            
            % 获取繁殖概率
            repro_probs = obj.params.repro_probs(age_indices);
            
            % 随机决定哪些个体繁殖
            will_reproduce = rand(size(repro_probs)) <= repro_probs;
            reproducing_limited = mature_limited(will_reproduce);
            
            if isempty(reproducing_limited)
                return;
            end
            
            % 确定繁殖个体数量
            num_reproducing = length(reproducing_limited);
            
            % 使用nchoosek随机选择另一方参与配对的个体
            selected_indices = randperm(length(mature_selected), num_reproducing);
            reproducing_selected = mature_selected(selected_indices);
            
            % 根据性别限制因素，确定父母
            if is_male_limited
                % 雄性是限制因素
                fathers = reproducing_limited;
                mothers = reproducing_selected;
            else
                % 雌性是限制因素
                mothers = reproducing_limited;
                fathers = reproducing_selected;
            end
            
            % 确定后代性别
            offspring_genders = rand(1, num_reproducing) <= obj.params.prob_m_repro;
            offspring_genders_str = repmat("female", 1, num_reproducing);
            offspring_genders_str(offspring_genders) = "male";
            
            % 获取父母ID
            father_all_ids = [fathers.all_id];
            mother_all_ids = [mothers.all_id];
            father_gen_ids = [fathers.gen_id];
            mother_gen_ids = [mothers.gen_id];
            father_generations = [fathers.generation];
            mother_generations = [mothers.generation];
            
            % 确定代数（父母中的最大代数 + 1）
            offspring_generations = max([father_generations; mother_generations], [], 1) + 1;
            
            % 确定出生年份（当前年份 + 生育周期）
            birth_year = obj.current_year + obj.params.birth_period;
            
            
            
            % 创建新个体数组使用createArray
            new_individuals = createArray(1, num_reproducing, "Individual");
            
            % 批量设置新个体属性
            % 设置全局ID
            all_ids = obj.all_next_id:(obj.all_next_id + num_reproducing - 1);
            all_idCells = num2cell(all_ids);
            [new_individuals.all_id] = deal(all_idCells{:});
            
            % 设置世代ID
            gen_ids = zeros(1, num_reproducing);
            % 为每个新个体计算世代ID
            for i = unique(offspring_generations)
                % 更新世代起始ID数组
                if length(obj.gen_next_ids) < i
                    obj.gen_next_ids(i) = 1;
                end
                % 获取当前世代的新个体数量
                gen_new_counts(i) = nnz(offspring_generations == i);
                % 计算世代ID
                gen_ids(offspring_generations==i) = obj.gen_next_ids(i):(obj.gen_next_ids(i) + gen_new_counts(i) - 1);
                % 更新世代起始ID
                obj.gen_next_ids(i) = obj.gen_next_ids(i) + gen_new_counts(i);
            end
            % 将gen_ids转换为单元格数组
            gen_idCells = num2cell(gen_ids);
            % 批量赋值
            [new_individuals.gen_id] = deal(gen_idCells{:});
            
            % 设置性别
            genderCells = num2cell(offspring_genders_str);
            [new_individuals.gender] = deal(genderCells{:});
            
            % 设置代数
            genCells = num2cell(offspring_generations);
            [new_individuals.generation] = deal(genCells{:});
            
            % 设置出生年份
            [new_individuals.birth_year] = deal(birth_year);
            
            % 设置父母全局ID
            parentAllIdPairs = [father_all_ids; mother_all_ids]';
            parentAllIdCells = num2cell(parentAllIdPairs, 2);
            [new_individuals.parent_all_ids] = deal(parentAllIdCells{:});
            
            % 父母世代ID已经在前面获取，直接使用
            
            % 设置父母世代ID
            parentGenIdPairs = [father_gen_ids; mother_gen_ids]';
            parentGenIdCells = num2cell(parentGenIdPairs, 2);
            [new_individuals.parent_gen_ids] = deal(parentGenIdCells{:});
            
            % 设置父母世代数
            parentGensPairs = [father_generations; mother_generations]';
            parentGensCells = num2cell(parentGensPairs, 2);
            [new_individuals.parent_gens] = deal(parentGensCells{:});
            
            % 设置生命状态
            [new_individuals.life_status] = deal("prebirth");
            
            % 更新next_id
            obj.all_next_id = obj.all_next_id + num_reproducing;
            
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