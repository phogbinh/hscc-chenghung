function [DUEs, RUEs] = generateDevices(bound, NUM_DUE, NUM_RUE)
% Generate User Devices and assign their position randomly
    global BS_POSITION;
    global NUM_RSC;
    DUEs = DUE.empty(1, 0); RUEs = RUE.empty(1, 0);
    NUM_UE = NUM_DUE + NUM_RUE;
    lbound = 0; rbound = bound;

    x_UEs = []; % candidate position on X-axis
    y_UEs = []; % candiadte position on Y-axis
    rnums = randi([lbound, rbound], 1, (NUM_DUE + NUM_RUE) * 2); % 2 * NUM_UE numbers for a coordinate
    for i = 1:length(rnums)
        if mod(i, 2) == 1
            x_UEs(end + 1) = rnums(i); % the numbers on odd positions are for X-axis
        else
            y_UEs(end + 1) = rnums(i); % the numbers on even positions are for Y-axis
        end
    end

    % Numbers of required RBs for every UE, equally share
    demand_UEs = zeros([NUM_UE, 1]);
    demand_UEs(:) = floor(NUM_RSC / NUM_UE);
    remaining_rsc = NUM_RSC - floor(NUM_RSC / NUM_UE) * NUM_UE;
    % randomly distribute the remaining RBs to the UEs
    if remaining_rsc > 0
        r = randperm(NUM_UE, remaining_rsc);
        demand_UEs(r) = demand_UEs(r) + 1;
    end

    % Classify DUEs and RUEs according to HMS
    for i = 1:NUM_UE
        ch_gain_c = chGain(x_UEs(i), y_UEs(i), 1, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
        isRUE = true;
        for j = 1:NUM_UE
            ch_gain_r1 = chGain(x_UEs(i), y_UEs(i), 1, x_UEs(j), y_UEs(j), 1);
            ch_gain_r2 = chGain(x_UEs(j), y_UEs(j), 1, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            ch_gain_eq = ch_gain_r1 * ch_gain_r2 / (ch_gain_r1 + ch_gain_r2);
            if ch_gain_eq >= ch_gain_c
                UE = DUE();
                UE.setPosition(Coordinate(ceil(x_UEs(i)), ceil(y_UEs(i)), 1));
                UE.setCapacity(0); % set after pre-allocation
                UE.setGrpRUE(RUE());
                UE.setPreResource(Resource.empty(1, 0));
                UE.setGrpResource(Resource.empty(1, 0));
                UE.setGrpState(false);
                DUEs(end + 1) = UE;
                isRUE = false;
                break;
            end
        end
        if isRUE
            UE = RUE();
            UE.setPosition(Coordinate(ceil(x_UEs(i)), ceil(y_UEs(i)), 1));
            UE.setCapacity(0); % set after pre-allocation
            UE.setGrpMembers(DUE.empty());
            UE.setPreResource(Resource.empty(1, 0));
            UE.setGrpResource(Resource.empty(1, 0));
            UE.setGrpReq(0);
            RUEs(end + 1) = UE;
        end
    end
    fprintf('before modification: NUM_RUE = %d, NUM_DUE = %d\n', length(RUEs), length(DUEs));

    % if the number of RUE or DUE is not enough, add/remove UEs
    if length(RUEs) < NUM_RUE
        DUEs = DUEs(1:NUM_DUE); % remove additional DUEs
        while length(RUEs) < NUM_RUE
            % generate a new UE and examine if it can be an RUE
            pos_x = randi([lbound, rbound], 1, 1);
            pos_y = randi([lbound, rbound], 1, 1);
            isRUE = true;
            for i = 1:NUM_DUE
                pos = DUEs(i).getPosition();
                ch_gain_r1 = chGain(pos.x, pos.y, pos.z, pos_x, pos_y, 1);
                ch_gain_r2 = chGain(pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
                ch_gain_c = chGain(pos_x, pos_y, 1, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
                ch_gain_eq = ch_gain_r1 * ch_gain_r2 / (ch_gain_r1 + ch_gain_r2);
                if ch_gain_eq >= ch_gain_c
                    isRUE = false;
                    break;
                end
            end
            if isRUE
                UE = RUE();
                UE.setPosition(Coordinate(pos_x, pos_y, 1));
                UE.setCapacity(0); % set after pre-allocation
                UE.setGrpMembers(DUE.empty());
                UE.setPreResource(Resource.empty(1, 0));
                UE.setGrpResource(Resource.empty(1, 0));
                UE.setGrpReq(0);
                RUEs(end + 1) = UE;
            end
        end
    elseif length(DUEs) < NUM_DUE
        RUEs = RUEs(1:NUM_RUE); % remove additional RUEs
        % remove DUEs that cannot get a relay due to removing additional RUEs
        true_DUE = DUEs.empty(1, 0);
        for i = 1:length(DUEs)
            pos = DUEs(i).getPosition();
            ch_gain_c = chGain(pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            for j = 1:NUM_RUE
                rpos = RUEs(j).getPosition();
                ch_gain_r1 = chGain(pos.x, pos.y, pos.z, rpos.x, rpos.y, rpos.z);
                ch_gain_r2 = chGain(rpos.x, rpos.y, rpos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
                ch_gain_eq = ch_gain_r1 * ch_gain_r2 / (ch_gain_r1 + ch_gain_r2);
                if ch_gain_eq >= ch_gain_c
                    true_DUE(end + 1) = DUEs(i);
                    break;
                end
            end
        end
        DUEs = true_DUE;
        while length(DUEs) < NUM_DUE
            % generate a new UE and examine if it can find an RUE for relaying
            pos_x = randi([lbound, rbound], 1, 1);
            pos_y = randi([lbound, rbound], 1, 1);
            ch_gain_c = chGain(pos_x, pos_y, 1, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            for i = 1:NUM_RUE
                rpos = RUEs(i).getPosition();
                ch_gain_r1 = chGain(pos_x, pos_y, 1, rpos.x, rpos.y, rpos.z);
                ch_gain_r2 = chGain(rpos.x, rpos.y, rpos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
                ch_gain_eq = ch_gain_r1 * ch_gain_r2 / (ch_gain_r1 + ch_gain_r2);
                if ch_gain_eq >= ch_gain_c
                    UE = DUE();
                    UE.setPosition(Coordinate(pos_x, pos_y, 1));
                    UE.setCapacity(0); % set after pre-allocation
                    UE.setGrpRUE(RUE());
                    UE.setPreResource(Resource.empty(1, 0));
                    UE.setGrpResource(Resource.empty(1, 0));
                    UE.setGrpState(false);
                    DUEs(end + 1) = UE;
                end
            end
        end
    end
    
    fprintf('after modification: NUM_RUE = %d, NUM_DUE = %d\n', length(RUEs), length(DUEs));

    UEs = [RUEs, DUEs];
    for i = 1:length(UEs)
        UEs(i).setDemand(demand_UEs(i));
    end

    for i = 1:NUM_DUE
        DUEs(i).setId(i);
    end
    for i = 1:NUM_RUE
        RUEs(i).setId(i);
    end

end