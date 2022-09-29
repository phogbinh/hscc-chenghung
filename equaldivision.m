function equaldivision(NUM_DUE, NUM_RUE, SEED, MAX_POWER_DUE_RUE)
    close all;
    bound = 500;
    global NUM_NUMEROLOGY;
    NUM_NUMEROLOGY = 3;
    global P_MAX;
    global BS_POSITION;
    global NUM_SLOT;
    global SLOT_DURATION;
    global NUM_RSC;
    global shadowing;
    global MAX_POWER;
    NUM_RSC = 34 + 32 + 32;
    NUM_SLOT = 2 * 2^(NUM_NUMEROLOGY - 1);
    P_MAX = 10^(23/10); % mW
    BS_POSITION = Coordinate(250, 250, 30); 
    SLOT_DURATION = 1 / NUM_SLOT;
    MAX_POWER(1) = MAX_POWER_DUE_RUE(1);
    MAX_POWER(2) = MAX_POWER_DUE_RUE(2);

    global testCase;
    testCase = matlab.unittest.TestCase.forInteractiveUse;
    assertGreaterThan(testCase, [NUM_DUE, NUM_RUE] , 0);

    rand('seed', SEED);
    randn('seed', 1);
    shadowing = randn(1);

    % Generate the devices, deciding the RUEs/DUEs and their properties.
    [DUEs, RUEs] = generateDevices2(bound, NUM_DUE, NUM_RUE);
    for i = 1:NUM_DUE
        pos = DUEs(i).getPosition();
        fprintf('DUE %d: %.2f, %.2f, %.2f, demand=%.2f\n',DUEs(i).getId(), pos.x, pos.y, pos.z, DUEs(i).getDemand());
    end
    for i = 1:NUM_RUE
        pos = RUEs(i).getPosition();
        fprintf('RUE %d: %.2f, %.2f, %.2f, demand=%.2f\n',RUEs(i).getId(), pos.x, pos.y, pos.z, RUEs(i).getDemand());
    end
    
    % Initialize the available resources
    % https://www.mathworks.com/matlabcentral/answers/6366-how-to-declare-array-of-variable-size
    NUM_FREQ = zeros(1, NUM_NUMEROLOGY); % number of subbands for numerology i
    NUM_TIME = zeros(1, NUM_NUMEROLOGY); % number of RBs per subband for numerology i
    resc_mat = cell(1, NUM_NUMEROLOGY);
    
    NUM_FREQ(1) = 34;
    NUM_FREQ(2) = 16;
    NUM_FREQ(3) = 8;
    rid = 1;
    for i = 1:NUM_NUMEROLOGY
        NUM_TIME(i) = 2^(i-1);
        nslot = 2*2^(NUM_NUMEROLOGY - i);
        mat = Resource.empty(NUM_TIME(i), 0);
        for ti = 1:NUM_TIME(i)
            slots = [(1 + (ti - 1) * nslot):ti * nslot];
            for fi = 1:NUM_FREQ(i)
                % not sure why the constructor cannot work here, so i remove it
                mat(ti, fi) = Resource();
                mat(ti, fi).init(rid, 0, i - 1, 180000*(2^(i-1)), 1.0 / (2^(i-1)), false, 0);
                mat(ti, fi).setSlot(slots);
                rid = rid + 1;
            end
        end
        resc_mat{i} = mat;
    end

    % 0. Pre- RB Allocation
    [DUEs, RUEs] = Initialize(DUEs, RUEs, resc_mat);
    % for i = 1:NUM_DUE
    %     r = DUEs(i).getPreResource();
    %     for j = 1:length(r)
    %         fprintf('%.2f, %.2f, %.2f, %.2f, %.2f\n', r(j).id, ...
    %                 r(j).numerology, r(j).bandwidth, ...
    %                 r(j).duration, r(j).tx_power);
    %     end
    % end
    
    % every RUE has its own DUE list: RUE1->list1, RUE2->list2, ...
    % https://www.mathworks.com/matlabcentral/answers/368376-object-array-modify-properties-of-a-single-element
    copy_DUEmat = DUE.empty(NUM_RUE, 0);
    for i = 1:NUM_RUE
        for j = 1:NUM_DUE
            copy_DUEmat(i, j) = DUEs(j).copy();
        end
    end

    tic;
    % 1. Greedy for every knapsack
    DUE_user = cell(1, NUM_DUE); % store id of the RUE that relay for DUE i
    [DUE_user{:}] = deal([]);
    profits = zeros([1, NUM_RUE]); % store the total save power for each relay group
    
    for i = 1:NUM_RUE
        [RUEs(i), copy_DUEmat(i, :), profits(i)] = GreedyEqual(RUEs(i), copy_DUEmat(i, :));
        members = RUEs(i).getGrpMembers();
        for j = 1:length(members)
            DUE_user{members(j).getId()}(end + 1) = RUEs(i).getId();
        end
    end

    % 2. Check duplicate DUEs
    dup = true;
    while dup
        for i = 1:NUM_DUE
            if length(DUE_user{i}) <= 1
                fprintf('DUE %d has no duplicate users\n', i);
                continue
            end
            fprintf('%d duplicate users for DUE %d\n', length(DUE_user{i}), i);
            % for j = 1:length(DUE_user{i})
            %     fprintf('%d, ', DUE_user{i}(j));
            % end
            % fprintf('\n');
            copy_RUEs = RUEs.copy();
            copy_DUEmat2 = copy_DUEmat.copy();
            comp = profits;
            bestId = DUE_user{i}(1);
            copy_RUEs(bestId).rmGrpMember(DUEs(i));
            [copy_RUEs(bestId), copy_DUEmat2(bestId, :), comp(bestId)] = GreedyEqual(copy_RUEs(bestId), copy_DUEmat2(bestId, :));
            for j = 2:length(DUE_user{i})
                tmpId = DUE_user{i}(j);
                copy_RUEs(tmpId).rmGrpMember(DUEs(i));
                [copy_RUEs(tmpId), copy_DUEmat2(tmpId, :), comp(tmpId)] = GreedyEqual(copy_RUEs(tmpId), copy_DUEmat2(tmpId, :));
                if profits(tmpId) + comp(bestId) >= profits(bestId) + comp(tmpId)
                    bestId = tmpId;
                end
            end
            fprintf('DUE %d with RUE bestId = %d\n', i, bestId);

            % finally, all RUE in DUE_user{i} should be updated except the bestId
            tmp_DUE_user = DUE_user{i};
            for j = 1:length(tmp_DUE_user)
                tmpId = tmp_DUE_user(j);
                if tmpId == bestId
                    continue;
                end
                [a, b] = ismember(tmpId, DUE_user{i});
                DUE_user{i}(b(a)) = []; %setdiff(DUE_user{i}, RUEs(tmpId));
                RUEs(tmpId) = copy_RUEs(tmpId);
                copy_DUEmat(tmpId, :) = copy_DUEmat2(tmpId, :); % assign the full column
                profits(tmpId) = comp(tmpId);
                members = RUEs(tmpId).getGrpMembers();
                for j = 1:length(members)
                    if ~ismember(tmpId, DUE_user{members(j).getId()})
                        DUE_user{members(j).getId()}(end + 1) = tmpId;
                    end
                end
            end
            fprintf('After: %d duplicate users for DUE %d\n', length(DUE_user{i}), i);
            for j = 1:length(DUE_user{i})
                fprintf('%d, ', DUE_user{i}(j));
            end
            fprintf('\n');
        end
        dup = false;
        for i = 1:length(DUE_user)
            fprintf('After processing: %d duplicate users for DUE %d\n', length(DUE_user{i}), i);
            if length(DUE_user{i}) > 1
                dup = true;
            end
        end
    end
    
    for i = 1:NUM_RUE
        fprintf('RUE %d has %d members\n', RUEs(i).getId(), length(RUEs(i).getGrpMembers()));
        members = RUEs(i).getGrpMembers();
        for j = 1:length(members)
            DUEs(members(j).getId()) = copy_DUEmat(i, members(j).getId());
            res = DUEs(members(j).getId()).getGrpResource();
            for k = 1:length(res)
                fprintf('DUE %d has rsc %d, %dth symbol, power: %.2f\n', members(j).getId(), res(k).id, res(k).sid, full(res(k).tx_power));
            end
        end
        % res = RUEs(i).getGrpResource();
        % for j = 1:length(res)
        %     fprintf('rsc %d, %dth symbol, power: %.2f\n', res(j).id, res(j).sid, res(j).tx_power);
        % end
    end
    % 3. Draw the Graphs / Output Results
    UEs = [RUEs, DUEs];
    tot_e = 0;
    tot_c = 0;
    tot_e_ori = 0;
    tot_c_ori = 0;
    true_e = 0;
    true_e_ori = 0;
    for i = 1:length(UEs)
        if (strcmp(class(UEs(i)), 'DUE') & UEs(i).getGrpState() == false) | (strcmp(class(UEs(i)), 'RUE') & length(UEs(i).getGrpMembers()) == 0)
            tot_e = tot_e + UEs(i).getDirectEnergy();
            tot_c = tot_c + UEs(i).getCapacity();
            tot_e_ori = tot_e_ori + UEs(i).getDirectEnergy();
            tot_c_ori = tot_c_ori + UEs(i).getCapacity();
            true_e = true_e + UEs(i).getDirectEnergyConsumption();
            true_e_ori = true_e_ori + UEs(i).getDirectEnergyConsumption();
            fprintf('no relay, databits: %.5f, req: %.5f\n', UEs(i).getRequirement(), UEs(i).getRequirement());
            fprintf('no relay, real_energy: %.5f, req: %.5f\n', UEs(i).getDirectEnergy(), UEs(i).getDirectEnergy());
        else
            tot_e = tot_e + UEs(i).getTotalEnergy();
            tot_c = tot_c + UEs(i).databits();
            tot_e_ori = tot_e_ori + UEs(i).getDirectEnergy();
            tot_c_ori = tot_c_ori + UEs(i).getCapacity();
            true_e = true_e + UEs(i).getEnergyConsumption();
            true_e_ori = true_e_ori + UEs(i).getDirectEnergyConsumption();
            fprintf('databits: %.5f, req: %.5f\n', UEs(i).databits(), UEs(i).getRequirement());
            fprintf('real_energy: %.5f, req: %.5f\n', UEs(i).getTotalEnergy(), UEs(i).getDirectEnergy());
        end
    end
    RUE_tot_e = 0;
    RUE_tot_e_ori = 0;
    RUE_true_e = 0;
    RUE_true_e_ori = 0;
    in_service = 0;
    for i = 1:NUM_RUE
        RUE_tot_e = RUE_tot_e + RUEs(i).getTotalEnergy();
        RUE_tot_e_ori = RUE_tot_e_ori + RUEs(i).getDirectEnergy();
        RUE_true_e = RUE_true_e + RUEs(i).getEnergyConsumption();
        RUE_true_e_ori = RUE_true_e_ori + RUEs(i).getDirectEnergyConsumption();
        if length(RUEs(i).getGrpMembers()) ~= 0
            in_service = in_service + 1;
        end
    end
    sr = 0;
    sr_ori = 0;
    for i = 1:length(UEs)
        sr = sr + UEs(i).sumRate();
        sr_ori = sr_ori + UEs(i).sumRateNR();
    end
    
    sr_DUE_ori = 0; % sum rate of DUEs without relay
    for i = 1:NUM_DUE
        sr_DUE_ori = sr_DUE_ori + DUEs(i).sumRateNR();
    end
    
    fileName = sprintf('./csv/equal_%dUE_Len%d_Seed-%d.json', length(UEs), 1, SEED);
    fileID = fopen(fileName, 'w');
    s = struct("NUM_UE", length(UEs), "NUM_RUE", NUM_RUE, "connected", in_service, "NUM_DUE", NUM_DUE, "MAX_LEN", 1, "SEED", SEED, ...
               "sys_energy", tot_e, "direct_energy", tot_e_ori, "avg_energy", RUE_tot_e/NUM_RUE, ...
               "direct_avg_energy", RUE_tot_e_ori/NUM_RUE, "EE", tot_c/tot_e, "direct_EE", tot_c_ori/tot_e_ori, ...
               "model_sys_energy", true_e, "direct_model_sys_energy", true_e_ori, "model_avg_energy", RUE_true_e/NUM_RUE, ...
               "direct_model_avg_energy", RUE_true_e_ori/NUM_RUE, "sum_rate", sr, "direct_sum_rate", sr_ori, "direct_avg_rate_DUE", sr_DUE_ori/NUM_DUE, ...
               "DUE_power_limit", MAX_POWER(1), "Mslot", 2, "method", 'equal');
    encodedJSON = jsonencode(s); 
    fprintf(fileID, encodedJSON);

    % fprintf('sum bits: %.5f, w/o relay: %.5f\n', tot_c, tot_c_ori);
    fclose(fileID);
    toc;