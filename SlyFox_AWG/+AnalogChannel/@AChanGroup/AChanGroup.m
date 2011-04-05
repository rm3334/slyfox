classdef AChanGroup < hgsetget
    %ACHANGROUP Container for many ACHAN objects
    %   Container for 1 DAQs card worth of analog channels. Arguments for
    %   constructor are as follows:
    %        numChannels (number)
    %        groupName (String)
    %        channelNames (Cell Array - List of Names)
    %        HardwareProperties (Map)
    %          Keys: DriverName, DevName
    
    properties (SetAccess = private)
        myOutputData = [];
        myDevice = [];
    end
    
    properties
        myNumChannels = 1;
        myAChans = AChan('Ch0');
        myName = 'Dev0'
        myDisplay = [];
        myChanNames = {'Ch0'};
    end
    
    methods
        function obj = AChanGroup(varargin)
            if nargin >0
                obj.myNumChannels = varargin{1};
                obj.myName = varargin{2};
                %%%%%%%%%%%%% Steps 1 - assign values to "myValues"
                %%%%%%%%%%%%% Steps 2 - safely create device
                %%%%%%%%%%%%% Steps 3 - safely create channel objects
                
            end
        end
%%%%%%%%%%%%%%%%%% SET METHODS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function obj = set.myNumChannels(obj,value)
            if ~(value > 0)
                error('Number of Analog Channels must be positive')
            else
                 obj.myNumChannels = value;
            end
        end
        
        function obj = set.myName(obj, value)
            if ~ischar(value)
                error('Name of Channel Group must be String')
            else
                obj.myName = value;
            end
        end
        
%%%%%%%%%%%%%%%%%% ADD GET METHODS for AChanGroupFrontend
    end
    
end

