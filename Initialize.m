function [DUEs, RUEs] = Initialize(DUEs, RUEs, resc_mat)
% Run CVX iteratively to solve the pre-allocation problem
    global NUM_NUMEROLOGY;
    global NUM_MINI_SLOT;
    global MAX_POWER;
    resource = Resource.empty(1, 0);
    NUM_RUE = length(RUEs);
    NUM_DUE = length(DUEs);

    % mixed-numerology resources
    for i = 1:NUM_NUMEROLOGY
        [TI, FI] = size(resc_mat{i});
        for ti = 1:TI
            for fi = 1:FI
                resource(end + 1) = resc_mat{i}(ti, fi);
            end
        end
    end

    % fixed-numerology resources: 100 PRBs
    % uncomment here and change 58 in line 77 to 100 if you want to test with fixed-numerology cases
    % remember to comment the lines for mixed-numerology cases
    % rid = 1;
    % for i = 1:100
    %     r = Resource();
    %     r.init(rid, 0, 0, 180000, 1.0, false, tx_power);
    %     r.setSlot([1:NUM_MINI_SLOT]);
    %     resource(end + 1) = r;
    %     rid = rid + 1;
    % end

    % initial power allocation
    UEs = [DUEs, RUEs];
    r = 1.3 + (2.0 - 1.3) .* rand(length(UEs), 1);
    max_power_UE = zeros([1, length(UEs)]); % the maximum power each UE can apply on each time slot, dbm/10
    for i = 1:length(max_power_UE)
        if strcmp(class(UEs(i)), 'DUE')
            max_power_UE(i) = r(1); % should be i, this is a case i found JMRP would be worse
        else
            max_power_UE(i) = r(2);
        end
    end
    [res, res_s, res_p] = SCA_Init_Alloc(resource, UEs, max_power_UE);
    
    % Allocate the mini-slots according to the results of SCA
    for u = 1:length(UEs)
        % fprintf('UE %d\n', u);
        UEs(u).setPreResource(Resource.empty(1, 0));
        for k = 1:length(resource)
            if round(res_s(k, u)) == 1
                % fprintf('%.2f\n', full(res_p(k, u)));
                resource(k).tx_power = res_p(k, u);
                UEs(u).addPreResource(resource(k));
            end
        end
    end
end

function [cstatus, res_s, res_p] = SCA_Init_Alloc(resource, UEs, max_power_UE)
    global BS_POSITION;
    global NUM_SLOT;
    K = length(resource);
    NUM_UE = length(UEs);
    iter = 1;
    diff = 1;
    last_p_tot = 0;
    tolerance = 10^-5;
    pfactor = 2e4;
    cstatus = 'Infeasible';
    res_s = zeros([K, NUM_UE]);
    res_p = zeros([K, NUM_UE]);

    % Initialize
    for u = 1:NUM_UE
        for k = 1:K
            res_p(k, u) = 10^max_power_UE(u) / 58; % change 58 to the desired values with different setups
        end
    end
    
    [check, res_s] = Init(resource, UEs, res_p, max_power_UE);
    if ~strcmp(check, 'Solved')
        fprintf('Infeasible Allocation\n');
        return;
    end
    
    % SCA
    while diff >= tolerance
        [status, res_s] = allocSymbol(resource, UEs, res_p, abs(res_s), pfactor, max_power_UE);
        if strcmp(status , 'Infeasible')
            return;
        end
        [status, res_p] = allocPower(resource, UEs, abs(res_s), max_power_UE);
        if strcmp(status, 'Infeasible')
            return;
        end
        p_tot = 0;
        for u = 1:NUM_UE
            pos = UEs(u).getPosition();
            for k =1:k
                p_tot = p_tot + res_s(k, u) * resource(k).bandwidth/1e6 * log(1 + SINR2(res_p(k, u), resource(k).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z)) / log(2) * resource(k).duration;
            end
        end
        diff = abs(p_tot - last_p_tot);
        last_p_tot = p_tot;
        cstatus = status;
        iter = iter + 1;
        if iter >= 50
            break;
        end
        fprintf('iter = %d, diff = %e\n', iter, diff);
    end

    % Examine fractional solutions
    for u = 1:NUM_UE
        d = 0;
        for k = 1:K
            d = d + round(res_s(k, u));
        end
        if UEs(u).getDemand() > d
            fprintf('fractional solution\n');
            cstatus = 'Infeasible';
            return;
        end
    end
    cstatus = status;
end

function [res, res_s] = Init(resource, UEs, p, max_power_UE)
% Initialization for the SCA algorithm. We aim to generate initial s(k, u) for Taylor Series Approximation
    global BS_POSITION;
    global P_MAX;
    global NUM_SLOT;
    K = length(resource);
    NUM_UE = length(UEs);
    res_s = zeros([K, NUM_UE]);

    cvx_begin quiet
        obj = 0;
        expression sub_power(NUM_UE, NUM_SLOT);
        expression sub_alloc(K);
        expression sub_RBs(NUM_UE);
        variable s(K, NUM_UE)
        for u = 1:NUM_UE
            pos = UEs(u).getPosition();
            for k = 1:K
                obj = obj + s(k, u) * resource(k).bandwidth/1e6 * log(1 + SINR2(p(k, u), resource(k).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z)) / log(2) * resource(k).duration;
            end
        end
        maximize (obj)
        res_s=s;
        subject to
        for u = 1:NUM_UE
            for k = 1:K
                sub_RBs(u) = sub_RBs(u) + s(k, u);
            end
        end
        for u = 1:NUM_UE
            sub_RBs(u) >= UEs(u).getDemand();
        end

        for k = 1:K
            for u = 1:NUM_UE
                sub_alloc(k) = sub_alloc(k) + s(k, u);
            end
        end
            sub_alloc<=1;
            s>=0;
            s<=1;

        for u = 1:NUM_UE
            for k = 1:K
                for j = 1:length(resource(k).tslot)
                    t = resource(k).tslot(j); % the time slot number
                    sub_power(u, t) = sub_power(u, t) + s(k, u) * p(k, u);
                end
            end
        end
        for u = 1:NUM_UE
            for t = 1:NUM_SLOT
                sub_power(u, t) <= 10^max_power_UE(u);
            end
        end
    cvx_end

    res = cvx_status;
    fprintf('init status: %s\n', res);
end

function [res, res_s] = allocSymbol(resource, UEs, p, last_s, pfactor, max_power_UE)
    global BS_POSITION;
    global P_MAX;
    global NUM_SLOT;
    K = length(resource);
    NUM_UE = length(UEs);
    res_s = zeros([K, NUM_UE]);

    cvx_begin quiet
        obj = 0;
        expression sub_power(NUM_UE, NUM_SLOT);
        expression sub_alloc(K);
        expression sub_RBs(NUM_UE)
        variable s(K, NUM_UE)
        for u = 1:NUM_UE
            pos = UEs(u).getPosition();
            for k = 1:K
                obj = obj + s(k, u) * resource(k).bandwidth/1e6 * log(1 + SINR2(p(k, u), resource(k).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z)) / log(2) * resource(k).duration + pfactor * ((last_s(k, u)^2 - last_s(k, u)) + (last_s(k, u) * 2) * (s(k, u) - last_s(k, u)));
            end
        end
        maximize (obj)
        res_s=s;
        subject to
        for u = 1:NUM_UE
            for k = 1:K
                sub_RBs(u) = sub_RBs(u) + s(k, u);
            end
        end
        for u = 1:NUM_UE
            sub_RBs(u) >= UEs(u).getDemand();
        end

        for k = 1:K
            for u = 1:NUM_UE
                sub_alloc(k) = sub_alloc(k) + s(k, u);
            end
        end
            sub_alloc<=1;
            s>=0;
            s<=1;

        for u = 1:NUM_UE
            for k = 1:K
                for j = 1:length(resource(k).tslot)
                    t = resource(k).tslot(j);
                    sub_power(u, t) = sub_power(u, t) + s(k, u) * p(k, u);
                end
            end
        end
        for u = 1:NUM_UE
            for t = 1:NUM_SLOT
                sub_power(u, t) <= 10^max_power_UE(u);
            end
        end
    cvx_end

    res = cvx_status;
    fprintf('symbol alloc: %s\n', res);

    tot = 0;
    for u = 1:NUM_UE
        n = 0;
        for k =1:K
            n = n + round(res_s(k, u));
            % fprintf('pre-alloc, Initial: UE %d, rsc %d: new: %.5f, last: %.5f\n', UEs(u).getId(), k, full(res_s(k, u)), full(last_s(k, u)));
        end
        tot = tot + n;
        % fprintf('UE %d uses %.2f RB\n', UEs(u).getId(), n);
    end
    fprintf('total %.2f RBs in use\n', tot);

end

function [res, res_p] = allocPower(resource, UEs, s, max_power_UE)
    global BS_POSITION;
    global P_MAX;
    global NUM_SLOT;
    K = length(resource);
    NUM_UE = length(UEs);
    res_p = zeros([K, NUM_UE]);

    cvx_begin quiet
        obj = 0;
        expression sub_power(NUM_UE, NUM_SLOT);
        variable p(K, NUM_UE)
        for u = 1:NUM_UE
            pos = UEs(u).getPosition();
            for k = 1:K
                sinr = SINR2(p(k, u), resource(k).bandwidth, pos.x, pos.y, pos.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z);
                bps = log(1 +  sinr)/log(2);
                obj = obj + s(k, u) * resource(k).bandwidth * bps * resource(k).duration/1e6;
            end
        end
        maximize (obj)
        res_p=p;
        subject to
        for u = 1:NUM_UE
            for k = 1:K
                for j = 1:length(resource(k).tslot)
                    t = resource(k).tslot(j);
                    sub_power(u, t) = sub_power(u, t) + s(k, u) * p(k, u);
                end
            end
        end
        for u = 1:NUM_UE
            for t = 1:NUM_SLOT
                sub_power(u, t) <= 10^max_power_UE(u);
            end
        end
            p>=0;
    cvx_end

    res = cvx_status;
    fprintf('power alloc: %s\n', res);
end