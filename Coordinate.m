classdef Coordinate < handle 
    properties
        x, y, z;
    end
    methods
        function obj = Coordinate(x, y, z)
            obj.x = x;
            obj.y = y;
            obj.z = z;
        end
    end
end
