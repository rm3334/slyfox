classdef seriesPID < handle
    %SERIESPID Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        myPIDs = {};
    end
    
    methods
        function obj = seriesPID(cellPIDs)
            obj.myPIDs = cellPIDs;
        end
        function u = calculate(obj, e1, t1)
            for count=1:length(obj.myPIDs)
                u = obj.myPIDs{count}.calculate(e1, t1);
                e1 = u;
            end
        end
        function setPolarity(obj, pol)
            for count=1:length(obj.myPIDs)
                obj.myPIDs{count}.myPolarity = pol;
            end
        end
        function reset(obj)
            for count=1:length(obj.myPIDs)
                obj.myPIDs{count}.reset();
            end
        end
        function clear(obj)
            for count=1:length(obj.myPIDs)
                obj.myPIDs{count}.clear();
            end
        end
    end
    
end

