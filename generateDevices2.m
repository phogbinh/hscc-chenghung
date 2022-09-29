function [DUEs, RUEs] = generateDevices2(bound, NUM_DUE, NUM_RUE)
% Generate User Devices and assign their position randomly
    global BS_POSITION;
    global NUM_RSC;
    DUEs = DUE.empty(1, 0); RUEs = RUE.empty(1, 0);
    NUM_UE = NUM_DUE + NUM_RUE;
    lbound = 0; rbound = bound;

    for u = 1:NUM_RUE
        rnums = randi([lbound, rbound], 1, (1 + 3) * 2);
        x_UEs = []; y_UEs = [];
        distance = zeros([1, 4]);
        for i = 1:length(rnums)
            if mod(i, 2) == 1
                x_UEs(end + 1) = rnums(i); % the numbers on odd positions are for X-axis
            else
                y_UEs(end + 1) = rnums(i); % the numbers on even positions are for Y-axis
            end
        end
        for i = 1:4
            distance(i) = sqrt((x_UEs(i)-BS_POSITION.x)^2 + (y_UEs(i)-BS_POSITION.y)^2 + (1-BS_POSITION.z)^2);
            % fprintf('%d, %d: %d\n', x_UEs(i), y_UEs(i), distance(i));
        end
        [~, idx] = min(distance);
        candidate_RUE_x = x_UEs(idx); candidate_RUE_y = y_UEs(idx);
        UE = RUE();
        UE.setPosition(Coordinate(x_UEs(idx), y_UEs(idx), 1));
        UE.setCapacity(0); % set after pre-allocation
        UE.setGrpMembers(DUE.empty(1, 0));
        UE.setPreResource(Resource.empty(1, 0));
        UE.setGrpResource(Resource.empty(1, 0));
        UE.setGrpReq(0);
        RUEs(end + 1) = UE;
        for i = 1:4
            if i == idx
                continue;
            end
            ch_gain_c = chGain(x_UEs(i), y_UEs(i), 1, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            ch_gain_r1 = chGain(x_UEs(i), y_UEs(i), 1, candidate_RUE_x, candidate_RUE_y, 1);
            ch_gain_r2 = chGain(candidate_RUE_x, candidate_RUE_y, 1, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            ch_gain_eq = ch_gain_r1 * ch_gain_r2 / (ch_gain_r1 + ch_gain_r2);
            if ch_gain_eq >= ch_gain_c
                UE = DUE();
                UE.setPosition(Coordinate(x_UEs(i), y_UEs(i), 1));
                UE.setCapacity(0); % set after pre-allocation
                UE.setGrpRUE(RUE());
                UE.setPreResource(Resource.empty(1, 0));
                UE.setGrpResource(Resource.empty(1, 0));
                UE.setGrpState(false);
                DUEs(end + 1) = UE;
            end
        end
        while length(DUEs) < length(RUEs) * 3
            pos_x = randi([lbound, rbound], 1, 1);
            pos_y = randi([lbound, rbound], 1, 1);
            ch_gain_r1 = chGain(candidate_RUE_x, candidate_RUE_y, 1, pos_x, pos_y, 1);
            ch_gain_r2 = chGain(candidate_RUE_x, candidate_RUE_y, 1, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            ch_gain_c = chGain(pos_x, pos_y, 1, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
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
    
    if length(DUEs) > NUM_DUE
        new_DUEs = DUE.empty();
        NUM_TO_RM = length(DUEs) - NUM_DUE;
        to_remove = [];
        for i = 1:NUM_TO_RM
            RUE_id = mod(i, NUM_RUE);
            if RUE_id == 0
                RUE_id = NUM_RUE;
            end
            rm_range = [1 + 3 * (RUE_id - 1): RUE_id * 3];
            for i = 1:length(rm_range)
                if ~ismember(rm_range(i), to_remove)
                    to_remove = [to_remove, rm_range(i)];
                    break;
                end
            end
        end
        for i = 1:length(DUEs)
            if ismember(i, to_remove)
               continue;
            end
            new_DUEs(end + 1) = DUEs(i);
        end
        DUEs = new_DUEs; 
    end
    UEs = [RUEs, DUEs];
    
    % % Numbers of required RBs for every UE, equally share
    % demand_UEs = zeros([1, NUM_UE]);
    % demand_UEs(:) = floor(NUM_RSC / NUM_UE);
    % remaining_rsc = NUM_RSC - floor(NUM_RSC / NUM_UE) * NUM_UE;
    % % randomly distribute the remaining RBs to the UEs
    % if remaining_rsc > 0
    %     r = randperm(NUM_UE, remaining_rsc);
    %     demand_UEs(r) = demand_UEs(r) + 1;
    % end
    avg = ceil(NUM_RSC / NUM_UE);
    while true
        demand_UEs=randi([ceil(avg/2) avg * 2-1], NUM_UE, 1);
        if(sum(demand_UEs) == NUM_RSC)
           break;
        end
    end
    % disp(demand_UEs);

    for i = 1:length(UEs)
        UEs(i).setDemand(demand_UEs(i));
        % if strcmp(class(UEs(i)), 'RUE')
        %     UEs(i).setDemand(demand_UEs(i) - 3*3);
        % elseif strcmp(class(UEs(i)), 'DUE')
        %     UEs(i).setDemand(demand_UEs(i) + 1*3);
        % end
    end

    for i = 1:NUM_DUE
        DUEs(i).setId(i);
    end
    for i = 1:NUM_RUE
        RUEs(i).setId(i);
    end
end