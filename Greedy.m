function [res_RUE, res_DUEs, res_profit] = Greedy(RUE, DUEs)
% Function of the Greedy Algorithm, take one RUE and its DUE list
% and will output the result RUE and its DUE list, which has been allocated
% optimal grpResources and grpMembers, along with an res_profit that indicate
% the power save brought by the relay group.
% @RUE: An RUE object
% @DUEs: A DUE object list, this is proprietary to this particular RUE
% @res_RUE: An RUE object that filled with grpMembers, grpResource and grp_req
% @res_DUEs: A DUE object list, each DUE object has been filled with:
%            grp_state (if it is decided to join)
%            grpRUE: the RUE that will help this DUE
%            and its grpResource
% @res_profit: the total power save this resulting relay group can bring to the sys (double)

    % MAX_LEN = length(DUEs);
    global MAX_LEN;
    global NUM_MINI_SLOT;
    NUM_DUE = length(DUEs);
    res_profit = 0;
    res(MAX_LEN, NUM_DUE) = struct('profit', 0, 'weight', 1, 'pw_ratio', 0, 'Ralloc', RUE(), 'Dalloc', DUE.empty(1, 0), 'status', 'Infeasible');
    for i = 1:MAX_LEN
        for j =1:NUM_DUE
            res(i, j).profit = 0;
            res(i, j).weight = 1;
            res(i, j).pw_ratio = 0;
            res(i, j).Ralloc = RUE;
            res(i, j).Dalloc = DUEs;
            res(i, j).status = 'Infeasible';
        end
    end

    % At each iteration, the grpResource of each UE in group may change, 
    % so we use the copy of RUE and DUEs instead of the original one.
    copy_RUE = RUE.copy();
    copy_DUEs = DUEs.copy();
    ori_len = length(copy_RUE.getGrpMembers());
    cur_len = ori_len;
    % get the profit of the current relay group
    if cur_len == 0
        best = 0;
    else
        [~, ~, ~, best, ~] = bSearch(copy_RUE.copy(), DUE.empty());
    end

    for l = ori_len + 1:MAX_LEN
        for i = 1:NUM_DUE
            fprintf('DUE %d, max len = %d\n', i, l);
            if copy_DUEs(i).getGrpState() == true
                fprintf('DUE %d has been in the group\n', i);
                continue;
            end
            [status, alloc_RUE, alloc_DUEs, profit, weight] = bSearch(copy_RUE, copy_DUEs(i));
            % if the status is solved, the RUE can take DUE i as its groupMember, and share its resources
            if strcmp(status, 'Solved')
                fprintf('Solved: save the result, max_len =%d, trying DUE %d\n', l, i);
                res(l, i).profit = profit; res(l, i).weight = weight;
                res(l, i).Ralloc = alloc_RUE; res(l, i).Dalloc = alloc_DUEs;
                res(l, i).status = status;
                res(l, i).pw_ratio = profit / weight;
            end
        end

        % Sort the list, we only take one that has the largest pw_ratio at each iteration
        list = [res(l, :).profit]; % test, orignally pw_ratio, only for L=1
        [~, idx] = max(list);
        fprintf('best res: %s with id %d\n', res(l, idx).status, idx);
        % If even the one that can bring the largest pw_ratio shows Infeasible, or no additional profit is given
        % it is impossible for the RUE to take more DUEs. 
        if strcmp(res(l, idx).status, 'Solved') & res(l, idx).profit >= best
            fprintf('put a new UE is possbile when MAX_LEN = %d\n', l);
            cur_len = cur_len + 1;
            copy_RUE = res(l, idx).Ralloc;
            for j = 1:length(res(l, idx).Dalloc)
                % fprintf('RUE %d has %d members with DUE %d, which has:\n', copy_RUE.getId(), length(copy_RUE.getGrpMembers()), res(l, idx).Dalloc(j).getId());
                id = res(l, idx).Dalloc(j).getId();
                copy_DUEs(id) = res(l, idx).Dalloc(j);
                copy_DUEs(id).setGrpState(true);
                copy_DUEs(id).setGrpRUE(copy_RUE);
            end
            res_profit = res(l, idx).profit;
            best = res_profit;
        else
            break;
        end
    end

    % no group members change, re-calculate their grpResource
    if ori_len == cur_len
        fprintf('no group member change\n');
        if ori_len == 0
            % no DUE in this relay group
            fprintf('no relaying members\n')
            res_profit = 0;
            copy_RUE.clearGrpResource();
            rbs = copy_RUE.getPreResource();
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
                    copy_RUE.addGrpResource(r);
                end
            end
        else
            [status, alloc_RUE, alloc_DUEs, profit, weight] = bSearch(copy_RUE, DUE.empty());
            if strcmp(status, 'Solved')
                copy_RUE = alloc_RUE;
                for i = 1:length(alloc_DUEs)
                    id = alloc_DUEs(i).getId();
                    copy_DUEs(id) = alloc_DUEs(i);
                end
                res_profit = profit;
            else
                fprintf('essential DUE is removed\n');
                members = copy_RUE.getGrpMembers();
                for i = 1:length(members)
                    copy_DUEs(members(i).getId()).setGrpState(false);
                end
                copy_RUE.setGrpMembers(DUE.empty(1, 0));
                copy_RUE.clearGrpResource();
                [copy_RUE, copy_DUEs, res_profit] = Greedy(copy_RUE, copy_DUEs);
            end
        end
    end
    % output the results
    res_RUE = copy_RUE;
    res_DUEs = copy_DUEs;

    members = res_RUE.getGrpMembers();
    for i = 1:length(members)
        fprintf('RUE %d has DUE %d, which has:\n', res_RUE.getId(), members(i).getId());
        resc = res_DUEs(members(i).getId()).getGrpResource();
        for j = 1:length(resc)
            fprintf('rsc %d with %.5f power\n', resc(j).id, full(resc(j).tx_power));
        end
    end
end