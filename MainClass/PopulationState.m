classdef PopulationState < handle
    % PopulationState 种群状态类
    % 存储特定时间点的种群个体信息和统计数据
    % 包含用于可视化展板的依赖属性，统计数据按结构体组织
    
    properties
        population Population
    end

    properties (Dependent)
        % 基本信息
        year int32                     % 统计年份
        currentYearDeathsCount int32   % 当年死亡个体数
        
        
        born_individuals Individual      % 个体属性数组（仅已出生个体）
        
        all_ids         int32          % 全局ID数组
        gen_ids         int32          % 世代ID数组
        ages            int32            % 年龄数组，prebirth阶段可为负数
        generations     int32           % 代数数组
        birth_years     int32          % 出生年份数组
        genders         categorical     % 性别数组
        life_statuses   LifeCycleState  % 生命状态数组
        % N*2 矩阵，每行表示一个个体的父母信息
        parent_all_ids  int32          % 亲代全局ID数组 [父亲ID, 母亲ID]
        parent_gen_ids  int32          % 亲代世代ID数组 [父亲ID, 母亲ID]
        parent_gens     int32           % 亲代世代数数组 [父亲世代, 母亲世代]

        % --- 依赖属性用于可视化统计，按结构体组织 ---
        % 生命周期和性别统计数据 (用于条形图)
        LifeCycleGenderStats struct
        
        % % 世代统计数据 (用于世代条形图)
        % GenerationStats struct

        % % 年龄分布统计数据 (用于饼图、甜甜圈图、直方图、KDE、小提琴图)
        % AgeDistributionStats struct
        
        % % 全局时间线图所需指标 (向量)
        % GlobalTimelineMetrics double
    end
    
    methods
        function obj = PopulationState(population)
            % 构造函数
            % 输入:
            %   population: 种群对象
            obj.population = population;

            lifeCycleGenderStats = obj.LifeCycleGenderStats; % Access dependent property
            % for fieldName = fieldnames(lifeCycleGenderStats)'
            %     disp(fieldName)
            %     disp(size(lifeCycleGenderStats.(char(fieldName))))
            % end
            stateReport = table(obj.year, ...
                lifeCycleGenderStats.TotalBorn, ...
                lifeCycleGenderStats.TotalAlive, ...
                lifeCycleGenderStats.CurrentYearBirthsCount, ...
                obj.currentYearDeathsCount, ...
                lifeCycleGenderStats.NetGrowth, ...
                {lifeCycleGenderStats.LifeCycleCounts}, ...
                lifeCycleGenderStats.LifeCycleLabels, ...
                lifeCycleGenderStats.GenderCounts, ...
                lifeCycleGenderStats.GenderLabels, ...
                'VariableNames', {
                    '年份', ...
                    '总出生数', ...
                    '存活数', ...
                    '当年出生数', ...
                    '当年死亡数', ...
                    '净增长', ...
                    '生命周期数量', ...
                    '生命周期标签', ...
                    '性别数量', ...
                    '性别标签', ...
                } ...
            );

            fprintf('--- 种群状态报告 (年份 %d) ---\n', obj.year);
            disp(stateReport);
            fprintf('-----------------------------------------\n');

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
            % 计算按性别分组的个体数量 (仅存活个体)
            % 假设 Individual.gender_set 已经定义
            genderCounts = [
                nnz(obj.genders == categorical("male") & maskAlive), ...
                nnz(obj.genders == categorical("female") & maskAlive) ...
                ];

            % 计算已出生个体总数 (生命状态 > Prebirth)
            totalBorn = length(obj.all_ids);

            % 计算存活个体总数 (生命状态 > Prebirth 且 < Dead)
            totalAlive = nnz(maskAlive);

            % 计算相对比例 (基于 TotalAlive)
            if totalAlive > 0
                lifeCycleRatios = lifeCycleCounts / totalAlive;
                genderRatios = genderCounts / totalAlive;
            else
                lifeCycleRatios = zeros(size(lifeCycleCounts));
                genderRatios = zeros(size(genderCounts));
            end

            % 获取当前年份出生数
            currentYearBirthsCount = nnz(obj.ages == 0 & obj.birth_years == obj.year);

            % 净增长 = 出生 - 死亡 (使用构造函数传入的当年死亡数)
            netGrowth = double(currentYearBirthsCount) - double(obj.currentYearDeathsCount);

            lifeCycleLabels = obj.life_statuses.toCategoricalFromInstance();

            % 组织到结构体中
            stats = struct(...
                'LifeCycleCounts', lifeCycleCounts, ...
                'GenderCounts', genderCounts, ...
                'TotalBorn', totalBorn, ...
                'TotalAlive', totalAlive, ...
                'LifeCycleRatios', lifeCycleRatios, ... % [Premature, Mature, Old] Ratios based on TotalAlive
                'GenderRatios', genderRatios, ... % [Male, Female] Ratios based on TotalAlive
                'CurrentYearBirthsCount', currentYearBirthsCount, ...
                'CurrentYearDeathsCount', obj.currentYearDeathsCount, ...
                'NetGrowth', netGrowth, ...
                'LifeCycleLabels', lifeCycleLabels, ... % 对应的生命状态标签
                'GenderLabels', {categories(obj.genders, "OutputType", "char")'} ... % 对应的性别标签
            );
        end

        % --- 其他依赖属性的 Get Methods ---
        function year = get.year(obj)
            year = obj.population.current_year;
        end
        function deathcount = get.currentYearDeathsCount(obj)
            deathcount = obj.population.currentYearDeathsCount;
        end
        function born_individuals = get.born_individuals(obj)
            % 提取已出生个体
            life_status = [obj.population.individuals.life_statuses];
            born_mask = life_status > LifeCycleState.Prebirth;
            born_individuals = obj.population.individuals(born_mask);
        end
        
        function all_ids = get.all_ids(obj)
            all_ids = [obj.born_individuals.all_ids];
        end
        function gen_ids = get.gen_ids(obj)
            gen_ids = [obj.born_individuals.gen_ids];
        end
        function ages = get.ages(obj)
            ages = [obj.born_individuals.ages];
        end
        function generations = get.generations(obj)
            generations = [obj.born_individuals.generations];
        end
        function birth_years = get.birth_years(obj)
            birth_years = [obj.born_individuals.birth_years];
        end
        function genders = get.genders(obj)
            genders = [obj.born_individuals.genders];
        end
        function life_statuses = get.life_statuses(obj)
            life_statuses = [obj.born_individuals.life_statuses];
        end
        % 提取父母ID和世代数
        % 由于这些是二维数组，需要特殊处理
        % 使用 cell2mat 和 reshape 提取 Nx2 矩阵
        function parent_all_ids = get.parent_all_ids(obj)
            sz_idvdl = size(obj.born_individuals);
            parent_all_ids = cell2mat(reshape({obj.born_individuals.parent_all_ids}, sz_idvdl));
        end
        function parent_gen_ids = get.parent_gen_ids(obj)
            sz_idvdl = size(obj.born_individuals);
            parent_gen_ids = cell2mat(reshape({obj.born_individuals.parent_gen_ids}, sz_idvdl));
        end
        function parent_gens = get.parent_gens(obj)
            sz_idvdl = size(obj.born_individuals);
            parent_gens = cell2mat(reshape({obj.born_individuals.parent_gens}, sz_idvdl));
        end
    end
end