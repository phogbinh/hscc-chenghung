function [status, p_tot, res_p] = AllocPower(resource, DUEs, RUE, s, res_comm, res_tx)
% This function solves power allocation in SCA algorithm
% @status(string): Infeasible if the resources are not enough for the DUEs
% @p_tot(double): the total energy use with the allocation calculated by the function
% @res_p: a K * NUM_DUE double matrix, stored the power allocation to the DUEs
% @resource: A Resource object array. the available resources in this problem
% @DUEs: A DUE object array. The DUEs are involved in this allocation problem.
% @s: a K * NUM_DUE double matrix, which is calculated by the symbol allocation function.

    global P_MAX;
    global NUM_SLOT;
    global SLOT_DURATION;
    global NUM_NUMEROLOGY;
    K = length(resource);
    NUM_DUE = length(DUEs);
    rpos = RUE.getPosition();
    p_tot = 0;

    cvx_begin quiet
        obj=0;
        expression sub_databits(1, NUM_DUE);
        expression sub_energy(1, NUM_DUE);
        expression sub_power(NUM_DUE, NUM_SLOT);
        variable p(K, NUM_DUE) % the variable we want to know
        for u = 1:NUM_DUE
            for k = 1:K
                obj = obj + s(k, u) * p(k, u) * resource(k).duration/1e6;
            end
        end
        for u = 1:NUM_DUE
            for t = 1:NUM_SLOT
                obj = obj + res_comm(u, t) * 853/8 * SLOT_DURATION/1e6;
            end
            for i = 1:NUM_NUMEROLOGY
                for t = 1:NUM_SLOT
                    obj = obj + res_tx(u, i, t) * 29.9/8 * SLOT_DURATION/1e6;
                end
            end
        end
        minimize (obj)
        res_p=p;
        subject to 
        for u = 1:NUM_DUE
            pos = DUEs(u).getPosition();
            for k = 1:K
                sinr = SINR_D2D(p(k, u), resource(k).bandwidth, pos.x, pos.y, pos.z, rpos.x, rpos.y, rpos.z);
                bps = log(1 + sinr) / log(2);
                sub_databits(u) = sub_databits(u) + s(k, u) * resource(k).bandwidth * bps * resource(k).duration;
            end
        end
            for u = 1:NUM_DUE
                sub_databits(u)>=DUEs(u).getRequirement();
            end
        
        for u = 1:NUM_DUE
            for k=1:K
                sub_energy(u) = sub_energy(u) + s(k, u) * p(k, u) * resource(k).duration;
            end
            for t = 1:NUM_SLOT
                sub_energy(u) = sub_energy(u) + res_comm(u, t) * 853/8 * SLOT_DURATION;
            end
            for i = 1:NUM_NUMEROLOGY
                for t = 1:NUM_SLOT
                    sub_energy(u) = sub_energy(u) + res_tx(u, i, t) * 29.9/8 * SLOT_DURATION;
                end
            end
        end
            for u = 1:NUM_DUE
                sub_energy(u)<=DUEs(u).getDirectEnergy();
            end

        for u = 1:NUM_DUE
            for k = 1:K
                for j = 1:length(resource(k).tslot)
                    t = resource(k).tslot(j);
                    sub_power(u, t) = sub_power(u, t) + s(k, u) * p(k, u);
                end
            end
        end
            for u = 1:NUM_DUE
                for t = 1:NUM_SLOT
                    sub_power(u, t) <= P_MAX;
                end
            end
            
            p>=0;
            % p<=s*P_MAX;
    cvx_end
    
    status = cvx_status;
    % fprintf('power alloc: %s\n', status);
    for u = 1:NUM_DUE
        d = 0;
        r = 0;
        pos = DUEs(u).getPosition();
        for k =1:k
            sinr = SINR_D2D(res_p(k, u), resource(k).bandwidth, pos.x, pos.y, pos.z, rpos.x, rpos.y, rpos.z);
            d = d + round(s(k, u))*resource(k).bandwidth * log2(1 + sinr) * resource(k).duration;
            p_tot = p_tot + s(k, u) * res_p(k, u);
            r = r + round(s(k, u)) * res_p(k, u) * resource(k).duration;
            % fprintf('Solution: UE %d, %.2f, %.2f\n', DUEs(u).getId(), full(s(k,u)), full(res_p(k,u)));
        end
        % fprintf('real data: %.2f\n', d);
        % fprintf('req data: %.2f\n', DUEs(u).getRequirement());
        % fprintf('real energy: %.2f\n', r);
        % fprintf('req energy: %.2f\n', DUEs(u).getDirectEnergy());
    end
    p_tot = cvx_optval;
    % fprintf('opt_val: %.2f\n', cvx_optval);
end