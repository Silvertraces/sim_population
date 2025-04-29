classdef PopulationState < handle
    % PopulationState 种群状态类
    % 存储特定时间点的种群个体信息
    
    properties
        % 基本信息
        year uint16                  % 统计年份
        
        % 个体属性数组（非未出生个体）
        all_ids                     % 全局ID数组
        gen_ids                     % 世代ID数组
        ages                        % 年龄数组
        generations                 % 代数数组
        birth_years                 % 出生年份数组
        parent_all_ids              % 亲代全局ID数组 [父亲ID, 母亲ID]
        parent_gen_ids              % 亲代世代ID数组 [父亲ID, 母亲ID]
        parent_gens                 % 亲代世代数数组 [父亲世代, 母亲世代]
        genders                     % 性别数组
        life_statuses               % 生命状态数组
    end
    
    methods
        function obj = PopulationState(year, individuals)
            % 构造函数
            % 输入:
            %   year - 统计年份
            %   individuals - 个体对象数组（所有个体）
            
            % 设置年份
            obj.year = year;
            
            % 排除未出生个体
            life_statuses = [individuals.life_status];
            born_mask = life_statuses > LifeCycleState.Prebirth;
            born_individuals = individuals(born_mask);
            
            % 如果没有已出生个体，则返回空属性
            if isempty(born_individuals)
                return;
            end
            
            % 提取个体属性到数组
            obj.all_ids = [born_individuals.all_id];
            obj.gen_ids = [born_individuals.gen_id];
            obj.ages = [born_individuals.age];
            obj.generations = [born_individuals.generation];
            obj.birth_years = [born_individuals.birth_year];
            obj.genders = [born_individuals.gender];
            obj.life_statuses = [born_individuals.life_status];
            
            % 提取父母ID和世代数
            % 由于这些是二维数组，需要特殊处理，暂时的计划是元胞数组+reshape+cell2mat
            sz_idvdl = size(born_individuals);
            obj.parent_all_ids = cell2mat(reshape({born_individuals.parent_all_ids}, sz_idvdl));
            obj.parent_gen_ids = cell2mat(reshape({born_individuals.parent_gen_ids}, sz_idvdl));
            obj.parent_gens = cell2mat(reshape({born_individuals.parent_gens}, sz_idvdl));
        end
    end
end