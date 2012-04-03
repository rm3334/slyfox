classdef AnalogVoltageStepper < handle
    %ANALOGVOLTAGESTEPPER Steps Values of Analog Voltage Out by Ben Bloom
    %03/15/12
    
    properties
        myDEBUGmode = 0;
        myDAQSession = [];
        myTopFigure = [];
        mySingleScanData = [];
        myCounter = 0;
        myPanel = uiextras.Panel();
        myNames = [];
        myListener = [];
    end
    
    methods
        function obj = AnalogVoltageStepper(top, f)
            obj.myTopFigure = top;
            obj.myDEBUGmode = getappdata(obj.myTopFigure, 'DEBUGMODE');
            set(obj.myPanel, 'Parent', f);
%             s1 = daq.getDevices;
            s1 = daqhwinfo('nidaq');
            
            vb1 = uiextras.VBox('Parent', obj.myPanel);
            uicontrol('Parent', vb1, ...
                'Style', 'checkbox', ...
                'String', 'Step Analog Voltages?', ...
                'Tag', 'stepVoltages');
            devHB = uiextras.HBox('Parent', vb1);
                uicontrol('Parent', devHB, ...
                    'Style', 'text', ...
                    'String', 'Device Name');
                uicontrol('Parent', devHB, ...
                    'Style', 'popup', ...
                    'String', s1.ObjectConstructorName(:,2), ... %'String', {s1(1:end).ID}, ...
                    'Tag', 'aDevName');
                dev1VB = uiextras.VBox('Parent', vb1);
                    for idx=0:7
                        eval(['dev1hb' int2str(idx) ' = uiextras.HButtonBox(''Parent'', dev1VB);']);
                        eval(['dev1Label' int2str(idx) ' = uicontrol(''Parent'', dev1hb' int2str(idx) ...
                            ', ''Style'', ''text'', ''String'', ''a' int2str(idx) ''');']);
                        eval(['dev1Label' int2str(idx) ' = uicontrol(''Parent'', dev1hb' int2str(idx) ...
                            ', ''Style'', ''edit'', ''Tag'', ''dev1a' int2str(idx) ''');']);
                    end
            uicontrol('Parent', vb1, ...
                'Style', 'pushbutton', ...
                'Tag', 'updateSingleScanData', ...
                'String', 'Update Data and Initialize', ...
                'Callback', @obj.updateSingleScanData_Callback )
            vb1.Sizes = [-1 -2 -8 -2];
            myHandles = guihandles(obj.myTopFigure);
            setappdata(obj.myTopFigure, 'DAQcallback_DataRequired', @(src, event) eval('return'));
            guidata(obj.myTopFigure, myHandles);
        end
        function updateSingleScanData_Callback(obj, ~, ~)
            %this is a two part function that both updates and initializes
            %the AnalogVoltageStepper
            myHandles = guidata(obj.myTopFigure);
            if ~isempty(obj.myDAQSession)
%                 obj.myDAQSession.release();
%                 obj.myDAQSession = [];
                  set(obj.myDAQSession,'StopFcn','');
                  stop(obj.myDAQSession);
                  delete(obj.myDAQSession);
                  obj.myDAQSession = [];
            end
            devVal = get(myHandles.aDevName, 'Value');
            devNames = get(myHandles.aDevName, 'String');
            devConstructor = devNames{devVal};
            obj.myDAQSession = eval(devConstructor);
%                 obj.myDAQSession.IsContinuous = true;
%                 obj.myListener = addlistener(obj.myDAQSession,'DataRequired',@obj.queueMoreData);
            set(obj.myDAQSession,'TriggerType', 'HwDigital');
            set(obj.myDAQSession,'SampleRate',100000);
            set(obj.myDAQSession,'HwDigitalTriggerSource', 'PFI0')
            set(obj.myDAQSession, 'TriggerCondition', 'PositiveEdge');
            set(obj.myDAQSession,'StopFcn',@obj.queueMoreData);
            chVals = cell(8,1);
            for idx=0:7
                tempStr = get(myHandles.(['dev1a' int2str(idx)]), 'String');
                if ~isempty(tempStr)
                    chVals{idx+1} = eval(tempStr);
                else
                    chVals{idx+1} = [];
                end
            end
            allCH = 0:7;
            chIDXni = allCH(~cellfun(@isempty, chVals));
            
            % Removes channels
%             numOldChannels = length(obj.myDAQSession.Channels);
%             if numOldChannels ~= 0
%                 obj.myDAQSession.removeChannel(1:numOldChannels);
%             end
            devVal = get(myHandles.aDevName, 'Value');
            devNames = get(myHandles.aDevName, 'String');
            devName = devNames{devVal};
            
%             obj.myDAQSession.addAnalogOutputChannel(devName, chIDXni, 'Voltage');
%             obj.myDAQSession.addTriggerConnection('External',[devName '/PFI0'],'StartTrigger');
            obj.myNames = arrayfun(@(x) ['a' num2str(x)], chIDXni, 'UniformOutput', 0);
            addchannel(obj.myDAQSession, chIDXni, obj.myNames);
%             obj.mySingleScanData = combvec(chVals{chIDXni+1})';
%             temp = cell()
            obj.mySingleScanData = cell2mat(chVals(chIDXni+1))'
%             obj.myNames = {obj.myDAQSession.Channels(:).ID};
            dataToOutput = cell2mat(arrayfun(@(x) x*ones(1,500)', obj.mySingleScanData(1,:), 'UniformOutput', 0));
            setappdata(obj.myTopFigure, 'DAQdata', dataToOutput);
%             obj.myDAQSession.queueOutputData(dataToOutput);
%             obj.myDAQSession.startBackground();
            putdata(obj.myDAQSession, dataToOutput);
            start(obj.myDAQSession);
            set(myHandles.updateSingleScanData, 'BackgroundColor', 'g');
            guidata(obj.myTopFigure, myHandles);
        end
        function [prevSet, curSet, nextSet] = getNextAnalogValues(obj)
            prevIDX = mod(obj.myCounter, length(obj.mySingleScanData))+1;
            curIDX = mod(obj.myCounter + 1, length(obj.mySingleScanData))+1;
            nextIDX = mod(obj.myCounter + 2, length(obj.mySingleScanData))+1;
            prevSet = obj.mySingleScanData(prevIDX,:);
            curSet = obj.mySingleScanData(curIDX,:);
            nextSet = obj.mySingleScanData(nextIDX,:);
        end
        function incrementCounter(obj)
            obj.myCounter = obj.myCounter + 1;
        end
        function queueMoreData(obj, src, event)
%             disp('callback')
            temp1 = getappdata(obj.myTopFigure, 'DAQdata');
%             temp1(1)
%             obj.myDAQSession.queueOutputData(temp1);
            putdata(obj.myDAQSession, temp1);
            start(obj.myDAQSession);
        end
        function quit(obj)
            try
                delete(obj.myListener);
            catch
            end
            obj.myDEBUGmode = [];
            obj.mySingleScanData = [];
            obj.myTopFigure = [];
            delete(obj.myPanel);
            
            try
%                 obj.myDAQSession.removeChannel(1:length(obj.myDAQSession.Channels));
%                 obj.myDAQSession.release();
%                 obj.myDAQSession = [];
                  set(obj.myDAQSession,'StopFcn','');
                  stop(obj.myDAQSession);
                  delete(obj.myDAQSession);
                  obj.myDAQSession = [];
            catch
            end
        end
    end
    
end

