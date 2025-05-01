classdef PopulationState < handle
    % PopulationState 种群状态类
    % 存储特定时间点的种群个体信息和统计数据
    % 包含用于可视化展板的依赖属性，统计数据按结构体组织
    
    properties
        % 基本信息
        year uint16                     % 统计年份
        currentYearDeathsCount uint16   % 当年死亡个体数
        
        % 个体属性数组（非未出生个体）
        % 这些是原始数据，依赖属性将基于它们进行计算
        all_ids         uint32          % 全局ID数组
        gen_ids         uint32          % 世代ID数组
        ages            int8            % 年龄数组，prebirth阶段可为负数
        generations     uint8           % 代数数组
        birth_years     uint16          % 出生年份数组
        parent_all_ids  uint32          % 亲代全局ID数组 [父亲ID, 母亲ID]
        parent_gen_ids  uint32          % 亲代世代ID数组 [父亲ID, 母亲ID]
        parent_gens     uint8           % 亲代世代数数组 [父亲世代, 母亲世代]
        genders         categorical     % 性别数组
        life_statuses   LifeCycleState  % 生命状态数组
    end

    properties (Dependent)
        % --- 依赖属性用于可视化统计，按结构体组织 ---

        % 生命周期和性别统计数据 (用于条形图)
        LifeCycleGenderStats struct

        % % 年龄分布统计数据 (用于饼图、甜甜圈图、直方图、KDE、小提琴图)
        % AgeDistributionStats struct

        % 世代统计数据 (用于世代条形图)
        GenerationStats struct

        % % 全局时间线图所需指标 (向量)
        % GlobalTimelineMetrics double
    end
    
    methods
        function obj = PopulationState(year, deathcount, individuals)
            % 构造函数
            % 输入:
            %   year - 统计年份
            %   individuals - 个体对象数组（所有个体）
            
            % 设置年份
            obj.year = year;
            obj.currentYearDeathsCount = deathcount;
            
            % 排除未出生个体
            life_statuses = [individuals.life_status];
            born_mask = life_statuses > LifeCycleState.Prebirth;
            born_individuals = individuals(born_mask);
            
            % 如果没有已出生个体，则返回空属性
            if isempty(born_individuals)
                % 初始化所有属性为空数组或默认值
                obj.all_ids = uint32.empty(1, 0);
                obj.gen_ids = uint32.empty(1, 0);
                obj.ages = int8.empty(1, 0);
                obj.generations = uint8.empty(1, 0);
                obj.birth_years = uint16.empty(1, 0);
                obj.parent_all_ids = uint32.empty(0, 2); % 父母ID是 Nx2 矩阵
                obj.parent_gen_ids = uint32.empty(0, 2);
                obj.parent_gens = uint8.empty(0, 2);
                obj.genders = categorical.empty(1, 0);
                obj.life_statuses = LifeCycleState.empty(1, 0); % 初始化为空的枚举数组
                return;
            end
            
            % 提取个体属性到数组 (仅已出生个体)
            obj.all_ids = [born_individuals.all_id];
            obj.gen_ids = [born_individuals.gen_id];
            obj.ages = [born_individuals.age];
            obj.generations = [born_individuals.generation];
            obj.birth_years = [born_individuals.birth_year];
            obj.genders = [born_individuals.gender];
            obj.life_statuses = [born_individuals.life_status];
            
            % 提取父母ID和世代数
            % 由于这些是二维数组，需要特殊处理
            % 使用 cell2mat 和 reshape 提取 Nx2 矩阵
            sz_idvdl = size(born_individuals);
            obj.parent_all_ids = cell2mat(reshape({born_individuals.parent_all_ids}, sz_idvdl));
            obj.parent_gen_ids = cell2mat(reshape({born_individuals.parent_gen_ids}, sz_idvdl));
            obj.parent_gens = cell2mat(reshape({born_individuals.parent_gens}, sz_idvdl));
        end

        % --- Dependent Property Get Methods ---

        function stats = get.LifeCycleGenderStats(obj)
            % 计算生命周期和性别统计数据

            % 计算按生命状态分组的个体数量 (排除 Prebirth)
            % 假设 LifeCycleState 枚举已经定义
            % 统计 Premature, Mature, Old, Dead 状态的数量
            lifeCycleCounts = [
                nnz(obj.life_statuses == LifeCycleState.Premature), ...
                nnz(obj.life_statuses == LifeCycleState.Mature), ...
                nnz(obj.life_statuses == LifeCycleState.Old), ...
                % nnz(obj.life_statuses == LifeCycleState.Dead) ...
                ];

            % 计算存活掩膜
            maskAlive = obj.life_statuses > LifeCycleState.Prebirth & obj.life_statuses < LifeCycleState.Dead;
            % 计算按性别分组的个体数量
            % 假设 Individual.gender_set 已经定义
            genderCounts = [
                nnz(obj.genders == categorical("male") & maskAlive), ...
                nnz(obj.genders == categorical("female") & maskAlive) ...
                ];

            % 计算已出生个体总数 (生命状态 > Prebirth)
            totalBorn = length(obj.all_ids);

            % 计算存活个体总数 (生命状态 > Prebirth 且 < Dead)
            totalAlive = nnz(maskAlive);

            % 计算相对比例 (基于 TotalBorn)
            if totalAlive > 0
                lifeCycleRatios = lifeCycleCounts / totalAlive;
                genderRatios = genderCounts / totalAlive;
            else
                lifeCycleRatios = zeros(size(lifeCycleCounts));
                genderRatios = zeros(size(genderCounts));
            end

            % 获取当前年份出生数
            currentYearBirthsCount = nnz(obj.ages == 0 & obj.birth_years == obj.year);

            % 组织到结构体中
            stats = struct(...
                'LifeCycleCounts', lifeCycleCounts, ...
                'GenderCounts', genderCounts, ...
                'TotalBorn', totalBorn, ...
                'TotalAlive', totalAlive, ...
                'LifeCycleRatios', lifeCycleRatios, ...
                'GenderRatios', genderRatios, ...
                'CurrentYearBirthsCount', currentYearBirthsCount, ...
                'CurrentYearDeathsCount', obj.currentYearDeathsCount, ...
                'NetGrowth', currentYearBirthsCount - obj.currentYearDeathsCount, ...
                'LifeCycleLabels', {categories(LifeCycleState.Premature:LifeCycleState.Old)}, ... % 对应的生命状态标签
                'GenderLabels', {categories(obj.genders)} ... % 对应的性别标签
            );
        end

        % function stats = get.AgeDistributionStats(obj)
        %     % 计算年龄分布统计数据

        %     % 获取存活个体的年龄和性别数组
        %     alive_mask = obj.life_statuses > LifeCycleState.Prebirth & obj.life_statuses < LifeCycleState.Dead;
        %     aliveAges = obj.ages(alive_mask);
        %     aliveGenders = obj.genders(alive_mask);

        %     % 计算按年龄分组的个体数量 (仅存活个体)
        %     % 示例年龄分组 (您可以根据需要调整)
        %     age_group_edges = [0, 10, 20, 30, 40, 50, 60, 70, Inf];
        %     ageGroupCounts = histcounts(aliveAges, age_group_edges);
        %     ageGroupLabels = {'0-9', '10-19', '20-29', '30-39', '40-49', '50-59', '60-69', '70+'};
        %      % 过滤掉计数为零的组的标签
        %     if ~isempty(ageGroupCounts)
        %          ageGroupLabels = ageGroupLabels(ageGroupCounts > 0);
        %     else
        %          ageGroupLabels = string.empty(1, 0);
        %     end


        %     % 组织到结构体中
        %     stats = struct(...
        %         'AliveAges', aliveAges, ...
        %         'AliveGenders', aliveGenders, ...
        %         'AgeGroupCounts', ageGroupCounts, ...
        %         'AgeGroupLabels', {ageGroupLabels} ...
        %     );
        % end

        function stats = get.GenerationStats(obj)
            % 计算世代统计数据

            % 过滤出存活个体
            alive_mask = obj.life_statuses > LifeCycleState.Prebirth & obj.life_statuses < LifeCycleState.Dead;
            alive_generations = obj.generations(alive_mask);
            alive_life_statuses = obj.life_statuses(alive_mask);

            uniqueGens = unique(alive_generations);
            % 统计 Premature, Mature, Old 状态
            lifeCycleStatesForGen = [LifeCycleState.Premature, LifeCycleState.Mature, LifeCycleState.Old];
            lifeCycleLabelsForGen = {categories(LifeCycleState.Premature:LifeCycleState.Old)}; % 对应的生命状态标签

            % 计算按世代和生命状态分组的存活个体数量矩阵
            % 行代表世代，列代表生命状态 (Premature, Mature, Old)
            genLifeCycleCountsMatrix = zeros(length(uniqueGens), length(lifeCycleStatesForGen));
            % 计算按世代分组的存活总数向量
            generationTotalCounts = zeros(size(uniqueGens));

            for i = 1:length(uniqueGens)
                currentGen = uniqueGens(i);
                genMask = alive_generations == currentGen;
                genLifeStatuses = alive_life_statuses(genMask);
                generationTotalCounts(i) = genLifeStatuses;

                for j = 1:length(lifeCycleStatesForGen)
                    currentStateEnum = lifeCycleStatesForGen(j);
                    genLifeCycleCountsMatrix(i, j) = nnz(genLifeStatuses == currentStateEnum);
                end
            end

            % 计算按世代分组的相对比例 (基于 GenerationTotalCounts)
            genLifeCycleRatiosMatrix = genLifeCycleCountsMatrix ./ generationTotalCounts';


            % 组织到结构体中
            stats = struct(...
                'UniqueGenerations', uniqueGens, ...
                'GenLifeCycleCountsMatrix', genLifeCycleCountsMatrix, ...
                'GenerationTotalCounts', generationTotalCounts, ...
                'GenLifeCycleRatiosMatrix', genLifeCycleRatiosMatrix, ...
                'LifeCycleLabels', lifeCycleLabelsForGen ...
            );
        end


    %     function metrics_vector = get.GlobalTimelineMetrics(obj)
    %         % 计算当前年份的关键种群指标向量
    %         % 顺序：总个体数，雄性数，雌性数，Premature数，Mature数，Old数，Dead数，
    %         % 当前年份出生数，当前年份死亡数（无法准确计算，留空），出生-死亡净增长（无法准确计算，留空）

    %         % 获取生命周期和性别计数 (从 LifeCycleGenderStats 结构体中获取)
    %         lifeCycleGenderStats = obj.LifeCycleGenderStats;
    %         lifeCycleCounts = lifeCycleGenderStats.LifeCycleCounts; % [Premature, Mature, Old]
    %         genderCounts = lifeCycleGenderStats.GenderCounts;       % [Male, Female]

    %         % 获取总个体数 (已出生)
    %         total_individuals = lifeCycleGenderStats.TotalBorn;

    %         % 获取当前年份出生数
    %         current_year_births = nnz(obj.ages == 0 & obj.birth_years == obj.year);

    %         % 获取总死亡数 (所有已出生并处于 Dead 状态的个体)
    %         total_dead = lifeCycleGenderStats.TotalDead;

    %         % --- 当前年份死亡人数和净增长 ---
    %         % 无法从单个快照准确计算“当前年份死亡人数”。
    %         % 需要比较前后两年的快照，或者在 Individual 类中存储死亡年份/年龄。
    %         % 如果 Population 类在模拟过程中计算了当年死亡人数并传递给 PopulationState 构造函数，
    %         % 则可以在 PopulationState 中存储该值并在此处使用。
    %         % 暂时保留 NaN 占位符。
    %         current_year_deaths = NaN; % 无法从单个快照计算

    %         % 出生 - 死亡 净增长也无法准确计算
    %         net_growth = NaN; % 无法从单个快照计算


    %         % 构建指标向量
    %         metrics_vector = [
    %             double(total_individuals); % 转换为 double 以避免类型不匹配
    %             double(genderCounts(1)); % Male
    %             double(genderCounts(2)); % Female
    %             double(lifeCycleCounts(1)); % Premature
    %             double(lifeCycleCounts(2)); % Mature
    %             double(lifeCycleCounts(3)); % Old
    %             double(lifeCycleCounts(4)); % Dead (Total Dead)
    %             double(current_year_births);
    %             current_year_deaths; % Placeholder for current year deaths (NaN)
    %             net_growth; % Placeholder for net growth (NaN)
    %             ];
    %     end
    % end
    end
end