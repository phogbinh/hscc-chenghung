function [status, psave, res_p, res_rp] = SCA_RUE(resource, RUE, rx_energy, remaining_rsc, DUE_tslot)
    % resource = type1, remaining_rsc = type2
    global NUM_SLOT;
    global BS_POSITION;
    global SLOT_DURATION;
    global NUM_NUMEROLOGY;
    MAX_ITER = 50; % testing (200)
    tolerance = 10^-5;
    pfactor = 200;
    last_p_tot = 0;
    diff = 1;
    iter = 1;
    psave = 0;
    K = length(resource);
    rK = length(remaining_rsc);
    cstatus = string([]);
    status = 'Infeasible';
    res_p = zeros([1, K]);
    res_rp = zeros([1, rK]);
    res_s = zeros([1, K]);
    res_tx = zeros([NUM_NUMEROLOGY, NUM_SLOT]);
    res_comm = zeros([1, NUM_SLOT]);
    num_rb_perslot = zeros([NUM_SLOT]);
    comm_slot = zeros([1, NUM_SLOT]);
    tx_slot = zeros([NUM_NUMEROLOGY, NUM_SLOT]);

    for k = 1:K
        slot_num = resource(k).tslot;
        for t = 1:length(slot_num)
            num_rb_perslot(slot_num(t)) = num_rb_perslot(slot_num(t)) + 1;
        end
    end

    for k = 1:rK
        slot_num = remaining_rsc(k).tslot;
        for t = 1:length(slot_num)
            num_rb_perslot(slot_num(t)) = num_rb_perslot(slot_num(t)) + 1;
        end
    end

    % initialize the variables, solve symbol alloc without penalty
    for k = 1:K
        tslot = resource(k).tslot;
        res_p(k) = 10^2.3 / max(max(num_rb_perslot(tslot)), 1);
    end
    for k = 1:rK
        tslot = remaining_rsc(k).tslot;
        res_rp(k) = 10^2.3 / max(max(num_rb_perslot(tslot)), 1);
    end

    [check, res_s, res_rs, res_tx, res_comm] = Init(resource, RUE, res_p, res_rp, DUE_tslot, remaining_rsc, rx_energy);
    if ~strcmp(check, 'Solved')
        return;
    end

    while diff >= tolerance
        [init_status, res_s, res_rs, res_tx, res_comm] = AllocSymbol(resource, RUE, res_p, res_rp, abs(res_s), abs(res_rs), ...
                                                        pfactor, remaining_rsc, abs(res_tx), abs(res_comm), DUE_tslot, rx_energy);
        if ~strcmp(init_status, 'Solved')
            return;
        end

        [st, p_tot, res_p, res_rp] = AllocPower_RUE(resource, RUE, abs(res_s), abs(res_rs), abs(res_tx), abs(res_comm), remaining_rsc, rx_energy);
        diff = abs(p_tot - last_p_tot);
        if ~strcmp(st, 'Solved')
            return;
        end
        last_p_tot = p_tot;
        cstatus = st;
        iter = iter + 1;
        if iter >= MAX_ITER
            break;
        end
        % fprintf('iter: %d, diff: %e\n', iter - 1, diff);
    end

    d = 0;
    e = 0;
    pos = RUE.getPosition();
    for k = 1:K
        sinr = SINR2(res_p(k), resource(k).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
        if round(res_s(k)) == 1
            for i = 1:length(resource(k).tslot)
                comm_slot(resource(k).tslot(i)) = 1;
                tx_slot(resource(k).numerology + 1, resource(k).tslot(i)) = 1;
            end
            d = d + round(res_s(k)) * resource(k).bandwidth * log2(1 + sinr) * resource(k).duration;
            e = e + round(res_s(k)) * res_p(k) * resource(k).duration;
        else
            res_p(k) = 0;
        end
    end

    if RUE.getMemberRequirement() > d + 1
        fprintf('fractional solution\n');
        psave = 0;
        status = 'Infeasible';
        return;
    end

    for k = 1:rK
        sinr = SINR2(res_rp(k), remaining_rsc(k).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
        if round(res_rs(k)) == 1
            for i = 1:length(remaining_rsc(k).tslot)
                comm_slot(remaining_rsc(k).tslot(i)) = 1;
                tx_slot(remaining_rsc(k).numerology + 1, remaining_rsc(k).tslot(i)) = 1;
            end
            d = d + round(res_rs(k)) * remaining_rsc(k).bandwidth * log2(1 + sinr) * remaining_rsc(k).duration;
            e = e + round(res_rs(k)) * res_rp(k) * remaining_rsc(k).duration;
        else
            res_rp(k) = 0;
        end
    end
    fprintf('tx1: %.2f\n', e);
    for i = 1:NUM_NUMEROLOGY
        for t = 1:NUM_SLOT
            e = e + tx_slot(i, t) * 29.9/8 * SLOT_DURATION;
        end
    end
    fprintf('tx2: %.2f\n', e);
    for i = 1:length(DUE_tslot)
        comm_slot(DUE_tslot(i)) = 1;
    end
    for t = 1:NUM_SLOT
        fprintf('%.2f, ', res_comm(t));
        e = e + comm_slot(t) * 853/8 * SLOT_DURATION;
    end
    fprintf('tx3: %.2f\n', e);
    e = e + rx_energy;
    if RUE.getRequirement() > d + 1 | RUE.getDirectEnergy() < e - 1 % +1 and -1 is for preventing error
        fprintf('fractional solution\n');
        psave = 0;
        status = 'Infeasible';
        return;
    end
    fprintf('%.2f(%.2f) vs. %.2f\n', e, rx_energy, RUE.getDirectEnergy());
    psave = RUE.getDirectEnergy() - e;

    status = cstatus;
end
    
function [status, res_s, res_rs, res_tx, res_comm] = AllocSymbol(resource, RUE, p, rp, last_s, last_rs, pfactor, remaining_rsc, last_tx, last_comm, DUE_tslot, rx_energy)
% This function solves symbol allocation in SCA
% @status(string): Infeasible if the resources are not enough for the DUEs
% @res_s: a K * NUM_DUE double matrix, stored the symbol allocation to the DUEs
% @resource: A Resource object array. the available resources in this problem
% @DUEs: A DUE object array. The DUEs are involved in this allocation problem.
% @RUE: An RUE object, which serves as relay for the DUEs.
% @p: a K * NUM_DUE double matrix, an initial power allocation for the SCA algorithm.
% @last_s: a K * NUM_DUE double matrix, which is calculated by the Init function.
%          these values are used for Taylor Series Approximation
% @pfactor: the figure indicates the penalty for this allocation problem. It is used to
%           make the solver prefer integer solutions for the res_s.

    global P_MAX;
    global NUM_SLOT;
    global BS_POSITION;
    global SLOT_DURATION;
    global NUM_NUMEROLOGY;
    K = length(resource);
    rK = length(remaining_rsc);
    pos = RUE.getPosition();
    res_s = zeros([1, K]);
    res_rs = zeros([1, rK]);

    cvx_begin quiet
        obj = 0;
        sub_databits = 0;
        sub_energy = 0;
        sub_memberdata = 0;
        expression sub_power(NUM_SLOT);
        expression sub_alloc(1, K);
        expression sub_comm_slot(1, NUM_SLOT);
        expression sub_tx_slot(NUM_NUMEROLOGY, NUM_SLOT);
        variable tx_slot(NUM_NUMEROLOGY, NUM_SLOT)
        variable comm_slot(1, NUM_SLOT)
        variable s(1, K)
        variable rs(1, rK)
        for k = 1:K
            obj = obj + s(k) * p(k) * resource(k).duration/1000 - pfactor * ((last_s(k)^2 - last_s(k)) + (last_s(k) * 2) * (s(k) - last_s(k)));
        end
        for k = 1:rK
            obj = obj + rs(k) * rp(k) * remaining_rsc(k).duration/1000 - pfactor * ((last_rs(k)^2 - last_rs(k)) + (last_rs(k) * 2) * (rs(k) - last_rs(k)));
        end
        for t = 1:NUM_SLOT
            obj = obj + comm_slot(t) * 853/8 * SLOT_DURATION/1000 - pfactor * ((last_comm(t)^2 - last_comm(t)) + (last_comm(t) * 2) * (comm_slot(t) - last_comm(t)));
        end
        for i = 1:NUM_NUMEROLOGY
            for t = 1:NUM_SLOT
                obj = obj + tx_slot(i, t) * 29.9/8 * SLOT_DURATION/1000 - pfactor * ((last_tx(i, t)^2 - last_tx(i, t)) + (last_tx(i, t) * 2) * (tx_slot(i, t) - last_tx(i, t)));
            end
        end
        minimize (obj)
        res_s=s;
        res_rs=rs;
        res_tx=tx_slot;
        res_comm=comm_slot;
        subject to
        % data bits
        for i=1:K
            sinr = SINR2(p(i), resource(i).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            sub_databits = sub_databits + s(i) * resource(i).bandwidth * log(1 + sinr) / log(2) * resource(i).duration;
        end
        for i=1:rK
            sinr = SINR2(rp(i), remaining_rsc(i).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            sub_databits = sub_databits + rs(i) * remaining_rsc(i).bandwidth * log(1 + sinr) / log(2) * remaining_rsc(i).duration; 
        end
            sub_databits>=RUE.getRequirement(); % condition

        for i=1:K
            sinr = SINR2(p(i), resource(i).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            sub_memberdata = sub_memberdata + s(i) * resource(i).bandwidth * log(1 + sinr) / log(2) * resource(i).duration; 
        end
            sub_memberdata>=RUE.getMemberRequirement();
        
        % energy
        for i=1:K
            sub_energy = sub_energy + s(i) * p(i) * resource(i).duration;
        end
        for i=1:rK
            sub_energy = sub_energy + rs(i) * rp(i) * remaining_rsc(i).duration;
        end
        for t = 1:NUM_SLOT
            sub_energy = sub_energy + comm_slot(t) * 853/8 * SLOT_DURATION;
        end
        for i = 1:NUM_NUMEROLOGY
            for t = 1:NUM_SLOT
                sub_energy = sub_energy + tx_slot(i, t) * 29.9/8 * SLOT_DURATION;
            end
        end
            sub_energy + rx_energy <=RUE.getDirectEnergy();

        % max tx power
        for k = 1:K
            for j = 1:length(resource(k).tslot)
                t = resource(k).tslot(j);
                sub_power(t) = sub_power(t) + s(k) * p(k);
            end
        end
        for k = 1:rK
            for j = 1:length(remaining_rsc(k).tslot)
                t = remaining_rsc(k).tslot(j);
                sub_power(t) = sub_power(t) + rs(k) * rp(k);
            end
        end
            for t = 1:NUM_SLOT
                sub_power(t) <= P_MAX;
            end
            s>=0;
            s<=1;
            rs>=0;
            rs<=1;
            for k = 1:K
                for j = 1:length(resource(k).tslot)
                    t = resource(k).tslot(j);
                    i = resource(k).numerology + 1;
                    sub_comm_slot(t) = sub_comm_slot(t) + s(k);
                    sub_tx_slot(i, t) = sub_tx_slot(i, t) + s(k);
                end
            end
            for k = 1:rK
                for j = 1:length(remaining_rsc(k).tslot)
                    t = remaining_rsc(k).tslot(j);
                    i = remaining_rsc(k).numerology + 1;
                    sub_comm_slot(t) = sub_comm_slot(t) + rs(k);
                    sub_tx_slot(i, t) = sub_tx_slot(i, t) + rs(k);
                end
            end
            for i = 1:length(DUE_tslot)
                sub_comm_slot(DUE_tslot(i)) = sub_comm_slot(DUE_tslot(i)) + 1;
            end

            for t = 1:NUM_SLOT
                sub_comm_slot(t) >= 1e-8 * comm_slot(t);
                sub_comm_slot(t) <= 98 * 7 * comm_slot(t);
            end
            sub_tx_slot >= 1e-8 * tx_slot;
            sub_tx_slot <= K * tx_slot;

            comm_slot>=0;
            comm_slot<=1;
            tx_slot>=0;
            tx_slot<=1;
    cvx_end

    status = cvx_status;
    % fprintf('symbol alloc: %s\n', status);
end

function [status, res_s, res_rs, res_tx, res_comm] = Init(resource, RUE, p, rp, DUE_tslot, remaining_rsc, rx_energy)
% The function provides initial symbol allocation for SCA, which serves as intial points
% @status(string): Infeasible if the resources are not enough for the DUEs
% @res_s: a K * NUM_DUE double matrix, stored the initial symbol allocation to the DUEs
% @resource: A Resource object array. the available resources in this problem
% @DUEs: A DUE object array. The DUEs are involved in this allocation problem.
% @RUE: An RUE object, which serves as relay for the DUEs.
% @p: a K * NUM_DUE double matrix, an initial power allocation for the SCA algorithm.

    global P_MAX;
    global NUM_SLOT;
    global BS_POSITION;
    global SLOT_DURATION;
    global NUM_NUMEROLOGY;
    K = length(resource);
    rK = length(remaining_rsc);
    res_s = zeros([1, K]);
    res_rs = zeros([1, rK]);
    res_tx = zeros([NUM_NUMEROLOGY, NUM_SLOT]);
    res_comm = zeros([1, NUM_SLOT]);
    pos = RUE.getPosition();

    cvx_begin quiet
        obj = 0;
        sub_databits = 0;
        sub_energy = 0;
        sub_memberdata = 0;
        expression sub_power(NUM_SLOT);
        expression sub_comm_slot(1, NUM_SLOT);
        expression sub_tx_slot(NUM_NUMEROLOGY, NUM_SLOT);
        variable tx_slot(NUM_NUMEROLOGY, NUM_SLOT)
        variable comm_slot(1, NUM_SLOT)
        variable s(1, K)
        variable rs(1, rK)
        for k = 1:K
            obj = obj + s(k) * p(k) * resource(k).duration/1000;
        end
        for k = 1:rK
            obj = obj + rs(k) * rp(k) * remaining_rsc(k).duration/1000;
        end
        for t = 1:NUM_SLOT
            obj = obj + comm_slot(t) * 853/8 * SLOT_DURATION/1000;
        end
        for i = 1:NUM_NUMEROLOGY
            for t = 1:NUM_SLOT
                obj = obj + tx_slot(i, t) * 29.9/8 * SLOT_DURATION/1000;
            end
        end
        minimize (obj)
        res_s=s;
        res_rs=rs;
        res_comm=comm_slot;
        res_tx=tx_slot;
        subject to
        % data bits
        for i=1:K
            sinr = SINR2(p(i), resource(i).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            sub_databits = sub_databits + s(i) * resource(i).bandwidth * log(1 + sinr) / log(2) * resource(i).duration;
        end
        for i=1:rK
            sinr = SINR2(rp(i), remaining_rsc(i).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            sub_databits = sub_databits + rs(i) * remaining_rsc(i).bandwidth * log(1 + sinr) / log(2) * remaining_rsc(i).duration; 
        end
            sub_databits>=RUE.getRequirement(); % condition

        for i=1:K
            sinr = SINR2(p(i), resource(i).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            sub_memberdata = sub_memberdata + s(i) * resource(i).bandwidth * log(1 + sinr) / log(2) * resource(i).duration; 
        end
            sub_memberdata>=RUE.getMemberRequirement();
        
        % energy
        for i=1:K
            sub_energy = sub_energy + s(i) * p(i) * resource(i).duration;
        end
        for i=1:rK
            sub_energy = sub_energy + rs(i) * rp(i) * remaining_rsc(i).duration;
        end
        for t = 1:NUM_SLOT
            sub_energy = sub_energy + comm_slot(t) * 853/8 * SLOT_DURATION;
        end
        for i = 1:NUM_NUMEROLOGY
            for t = 1:NUM_SLOT
                sub_energy = sub_energy + tx_slot(i, t) * 29.9/8 * SLOT_DURATION;
            end
        end
            sub_energy + rx_energy <=RUE.getDirectEnergy();

        % max tx power
        for k = 1:K
            for j = 1:length(resource(k).tslot)
                t = resource(k).tslot(j);
                sub_power(t) = sub_power(t) + s(k) * p(k);
            end
        end
        for k = 1:rK
            for j = 1:length(remaining_rsc(k).tslot)
                t = remaining_rsc(k).tslot(j);
                sub_power(t) = sub_power(t) + rs(k) * rp(k);
            end
        end
            for t = 1:NUM_SLOT
                sub_power(t) <= P_MAX;
            end
            s>=0;
            s<=1;
            rs>=0;
            rs<=1;
            for k = 1:K
                for j = 1:length(resource(k).tslot)
                    t = resource(k).tslot(j);
                    i = resource(k).numerology + 1;
                    sub_comm_slot(t) = sub_comm_slot(t) + s(k);
                    sub_tx_slot(i, t) = sub_tx_slot(i, t) + s(k);
                end
            end
            for k = 1:rK
                for j = 1:length(remaining_rsc(k).tslot)
                    t = remaining_rsc(k).tslot(j);
                    i = remaining_rsc(k).numerology + 1;
                    sub_comm_slot(t) = sub_comm_slot(t) + rs(k);
                    sub_tx_slot(i, t) = sub_tx_slot(i, t) + rs(k);
                end
            end
            for i = 1:length(DUE_tslot)
                sub_comm_slot(DUE_tslot(i)) = sub_comm_slot(DUE_tslot(i)) + 1;
            end

            for t = 1:NUM_SLOT
                sub_comm_slot(t) >= 1e-8 * comm_slot(t);
                sub_comm_slot(t) <= 98 * 7 * comm_slot(t);
            end
            sub_tx_slot >= 1e-8 * tx_slot;
            sub_tx_slot <= K * tx_slot;

            comm_slot>=0;
            comm_slot<=1;
            tx_slot>=0;
            tx_slot<=1;
    cvx_end
    status = cvx_status;

    % fprintf('init status: %s, %d\n', status, cvx_optval);
end

function [status, p_tot, res_p, res_rp] = AllocPower_RUE(resource, RUE, s, rs, res_tx, res_comm, remaining_rsc, rx_energy)
% The function provides initial symbol allocation for SCA, which serves as intial points
% @status(string): Infeasible if the resources are not enough for the DUEs
% @res_s: a K * NUM_DUE double matrix, stored the initial symbol allocation to the DUEs
% @resource: A Resource object array. the available resources in this problem
% @DUEs: A DUE object array. The DUEs are involved in this allocation problem.
% @RUE: An RUE object, which serves as relay for the DUEs.
% @p: a K * NUM_DUE double matrix, an initial power allocation for the SCA algorithm.

    global P_MAX;
    global NUM_SLOT;
    global BS_POSITION;
    global SLOT_DURATION;
    global NUM_NUMEROLOGY;
    K = length(resource);
    rK = length(remaining_rsc);
    pos = RUE.getPosition();

    cvx_begin quiet
        obj = 0;
        sub_databits = 0;
        sub_energy = 0;
        sub_memberdata = 0;
        expression sub_power(NUM_SLOT);
        variable p(1, K)
        variable rp(1, rK)
        for k = 1:K
            obj = obj + s(k) * p(k) * resource(k).duration/1000;
        end
        for k = 1:rK
            obj = obj + rs(k) * rp(k) * remaining_rsc(k).duration/1000;
        end
        for t = 1:NUM_SLOT
            obj = obj + res_comm(t) * 853/8 * SLOT_DURATION/1000;
        end
        for i = 1:NUM_NUMEROLOGY
            for t = 1:NUM_SLOT
                obj = obj + res_tx(i, t) * 29.9/8 * SLOT_DURATION/1000;
            end
        end
        minimize (obj)
        res_p=p;
        res_rp=rp;
        subject to
        % data bits
        for i=1:K
            sinr = SINR2(p(i), resource(i).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            sub_databits = sub_databits + s(i) * resource(i).bandwidth * log(1 + sinr) / log(2) * resource(i).duration;
        end
        for i=1:rK
            sinr = SINR2(rp(i), remaining_rsc(i).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            sub_databits = sub_databits + rs(i) * remaining_rsc(i).bandwidth * log(1 + sinr) / log(2) * remaining_rsc(i).duration; 
        end
            sub_databits>=RUE.getRequirement(); % condition

        for i=1:K
            sinr = SINR2(p(i), resource(i).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
            sub_memberdata = sub_memberdata + s(i) * resource(i).bandwidth * log(1 + sinr) / log(2) * resource(i).duration; 
        end
            sub_memberdata>=RUE.getMemberRequirement();
        
        % energy
        for i=1:K
            sub_energy = sub_energy + s(i) * p(i) * resource(i).duration;
        end
        for i=1:rK
            sub_energy = sub_energy + rs(i) * rp(i) * remaining_rsc(i).duration;
        end
        for t = 1:NUM_SLOT
            sub_energy = sub_energy + res_comm(t) * 853/8 * SLOT_DURATION;
        end
        for i = 1:NUM_NUMEROLOGY
            for t = 1:NUM_SLOT
                sub_energy = sub_energy + res_tx(i, t) * 29.9/8 * SLOT_DURATION;
            end
        end
            sub_energy + rx_energy <=RUE.getDirectEnergy();

        % max tx power
        for k = 1:K
            for j = 1:length(resource(k).tslot)
                t = resource(k).tslot(j);
                sub_power(t) = sub_power(t) + s(k) * p(k);
            end
        end
        for i = 1:rK
            for j = 1:length(remaining_rsc(i).tslot)
                t = remaining_rsc(i).tslot(j);
                sub_power(t) = sub_power(t) + rs(i) * rp(i);
            end
        end
            for t = 1:NUM_SLOT
                sub_power(t) <= P_MAX;
            end
            p>=0;
            rp>=0;
    cvx_end
    status = cvx_status;
    p_tot = cvx_optval + rx_energy;

    % fprintf('power_alloc status: %s, %d\n', status, cvx_optval);
end