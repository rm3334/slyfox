classdef AnalogVoltageStepper
    %ANALOGVOLTAGESTEPPER Steps Values of Analog Voltage Out by Ben Bloom
    %03/15/12
    
    properties
        myDEBUGmode = 0;
        myDAQSession = [];
        myTopFigure = [];
        mySingleScanData = [];
        myPanel = uiextras.Panel();
    end
    
    methods
        function obj = AnalogVoltageStepper(top, f)
            obj.myTopFigure = top;
            obj.myDEBUGmode = getappdata(obj.myTopFigure, 'DEBUGMODE');
            set(obj.myPanel, 'Parent', f);
            s1 = daq.getDevices;
            
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
                    'String', {s1(1:end).ID}, ...
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
            guidata(obj.myTopFigure, myHandles);
        end
        function updateSingleScanData_Callback(obj)
            %this is a two part function that both updates and initializes
            %the AnalogVoltageStepper
            if isempty(obj.myDAQSession)
                obj.myDAQSession = daq.createSession('ni');
            end
            myHandles = guidata(obj.myTopFigure);
            chVals = cell(8,1);
            for idx=0:7
                chVals{idx+1} = eval(get(myHandles.(['dev1a' int2str(idx)]), 'String'));
            end
            allCH = 1:8;
            chIDX = allCH(~cellfun(@isempty, chVals));
            
            % Removes channels
            obj.myDAQSession.removeChannel(1:length(obj.myDAQSession.Channels));
            devVal = get(myHandles.aDevName, 'Value');
            devNames = get(myHandles.aDevName, 'String');
            devName = devNames{devVal};
            
            obj.myDAQSession.addAnalogOutputChannel(devName, chIDX, 'Voltage');
            
            obj.mySingleScanData = combvec(chVals{chIDX});
            
            obj.myDAQSession.prepare
            guidata(obj.myTopFigure, myHandles);
        end
        
        function quit(obj)
            obj.myDEBUGmode = [];
            obj.mySingleScanData = [];
            obj.myTopFigure = [];
            delete(obj.myPanel);
            
            try
                obj.myDAQSession.removeChannel(1:length(obj.myDAQSession.Channels));
                obj.myDAQSession.release();
                obj.myDAQSession = [];
            catch
            end
        end
    end
    
end

