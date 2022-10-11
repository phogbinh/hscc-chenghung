function runExp(TEST_POINT, MAX_SERVED, NUM_MSLOT, MAX_POWER_DUE_RUE, SEED, scenario)
% TEST_POINT 使用者數量
% MAX_SERVED 一個 RUE 可以服務最多幾個 DUEs（只有學長提出的方法才會用到
% NUM_MSLOT 一個 time slot 要切成幾個 time minislots
% MAX_POWER_DUE_RUE 論文 (C2) 的限制，先 DUE 再 RUE
% SEED 隨機種子
% scenario 使用的方法
% e.g. runExp([4], 2, 2, [2, 2], [2:11], "proposed")
    for i = 1:length(SEED)
        for j = 1:length(TEST_POINT)
            clearvars -except TEST_POINT MAX_SERVED SEED scenario i j NUM_MSLOT MAX_POWER_DUE_RUE;
            if strcmp(scenario, 'equal')
                equaldivision(round(TEST_POINT(j)*3/4), round(TEST_POINT(j)/4), SEED(i), MAX_POWER_DUE_RUE);
            end
            if strcmp(scenario, 'proposed')
                main(round(TEST_POINT(j)*3/4), round(TEST_POINT(j)/4), SEED(i), MAX_SERVED, NUM_MSLOT, MAX_POWER_DUE_RUE);
            end
            if strcmp(scenario, 'exhaustive')
                phogbinh(round(TEST_POINT(j)*3/4), round(TEST_POINT(j)/4), SEED(i), MAX_SERVED, NUM_MSLOT, MAX_POWER_DUE_RUE);
            end
        end
    end
end
