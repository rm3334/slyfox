classdef PID_gui < hgsetget
    %PID_GUI Frontend for tuning up a software controlled PID
    %   Frontend for a software controlled PID which includes inputs for
    %   gains, plotted error as a function of time, and FFT of the error as
    %   a function of time, log file save location, etc.
    
    properties
        myTopFigure = [];
        myTitlePanel = [];
        myPanel = [];
        myPID;
        myName;
        myPlotHandle = [];
        myKp = [];
        myKi = [];
        myKd = [];
        myDeltaT = [];
        mySetPoint = [];
        myEnableBox = [];
        mySaveLog = [];
    end
    
    methods
        function obj = PID_gui(topFig, parentObj, myName)
            obj.myTopFigure = topFig;
            obj.myName = myName;
            obj.myPID = PID.PID(1,0,0,0,10);
            obj.myTitlePanel = uiextras.Panel('Parent', parentObj, ...
                'Title', ['PID ' num2str(myName)]);
            obj.myPanel = uiextras.HBox('Parent', obj.myTitlePanel, ...
                'Spacing', 5, ...
                'Padding', 5);
            mainControlsVB = uiextras.VBox('Parent', obj.myPanel, ...
                'Spacing', 5, ...
                'Padding', 5);
                gainsPanel = uiextras.Panel('Parent', mainControlsVB, ...
                    'Title', 'Gains');
                gainsHB = uiextras.HBox('Parent', gainsPanel);
                gainLabels = uiextras.VButtonBox('Parent', gainsHB, ...
                'Spacing', 5, ...
                'Padding', 5);
                    uicontrol('Parent', gainLabels, ...
                        'Style', 'text', ...
                        'FontSize', 14, ...
                        'String', 'Kp');
                    uicontrol('Parent', gainLabels, ...
                        'Style', 'text', ...
                        'FontSize', 14, ...
                        'String', 'Ki');
                    uicontrol('Parent', gainLabels, ...
                        'Style', 'text', ...
                        'FontSize', 14, ...
                        'String', 'Kd');
                    uicontrol('Parent', gainLabels, ...
                        'Style', 'text', ...
                        'FontSize', 14, ...
                        'String', 'Set Point');
                    uicontrol('Parent', gainLabels, ...
                        'Style', 'text', ...
                        'FontSize', 14, ...
                        'String', 'Delta t');
                gainsEdits = uiextras.VButtonBox('Parent', gainsHB, ...
                'Spacing', 5, ...
                'Padding', 5);
                    obj.myKp = uicontrol('Parent', gainsEdits, ...
                        'Style', 'edit', ...
                        'Tag', 'kP', ...
                        'String', '0');
                    obj.myKi = uicontrol('Parent', gainsEdits, ...
                        'Style', 'edit', ...
                        'Tag', 'kI', ...
                        'String', '0');
                    obj.myKd = uicontrol('Parent', gainsEdits, ...
                        'Style', 'edit', ...
                        'Tag', 'kD', ...
                        'String', '0');
                    obj.mySetPoint = uicontrol('Parent', gainsEdits, ...
                        'Style', 'edit', ...
                        'Tag', 'setPoint', ...
                        'String', '0');
                    obj.myDeltaT = uicontrol('Parent', gainsEdits, ...
                        'Style', 'edit', ...
                        'Tag', 'deltaT', ...
                        'String', '0');
                    savePathVB = uiextras.VBox(...
                        'Parent', mainControlsVB, ...
                        'Spacing', 5, ...
                        'Padding', 1);
                        pidButtons = uiextras.HButtonBox('Parent', savePathVB);
                        obj.mySaveLog = uicontrol( ...
                            'Parent', pidButtons, ...
                            'Style', 'checkbox', ...
                            'String', 'Save Log File?', ...
                            'Tag', 'saveLog', ...
                            'Value', 1);
                        obj.myEnableBox = uicontrol( ...
                            'Parent', pidButtons, ...
                            'Style', 'checkbox', ...
                            'String', 'Enable PID', ...
                            'Tag', 'pidEnabled');
                        pathHB = uiextras.HBox(...
                            'Parent', savePathVB, ...
                            'Spacing', 5, ...
                            'Padding', 5);
                            uicontrol(...
                                'Parent', pathHB, ...
                                'Style', 'pushbutton', ...
                                'Tag', ['getSaveDir' obj.myName], ...
                                'String', 'SaveDir', ...
                                'Callback', @obj.getSaveDir_Callback);
                            uicontrol(...
                                'Parent', pathHB, ...
                                'Style', 'edit', ...
                                'String', 'Z:\Sr3\data', ...
                                'Tag', ['saveDirPID' obj.myName]);
                            set(pathHB, 'Sizes', [60 -1]);
                        set(savePathVB, 'Sizes', [-2 -1]);
                        tempPAN = obj.myPanel; %Needed for older matlabs
                    errPlot = axes( 'Parent', tempPAN, ...
                        'Tag', ['err_PID' obj.myName ], ...
                        'ActivePositionProperty', 'OuterPosition');
                        title(errPlot, 'Error Signal');
                    errFFT = axes( 'Parent', tempPAN, ...
                        'ActivePositionProperty', 'OuterPosition');
                        title(errFFT, 'Error FFT');
        end
        
        function updateMyPlots(obj, newErr, runNum, plotstart)
            myHandles = guidata(obj.myTopFigure);
            tempPIDData = getappdata(obj.myTopFigure, ['PID' obj.myName 'Data']);
            if isempty(obj.myPlotHandle) || plotstart > 2 % this should really be fixed
                obj.myPlotHandle = plot(myHandles.(['err_PID' obj.myName]), tempPIDData, 'ok', 'LineWidth', 3);
            elseif runNum > 2
                set(obj.myPlotHandle, 'YData', tempPIDData);
                refreshdata(obj.myPlotHandle);
            end
            guidata(obj.myTopFigure, myHandles);
        end
        function getSaveDir_Callback(obj, src, eventData)      
            myHandles = guidata(obj.myTopFigure);
            dirPath = uigetdir(['Z:\Sr3\data']);
            set(myHandles.saveDir, 'String', dirPath);
            guidata(obj.myTopFigure, myHandles);
        end
    end
    
end

