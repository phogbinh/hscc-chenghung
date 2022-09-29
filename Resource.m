classdef Resource < handle
% class definition of an RB or a symbol in an RB
% @id - a unique identifer of this particular resource(RB or symbol)
%       the id of the jth symbol in an RB with id I will be I + j / 10
% @numerology - the numerology of this RB/symbol
% @bandwidth  - the bandwidth of this RB/symbol (Hz)
% @duration   - the duration of this RB/symbol; symbol_duration = RB_duration/7 (ms)
% @isSymbol   - an indicator to show if this resource is symbol or not
% @tx_power   - the transmission power a user applies to this particular resource (mW)

    properties
        id; % [ti, fi]
        sid; % symbol number of Resource id, 1~7
        numerology;
        bandwidth;
        duration;
        isSymbol;
        tx_power;
        tslot; % will be an array of occupied time slots
    end
    methods
        % function obj = Resource(id, sid, numerology, bw, duration, isSymbol, tx_power)
        %     obj.id = id;
        %     obj.sid = sid;
        %     obj.numerology = numerology;
        %     obj.bandwidth = bw;
        %     obj.duration = duration;
        %     obj.isSymbol = isSymbol;
        %     obj.tx_power = tx_power;
        % end

        function init(obj, id, sid, numerology, bw, duration, isSymbol, tx_power)
            obj.id = id;
            obj.sid = sid;
            obj.numerology = numerology;
            obj.bandwidth = bw;
            obj.duration = duration;
            obj.isSymbol = isSymbol;
            obj.tx_power = tx_power;
        end

        function setSlot(obj, tslots)
            obj.tslot = tslots;
        end

        function newObj = copy(obj)
            objByteArray = getByteStreamFromArray(obj);
            newObj = getArrayFromByteStream(objByteArray);
        end
    end
end