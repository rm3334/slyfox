classdef AnalogVoltageCC < handle
    %ANALOGVOLTAGECC Quick Portal for sending out analog voltages with timing controlld via computer
    % by Ben Bloom
    %02/17/13
    
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
        function obj = AnalogVoltageCC(top, f)
            obj.myTopFigure = top;
            obj.myDEBUGmode = getappdata(obj.myTopFigure, 'DEBUGMODE');
            set(obj.myPanel, 'Parent', f);
            
            vb1 = uiextras.VBox('Parent', obj.myPanel);
            devHB = uiextras.HBox('Parent', vb1);
                uicontrol('Parent', devHB, ...
                    'Style', 'text', ...
                    'String', 'Device Name');
                uicontrol('Parent', devHB, ...
                    'Style', 'popup', ...
                    'String', 'Dev1', ...
                    'Tag', 'aDevName');
                dev1VB = uiextras.VBox('Parent', vb1);
                    for idx=0:7
                        eval(['dev1hb' int2str(idx) ' = uiextras.HButtonBox(''Parent'', dev1VB);']);
                        eval(['dev1Label' int2str(idx) ' = uicontrol(''Parent'', dev1hb' int2str(idx) ...
                            ', ''Style'', ''text'', ''String'', ''a' int2str(idx) ''');']);
                        eval(['dev1Label' int2str(idx) ' = uicontrol(''Parent'', dev1hb' int2str(idx) ...
                            ', ''Style'', ''edit'', ''String'', ''0'', ''Tag'', ''dev1a' int2str(idx) ''');']);
                    end
            uicontrol('Parent', vb1, ...
                'Style', 'pushbutton', ...
                'Tag', 'outputCurrentVoltages', ...
                'String', 'Output Current Voltages', ...
                'Callback', @obj.outputCurrentVoltages_Callback )
            vb1.Sizes = [-2 -8 -2];
            
            
            obj.myDAQSession = daq.createSession('ni');
            obj.myDAQSession.addAnalogOutputChannel('Dev1', 0:2, 'Voltage');
            
            myHandles = guihandles(obj.myTopFigure);
            guidata(obj.myTopFigure, myHandles);
            obj.outputCurrentVoltages_Callback();
        end
        function outputCurrentVoltages_Callback(obj, ~, ~)
            myHandles = guidata(obj.myTopFigure);
            chVals = cell(8,1);
            for idx=0:7
                tempStr = get(myHandles.(['dev1a' int2str(idx)]), 'String');
                if ~isempty(tempStr)
                    chVals{idx+1} = eval(tempStr);
                else
                    chVals{idx+1} = [];
                end
            end
            obj.mySingleScanData = cell2mat(chVals(1:3))';
            chVals(1:3)
            obj.myDAQSession.queueOutputData(obj.mySingleScanData);
            obj.myDAQSession.startBackground();

        end


        function quit(obj)
            obj.myDEBUGmode = [];
            obj.mySingleScanData = [];
            obj.myTopFigure = [];
            delete(obj.myPanel);
            
            try
                obj.myDAQSession.removeChannel(1:length(obj.myDAQSession.Channels));
                obj.myDAQSession.release();
                delete(obj.myDAQSession);
                obj.myDAQSession = [];
            catch
            end
        end
    end
    
end

