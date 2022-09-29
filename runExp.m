function runExp(TEST_POINT, MAX_SERVED, NUM_MSLOT, MAX_POWER_DUE_RUE, SEED, scenario)

    for i = 1:length(SEED)
        for j = 1:length(TEST_POINT)
            clearvars -except TEST_POINT MAX_SERVED SEED scenario i j NUM_MSLOT MAX_POWER_DUE_RUE;
            if strcmp(scenario, 'equal')
                equaldivision(round(TEST_POINT(j)*3/4), round(TEST_POINT(j)/4), SEED(i), MAX_POWER_DUE_RUE);
            end
            if strcmp(scenario, 'proposed')
                main(round(TEST_POINT(j)*3/4), round(TEST_POINT(j)/4), SEED(i), MAX_SERVED, NUM_MSLOT, MAX_POWER_DUE_RUE);
            end
        end
    end
end