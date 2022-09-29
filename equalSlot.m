function [status, alloc_RUE, alloc_DUE, profit] = equalSlot(RUE, DUE)
    
    DUE_rsc = Resource.empty();
    RUE_rsc = Resource.empty();
    status = 'Infeasible';
    % Generate the group
    group = UE.empty(1, 0);
    copy_RUE = RUE.copy();
    copy_RUE.clearGrpResource();
    copy_DUE = DUE.copy();
    copy_DUE.clearGrpResource();
    
    if length(copy_DUE) == 1
        copy_RUE.addtoGroup(copy_DUE);
    end
    group(1) = copy_RUE;
    members = copy_RUE.getGrpMembers();
    for i = 1:length(members)
        members(i).clearGrpResource();
        group(i + 1) = members(i);
    end
    % generate the symbols
    for i = 1:length(group)
        rbs = group(i).getPreResource();
        for k = 1:length(rbs)
            nslot = length(rbs(k).tslot) / 2;
            for idx_symbol = 1:2
                r = Resource();
                slots = [rbs(k).tslot(1) + (idx_symbol - 1)*nslot: (rbs(k).tslot(1) + idx_symbol * nslot - 1)];
                r.init(rbs(k).id, idx_symbol, ... 
                    rbs(k).numerology, ...
                    rbs(k).bandwidth, ...
                    rbs(k).duration/2, ...
                    true, 0);
                r.setSlot(slots);
                if idx_symbol == 1
                    DUE_rsc(end + 1) = r;
                else
                    RUE_rsc(end + 1) = r;
                end
            end
        end
    end

    [d_status, d_psave, res_p_DUEs] = allocDUE(DUE_rsc, copy_DUE, copy_RUE);
    
    rsc_req = zeros([1, length(RUE_rsc)]);
    for i = 1:length(DUE_rsc)
        pos = copy_DUE.getPosition();
        for j = 1:length(RUE_rsc)
            rpos = copy_RUE.getPosition();
            if DUE_rsc(i).id == RUE_rsc(j).id
                rsc_req(j) = DUE_rsc(i).bandwidth * log2(1 + SINR_D2D(res_p_DUEs(i), DUE_rsc(i).bandwidth, ... 
                                                        pos.x, pos.y, pos.z, rpos.x, rpos.y, rpos.z)) * DUE_rsc(i).duration;
            end
        end
    end
    [r_status, r_psave, res_p_RUE] = allocRUE(RUE_rsc, copy_RUE, rsc_req);
    profit = r_psave + d_psave;
    if strcmp(r_status, 'Solved') & strcmp(d_status, 'Solved')
        status = 'Solved';
    else
        % fprintf('RUE:%s, DUE:%s\n', r_status, d_status);
    end

    copy_RUE.clearGrpResource();
    copy_DUE.clearGrpResource();

    for i = 1:length(RUE_rsc)
        RUE_rsc(i).tx_power = res_p_RUE(i);
        copy_RUE.addGrpResource(RUE_rsc(i));
    end

    for i = 1:length(DUE_rsc)
        DUE_rsc(i).tx_power = res_p_DUEs(i);
        copy_DUE.addGrpResource(DUE_rsc(i));
    end
    alloc_RUE = copy_RUE;
    alloc_DUE = copy_DUE;
end

function [status, psave, res_p] = allocRUE(resource, RUE, rsc_req)
    global BS_POSITION;
    global P_MAX;
    global NUM_SLOT;
    global NUM_NUMEROLOGY;
    K = length(resource);
    pos = RUE.getPosition();

    cvx_begin quiet
        obj=0;
        sub_databits = 0;
        sub_energy = 0;
        expression sub_power(NUM_SLOT);
        expression rsc_data(K);
        variable p(K)
        for i=1:K
            obj=obj+p(i) * resource(i).duration;
        end
        minimize (obj)
        res_p=p; % output result
        
        subject to 
        for i=1:K
            sinr = SINR2(p(i), resource(i).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            sub_databits = sub_databits + resource(i).bandwidth * log(1 + sinr) / log(2) * resource(i).duration; 
        end
            sub_databits>=RUE.getRequirement(); % condition

        for i = 1:K
            sinr = SINR2(p(i), resource(i).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            rsc_data(i) = rsc_data(i) + resource(i).bandwidth * log(1 + sinr) / log(2) * resource(i).duration;
        end
        for i = 1:K
            rsc_data(i)>=rsc_req(i);
        end

        for i = 1:K
            for j = 1:length(resource(i).tslot)
                t = resource(i).tslot(j);
                sub_power(t) = sub_power(t) + p(i);
            end
        end
            sub_power <= P_MAX;
            p>=0;
            
    cvx_end
    
    status = cvx_status;
    psave = RUE.getDirectEnergy() - cvx_optval;
end

function [status, psave, res_p] = allocDUE(resource, DUE, RUE)
    global BS_POSITION;
    global P_MAX;
    global NUM_SLOT;
    global NUM_NUMEROLOGY;
    K = length(resource);
    pos = DUE.getPosition();
    rpos = RUE.getPosition();

    cvx_begin quiet
        obj=0;
        sub_databits = 0;
        sub_energy = 0;
        expression sub_power(NUM_SLOT);
        variable p(K)
        for i=1:K
            obj=obj+p(i) * resource(i).duration;
        end
        minimize (obj)
        res_p=p; % output result
        
        subject to 
        for i=1:K
            sinr = SINR_D2D(p(i), resource(i).bandwidth, pos.x, pos.y, pos.z, rpos.x, rpos.y, rpos.z);
            sub_databits = sub_databits + resource(i).bandwidth * log(1 + sinr) / log(2) * resource(i).duration; 
        end
            sub_databits>=DUE.getRequirement(); % condition

        for i = 1:K
            for j = 1:length(resource(i).tslot)
                t = resource(i).tslot(j);
                sub_power(t) = sub_power(t) + p(i);
            end
        end
            sub_power <= P_MAX;
            p>=0;
            
    cvx_end
    
    status = cvx_status;
    psave = DUE.getDirectEnergy() - cvx_optval;
end