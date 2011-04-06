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
        myDevice = [];
    end
    
    properties (Dependent)
        myOutputData
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
                obj.myChanNames{:} = varargin{3}
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
        end % myNumChannels get function  
        function obj = set.myName(obj, value)
            if ~ischar(value)
                error('Name of Channel Group must be String')
            else
                obj.myName = value;
            end
        end % myName set function
        function obj = set.myChanNames(obj, value)
            if ~iscellstr(value) || length(value) ~= obj.myNumChannels
                error('Channel Names must be a Cell Array of Strings')
            else
                obj.myChanNames{:} = value;
                %%%% SET NAMES IN EVERY ACHAN
            end
        end % myChanNames get function    
        function obj = set.myOutputData(obj,~)
            fprintf('%s%d\n','OutputData is: ',obj.Modulus)
            error('You cannot set OutputData explicitly'); 
        end % myOutputData get function
        
        
%%%%%%%%%%%%%%%%%% ADD GET METHODS%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%SMART DESTRUCTOR%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%% ACTIVE/BUILDER Functions%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function addAChan - should be public
% function enableAChan - should be public  Start/Stops output without
%                       destroying waveform
% function disableAChan - should be public Start/Stops output without
%                       destroying waveform
% function uploadData - should be public
% function loadAChanGroup - should be public WRONG? - MAYBE SHOULD BE AS
% HIGH LEVEL AS POSSIBLE
% function saveAChanGroup - should be public WRONG? - MAYBE SHOULD BE AS
% HIGH LEVEL AS POSSIBLE
%%%%%%%%%%%%%%%%%%HELPER FUNCTIONS%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function assembleOutputData - should be private, needs to make everything
% 
% function findLongestWaveform - should be private
% function possibleSampleRates - should be public
    end
    
end

