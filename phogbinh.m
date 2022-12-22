function phogbinh(NUM_DUE, NUM_RUE, SEED, MAX_SERVED, NUM_MSLOT, MAX_POWER_DUE_RUE)
    global NUM_NUMEROLOGY;
    global P_MAX;
    global BS_POSITION;
    global NUM_SLOT;
    global NUM_RSC;
    global shadowing;
    global MAX_LEN;
    global SLOT_DURATION;
    global NUM_MINI_SLOT;
    global MAX_POWER;
    bound = 500;
    NUM_NUMEROLOGY = 3; % change this to i if tested with resources with only numerology-i
    MAX_LEN = MAX_SERVED;
    NUM_MINI_SLOT = NUM_MSLOT;
    NUM_RSC = 34 + 32 + 32; % change this for different RB settings
    NUM_SLOT = NUM_MINI_SLOT * 2^(NUM_NUMEROLOGY - 1);
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
    
    % change the following 3 lines if a different setting is required
    NUM_FREQ(1) = 34;
    NUM_FREQ(2) = 16;
    NUM_FREQ(3) = 8;
    
    rid = 1;
    for i = 1:NUM_NUMEROLOGY
        NUM_TIME(i) = 2^(i-1);
        nslot = NUM_MINI_SLOT*2^(NUM_NUMEROLOGY - i);
        mat = Resource.empty(NUM_TIME(i), 0);
        for ti = 1:NUM_TIME(i)
            slots = [(1 + (ti - 1) * nslot):ti * nslot];
            for fi = 1:NUM_FREQ(i)
                % not sure why the constructor cannot work here, so I apply set functions instead
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
    
    tic;
    % 1. Greedy for every knapsack
    max_profit = -1;
    res_RUEs = RUEs.copy();
    copy_DUEmat = DUE.empty(NUM_DUE, 0);
    DUE_user = cell(1, NUM_DUE); % store id of the RUE that serves DUE i
    combinations = get_combinations(NUM_RUE, NUM_DUE);
    for mli = 1:size(combinations, 1)
        cur_combination = combinations(mli, :);
        if ~is_feasible(cur_combination, NUM_RUE)
            continue;
        end
        cur_RUEs = RUEs.copy();
        % every RUE has its own DUE list: RUE1->list1, RUE2->list2, ...
        % https://www.mathworks.com/matlabcentral/answers/368376-object-array-modify-properties-of-a-single-element
        cur_DUEmat = DUE.empty(NUM_RUE, 0);
        for rue_mli = 1:NUM_RUE
            for due_mli = 1:NUM_DUE
                cur_DUEmat(rue_mli, due_mli) = DUEs(due_mli).copy();
            end
        end
        cur_DUE_user = cell(1, NUM_DUE);
        [cur_DUE_user{:}] = deal([]);
        cur_profit = 0;
        for rue_mli = 1:NUM_RUE
            [cur_RUEs(rue_mli), cur_DUEmat(rue_mli, :), profit] = get_profit(cur_RUEs(rue_mli), get_relay_DUEs(rue_mli, cur_DUEmat(rue_mli, :), cur_combination), cur_DUEmat(rue_mli, :));
            members = cur_RUEs(rue_mli).getGrpMembers();
            for j = 1:length(members)
                cur_DUE_user{members(j).getId()}(end + 1) = cur_RUEs(rue_mli).getId();
            end
            if length(members) == 0
              fprintf('no relaying members\n')
              profit = 0;
              cur_RUEs(rue_mli).clearGrpResource();
              rbs = cur_RUEs(rue_mli).getPreResource();
              for i = 1:length(rbs)
                  nslot = length(rbs(i).tslot) / NUM_MINI_SLOT;
                  for idx_symbol = 1:NUM_MINI_SLOT
                      r = Resource();
                      slots = [(rbs(i).tslot(1) + (idx_symbol - 1) * nslot):(rbs(i).tslot(1) + idx_symbol * nslot - 1)];
                      r.init(rbs(i).id, idx_symbol, ... 
                          rbs(i).numerology, ...
                          rbs(i).bandwidth, ...
                          rbs(i).duration/NUM_MINI_SLOT, ...
                          true, rbs(i).tx_power);
                      r.setSlot(slots);
                      cur_RUEs(rue_mli).addGrpResource(r);
                  end
              end
            end
            cur_profit = cur_profit + profit;
        end
        if cur_profit > max_profit
            res_RUEs = cur_RUEs;
            copy_DUEmat = cur_DUEmat;
            DUE_user = cur_DUE_user;
            max_profit = cur_profit;
        end
    end
    RUEs = res_RUEs;
    fprintf("exhaustive profit: %.2f\n", max_profit)
    assert(max_profit >= 0);

    % 2. Check duplicate DUEs
    dup = true;
    while dup
        for i = 1:NUM_DUE
            if length(DUE_user{i}) <= 1
                fprintf('DUE %d has no duplicate users\n', i);
                continue
            end
            fprintf('%d duplicate users for DUE %d\n', length(DUE_user{i}), i);
            copy_RUEs = RUEs.copy();
            copy_DUEmat2 = copy_DUEmat.copy();
            comp = profits; % temp profits for RUE without DUEs(i)
            bestId = DUE_user{i}(1);
            copy_RUEs(bestId).rmGrpMember(DUEs(i)); % removed from grpMembers but GrpState is not modified, so it will not be used.
            [copy_RUEs(bestId), copy_DUEmat2(bestId, :), comp(bestId)] = Exhaustive(copy_RUEs(bestId), copy_DUEmat2(bestId, :));
            for j = 2:length(DUE_user{i})
                tmpId = DUE_user{i}(j);
                copy_RUEs(tmpId).rmGrpMember(DUEs(i));
                [copy_RUEs(tmpId), copy_DUEmat2(tmpId, :), comp(tmpId)] = Exhaustive(copy_RUEs(tmpId), copy_DUEmat2(tmpId, :));
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
                DUE_user{i}(b(a)) = []; %setdiff(DUE_user{i}, RUEs(tmpId)); remove non-selected RUE from DUE_user{i}
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

    % Assign updated DUEs according to the GrpMembers of each RUE
    for i = 1:NUM_RUE
        fprintf('RUE %d has %d members\n', RUEs(i).getId(), length(RUEs(i).getGrpMembers()));
        members = RUEs(i).getGrpMembers();
        for j = 1:length(members)
            DUEs(members(j).getId()) = copy_DUEmat(i, members(j).getId());
            res = DUEs(members(j).getId()).getGrpResource();
            for k = 1:length(res)
                fprintf('DUE %d has rsc %d, %dth mini-slot, power: %.2f\n', members(j).getId(), res(k).id, res(k).sid, full(res(k).tx_power));
            end
        end
    end
    elapsed = toc;

    % 3. Draw the Graphs / Output Results
    UEs = [RUEs, DUEs];
    tot_e = 0; % total energy
    tot_c = 0; % total transmitting bits
    tot_e_ori = 0; % total energy without relay
    tot_c_ori = 0; % total transmitting bits without relay
    true_e = 0; % total energy by LTE power model
    true_e_ori = 0; % total energy by LTE power model without relay
    for i = 1:length(UEs)
        fprintf('%s%d:\n', class(UEs(i)), UEs(i).getId());
        if (strcmp(class(UEs(i)), 'DUE') & UEs(i).getGrpState() == false) | (strcmp(class(UEs(i)), 'RUE') & length(UEs(i).getGrpMembers()) == 0)
            tot_e = tot_e + UEs(i).getDirectEnergy();
            tot_c = tot_c + UEs(i).getCapacity();
            tot_e_ori = tot_e_ori + UEs(i).getDirectEnergy();
            tot_c_ori = tot_c_ori + UEs(i).getCapacity();
            true_e = true_e + UEs(i).getDirectEnergyConsumption();
            true_e_ori = true_e_ori + UEs(i).getDirectEnergyConsumption();
            fprintf('no relay, databits: %.5f, req: %.5f\n', UEs(i).getRequirement(), UEs(i).getRequirement());
            % fprintf('no relay, data rate: %.5f, req: %.5f\n', UEs(i).sumRateNR(), UEs(i).sumRateNR());
            fprintf('no relay, real_energy: %.5f, req: %.5f\n', UEs(i).getDirectEnergy(), UEs(i).getDirectEnergy());
        else
            tot_e = tot_e + UEs(i).getTotalEnergy();
            tot_c = tot_c + UEs(i).databits();
            tot_e_ori = tot_e_ori + UEs(i).getDirectEnergy();
            tot_c_ori = tot_c_ori + UEs(i).getCapacity();
            true_e = true_e + UEs(i).getEnergyConsumption();
            true_e_ori = true_e_ori + UEs(i).getDirectEnergyConsumption();
            fprintf('databits: %.5f, req: %.5f\n', UEs(i).databits(), UEs(i).getRequirement());
            % fprintf('data rate: %.5f, req: %.5f\n', UEs(i).sumRate(), UEs(i).sumRateNR());
            fprintf('real_energy: %.5f, req: %.5f\n', UEs(i).getTotalEnergy(), UEs(i).getDirectEnergy());
        end
        fprintf('-------');
    end

    RUE_tot_e = 0; % total energy of RUEs 
    RUE_tot_e_ori = 0; % total energy of RUEs without relay
    RUE_true_e = 0; % total energy of RUEs by LTE power model
    RUE_true_e_ori = 0; % total energy of RUEs by LTE power model without relay
    in_service = 0; % number of RUEs that relay for DUEs
    for i = 1:NUM_RUE
        RUE_tot_e = RUE_tot_e + RUEs(i).getTotalEnergy();
        RUE_tot_e_ori = RUE_tot_e_ori + RUEs(i).getDirectEnergy();
        RUE_true_e = RUE_true_e + RUEs(i).getEnergyConsumption();
        RUE_true_e_ori = RUE_true_e_ori + RUEs(i).getDirectEnergyConsumption();
        if length(RUEs(i).getGrpMembers()) ~= 0
            in_service = in_service + 1;
        end
    end

    sr = 0; % sum data rate
    sr_ori = 0; % sum data rate without relay
    for i = 1:length(UEs)
        sr = sr + UEs(i).sumRate();
        sr_ori = sr_ori + UEs(i).sumRateNR();
    end

    sr_DUE_ori = 0; % sum rate of DUEs without relay
    for i = 1:NUM_DUE
        sr_DUE_ori = sr_DUE_ori + DUEs(i).sumRateNR();
    end

    fileName = sprintf('./csv/exhaustive_%dUE_Len%d_Seed-%d_Mslot-%d.json', length(UEs), MAX_LEN, SEED, NUM_MINI_SLOT);
    fileID = fopen(fileName, 'w');
    method = sprintf('exhaustive-%d', MAX_LEN);
    s = struct("NUM_UE", length(UEs), "NUM_RUE", NUM_RUE, "connected", in_service, "NUM_DUE", NUM_DUE, "MAX_LEN", MAX_LEN, "SEED", SEED, ...
               "sys_energy", tot_e, "direct_energy", tot_e_ori, "avg_energy", RUE_tot_e/NUM_RUE, ...
               "direct_avg_energy", RUE_tot_e_ori/NUM_RUE, "EE", tot_c/tot_e, "direct_EE", tot_c_ori/tot_e_ori, ...
               "model_sys_energy", true_e, "direct_model_sys_energy", true_e_ori, "model_avg_energy", RUE_true_e/NUM_RUE, ...
               "direct_model_avg_energy", RUE_true_e_ori/NUM_RUE, "sum_rate", sr, "direct_sum_rate", sr_ori, "direct_avg_rate_DUE", sr_DUE_ori/NUM_DUE, ...
               "DUE_power_limit", MAX_POWER(1), "Mslot", NUM_MINI_SLOT, "method", method, "time", elapsed);
    encodedJSON = jsonencode(s); 
    fprintf(fileID, encodedJSON);

    % fprintf('sum bits: %.5f, w/o relay: %.5f\n', tot_c, tot_c_ori);
    fclose(fileID);
