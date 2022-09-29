function [status, psave, res_s, res_p, rx_energy, remaining_rsc, used_rsc] = SCA(resource, DUEs, RUE)
% Tested with CVX - Mosek, SDTP3 Solver
% This function applies Successive Complex Approximation algorithm
% to solve the symbol and power allocation problem for DUEs
% @resource: the available resources to DUEs (A Resource object array)
% @DUEs: the user devices that involved in this allocation problem (A DUE object array)
% @RUE: the UE that serves as relay for the DUEs (An RUE object array)
% @status: Solved if there is solution for this allocation problem (string)
% @psave: the power these DUE can save by using this allocation (double)
% @res_s: the symbol allocation result (a K * NUM_DUE integer matrix)
% @res_p: the power allocation result  (a K * NUM_DUE double matrix)
    global NUM_SLOT;
    global SLOT_DURATION;
    global NUM_NUMEROLOGY;
    MAX_ITER = 50; % testing (200)
    tolerance = 10^-5;
    pfactor = 200; % log2(10^2.3/(10^-14 + 10^-17.4))*10
    last_p_tot = 0;
    diff = 1;
    iter = 1;
    psave = 0;
    K = length(resource);
    NUM_DUE = length(DUEs);
    cstatus = string([]);
    status = 'Infeasible';
    res_p = zeros([K, NUM_DUE]);
    res_s = zeros([K, NUM_DUE]);
    res_comm = zeros([NUM_DUE, NUM_SLOT]);
    res_tx = zeros([NUM_DUE, NUM_NUMEROLOGY, NUM_SLOT]);
    num_rb_perslot = zeros([NUM_NUMEROLOGY, NUM_SLOT]);
    rx_energy = 0;
    remaining_rsc = Resource.empty(1, 0);
    used_rsc = Resource.empty(1, 0);

    for k = 1:K
        slot_num = resource(k).tslot;
        i = resource(k).numerology + 1;
        for t = 1:length(slot_num)
            num_rb_perslot(i, slot_num(t)) = num_rb_perslot(i, slot_num(t)) + 1;
        end
    end

    % initialize the variables, solve symbol alloc without penalty
    for u = 1:NUM_DUE
        for k = 1:K
            tslot = resource(k).tslot;
            i = resource(k).numerology + 1;
            res_p(k, u) = 10^2.3 / max(max(num_rb_perslot(i, tslot)), 1);
        end
    end
    [check, res_s, res_comm, res_tx] = Init(resource, DUEs, RUE, res_p);
    if ~strcmp(check, 'Solved')
        return;
    end
    
    while diff >= tolerance
        [init_status, res_s, res_comm, res_tx] = AllocSymbol(resource, DUEs, RUE, res_p, abs(res_s), abs(res_comm), abs(res_tx), pfactor);
        if ~strcmp(init_status, 'Solved')
            return;
        end
        [st, p_tot, res_p] = AllocPower(resource, DUEs, RUE, abs(res_s), abs(res_comm), abs(res_tx));
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

    % check special cases: if there is only fractional solution, we ignore this result
    rpos = RUE.getPosition();
    used_slot = zeros([1, NUM_SLOT]); % the receiving time slots for RUE
    receiver_slot = zeros([NUM_NUMEROLOGY, NUM_SLOT]); % the receiver time slot for RUE
    comm_slot = zeros([NUM_DUE, NUM_SLOT]); % the communication time slots for every DUE
    tx_slot = zeros([NUM_DUE, NUM_NUMEROLOGY, NUM_SLOT]); % the transmitter time slots for every DUE
    for u = 1:NUM_DUE
        psave = psave + DUEs(u).getDirectEnergy();
        d = 0; % data bits of DUE u
        e = 0; % energy consumption of DUE u
        pos = DUEs(u).getPosition();
        for k = 1:K
            sinr = SINR_D2D(res_p(k, u), resource(k).bandwidth, pos.x, pos.y, pos.z, rpos.x, rpos.y, rpos.z);
            if round(res_s(k, u)) == 1
                d = d + round(res_s(k, u)) * resource(k).bandwidth * log2(1 + sinr) * resource(k).duration;
                e = e + round(res_s(k, u)) * res_p(k, u) * resource(k).duration;
                rx_energy = rx_energy + res_p(k, u) * RXratio(res_p(k, u), DUEs(u), RUE, resource(k)) * resource(k).duration;
                used_rsc(end + 1) = resource(k);
                for i = 1:length(resource(k).tslot)
                    used_slot(resource(k).tslot(i)) = 1;
                    receiver_slot(resource(k).numerology + 1, resource(k).tslot(i)) = 1;
                    tx_slot(u, resource(k).numerology + 1, resource(k).tslot(i)) = 1;
                    comm_slot(u, resource(k).tslot(i)) = 1;
                end
            end
        end

        e = e + 853/8 * sum(comm_slot(u, :)) * SLOT_DURATION;
        for i = 1:NUM_NUMEROLOGY
            for t = 1:NUM_SLOT
                e = e + tx_slot(u, i, t) * 29.9/8 * SLOT_DURATION;
                rx_energy = rx_energy + tx_slot(u, i, t) * 25.1/8 * SLOT_DURATION;
            end
        end

        if DUEs(u).getRequirement() > d + 1 | DUEs(u).getDirectEnergy() < e - 1 % +1 and -1 is for preventing error
            fprintf('fractional solution\n');
            psave = 0;
            status = 'Infeasible';
            return;
        end
        psave = psave - e;
    end

    for k = 1:K
        if ~ismember(resource(k), used_rsc)
            remaining_rsc(end + 1) = resource(k);
        end
    end

    status = cstatus;
end

function [status, res_s, res_comm, res_tx] = AllocSymbol(resource, DUEs, RUE, p, last_s, last_comm, last_tx, pfactor)
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
    global SLOT_DURATION;
    global NUM_NUMEROLOGY;
    K = length(resource);
    NUM_DUE = length(DUEs);
    rpos = RUE.getPosition();
    res_s = zeros([K, NUM_DUE]);
    res_comm = zeros([NUM_DUE, NUM_SLOT]);
    res_tx = zeros([NUM_DUE, NUM_NUMEROLOGY, NUM_SLOT]);

    cvx_begin quiet
        obj = 0;
        expression sub_databits(1, NUM_DUE);
        expression sub_energy(1, NUM_DUE);
        expression sub_power(NUM_DUE, NUM_SLOT);
        expression sub_alloc(1, K);
        expression sub_slot(NUM_DUE, NUM_SLOT);
        expression sub_tx(NUM_DUE, NUM_NUMEROLOGY, NUM_SLOT);
        variable comm_tslot(NUM_DUE, NUM_SLOT)
        variable tx_slot(NUM_DUE, NUM_NUMEROLOGY, NUM_SLOT);
        variable s(K, NUM_DUE)
        for u = 1:NUM_DUE
            for k = 1:K
                obj = obj + s(k, u) * p(k, u) * resource(k).duration/1e6 - pfactor * ((last_s(k, u)^2 - last_s(k, u)) + (last_s(k, u) * 2) * (s(k, u) - last_s(k, u)));
            end
            
            for t = 1:NUM_SLOT
                obj = obj + comm_tslot(u, t) * 853/8 * SLOT_DURATION/1e6 - pfactor * ((last_comm(u, t)^2 - last_comm(u, t)) + (last_comm(u, t) * 2) * (comm_tslot(u, t) - last_comm(u, t)));
            end

            for i = 1:NUM_NUMEROLOGY
                for t = 1:NUM_SLOT
                    obj = obj + tx_slot(u, i, t) * 29.9/8 * SLOT_DURATION/1e6 - pfactor * ((last_tx(u, i, t)^2 - last_tx(u, i, t)) + (last_tx(u, i, t) * 2) * (tx_slot(u, i, t) - last_tx(u, i, t)));
                end
            end
        end
        minimize (obj)
        res_s=s;
        res_comm=comm_tslot;
        res_tx=tx_slot;
        subject to
        for u = 1:NUM_DUE
            pos = DUEs(u).getPosition();
            for k = 1:K
                sinr = SINR_D2D(p(k, u), resource(k).bandwidth, pos.x, pos.y, pos.z, rpos.x, rpos.y, rpos.z);
                sub_databits(u) = sub_databits(u) + s(k, u) * resource(k).bandwidth * log(1 + sinr) / log(2) * resource(k).duration;
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
                sub_energy(u) = sub_energy(u) + comm_tslot(u,t) * 853/8 * SLOT_DURATION;
            end

            for i = 1:NUM_NUMEROLOGY
                for t = 1:NUM_SLOT
                    sub_energy(u) = sub_energy(u) + tx_slot(u, i, t) * 29.9/8 * SLOT_DURATION;
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
        for k = 1:K
            for u = 1:NUM_DUE
                sub_alloc(k) = sub_alloc(k) + s(k, u);
            end
        end
            for i = 1:K
                sub_alloc(i)<=1;
            end
            s>=0;
            s<=1;

            for u = 1:NUM_DUE
                for k = 1:K
                    for j = 1:length(resource(k).tslot)
                        t = resource(k).tslot(j);
                        sub_slot(u, t) = sub_slot(u, t) + s(k, u);
                        sub_tx(u, resource(k).numerology + 1, t) = sub_tx(u, resource(k).numerology + 1, t) + s(k, u);
                    end
                end
            end
            for u = 1:NUM_DUE
                for t = 1:NUM_SLOT
                    sub_slot(u, t) >= 1e-8 * comm_tslot(u, t);
                    sub_slot(u, t) <= K * comm_tslot(u, t);
                end
            end
            comm_tslot>=0;
            comm_tslot<=1;

            for u = 1:NUM_DUE
                for i = 1:NUM_NUMEROLOGY
                    for t = 1:NUM_SLOT
                        sub_tx(u, i, t) >= 1e-8 * tx_slot(u, i, t);
                        sub_tx(u, i, t) <= K * tx_slot(u, i, t);
                    end
                end
            end
            tx_slot>=0;
            tx_slot<=1;
    cvx_end

    status = cvx_status; 
    % fprintf('symbol alloc: %s, %d\n', status, cvx_optval);
    % for u = 1:NUM_DUE
    %     d = 0;
    %     r = 0;
    %     pos = DUEs(u).getPosition();
    %     rsc = DUEs(u).getPreResource();
    %     rpos = RUE.getPosition();
    %     for k =1:K
    %         sinr = SINR_D2D(p(k, u), resource(k).bandwidth, pos.x, pos.y, pos.z, rpos.x, rpos.y, rpos.z);
    %         d = d + res_s(k, u)*resource(k).bandwidth * log2(1 + sinr) * resource(k).duration;
    %         r = r + res_s(k, u) * p(k, u) * resource(k).duration;
    %         fprintf('Initial: UE %d: %e, %.2f\n', DUEs(u).getId(), full(res_s(k, u)), full(p(k, u)));
    %     end
    %     % fprintf('real data: %.2f\n', d);
    %     % fprintf('req data: %.2f\n', DUEs(u).getRequirement());
    %     % fprintf('real energy: %.2f\n', r);
    %     % fprintf('req energy: %.2f\n', DUEs(u).getDirectEnergy());
    % end
    % for u = 1:NUM_DUE
    %     for t = 1:NUM_SLOT
    %         fprintf('%.2f\n', res_t(u, t));
    %     end
    %     for k = 1:K
    %         if round(s(k, u)) == 1
    %             fprintf('power = %.2f\n', p(k, u));
    %             for j = 1:length(resource(k).tslot)
    %                 fprintf('%d, ', resource(k).tslot(j));
    %             end
    %             fprintf('\n');
    %         end
    %     end
    % end
end

function [status, res_s, res_comm, res_tx] = Init(resource, DUEs, RUE, p)
% The function provides initial symbol allocation for SCA, which serves as intial points
% @status(string): Infeasible if the resources are not enough for the DUEs
% @res_s: a K * NUM_DUE double matrix, stored the initial symbol allocation to the DUEs
% @resource: A Resource object array. the available resources in this problem
% @DUEs: A DUE object array. The DUEs are involved in this allocation problem.
% @RUE: An RUE object, which serves as relay for the DUEs.
% @p: a K * NUM_DUE double matrix, an initial power allocation for the SCA algorithm.

    global P_MAX;
    global NUM_SLOT;
    global SLOT_DURATION;
    global NUM_NUMEROLOGY;
    K = length(resource);
    NUM_DUE = length(DUEs);
    res_s = zeros([K, NUM_DUE]);
    res_comm = zeros([NUM_DUE, NUM_SLOT]);
    res_tx = zeros([NUM_DUE, NUM_NUMEROLOGY, NUM_SLOT]);
    rpos = RUE.getPosition();

    cvx_begin quiet
        obj = 0;
        expression sub_databits(1, NUM_DUE);
        expression sub_energy(1, NUM_DUE);
        expression sub_power(NUM_DUE, NUM_SLOT);
        expression sub_alloc(1, K);
        expression sub_slot(NUM_DUE, NUM_SLOT);
        expression sub_tx(NUM_DUE, NUM_NUMEROLOGY, NUM_SLOT);
        variable comm_tslot(NUM_DUE, NUM_SLOT);
        variable tx_slot(NUM_DUE, NUM_NUMEROLOGY, NUM_SLOT);
        variable s(K, NUM_DUE)
        for u = 1:NUM_DUE
            for k = 1:K
                obj = obj + s(k, u) * p(k, u) * resource(k).duration/1e6;
            end
            for t = 1:NUM_SLOT
                obj = obj + comm_tslot(u, t) * 853/8 * SLOT_DURATION/1e6;
            end
            for i = 1:NUM_NUMEROLOGY
                for t = 1:NUM_SLOT
                    obj = obj + tx_slot(u, i, t) * 29.9/8 * SLOT_DURATION/1e6;
                end
            end
        end
        minimize (obj)
        res_s=s;
        res_comm=comm_tslot;
        res_tx=tx_slot;
        subject to
        for u = 1:NUM_DUE
            pos = DUEs(u).getPosition();
            for k = 1:K
                sinr = SINR_D2D(p(k, u), resource(k).bandwidth, pos.x, pos.y, pos.z, rpos.x, rpos.y, rpos.z);
                sub_databits(u) = sub_databits(u) + s(k, u) * resource(k).bandwidth * log(1 + sinr) / log(2) * resource(k).duration;
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
                sub_energy(u) = sub_energy(u) + comm_tslot(u,t) * 853/8 * SLOT_DURATION;
            end
            for i = 1:NUM_NUMEROLOGY
                for t = 1:NUM_SLOT
                    sub_energy(u) = sub_energy(u) + tx_slot(u, i, t) * 29.9/8 * SLOT_DURATION;
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
        for k = 1:K
            for u = 1:NUM_DUE
                sub_alloc(k) = sub_alloc(k) + s(k, u);
            end
        end
            for i = 1:K
                sub_alloc(i)<=1;
            end
            s>=0;
            s<=1;
            for u = 1:NUM_DUE
                for k = 1:K
                    for j = 1:length(resource(k).tslot)
                        t = resource(k).tslot(j);
                        sub_slot(u, t) = sub_slot(u, t) + s(k, u);
                        sub_tx(u, resource(k).numerology + 1, t) = sub_tx(u, resource(k).numerology + 1, t) + s(k, u);
                    end
                end
            end
            for u = 1:NUM_DUE
                for t = 1:NUM_SLOT
                    sub_slot(u, t) >= 1e-8 * comm_tslot(u, t);
                    sub_slot(u, t) <= K * comm_tslot(u, t);
                end
            end
            comm_tslot>=0;
            comm_tslot<=1;

            for u = 1:NUM_DUE
                for i = 1:NUM_NUMEROLOGY
                    for t = 1:NUM_SLOT
                        sub_tx(u, i, t) >= 1e-8 * tx_slot(u, i, t);
                        sub_tx(u, i, t) <= K * tx_slot(u, i, t);
                    end
                end
            end
            tx_slot>=0;
            tx_slot<=1;
    cvx_end
    status = cvx_status;
    % for u = 1:NUM_DUE
    %     for k =1:K
    %         fprintf('Before SCA: UE %d: %.2f, %.2f\n', DUEs(u).getId(), full(res_s(k, u)), full(p(k, u)));
    %     end
    % end
    % fprintf('init status: %s\n', status);
end