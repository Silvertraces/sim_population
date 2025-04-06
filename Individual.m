classdef Individual < handle
    % Individual 个体类
    % 存储种群模拟中每个个体的属性和方法
    
    properties
        all_id uint16         % 个体全局编号
        gen_id uint16         % 个体世代编号
        age int8 = 0     % 年龄
        generation int8  % 代数
        birth_year uint16 % 出生年份
        parent_all_ids (1, 2) uint32 % 亲代全局编号 [父亲ID, 母亲ID]
        parent_gen_ids (1, 2) uint32 % 亲代世代编号 [父亲ID, 母亲ID]
        parent_gens (1, 2) uint8 % 亲代世代数 [父亲ID, 母亲ID]
        gender categorical % 性别 (male:雄性, female:雌性)
        life_status categorical = "prebirth" % 生命状态
    end
    
    properties (Constant)
        gender_set = ["male", "female"] % 性别选项
        life_status_set = ["prebirth", "premature", "mature", "old", "dead"] % 生命状态选项
    end
    
    methods (Access = protected)
        function catArray = convertToCategorical(~, inputValue, validCategories, isOrdinal)
            % 通用转换方法：将字符串或数值输入转换为分类数组
            % 输入:
            %   inputValue - 原始输入值（字符串、字符数组或分类数组）
            %   validCategories - 允许的类别集合（字符串数组）
            %   isOrdinal - 是否有序（逻辑值）
            % 输出:
            %   catArray - 转换后的分类数组
            
            % 如果输入是字符串/字符数组，转换为分类数组
            if isstring(inputValue) || ischar(inputValue)
                inputValue = categorical(inputValue, validCategories, 'Ordinal', isOrdinal);
            end
            
            % 验证类别合法性
            if ~all(ismember(categories(inputValue), validCategories))
                error('输入值包含非法类别，允许的类别为: %s', strjoin(validCategories, ', '));
            end
            
            % % 验证有序性
            % if isOrdinal && ~isordinal(inputValue)
            %     error('输入值必须是有序分类数组');
            % end
            
            catArray = inputValue;
        end
    end

    methods
        function set.life_status(obj, value)
            % 调用通用转换方法
            validCategories = obj.life_status_set;
            obj.life_status = obj.convertToCategorical(value, validCategories, true);
        end
        
        function set.gender(obj, value)
            % 调用通用转换方法
            validCategories = obj.gender_set;
            obj.gender = obj.convertToCategorical(value, validCategories, false);
        end
        
        function update(obj, current_year, death_probs, repro_range)
            % 更新个体状态
            % 输入:
            %   current_year - 当前年份
            %   death_probs - 死亡概率累积分布数组
            %   repro_range - 繁殖年龄范围 [最小年龄, 最大年龄]
            
            obj.age = current_year - obj.birth_year;
            
            % 使用switch-case更新生命状态
            switch obj.life_status
                case "prebirth"
                    if obj.age >= 0
                        obj.life_status = "premature";
                    end
                case "premature"
                    if obj.age >= repro_range(1)
                        obj.life_status = "mature";
                    end
                case "mature"
                    if obj.age > repro_range(2)
                        obj.life_status = "old";
                    end
                case "old"
                    % 计算在死亡概率数组中的索引
                    death_idx = obj.age - repro_range(2);
                    
                    % 确保索引在有效范围内
                    if death_idx >= 1 && death_idx <= length(death_probs)
                        % 随机决定是否死亡
                        if rand() <= death_probs(death_idx)
                            obj.life_status = "dead";
                        end
                    else
                        % 超过最大年龄，必然死亡
                        obj.life_status = "dead";
                    end
            end
        end
    end
end