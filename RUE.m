classdef RUE < UE & handle
% class definition of a Relay user device, which help relay DUE's data
% @id       - a unique identifier of this particular device
% @position - 3D coordinate
% @demand   - data rate requirement in the pre-allocation problem
% @pre_resource - RB allocation in the pre-allocation problem
% @capacity - the energy consumption of this DUE when without relay
% @grp_resource - the symbol allocation in our main problem
% @grp_req   - the total bits this device should transmit to the BS
% @grp_members  - the DUEs that are assigned to this RUE, they will be helped
%                 by this device

    properties (Access = private)
        grp_resource;
        grp_req;
        grp_members;
    end
    methods
        % function obj = RUE(id, x, y, demand)
        %     obj.position = Coordinate(x, y, 1);
        %     obj.id = id;
        %     obj.demand = demand;
        %     obj.pre_resource = Resource.empty();
        %     obj.capacity = 0; % set after pre-allocation
        %     obj.grp_members = DUE.empty();
        %     obj.grp_resource = Resource.empty();
        % end

        function members = getGrpMembers(obj)
            members = obj.grp_members;
        end
        
        function power = getTotalPower(obj, rb)
            pslot = zeros([1, length(rb.tslot)]);
            power = 0;

            for i = 1:length(pslot)
                s = rb.tslot(i);
                for j = 1:length(obj.grp_resource)
                    if ismember(s, obj.grp_resource(j).tslot)
                        pslot(i) = pslot(i) + obj.grp_resource(j).tx_power;
                        % fprintf('%dth symbol with p:%d\n', j, obj.grp_resource(j).tx_power);
                    end
                end
            end
            power= max(pslot);
        end

        function energy = getTotalEnergy(obj)
            energy = 0;
            global NUM_SLOT;
            global SLOT_DURATION;
            global NUM_NUMEROLOGY;
            used_slot = zeros([NUM_NUMEROLOGY, NUM_SLOT]);
            comm_slot = zeros([1, NUM_SLOT]);
            receiver_slot = zeros([NUM_NUMEROLOGY, NUM_SLOT]);
            for i = 1:length(obj.grp_resource)
                if obj.grp_resource(i).tx_power ~= 0
                    energy = energy + obj.grp_resource(i).duration * obj.grp_resource(i).tx_power;
                    % fprintf('numerology-%d: ', obj.grp_resource(i).numerology);
                    for t = 1:length(obj.grp_resource(i).tslot)
                        % fprintf('%d, ', obj.grp_resource(i).tslot(t));
                        used_slot(obj.grp_resource(i).numerology + 1, obj.grp_resource(i).tslot(t)) = 1;
                        comm_slot(obj.grp_resource(i).tslot(t)) = 1;
                    end
                    % fprintf('\n');
                end
            end
            % fprintf('tx1: %.2f\n', energy);
            for i = 1:NUM_NUMEROLOGY
                for t = 1:NUM_SLOT
                    energy = energy + used_slot(i, t) * 29.9/8 * SLOT_DURATION;
                    % fprintf('%d, ', used_slot(i, t));
                end
                % fprintf('\n');
            end
            % fprintf('tx2: %.2f\n', energy);
            re = 0;
            for i = 1:length(obj.grp_members)
                [rx_energy, rx_slot, receiver_slot_DUE] = obj.grp_members(i).getApproxiRXEnergy();
                energy = energy + rx_energy;
                re = re + rx_energy;
                for t = 1:NUM_SLOT
                    % fprintf('%d, ', rx_slot(t));
                    if rx_slot(t) == 1
                        comm_slot(t) = 1;
                    end
                end
                % fprintf(', rx\n');
                for numer = 1:NUM_NUMEROLOGY
                    for t = 1:NUM_SLOT
                        energy = energy + receiver_slot_DUE(numer, t) * 25.1/8 * SLOT_DURATION;
                        % fprintf('%d, ', receiver_slot_DUE(numer, t));
                    end
                    % fprintf('\n');
                end
            end
            
            for t = 1:NUM_SLOT
                energy = energy + comm_slot(t) * 853/8 * SLOT_DURATION;
                % fprintf('%d, ', comm_slot(t));
            end
            % fprintf('\ntx3: %.2f\n', energy);
        end

        function r = getRequirement(obj)
            r = 0;
            pre_resource = obj.getPreResource();
            pos = obj.getPosition();
            global BS_POSITION;
            for i = 1:length(pre_resource)
                r = r + pre_resource(i).bandwidth * log2(1 + SINR(pre_resource(i), pos.x, pos.y, pos.z, ...
                                                        BS_POSITION.x, BS_POSITION.y, BS_POSITION.z))* pre_resource(i).duration;
            end

            for i = 1:length(obj.grp_members)
                r = r + obj.grp_members(i).getRequirement();
            end
        end

        function r = getMemberRequirement(obj)
            r = 0;
            for i = 1:length(obj.grp_members)
                r = r + obj.grp_members(i).getRequirement();
            end
        end

        function d = databits(obj)
            d = 0;
            global BS_POSITION;
            pos = obj.getPosition();
            for i = 1:length(obj.grp_resource)
                d = d + obj.grp_resource(i).bandwidth * log2(1 + SINR(obj.grp_resource(i), pos.x, pos.y, pos.z, ...
                                                        BS_POSITION.x, BS_POSITION.y, BS_POSITION.z)) * obj.grp_resource(i).duration;
            end
        end
        
        function setGrpResource(obj, r)
            obj.grp_resource = r;
        end
        
        function setGrpMembers(obj, m)
            obj.grp_members = m;
        end
        
        function setGrpReq(obj, r)
            obj.grp_req = r;
        end

        function addtoGroup(obj, DUE)
            obj.grp_req = obj.grp_req + DUE.getRequirement();
            obj.grp_members(end + 1) = DUE;
            DUE.setGrpRUE(obj);
        end

        function rmGrpMember(obj, DUE)
            % this is correct only when DUE is a single object
            obj.grp_req = obj.grp_req - DUE.getRequirement();
            tmp_grp_members = obj.grp_members;
            for i = 1:length(tmp_grp_members)
                if tmp_grp_members(i).getId() == DUE.getId()
                    obj.grp_members(i) = [];
                    break;
                end
            end
            DUE.setGrpRUE(RUE());
        end

        function addGrpResource(obj, symbol)
            obj.grp_resource(end + 1) = symbol; 
        end

        function clearGrpResource(obj)
            obj.grp_resource = Resource.empty(1, 0);
        end

        function gr =getGrpResource(obj)
            gr = obj.grp_resource;
        end

        function e = getEnergyConsumption(obj)
            e = 0;
            global NUM_SLOT;
            global SLOT_DURATION;
            global NUM_NUMEROLOGY;
            power_per_slot = zeros([NUM_SLOT]);
            comm_slot = zeros([1, NUM_SLOT]);
            antenna_slot = zeros([NUM_NUMEROLOGY, NUM_SLOT]);
            
            for i = 1:length(obj.grp_resource)
                % fprintf('numerology-%d: ', obj.grp_resource(i).numerology);
                for t = 1:length(obj.grp_resource(i).tslot)
                    % fprintf('%d, ', obj.grp_resource(i).tslot(t));
                    slot = obj.grp_resource(i).tslot(t);
                    power_per_slot(slot) = power_per_slot(slot) + obj.grp_resource(i).tx_power;
                    if obj.grp_resource(i).tx_power ~= 0
                        antenna_slot(obj.grp_resource(i).numerology + 1, slot) = 1;
                    end
                end
                % fprintf('\n');
            end

            for t = 1:NUM_SLOT
                tx_energy = 0;
                tx_power = power_per_slot(t);
                % fprintf('%.2f, ', tx_power);
                if tx_power == 0
                    continue;
                end
                comm_slot(t) = 1;
                if tx_power <= 10^0.02
                    tx_energy = 0.78 * 10*log10(tx_power) + 23.6;
                elseif tx_power > 10^0.02 & tx_power <= 10^1.14
                    tx_energy = 17 * 10*log10(tx_power) + 45.4;
                elseif tx_power > 10^1.14
                    tx_energy = 5.9 * (10*log10(tx_power))^2 - 118 * 10*log10(tx_power) + 1195;
                end
                e = e + (tx_energy + 0.62) * SLOT_DURATION;
            end
            % fprintf('\n');
            for i = 1:NUM_NUMEROLOGY
                for t = 1:NUM_SLOT
                    e = e + 29.9/8 * antenna_slot(i, t) * SLOT_DURATION;
                    % fprintf('%d, ', antenna_slot(i, t));
                end
                % fprintf('\n');
            end

            for i = 1:length(obj.grp_members)
                [rx_energy, rx_tslot, receiver_slot_DUE] = obj.grp_members(i).getRXEnergy();
                e = e + rx_energy;
                % fprintf('rx_energy: %.2f\n', rx_energy);
                % comm_slot = comm_slot | rx_tslot;
                for t = 1:NUM_SLOT
                    % fprintf('%d, ', rx_tslot(t));
                    if rx_tslot(t) == 1
                        comm_slot(t) = 1;
                    end
                end
                % fprintf(', rx\n');
                for numer = 1:NUM_NUMEROLOGY
                    for t = 1:NUM_SLOT
                        e = e + receiver_slot_DUE(numer, t) * 25.1/8 * SLOT_DURATION;
                        % fprintf('%d, ', receiver_slot_DUE(numer, t));
                    end
                    % fprintf('\n');
                end
            end
            
            for i = 1:NUM_SLOT
                e = e + comm_slot(i) * 853/8 * SLOT_DURATION;
                % fprintf('%d, ', comm_slot(t));
            end
        end

        function r = sumRate(obj)
            r = 0;
            bits = obj.databits();
            time = 0;
            global NUM_SLOT;
            global SLOT_DURATION;
            used_slot = zeros([1, NUM_SLOT]);
            for i = 1:length(obj.grp_resource)
                if obj.grp_resource(i).tx_power ~= 0
                    for t = 1:length(obj.grp_resource(i).tslot)
                        used_slot(obj.grp_resource(i).tslot(t)) = 1;
                    end
                end
            end
            for i = 1:NUM_SLOT
                if used_slot(i) == 1
                    time = time + 1;
                end
            end
            fprintf('%.2f, %.2f\n', bits, time);
            r = bits / (time * SLOT_DURATION);
        end
    end
end