function [res_RUE, res_DUE, res_profit] = GreedyEqual(RUE, DUEs)
% Function of the Greedy Algorithm for equalSlot, take one RUE and its DUE list
% and will output the result RUE and its DUE list, which has been allocated
% optimal grpResources and grpMembers, along with an res_profit that indicate
% the power save brought by the relay group.
% @RUE: An RUE object
% @DUE: A DUE object, this is proprietary to this particular RUE
% @res_RUE: An RUE object that filled with grpMembers, grpResource and grp_req
% @res_DUE: A DUE object, each DUE object has been filled with:
%            grp_state (if it is decided to join)
%            grpRUE: the RUE that will help this DUE
%            and its grpResource
% @res_profit: the total power save this resulting relay group can bring to the sys (double)

    res_profit = 0;
    NUM_DUE = length(DUEs);
    res(NUM_DUE) = struct('profit', 0, 'weight', 1, 'pw_ratio', 0, 'Ralloc', RUE(), 'Dalloc', DUE(), 'status', 'Infeasible');
    for i =1:NUM_DUE
        res(i).profit = 0;
        res(i).weight = 1;
        res(i).pw_ratio = 0;
        res(i).Ralloc = RUE;
        res(i).Dalloc = DUE;
        res(i).status = 'Infeasible';
    end

    % At each iteration, the grpResource of each UE in group may change, 
    % so we use the copy of RUE and DUEs instead of the original one.
    copy_RUE = RUE.copy();
    copy_DUEs = DUEs.copy();
    ori_len = length(copy_RUE.getGrpMembers());
    cur_len = ori_len;
    best = 0;
    for i = 1:NUM_DUE
        if copy_DUEs(i).getGrpState() == true
            % fprintf('DUE %d has been in the group\n', i);
            continue;
        end
        [status, alloc_RUE, alloc_DUE, profit] = equalSlot(copy_RUE, copy_DUEs(i));
        % if the status is solved, the RUE can take DUE i as its groupMember, and share its resources
        if strcmp(status, 'Solved')
            % fprintf('Solved: save the result\n')
            res(i).profit = profit; res(i).weight = 1;
            res(i).Ralloc = alloc_RUE; res(i).Dalloc = alloc_DUE;
            res(i).status = status;
            res(i).pw_ratio = profit / 1;
        end
    end

    % Sort the list, we only take one that has the largest pw_ratio at each iteration
    list = [res(:).profit];
    [~, idx] = max(list);
    % fprintf('best res: %s with id %d\n', res(idx).status, idx);
    % If even the one that can bring the largest pw_ratio shows Infeasible,
    % it is impossible for the RUE to take more DUEs. 
    if strcmp(res(idx).status, 'Solved') & res(idx).profit >= best
        copy_RUE = res(idx).Ralloc;
        id = res(idx).Dalloc.getId();
        copy_DUEs(id) = res(idx).Dalloc;
        copy_DUEs(id).setGrpState(true);
        copy_DUEs(id).setGrpRUE(copy_RUE);
        res_profit = res(idx).profit;
        cur_len = cur_len + 1;
        best = res_profit;
    end

    % no group members change, re-calculate their grpResource
    if ori_len == cur_len
        % fprintf('no group member change\n');
        if ori_len == 0
            % no DUE in this relay group
            res_profit = 0;
            copy_RUE.clearGrpResource();
            rbs = RUE.getPreResource();
            for i = 1:length(rbs)
                nslot = length(rbs(i).tslot) / 2;
                for idx_symbol = 1:2
                    r = Resource();
                    slots = [rbs(i).tslot(1) + (idx_symbol - 1)*nslot: (rbs(i).tslot(1) + idx_symbol * nslot - 1)];
                    r.init(rbs(i).id, idx_symbol, ... 
                        rbs(i).numerology, ...
                        rbs(i).bandwidth, ...
                        rbs(i).duration/2, ...
                        true, rbs(i).tx_power);
                    r.setSlot(slots);
                    copy_RUE.addGrpResource(r);
                end
            end
        end
    end
    % output the results
    res_RUE = copy_RUE;
    res_DUE = copy_DUEs;
end