classdef FreqSweeper < handle
    %FREQSWEEPER Sweeps Frequency of FreqSynth and Plots Results
    %   Creates a nice user interface to watch a frequency sweep take place
    %   and edit its characteristics.
    
    properties
        myPanel = uiextras.Panel();
        myTopFigure = [];
        myFreqSynth = [];
        myTimeSynth = [];
        myGageConfigFrontend = [];
        myLCuControl = [];
        myCycleNuControl = [];
        myClient = [];
        mySweepModes = [];
    end
    
    methods
        function obj = FreqSweeper(top,f)
            obj.myTopFigure = top;
            obj.myPanel.Parent = f;
            
            %%%%Layout Manager Stuff
            %Splits the Window into 3 main Sections
            hsplit = uiextras.HBox(...
                'Parent', obj.myPanel, ...
                'Tag', 'hsplit', ...
                'Spacing', 5, ...
                'Padding', 5);
            
                %%First Section is for controls of
                %Frequency/Cursors/Starting and Stopping
                uiVB = uiextras.VBox(...
                    'Parent', hsplit, ...
                    'Tag', 'uiVB', ...
                    'Spacing', 5, ...
                    'Padding', 5);
                
                    %Spacer Box
                    uiextras.Empty('Parent', uiVB);
                    %Fit Readout box
                    fitButtonHB = uiextras.HBox(...
                            'Parent', uiVB, ...
                            'Spacing', 5, ...
                            'Padding', 5);
                            uicontrol(...
                                'Parent', fitButtonHB,...
                                'Style', 'pushbutton', ...
                                'Tag', 'fitLorentzian',...
                                'String', 'Fit Lorentzian', ...
                                'Callback', @obj.fitLorentzian_Callback);
                            fitResultsCenteringVB = uiextras.VBox(...
                                'Parent', fitButtonHB);
                                uiextras.Empty('Parent', fitResultsCenteringVB);
                                uicontrol(...
                                    'Parent', fitResultsCenteringVB,...
                                    'Style', 'text',...
                                    'Tag', 'fitResults',...
                                    'FontWeight', 'bold',...
                                    'String', 'FWHM:');
                                uiextras.Empty('Parent', fitResultsCenteringVB);
                    %CursorButtons Box
                    cursorButtonVB = uiextras.VBox(...
                        'Parent', uiVB);
                        cursorReadoffsHB = uiextras.HBox(...
                            'Parent', cursorButtonVB, ...
                            'Spacing', 5, ...
                            'Padding', 5);
                            uicontrol(...
                                    'Parent', cursorReadoffsHB,...
                                    'Style', 'edit', ...
                                    'Tag', 'c1Freq',...
                                    'String', '0');
                            uicontrol(...
                                    'Parent', cursorReadoffsHB,...
                                    'Style', 'pushbutton', ...
                                    'Tag', 'grabCursorButton',...
                                    'String', 'Grab', ...
                                    'Callback', @obj.grabCursorButton_Callback);
                            uicontrol(...
                                    'Parent', cursorReadoffsHB,...
                                    'Style', 'pushbutton', ...
                                    'Tag', 'setCursorButton',...
                                    'String', 'Set', ...
                                    'Callback', @obj.setCursorButton_Callback);
                            uicontrol(...
                                    'Parent', cursorReadoffsHB,...
                                    'Style', 'edit', ...
                                    'Tag', 'c2Freq',...
                                    'String', '1');
                        cursorButtonHB = uiextras.HBox(...
                            'Parent', cursorButtonVB, ...
                            'Spacing', 5, ...
                            'Padding', 5);
                            uiextras.Empty('Parent', cursorButtonHB);
                            uicontrol(...
                                    'Parent', cursorButtonHB,...
                                    'Style', 'checkbox', ...
                                    'Tag', 'cursorToggle',...
                                    'Value', 1, ...
                                    'String', 'Use Cursors', ...
                                    'Callback', @obj.cursorToggle_Callback);
                            uicontrol(...
                                    'Parent', cursorButtonHB,...
                                    'Style', 'checkbox', ...
                                    'Tag', 'ignoreFirstToggle',...
                                    'Value', 0, ...
                                    'String', 'Ignore First Data Point');
                            uiextras.Empty('Parent', cursorButtonHB);
                            set(cursorButtonHB, 'Sizes', [-1 -3 -3 -1]);
                    %Start/Stop Button Box
                    startStopVB = uiextras.VBox(...
                        'Parent', uiVB);
                        uiextras.Empty('Parent', startStopVB);
                        startStopHB = uiextras.HBox(...
                            'Parent', startStopVB, ...
                            'Spacing', 5, ...
                            'Padding', 5);
                            uicontrol(...
                                'Parent', startStopHB,...
                                'Style', 'pushbutton', ...
                                'Tag', 'startButton',...
                                'String', 'Start',...
                                'Callback', @obj.startButton_Callback);
                            uiextras.Empty('Parent', startStopHB);
                            uicontrol(...
                                'Parent', startStopHB,...
                                'Style', 'pushbutton', ...
                                'Tag', 'stopButton',...
                                'String', 'Stop',...
                                'Callback', @obj.stopButton_Callback);
                            set(startStopHB, 'Sizes', [-2 -1 -2]);
                        uiextras.Empty('Parent', startStopVB);
                        set(startStopVB, 'Sizes', [-1 -2 -1]);
                    %Frequency Parameter Box
                    obj.mySweepModes = uiextras.TabPanel(...
                        'Parent', uiVB, ...
                        'Tag', 'sweepParamTP', ...
                        'ForegroundColor', 'k', ...
                        'Padding', 5);
                        freqParamHB = uiextras.HBox(...
                            'Parent', obj.mySweepModes, ...
                            'Spacing', 5, ...
                            'Padding', 5);
                            startFreqVB = uiextras.VBox(...
                                'Parent', freqParamHB, ...
                                'Spacing', 5, ...
                                'Padding', 5);
                                uiextras.Empty('Parent', startFreqVB);
                                uicontrol(...
                                    'Parent', startFreqVB, ...
                                    'Style', 'text', ...
                                    'String', 'Start Frequency', ...
                                    'FontWeight', 'bold', ...
                                    'FontUnits', 'normalized', ...
                                    'FontSize', 0.6);
                                uicontrol(...
                                    'Parent', startFreqVB, ...
                                    'Style', 'edit', ...
                                    'Tag', 'startFrequency', ...
                                    'String', '24000000', ...
                                    'FontWeight', 'normal', ...
                                    'FontUnits', 'normalized', ...
                                    'FontSize', 0.6); 
                                uiextras.Empty('Parent', startFreqVB);

                            centerFreqVB = uiextras.VBox(...
                                'Parent', freqParamHB, ...
                                'Spacing', 5, ...
                                'Padding', 5);
                                uicontrol(...
                                    'Parent', centerFreqVB, ...
                                    'Style', 'text', ...
                                    'String', 'Current Frequency', ...
                                    'FontWeight', 'bold', ...
                                    'FontUnits', 'normalized', ...
                                    'FontSize', 0.7);
                                uicontrol(...
                                    'Parent', centerFreqVB, ...
                                    'Style', 'text', ...
                                    'Tag', 'curFreq', ...
                                    'String', 'curFreq', ...
                                    'FontWeight', 'bold', ...
                                    'FontUnits', 'normalized', ...
                                    'FontSize', 0.7);
                                uiextras.Empty('Parent', centerFreqVB);
                                uicontrol(...
                                    'Parent', centerFreqVB, ...
                                    'Style', 'text', ...
                                    'String', 'Step Size', ...
                                    'FontWeight', 'bold', ...
                                    'FontUnits', 'normalized', ...
                                    'FontSize', 0.7);
                                uicontrol(...
                                    'Parent', centerFreqVB, ...
                                    'Style', 'edit', ...
                                    'Tag', 'stepFrequency', ...
                                    'String', '1', ...
                                    'FontWeight', 'normal', ...
                                    'FontUnits', 'normalized', ...
                                    'FontSize', 0.7); 
                            stopFreqVB = uiextras.VBox(...
                                'Parent', freqParamHB, ...
                                'Spacing', 5, ...
                                'Padding', 5);
                                uiextras.Empty('Parent', stopFreqVB);
                                uicontrol(...
                                    'Parent', stopFreqVB, ...
                                    'Style', 'text', ...
                                    'String', 'Stop Frequency', ...
                                    'FontWeight', 'bold', ...
                                    'FontUnits', 'normalized', ...
                                    'FontSize', 0.6);
                                uicontrol(...
                                    'Parent', stopFreqVB, ...
                                    'Style', 'edit', ...
                                    'Tag', 'stopFrequency', ...
                                    'String', '24000010', ...
                                    'FontWeight', 'normal', ...
                                    'FontUnits', 'normalized', ...
                                    'FontSize', 0.6); 
                                uiextras.Empty('Parent', stopFreqVB);
                                
                                
                            timeParamHB = uiextras.HBox(...
                            'Parent', obj.mySweepModes, ...
                            'Spacing', 5, ...
                            'Padding', 5);
                            startTimeVB = uiextras.VBox(...
                                'Parent', timeParamHB, ...
                                'Spacing', 5, ...
                                'Padding', 5);
                                uiextras.Empty('Parent', startTimeVB);
                                uicontrol(...
                                    'Parent', startTimeVB, ...
                                    'Style', 'text', ...
                                    'String', 'Start Time (ms)', ...
                                    'FontWeight', 'bold', ...
                                    'FontUnits', 'normalized', ...
                                    'FontSize', 0.6);
                                uicontrol(...
                                    'Parent', startTimeVB, ...
                                    'Style', 'edit', ...
                                    'Tag', 'startTime', ...
                                    'String', '1', ...
                                    'FontWeight', 'normal', ...
                                    'FontUnits', 'normalized', ...
                                    'FontSize', 0.6); 
                                uiextras.Empty('Parent', startTimeVB);

                            centerTimeVB = uiextras.VBox(...
                                'Parent', timeParamHB, ...
                                'Spacing', 5, ...
                                'Padding', 5);
                                uicontrol(...
                                    'Parent', centerTimeVB, ...
                                    'Style', 'text', ...
                                    'String', 'Current Time', ...
                                    'FontWeight', 'bold', ...
                                    'FontUnits', 'normalized', ...
                                    'FontSize', 0.7);
                                uicontrol(...
                                    'Parent', centerTimeVB, ...
                                    'Style', 'text', ...
                                    'Tag', 'curTime', ...
                                    'String', 'curTime', ...
                                    'FontWeight', 'bold', ...
                                    'FontUnits', 'normalized', ...
                                    'FontSize', 0.7);
                                uiextras.Empty('Parent', centerTimeVB);
                                uicontrol(...
                                    'Parent', centerTimeVB, ...
                                    'Style', 'text', ...
                                    'String', 'Step Size', ...
                                    'FontWeight', 'bold', ...
                                    'FontUnits', 'normalized', ...
                                    'FontSize', 0.7);
                                uicontrol(...
                                    'Parent', centerTimeVB, ...
                                    'Style', 'edit', ...
                                    'Tag', 'stepTime', ...
                                    'String', '1', ...
                                    'FontWeight', 'normal', ...
                                    'FontUnits', 'normalized', ...
                                    'FontSize', 0.7); 
                            stopTimeVB = uiextras.VBox(...
                                'Parent', timeParamHB, ...
                                'Spacing', 5, ...
                                'Padding', 5);
                                uiextras.Empty('Parent', stopTimeVB);
                                uicontrol(...
                                    'Parent', stopTimeVB, ...
                                    'Style', 'text', ...
                                    'String', 'Stop Time (ms)', ...
                                    'FontWeight', 'bold', ...
                                    'FontUnits', 'normalized', ...
                                    'FontSize', 0.6);
                                uicontrol(...
                                    'Parent', stopTimeVB, ...
                                    'Style', 'edit', ...
                                    'Tag', 'stopTime', ...
                                    'String', '400', ...
                                    'FontWeight', 'normal', ...
                                    'FontUnits', 'normalized', ...
                                    'FontSize', 0.6); 
                                uiextras.Empty('Parent', stopTimeVB);
                    obj.mySweepModes.TabNames = {'Freq', 'SinglePulse'};
                    obj.mySweepModes.SelectedChild = 1;
                    %Direction/Constant Box
                    directionConstantHB = uiextras.HBox(...
                        'Parent', uiVB, ...
                        'Spacing', 5, ...
                        'Padding', 1);
                        uiextras.Empty('Parent', directionConstantHB);
                        directionConstantVB = uiextras.VBox(...
                            'Parent', directionConstantHB, ...
                            'Spacing', 5, ...
                            'Padding', 1);
                            uicontrol( ...
                                'Parent', directionConstantVB, ...
                                'Style', 'checkbox', ...
                                'String', 'Flip Scan Direction', ...
                                'Tag', 'flipScan', ...
                                'Value', 0);
                            uicontrol( ...
                                'Parent', directionConstantVB, ...
                                'Style', 'checkbox', ...
                                'String', 'Approach from Both Extremes', ...
                                'Tag', 'backAndForthScan', ...
                                'Value', 0);
                            uicontrol( ...
                                'Parent', directionConstantVB, ...
                                'Style', 'checkbox', ...
                                'String', 'Hold at Start Frequency', ...
                                'Tag', 'holdFreq', ...
                                'Value', 0);
                            uicontrol( ...
                                'Parent', directionConstantVB, ...
                                'Style', 'popup', ...
                                'String', 'Ignore LC Waveplate | LC V1 | LC V2 | Oscillate LC Waveplate', ...
                                'Tag', 'oscLCwave', ...
                                'Value', 1);
                            set(directionConstantVB, 'Sizes', [-1 -1 -1 -1]);
                        uiextras.Empty('Parent', directionConstantHB);
                        set(directionConstantHB, 'Sizes', [-1 -3 -0.5]);
                    %ProgressBar Box
                    jProgBarPanel = uipanel(...
                        'Parent', uiVB, ...
                        'Tag', 'jProgBarPanel', ...
                        'BorderType', 'none', ...
                        'ResizeFcn', @obj.resizeJProgressBarHolder);
                        try
                            jProgBar = javaObjectEDT('javax.swing.JProgressBar');
                            jProgBar.setOrientation(jProgBar.HORIZONTAL);
                        catch
                           error('Cannot create Java-based scroll-bar!');
                        end
                    % Display the object onscreen
                        try
                          [jProgBar, hProgBar] = javacomponent(jProgBar);
                          set(hProgBar,'Parent', jProgBarPanel);
                          setappdata(obj.myTopFigure, 'jProgBar', jProgBar);
                          setappdata(obj.myTopFigure, 'hProgBar', hProgBar);
                        catch
                           error('Cannot display Java-base scroll-bar!');
                        end
                    %SavePath Box
                    savePathVB = uiextras.VBox(...
                        'Parent', uiVB, ...
                        'Spacing', 5, ...
                        'Padding', 1);  
                        uicontrol( ...
                            'Parent', savePathVB, ...
                            'Style', 'checkbox', ...
                            'String', 'Save as you go?', ...
                            'Tag', 'saveScan', ...
                            'Value', 1);
                        pathHB = uiextras.HBox(...
                            'Parent', savePathVB, ...
                            'Spacing', 5, ...
                            'Padding', 5);
                            uicontrol(...
                                'Parent', pathHB, ...
                                'Style', 'pushbutton', ...
                                'Tag', 'getSaveDir', ...
                                'String', 'SaveDir', ...
                                'Callback', @obj.getSaveDir_Callback);
                            uicontrol(...
                                'Parent', pathHB, ...
                                'Style', 'edit', ...
                                'String', 'Z:\Sr3\data', ...
                                'Tag', 'saveDir');
                            set(pathHB, 'Sizes', [60 -1]);
                        set(savePathVB, 'Sizes', [-2 -1]);
                    %Locking Error Signal Box
%                     uiextras.Empty('Parent', uiVB);
                    errPlot = axes( 'Parent', uiVB, ...
                        'Tag', 'errPlot', ...
                        'NextPlot', 'replaceChildren');
                        title(errPlot, 'Locking Error Signal');
                        
                    %Spacer
                    %FitReadout
                    %CursorButton Box
                    %Start/Stop
                    %Frequency / Time Parameters
                    %Direction/Constant Box
                    %ProgressBar
                    %SavePath
                    %Locking Error Signal
                    set(uiVB, 'Sizes', [-1 -0.5 -0.5 -1 -1.5 -1 -1 -1 -3]);

                scanPlotsVB = uiextras.VBox(...
                    'Parent', hsplit, ...
                    'Tag', 'scanPlotsVB', ...
                    'Spacing', 5, ...
                    'Padding', 5);
                    sNormAxes = axes(...
                        'Parent', scanPlotsVB,...
                        'Tag', 'sNormAxes', ...
                        'NextPlot', 'replaceChildren');
                        title(sNormAxes, 'Normalized Counts');
                    sEAxes = axes(...
                        'Parent', scanPlotsVB,...
                        'Tag', 'sEAxes', ...
                        'NextPlot', 'replaceChildren');
                        title(sEAxes, 'Excited State Counts');
                    sGAxes = axes(...
                        'Parent', scanPlotsVB,...
                        'Tag', 'sGAxes', ...
                        'NextPlot', 'replaceChildren');
                        title(sGAxes, 'Ground State Counts');
                    sBGAxes = axes(...
                        'Parent', scanPlotsVB,...
                        'Tag', 'sBGAxes', ...
                        'NextPlot', 'replaceChildren');
                        title(sBGAxes, 'Background Counts');
                    sSummedAxes = axes(...
                        'Parent', scanPlotsVB,...
                        'Tag', 'sSummedAxes', ...
                        'NextPlot', 'replaceChildren');
                        title(sSummedAxes, 'Summed Counts');
%                     sBEAxes = axes(...
%                         'Parent', scanPlotsVB,...
%                         'Tag', 'sBEAxes', ...
%                         'NextPlot', 'replaceChildren');
%                         title(sBEAxes, '461 witness ExcState');
                
                rawPlotsVB = uiextras.VBox(...
                    'Parent', hsplit, ...
                    'Tag', 'scanPlotsVB', ...
                    'Spacing', 5, ...
                    'Padding', 5);
                    
                    rGSAxes = axes(...
                        'Parent', rawPlotsVB,...
                        'Tag', 'rGSAxes', ...
                        'NextPlot', 'replaceChildren');
                        title(rGSAxes, 'Ground State Flourescence');
                    rEAxes = axes(...
                        'Parent', rawPlotsVB,...
                        'Tag', 'rEAxes', ...
                        'NextPlot', 'replaceChildren');
                        title(rEAxes, 'Excited State Flourescence');
                    rBGAxes = axes(...
                        'Parent', rawPlotsVB,...
                        'Tag', 'rBGAxes', ...
                        'NextPlot', 'replaceChildren');
                        title(rBGAxes, 'Background Flourescence');
                    rBGSAxes = axes(...
                        'Parent', rawPlotsVB,...
                        'Tag', 'rBGSAxes', ...
                        'NextPlot', 'replaceChildren');
                        title(rBGSAxes, '461 GndState Witness');
                    rBEAxes = axes(...
                        'Parent', rawPlotsVB,...
                        'Tag', 'rBEAxes', ...
                        'NextPlot', 'replaceChildren');
                        title(rBEAxes, '461 ExcState Witness');
                    rBBGAxes = axes(...
                        'Parent', rawPlotsVB,...
                        'Tag', 'rBBGAxes', ...
                        'NextPlot', 'replaceChildren');
                        title(rBBGAxes, '461 Background Witness');
                set(hsplit, 'Sizes', [-1 -1.5 -1]);
                myHandles = guihandles(obj.myTopFigure);
                guidata(obj.myTopFigure, myHandles);
                obj.loadState();
        end
        function setFreqSynth(obj, fs)
            obj.myFreqSynth = fs;
        end
        function setTimeSynth(obj, ts)
            obj.myTimeSynth = ts;
        end
        function setGageConfigFrontend(obj, gc)
            obj.myGageConfigFrontend = gc;
        end
        function setLCuControl(obj, uC)
            obj.myLCuControl = uC;
        end
        function setCycleNuControl(obj, uC)
            obj.myCycleNuControl = uC;
        end
        function startButton_Callback(obj, src, eventData)
            switch getappdata(obj.myTopFigure, 'DEBUGMODE')
                case {0,1}
                    obj.sweep_initialize();
                    obj.sweep_takeNextPoint();
                case 2
                    obj.sweepRemote_initialize();
            end
        end
        function sweepRemote_initialize(obj)
            setappdata(obj.myTopFigure, 'readyForData', 0);
            myHandles = guidata(obj.myTopFigure);
            set(myHandles.startButton, 'Enable', 'off');
            set(myHandles.stopButton, 'Enable', 'on');
            set(myHandles.saveScan, 'Enable', 'off');
            set(myHandles.flipScan, 'Enable', 'off');
            set(myHandles.holdFreq, 'Enable', 'off');
            set(myHandles.backAndForthScan, 'Enable', 'off');
            
            sweepSelect = obj.mySweepModes.SelectedChild; %1-Frequency 2-Time
%             sweepSelect = 1;                                              
            
            %1. Create Frequency List
                %Check to see if you want to scan, or you want to hold the
                %Frequency
                if ~get(myHandles.holdFreq, 'Value')
                        %Check to see if direciton of scan is flipped
                        if ~get(myHandles.flipScan, 'Value')
                            startFrequency = str2double(get(myHandles.startFrequency, 'String'));
                            stepFrequency = str2double(get(myHandles.stepFrequency, 'String'));
                            stopFrequency = str2double(get(myHandles.stopFrequency, 'String'));
                        else
                            startFrequency = str2double(get(myHandles.stopFrequency, 'String')); %FLIPPED
                            stepFrequency = -1*str2double(get(myHandles.stepFrequency, 'String')); %FLIPPED
                            stopFrequency = str2double(get(myHandles.startFrequency, 'String')); %FLIPPED
                        end
                        try
                            freqList = startFrequency:stepFrequency:stopFrequency;
                            curFrequency = freqList(1);
                        catch exception
                            set(myHandles.startButton, 'Enable', 'on');
                            set(myHandles.stopButton, 'Enable', 'off');
                            set(myHandles.saveScan, 'Enable', 'on');
                            set(myHandles.flipScan, 'Enable', 'on');
                            set(myHandles.holdFreq, 'Enable', 'on');
                            set(myHandles.backAndForthScan, 'Enable', 'on');
                            errordlg('Bad Frequency Numbers');
                            return
                        end
                else
                    freqList = 1:10000;
                    curFrequency = str2double(get(myHandles.startFrequency, 'String'));
                end
                if get(myHandles.backAndForthScan, 'Value')
                    n = length(freqList);
                    i1 = 1:n;
                    i2 = ((1+(-1).^i1)/2).*(n - (i1-2)/2) + ((1-(-1).^i1)/2).*(i1+1)/2;
                    freqList = freqList(i2);
                end
                %Create TimeList
                startTime = str2double(get(myHandles.startTime, 'String'));
                stepTime = str2double(get(myHandles.stepTime, 'String'));
                stopTime = str2double(get(myHandles.stopTime, 'String'));
                
                timeList = startTime:stepTime:stopTime;
                %Preallocate data
                if sweepSelect == 1
                    tempNormData = zeros(1, length(freqList));
                    tempSummedData = zeros(1, length(freqList));
                    tempScanData = zeros(6, length(freqList));
                    x = freqList - freqList(1);
                else
                    tempNormData = zeros(1, length(timeList));
                    tempSummedData = zeros(1, length(timeList));
                    tempScanData = zeros(6, length(timeList));
                    x = timeList;
                end
                
                %Initialize Liquid Crystal Waveplate
                if get(myHandles.oscLCwave, 'Value') && strcmp(get(myHandles.openSerialLC, 'Enable'), 'off')
                    %fprintf(obj.myLCuControl.mySerial, 'H')
                end
            %1a. Initialize Progress Bar
            jProgBar = getappdata(obj.myTopFigure, 'jProgBar');
            if sweepSelect == 1
                jProgBar.setMaximum(length(freqList));
            else
                jProgBar.setMaximum(length(timeList));
            end
            %2. Check Save/'Run' and Create Saved File Header
            if getappdata(obj.myTopFigure, 'run') && get(myHandles.saveScan, 'Value')
                [path, fileName] = obj.createFileName();
                try
                    mkdir(path);
                    fid = fopen([path filesep fileName], 'a');
                    fwrite(fid, datestr(now, 'mm/dd/yyyy\tHH:MM AM'))
                    fprintf(fid, '\r\n');
                    colNames = {'Frequency', 'Norm', 'GndState', ...
                        'ExcState', 'Background', 'TStamp', 'BLUEGndState', ...
                        'BLUEBackground', 'BLUEExcState', 'pulseTime'};
                    n = length(colNames);
                    for i=1:n
                        fprintf(fid, '%s\t', colNames{i});
                    end
                        fprintf(fid, '\r\n');
                catch
                    disp('Could not open file to write to.');
                end
            else
                fid = [];
            end

            set(myHandles.setCursorButton, 'Enable', 'off'); %Clicking set twice would be bad.
            set(myHandles.grabCursorButton, 'Enable', 'on'); %Clicking set twice would be bad.
            %2.5 Initialize Frequency Synthesizer
            obj.myFreqSynth.initialize();
            %Initialize Time Synthesizer
%             obj.myTimeSynth.initialize();
            %Set to first frequency point
            ret = obj.myFreqSynth.setFrequency(num2str(curFrequency));
            if sweepSelect == 2
                totalTime = max(timeList);
                obj.myTimeSynth.setSinglePulse(totalTime - timeList(1), timeList(1));
%                 realPulseTime = realPulseTime*1e3;
%                 timeList(1) = realPulseTime;
%                 x(1) = realPulseTime;
            end
                if ~ret
                    setappdata(obj.myTopFigure, 'run', 0);
                end
            %Start Frequency Loop / Check 'Run'
            set(myHandles.curFreq, 'BackgroundColor', 'green');
            
            setappdata(obj.myTopFigure, 'normData', tempNormData);
            setappdata(obj.myTopFigure, 'scanData', tempScanData);
            setappdata(obj.myTopFigure, 'summedData', tempSummedData);
            setappdata(obj.myTopFigure, 'runNum', 1);
            setappdata(obj.myTopFigure, 'fid', fid);
            setappdata(obj.myTopFigure, 'x', x);
            setappdata(obj.myTopFigure, 'freqList', freqList);
            setappdata(obj.myTopFigure, 'timeList', timeList);
            setappdata(obj.myTopFigure, 'sweepSelect', sweepSelect);
            setappdata(obj.myTopFigure, 'prevTime', timeList(1));
            setappdata(obj.myTopFigure, 'curTime', timeList(1));
            setappdata(obj.myTopFigure, 'prevFrequency', curFrequency);
            setappdata(obj.myTopFigure, 'curFrequency', curFrequency);
            setappdata(obj.myTopFigure, 'nextStep', @obj.sweepRemote_takeNextPoint);
            pause(0.5) %I think I need this to make sure we get our first point good
            guidata(obj.myTopFigure, myHandles);
            setappdata(obj.myTopFigure, 'readyForData', 1);
        end
        function sweepRemote_takeNextPoint(obj, data)
            myHandles = guidata(obj.myTopFigure);
            tempNormData = getappdata(obj.myTopFigure, 'normData');
            tempScanData = getappdata(obj.myTopFigure, 'scanData');
            tempSummedData = getappdata(obj.myTopFigure, 'summedData');
            runNum = getappdata(obj.myTopFigure, 'runNum');
            taxis = getappdata(obj.myTopFigure, 'taxis');
            fid = getappdata(obj.myTopFigure, 'fid');
            x = getappdata(obj.myTopFigure, 'x');
            freqList = getappdata(obj.myTopFigure, 'freqList');
            timeList = getappdata(obj.myTopFigure, 'timeList');
            sweepSelect = getappdata(obj.myTopFigure, 'sweepSelect');
            jProgBar = getappdata(obj.myTopFigure, 'jProgBar');
            curFrequency = getappdata(obj.myTopFigure, 'curFrequency');
            prevFrequency = getappdata(obj.myTopFigure, 'prevFrequency');
            prevTime = getappdata(obj.myTopFigure, 'prevTime');
            curTime = getappdata(obj.myTopFigure, 'curTime');

            
            if runNum~=1
                tempH = getappdata(obj.myTopFigure, 'plottingHandles');
                taxis = getappdata(obj.myTopFigure, 'taxis');
            end
            
            if sweepSelect == 1
                curList = freqList;
            else
                curList = timeList;
            end
            pointDone = 0;
            while( getappdata(obj.myTopFigure, 'run') && runNum <= length(curList) && ~pointDone)
                if sweepSelect == 1
                    %3. Set Frequency (Display + Synthesizer)
                        %Check to see if you are scanning the frequency
                        if ~get(myHandles.holdFreq, 'Value') && runNum+1 <= length(freqList)
                            curFrequency = freqList(runNum + 1);
                        end
                    ret = obj.myFreqSynth.setFrequency(num2str(curFrequency));
                    if ~ret
                        setappdata(obj.myTopFigure, 'run', 0);
                        break;
                    end
                    set(myHandles.curFreq, 'String', num2str(curFrequency));
                else
                    if runNum+1 <= length(timeList)
                        %Set Pulse Time
                        totalTime = max(timeList);
                        obj.myTimeSynth.setSinglePulse(totalTime - timeList(runNum+1), timeList(runNum+1));
                        curTime = timeList(runNum+1);
%                     realPulseTime = realPulseTime*1e3;
%                     timeList(runNum) = realPulseTime;
%                     x(runNum) = realPulseTime;
                    end
                end
                %4. Update Progress Bar
                jProgBar.setValue(runNum);
                drawnow;
                
                LCmode = get(myHandles.oscLCwave, 'Value'); %equals 1 when no communication is required
                %IMMEDIATELY CHANGE THE LIQUID CRYSTAL WAVEPLATE IF NEED BE
                if LCmode ~= 1 && strcmp(get(myHandles.openSerialLC, 'Enable'), 'off')
                    switch LCmode
                        case 2
                            fprintf(obj.myLCuControl.mySerial, ':0;c2;d0;t80000');
                        case 3
                            fprintf(obj.myLCuControl.mySerial, ':0;c0;d0;t80000');
                        case 4
                            if ~mod(runNum+1,2)
                                fprintf(obj.myLCuControl.mySerial, ':0;c2;d0;t80000');
                            else
                                fprintf(obj.myLCuControl.mySerial, ':0;c0;d0;t80000');
                            end
                    end
                end
%                 if ~ret
%                     setappdata(obj.myTopFigure, 'run', 0);
%                     break;
%                 end
                %6. Start Parsing Data
                time = data(1);
                tSCdat12 = data(2:3);
                tSCdat3 = data(4);
                tSCdat456 = data(5:7);
                tStep = data(8);
                chDataLength = length(data(9:end))/6;

                %7. Clear the Raw Plots, Plot the Raw Plots
                temp7 = data(9:8+chDataLength);
                temp8 = data(9+1*chDataLength:8+2*chDataLength);
                temp9 = data(9+2*chDataLength:8+3*chDataLength);
                temp10 = data(9+3*chDataLength:8+4*chDataLength);
                temp11 = data(9+4*chDataLength:8+5*chDataLength);
                temp12 = data(9+5*chDataLength:8+6*chDataLength);
                if runNum == 1
                    taxis = (1:length(temp7))*tStep;
                    tempH(7) = plot(myHandles.rGSAxes, taxis, ...
                                temp7);

                    tempH(8) = plot(myHandles.rEAxes, taxis, ...
                                temp8);

                    tempH(9) = plot(myHandles.rBGAxes, taxis, ...
                                temp9);

                    tempH(10) = plot(myHandles.rBGSAxes, taxis, ...
                                temp10);

                    tempH(11) = plot(myHandles.rBEAxes, taxis, ...
                                temp11);

                    tempH(12) = plot(myHandles.rBBGAxes, taxis, ...
                                temp12);
                else
                    set(tempH(7), 'XData',  taxis);
                    set(tempH(7), 'YData', temp7);
                    set(tempH(8), 'XData',  taxis);
                    set(tempH(8), 'YData', temp8);
                    set(tempH(9), 'XData',  taxis);
                    set(tempH(9), 'YData', temp9);
                    set(tempH(10), 'XData',  taxis);
                    set(tempH(10), 'YData', temp10);
                    set(tempH(11), 'XData',  taxis);
                    set(tempH(11), 'YData', temp11);
                    set(tempH(12), 'XData',  taxis);
                    set(tempH(12), 'YData', temp12);

                end
                %8. Update Scan Plots
                tempScanData(1:2,runNum) = tSCdat12;
                tempScanData(3,runNum) = tSCdat3;
                tempScanData(4:6,runNum) = tSCdat456;
                %NORMALIZED counts are (E - bg)/(E + G - 2bg)
                tempNormData(runNum) = (tempScanData(2,runNum)) / (tempScanData(2,runNum) + tempScanData(1,runNum));
                %SUMMED counts
                tempSummedData(runNum) = tempScanData(2,runNum)+tempScanData(1,runNum);
                
                
                plotstart = 1;
                firstplot = 1;
                if get(myHandles.ignoreFirstToggle, 'Value')
                    plotstart = 2;
                    firstplot = 2;
                end
                
                if floor(runNum/300) >= 1 %Fixes memory leaking issue?
                    plotstart = floor(runNum/300)*300;
                end
                
                if runNum == firstplot && ~get(myHandles.backAndForthScan, 'Value')  %First time you have to plot....the rest of the time we will "refreshdata"
                    tempH(1) = plot(myHandles.sNormAxes, x(plotstart:runNum), tempNormData(plotstart:runNum), '-ok', 'LineWidth', 3);
                    tempH(2) = plot(myHandles.sEAxes, x(plotstart:runNum), tempScanData(2,plotstart:runNum), '-or', 'LineWidth', 2);
                    tempH(3) = plot(myHandles.sGAxes, x(plotstart:runNum), tempScanData(1,plotstart:runNum), '-ob', 'LineWidth', 2);
                    tempH(4) = plot(myHandles.sBGAxes, x(plotstart:runNum), tempScanData(3,plotstart:runNum), '-ob', 'LineWidth', 1);
                    tempH(5) = plot(myHandles.sSummedAxes, x(plotstart:runNum), tempSummedData(plotstart:runNum), '-og', 'LineWidth', 2);
                elseif runNum == firstplot
                    tempH(1) = plot(myHandles.sNormAxes, x(plotstart:runNum), tempNormData(plotstart:runNum), 'ok', 'LineWidth', 3);
                    tempH(2) = plot(myHandles.sEAxes, x(plotstart:runNum), tempScanData(2,plotstart:runNum), 'or', 'LineWidth', 2);
                    tempH(3) = plot(myHandles.sGAxes, x(plotstart:runNum), tempScanData(1,plotstart:runNum), 'ob', 'LineWidth', 2);
                    tempH(4) = plot(myHandles.sBGAxes, x(plotstart:runNum), tempScanData(3,plotstart:runNum), 'ob', 'LineWidth', 1);
                    tempH(5) = plot(myHandles.sSummedAxes, x(plotstart:runNum), tempSummedData(plotstart:runNum), 'og', 'LineWidth', 2);
                elseif runNum > firstplot
                    set(tempH(1), 'XData', x(plotstart:runNum), 'YData', tempNormData(plotstart:runNum));
                    set(tempH(2), 'XData', x(plotstart:runNum), 'YData', tempScanData(2,plotstart:runNum));
                    set(tempH(3), 'XData', x(plotstart:runNum), 'YData', tempScanData(1,plotstart:runNum));
                    set(tempH(4), 'XData', x(plotstart:runNum), 'YData', tempScanData(3,plotstart:runNum));
                    set(tempH(5), 'XData', x(plotstart:runNum), 'YData', tempSummedData(plotstart:runNum));
                end
                
%                 This is for creating cursors
                if runNum == 4 && get(myHandles.cursorToggle, 'Value')
%                     Create Interactive Draggable cursors
                    dualcursor([],[.65 1.08;.9 1.08],[],@(x, y) '', myHandles.sNormAxes);
                elseif runNum > 4 && get(myHandles.cursorToggle, 'Value')
%                     Need to double check because of the cursor toggle
%                     button
                    if isempty(dualcursor(myHandles.sNormAxes))
                        dualcursor([],[.65 1.08;.9 1.08],[],@(x, y) '', myHandles.sNormAxes);
                    else
                        dualcursor('update', [.65 1.08;.9 1.08], [], @(x, y) '', myHandles.sNormAxes);
                    end
                end
                data = [];
                
                %9. Check Save and Write Data to file.
                if get(myHandles.saveScan, 'Value')
% 'Frequency', 'Norm', 'GndState', 'ExcState', 'Background', 'TStamp', 'BLUEGndState', 'BLUEBackground', 'BLUEExcState'
                    temp = [prevFrequency tempNormData(runNum) tempScanData(1,runNum) tempScanData(2,runNum) tempScanData(3,runNum) time tempScanData(4,runNum) tempScanData(6,runNum) tempScanData(5,runNum)];
                    if sweepSelect == 1
                        temp = [temp 0];
                    else
                        temp = [temp prevTime];
                    end
                    fprintf(fid, '%8.6f\t', temp);
                    fprintf(fid, '\r\n');
                end
                pointDone = 1;
            end
            if (getappdata(obj.myTopFigure, 'run') && runNum <= length(curList)) % Prepare for a new data point
                if runNum == 1
                    setappdata(obj.myTopFigure, 'taxis', taxis);
                end
                runNum = runNum + 1;
                setappdata(obj.myTopFigure, 'normData', tempNormData);
                setappdata(obj.myTopFigure, 'scanData', tempScanData);
                setappdata(obj.myTopFigure, 'summedData', tempSummedData);
                setappdata(obj.myTopFigure, 'runNum', runNum);
                setappdata(obj.myTopFigure, 'plottingHandles', tempH);
                setappdata(obj.myTopFigure, 'curFrequency', curFrequency);
                setappdata(obj.myTopFigure, 'prevFrequency', curFrequency);
                if sweepSelect == 2
                    setappdata(obj.myTopFigure, 'prevTime', curTime);
                    setappdata(obj.myTopFigure, 'x', x);
                end
%                 pause(3) %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Testing
                guidata(obj.myTopFigure, myHandles);
                
            else %close everything done
                    setappdata(obj.myTopFigure, 'readyForData', 0);
                    %9.5 Close Frequency Synthesizer and Data file
% % % % % % %                     obj.myFreqSynth.close();
% % % % % % %                     obj.myTimeSynth.close();
                    fclose('all'); % weird matlab thing, can't just close fid, won't work.
                    %10. If ~Run, make obvious and reset 'run'
                    if ~getappdata(obj.myTopFigure, 'run')
                        disp('Acquisistion Stopped');
                        set(myHandles.curFreq, 'String', 'STOPPED');
                        setappdata(obj.myTopFigure, 'run', 1);
                        drawnow;
                    end
                    %Make obvious that the scan stopped
                    set(myHandles.curFreq, 'BackgroundColor', 'red');
                    set(myHandles.startButton, 'Enable', 'on');
                    set(myHandles.stopButton, 'Enable', 'off');
                    set(myHandles.saveScan, 'Enable', 'on');
                    set(myHandles.flipScan, 'Enable', 'on');
                    set(myHandles.holdFreq, 'Enable', 'on');
                    set(myHandles.backAndForthScan, 'Enable', 'on');
                    
                    rmappdata(obj.myTopFigure, 'scanData');
                    rmappdata(obj.myTopFigure, 'summedData');
                    rmappdata(obj.myTopFigure, 'runNum');
                    try
                        rmappdata(obj.myTopFigure, 'taxis');
                        rmappdata(obj.myTopFigure, 'plottingHandles');
                    catch exception
                        exception.message
                    end
                    rmappdata(obj.myTopFigure, 'fid');
                    rmappdata(obj.myTopFigure, 'x');
                    rmappdata(obj.myTopFigure, 'freqList');
                    rmappdata(obj.myTopFigure, 'timeList');
                    rmappdata(obj.myTopFigure, 'curFrequency');
                    rmappdata(obj.myTopFigure, 'prevFrequency');
                    rmappdata(obj.myTopFigure, 'prevTime');
                    rmappdata(obj.myTopFigure, 'curTime');
                    rmappdata(obj.myTopFigure, 'sweepSelect');
                    
                    drawnow;

                    guidata(obj.myTopFigure, myHandles);
                    
                    clear variables %Fixing memory leak?
                    clear mex
            end
        end
        function resizeJProgressBarHolder(obj, src, eventData)
            myHandles = guidata(obj.myTopFigure);
            old_units = get(src,'Units');
            set(src,'Units','pixels');
            figpos = get(src,'Position');
            hProgBar = getappdata(obj.myTopFigure, 'hProgBar');
            set(hProgBar, 'Position', [floor(0.1*figpos(3)) floor(0.32*figpos(4)) floor(0.8*figpos(3)) floor(0.36*figpos(4))]);
            set(src,'Units',old_units);
        end
        function cursorToggle_Callback(obj, src, eventData)
            myHandles = guidata(obj.myTopFigure);
            if ~get(myHandles.cursorToggle, 'Value')
                try
                    dualcursor('off',[.65 1.08;.9 1.08],[],[], myHandles.sNormAxes)
                catch
                end
            elseif ~isempty(getappdata(obj.myTopFigure, 'scanData'))
                dualcursor([],[.65 1.08;.9 1.08],[],@(x, y) '', myHandles.sNormAxes)
            end
        end
        function stopButton_Callback(obj, src, eventData)
            setappdata(obj.myTopFigure, 'run', 0);
        end
        function getSaveDir_Callback(obj, src, eventData)      
            myHandles = guidata(obj.myTopFigure);
            dirPath = uigetdir(['Z:\Sr3\data']);
            set(myHandles.saveDir, 'String', dirPath);
            guidata(obj.myTopFigure, myHandles);
        end
        function grabCursorButton_Callback(obj, src, eventData)
            myHandles = guidata(obj.myTopFigure);
            if get(myHandles.cursorToggle, 'Value')
                val = dualcursor(myHandles.sNormAxes);
                xLow = min([val(1) val(3)]);
                xHigh = max([val(1) val(3)]);
                if ~get(myHandles.flipScan, 'Value')
                    c1F = num2str(str2double(get(myHandles.startFrequency, 'String')) + xLow);
                    c2F = num2str(str2double(get(myHandles.startFrequency, 'String')) + xHigh);
                else
                    c1F = num2str(str2double(get(myHandles.stopFrequency, 'String')) + xLow);
                    c2F = num2str(str2double(get(myHandles.stopFrequency, 'String')) + xHigh);
                end
                set(myHandles.c1Freq, 'String',c1F);
                set(myHandles.c2Freq, 'String',c2F);
                set(myHandles.setCursorButton, 'Enable', 'on'); %Clicking set twice would be bad.
            end
        end
        function setCursorButton_Callback(obj, src, eventData)
            myHandles = guidata(obj.myTopFigure);
            % Set cursor will now transfer values of grab to start/stop
            % frequency
            % % % % % % % % %             if get(myHandles.cursorToggle, 'Value')
            % % % % % % % % %                 val = dualcursor(myHandles.sNormAxes);
            % % % % % % % % %                 c1F = -str2double(get(myHandles.startFrequency, 'String')) + str2double(get(myHandles.c1Freq, 'String'));
            % % % % % % % % %                 c2F = -str2double(get(myHandles.startFrequency, 'String')) + str2double(get(myHandles.c2Freq, 'String'));
            % % % % % % % % %                 dualcursor([c1F c2F],[.65 1.08;.9 1.08],[],[], myHandles.sNormAxes);
            % % % % % % % % %             end
            val = dualcursor(myHandles.sNormAxes);
            set(myHandles.startFrequency, 'String', get(myHandles.c1Freq, 'String'));
            set(myHandles.stopFrequency, 'String', get(myHandles.c2Freq, 'String'));
            set(myHandles.setCursorButton, 'Enable', 'off'); %Clicking set twice would be bad.
            set(myHandles.grabCursorButton, 'Enable', 'off'); %Clicking set twice would be bad.
        end
        function fitLorentzian_Callback(obj, src, eventData)
            %This absolutely needs to be cleaned up.
            myHandles = guidata(obj.myTopFigure);
            val = dualcursor(myHandles.sNormAxes);
            xLow = min([val(1) val(3)]);
            xHigh = max([val(1) val(3)]);
            if ~isempty(val)
                scannedVals = getappdata(obj.myTopFigure, 'normData');
                if ~get(myHandles.flipScan, 'Value')
                    fullx = str2double(get(myHandles.startFrequency, 'String')):str2double(get(myHandles.stepFrequency, 'String')):str2double(get(myHandles.stopFrequency, 'String'));
                    fullx = fullx - str2double(get(myHandles.startFrequency, 'String'));               
                else %FLIPPED
                    fullx = str2double(get(myHandles.stopFrequency, 'String')):(-1*str2double(get(myHandles.stepFrequency, 'String'))):str2double(get(myHandles.startFrequency, 'String'));
                    fullx = fullx - str2double(get(myHandles.stopFrequency, 'String'));
                end
                ValsToFit = scannedVals(fullx >= xLow & fullx <= xHigh);
                nu = xLow:str2double(get(myHandles.stepFrequency, 'String')):xHigh;

                opts = optimset('Algorithm', 'levenberg-marquardt', 'TolFun',1e-8, 'TolX',1e-6);
%                 opts = optimset('TolFun',1e-8, 'TolX',1e-6);

                Coefs = lsqnonlin(@(x) ValsToFit - x(1).*(1./(1 + ((nu-x(3))/x(2)).^2)), [10 abs(xHigh-xLow)/2 abs(xHigh + xLow)/2], [0 0 xLow],[100 2*abs(xHigh-xLow) xHigh], opts)
                hold(myHandles.sNormAxes);
                nuFine = xLow:0.1:xHigh;
                y = Coefs(1).*(1./(1 + ((nuFine-Coefs(3))/Coefs(2)).^2));
                plot(myHandles.sNormAxes, nuFine, y, 'r');
                set(myHandles.fitResults, 'String', sprintf('FWHM: %f Hz', 2*Coefs(2)))
                hold(myHandles.sNormAxes);
            end
        end
        function [path, fileName] = createFileName(obj)
            myHandles = guidata(obj.myTopFigure);
            basePath = get(myHandles.saveDir, 'String');
            folderPath = [datestr(now, 'yymmdd') filesep 'Sweeps'];
            curTime = datestr(now, 'HHMMSS');
            fileName = ['Sweep_' curTime '.txt'];
            path = [basePath filesep folderPath];
        end
        function scanData = analyzeRawData(obj, data)
            scanData = cellfun(@sum, data);
        end
        function scanData = analyzeRawDataBLUE(obj, data)
            scanData = cellfun(@mean, data);
        end
        function quit(obj)
            obj.myGageConfigFrontend = [];
            obj.myFreqSynth = [];
            obj.myTimeSynth = [];
            obj.myTopFigure = [];
            delete(obj.myPanel);
        end
        function saveState(obj)
            myHandles = guidata(obj.myTopFigure);
            FreqSweeperState.startFrequency = get(myHandles.startFrequency, 'String');
            FreqSweeperState.stepFrequency = get(myHandles.stepFrequency, 'String');
            FreqSweeperState.stopFrequency = get(myHandles.stopFrequency, 'String');
            FreqSweeperState.saveScan = get(myHandles.saveScan, 'Value');
            FreqSweeperState.saveDir = get(myHandles.saveDir, 'String');
            save FreqSweeperState;
        end
        function loadState(obj)
            try
                load FreqSweeperState
                myHandles = guidata(obj.myTopFigure);
                set(myHandles.startFrequency, 'String', FreqSweeperState.startFrequency);
                set(myHandles.stepFrequency, 'String', FreqSweeperState.stepFrequency);
                set(myHandles.stopFrequency, 'String', FreqSweeperState.stopFrequency);
                set(myHandles.startScan, 'Value', FreqSweeperState.saveScan);
                set(myHandles.saveDir, 'String', FreqSweeperState.saveDir);
                guidata(obj.myTopFigure, myHandles);
            catch
                disp('No saved state for FreqSweeper Exists');
            end
        end
    end
    
end

