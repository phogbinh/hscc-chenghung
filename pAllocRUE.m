function [status, psave, res, res_rp] = pAllocRUE(resource, RUE, rx_energy, remaining_rsc)
    global BS_POSITION;
    global P_MAX;
    global NUM_SLOT;
    K = length(resource);
    rK = length(remaining_rsc);
    pos = RUE.getPosition();
    
    cvx_begin quiet
        obj=0;
        sub_databits = 0;
        sub_memberdata = 0;
        sub_energy = 0;
        expression sub_power(NUM_SLOT);
        variable p(K)
        variable rp(rK)
        for i=1:K
            obj=obj+p(i) * resource(i).duration;
        end
        for i = 1:rK
            obj = obj + rp(i) * remaining_rsc(i).duration;
        end
        minimize (obj)
        res=p; % output result
        res_rp = rp;

        subject to 
        for i=1:K
            sinr = SINR2(p(i), resource(i).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            sub_databits = sub_databits + resource(i).bandwidth * log(1 + sinr) / log(2) * resource(i).duration;
        end
        for i=1:rK
            sinr = SINR2(rp(i), remaining_rsc(i).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            sub_databits = sub_databits + remaining_rsc(i).bandwidth * log(1 + sinr) / log(2) * remaining_rsc(i).duration; 
        end
            sub_databits>=RUE.getRequirement(); % condition

        for i=1:K
            sinr = SINR2(p(i), resource(i).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            sub_memberdata = sub_memberdata + resource(i).bandwidth * log(1 + sinr) / log(2) * resource(i).duration; 
        end
            sub_memberdata>=RUE.getMemberRequirement();

        for i=1:K
            sub_energy = sub_energy + p(i) * resource(i).duration;
        end
        for i=1:rK
            sub_energy = sub_energy + rp(i) * remaining_rsc(i).duration;
        end
            sub_energy + rx_energy <=RUE.getDirectEnergy();

        for i = 1:K
            for j = 1:length(resource(i).tslot)
                t = resource(i).tslot(j);
                sub_power(t) = sub_power(t) + p(i);
            end
        end
        for i = 1:rK
            for j = 1:length(remaining_rsc(i).tslot)
                t = remaining_rsc(i).tslot(j);
                sub_power(t) = sub_power(t) + rp(i);
            end
        end
            for i = 1:NUM_SLOT
                sub_power(i) <= P_MAX;
            end
            p>=0;
            rp>=0;
    cvx_end
    
    % fprintf('RUE res_p: %e, %e\n', cvx_optval, RUE.getDirectEnergy());
    d = 0;
    for i=1:K
        sinr = SINR2(res(i), resource(i).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
        d = d + resource(i).bandwidth * log(1 + sinr) / log(2) * resource(i).duration; 
    end
    % fprintf('memberdata = %.5f, req: %.5f\n', d, RUE.getMemberRequirement());
    status = cvx_status;
    psave = RUE.getDirectEnergy() - cvx_optval - rx_energy;
end