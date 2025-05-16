classdef Population < handle
    % Population 种群类
    % 管理所有个体并实现种群动态
    
    properties
        individuals Individual % 个体对象数组
        current_year int32 = 0 % 当前年份
        all_next_id int32 = 1     % 下一个个体全局ID
        gen_next_ids int32 = 1     % 每个世代的起始ID数组
        currentYearDeathsCount int32 = 0 % 当前年份死亡个体数
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
            obj.initializePopulation(obj.params.population, obj.params.structure_type);
        end
        
    end
    
    methods
        function initializePopulation(obj, population_size, structure_type)
            % initializePopulation 根据不同经典年龄结构和平均生育年龄初始化初始种群，并进行世代分箱
            % 输入:
            %   population_size - 初始种群数量
            %   structure_type - 年龄结构类型（'pyramid', 'inverted_pyramid', 'column', 'coffin', 'custom'等）
            %
            % 若未指定structure_type，默认为'column'（均匀分布）
            if nargin < 3
                structure_type = 'column';
            end
            % 获取参数
            max_age = obj.params.max_age;
            repro_range = obj.params.range_repro;
            mean_repro_age = obj.params.mean_repro_age; % 获取平均生育年龄

            if mean_repro_age <= 0
                warning('平均生育年龄为0或负数，所有初始个体将属于第1代。');
                % 即使平均生育年龄无效，也应继续初始化，但所有个体都属于第一代
            end

            % % 生成年龄分布
            % age_dist = zeros(1, max_age + 1);
            switch lower(structure_type)
                case {'pyramid', '金字塔型'}
                    age_dist = linspace(1.5, 0.5, max_age + 1);
                case {'inverted_pyramid', '倒金字塔型'}
                    age_dist = linspace(0.5, 1.5, max_age + 1);
                case {'coffin', '枣核型'}
                    mu = round(max_age / 2);
                    sigma = max(2, round(max_age / 6));
                    age_dist = exp(-0.5 * ((0:max_age) - mu).^2 / sigma^2);
                case {'column', '柱型'}
                    age_dist = ones(1, max_age + 1);
                case {'custom', '自定义'}
                    error('暂未实现自定义年龄结构');
                otherwise
                    warning('未知年龄结构类型，采用均匀分布');
                    age_dist = ones(1, max_age + 1);
            end
            age_dist = age_dist / sum(age_dist);
            age_counts = round(age_dist .* double(population_size));
            diff = population_size - sum(age_counts);
            if diff ~= 0
                [~, idx] = max(age_dist); % 将多余或不足的数量加到概率最大的年龄组
                age_counts(idx) = age_counts(idx) + diff;
            end

            % 创建个体年龄数组并打乱
            ages = repelem(0:max_age, age_counts);
            ages = ages(randperm(population_size)); 

            % 性别分配并打乱
            num_males = round(population_size * obj.params.ratio_m);
            num_females = population_size - num_males;
            
            % 使用 repmat 和 categorical 
            % 批量创建性别数组（前num_males个为雄性，其余为雌性）
            genders = [repmat(categorical("male"), 1, num_males), repmat(categorical("female"), 1, num_females)];
            genders = genders(randperm(population_size)); 

            % 使用createArray预分配个体数组
            obj.individuals = createArray(1, population_size, "Individual");

            % --- 批量设置个体属性 ---
            % 设置全局ID
            all_ids = obj.all_next_id : (obj.all_next_id + population_size - 1);
            
            % --- 根据年龄和平均生育年龄进行世代分箱 ---
            % 目标：年龄较大的个体属于较早的世代 (世代号小)，年龄较小的个体属于较晚的世代 (世代号大)
            % 例如，如果平均生育年龄是 mean_repro_age，最大年龄是 max_age
            % 一个年龄为 age 的个体，其世代数可以考虑为 floor((max_age - age) / mean_repro_age) + 1
            % 这样，年龄最大的个体（接近 max_age）的世代数接近1，而年龄最小的个体（接近0）的世代数最大。
            if mean_repro_age > 0
                % 计算相对于最大年龄的“生育周期数”
                % 年龄越大，(max_age - ages)越小，世代数越小
                individual_generations = floor((max_age - ages) / mean_repro_age) + 1;
            else % 如果平均生育年龄无效，则所有个体属于第一代
                individual_generations = ones(1, population_size);
            end
            individual_generations = max(individual_generations, 1); % 确保最小代数为1

            % --- 设置世代ID (gen_id) ---
            % gen_id 是在同一世代内的个体的唯一标识符，从1开始计数
            % unique_initial_gens 包含了所有初始个体实际产生的世代编号
            gen_ids_assigned = zeros(1, population_size); % 预分配用于存储每个个体的世代ID
            unique_initial_gens = unique(individual_generations); % 获取所有不重复的世代编号，并按升序排列

            for i = 1:length(unique_initial_gens)
                current_gen_val = unique_initial_gens(i);
                
                % 确保 obj.gen_next_ids 对当前代有效且已初始化为起始ID 1
                if length(obj.gen_next_ids) < current_gen_val || obj.gen_next_ids(current_gen_val) == 0
                    obj.gen_next_ids(current_gen_val) = 1; % MATLAB会自动扩展数组并用0填充，然后此行将其设置为1
                end
                
                gen_mask_for_this_gen = (individual_generations == current_gen_val);
                num_in_this_gen = nnz(gen_mask_for_this_gen);
                
                start_id_for_this_gen = obj.gen_next_ids(current_gen_val);
                gen_ids_assigned(gen_mask_for_this_gen) = start_id_for_this_gen : (start_id_for_this_gen + num_in_this_gen - 1);
                
                obj.gen_next_ids(current_gen_val) = start_id_for_this_gen + num_in_this_gen;
            end

            % --- 将计算好的属性批量赋值给个体对象 ---
            % 使用 num2cell 将数组转换为元胞数组，以便使用 deal 进行批量赋值
            all_idCells = num2cell(all_ids); % 全局ID
            gen_idCells = num2cell(gen_ids_assigned); % 世代ID
            ageCells = num2cell(ages); % 年龄
            genderCells = num2cell(genders); % 性别
            generationDataCells = num2cell(individual_generations); % 代数
            birthYearCells = num2cell(obj.current_year - int32(ages)); % 根据当前年份和年龄计算出生年份

            % 批量设置核心属性
            [obj.individuals.all_id] = deal(all_idCells{:});
            [obj.individuals.gen_id] = deal(gen_idCells{:});
            [obj.individuals.age] = deal(ageCells{:});
            [obj.individuals.gender] = deal(genderCells{:});
            [obj.individuals.generation] = deal(generationDataCells{:});
            [obj.individuals.birth_year] = deal(birthYearCells{:});

            % --- 设置初始生命状态 (life_status) ---
            % 根据年龄和繁殖年龄范围确定个体的初始生命状态
            life_statuses_val = repmat(LifeCycleState.Premature, 1, population_size); % 默认为未成熟
            mature_mask = (ages >= repro_range(1)) & (ages <= repro_range(2)); % 处于繁殖年龄范围内的为成熟
            old_mask = ages > repro_range(2); % 大于繁殖年龄上限的为年老
            life_statuses_val(mature_mask) = LifeCycleState.Mature;
            life_statuses_val(old_mask) = LifeCycleState.Old;
            lifeStatusCells = num2cell(life_statuses_val);
            [obj.individuals.life_status] = deal(lifeStatusCells{:});
            
            % --- 设置初始父母信息 ---
            % 初始种群没有父母，相关ID和代数设为0
            parent_val = 0; % 表示无父母的占位符
            % 父母全局ID，每行代表一个个体，[父亲ID, 母亲ID]
            parentAllIdsCells = num2cell(repmat([parent_val, parent_val], population_size, 1), 2);
            % 父母世代ID，同上结构
            parentGenIdsCells = num2cell(repmat([parent_val, parent_val], population_size, 1), 2);
            % 父母代数，同上结构
            parentGensCells = num2cell(repmat([parent_val, parent_val], population_size, 1), 2);

            [obj.individuals.parent_all_ids] = deal(parentAllIdsCells{:});
            [obj.individuals.parent_gen_ids] = deal(parentGenIdsCells{:});
            [obj.individuals.parent_gens] = deal(parentGensCells{:});

            % --- 更新下一个可用的全局ID ---
            % obj.gen_next_ids 已在之前的世代ID分配循环中更新
            obj.all_next_id = obj.all_next_id + population_size;
        end
        
        function simulateYear(obj)
            % simulateYear 模拟一年的种群变化
            % 包括个体状态更新、死亡和繁殖
            
            % 更新当前年份
            obj.current_year = obj.current_year + 1;
            
            % --- 个体状态更新和死亡 ---
            % 获取所有个体的生命状态 (使用 [obj.individuals.life_status] 向量化获取枚举数组)
            life_statuses = [obj.individuals.life_status];
            
            % 找出所有非死亡个体的逻辑索引，顺便统计update前的死亡个体数
            alive_mask = life_statuses < LifeCycleState.Dead;
            deathcount_pre = nnz(life_statuses == LifeCycleState.Dead);

            % 获取需要传递给个体 update 方法的参数
            death_probs = obj.params.death_probs;
            repro_range = obj.params.range_repro;
            repro_probs = obj.params.repro_probs;
            prob_m_repro = obj.params.prob_m_repro;
            birth_period = obj.params.birth_period;
            
            % 使用 arrayfun 批量更新非死亡个体的状态
            % arrayfun 在这里是合适的，因为 Individual.update 是对象方法，处理单个个体
            arrayfun(@(ind) ind.update(obj.current_year, death_probs, repro_range), obj.individuals(alive_mask));

            % update后的死亡个体数
            life_statuses = [obj.individuals.life_status];
            deathcount_post = nnz(life_statuses == LifeCycleState.Dead);
            obj.currentYearDeathsCount = deathcount_post - deathcount_pre;

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
            new_individuals = createArray(1, num_reproducing_pairs, "Individual");
            
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
            
            state = PopulationState(obj.current_year, obj.currentYearDeathsCount, obj.individuals);
        end
        
        function states = batchSimulate(obj, max_years)
            % batchSimulate 批量模拟多年的种群变化
            % 一次性运行所有年份的模拟，并返回所有年份的状态
            % 输入:
            %   max_years - 最大模拟年份数
            % 输出:
            %   states - PopulationState对象数组，包含所有年份的种群状态
            
            % 预分配状态数组
            states = PopulationState.empty(0, max_years+1);
            
            % 存储初始状态
            states(1) = obj.getCurrentState();
            
            % 创建进度条
            progress_bar = waitbar(0, '批量模拟进行中...');
            
            % 批量模拟
            for year = 1:max_years
                obj.simulateYear();
                states(year+1) = obj.getCurrentState();
                waitbar(year/max_years, progress_bar, sprintf('正在模拟第 %d/%d 年...', year, max_years));
            end
            close(progress_bar);
        end
    end
end