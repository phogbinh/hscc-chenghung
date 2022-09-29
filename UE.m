classdef (HandleCompatible) UE < matlab.mixin.Heterogeneous
    properties (Access = private)
        id;
        position;
        demand;
        pre_resource;
        capacity;
    end
    methods (Sealed)
        %Make a copy of a handle object
        function newObj = copy(obj)
            objByteArray = getByteStreamFromArray(obj);
            newObj = getArrayFromByteStream(objByteArray);
        end

        function id = getId(obj)
            id = obj.id;
        end

        function pos = getPosition(obj)
            pos = obj.position;
        end

        function d = getDemand(obj)
            d = obj.demand;
        end

        function r = getPreResource(obj)
            r = obj.pre_resource;
        end

        function c = getCapacity(obj)
            c = 0;
            global BS_POSITION;
            for i = 1:length(obj.pre_resource)
                c = c + obj.pre_resource(i).bandwidth * ...
                log2(1 +SINR(obj.pre_resource(i), obj.position.x, obj.position.y, obj.position.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z)) * obj.pre_resource(i).duration;
            end
        end

        function energy = getDirectEnergy(obj)
            energy = 0;
            global NUM_SLOT;
            global SLOT_DURATION;
            global NUM_NUMEROLOGY;
            used_slot = zeros([NUM_NUMEROLOGY, NUM_SLOT]);
            comm_slot = zeros([1, NUM_SLOT]);
            for i = 1:length(obj.pre_resource)
                % fprintf('numerology-%d: ', obj.pre_resource(i).numerology);
                energy = energy + obj.pre_resource(i).duration * obj.pre_resource(i).tx_power;
                if obj.pre_resource(i).tx_power ~= 0
                    for t = 1:length(obj.pre_resource(i).tslot)
                        % fprintf('%d, ', obj.pre_resource(i).tslot(t));
                        used_slot(obj.pre_resource(i).numerology + 1, obj.pre_resource(i).tslot(t)) = 1;
                        comm_slot(obj.pre_resource(i).tslot(t)) = 1;
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
        end

        function setId(obj, id)
            obj.id = id;
        end

        function setPosition(obj, position)
            obj.position = position;
        end

        function setCapacity(obj, c)
            obj.capacity = c;
        end

        function setPreResource(obj, r)
            obj.pre_resource = r;
        end

        function addPreResource(obj, r)
            global BS_POSITION;
            obj.pre_resource(end + 1) = r;
            obj.capacity = obj.capacity + r.bandwidth * log2(1 + SINR(r, obj.position.x, obj.position.y, obj.position.z, BS_POSITION.x, BS_POSITION.y, BS_POSITION.z)) * r.duration;
        end

        function setDemand(obj, d)
            obj.demand = d;
        end

        function e = getDirectEnergyConsumption(obj)
            e = 0;
            global NUM_SLOT;
            global SLOT_DURATION;
            global NUM_NUMEROLOGY;
            power_per_slot = zeros([NUM_SLOT]);
            antenna_slot = zeros([NUM_NUMEROLOGY, NUM_SLOT]);
            for i = 1:length(obj.pre_resource)
                % fprintf('numerology-%d: ', obj.pre_resource(i).numerology);
                for t = 1:length(obj.pre_resource(i).tslot)
                    % fprintf('%d, ', obj.pre_resource(i).tslot(t));
                    slot = obj.pre_resource(i).tslot(t);
                    power_per_slot(slot) = power_per_slot(slot) + obj.pre_resource(i).tx_power;
                    if obj.pre_resource(i).tx_power ~= 0
                        antenna_slot(obj.pre_resource(i).numerology + 1, slot) = 1;
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
                if tx_power <= 10^0.02
                    tx_energy = 0.78 * 10*log10(tx_power) + 23.6;
                elseif tx_power > 10^0.02 & tx_power <= 10^1.14
                    tx_energy = 17 * 10*log10(tx_power) + 45.4;
                elseif tx_power > 10^1.14
                    tx_energy = 5.9 * (10*log10(tx_power))^2 - 118 * 10*log10(tx_power) + 1195;
                end
                e = e + (tx_energy + 0.62 + 853/8) * SLOT_DURATION;
            end
            % fprintf('\n');

            for i = 1:NUM_NUMEROLOGY
                for t = 1:NUM_SLOT
                    e = e + 29.9/8 * antenna_slot(i, t) * SLOT_DURATION;
                    % fprintf('%d, ', antenna_slot(i, t));
                end
                % fprintf('\n');
            end
        end

        function r = sumRateNR(obj)
            r = 0;
            bits = obj.getCapacity();
            time = 0;
            global NUM_SLOT;
            global SLOT_DURATION;
            used_slot = zeros([1, NUM_SLOT]);
            for i = 1:length(obj.pre_resource)
                if obj.pre_resource(i).tx_power ~= 0
                    for t = 1:length(obj.pre_resource(i).tslot)
                        used_slot(obj.pre_resource(i).tslot(t)) = 1;
                    end
                end
            end
            for i = 1:NUM_SLOT
                if used_slot(i) == 1
                    time = time + 1;
                end
            end
            fprintf('NR, bits %.2f, num of slot %.2f\n', bits, time);
            r = bits / (time * SLOT_DURATION);
        end
    end
end