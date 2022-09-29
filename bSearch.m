function [status, alloc_RUE, alloc_DUEs, profit, weight] = bSearch(RUE, DUE)
% The function is responsible for finding the best division using binary search and peack finding
% This method numbers all available symbols and divide them by 'rbound', the resources with number
% rbound to the last one will be allocated to the RUE, while the remaining is belong to all DUEs
% in the group.
% @status(string): Infeasible if there is no solution for this RUE-DUE coalition, Solved otherwise
% @alloc_RUE: an RUE object, which is filled with its grpMember and grpResource, in the case that
%             this DUE joins the RUE's group
% @alloc_DUEs: A DUE object array, including the DUEs that are in the RUE's group, while their 
%              grp Information are filled.
% @profit(double): the total power this relay group can save
% @weight(double): the reciprocal of the total power the RUE can save by serving its relay group.
% @RUE: An RUE object that may has been filled with grpMembers and grpResource in previous rounds
% @DUE: An DUE object that will try to join the relay group in this iteration.

    global NUM_SLOT;
    global NUM_MINI_SLOT;
    % MIN_NUMEROLOGY = +inf;
    rsc_tslot = cell(1, NUM_SLOT); % for classifying the resources according to their time slots
    resources = Resource.empty(1, 0); % the available resources in this group

    status = 'Infeasible';
    alloc_RUE = RUE;
    alloc_DUEs = DUE.empty(1, 0);
    profit = 0;
    weight = 1;
    rx_energy = 0;

    % Generate the group
    group = UE.empty(1, 0);
    copy_RUE = RUE.copy();
    copy_RUE.clearGrpResource();
    if length(DUE) == 1
        copy_DUE = DUE.copy();
        copy_DUE.clearGrpResource();
        copy_RUE.addtoGroup(copy_DUE);
    end

    group(1) = copy_RUE;
    members = copy_RUE.getGrpMembers();
    for i = 1:length(members)
        members(i).clearGrpResource();
        group(i + 1) = members(i);
    end
    fprintf('number of members in grp: %d\n', length(group));

    % generate the symbols
    for i = 1:length(group)
        rbs = group(i).getPreResource();
        for k = 1:length(rbs)
            nslot = length(rbs(k).tslot) / NUM_MINI_SLOT;
            for idx_symbol = 1:NUM_MINI_SLOT
                r = Resource();
                slots = [(rbs(k).tslot(1) + (idx_symbol - 1) * nslot):(rbs(k).tslot(1) + idx_symbol * nslot - 1)];
                r.init(rbs(k).id, idx_symbol, ... 
                    rbs(k).numerology, ...
                    rbs(k).bandwidth, ...
                    rbs(k).duration/NUM_MINI_SLOT, ...
                    true, 0);
                r.setSlot(slots);
                resources(end + 1) = r;
            end
        end
    end

    % classify the symbols according to their slots
    for t = 1:NUM_SLOT
        arr_ts = Resource.empty(1, 0);
        for k = 1:length(resources)
            if resources(k).tslot(end) == t
                arr_ts(end + 1) = resources(k);
            end 
        end
        rsc_tslot{t} = arr_ts;
        % fprintf('%d\n', length(rsc_tslot{t}));
    end

    % sort each slot by symbols' numerology
    % https://stackoverflow.com/questions/25047590/sorting-array-of-objects-by-property-in-matlab
    for t = 1:NUM_SLOT
        [~, idx] = sort([rsc_tslot{t}.numerology], 'descend');
        rsc_tslot{t} = rsc_tslot{t}(idx);
    end

    % Number the symbols
    resources = Resource.empty(1, 0);
    for t = 1:NUM_SLOT
        for i = 1:length(rsc_tslot{t})
            resources(end + 1) = rsc_tslot{t}(i);
        end
    end

    f_lb = 1; % the point that ensures enough mini-slots for DUE set
    f_rb = length(resources); % the point that ensures enough mini-slots for RUE
    best = struct('num', 0, 'profit', 0, 'weight', 1, 'Ralloc', RUE(), 'Dalloc', DUE.empty(1, 0), 'status', 'Infeasible');

    % 1. binary search to find just sufficient mini-slots for RUE
    lbound = 1;
    rbound = length(resources);
    checked_num = [];
    last_profit = 0;    % for comparing in the second stage
    mid = floor((lbound + rbound)/2);

    while true
        if ismember(mid, checked_num)
            break;
        end
        checked_num(end + 1) = mid;

        copy_RUE = group(1).copy();
        copy_DUEs = group(2:end).copy();
        DUE_rsc = resources(1:mid);
        DUE_tslot = []; % the time-slots occupied by the mini-slots used by DUEs
        RUE_rsc = resources(mid + 1: length(resources));

        fprintf('---------------------------\n');
        % only perfrom allocation when the available mini-slots is more than the number of DUEs
        if length(copy_DUEs) <= length(DUE_rsc)
            [res_DUEs, psave_DUEs, res_s_DUEs, res_p_DUEs, rx_energy, remaining_rsc, used_rsc] = SCA(DUE_rsc, copy_DUEs, copy_RUE);
        else
            res_DUEs = 'Infeasible';
            psave_DUEs = 0;
            res_s_DUEs = [];
            res_p_DUEs = [];
            rx_energy = 0;
            remaining_rsc = DUE_rsc;
            used_rsc = Resource.empty(1, 0);
        end
        fprintf('DUE %d: %s with %d mini-slot, where %d slots are used\n', copy_DUEs.getId(), res_DUEs, length(DUE_rsc), length(used_rsc));

        % get the time slots occupied by DUEs' resources
        for k = 1:length(DUE_rsc)
            for t = 1:length(DUE_rsc(k).tslot)
                if ~ismember(DUE_rsc(k).tslot(t), DUE_tslot)
                    DUE_tslot(end + 1) = DUE_rsc(k).tslot(t);
                end
            end
        end

        % the resources that are assigned to RUE
        % RUE_rsc = [RUE_rsc, remaining_rsc]; % the available resources for RUE
        type1_rsc = Resource.empty(1, 0); % non-overlapped
        type2_rsc = Resource.empty(1, 0); % overlapped or preceding

        % Classify type-1 and type-2 resources
        if length(DUE_tslot) ~= 0
            for k = 1:length(RUE_rsc)
                tslot = RUE_rsc(k).tslot;
                overlapped = false;
                for t = 1:length(tslot)
                    if ismember(tslot(t), DUE_tslot)
                        overlapped = true;
                        break;
                    end
                end
                if overlapped == true
                    type2_rsc(end + 1) = RUE_rsc(k);
                else
                    if tslot(1) > max(DUE_tslot)
                        type1_rsc(end + 1) = RUE_rsc(k);
                    else
                        type2_rsc(end + 1) = RUE_rsc(k);
                    end
                end
            end
        else
            % if DUE set's allocation is infeasible, then all mini-slots are type-1 resources and allocated to RUE
            type1_rsc = resources;
        end

        % only perform when there is type-1 resource, DUE_tslot is the receiving time-slots
        if length(type1_rsc) > 0
            [res_RUE, psave_RUE, res_p_RUE, res_rp] = SCA_RUE(type1_rsc, copy_RUE, rx_energy, type2_rsc, DUE_tslot);
        else
            res_RUE = 'Infeasible';
            psave_RUE = 0;
            res_p_RUE = [];
            res_rp = [];
        end
        fprintf('RUE %d: %s with %d type-1 mini-slot and %d type-2 mini-slots\n', copy_RUE.getId(), res_RUE, length(type1_rsc), length(type2_rsc));

        if strcmp(res_RUE, 'Solved') & strcmp(res_DUEs, 'Solved')
            % fprintf('Solution Found\n');
            last_profit = psave_DUEs + psave_RUE;
            f_rb = mid;
            if psave_DUEs + psave_RUE >= best.profit
                best.profit = psave_DUEs + psave_RUE;
                best.weight = 1/psave_RUE;
                best.num = mid;
                best.status = 'Solved';

                copy_RUE.clearGrpResource();
                for u = 1:length(copy_DUEs)
                    copy_DUEs(u).clearGrpResource();
                end

                for i = 1:length(type1_rsc)
                    type1_rsc(i).tx_power = res_p_RUE(i);
                    copy_RUE.addGrpResource(type1_rsc(i)); 
                end

                for i = 1:length(type2_rsc)
                    type2_rsc(i).tx_power = res_rp(i);
                    copy_RUE.addGrpResource(type2_rsc(i));
                end

                for u = 1:length(copy_DUEs)
                    for k = 1:length(DUE_rsc)
                        if round(res_s_DUEs(k, u)) == 1
                            DUE_rsc(k).tx_power = res_p_DUEs(k, u);
                            copy_DUEs(u).addGrpResource(DUE_rsc(k));
                        end
                    end
                end
                copy_RUE.setGrpMembers(copy_DUEs);
                best.Ralloc = copy_RUE;
                best.Dalloc = copy_DUEs;
            end
        end

        if strcmp(res_RUE, 'Infeasible') & strcmp(res_DUEs, 'Solved')
            % fprintf('move to left\n');
            rbound = mid;
            mid = floor((lbound + rbound) / 2);
        elseif strcmp(res_RUE, 'Infeasible') & strcmp(res_DUEs, 'Infeasible')
            break;
        else
            % fprintf('move to right, now: %d, next: %d\n', mid, ceil((mid + rbound) / 2));
            lbound = mid;
            mid = ceil((lbound + rbound) / 2);
        end
        % guarantee at least one mini-slot for each
        mid = min(length(resources) - 1, mid);
        mid = max(1, mid);
    end
    
    if ~strcmp(best.status, 'Solved')
        % fprintf('no solution, return from bSearch\n');
        return;
    end

    % 2. binary search to find just sufficient mini-slots for DUE set
    lbound = 1;
    rbound = f_rb;
    checked_num = [];
    last_profit = 0; % for comparing in the second stage
    mid = floor((lbound + rbound)/2);
 
    while true
        if ismember(mid, checked_num)
            break;
        end
        checked_num(end + 1) = mid;
 
        copy_RUE = group(1).copy();
        copy_DUEs = group(2:end).copy();
        DUE_rsc = resources(1:mid);
        DUE_tslot = []; % the time-slots occupied by the mini-slots used by DUEs
        RUE_rsc = resources(mid + 1: length(resources));
 
        fprintf('---------------------------\n');
        % only perfrom allocation when the available mini-slots is more than the number of DUEs
        if length(copy_DUEs) <= length(DUE_rsc)
            [res_DUEs, psave_DUEs, res_s_DUEs, res_p_DUEs, rx_energy, remaining_rsc, used_rsc] = SCA(DUE_rsc, copy_DUEs, copy_RUE);
        else
            res_DUEs = 'Infeasible';
            psave_DUEs = 0;
            res_s_DUEs = [];
            res_p_DUEs = [];
            rx_energy = 0;
            remaining_rsc = DUE_rsc;
            used_rsc = Resource.empty(1, 0);
        end
        fprintf('b2, DUE %d: %s with %d mini-slot, where %d slots are used\n', copy_DUEs.getId(), res_DUEs, length(DUE_rsc), length(used_rsc));
 
        % get the time slots occupied by DUEs' resources
        for k = 1:length(DUE_rsc)
            for t = 1:length(DUE_rsc(k).tslot)
                if ~ismember(DUE_rsc(k).tslot(t), DUE_tslot)
                    DUE_tslot(end + 1) = DUE_rsc(k).tslot(t);
                end
            end
        end
 
        % the resources that are assigned to RUE
        % RUE_rsc = [RUE_rsc, remaining_rsc]; % the available resources for RUE
        type1_rsc = Resource.empty(1, 0); % non-overlapped
        type2_rsc = Resource.empty(1, 0); % overlapped or preceding
 
        % Classify type-1 and type-2 resources
        if length(DUE_tslot) ~= 0
            for k = 1:length(RUE_rsc)
                tslot = RUE_rsc(k).tslot;
                overlapped = false;
                for t = 1:length(tslot)
                    if ismember(tslot(t), DUE_tslot)
                        overlapped = true;
                        break;
                    end
                end
                if overlapped == true
                    type2_rsc(end + 1) = RUE_rsc(k);
                else
                    if tslot(1) > max(DUE_tslot)
                        type1_rsc(end + 1) = RUE_rsc(k);
                    else
                        type2_rsc(end + 1) = RUE_rsc(k);
                    end
                end
            end
        else
            % if DUE set's allocation is infeasible, then all mini-slots are type-1 resources and allocated to RUE
            type1_rsc = resources;
        end
 
        % only perform when there is type-1 resource, DUE_tslot is the receiving time-slots
        if length(type1_rsc) > 0
            [res_RUE, psave_RUE, res_p_RUE, res_rp] = SCA_RUE(type1_rsc, copy_RUE, rx_energy, type2_rsc, DUE_tslot);
        else
            res_RUE = 'Infeasible';
            psave_RUE = 0;
            res_p_RUE = [];
            res_rp = [];
        end
        fprintf('b2, RUE %d: %s with %d type-1 mini-slot and %d type-2 mini-slots\n', copy_RUE.getId(), res_RUE, length(type1_rsc), length(type2_rsc));
 
        if strcmp(res_RUE, 'Solved') & strcmp(res_DUEs, 'Solved')
            % fprintf('Solution Found\n');
            last_profit = psave_DUEs + psave_RUE;
            f_lb = mid;
            if psave_DUEs + psave_RUE >= best.profit
                best.profit = psave_DUEs + psave_RUE;
                best.weight = 1/psave_RUE;
                best.num = mid;
                best.status = 'Solved';
 
                copy_RUE.clearGrpResource();
                for u = 1:length(copy_DUEs)
                    copy_DUEs(u).clearGrpResource();
                end
 
                for i = 1:length(type1_rsc)
                    type1_rsc(i).tx_power = res_p_RUE(i);
                    copy_RUE.addGrpResource(type1_rsc(i)); 
                end
 
                for i = 1:length(type2_rsc)
                    type2_rsc(i).tx_power = res_rp(i);
                    copy_RUE.addGrpResource(type2_rsc(i));
                end
 
                for u = 1:length(copy_DUEs)
                    for k = 1:length(DUE_rsc)
                        if round(res_s_DUEs(k, u)) == 1
                            DUE_rsc(k).tx_power = res_p_DUEs(k, u);
                            copy_DUEs(u).addGrpResource(DUE_rsc(k));
                        end
                    end
                end
                copy_RUE.setGrpMembers(copy_DUEs);
                best.Ralloc = copy_RUE;
                best.Dalloc = copy_DUEs;
            end
        end
 
        if strcmp(res_DUEs, 'Infeasible') & strcmp(res_RUE, 'Solved')
            % fprintf('move to right\n');
            lbound = mid;
            mid = ceil((lbound + rbound) / 2);
        elseif strcmp(res_RUE, 'Infeasible') & strcmp(res_DUEs, 'Infeasible')
            break;
        else
            % fprintf('move to left, now: %d, next: %d\n', mid, ceil((mid + rbound) / 2));
            rbound = mid;
            mid = floor((lbound + rbound) / 2);
        end
        % guarantee at least one symbol for each
        mid = min(f_rb, mid);
        mid = max(1, mid);
    end

    % 3. find the best division for the system power save, hardcoded, duplicate codes, but im lazy:(
    checked_num = [];
    lbound = f_lb;
    rbound = f_rb;
    rlimit = f_rb;
    llimit = f_lb;
    last_move = 2; % left:1, right:2
    mid = floor((lbound + rbound)/2);

    while true
        if ismember(mid, checked_num)
            break;
        end
        checked_num(end + 1) = mid;
        copy_RUE = group(1).copy();
        copy_DUEs = group(2:end).copy();

        DUE_rsc = resources(1:mid);
        DUE_tslot = [];
        RUE_rsc = resources(mid + 1: length(resources));

        if length(copy_DUEs) <= length(DUE_rsc)
            [res_DUEs, psave_DUEs, res_s_DUEs, res_p_DUEs, rx_energy, remaining_rsc, used_rsc] = SCA(DUE_rsc, copy_DUEs, copy_RUE);
        else
            res_DUEs = 'Infeasible';
            psave_DUEs = 0;
            res_s_DUEs = [];
            res_p_DUEs = [];
            rx_energy = 0;
            remaining_rsc = DUE_rsc;
            used_rsc = Resource.empty(1, 0);
        end
        fprintf('-------------------------\n');
        fprintf('phase2, DUE %d: %s with %d mini-slot, where %d slots are used\n', copy_DUEs.getId(), res_DUEs, length(DUE_rsc), length(used_rsc));

        for k = 1:length(used_rsc)
            for t = 1:length(used_rsc(k).tslot)
                if ~ismember(used_rsc(k).tslot(t), DUE_tslot)
                    DUE_tslot(end + 1) = used_rsc(k).tslot(t);
                end
            end
        end

        RUE_rsc = [RUE_rsc, remaining_rsc];
        type1_rsc = Resource.empty(1, 0);
        type2_rsc = Resource.empty(1, 0);

        if length(DUE_tslot) ~= 0
            for k = 1:length(RUE_rsc)
                tslot = RUE_rsc(k).tslot;
                overlapped = false;
                for t = 1:length(tslot)
                    if ismember(tslot(t), DUE_tslot)
                        overlapped = true;
                        break;
                    end
                end
                if overlapped == true
                    type2_rsc(end + 1) = RUE_rsc(k);
                else
                    if tslot(1) > max(DUE_tslot)
                        type1_rsc(end + 1) = RUE_rsc(k);
                    else
                        type2_rsc(end + 1) = RUE_rsc(k);
                    end
                end
            end
        else
            type1_rsc = resources;
        end
        
        if length(type1_rsc) > 0
            [res_RUE, psave_RUE, res_p_RUE, res_rp] = SCA_RUE(type1_rsc, copy_RUE, rx_energy, type2_rsc, DUE_tslot);
        else
            res_RUE = 'Infeasible';
            psave_RUE = 0;
            res_p_RUE = [];
            res_rp = [];
        end
        fprintf('phase2, RUE %d: %s with %d type-1 mini-slot + %d type-2 mini-slots\n', copy_RUE.getId(), res_RUE, length(type1_rsc), length(type2_rsc));

        if strcmp(res_DUEs, 'Solved') & strcmp(res_RUE, 'Solved')
            if psave_RUE + psave_DUEs >= best.profit
                best.profit = psave_DUEs + psave_RUE;
                best.weight = 1/psave_RUE;
                best.num = mid;
                best.status = 'Solved';

                copy_RUE.clearGrpResource();
                for u = 1:length(copy_DUEs)
                    copy_DUEs(u).clearGrpResource();
                end
                for i = 1:length(type1_rsc)
                    type1_rsc(i).tx_power = res_p_RUE(i);
                    copy_RUE.addGrpResource(type1_rsc(i));
                end

                for i = 1:length(type2_rsc)
                    type2_rsc(i).tx_power = res_rp(i);
                    copy_RUE.addGrpResource(type2_rsc(i));
                end

                for u = 1:length(copy_DUEs)
                    for k = 1:length(DUE_rsc)
                        if round(res_s_DUEs(k, u)) == 1
                            DUE_rsc(k).tx_power = res_p_DUEs(k, u);
                            copy_DUEs(u).addGrpResource(DUE_rsc(k));
                        end
                    end
                end
                copy_RUE.setGrpMembers(copy_DUEs);
                best.Ralloc = copy_RUE;
                best.Dalloc = copy_DUEs;
            end

            % calculate the next candidate point on the right-hand side
            rDUE_rsc = resources(1: min(rlimit, ceil((mid + rbound)/2)));
            rDUE_tslot = [];
            rRUE_rsc = resources(min(rlimit, ceil((mid + rbound)/2)) + 1: length(resources)); %rRUE_rsc = resources(min(rlimit, rbound + 1): length(resources));
            if length(copy_DUEs) <= length(rDUE_rsc)
                [r_res_DUEs, r_psave_DUEs, ~, ~, rx_energy, remaining_rsc, used_rsc] = SCA(rDUE_rsc, copy_DUEs, copy_RUE);
            else
                r_res_DUEs = 'Infeasible';
                r_psave_DUEs = 0;
                rx_energy = 0;
                remaining_rsc = rDUE_rsc;
                used_rsc = Resource.empty(1, 0);
            end

            for k = 1:length(used_rsc)
                for t = 1:length(used_rsc(k).tslot)
                    if ~ismember(used_rsc(k).tslot(t), rDUE_tslot)
                        rDUE_tslot(end + 1) = used_rsc(k).tslot(t);
                    end
                end
            end

            rRUE_rsc = [rRUE_rsc, remaining_rsc];
            rtype1_rsc = Resource.empty(1, 0);
            rtype2_rsc = Resource.empty(1, 0);

            if length(rDUE_tslot) ~= 0
                for k = 1:length(rRUE_rsc)
                    tslot = rRUE_rsc(k).tslot;
                    overlapped = false;
                    for t = 1:length(tslot)
                        if ismember(tslot(t), rDUE_tslot)
                            overlapped = true;
                            break;
                        end
                    end
                    if overlapped == true
                        rtype2_rsc(end + 1) = rRUE_rsc(k);
                    else
                        if tslot(1) > max(rDUE_tslot)
                            rtype1_rsc(end + 1) = rRUE_rsc(k);
                        else
                            rtype2_rsc(end + 1) = rRUE_rsc(k);
                        end
                    end
                end
            else
                rtype1_rsc = resources;
            end
            
            if length(rtype1_rsc) > 0
                [r_res_RUE, r_psave_RUE] = SCA_RUE(rtype1_rsc, copy_RUE, rx_energy, rtype2_rsc, rDUE_tslot);
                % fprintf('phase2, right: RUE with %d type-1 mini-slot + %d type-2 mini-slots\n', length(rtype1_rsc), length(rtype2_rsc));
            else
                r_res_RUE = 'Infeasible';
                r_psave_RUE = 0;
            end

            % calculate the profit of next candidate point on the left-hand side
            lDUE_rsc = resources(1: max(llimit, floor((lbound + mid)/2)));
            lDUE_tslot = [];
            lRUE_rsc = resources(max(llimit, floor((lbound + mid)/2)) + 1: length(resources)); %rRUE_rsc = resources(min(rlimit, rbound + 1): length(resources));
            if length(copy_DUEs) <= length(lDUE_rsc)
                [l_res_DUEs, l_psave_DUEs, ~, ~, rx_energy, remaining_rsc, used_rsc] = SCA(lDUE_rsc, copy_DUEs, copy_RUE);
            else
                l_res_DUEs = 'Infeasible';
                l_psave_DUEs = 0;
                rx_energy = 0;
                remaining_rsc = lDUE_rsc;
                used_rsc = Resource.empty(1, 0);
            end
            for k = 1:length(used_rsc)
                for t = 1:length(used_rsc(k).tslot)
                    if ~ismember(used_rsc(k).tslot(t), lDUE_tslot)
                        lDUE_tslot(end + 1) = used_rsc(k).tslot(t);
                    end
                end
            end

            lRUE_rsc = [lRUE_rsc, remaining_rsc];
            ltype1_rsc = Resource.empty(1, 0);
            ltype2_rsc = Resource.empty(1, 0);

            if length(lDUE_tslot) ~= 0
                for k = 1:length(lRUE_rsc)
                    tslot = lRUE_rsc(k).tslot;
                    overlapped = false;
                    for t = 1:length(tslot)
                        if ismember(tslot(t), lDUE_tslot)
                            overlapped = true;
                            break;
                        end
                    end
                    if overlapped == true
                        ltype2_rsc(end + 1) = lRUE_rsc(k);
                    else
                        if tslot(1) > max(lDUE_tslot)
                            ltype1_rsc(end + 1) = lRUE_rsc(k);
                        else
                            ltype2_rsc(end + 1) = lRUE_rsc(k);
                        end
                    end
                end
            else
                ltype1_rsc = resources;
            end

            if length(ltype1_rsc) > 0
                [l_res_RUE, l_psave_RUE] = SCA_RUE(ltype1_rsc, copy_RUE, rx_energy, ltype2_rsc, lDUE_tslot);
            else
                l_res_RUE = 'Infeasible';
                l_psave_RUE = 0;
            end
            
            fprintf('%.5f(%d) vs. %.5f(%d) vs. %.5f(%d)\n', l_psave_RUE + l_psave_DUEs, max(llimit, floor((lbound + mid)/2)), ...
                                    psave_DUEs + psave_RUE, mid, r_psave_DUEs + r_psave_RUE, min(rlimit, ceil((mid + rbound)/2)));
            if r_psave_DUEs + r_psave_RUE >= psave_RUE + psave_DUEs & r_psave_DUEs + r_psave_RUE >= l_psave_DUEs + l_psave_RUE
                fprintf('allocation in the righthand side is better, go right\n');
                lbound = mid;
                mid = ceil((lbound + rbound) / 2);
                last_move = 2;
            elseif l_psave_DUEs + l_psave_RUE >= psave_RUE + psave_DUEs & l_psave_DUEs + l_psave_RUE >= r_psave_RUE + r_psave_DUEs
                fprintf('allocation in the lefthand side is better, go left.\n');
                rbound = mid;
                mid = floor((lbound + rbound) / 2);
                last_move = 1;
            else 
                fprintf('here is the local optima\n')
                break;
            end
            last_profit = psave_RUE + psave_DUEs;
        elseif strcmp(res_DUEs, 'Infeasible')
            lbound = mid;
            mid = ceil((lbound + rbound) / 2);
            last_move = 2;
        else
            rbound = mid;
            mid = floor((lbound + rbound) / 2);
            last_move = 1;
        end
        mid = min(rlimit, mid);
        mid = max(llimit, mid);
    end

    % Output the result
    % status, alloc_RUE, alloc_DUEs, profit, weight
    status = best.status;
    alloc_RUE = best.Ralloc;
    alloc_DUEs = best.Dalloc;
    profit = best.profit;
    weight = best.weight;
end