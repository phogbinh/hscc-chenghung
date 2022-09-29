classdef DUE < UE & handle
% class definition of a D2D user device.
% @id       - a unique identifier of this particular device
% @position - 3D coordinate
% @demand   - data rate requirement in the pre-allocation problem
% @pre_resource - RB allocation in the pre-allocation problem
% @grp_id - the identifier of the RUE that help relay data for this DUE
% @capacity - the energy consumption of this DUE when without relay
% @grp_resource - the symbol allocation in our main problem

    properties (Access = private)
        grp_RUE;
        grp_resource;
        grp_state;
    end
    methods
        % function obj = DUE(id, x, y, demand)
        %     obj.position = Coordinate(x, y, 1);
        %     obj.id = id;
        %     obj.capacity = 0; % set after pre-allocation
        %     obj.grp_id = 0;
        %     obj.demand = demand;
        % end
        function grp_RUE = getGrpRUE(obj)
            grp_RUE = obj.grp_RUE;
        end

        function power = getTotalPower(obj, rb)
            pslot = zeros([1, length(rb.tslot)]);
            power = 0;

            for i = 1:length(pslot)
                s = rb.tslot(i);
                for j = 1:length(obj.grp_resource)
                    if ismember(s, obj.grp_resource(j).tslot)
                        pslot(i) = pslot(i) + obj.grp_resource(j).tx_power;
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
            % fprintf('DUE%d-number of rsc: %d\n', obj.getId(), length(obj.grp_resource));
            used_slot = zeros([NUM_NUMEROLOGY, NUM_SLOT]);
            comm_slot = zeros([1, NUM_SLOT]);
            for i = 1:length(obj.grp_resource)
                % fprintf('numerology-%d: ', obj.grp_resource(i).numerology);
                if obj.grp_resource(i).tx_power ~= 0
                    energy = energy + obj.grp_resource(i).duration * obj.grp_resource(i).tx_power;
                    for t = 1:length(obj.grp_resource(i).tslot)
                        % fprintf('%d, ', obj.grp_resource(i).tslot(t));
                        used_slot(obj.grp_resource(i).numerology + 1, obj.grp_resource(i).tslot(t)) = 1;
                        comm_slot(obj.grp_resource(i).tslot(t)) = 1;
                    end
                    % fprintf('\n');
                end
            end

            for i = 1:NUM_NUMEROLOGY
                for t = 1:NUM_SLOT
                    energy = energy + used_slot(i, t) * 29.9/8 * SLOT_DURATION;
                    % fprintf('%d, ', used_slot(i, t));
                end
                % fprintf('\n');
            end

            for t = 1:NUM_SLOT
                energy = energy + comm_slot(t) * 853/8 * SLOT_DURATION;
                % fprintf('%d, ', comm_slot(t));
            end
            % fprintf('\n');
        end

        function r = getRequirement(obj)
            global BS_POSITION;
            r = 0;
            pre_resource = obj.getPreResource();
            pos = obj.getPosition();
            for i = 1:length(pre_resource)
                r = r + pre_resource(i).bandwidth * log2(1 + SINR(pre_resource(i), pos.x, pos.y, pos.z, ...
                                                        BS_POSITION.x, BS_POSITION.y, BS_POSITION.z)) * pre_resource(i).duration;
            end
        end

        function d = databits(obj)
            d = 0;
            pos = obj.getPosition();
            lpos = obj.grp_RUE.getPosition();
            for i = 1:length(obj.grp_resource)
                d = d + obj.grp_resource(i).bandwidth * log2(1 + SINR_D2D(obj.grp_resource(i).tx_power, obj.grp_resource(i).bandwidth, pos.x, pos.y, pos.z, ...
                                                        lpos.x, lpos.y, lpos.z)) * obj.grp_resource(i).duration;
            end
        end

        function setGrpRUE(obj, RUE)
            obj.grp_RUE = RUE;
        end

        function addGrpResource(obj, symbol)
            obj.grp_resource(end + 1) = symbol; 
        end

        function setGrpState(obj, s)
            obj.grp_state = s;
        end
        
        function setGrpResource(obj, r)
            obj.grp_resource = r;
        end

        function clearGrpResource(obj)
            obj.grp_resource = Resource.empty(1, 0);
        end
        
        function s = getGrpState(obj)
            s = obj.grp_state;
        end

        function gr = getGrpResource(obj)
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
                for t = 1:length(obj.grp_resource(i).tslot)
                    slot = obj.grp_resource(i).tslot(t);
                    power_per_slot(slot) = power_per_slot(slot) + obj.grp_resource(i).tx_power;
                    if obj.grp_resource(i).tx_power ~= 0
                        comm_slot(slot) = 1;
                        antenna_slot(obj.grp_resource(i).numerology + 1, slot) = 1;
                    end
                end
            end

            for t = 1:NUM_SLOT
                tx_energy = 0;
                tx_power = power_per_slot(t);
                if tx_power == 0
                    continue;
                end
                if tx_power <= 10^0.02
                    tx_energy = 0.78 * 10*log10(tx_power) + 23.6;
                elseif tx_power > 10^0.02 & tx_power <= 10^1.14
                    tx_energy = 17 * 10*log10(tx_power) + 45.4;
                elseif tx_power > 10^1.14
                    tx_energy = 5.9 * (10*log10(tx_power))^2 - 118 * 10*log10(tx_power) + 1195;
                end
                tx_energy = (tx_energy + 0.62) * SLOT_DURATION;
                e = e + tx_energy;
            end

            for i = 1:NUM_NUMEROLOGY
                for t = 1:NUM_SLOT
                    e = e + 29.9/8 * antenna_slot(i, t) * SLOT_DURATION;
                end
            end
            
            for t = 1:NUM_SLOT
                e = e + 853/8 * comm_slot(t) * SLOT_DURATION;
            end
        end

        function [e, rx_tslot, receiver_slot] = getRXEnergy(obj)
            e = 0;
            global NUM_SLOT;
            global SLOT_DURATION;
            global NUM_NUMEROLOGY;
            rpos = obj.grp_RUE.getPosition();
            pos = obj.getPosition();
            power_per_slot = zeros([NUM_SLOT]);
            bw_per_slot = zeros([NUM_SLOT]);
            rx_tslot = zeros(1, NUM_SLOT);
            receiver_slot = zeros([NUM_NUMEROLOGY, NUM_SLOT]);
            
            for i = 1:length(obj.grp_resource)
                % fprintf('numerology-%d: ', obj.grp_resource(i).numerology);
                for t = 1:length(obj.grp_resource(i).tslot)
                    slot = obj.grp_resource(i).tslot(t);
                    power_per_slot(slot) = power_per_slot(slot) + obj.grp_resource(i).tx_power;
                    bw_per_slot(slot) = bw_per_slot(slot) + obj.grp_resource(i).bandwidth;
                    if obj.grp_resource(i).tx_power ~= 0
                        rx_tslot(slot) = 1;
                        receiver_slot(obj.grp_resource(i).numerology + 1, slot) = 1;
                        % fprintf('%d, ', obj.grp_resource(i).tslot(t));
                    end
                end
                % fprintf('\n');
            end

            for t = 1:NUM_SLOT
                rx_energy = 0;
                tx_power = power_per_slot(t);
                bw = bw_per_slot(t);
                % fprintf('%.2f, ', tx_power);
                if tx_power == 0
                    continue;
                end
                if tx_power <= 10^-5.25
                    rx_energy = -0.04 * 10*log10(tx_power*chGain_D2D(bw, pos.x, pos.y, pos.z, rpos.x, rpos.y, rpos.z)) + 24.8;
                else
                    rx_energy = -0.11 * 10*log10(tx_power*chGain_D2D(bw, pos.x, pos.y, pos.z, rpos.x, rpos.y, rpos.z)) + 7.86;
                end
                sinr = SINR_D2D(tx_power, bw, pos.x, pos.y, pos.z, rpos.x, rpos.y, rpos.z);
                rate = bw * log2(1 + sinr) / 1e6;
                rx_energy = (rx_energy + 0.97 * rate + 8.16) * SLOT_DURATION;
                e = e + rx_energy;
            end
            % fprintf('\n');

            % for t = 1:NUM_SLOT
            %     fprintf('%d, ', rx_tslot(t));
            % end
            
            % for i = 1:NUM_NUMEROLOGY
            %     for t = 1:NUM_SLOT
            %         fprintf('%d, ', receiver_slot(i, t));
            %     end
            %     fprintf('\n');
            % end
            % fprintf('rx_energy: %e\n', rx_energy);
        end

        function [e, comm_slot, used_slot] = getApproxiRXEnergy(obj)
            e = 0;
            global NUM_SLOT;
            global SLOT_DURATION;
            global NUM_NUMEROLOGY;
            used_slot = zeros([NUM_NUMEROLOGY, NUM_SLOT]);
            comm_slot = zeros([1, NUM_SLOT]);
            rpos = obj.grp_RUE.getPosition();
            % fprintf('DUE%d-number of rsc: %d\n', obj.getId(), length(obj.grp_resource));
            
            for i = 1:length(obj.grp_resource)
                if obj.grp_resource(i).tx_power ~= 0
                    % fprintf('numerology-%d: ', obj.grp_resource(i).numerology);
                    e = e + obj.grp_resource(i).tx_power * obj.grp_resource(i).duration * RXratio(obj.grp_resource(i).tx_power, obj, obj.grp_RUE, obj.grp_resource(i));
                    for t = 1:length(obj.grp_resource(i).tslot)
                        used_slot(obj.grp_resource(i).numerology + 1, obj.grp_resource(i).tslot(t)) = 1;
                        comm_slot(obj.grp_resource(i).tslot(t)) = 1;
                        % fprintf('%d, ', obj.grp_resource(i).tslot(t));
                    end
                    % fprintf('\n')
                end
            end
            % fprintf('approxi_rx_energy: %e\n', e);
        end

        function r = sumRate(obj)
            r = 0;
            bits = 0;
            time = 0;
            global NUM_SLOT;
            global SLOT_DURATION;
            used_slot = zeros([1, NUM_SLOT]);
            if obj.grp_state == true
                bits = obj.databits();
                for i = 1:length(obj.grp_resource)
                    if obj.grp_resource(i).tx_power ~= 0
                        for t = 1:length(obj.grp_resource(i).tslot)
                            used_slot(obj.grp_resource(i).tslot(t)) = 1;
                        end
                    end
                end
            else
                bits = obj.getCapacity();
                pre_resource = obj.getPreResource();
                for i = 1:length(pre_resource)
                    if pre_resource(i).tx_power ~= 0
                        for t = 1:length(pre_resource(i).tslot)
                            used_slot(pre_resource(i).tslot(t)) = 1;
                        end
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