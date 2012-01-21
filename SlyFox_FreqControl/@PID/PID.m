classdef PID
    %PID PID controller
    %   This is a simple PID that holds that values of its gains, and the
    %   last summed error, and has functions for computing correction
    %   factors.
    %   Written by Ben Bloom. Last Updated 01/20/2012 18:01:00
    
    properties
        myPolarity = 1; %Polarity of error
        myKp = 0;       %Proportional Gain
        myKi = 0;       %Integral Gain
        myKd = 0;       %Derivative Gain
        myORange = 1;  %Clamped Output Range
        myIntE = 0;  %Record of ALL Previous Errors
        myE0 = 0;    %Previous output error
        myT0 = 0;   %Previous Evaluation Time
    end
    
    methods
        % Instantiates the object
        function obj = PID(pol, Kp, Ki, Kd, oRange)
            obj.myPolarity = pol;
            obj.myKp = Kp;
            obj.myKi = Ki;
            obj.myKd = Kd;
            obj.myORange = oRange;
        end
        
        %Calculates correction factor for Error for this Iteration and Updates Records
        %Nice Pseudocode from Wikipedia
        function u = calculate(obj, e1, t1)
            e1 = obj.myPolarity*e1;
            dt = t1 - obj.myT0;
            
            if obj.myT0 ~= 0
                %Calculate Integral
                obj.myIntE = obj.myIntE + e1*dt;
                %Calculate Derivative
                derivative = (e1 - obj.myE0)/dt;
            else
                derivative = 0;
            end
            
            %Calculate Output
            u = obj.myKp*e1 + obj.myKi*obj.myIntE + obj.myKd*derivative;
            
            %Clamp the outputs
            if abs(u) > obj.myORange
                if u <0
                    u = -1*obj.myORange;
                else
                    u = obj.myORange;
                end
            end
            
            %Update last Error and last Time.
            obj.myE0 = e1;
            obj.myT0 = t1;
        end
        
    end
    
end

