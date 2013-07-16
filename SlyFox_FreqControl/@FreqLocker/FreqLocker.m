classdef FreqLocker < hgsetget
    %FREQLOCKER Rabi Spectroscopy locking program
    %   This program is intended to be used in conjunction with the
    %   freqsweeper program and is meant to be used to lock to Rabi
    %   lineshapes for use in atomic clock experiments, or to carefully
    %   cancel drifts between shots. This program should have a few
    %   different modes once it is done. Single-peak locking, Stretched
    %   State locking, and intermittent locking mode for canceling drifts
    %   between experiments. Written by Ben Bloom. Last Updated 03/30/12
    
    properties
        myPanel = uiextras.Grid();
        myTopFigure = [];
        myFreqSynth = [];
        myGageConfigFrontend = [];
        myFreqSweeper = [];
        myLCuControl = [];
        myCycleNuControl = [];
        myAnalogStepper = [];
        myAnalogCC = [];
        myLockModes = [];
        mysPID1 = [];
        myPID1gui = [];
        mysPID2 = [];
        myPID2gui = [];
        mysPID3 = [];
        myPID3gui = [];
        mysPID4 = [];
        myPID4gui = [];
        myDataToOutput = [];
        myDriftPlotHandle = [];
        myDriftFitHandle = [];
        myTempSensor = [];
    end
    
    properties (Constant)
        bufferSize = 128;
        plotSize = 40;
        refTime = 1361903296619;
    end
    
    methods
        function obj = FreqLocker(top,f)
            obj.myTopFigure = top;
            obj.myPanel.Parent = f;
            import PID.*
            
            initValues = struct('kP1',1.625,'Ti1',30,'Td1',0.24, 'kP2',1,'Ti2',10e10,'Td2',0,'delta', 8);
            
            obj.myPID1gui = PID.PID_gui(top, obj.myPanel, '1', initValues);
            obj.mysPID1 = seriesPID({obj.myPID1gui.myPID, obj.myPID1gui.myPID2});
            obj.myPID2gui = PID.PID_gui(top, obj.myPanel, '2', initValues);
            obj.mysPID2 = seriesPID({obj.myPID2gui.myPID, obj.myPID2gui.myPID2});
            obj.myPID3gui = PID.PID_gui(top, obj.myPanel, '3', initValues);
            obj.mysPID3 = seriesPID({obj.myPID3gui.myPID, obj.myPID3gui.myPID2});
            obj.myPID4gui = PID.PID_gui(top, obj.myPanel, '4', initValues);
            obj.mysPID4 = seriesPID({obj.myPID4gui.myPID, obj.myPID4gui.myPID2});
            
            lockOptPanel = uiextras.Panel('Parent', obj.myPanel, ...
                'Title', 'Locking Options');
                obj.myLockModes = uiextras.TabPanel('Parent', lockOptPanel, ...
                    'Tag', 'lockModes');
                    singlePeakP = uiextras.Panel('Parent', obj.myLockModes);
                        uicontrol(...
                            'Parent', singlePeakP, ...
                            'Style', 'popup', ...
                            'Tag', 'singlePeakLockOptions', ...
                            'String', 'Continuous Lock | Intermittent Lock with Data Point Between Lock Steps');
                    multiPeakP = uiextras.HBox('Parent', obj.myLockModes);
                        vb1 = uiextras.VBox('Parent', multiPeakP);
                        uicontrol(...
                            'Parent', vb1, ...
                            'Style', 'popup', ...
                            'Tag', 'multiplePeakLockOptions', ...
                            'String', 'Continuous Stretched States Lock | Interleaved 2-Shot (DIO) Lock | Analog Stepper | 4 PID Lock | 4 PID Lock with Rezeroing | 2 PID Lock with Rezeroing');
                        hb1 = uiextras.HBox('Parent', vb1);
                            vb2 = uiextras.VBox('Parent', hb1);
                            uiextras.Empty('Parent', vb2);
                            uicontrol(...
                                'Parent', vb2, ...
                                'Style', 'text', ...
                                'String', 'Iterations Before Rezeroing');
                            uiextras.Empty('Parent', vb2);
                            vb3 = uiextras.VBox('Parent', hb1);
                            uiextras.Empty('Parent', vb3);
                            uicontrol(...
                                'Parent', vb3, ...
                                'Style', 'edit', ...
                                'Tag', 'numRezero', ...
                                'String', '41');
                            uiextras.Empty('Parent', vb3);
                        uicontrol(...
                            'Parent', multiPeakP, ...
                            'Style', 'checkbox', ...
                            'Tag', 'bounceLCwaveplate', ...
                            'Value', 1, ...
                            'String', 'Bounce LC waveplate?');
                        uicontrol(...
                            'Parent', multiPeakP, ...
                            'Style', 'checkbox', ...
                            'Tag', 'calcSrFreq', ...
                            'Value', 1, ...
                            'Enable', 'off', ...
                            'String', 'Calculate Center Sr Frequency?');
                        uicontrol(...
                            'Parent', multiPeakP, ...
                            'Style', 'checkbox', ...
                            'Tag', 'useTSensor', ...
                            'Value', 1, ...
                            'String', 'Use Temperature Sensor?');
                    obj.myLockModes.SelectedChild = 2;
                    obj.myLockModes.TabNames = {'Single Peak Lock', 'Multiple Peak Lock'};
            lockControlP = uiextras.Panel('Parent', obj.myPanel, ...
                'Title', 'Locking Control');
                lockControl = uiextras.VBox('Parent', lockControlP);
%                 uicontrol(...
%                                     'Parent', cursorReadoffsHB,...
%                                     'Style', 'pushbutton', ...
%                                     'Tag', 'grabCursorButton',...
%                                     'String', 'Grab', ...
%                                     'Callback', @obj.grabCursorButton_Callback);

                %Frequency Parameter Box
                    freqParamHBL = uiextras.HBox(...
                        'Parent', lockControl, ...
                        'Spacing', 5, ...
                        'Padding', 5);
                        lowFreqVBL1 = uiextras.VBox(...
                            'Parent', freqParamHBL, ...
                            'Spacing', 5, ...
                            'Padding', 5);
                            uicontrol(...
                                'Parent', lowFreqVBL1, ...
                                'Style', 'text', ...
                                'String', 'Low Frequency (L1)', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.6);
                            uicontrol(...
                                'Parent', lowFreqVBL1, ...
                                'Style', 'edit', ...
                                'Tag', 'lowStartFrequency1', ...
                                'String', '24000000', ...
                                'FontWeight', 'normal', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.6); 
                                
                        widthFreqVBL1 = uiextras.VBox(...
                            'Parent', freqParamHBL, ...
                            'Spacing', 5, ...
                            'Padding', 5);
                            uicontrol(...
                                'Parent', widthFreqVBL1, ...
                                'Style', 'text', ...
                                'String', 'Current Frequency', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.7);
                            uicontrol(...
                                'Parent', widthFreqVBL1, ...
                                'Style', 'text', ...
                                'Tag', 'curFreqL', ...
                                'String', 'curFreq', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.7);
                            uicontrol(...
                                'Parent', widthFreqVBL1, ...
                                'Style', 'text', ...
                                'String', 'Linewidth (FWHM)', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.7);
                            uicontrol(...
                                'Parent', widthFreqVBL1, ...
                                'Style', 'edit', ...
                                'Tag', 'linewidth', ...
                                'String', '4.5', ...
                                'FontWeight', 'normal', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.7); 
                        highFreqVBL1 = uiextras.VBox(...
                            'Parent', freqParamHBL, ...
                            'Spacing', 5, ...
                            'Padding', 5);
                            uicontrol(...
                                'Parent', highFreqVBL1, ...
                                'Style', 'text', ...
                                'String', 'High Frequency (H1)', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.7);
                            uicontrol(...
                                'Parent', highFreqVBL1, ...
                                'Style', 'edit', ...
                                'Tag', 'highStartFrequency1', ...
                                'String', '24000010', ...
                                'FontWeight', 'normal', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.7); 
                       controlBox = uiextras.HButtonBox('Parent', lockControl);
                            uicontrol(...
                                'Parent', controlBox, ...
                                'Style', 'pushbutton', ...
                                'Callback', @obj.grabFromSweeper1_Callback, ...
                                'String', 'Grab From Sweeper');
                            uicontrol(...
                                'Parent', controlBox, ...
                                'Style', 'checkbox', ...
                                'String', 'Ignore First Point', ...
                                'Tag', 'ignoreFirstLock', ...
                                'Value', 0);
                            uicontrol(...
                                'Parent', controlBox, ...
                                'Style', 'pushbutton', ...
                                'Tag', 'startAcquire', ...
                                'String', 'Start Acquire', ...
                                'Callback', @obj.startAcquire_Callback, ...
                                'Enable', 'on');
                            uicontrol(...
                                'Parent', controlBox, ...
                                'Style', 'pushbutton', ...
                                'Tag', 'stopAcquire', ...
                                'String', 'Stop Acquire', ...
                                'Callback', @obj.stopAcquire_Callback, ...
                                'Enable', 'off');
                       uicontrol(...
                           'Parent', lockControl, ...
                           'Style', 'text', ...
                           'Tag', 'lockStatus', ...
                           'String', 'LockPoint');
                       
                       freqParamHBL2 = uiextras.HBox(...
                        'Parent', lockControl, ...
                        'Spacing', 5, ...
                        'Padding', 5);
                        lowFreqVBL2 = uiextras.VBox(...
                            'Parent', freqParamHBL2, ...
                            'Spacing', 5, ...
                            'Padding', 5);
                            uicontrol(...
                                'Parent', lowFreqVBL2, ...
                                'Style', 'text', ...
                                'String', 'Low Frequency (L2)', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.7);
                            uicontrol(...
                                'Parent', lowFreqVBL2, ...
                                'Style', 'edit', ...
                                'Tag', 'lowStartFrequency2', ...
                                'String', '24000000', ...
                                'FontWeight', 'normal', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.7); 
                                
                        widthFreqVBL2 = uiextras.VBox(...
                            'Parent', freqParamHBL2, ...
                            'Spacing', 5, ...
                            'Padding', 5);
                            uicontrol(...
                                'Parent', widthFreqVBL2, ...
                                'Style', 'text', ...
                                'String', 'Linewidth 2 (FWHM)', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.7);
                            uicontrol(...
                                'Parent', widthFreqVBL2, ...
                                'Style', 'edit', ...
                                'Tag', 'linewidth2', ...
                                'String', '4.5', ...
                                'FontWeight', 'normal', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.7); 
                        highFreqVBL2 = uiextras.VBox(...
                            'Parent', freqParamHBL2, ...
                            'Spacing', 5, ...
                            'Padding', 5);
                            uicontrol(...
                                'Parent', highFreqVBL2, ...
                                'Style', 'text', ...
                                'String', 'High Frequency (H2)', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.7);
                            uicontrol(...
                                'Parent', highFreqVBL2, ...
                                'Style', 'edit', ...
                                'Tag', 'highStartFrequency2', ...
                                'String', '24000010', ...
                                'FontWeight', 'normal', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.7); 
                       controlBox2 = uiextras.HButtonBox('Parent', lockControl);
                            uicontrol(...
                                'Parent', controlBox2, ...
                                'Style', 'pushbutton', ...
                                'Callback', @obj.grabFromSweeper2_Callback, ...
                                'String', 'Grab From Sweeper');
                       set(lockControl, 'Sizes', [-3, -1, -1, -3, -1]);
            lockOutput = uiextras.TabPanel('Parent', obj.myPanel);
                p1 = uiextras.Panel('Parent', lockOutput);
                    axes('Tag', 'DriftAXES', 'Parent', p1, 'ActivePositionProperty', 'OuterPosition');
                p2 = uiextras.Panel('Parent', lockOutput);
                    axes('Tag', 'normExcAXES', 'Parent', p2, 'ActivePositionProperty', 'OuterPosition');
                    lockOutput.TabNames = {'Drift', 'Normalized Exc'};
                    lockOutput.SelectedChild = 1;
            %%% Comparison and Correction Box
                correctionGrid = uiextras.Grid('Parent',obj.myPanel, 'Spacing', 3);
                uicontrol(...
                                'Parent', correctionGrid, ...
                                'Style', 'text', ...
                                'String', 'Temperature Fixed Sensor', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.4);
                uicontrol(...
                                'Parent', correctionGrid, ...
                                'Style', 'text', ...
                                'String', 'Temperature Bellows Sensor', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.4);
                 uicontrol(...
                                'Parent', correctionGrid, ...
                                'Style', 'text', ...
                                'String', '300 K', ...
                                'Tag', 'TempFixed', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.4);
                 uicontrol(...
                                'Parent', correctionGrid, ...
                                'Style', 'text', ...
                                'String', '300 K', ...
                                'Tag', 'TempBellows', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.4);
                set(correctionGrid, 'ColumnSizes', [-1 -1], 'RowSizes', [-1 -1]);
            set(obj.myPanel, 'ColumnSizes', [-1 -1], 'RowSizes', [-1 -1 -1 -1]);
            myHandles = guihandles(obj.myTopFigure);
            guidata(obj.myTopFigure, myHandles);
%             obj.loadState();
        end
        function setFreqSynth(obj, fs)
            obj.myFreqSynth = fs;
        end
        function setGageConfigFrontend(obj, gc)
            obj.myGageConfigFrontend = gc;
        end
        function setFreqSweeper(obj, fs)
            obj.myFreqSweeper = fs;
        end
        function setLCuControl(obj, uC)
            obj.myLCuControl = uC;
        end
        function setCycleNuControl(obj, uC)
            obj.myCycleNuControl = uC;
        end
        function setAnalogStepper(obj, aStep)
            obj.myAnalogStepper = aStep;
        end
        function setAnalogCC(obj, aCC)
            obj.myAnalogCC = aCC;
        end
        function startAcquire_Callback(obj, src, eventData)
            myHandles = guidata(obj.myTopFigure);
            set(myHandles.stopAcquire, 'Enable', 'on');
            set(myHandles.startAcquire, 'Enable', 'off');
            setappdata(obj.myTopFigure, 'run', 1);
            
            obj.startLockingProtocol();
        end
        function stopAcquire_Callback(obj, src, eventData)
            setappdata(obj.myTopFigure, 'run', 0);
            
            myHandles = guidata(obj.myTopFigure);
            set(myHandles.startAcquire, 'Enable', 'on');
            set(myHandles.stopAcquire, 'Enable', 'off');
        end
        function grabFromSweeper1_Callback(obj, src, eventData)
            myHandles = guidata(obj.myTopFigure);
            lowF = get(myHandles.c1Freq, 'String');
            highF = get(myHandles.c2Freq, 'String');
            set(myHandles.highStartFrequency1, 'String', highF);
            set(myHandles.lowStartFrequency1, 'String', lowF);
        end
        function grabFromSweeper2_Callback(obj, src, eventData)
            myHandles = guidata(obj.myTopFigure);
            lowF = get(myHandles.c1Freq, 'String');
            highF = get(myHandles.c2Freq, 'String');
            set(myHandles.highStartFrequency2, 'String', highF);
            set(myHandles.lowStartFrequency2, 'String', lowF);
        end
        function startLockingProtocol(obj)
            myHandles = guidata(obj.myTopFigure);
            
            modeSelected = obj.myLockModes.SelectedChild;
%             modeSelected = 1;
            
            switch modeSelected
                case 1 % Single PID
                    tempVal = get(myHandles.singlePeakLockOptions, 'Value');
                    switch tempVal
                        case 1 %CONTINUOUS LOCK
                            obj.startContinuousLock_initialize();
                        case 2 %INTERMITTENT LOCK WITH DATA POINTS BETWEEN LOCK POINTS
                            obj.startIntermittentLock_initialize();
                    end
                case 2 % Multiple PID
                    tempVal = get(myHandles.multiplePeakLockOptions, 'Value');
                    switch tempVal
                        case 1 %MULTIPLE STRETCHED STATES CONTINUOUS LOCK
                            obj.startContinuousMultiLock_initialize();
                        case 2 % INTERLEAVED 2-SHOT (DIO) LOCK
                            obj.startInterleaved2ShotLock_initialize();
                        case 3 % STEP ANALOG VOLTAGES BETWEEN SEPERATE LOCKS
                            obj.startContinuousMultiLockAnalog_initialize()
                        case 4 % 4 PEAK LOCK
                            obj.start4PeakLock_initialize()
                        case 5 % 4 PEAK LOCK WITH AUTOMATIC REZEROING
                            obj.start4PeakLockRezero_initialize()
                        case 6 % 2 PEAK LOCK WITH AUTOMATIC REZEROING
                            obj.start2PeakLockRezero_initialize()
                    end
            end
        end
        function startContinuousLock_initialize(obj)
            setappdata(obj.myTopFigure, 'readyForData', 0);
            myHandles = guidata(obj.myTopFigure);
            prevExc = 0; %For use in calculating the present Error
            linewidth = str2double(get(myHandles.linewidth, 'String'));
            newCenterFreq = str2double(get(myHandles.lowStartFrequency1, 'String'))+ linewidth/2;
            runNum = 1;
            if get(myHandles.cycleNumOnCN, 'Value')
                runNum = 0;
                obj.myCycleNuControl.initialize();
            end
            seqPlace = 0; %0 = left side of line 1
                          %1 = right side of line 1
            
            %AVOID MEMORY MOVEMENT SLOWDOWNS
            tempScanData = zeros(6,FreqLocker.bufferSize);
            tempSummedData = zeros(1,FreqLocker.bufferSize);
            tempNormData = zeros(1,FreqLocker.bufferSize);
            tempPID1Data = zeros(1,FreqLocker.bufferSize);
            tempDriftData = NaN(2,FreqLocker.bufferSize);
            obj.myDriftFitHandle = [];
            obj.myDriftPlotHandle = [];
            cla(myHandles.DriftAXES);
            
            %2.5 Initialize Frequency Synthesizer
            obj.myFreqSynth.initialize();
            %Start Frequency Loop / Check 'Run'
            set(myHandles.curFreq, 'BackgroundColor', 'green');
            
            if getappdata(obj.myTopFigure, 'run')
                        [path, fileName] = obj.createFileName();
                        try
                            mkdir(path);
                            fid = fopen([path filesep fileName], 'a');
                            fwrite(fid, datestr(now, 'mm/dd/yyyy\tHH:MM AM'))
                            fprintf(fid, '\r\n');
                            colNames = {'Frequency', 'Norm', 'GndState', ...
                                'ExcState', 'Background', 'TStamp', 'BLUEGndState', ...
                                'BLUEBackground', 'BLUEExcState', ...
                                'err1', 'cor1', 'servoVal1', ...
                                'err2', 'cor2', 'servoVal2', ...
                                'err3', 'cor3', 'servoVal3', ...
                                'cycleNum', 'badData'};
                            n = length(colNames);
                            for i=1:n
                                fprintf(fid, '%s\t', colNames{i});
                            end
                                fprintf(fid, '\r\n');
                        catch
                            disp('Could not open file to write to.');
                        end
            end
            
            %Set to first frequency point
            curFrequency = newCenterFreq - linewidth/2;
            ret = obj.myFreqSynth.setFrequency(num2str(curFrequency));
                if ~ret
                    setappdata(obj.myTopFigure, 'run', 0);
                end
            
            setappdata(obj.myTopFigure, 'normData', tempNormData);
            setappdata(obj.myTopFigure, 'scanData', tempScanData);
            setappdata(obj.myTopFigure, 'summedData', tempSummedData);
            setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
            setappdata(obj.myTopFigure, 'DriftData', tempDriftData);
            setappdata(obj.myTopFigure, 'runNum', runNum);
            setappdata(obj.myTopFigure, 'fid', fid);
            setappdata(obj.myTopFigure, 'seqPlace', seqPlace);
            setappdata(obj.myTopFigure, 'prevExc', prevExc);
            setappdata(obj.myTopFigure, 'newCenterFreq', newCenterFreq);
            setappdata(obj.myTopFigure, 'prevFrequency', curFrequency);
            setappdata(obj.myTopFigure, 'nextStep', @obj.startContinuousLock_takeNextPoint);
            pause(0.5) %I think I need this to make sure we get our first point good
            guidata(obj.myTopFigure, myHandles);
            setappdata(obj.myTopFigure, 'readyForData', 1);
        end
        function startContinuousLock_takeNextPoint(obj, data)
            myHandles = guidata(obj.myTopFigure);
            tempNormData = getappdata(obj.myTopFigure, 'normData');
            tempScanData = getappdata(obj.myTopFigure, 'scanData');
            tempSummedData = getappdata(obj.myTopFigure, 'summedData');
            tempPID1Data = getappdata(obj.myTopFigure, 'PID1Data');
            tempDriftData = getappdata(obj.myTopFigure, 'DriftData');
            runNum = getappdata(obj.myTopFigure, 'runNum');
            fid = getappdata(obj.myTopFigure, 'fid');
            seqPlace = getappdata(obj.myTopFigure, 'seqPlace');
            prevExc = getappdata(obj.myTopFigure, 'prevExc');
            linewidth = str2double(get(myHandles.linewidth, 'String'));
            newCenterFreq = getappdata(obj.myTopFigure, 'newCenterFreq');
            prevFrequency = getappdata(obj.myTopFigure, 'prevFrequency');
            badData = 0;
            
            if runNum~=1
                tempH = getappdata(obj.myTopFigure, 'plottingHandles');
                taxis = getappdata(obj.myTopFigure, 'taxis');
            end
            
            if get(myHandles.cycleNumOnCN, 'Value')
                cycleNum = str2double(obj.myCycleNuControl.getCycleNum());
                if runNum ~= 0
                    prevCycleNum = getappdata(obj.myTopFigure, 'prevCycleNum');
                end
                seqPlace = mod(cycleNum-2,2); % 1 for previous measurement and 1 for mike bishof's convention
                fprintf(1,['Cycle Number for data just taken : ' num2str(cycleNum-1) '\rTherfore we just took seqPlace: ' num2str(mod(cycleNum-2,4)) '\n']);
                if runNum ~= 0 && prevCycleNum ~= (cycleNum-1)
                    fprintf(1, 'Cycle Slipped\n');
                    badData = 1;
                end
                setappdata(obj.myTopFigure, 'prevCycleNum', cycleNum);
            end
            
            pointDone = 0;
            while(getappdata(obj.myTopFigure, 'run') && ~pointDone)
                plotstart = 1; %Needs to be out here so plots can be cleared
                
                
                %3. Set Frequency (Display + Synthesizer)
                switch mod(seqPlace+1,2) 
                    case 0 % left side of line 1
                        curFrequency = newCenterFreq - linewidth/2;
                    case 1 % right side of line 2
                        curFrequency = newCenterFreq + linewidth/2;
                end
            
                ret = obj.myFreqSynth.setFrequency(num2str(curFrequency));
                if ~ret
                    setappdata(obj.myTopFigure, 'run', 0);
                    break;
                end
                set(myHandles.curFreq, 'String', num2str(curFrequency));
                set(myHandles.curFreqL, 'String', num2str(curFrequency));
                
                if runNum == 0
                    runNum = runNum + 1;
                    setappdata(obj.myTopFigure, 'runNum', runNum);
                    return;
                end
                %4. Update Progress Bar
                drawnow;
                %5. Call Gage Card to gather data
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
                    %7. Clear the Raw Plots, Plot the Raw Plots
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
                    tempScanData(1:2, :) = [tempScanData(1:2, 2:end) tSCdat12];
                    tempScanData(3,:) = [tempScanData(3, 2:end) tSCdat3];
                    tempScanData(4:6,:) = [tempScanData(4:6, 2:end) tSCdat456];
                    %NORMALIZED counts are (E - bg)/(E + G - 2bg)
                    tNorm = (tSCdat12(2)) / (tSCdat12(2) + tSCdat12(1));
                    tempNormData = [tempNormData(2:end) tNorm];
                    %SUMMED counts
                    tSum = tSCdat12(2) + tSCdat12(1);
                    tempSummedData = [tempSummedData(2:end) tSum];
                    
                    
                    %Do some PID magic!
                    %Calculate Error for PID1
                    calcErr1 = tNorm - prevExc;
                    
                    if runNum >= 2 && ~badData
                        prevExc = tNorm;
                        seqPlace = mod(seqPlace + 1,2);
                            if seqPlace == 0
                                obj.mysPID1.setPolarity(1);
                            else
                                obj.mysPID1.setPolarity(-1);
                                calcErr1 = -1*calcErr1;
                            end
                            obj.updatePIDvalues();
                            obj.checkPIDenables();
                            deltaT = str2double(get(obj.myPID1gui.myDeltaT, 'String'));
                            if deltaT == 0
                                calcCorr1 = obj.mysPID1.calculate(calcErr1, time);
                            else
                                calcCorr1 = obj.mysPID1.calculate(calcErr1, -deltaT);
                            end
                            newCenterFreq = newCenterFreq + calcCorr1;
                    end
                    
                    tempPID1Data = [tempPID1Data(2:end) calcErr1];
                    tempDriftData(1, :) = [tempDriftData(1, 2:end) newCenterFreq];
                    tempDriftData(2, :) = [tempDriftData(2, 2:end) ((time- obj.refTime)/1000)];
                    
                    %Do some Plotting
                    firstplot = 1;
                    if get(myHandles.ignoreFirstToggle, 'Value') && plotstart < 3
                        plotstart = 2;
                        firstplot = 2;
                    end
                    if runNum == 1
                        tempH(1) = plot(myHandles.sNormAxes, tempNormData(end-FreqLocker.plotSize:end), 'ok', 'LineWidth', 3);
                        tempH(2) = plot(myHandles.sEAxes, tempScanData(2,end-FreqLocker.plotSize:end), 'or', 'LineWidth', 2);
                        tempH(3) = plot(myHandles.sGAxes, tempScanData(1,end-FreqLocker.plotSize:end), 'ob', 'LineWidth', 2);
                        tempH(4) = plot(myHandles.sBGAxes, tempScanData(3,end-FreqLocker.plotSize:end), 'ob', 'LineWidth', 1);
                        tempH(5) = plot(myHandles.sSummedAxes, tempSummedData(end-FreqLocker.plotSize:end), 'og', 'LineWidth', 2);
                        tempH(6) = plot(myHandles.errPlot, tempPID1Data(end-FreqLocker.plotSize:end), 'ok', 'LineWidth', 2);
                    elseif runNum > 1
                        set(tempH(1), 'YData', tempNormData(end-FreqLocker.plotSize:end));
                        set(tempH(2), 'YData', tempScanData(2,end-FreqLocker.plotSize:end));
                        set(tempH(3), 'YData', tempScanData(1,end-FreqLocker.plotSize:end));
                        set(tempH(4), 'YData', tempScanData(3,end-FreqLocker.plotSize:end));
                        set(tempH(5), 'YData', tempSummedData(end-FreqLocker.plotSize:end));
                        set(tempH(6), 'YData', tempPID1Data(end-FreqLocker.plotSize:end));
                    end
                    obj.myPID1gui.updateMyPlots(calcErr1, runNum, FreqLocker.plotSize);
                    if mod(seqPlace+1,2) == 0
                        set(myHandles.lockStatus, 'String', 'L1');
                    else
                        set(myHandles.lockStatus, 'String', 'R1');
                    end
                    %9. Check Save and Write Data to file.
% 'Frequency', 'Norm', 'GndState', 'ExcState', 'Background', 'TStamp', 'BLUEGndState', 'BLUEBackground', 'BLUEExcState'

                    temp = [prevFrequency tNorm tSCdat12(1) tSCdat12(2) tSCdat3 str2double(time) tSCdat456(1) tSCdat456(3) tSCdat456(2)];                    
                        if runNum >= 2 && ~badData
                            tempPID1 = [calcErr1 calcCorr1 newCenterFreq];%err correctionApplied servoVal
                        else
                            tempPID1 = [calcErr1 0 newCenterFreq];%err correctionApplied servoVal
                        end
                    tempPID2 = [0 0 0];
                    tempPID3 = [0 0 0];
                    temp = [temp tempPID1 tempPID2 tempPID3];
                    if get(myHandles.cycleNumOnCN, 'Value')
                        temp = [temp prevCycleNum];
                        setappdata(obj.myTopFigure, 'prevCycleNum', cycleNum);
                    else
                        temp = [temp 0];
                    end
                    temp = [temp badData];
                    fprintf(fid, '%8.6f\t', temp);
                    fprintf(fid, '\r\n');
                    
                    if (runNum > 5 && tNorm >= 0.1)
                        set(myHandles.lowStartFrequency1, 'String', num2str(newCenterFreq - linewidth/2));
                        set(myHandles.highStartFrequency1, 'String', num2str(newCenterFreq + linewidth/2));
                    end
                    pointDone = 1;
                    obj.updateDriftPlots(runNum);
            end
            if (getappdata(obj.myTopFigure, 'run')) % Prepare for a new data point
                if runNum == 1
                    setappdata(obj.myTopFigure, 'taxis', taxis);
                end
                runNum = runNum + 1;
                setappdata(obj.myTopFigure, 'prevFrequency', curFrequency);
                setappdata(obj.myTopFigure, 'normData', tempNormData);
                setappdata(obj.myTopFigure, 'scanData', tempScanData);
                setappdata(obj.myTopFigure, 'summedData', tempSummedData);
                setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
                setappdata(obj.myTopFigure, 'DriftData', tempDriftData);
                setappdata(obj.myTopFigure, 'runNum', runNum);
                setappdata(obj.myTopFigure, 'seqPlace', seqPlace);
                setappdata(obj.myTopFigure, 'prevExc', prevExc);
                setappdata(obj.myTopFigure, 'newCenterFreq', newCenterFreq);
                setappdata(obj.myTopFigure, 'plottingHandles', tempH);
                
                guidata(obj.myTopFigure, myHandles);
                
           else %close everything done
               setappdata(obj.myTopFigure, 'readyForData', 0);
                %9.5 Close Frequency Synthesizer and Data file
                obj.mysPID1.clear();
                obj.myFreqSynth.close();
                fclose('all'); % weird matlab thing, can't just close fid, won't work.
                %10. If ~Run, make obvious and reset 'run'
                disp('Acquisistion Stopped');
                set(myHandles.curFreq, 'String', 'STOPPED');
                setappdata(obj.myTopFigure, 'run', 1);
                drawnow;
                try
                    rmappdata(obj.myTopFigure, 'normData');
                    rmappdata(obj.myTopFigure, 'scanData');
                    rmappdata(obj.myTopFigure, 'summedData');
                    rmappdata(obj.myTopFigure, 'PID1Data');
                    rmappdata(obj.myTopFigure, 'DriftData');
                    rmappdata(obj.myTopFigure, 'runNum');
                    rmappdata(obj.myTopFigure, 'taxis');
                    rmappdata(obj.myTopFigure, 'fid');
                    rmappdata(obj.myTopFigure, 'seqPlace');
                    rmappdata(obj.myTopFigure, 'prevExc');
                    rmappdata(obj.myTopFigure, 'newCenterFreq');
                    rmappdata(obj.myTopFigure, 'plottingHandles');
                    rmappdata(obj.myTopFigure, 'prevCycleNum');
                catch exception
                    exception.message
                end
                    
                drawnow;
                
                guidata(obj.myTopFigure, myHandles);

                clear variables
                clear mex
            end
        end
        function startIntermittentLock_initialize(obj)
            setappdata(obj.myTopFigure, 'readyForData', 0);
            myHandles = guidata(obj.myTopFigure);
            prevExc = 0; %For use in calculating the present Error
            linewidth = str2double(get(myHandles.linewidth, 'String'));
            newCenterFreq = str2double(get(myHandles.lowStartFrequency1, 'String'))+ linewidth/2;
            runNum = 1;
            if get(myHandles.cycleNumOnCN, 'Value')
                runNum = 0;
                obj.myCycleNuControl.initialize();
            end
            seqPlace = 0; %0 = left side of line 1
                          %1 = Data point
                          %2 = right side of line 1
                          %3 = Data point
            
            %AVOID MEMORY MOVEMENT SLOWDOWNS
            tempScanData = zeros(6,FreqLocker.bufferSize);
            tempSummedData = zeros(1,FreqLocker.bufferSize);
            tempNormData = zeros(1,FreqLocker.bufferSize);
            tempPID1Data = zeros(1,FreqLocker.bufferSize);
            tempIntermittentData = zeros(1,FreqLocker.bufferSize);
            tempDriftData = NaN(2,FreqLocker.bufferSize);
            obj.myDriftFitHandle = [];
            obj.myDriftPlotHandle = [];
            cla(myHandles.DriftAXES);
            
            %2.5 Initialize Frequency Synthesizer
            obj.myFreqSynth.initialize();
            %Start Frequency Loop / Check 'Run'
            set(myHandles.curFreq, 'BackgroundColor', 'green');
            
            if getappdata(obj.myTopFigure, 'run')
                        [path, fileName] = obj.createFileName();
                        try
                            mkdir(path);
                            fid = fopen([path filesep fileName], 'a');
                            fwrite(fid, datestr(now, 'mm/dd/yyyy\tHH:MM AM'))
                            fprintf(fid, '\r\n');
                            colNames = {'Frequency', 'Norm', 'GndState', ...
                                'ExcState', 'Background', 'TStamp', 'BLUEGndState', ...
                                'BLUEBackground', 'BLUEExcState', ...
                                'err1', 'cor1', 'servoVal1', ...
                                'err2', 'cor2', 'servoVal2', ...
                                'err3', 'cor3', 'servoVal3', ...
                                'cycleNum', 'badData'};
                            n = length(colNames);
                            for i=1:n
                                fprintf(fid, '%s\t', colNames{i});
                            end
                                fprintf(fid, '\r\n');
                        catch
                            disp('Could not open file to write to.');
                        end
            end
            
            %Set to first frequency point
            curFrequency = newCenterFreq - linewidth/2;
            ret = obj.myFreqSynth.setFrequency(num2str(curFrequency));
                if ~ret
                    setappdata(obj.myTopFigure, 'run', 0);
                end
            
            setappdata(obj.myTopFigure, 'normData', tempNormData);
            setappdata(obj.myTopFigure, 'scanData', tempScanData);
            setappdata(obj.myTopFigure, 'summedData', tempSummedData);
            setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
            setappdata(obj.myTopFigure, 'DriftData', tempDriftData);
            setappdata(obj.myTopFigure, 'intermittentData', tempIntermittentData);
            setappdata(obj.myTopFigure, 'runNum', runNum);
            setappdata(obj.myTopFigure, 'fid', fid);
            setappdata(obj.myTopFigure, 'seqPlace', seqPlace);
            setappdata(obj.myTopFigure, 'prevExc', prevExc);
            setappdata(obj.myTopFigure, 'newCenterFreq', newCenterFreq);
            setappdata(obj.myTopFigure, 'prevFrequency', curFrequency);
            setappdata(obj.myTopFigure, 'nextStep', @obj.startIntermittentLock_takeNextPoint);
            pause(0.5) %I think I need this to make sure we get our first point good
            guidata(obj.myTopFigure, myHandles);
            setappdata(obj.myTopFigure, 'readyForData', 1);
        end
        function startIntermittentLock_takeNextPoint(obj, data)
            myHandles = guidata(obj.myTopFigure);
            tempNormData = getappdata(obj.myTopFigure, 'normData');
            tempScanData = getappdata(obj.myTopFigure, 'scanData');
            tempSummedData = getappdata(obj.myTopFigure, 'summedData');
            tempPID1Data = getappdata(obj.myTopFigure, 'PID1Data');
            tempDriftData = getappdata(obj.myTopFigure, 'DriftData');
            tempIntermittentData = getappdata(obj.myTopFigure, 'intermittentData');
            runNum = getappdata(obj.myTopFigure, 'runNum');
            fid = getappdata(obj.myTopFigure, 'fid');
            seqPlace = getappdata(obj.myTopFigure, 'seqPlace');
            prevExc = getappdata(obj.myTopFigure, 'prevExc');
            linewidth = str2double(get(myHandles.linewidth, 'String'));
            newCenterFreq = getappdata(obj.myTopFigure, 'newCenterFreq');
            prevFrequency = getappdata(obj.myTopFigure, 'prevFrequency');
            
            badData = 0;
            detuning = 0;
            
            if runNum~=1
                tempH = getappdata(obj.myTopFigure, 'plottingHandles');
                taxis = getappdata(obj.myTopFigure, 'taxis');
            end
            
            if get(myHandles.cycleNumOnCN, 'Value')
                cycleNum = str2double(obj.myCycleNuControl.getCycleNum());
                if runNum ~= 0
                    prevCycleNum = getappdata(obj.myTopFigure, 'prevCycleNum');
                end
                seqPlace = mod(cycleNum-2,4); % 1 for previous measurement and 1 for mike bishof's convention
                fprintf(1,['Cycle Number for data just taken : ' num2str(cycleNum-1) '\rTherfore we just took seqPlace: ' num2str(mod(cycleNum-2,4)) '\n']);
                if runNum ~= 0 && prevCycleNum ~= (cycleNum-1)
                    fprintf(1, 'Cycle Slipped\n');
                    badData = 1;
                end
                setappdata(obj.myTopFigure, 'prevCycleNum', cycleNum);
            end
            
            pointDone = 0;
            while(getappdata(obj.myTopFigure, 'run') && ~pointDone)
                plotstart = 1; %Needs to be out here so plots can be cleared
                
                
                %3. Set Frequency (Display + Synthesizer)
                switch mod(seqPlace+1,4) 
                    case 0 % left side of line 1 is next
                        curFrequency = newCenterFreq - linewidth/2;
                    case 1 % data point 1 is next
                        curFrequency = newCenterFreq + detuning;
                    case 2 % right side of line 2 is next
                        curFrequency = newCenterFreq + linewidth/2;
                    case 3 % data point 2 is next
                        curFrequency = newCenterFreq + detuning;
                end
            
                ret = obj.myFreqSynth.setFrequency(num2str(curFrequency));
                if ~ret
                    setappdata(obj.myTopFigure, 'run', 0);
                    break;
                end
                set(myHandles.curFreq, 'String', num2str(curFrequency));
                set(myHandles.curFreqL, 'String', num2str(curFrequency));
                
                if runNum == 0
                    runNum = runNum + 1;
                    setappdata(obj.myTopFigure, 'runNum', runNum);
                    return;
                end
                %4. Update Progress Bar
                drawnow;
                %5. Call Gage Card to gather data
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
                    %7. Clear the Raw Plots, Plot the Raw Plots
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
                    tempScanData(1:2, :) = [tempScanData(1:2, 2:end) tSCdat12];
                    tempScanData(3,:) = [tempScanData(3, 2:end) tSCdat3];
                    tempScanData(4:6,:) = [tempScanData(4:6, 2:end) tSCdat456];
                    %NORMALIZED counts are (E - bg)/(E + G - 2bg)
                    tNorm = (tSCdat12(2)) / (tSCdat12(2) + tSCdat12(1));
                    tempNormData = [tempNormData(2:end) tNorm];
                    %SUMMED counts
                    tSum = tSCdat12(2) + tSCdat12(1);
                    tempSummedData = [tempSummedData(2:end) tSum];
                    
                    
                    
                    %Do some PID magic
                    

                    seqPlace = mod(seqPlace + 1,4);% now refers to next point
                    if runNum >= 2 && ~badData
                        switch seqPlace
                            case {1,3} %which means you just took a lock point
                                calcErr1 = prevExc - tNorm;
                                prevExc = tNorm;
                                if seqPlace == 1
                                    obj.mysPID1.setPolarity(1);
                                elseif seqPlace == 3
                                    obj.mysPID1.setPolarity(-1);
                                    calcErr1 = -1*calcErr1;
                                end
                                obj.updatePIDvalues();
                                obj.checkPIDenables();
                                deltaT = str2double(get(obj.myPID1gui.myDeltaT, 'String'));
                                if deltaT == 0
                                    calcCorr1 = obj.mysPID1.calculate(calcErr1, time);
                                else
                                    calcCorr1 = obj.mysPID1.calculate(calcErr1, -deltaT);
                                end
                                newCenterFreq = newCenterFreq + calcCorr1;                      
                            case {0,2} %which means you just took data
                                calcErr1 = 0;
                                calcCorr1 = 0;
                                tempIntermittentData = [tempIntermittentData(2:end), tNorm];
                                if runNum == 2
                                    tempH(13) = plot(myHandles.normExcAXES, tempIntermittentData, 'ok', 'LineWidth', 2);
                                else
                                    set(tempH(13), 'YData', tempIntermittentData);
                                end
                        end
                        tempPID1Data = [tempPID1Data(2:end) calcErr1];
                        tempDriftData(1, :) = [tempDriftData(1, 2:end) newCenterFreq];
                        tempDriftData(2, :) = [tempDriftData(2, 2:end) ((time- obj.refTime)/1000)];
                                
                    else
                        calcErr1 = 0;
                        calcCorr1 = 0;
                    end
                    
                    
                    
                    %Do some Plotting
                    firstplot = 1;
                    if get(myHandles.ignoreFirstToggle, 'Value') && plotstart < 3
                        plotstart = 2;
                        firstplot = 2;
                    end
                    if runNum == 1
                        tempH(1) = plot(myHandles.sNormAxes, tempNormData(end-FreqLocker.plotSize:end), 'ok', 'LineWidth', 3);
                        tempH(2) = plot(myHandles.sEAxes, tempScanData(2,end-FreqLocker.plotSize:end), 'or', 'LineWidth', 2);
                        tempH(3) = plot(myHandles.sGAxes, tempScanData(1,end-FreqLocker.plotSize:end), 'ob', 'LineWidth', 2);
                        tempH(4) = plot(myHandles.sBGAxes, tempScanData(3,end-FreqLocker.plotSize:end), 'ob', 'LineWidth', 1);
                        tempH(5) = plot(myHandles.sSummedAxes, tempSummedData(end-FreqLocker.plotSize:end), 'og', 'LineWidth', 2);
                        tempH(6) = plot(myHandles.errPlot, tempPID1Data(end-FreqLocker.plotSize:end), 'ok', 'LineWidth', 2);
                    elseif runNum > 1
                        set(tempH(1), 'YData', tempNormData(end-FreqLocker.plotSize:end));
                        set(tempH(2), 'YData', tempScanData(2,end-FreqLocker.plotSize:end));
                        set(tempH(3), 'YData', tempScanData(1,end-FreqLocker.plotSize:end));
                        set(tempH(4), 'YData', tempScanData(3,end-FreqLocker.plotSize:end));
                        set(tempH(5), 'YData', tempSummedData(end-FreqLocker.plotSize:end));
                        set(tempH(6), 'YData', tempPID1Data(end-FreqLocker.plotSize:end));
                    end
                    obj.myPID1gui.updateMyPlots(calcErr1, runNum, FreqLocker.plotSize);
                    switch seqPlace %Refers to next point
                        case 0
                        set(myHandles.lockStatus, 'String', 'L1');
                        
                        case 2
                        set(myHandles.lockStatus, 'String', 'R1');
                        
                        otherwise
                        set(myHandles.lockStatus, 'String', 'D');
                    end
                    %9. Check Save and Write Data to file.
% 'Frequency', 'Norm', 'GndState', 'ExcState', 'Background', 'TStamp', 'BLUEGndState', 'BLUEBackground', 'BLUEExcState'

                    temp = [prevFrequency tNorm tSCdat12(1) tSCdat12(2) tSCdat3 str2double(time) tSCdat456(1) tSCdat456(3) tSCdat456(2)];                    
                        if runNum >= 2 && ~badData
                            tempPID1 = [calcErr1 calcCorr1 newCenterFreq];%err correctionApplied servoVal
                        else
                            tempPID1 = [calcErr1 0 newCenterFreq];%err correctionApplied servoVal
                        end
                    tempPID2 = [0 0 0];
                    tempPID3 = [0 0 0];
                    temp = [temp tempPID1 tempPID2 tempPID3];
                    if get(myHandles.cycleNumOnCN, 'Value')
                        temp = [temp prevCycleNum];
                        setappdata(obj.myTopFigure, 'prevCycleNum', cycleNum);
                    else
                        temp = [temp 0];
                    end
                    temp = [temp badData];
                    fprintf(fid, '%8.6f\t', temp);
                    fprintf(fid, '\r\n');
                    
                    if (runNum > 5 && tNorm >= 0.1)
                        set(myHandles.lowStartFrequency1, 'String', num2str(newCenterFreq - linewidth/2));
                        set(myHandles.highStartFrequency1, 'String', num2str(newCenterFreq + linewidth/2));
                    end
                    pointDone = 1;
                    obj.updateDriftPlots(runNum);
            end
            if (getappdata(obj.myTopFigure, 'run')) % Prepare for a new data point
                if runNum == 1
                    setappdata(obj.myTopFigure, 'taxis', taxis);
                end
                runNum = runNum + 1;
                setappdata(obj.myTopFigure, 'prevFrequency', curFrequency);
                setappdata(obj.myTopFigure, 'normData', tempNormData);
                setappdata(obj.myTopFigure, 'scanData', tempScanData);
                setappdata(obj.myTopFigure, 'summedData', tempSummedData);
                setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
                setappdata(obj.myTopFigure, 'DriftData', tempDriftData);
                setappdata(obj.myTopFigure, 'runNum', runNum);
                setappdata(obj.myTopFigure, 'seqPlace', seqPlace);
                setappdata(obj.myTopFigure, 'prevExc', prevExc);
                setappdata(obj.myTopFigure, 'newCenterFreq', newCenterFreq);
                setappdata(obj.myTopFigure, 'plottingHandles', tempH);
                setappdata(obj.myTopFigure, 'intermittentData', tempIntermittentData);
                
                guidata(obj.myTopFigure, myHandles);
                
           else %close everything done
               setappdata(obj.myTopFigure, 'readyForData', 0);
                %9.5 Close Frequency Synthesizer and Data file
                obj.mysPID1.clear();
                obj.myFreqSynth.close();
                fclose('all'); % weird matlab thing, can't just close fid, won't work.
                %10. If ~Run, make obvious and reset 'run'
                disp('Acquisistion Stopped');
                set(myHandles.curFreq, 'String', 'STOPPED');
                setappdata(obj.myTopFigure, 'run', 1);
                drawnow;
                try
                    rmappdata(obj.myTopFigure, 'normData');
                    rmappdata(obj.myTopFigure, 'scanData');
                    rmappdata(obj.myTopFigure, 'summedData');
                    rmappdata(obj.myTopFigure, 'PID1Data');
                    rmappdata(obj.myTopFigure, 'DriftData');
                    rmappdata(obj.myTopFigure, 'runNum');
                    rmappdata(obj.myTopFigure, 'taxis');
                    rmappdata(obj.myTopFigure, 'fid');
                    rmappdata(obj.myTopFigure, 'seqPlace');
                    rmappdata(obj.myTopFigure, 'prevExc');
                    rmappdata(obj.myTopFigure, 'newCenterFreq');
                    rmappdata(obj.myTopFigure, 'plottingHandles');
                    rmappdata(obj.myTopFigure, 'prevCycleNum');
                    rmappdata(obj.myTopFigure, 'intermittentData');
                catch exception
                    exception.message
                end
                    
                drawnow;
                
                guidata(obj.myTopFigure, myHandles);

                clear variables
                clear mex
            end
        end
        function startInterleaved2ShotLock_initialize(obj)
            setappdata(obj.myTopFigure, 'readyForData', 0);
            myHandles = guidata(obj.myTopFigure);
            prevExcL = 0; %For use in calculating the present Error for Low Freq Lock
            prevExcH = 0; %For use in calculating the present Error for Low Freq Lock
            linewidth = str2double(get(myHandles.linewidth, 'String'));
            newCenterFreqL = str2double(get(myHandles.lowStartFrequency1, 'String'))+ linewidth/2;
            newCenterFreqH = str2double(get(myHandles.highStartFrequency1, 'String'))- linewidth/2;
            runNum = 1;
            if get(myHandles.cycleNumOnCN, 'Value')
                runNum = 0;
                obj.myCycleNuControl.initialize();
            end
            seqPlace = 0; %0 = left side of line 1
                          %1 = left side of line 2
                          %2 = right side of line 1
                          %3 = right side of line 2
            
            %AVOID MEMORY MOVEMENT SLOWDOWNS
            tempScanData = zeros(6,FreqLocker.bufferSize);
            tempSummedData = zeros(1,FreqLocker.bufferSize);
            tempNormData = zeros(1,FreqLocker.bufferSize);
            tempPID1Data = zeros(1,FreqLocker.bufferSize);
            tempPID2Data = zeros(1,FreqLocker.bufferSize);
            

            %2.5 Initialize Frequency Synthesizer
            obj.myFreqSynth.initialize();
            %Start Frequency Loop / Check 'Run'
            set(myHandles.curFreq, 'BackgroundColor', 'green');
            
            if getappdata(obj.myTopFigure, 'run')
                        [path, fileName] = obj.createFileName();
                        try
                            mkdir(path);
                            fid = fopen([path filesep fileName], 'a');
                            fwrite(fid, datestr(now, 'mm/dd/yyyy\tHH:MM AM'))
                            fprintf(fid, '\r\n');
                            colNames = {'Frequency', 'Norm', 'GndState', ...
                                'ExcState', 'Background', 'TStamp', 'BLUEGndState', ...
                                'BLUEBackground', 'BLUEExcState', ...
                                'err1', 'cor1', 'servoVal1', ...
                                'err2', 'cor2', 'servoVal2', ...
                                'err3', 'cor3', 'servoVal3', ...
                                'freqSr', 'cycleNum', 'badData'};
                            n = length(colNames);
                            for i=1:n
                                fprintf(fid, '%s\t', colNames{i});
                            end
                                fprintf(fid, '\r\n');
                        catch
                            disp('Could not open file to write to.');
                        end
            end
            %Set to first frequency point
            curFrequency = newCenterFreqL - linewidth/2;
            ret = obj.myFreqSynth.setFrequency(num2str(curFrequency));
                if ~ret
                    setappdata(obj.myTopFigure, 'run', 0);
                end
            
            setappdata(obj.myTopFigure, 'normData', tempNormData);
            setappdata(obj.myTopFigure, 'scanData', tempScanData);
            setappdata(obj.myTopFigure, 'summedData', tempSummedData);
            setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
            setappdata(obj.myTopFigure, 'PID2Data', tempPID2Data);
            setappdata(obj.myTopFigure, 'runNum', runNum);
            setappdata(obj.myTopFigure, 'fid', fid);
            setappdata(obj.myTopFigure, 'seqPlace', seqPlace);
            setappdata(obj.myTopFigure, 'prevExcL', prevExcL);
            setappdata(obj.myTopFigure, 'prevExcH', prevExcH);
            setappdata(obj.myTopFigure, 'newCenterFreqL', newCenterFreqL);
            setappdata(obj.myTopFigure, 'newCenterFreqH', newCenterFreqH);
            setappdata(obj.myTopFigure, 'prevFrequency', curFrequency);
            setappdata(obj.myTopFigure, 'nextStep', @obj.startInterleaved2ShotLock_takeNextPoint);
            pause(0.5) %I think I need this to make sure we get our first point good
            guidata(obj.myTopFigure, myHandles);
            setappdata(obj.myTopFigure, 'readyForData', 1);
        end
        function startInterleaved2ShotLock_takeNextPoint(obj, data)
            myHandles = guidata(obj.myTopFigure);
            tempNormData = getappdata(obj.myTopFigure, 'normData');
            tempScanData = getappdata(obj.myTopFigure, 'scanData');
            tempSummedData = getappdata(obj.myTopFigure, 'summedData');
            tempPID1Data = getappdata(obj.myTopFigure, 'PID1Data');
            tempPID2Data = getappdata(obj.myTopFigure, 'PID2Data');
            runNum = getappdata(obj.myTopFigure, 'runNum');
            fid = getappdata(obj.myTopFigure, 'fid');
            seqPlace = getappdata(obj.myTopFigure, 'seqPlace');
            prevExcL = getappdata(obj.myTopFigure, 'prevExcL');
            prevExcH = getappdata(obj.myTopFigure, 'prevExcH');
            linewidth = str2double(get(myHandles.linewidth, 'String'));
            newCenterFreqL = getappdata(obj.myTopFigure, 'newCenterFreqL');
            newCenterFreqH = getappdata(obj.myTopFigure, 'newCenterFreqH');
            prevFrequency = getappdata(obj.myTopFigure, 'prevFrequency');
            badData = 0;
            
            if runNum > 1
                tempH = getappdata(obj.myTopFigure, 'plottingHandles');
                taxis = getappdata(obj.myTopFigure, 'taxis');
            end
            
            if get(myHandles.cycleNumOnCN, 'Value')
                cycleNum = str2double(obj.myCycleNuControl.getCycleNum());
                if runNum ~= 0
                    prevCycleNum = getappdata(obj.myTopFigure, 'prevCycleNum');
                end
                seqPlace = mod(cycleNum-2,4); % 1 for previous measurement and 1 for mike bishof's convention
                 fprintf(1,['Cycle Number I just read was : ' num2str(cycleNum-1) '\rTherfore we should be at seqPlace: ' num2str(mod(cycleNum-2,4))]);
                if runNum ~= 0 && prevCycleNum ~= (cycleNum-1)
                    fprintf(1, 'Cycle Slipped\n');
                    badData = 1;
                end
                setappdata(obj.myTopFigure, 'prevCycleNum', cycleNum);
            end
            pointDone = 0;
            while(getappdata(obj.myTopFigure, 'run') && ~pointDone)
                plotstart = 1; %Needs to be out here so plots can be cleared
                %IMMEDIATELY READJUST LC WAVEPLATE and set frequency for
                %next point.
                    switch mod(seqPlace+1,4) 
                        case 0 % left side of line 1
                            curFrequency = newCenterFreqL - linewidth/2;
                        case 1 % left side of line 2
                            curFrequency = newCenterFreqH - linewidth/2;
                        case 2 % right side of line 1
                            curFrequency = newCenterFreqL + linewidth/2;
                        case 3 % right side of line 2
                            curFrequency = newCenterFreqH + linewidth/2;
                    end

                ret = obj.myFreqSynth.setFrequency(num2str(curFrequency));
                if ~ret
                    setappdata(obj.myTopFigure, 'run', 0);
                    break;
                end
                set(myHandles.curFreq, 'String', num2str(curFrequency));
                set(myHandles.curFreqL, 'String', num2str(curFrequency));
                
                if runNum == 0
                    runNum = runNum + 1;
                    setappdata(obj.myTopFigure, 'runNum', runNum);
                    return;
                end
                %4. Update Progress Bar
                drawnow;
                %5. Call Gage Card to gather data
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
                    %7. Clear the Raw Plots, Plot the Raw Plots
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
                    tempScanData(1:2, :) = [tempScanData(1:2, 2:end) tSCdat12];
                    tempScanData(3,:) = [tempScanData(3, 2:end) tSCdat3];
                    tempScanData(4:6,:) = [tempScanData(4:6, 2:end) tSCdat456];
                    %NORMALIZED counts are (E - bg)/(E + G - 2bg)
                    tNorm = (tSCdat12(2)) / (tSCdat12(2) + tSCdat12(1));
                    tempNormData = [tempNormData(2:end) tNorm];
                    %SUMMED counts
                    tSum = tSCdat12(2) + tSCdat12(1);
                    tempSummedData = [tempSummedData(2:end) tSum];
                    
                    
                    %Do some PID magic!
                    %Calculate Error for PID1
                    switch seqPlace
                        case {0, 2}
                            calcErr1 = tNorm - prevExcL;
                            tempPID1Data = getappdata(obj.myTopFigure, 'PID1Data');
                        case {1, 3}
                            calcErr2 = tNorm - prevExcH;
                            tempPID2Data = getappdata(obj.myTopFigure, 'PID2Data');
                    end
                    
                    if runNum >= 2 && ~badData
                        switch seqPlace
                            case {0,2}
                                prevExcL = tNorm;
                            case {1, 3}
                                prevExcH = tNorm;
                        end
                        switch seqPlace
                                case 0
                                    obj.mysPID1.setPolarity(-1);
                                    calcErr1 = -1*calcErr1;
                                case 2
                                    obj.mysPID1.setPolarity(1);
                                case 1
                                    obj.mysPID2.setPolarity(-1);
                                    calcErr2 = -1*calcErr2;
                                case 3
                                    obj.mysPID2.setPolarity(1);
                        end
                        obj.updatePIDvalues();
                        obj.checkPIDenables();
                        deltaT1 = str2double(get(obj.myPID1gui.myDeltaT, 'String'));
                        deltaT2 = str2double(get(obj.myPID1gui.myDeltaT, 'String'));
                        switch seqPlace
                            case 0
                                calcCorr1 = 0;
                            case 2
                                    if deltaT1 == 0
                                        calcCorr1 = obj.mysPID1.calculate(calcErr1, time);
                                    else
                                        calcCorr1 = obj.mysPID1.calculate(calcErr1, -deltaT1);
                                    end
                                        newCenterFreqL = newCenterFreqL + calcCorr1;
                            case 1
                                calcCorr2 = 0;
                            case 3
                                    if deltaT2 == 0
                                        calcCorr2 = obj.mysPID2.calculate(calcErr2, time);
                                    else
                                        calcCorr2 = obj.mysPID2.calculate(calcErr2, -deltaT2);
                                    end
                                        newCenterFreqH = newCenterFreqH + calcCorr2;
                        end
                    end
                    
                    switch seqPlace
                        case 2
                            tempPID1Data = [tempPID1Data(2:end) calcErr1];
                        case 3
                            tempPID2Data = [tempPID2Data(2:end) calcErr2];
                    end
                    
                    %Do some Plotting
                    firstplot = 1;
                    if get(myHandles.ignoreFirstToggle, 'Value') && plotstart < 3
                        plotstart = 2;
                        firstplot = 2;
                    end
                    if runNum == 1
                        tempH(1) = plot(myHandles.sNormAxes, tempNormData(end-FreqLocker.plotSize:end), 'ok', 'LineWidth', 3);
                        tempH(2) = plot(myHandles.sEAxes, tempScanData(2,end-FreqLocker.plotSize:end), 'or', 'LineWidth', 2);
                        tempH(3) = plot(myHandles.sGAxes, tempScanData(1,end-FreqLocker.plotSize:end), 'ob', 'LineWidth', 2);
                        tempH(4) = plot(myHandles.sBGAxes, tempScanData(3,end-FreqLocker.plotSize:end), 'ob', 'LineWidth', 1);
                        tempH(5) = plot(myHandles.sSummedAxes, tempSummedData(end-FreqLocker.plotSize:end), 'og', 'LineWidth', 2);
                        tempH(6) = plot(myHandles.errPlot, tempPID1Data(end-FreqLocker.plotSize:end), 'ok', 'LineWidth', 2);
                    elseif runNum > 1
                        set(tempH(1), 'YData', tempNormData(end-FreqLocker.plotSize:end));
                        set(tempH(2), 'YData', tempScanData(2,end-FreqLocker.plotSize:end));
                        set(tempH(3), 'YData', tempScanData(1,end-FreqLocker.plotSize:end));
                        set(tempH(4), 'YData', tempScanData(3,end-FreqLocker.plotSize:end));
                        set(tempH(5), 'YData', tempSummedData(end-FreqLocker.plotSize:end));
                        set(tempH(6), 'YData', tempPID1Data(end-FreqLocker.plotSize:end));
                    end
                    switch seqPlace
                        case {0,2}
                            obj.myPID1gui.updateMyPlots(calcErr1, runNum, FreqLocker.plotSize);
                        case {1,3}
                            obj.myPID2gui.updateMyPlots(calcErr2, runNum, FreqLocker.plotSize);
                    end
                    switch mod(seqPlace+1,4)
                        case 0
                            set(myHandles.lockStatus, 'String', 'Low_L');
                        case 2
                            set(myHandles.lockStatus, 'String', 'Low_R');
                        case 1
                            set(myHandles.lockStatus, 'String', 'High_L');
                        case 3
                            set(myHandles.lockStatus, 'String', 'High_R');
                    end
                    %9. Check Save and Write Data to file.
% 'Frequency', 'Norm', 'GndState', 'ExcState', 'Background', 'TStamp', 'BLUEGndState', 'BLUEBackground', 'BLUEExcState'
                    temp = [prevFrequency tNorm tSCdat12(1) tSCdat12(2) tSCdat3 time tSCdat456(1) tSCdat456(3) tSCdat456(2)];
                    
                        if runNum >= 2 && seqPlace == 2 && ~badData
                            tempPID1 = [calcErr1 calcCorr1 newCenterFreqL];%err correctionApplied servoVal
                        else
                            tempPID1 = [0 0 0];%err correctionApplied servoVal
                        end

                        if runNum >= 2 && seqPlace == 3 && ~badData
                            tempPID2 = [calcErr2 calcCorr2 newCenterFreqH];%err correctionApplied servoVal
                        else
                            tempPID2 = [0 0 newCenterFreqH];
                        end
                    tempPID3 = [0 0 0];
                    temp = [temp tempPID1 tempPID2 tempPID3];
                    if get(myHandles.calcSrFreq, 'Value') && runNum >= 4
                        temp = [temp (newCenterFreqL + newCenterFreqH)/2];
                    else
                        temp = [temp 0];
                    end
                    if get(myHandles.cycleNumOnCN, 'Value')
                        temp = [temp prevCycleNum];
                        setappdata(obj.myTopFigure, 'prevCycleNum', cycleNum);
                    else
                        temp = [temp 0];
                    end
                    temp = [temp badData];
                    fprintf(fid, '%8.6f\t', temp);
                    fprintf(fid, '\r\n');
                    
                    
                    if (runNum > 5 && tNorm >= 0.1)
                        set(myHandles.lowStartFrequency1, 'String', num2str(newCenterFreqL - linewidth/2));
                        set(myHandles.highStartFrequency1, 'String', num2str(newCenterFreqH + linewidth/2));
                    end
                    pointDone = 1;
            end
            if (getappdata(obj.myTopFigure, 'run')) % Prepare for a new data point
                if runNum == 1
                    setappdata(obj.myTopFigure, 'taxis', taxis);
                end
                runNum = runNum + 1;
                seqPlace = mod(seqPlace + 1,4);
                setappdata(obj.myTopFigure, 'prevFrequency', curFrequency);
                setappdata(obj.myTopFigure, 'normData', tempNormData);
                setappdata(obj.myTopFigure, 'scanData', tempScanData);
                setappdata(obj.myTopFigure, 'summedData', tempSummedData);
                setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
                setappdata(obj.myTopFigure, 'PID2Data', tempPID2Data);
                setappdata(obj.myTopFigure, 'runNum', runNum);
                setappdata(obj.myTopFigure, 'seqPlace', seqPlace);
                setappdata(obj.myTopFigure, 'prevExcL', prevExcL);
                setappdata(obj.myTopFigure, 'prevExcH', prevExcH);
                setappdata(obj.myTopFigure, 'newCenterFreqL', newCenterFreqL);
                setappdata(obj.myTopFigure, 'newCenterFreqH', newCenterFreqH);
                setappdata(obj.myTopFigure, 'plottingHandles', tempH);
                
                guidata(obj.myTopFigure, myHandles);
               
            else %close everything done
                setappdata(obj.myTopFigure, 'readyForData', 0);
                %9.5 Close Frequency Synthesizer and Data file
                obj.mysPID1.clear();
                obj.mysPID2.clear();
                obj.myFreqSynth.close();
                fclose('all'); % weird matlab thing, can't just close fid, won't work.
                %10. If ~Run, make obvious and reset 'run'
                disp('Acquisistion Stopped');
                set(myHandles.curFreq, 'String', 'STOPPED');
                setappdata(obj.myTopFigure, 'run', 1);
                drawnow;
                try
                    rmappdata(obj.myTopFigure, 'normData');
                    rmappdata(obj.myTopFigure, 'scanData');
                    rmappdata(obj.myTopFigure, 'summedData');
                    rmappdata(obj.myTopFigure, 'PID1Data');
                    rmappdata(obj.myTopFigure, 'PID2Data');
                    rmappdata(obj.myTopFigure, 'runNum');
                    rmappdata(obj.myTopFigure, 'taxis');
                    rmappdata(obj.myTopFigure, 'fid');
                    rmappdata(obj.myTopFigure, 'seqPlace');
                    rmappdata(obj.myTopFigure, 'prevExcL');
                    rmappdata(obj.myTopFigure, 'prevExcH');
                    rmappdata(obj.myTopFigure, 'newCenterFreqL');
                    rmappdata(obj.myTopFigure, 'newCenterFreqH');
                    rmappdata(obj.myTopFigure, 'prevFrequency');
                    rmappdata(obj.myTopFigure, 'plottingHandles');
                    rmappdata(obj.myTopFigure, 'prevCycleNum');
                catch exception
                    exception.message
                end
                drawnow;
                
                guidata(obj.myTopFigure, myHandles);
                
                clear variables
                clear mex
            end
        end
        function startContinuousMultiLock_initialize(obj)
            setappdata(obj.myTopFigure, 'readyForData', 0);
            myHandles = guidata(obj.myTopFigure);
            prevExcL = 0; %For use in calculating the present Error for Low Freq Lock
            prevExcH = 0; %For use in calculating the present Error for Low Freq Lock
            linewidth = str2double(get(myHandles.linewidth, 'String'));
            linewidth2 = str2double(get(myHandles.linewidth2, 'String'));
            newCenterFreqL = str2double(get(myHandles.lowStartFrequency1, 'String'))+ linewidth/2;
            newCenterFreqH = str2double(get(myHandles.highStartFrequency1, 'String'))- linewidth/2;
            runNum = 1;
            if get(myHandles.cycleNumOnCN, 'Value')
                runNum = 0;
                obj.myCycleNuControl.initialize();
            end
            seqPlace = 0; %0 = left side of line 1
                          %1 = right side of line 1
                          %2 = left side of line 2
                          %3 = right side of line 2
            
            %AVOID MEMORY MOVEMENT SLOWDOWNS
            tempScanData = zeros(6,FreqLocker.bufferSize);
            tempSummedData = zeros(1,FreqLocker.bufferSize);
            tempNormData = zeros(1,FreqLocker.bufferSize);
            tempPID1Data = zeros(1,FreqLocker.bufferSize);
            tempPID2Data = zeros(1,FreqLocker.bufferSize);
            tempDriftData = NaN(2,FreqLocker.bufferSize);
            obj.myDriftFitHandle = [];
            obj.myDriftPlotHandle = [];
            cla(myHandles.DriftAXES);
            
            
            
            %Initialize Liquid Crystal Waveplate
            if get(myHandles.bounceLCwaveplate, 'Value') && strcmp(get(myHandles.openSerialLC, 'Enable'), 'off')
                fprintf(obj.myLCuControl.mySerial, 'H');
            end
            

            %2.5 Initialize Frequency Synthesizer
            obj.myFreqSynth.initialize();
            %Start Frequency Loop / Check 'Run'
            set(myHandles.curFreq, 'BackgroundColor', 'green');
            
            if getappdata(obj.myTopFigure, 'run')
                        [path, fileName] = obj.createFileName();
                        try
                            mkdir(path);
                            fid = fopen([path filesep fileName], 'a');
                            fwrite(fid, datestr(now, 'mm/dd/yyyy\tHH:MM AM'))
                            fprintf(fid, '\r\n');
                            colNames = {'Frequency', 'Norm', 'GndState', ...
                                'ExcState', 'Background', 'TStamp', 'BLUEGndState', ...
                                'BLUEBackground', 'BLUEExcState', ...
                                'err1', 'cor1', 'servoVal1', ...
                                'err2', 'cor2', 'servoVal2', ...
                                'err3', 'cor3', 'servoVal3', ...
                                'freqSr', 'delta','cycleNum', 'badData'};
%                             if get(myHandles.stepVoltages, 'Value')
%                                 colNames = [colNames obj.myAnalogStepper.myNames];
%                             end
                            n = length(colNames);
                            for i=1:n
                                fprintf(fid, '%s\t', colNames{i});
                            end
                                fprintf(fid, '\r\n');
                        catch
                            disp('Could not open file to write to.');
                        end
            end
            %Set to first frequency point
            curFrequency = newCenterFreqL - linewidth/2;
            ret = obj.myFreqSynth.setFrequency(num2str(curFrequency));
                if ~ret
                    setappdata(obj.myTopFigure, 'run', 0);
                end
            
            setappdata(obj.myTopFigure, 'normData', tempNormData);
            setappdata(obj.myTopFigure, 'scanData', tempScanData);
            setappdata(obj.myTopFigure, 'summedData', tempSummedData);
            setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
            setappdata(obj.myTopFigure, 'PID2Data', tempPID2Data);
            setappdata(obj.myTopFigure, 'DriftData', tempDriftData);
            setappdata(obj.myTopFigure, 'runNum', runNum);
            setappdata(obj.myTopFigure, 'fid', fid);
            setappdata(obj.myTopFigure, 'seqPlace', seqPlace);
            setappdata(obj.myTopFigure, 'prevExcL', prevExcL);
            setappdata(obj.myTopFigure, 'prevExcH', prevExcH);
            setappdata(obj.myTopFigure, 'newCenterFreqL', newCenterFreqL);
            setappdata(obj.myTopFigure, 'newCenterFreqH', newCenterFreqH);
            setappdata(obj.myTopFigure, 'prevFrequency', curFrequency);
            setappdata(obj.myTopFigure, 'nextStep', @obj.startContinuousMultiLock_takeNextPoint);
            pause(0.5) %I think I need this to make sure we get our first point good
            guidata(obj.myTopFigure, myHandles);
            setappdata(obj.myTopFigure, 'readyForData', 1);
        end
        function startContinuousMultiLock_takeNextPoint(obj, data)
            myHandles = guidata(obj.myTopFigure);
            tempNormData = getappdata(obj.myTopFigure, 'normData');
            tempScanData = getappdata(obj.myTopFigure, 'scanData');
            tempSummedData = getappdata(obj.myTopFigure, 'summedData');
            tempPID1Data = getappdata(obj.myTopFigure, 'PID1Data');
            tempPID2Data = getappdata(obj.myTopFigure, 'PID2Data');
            tempDriftData = getappdata(obj.myTopFigure, 'DriftData');
            runNum = getappdata(obj.myTopFigure, 'runNum');
            fid = getappdata(obj.myTopFigure, 'fid');
            seqPlace = getappdata(obj.myTopFigure, 'seqPlace');
            prevExcL = getappdata(obj.myTopFigure, 'prevExcL');
            prevExcH = getappdata(obj.myTopFigure, 'prevExcH');
            linewidth = str2double(get(myHandles.linewidth, 'String'));
            linewidth2 = str2double(get(myHandles.linewidth2, 'String'));
            newCenterFreqL = getappdata(obj.myTopFigure, 'newCenterFreqL');
            newCenterFreqH = getappdata(obj.myTopFigure, 'newCenterFreqH');
            prevFrequency = getappdata(obj.myTopFigure, 'prevFrequency');
            badData = 0;
            
            if runNum > 1
                tempH = getappdata(obj.myTopFigure, 'plottingHandles');
                taxis = getappdata(obj.myTopFigure, 'taxis');
            end
            
            if get(myHandles.cycleNumOnCN, 'Value')
                cycleNum = str2double(obj.myCycleNuControl.getCycleNum());
                if runNum ~= 0
                    prevCycleNum = getappdata(obj.myTopFigure, 'prevCycleNum');
                end
                seqPlace = mod(cycleNum-2,4); % 1 for previous measurement and 1 for mike bishof's convention
                fprintf(1,['Cycle Number for data just taken : ' num2str(cycleNum-1) '\rTherfore we just took seqPlace: ' num2str(mod(cycleNum-2,4)) '\n']);
                if runNum ~= 0 && prevCycleNum ~= (cycleNum-1)
                    fprintf(1, 'Cycle Slipped\n');
                    badData = 1;
                end
                setappdata(obj.myTopFigure, 'prevCycleNum', cycleNum);
            end
            pointDone = 0;
            while(getappdata(obj.myTopFigure, 'run') && ~pointDone)
                plotstart = 1; %Needs to be out here so plots can be cleared
                %IMMEDIATELY READJUST LC WAVEPLATE and set frequency for
                %next point.
                   switch mod(seqPlace+1,4) 
                        case 0 % left side of line 1
                            curFrequency = newCenterFreqL - linewidth/2;
                        case 1 % right side of line 1
                            curFrequency = newCenterFreqL + linewidth/2;
                        case 2 % left side of line 2
                            curFrequency = newCenterFreqH - linewidth2/2;
                        case 3 % right side of line 2
                            curFrequency = newCenterFreqH + linewidth2/2;
                    end
%                 if get(myHandles.bounceLCwaveplate, 'Value') && strcmp(get(myHandles.openSerialLC, 'Enable'), 'off')
                if strcmp(get(myHandles.openSerialLC, 'Enable'), 'off')
                    disp([':1;c' int2str(mod(seqPlace+1,4)) ';d0;t80000']);
                    fprintf(obj.myLCuControl.mySerial, [':1;c' int2str(mod(seqPlace+1,4)) ';d0;t80000']);
                    %fscanf(obj.myLCuControl.mySerial)
                end
                

                ret = obj.myFreqSynth.setFrequency(num2str(curFrequency));
                if ~ret
                    setappdata(obj.myTopFigure, 'run', 0);
                    break;
                end
                set(myHandles.curFreq, 'String', num2str(curFrequency));
                set(myHandles.curFreqL, 'String', num2str(curFrequency));
                
                if runNum == 0
                    runNum = runNum + 1;
                    setappdata(obj.myTopFigure, 'runNum', runNum);
                    return;
                end
                %4. Update Progress Bar
                drawnow;
                %5. Call Gage Card to gather data
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
                    %7. Clear the Raw Plots, Plot the Raw Plots
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
                    tempScanData(1:2, :) = [tempScanData(1:2, 2:end) tSCdat12];
                    tempScanData(3,:) = [tempScanData(3, 2:end) tSCdat3];
                    tempScanData(4:6,:) = [tempScanData(4:6, 2:end) tSCdat456];
                    %NORMALIZED counts are (E - bg)/(E + G - 2bg)
                    tNorm = (tSCdat12(2)) / (tSCdat12(2) + tSCdat12(1));
                    tempNormData = [tempNormData(2:end) tNorm];
                    %SUMMED counts
                    tSum = tSCdat12(2) + tSCdat12(1);
                    tempSummedData = [tempSummedData(2:end) tSum];
                    
                    
                    %Do some PID magic!
                    %Calculate Error for PID1
                    switch seqPlace
                        case {0, 1}
                            calcErr1 = tNorm - prevExcL;
                            tempPID1Data = getappdata(obj.myTopFigure, 'PID1Data');
                        case {2, 3}
                            calcErr2 = tNorm - prevExcH;
                            tempPID2Data = getappdata(obj.myTopFigure, 'PID2Data');
                    end
                    
                    if runNum >= 2 && ~badData
                        switch seqPlace
                            case {0,1}
                                prevExcL = tNorm;
                            case {2, 3}
                                prevExcH = tNorm;
                        end
                        switch seqPlace
                                case 0
                                    obj.mysPID1.setPolarity(-1);
                                    calcErr1 = -1*calcErr1;
                                case 1
                                    obj.mysPID1.setPolarity(1);
                                case 2
                                    obj.mysPID2.setPolarity(-1);
                                    calcErr2 = -1*calcErr2;
                                case 3
                                    obj.mysPID2.setPolarity(1);
                        end
                        obj.updatePIDvalues();
                        obj.checkPIDenables();
                        deltaT1 = str2double(get(obj.myPID1gui.myDeltaT, 'String'));
                        deltaT2 = str2double(get(obj.myPID1gui.myDeltaT, 'String'));
                            switch seqPlace
                                case 0
                                    calcCorr1 = 0;
                                case 1
                                        if deltaT1 == 0
                                            calcCorr1 = obj.mysPID1.calculate(calcErr1, time);
                                        else
                                            calcCorr1 = obj.mysPID1.calculate(calcErr1, -deltaT1);
                                        end
                                            newCenterFreqL = newCenterFreqL + calcCorr1;
                                case 2
                                    calcCorr2 = 0;
                                case 3
                                        if deltaT2 == 0
                                            calcCorr2 = obj.mysPID2.calculate(calcErr2, time);
                                        else
                                            calcCorr2 = obj.mysPID2.calculate(calcErr2, -deltaT2);
                                        end
                                            newCenterFreqH = newCenterFreqH + calcCorr2;
                            end
                    end
                    
                        switch seqPlace
                            case 1
                                tempPID1Data = [tempPID1Data(2:end) calcErr1];
                                tempDriftData(1, :) = [tempDriftData(1, 2:end) (newCenterFreqL + newCenterFreqH)/2];
                                tempDriftData(2, :) = [tempDriftData(2, 2:end) ((time- obj.refTime)/1000)];
                            case 3
                                tempPID2Data = [tempPID2Data(2:end) calcErr2];
                                tempDriftData(1, :) = [tempDriftData(1, 2:end) (newCenterFreqL + newCenterFreqH)/2];
                                tempDriftData(2, :) = [tempDriftData(2, 2:end) ((time- obj.refTime)/1000)];
                        end
                    
                    %Do some Plotting
                    firstplot = 1;
                    if get(myHandles.ignoreFirstToggle, 'Value') && plotstart < 3
                        plotstart = 2;
                        firstplot = 2;
                    end
                    if runNum == 1
                        tempH(1) = plot(myHandles.sNormAxes, tempNormData(end-FreqLocker.plotSize:end), 'ok', 'LineWidth', 3);
                        tempH(2) = plot(myHandles.sEAxes, tempScanData(2,end-FreqLocker.plotSize:end), 'or', 'LineWidth', 2);
                        tempH(3) = plot(myHandles.sGAxes, tempScanData(1,end-FreqLocker.plotSize:end), 'ob', 'LineWidth', 2);
                        tempH(4) = plot(myHandles.sBGAxes, tempScanData(3,end-FreqLocker.plotSize:end), 'ob', 'LineWidth', 1);
                        tempH(5) = plot(myHandles.sSummedAxes, tempSummedData(end-FreqLocker.plotSize:end), 'og', 'LineWidth', 2);
                        tempH(6) = plot(myHandles.errPlot, tempPID1Data(end-FreqLocker.plotSize:end), 'ok', 'LineWidth', 2);
                    elseif runNum > 1
                        set(tempH(1), 'YData', tempNormData(end-FreqLocker.plotSize:end));
                        set(tempH(2), 'YData', tempScanData(2,end-FreqLocker.plotSize:end));
                        set(tempH(3), 'YData', tempScanData(1,end-FreqLocker.plotSize:end));
                        set(tempH(4), 'YData', tempScanData(3,end-FreqLocker.plotSize:end));
                        set(tempH(5), 'YData', tempSummedData(end-FreqLocker.plotSize:end));
                        set(tempH(6), 'YData', tempPID1Data(end-FreqLocker.plotSize:end));
                    end
                    switch seqPlace
                        case {0,1}
                            obj.myPID1gui.updateMyPlots(calcErr1, runNum, FreqLocker.plotSize);
                        case {2,3}
                            obj.myPID2gui.updateMyPlots(calcErr2, runNum, FreqLocker.plotSize);
                    end
                    switch mod(seqPlace+1,4)
                        case 0
                            set(myHandles.lockStatus, 'String', 'Low_L');
                        case 1
                            set(myHandles.lockStatus, 'String', 'Low_R');
                        case 2
                            set(myHandles.lockStatus, 'String', 'High_L');
                        case 3
                            set(myHandles.lockStatus, 'String', 'High_R');
                    end
                    %9. Check Save and Write Data to file.
% 'Frequency', 'Norm', 'GndState', 'ExcState', 'Background', 'TStamp', 'BLUEGndState', 'BLUEBackground', 'BLUEExcState'
                    temp = [prevFrequency tNorm tSCdat12(1) tSCdat12(2) tSCdat3 time tSCdat456(1) tSCdat456(3) tSCdat456(2)];
                    
                        if runNum >= 2 && seqPlace == 1 && ~badData
                            tempPID1 = [calcErr1 calcCorr1 newCenterFreqL];%err correctionApplied servoVal
                        else
                            tempPID1 = [0 0 0];%err correctionApplied servoVal
                        end
                        if runNum >= 2 && seqPlace == 3 && ~badData
                            tempPID2 = [calcErr2 calcCorr2 newCenterFreqH];%err correctionApplied servoVal
                        else
                            tempPID2 = [0 0 0];
                        end
                    tempPID3 = [0 0 0];
                    temp = [temp tempPID1 tempPID2 tempPID3];
                    if get(myHandles.calcSrFreq, 'Value') && runNum >= 4
                        temp = [temp (newCenterFreqL + newCenterFreqH)/2];
                        %delta
                        temp = [temp (newCenterFreqL - newCenterFreqH)];
                    else
                        temp = [temp 0 0];
                    end
                    if get(myHandles.cycleNumOnCN, 'Value')
                        temp = [temp prevCycleNum];
                        setappdata(obj.myTopFigure, 'prevCycleNum', cycleNum);
                    else
                        temp = [temp 0];
                    end
                    temp = [temp badData];
                    fprintf(fid, '%8.6f\t', temp);
                    fprintf(fid, '\r\n');
                    
                    
                    if (runNum > 5 && tNorm >= 0.1)
                        set(myHandles.lowStartFrequency1, 'String', num2str(newCenterFreqL - linewidth/2));
                        set(myHandles.highStartFrequency1, 'String', num2str(newCenterFreqH + linewidth2/2));
                    end
                    pointDone = 1;
                    obj.updateDriftPlots(runNum);
            end
            if (getappdata(obj.myTopFigure, 'run')) % Prepare for a new data point
                if runNum == 1
                    setappdata(obj.myTopFigure, 'taxis', taxis);
                end
                runNum = runNum + 1;
                seqPlace = mod(seqPlace + 1,4);
                setappdata(obj.myTopFigure, 'prevFrequency', curFrequency);
                setappdata(obj.myTopFigure, 'normData', tempNormData);
                setappdata(obj.myTopFigure, 'scanData', tempScanData);
                setappdata(obj.myTopFigure, 'summedData', tempSummedData);
                setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
                setappdata(obj.myTopFigure, 'PID2Data', tempPID2Data);
                setappdata(obj.myTopFigure, 'DriftData', tempDriftData);
                setappdata(obj.myTopFigure, 'runNum', runNum);
                setappdata(obj.myTopFigure, 'seqPlace', seqPlace);
                setappdata(obj.myTopFigure, 'prevExcL', prevExcL);
                setappdata(obj.myTopFigure, 'prevExcH', prevExcH);
                setappdata(obj.myTopFigure, 'newCenterFreqL', newCenterFreqL);
                setappdata(obj.myTopFigure, 'newCenterFreqH', newCenterFreqH);
                setappdata(obj.myTopFigure, 'plottingHandles', tempH);
                
                guidata(obj.myTopFigure, myHandles);
               
            else %close everything done
                setappdata(obj.myTopFigure, 'readyForData', 0);
                %9.5 Close Frequency Synthesizer and Data file
                obj.mysPID1.clear();
                obj.mysPID2.clear();
                obj.myFreqSynth.close();
                fclose('all'); % weird matlab thing, can't just close fid, won't work.
                %10. If ~Run, make obvious and reset 'run'
                disp('Acquisistion Stopped');
                set(myHandles.curFreq, 'String', 'STOPPED');
                setappdata(obj.myTopFigure, 'run', 1);
                drawnow;
                try
                    rmappdata(obj.myTopFigure, 'normData');
                    rmappdata(obj.myTopFigure, 'scanData');
                    rmappdata(obj.myTopFigure, 'summedData');
                    rmappdata(obj.myTopFigure, 'PID1Data');
                    rmappdata(obj.myTopFigure, 'PID2Data');
                    rmappdata(obj.myTopFigure, 'DriftData');
                    rmappdata(obj.myTopFigure, 'runNum');
                    rmappdata(obj.myTopFigure, 'taxis');
                    rmappdata(obj.myTopFigure, 'fid');
                    rmappdata(obj.myTopFigure, 'seqPlace');
                    rmappdata(obj.myTopFigure, 'prevExcL');
                    rmappdata(obj.myTopFigure, 'prevExcH');
                    rmappdata(obj.myTopFigure, 'newCenterFreqL');
                    rmappdata(obj.myTopFigure, 'newCenterFreqH');
                    rmappdata(obj.myTopFigure, 'prevFrequency');
                    rmappdata(obj.myTopFigure, 'plottingHandles');
                    rmappdata(obj.myTopFigure, 'prevCycleNum');
                catch exception
                    exception.message
                end
                drawnow;
                
                guidata(obj.myTopFigure, myHandles);
                
                clear variables
                clear mex
            end
        end
        function start4PeakLock_initialize(obj)
            setappdata(obj.myTopFigure, 'readyForData', 0);
            myHandles = guidata(obj.myTopFigure);
            prevExcPID1 = 0; %For use in calculating the present Error for PID1
            prevExcPID2 = 0; %For use in calculating the present Error for PID2
            prevExcPID3 = 0; %For use in calculating the present Error for PID3
            prevExcPID4 = 0; %For use in calculating the present Error for PID4
            linewidth = str2double(get(myHandles.linewidth, 'String'));
            linewidth2 = str2double(get(myHandles.linewidth2, 'String'));
            newCenterFreqL1 = str2double(get(myHandles.lowStartFrequency1, 'String'))+ linewidth/2;
            newCenterFreqL2 = str2double(get(myHandles.lowStartFrequency2, 'String'))+ linewidth2/2;
            newCenterFreqH1 = str2double(get(myHandles.highStartFrequency1, 'String'))- linewidth/2;
            newCenterFreqH2 = str2double(get(myHandles.highStartFrequency2, 'String'))- linewidth2/2;
            runNum = 1;
            if get(myHandles.cycleNumOnCN, 'Value')
                runNum = 0;
                obj.myCycleNuControl.initialize();
            end
            seqPlace = 0; %0 = left side of PID1 - low Freq
                          %1 = right side of PID1  - low Freq
                          %2 = left side of PID2  - low Freq
                          %3 = right side of PID2  - low Freq
                          %4 = left side of PID3  - high Freq
                          %5 = right side of PID3 - high Freq
                          %6 = left side of PID4 - high Freq
                          %7 = right side of PID4 - high Freq
            
            %AVOID MEMORY MOVEMENT SLOWDOWNS
            tempScanData = zeros(6,FreqLocker.bufferSize);
            tempSummedData = zeros(1,FreqLocker.bufferSize);
            tempNormData = zeros(1,FreqLocker.bufferSize);
            tempPID1Data = zeros(1,FreqLocker.bufferSize);
            tempPID2Data = zeros(1,FreqLocker.bufferSize);
            tempPID3Data = zeros(1,FreqLocker.bufferSize);
            tempPID4Data = zeros(1,FreqLocker.bufferSize);
            tempDriftData = NaN(2,FreqLocker.bufferSize);
            obj.myDriftFitHandle = [];
            obj.myDriftPlotHandle = [];
            cla(myHandles.DriftAXES);
            
            
            
            %Initialize Liquid Crystal Waveplate
            if get(myHandles.bounceLCwaveplate, 'Value') && strcmp(get(myHandles.openSerialLC, 'Enable'), 'off')
                fprintf(obj.myLCuControl.mySerial, [':2;c' int2str(mod(seqPlace+1,8)) ';d0;t80000']);
            end
            

            %2.5 Initialize Frequency Synthesizer
            obj.myFreqSynth.initialize();
            %Start Frequency Loop / Check 'Run'
            set(myHandles.curFreq, 'BackgroundColor', 'green');
            
            if getappdata(obj.myTopFigure, 'run')
                        [path, fileName] = obj.createFileName();
                        try
                            mkdir(path);
                            fid = fopen([path filesep fileName], 'a');
                            fwrite(fid, datestr(now, 'mm/dd/yyyy\tHH:MM AM'))
                            fprintf(fid, '\r\n');
                            colNames = {'Frequency', 'Norm', 'GndState', ...
                                'ExcState', 'Background', 'TStamp', 'BLUEGndState', ...
                                'BLUEBackground', 'BLUEExcState', ...
                                'err1', 'cor1', 'servoVal1', ...
                                'err2', 'cor2', 'servoVal2', ...
                                'err3', 'cor3', 'servoVal3', ...
                                'err4', 'cor4', 'servoVal4', ...
                                'freqSr1', 'delta1', 'freqSr2', 'delta2', 'cycleNum', 'badData'};
                            if get(myHandles.stepVoltages, 'Value')
                                colNames = [colNames obj.myAnalogStepper.myNames];
                            end
                            n = length(colNames);
                            for i=1:n
                                fprintf(fid, '%s\t', colNames{i});
                            end
                                fprintf(fid, '\r\n');
                        catch
                            disp('Could not open file to write to.');
                        end
            end
            %Set to first frequency point
            curFrequency = newCenterFreqL1 - linewidth/2;
            ret = obj.myFreqSynth.setFrequency(num2str(curFrequency));
                if ~ret
                    setappdata(obj.myTopFigure, 'run', 0);
                end
            
            setappdata(obj.myTopFigure, 'normData', tempNormData);
            setappdata(obj.myTopFigure, 'scanData', tempScanData);
            setappdata(obj.myTopFigure, 'summedData', tempSummedData);
            setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
            setappdata(obj.myTopFigure, 'PID2Data', tempPID2Data);
            setappdata(obj.myTopFigure, 'PID3Data', tempPID3Data);
            setappdata(obj.myTopFigure, 'PID4Data', tempPID4Data);
            setappdata(obj.myTopFigure, 'DriftData', tempDriftData);
            setappdata(obj.myTopFigure, 'runNum', runNum);
            setappdata(obj.myTopFigure, 'fid', fid);
            setappdata(obj.myTopFigure, 'seqPlace', seqPlace);
            setappdata(obj.myTopFigure, 'prevExcPID1', prevExcPID1);
            setappdata(obj.myTopFigure, 'prevExcPID2', prevExcPID2);
            setappdata(obj.myTopFigure, 'prevExcPID3', prevExcPID3);
            setappdata(obj.myTopFigure, 'prevExcPID4', prevExcPID4);
            setappdata(obj.myTopFigure, 'newCenterFreqL1', newCenterFreqL1);
            setappdata(obj.myTopFigure, 'newCenterFreqL2', newCenterFreqL2);
            setappdata(obj.myTopFigure, 'newCenterFreqH1', newCenterFreqH1);
            setappdata(obj.myTopFigure, 'newCenterFreqH2', newCenterFreqH2);
            setappdata(obj.myTopFigure, 'prevFrequency', curFrequency);
            setappdata(obj.myTopFigure, 'nextStep', @obj.start4PeakLock_takeNextPoint);
            pause(0.5) %I think I need this to make sure we get our first point good
            guidata(obj.myTopFigure, myHandles);
            setappdata(obj.myTopFigure, 'readyForData', 1);
        end
        function start4PeakLock_takeNextPoint(obj, data)
            myHandles = guidata(obj.myTopFigure);
            tempNormData = getappdata(obj.myTopFigure, 'normData');
            tempScanData = getappdata(obj.myTopFigure, 'scanData');
            tempSummedData = getappdata(obj.myTopFigure, 'summedData');
            tempPID1Data = getappdata(obj.myTopFigure, 'PID1Data');
            tempPID2Data = getappdata(obj.myTopFigure, 'PID2Data');
            tempPID3Data = getappdata(obj.myTopFigure, 'PID3Data');
            tempPID4Data = getappdata(obj.myTopFigure, 'PID4Data');
            tempDriftData = getappdata(obj.myTopFigure, 'DriftData');
            runNum = getappdata(obj.myTopFigure, 'runNum');
            fid = getappdata(obj.myTopFigure, 'fid');
            seqPlace = getappdata(obj.myTopFigure, 'seqPlace');
            prevExcPID1 = getappdata(obj.myTopFigure, 'prevExcPID1');
            prevExcPID2 = getappdata(obj.myTopFigure, 'prevExcPID2');
            prevExcPID3 = getappdata(obj.myTopFigure, 'prevExcPID3');
            prevExcPID4 = getappdata(obj.myTopFigure, 'prevExcPID4');
            linewidth = str2double(get(myHandles.linewidth, 'String'));
            linewidth2 = str2double(get(myHandles.linewidth2, 'String'));
            newCenterFreqL1 = getappdata(obj.myTopFigure, 'newCenterFreqL1');
            newCenterFreqL2 = getappdata(obj.myTopFigure, 'newCenterFreqL2');
            newCenterFreqH1 = getappdata(obj.myTopFigure, 'newCenterFreqH1');
            newCenterFreqH2 = getappdata(obj.myTopFigure, 'newCenterFreqH2');
            prevFrequency = getappdata(obj.myTopFigure, 'prevFrequency');
            badData = 0;
            
            if runNum > 1
                tempH = getappdata(obj.myTopFigure, 'plottingHandles');
                taxis = getappdata(obj.myTopFigure, 'taxis');
            end
            
            if get(myHandles.cycleNumOnCN, 'Value')
                cycleNum = str2double(obj.myCycleNuControl.getCycleNum());
                if runNum ~= 0
                    prevCycleNum = getappdata(obj.myTopFigure, 'prevCycleNum');
                end
                seqPlace = mod(cycleNum-2,8); % 1 for previous measurement and 1 for mike bishof's convention
                fprintf(1,['Cycle Number for data just taken : ' num2str(cycleNum-1) '\rTherfore we just took seqPlace: ' num2str(mod(cycleNum-2,8)) '\n']);
                if runNum ~= 0 && prevCycleNum ~= (cycleNum-1)
                    fprintf(1, 'Cycle Slipped\n');
                    badData = 1;
                end
                setappdata(obj.myTopFigure, 'prevCycleNum', cycleNum);
            end
            pointDone = 0;
            while(getappdata(obj.myTopFigure, 'run') && ~pointDone)
                plotstart = 1; %Needs to be out here so plots can be cleared
                %IMMEDIATELY READJUST LC WAVEPLATE and set frequency for
                %next point.
                   switch mod(seqPlace+1,8) 
                        case 0 % left side of line 1
                            curFrequency = newCenterFreqL1 - linewidth/2;
                        case 1 % right side of line 1
                            curFrequency = newCenterFreqL1 + linewidth/2;
                        case 2 % left side of line 2
                            curFrequency = newCenterFreqL2 - linewidth2/2;
                        case 3 % right side of line 2
                            curFrequency = newCenterFreqL2 + linewidth2/2;
                        case 4 % left side of line 3
                            curFrequency = newCenterFreqH1 - linewidth/2;
                        case 5 % right side of line 3
                            curFrequency = newCenterFreqH1 + linewidth/2;
                        case 6 % left side of line 4
                            curFrequency = newCenterFreqH2 - linewidth2/2;
                        case 7 % right side of line 4
                            curFrequency = newCenterFreqH2 + linewidth2/2;
                    end
                if get(myHandles.bounceLCwaveplate, 'Value') && strcmp(get(myHandles.openSerialLC, 'Enable'), 'off') %NEEDS TO BE FIXED
                    disp([':2;c' int2str(mod(seqPlace+1,8)) ';d0;t80000']); 
                    fprintf(obj.myLCuControl.mySerial, [':2;c' int2str(mod(seqPlace+1,8)) ';d0;t80000']);
                    %fscanf(obj.myLCuControl.mySerial)
                end
                

                ret = obj.myFreqSynth.setFrequency(num2str(curFrequency));
                if ~ret
                    setappdata(obj.myTopFigure, 'run', 0);
                    break;
                end
                set(myHandles.curFreq, 'String', num2str(curFrequency));
                set(myHandles.curFreqL, 'String', num2str(curFrequency));
                
                if runNum == 0
                    runNum = runNum + 1;
                    setappdata(obj.myTopFigure, 'runNum', runNum);
                    return;
                end
                %4. Update Progress Bar
                drawnow;
                %5. Call Gage Card to gather data
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
                    %7. Clear the Raw Plots, Plot the Raw Plots
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
                    tempScanData(1:2, :) = [tempScanData(1:2, 2:end) tSCdat12];
                    tempScanData(3,:) = [tempScanData(3, 2:end) tSCdat3];
                    tempScanData(4:6,:) = [tempScanData(4:6, 2:end) tSCdat456];
                    %NORMALIZED counts are (E - bg)/(E + G - 2bg)
                    tNorm = (tSCdat12(2)) / (tSCdat12(2) + tSCdat12(1));
                    tempNormData = [tempNormData(2:end) tNorm];
                    %SUMMED counts
                    tSum = tSCdat12(2) + tSCdat12(1);
                    tempSummedData = [tempSummedData(2:end) tSum];
                    
                    
                    %Do some PID magic!
                    %Calculate Error for PID1
                    switch seqPlace
                        case {0, 1}
                            calcErr1 = tNorm - prevExcPID1;
                            tempPID1Data = getappdata(obj.myTopFigure, 'PID1Data');
                        case {2, 3}
                            calcErr2 = tNorm - prevExcPID2;
                            tempPID2Data = getappdata(obj.myTopFigure, 'PID2Data');
                        case {4, 5}
                            calcErr3 = tNorm - prevExcPID3;
                            tempPID3Data = getappdata(obj.myTopFigure, 'PID3Data');
                        case {6, 7}
                            calcErr4 = tNorm - prevExcPID4;
                            tempPID4Data = getappdata(obj.myTopFigure, 'PID4Data');
                    end
                    
                    if runNum >= 2 && ~badData
                        switch seqPlace
                            case {0,1}
                                prevExcPID1 = tNorm;
                            case {2, 3}
                                prevExcPID2 = tNorm;
                            case {4, 5}
                                prevExcPID3 = tNorm;
                            case {6, 7}
                                prevExcPID4 = tNorm;
                        end
%                         %Needed if you want to servo on every shot.
%                         switch seqPlace
%                                 case 1
%                                     obj.myPID1.myPolarity = 1;
%                                 case 3
%                                     obj.myPID2.myPolarity = 1;
%                                 case 5
%                                     obj.myPID3.myPolarity = 1;
%                                 case 7
%                                     obj.myPID3.myPolarity = 1;    
%                         end
                        obj.updatePIDvalues();
                        obj.checkPIDenables();
                        deltaT1 = str2double(get(obj.myPID1gui.myDeltaT, 'String'));
                        deltaT2 = str2double(get(obj.myPID2gui.myDeltaT, 'String'));
                        deltaT3 = str2double(get(obj.myPID3gui.myDeltaT, 'String'));
                        deltaT4 = str2double(get(obj.myPID4gui.myDeltaT, 'String'));
                            switch seqPlace
                                case 0
                                    calcCorr1 = 0;
                                case 1
                                        if deltaT1 == 0
                                            calcCorr1 = obj.mysPID1.calculate(calcErr1, time);
                                        else
                                            calcCorr1 = obj.mysPID1.calculate(calcErr1, -deltaT1);
                                        end
                                        newCenterFreqL1 = newCenterFreqL1 + calcCorr1;
                                case 2
                                    calcCorr2 = 0;
                                case 3
                                        if deltaT2 == 0
                                            calcCorr2 = obj.mysPID2.calculate(calcErr2, time);
                                        else
                                            calcCorr2 = obj.mysPID2.calculate(calcErr2, -deltaT2);
                                        end
                                        newCenterFreqL2 = newCenterFreqL2 + calcCorr2;
                                case 4
                                    calcCorr3 = 0;
                                case 5
                                        if deltaT3 == 0
                                            calcCorr3 = obj.mysPID3.calculate(calcErr3, time);
                                        else
                                            calcCorr3 = obj.mysPID3.calculate(calcErr3, -deltaT3);
                                        end
                                        newCenterFreqH1 = newCenterFreqH1 + calcCorr3;
                                case 6
                                    calcCorr4 = 0;
                                case 7
                                        if deltaT4 == 0
                                            calcCorr4 = obj.mysPID4.calculate(calcErr4, time);
                                        else
                                            calcCorr4 = obj.mysPID4.calculate(calcErr4, -deltaT3);
                                        end
                                        newCenterFreqH2 = newCenterFreqH2 + calcCorr4;
                            end
                    end
                    
                        switch seqPlace
                            case 1
                                tempPID1Data = [tempPID1Data(2:end) calcErr1];
                                tempDriftData(1, :) = [tempDriftData(1, 2:end) (newCenterFreqL1 + newCenterFreqH1)/2];
                                tempDriftData(2, :) = [tempDriftData(2, 2:end) ((time- obj.refTime)/1000)];
                            case 3
                                tempPID2Data = [tempPID2Data(2:end) calcErr2];
                            case 5
                                tempPID3Data = [tempPID3Data(2:end) calcErr3];
                                tempDriftData(1, :) = [tempDriftData(1, 2:end) (newCenterFreqL1 + newCenterFreqH1)/2];
                                tempDriftData(2, :) = [tempDriftData(2, 2:end) ((time- obj.refTime)/1000)];
                            case 7
                                tempPID4Data = [tempPID4Data(2:end) calcErr4];
                        end
                    
                    %Do some Plotting
                    firstplot = 1;
                    if get(myHandles.ignoreFirstToggle, 'Value') && plotstart < 3
                        plotstart = 2;
                        firstplot = 2;
                    end
                    if runNum == 1
                        tempH(1) = plot(myHandles.sNormAxes, tempNormData(end-FreqLocker.plotSize:end), 'ok', 'LineWidth', 3);
                        tempH(2) = plot(myHandles.sEAxes, tempScanData(2,end-FreqLocker.plotSize:end), 'or', 'LineWidth', 2);
                        tempH(3) = plot(myHandles.sGAxes, tempScanData(1,end-FreqLocker.plotSize:end), 'ob', 'LineWidth', 2);
                        tempH(4) = plot(myHandles.sBGAxes, tempScanData(3,end-FreqLocker.plotSize:end), 'ob', 'LineWidth', 1);
                        tempH(5) = plot(myHandles.sSummedAxes, tempSummedData(end-FreqLocker.plotSize:end), 'og', 'LineWidth', 2);
                        tempH(6) = plot(myHandles.errPlot, tempPID1Data(end-FreqLocker.plotSize:end), 'ok', 'LineWidth', 2);
                    elseif runNum > 1
                        set(tempH(1), 'YData', tempNormData(end-FreqLocker.plotSize:end));
                        set(tempH(2), 'YData', tempScanData(2,end-FreqLocker.plotSize:end));
                        set(tempH(3), 'YData', tempScanData(1,end-FreqLocker.plotSize:end));
                        set(tempH(4), 'YData', tempScanData(3,end-FreqLocker.plotSize:end));
                        set(tempH(5), 'YData', tempSummedData(end-FreqLocker.plotSize:end));
                        set(tempH(6), 'YData', tempPID1Data(end-FreqLocker.plotSize:end));
                    end
                    switch seqPlace
                        case {0,1}
                            obj.myPID1gui.updateMyPlots(calcErr1, runNum, FreqLocker.plotSize);
                        case {2,3}
                            obj.myPID2gui.updateMyPlots(calcErr2, runNum, FreqLocker.plotSize);
                        case {4,5}
                            obj.myPID3gui.updateMyPlots(calcErr3, runNum, FreqLocker.plotSize);
                        case {6,7}
                            obj.myPID4gui.updateMyPlots(calcErr4, runNum, FreqLocker.plotSize);
                    end
                    switch mod(seqPlace+1,8)
                        case 0
                            set(myHandles.lockStatus, 'String', 'Low1_L');
                        case 1
                            set(myHandles.lockStatus, 'String', 'Low1_R');
                        case 2
                            set(myHandles.lockStatus, 'String', 'Low2_L');
                        case 3
                            set(myHandles.lockStatus, 'String', 'Low2_R');
                        case 4
                            set(myHandles.lockStatus, 'String', 'High1_L');
                        case 5
                            set(myHandles.lockStatus, 'String', 'High1_R');
                        case 6
                            set(myHandles.lockStatus, 'String', 'High2_L');
                        case 7
                            set(myHandles.lockStatus, 'String', 'High2_R');
                    end
                    %9. Check Save and Write Data to file.
% 'Frequency', 'Norm', 'GndState', 'ExcState', 'Background', 'TStamp', 'BLUEGndState', 'BLUEBackground', 'BLUEExcState'
                    temp = [prevFrequency tNorm tSCdat12(1) tSCdat12(2) tSCdat3 time tSCdat456(1) tSCdat456(3) tSCdat456(2)];
                    
                        if runNum >= 2 && seqPlace == 1 && ~badData
                            tempPID1 = [calcErr1 calcCorr1 newCenterFreqL1];%err correctionApplied servoVal
                        else
                            tempPID1 = [0 0 0];%err correctionApplied servoVal
                        end
                        if runNum >= 2 && seqPlace == 3 && ~badData
                            tempPID2 = [calcErr2 calcCorr2 newCenterFreqL2];%err correctionApplied servoVal
                        else
                            tempPID2 = [0 0 0];
                        end

                        if runNum >= 2 && seqPlace == 5 && ~badData
                            tempPID3 = [calcErr3 calcCorr3 newCenterFreqH1];%err correctionApplied servoVal
                        else
                            tempPID3 = [0 0 0];
                        end

                        if runNum >= 2 && seqPlace == 7 && ~badData
                            tempPID4 = [calcErr4 calcCorr4 newCenterFreqH2];%err correctionApplied servoVal
                        else
                            tempPID4 = [0 0 0];
                        end
                    temp = [temp tempPID1 tempPID2 tempPID3 tempPID4];
                    if get(myHandles.calcSrFreq, 'Value') && runNum >= 8
                        temp = [temp (newCenterFreqL1 + newCenterFreqH1)/2 (newCenterFreqL1 - newCenterFreqH1)];
                        temp = [temp (newCenterFreqL2 + newCenterFreqH2)/2 (newCenterFreqL2 - newCenterFreqH2)];
                    else
                        temp = [temp 0 0 0 0];
                    end
                    if get(myHandles.cycleNumOnCN, 'Value')
                        temp = [temp prevCycleNum];
                        setappdata(obj.myTopFigure, 'prevCycleNum', cycleNum);
                    else
                        temp = [temp 0];
                    end
                    temp = [temp badData];
                    fprintf(fid, '%8.6f\t', temp);
                    fprintf(fid, '\r\n');
                    
                    
                    if (runNum > 5 && tNorm >= 0.1 && tNorm <= 1.0)
                        set(myHandles.lowStartFrequency1, 'String', num2str(newCenterFreqL1 - linewidth/2));
                        set(myHandles.highStartFrequency1, 'String', num2str(newCenterFreqH1 + linewidth/2));
                        set(myHandles.lowStartFrequency2, 'String', num2str(newCenterFreqL2 - linewidth2/2));
                        set(myHandles.highStartFrequency2, 'String', num2str(newCenterFreqH2 + linewidth2/2));
                    end
                    pointDone = 1;
                    obj.updateDriftPlots(runNum);
            end
            if (getappdata(obj.myTopFigure, 'run')) % Prepare for a new data point
                if runNum == 1
                    setappdata(obj.myTopFigure, 'taxis', taxis);
                end
                runNum = runNum + 1;
                seqPlace = mod(seqPlace + 1,4);
                setappdata(obj.myTopFigure, 'prevFrequency', curFrequency);
                setappdata(obj.myTopFigure, 'normData', tempNormData);
                setappdata(obj.myTopFigure, 'scanData', tempScanData);
                setappdata(obj.myTopFigure, 'summedData', tempSummedData);
                setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
                setappdata(obj.myTopFigure, 'PID2Data', tempPID2Data);
                setappdata(obj.myTopFigure, 'PID3Data', tempPID3Data);
                setappdata(obj.myTopFigure, 'PID4Data', tempPID4Data);
                setappdata(obj.myTopFigure, 'DriftData', tempDriftData);
                setappdata(obj.myTopFigure, 'runNum', runNum);
                setappdata(obj.myTopFigure, 'seqPlace', seqPlace);
                setappdata(obj.myTopFigure, 'prevExcPID1', prevExcPID1);
                setappdata(obj.myTopFigure, 'prevExcPID2', prevExcPID2);
                setappdata(obj.myTopFigure, 'prevExcPID3', prevExcPID3);
                setappdata(obj.myTopFigure, 'prevExcPID4', prevExcPID4);
                setappdata(obj.myTopFigure, 'newCenterFreqL1', newCenterFreqL1);
                setappdata(obj.myTopFigure, 'newCenterFreqL2', newCenterFreqL2);
                setappdata(obj.myTopFigure, 'newCenterFreqH1', newCenterFreqH1);
                setappdata(obj.myTopFigure, 'newCenterFreqH2', newCenterFreqH2);
                setappdata(obj.myTopFigure, 'plottingHandles', tempH);
                
                guidata(obj.myTopFigure, myHandles);
               
            else %close everything done
                setappdata(obj.myTopFigure, 'readyForData', 0);
                %9.5 Close Frequency Synthesizer and Data file
                obj.mysPID1.clear();
                obj.mysPID2.clear();
                obj.mysPID3.clear();
                obj.mysPID4.clear();
                obj.myFreqSynth.close();
                fclose('all'); % weird matlab thing, can't just close fid, won't work.
                %10. If ~Run, make obvious and reset 'run'
                disp('Acquisistion Stopped');
                set(myHandles.curFreq, 'String', 'STOPPED');
                setappdata(obj.myTopFigure, 'run', 1);
                drawnow;
                try
                    rmappdata(obj.myTopFigure, 'normData');
                    rmappdata(obj.myTopFigure, 'scanData');
                    rmappdata(obj.myTopFigure, 'summedData');
                    rmappdata(obj.myTopFigure, 'PID1Data');
                    rmappdata(obj.myTopFigure, 'PID2Data');
                    rmappdata(obj.myTopFigure, 'PID3Data');
                    rmappdata(obj.myTopFigure, 'PID4Data');
                    rmappdata(obj.myTopFigure, 'DriftData');
                    rmappdata(obj.myTopFigure, 'runNum');
                    rmappdata(obj.myTopFigure, 'taxis');
                    rmappdata(obj.myTopFigure, 'fid');
                    rmappdata(obj.myTopFigure, 'seqPlace');
                    rmappdata(obj.myTopFigure, 'prevExcPID1');
                    rmappdata(obj.myTopFigure, 'prevExcPID2');
                    rmappdata(obj.myTopFigure, 'prevExcPID3');
                    rmappdata(obj.myTopFigure, 'prevExcPID4');
                    rmappdata(obj.myTopFigure, 'newCenterFreqL1');
                    rmappdata(obj.myTopFigure, 'newCenterFreqL2');
                    rmappdata(obj.myTopFigure, 'newCenterFreqH1');
                    rmappdata(obj.myTopFigure, 'newCenterFreqH2');
                    rmappdata(obj.myTopFigure, 'prevFrequency');
                    rmappdata(obj.myTopFigure, 'plottingHandles');
                    rmappdata(obj.myTopFigure, 'prevCycleNum');
                catch exception
                    exception.message
                end
                drawnow;
                
                guidata(obj.myTopFigure, myHandles);
                
                clear variables
                clear mex
            end
        end
        function start4PeakLockRezero_initialize(obj)
            setappdata(obj.myTopFigure, 'readyForData', 0);
            myHandles = guidata(obj.myTopFigure);
            rezeroSequenceNumber = str2num(['uint16(' get(myHandles.numRezero, 'String') ')']);
%             rezeroSequenceNumber = 41;
            voltageStepSize = 1.25;
            meanFilterNum = 3;
            meanVx = NaN;
            meanVy = NaN;
            meanVz = NaN;
            zeroingExcAndVoltages = [0, 0; 0, 0; 0, 0];
            prevExcPID1 = 0; %For use in calculating the present Error for PID1
            prevExcPID2 = 0; %For use in calculating the present Error for PID2
            prevExcPID3 = 0; %For use in calculating the present Error for PID3
            prevExcPID4 = 0; %For use in calculating the present Error for PID4
            linewidth = str2double(get(myHandles.linewidth, 'String'));
            linewidth2 = str2double(get(myHandles.linewidth2, 'String'));
            newCenterFreqL1 = str2double(get(myHandles.lowStartFrequency1, 'String'))+ linewidth/2;
            newCenterFreqL2 = str2double(get(myHandles.lowStartFrequency2, 'String'))+ linewidth2/2;
            newCenterFreqH1 = str2double(get(myHandles.highStartFrequency1, 'String'))- linewidth/2;
            newCenterFreqH2 = str2double(get(myHandles.highStartFrequency2, 'String'))- linewidth2/2;
            runNum = 1;
            if get(myHandles.cycleNumOnCN, 'Value')
                runNum = 0;
                obj.myCycleNuControl.initialize();
            end
            seqPlace = 0; %0 = left side of PID1 - low Freq
                          %1 = right side of PID1  - low Freq
                          %2 = left side of PID2  - low Freq
                          %3 = right side of PID2  - low Freq
                          %4 = left side of PID3  - high Freq
                          %5 = right side of PID3 - high Freq
                          %6 = left side of PID4 - high Freq
                          %7 = right side of PID4 - high Freq
            rezeroSeqPlace = 9; %0 = Unpol,  Ix =  Ix0 - Delta
                                %1 = Unpol,  Ix =  Ix0
                                %2 = Unpol,  Ix =  Ix0 + Delta
                                %3 = Unpol,  Iy =  Iy0 - Delta
                                %4 = Unpol,  Iy =  Iy0
                                %5 = Unpol,  Iy =  Iy0 + Delta
                                %6 = Unpol,  Iz =  Iz0 - Delta
                                %7 = Unpol,  Iz =  Iz0
                                %8 = Unpol,  Iy =  Iy0 + Delta
                                %9 and on.....do whatever seqPlace says 
           
            %AVOID MEMORY MOVEMENT SLOWDOWNS
            tempScanData = zeros(6,FreqLocker.bufferSize);
            tempSummedData = zeros(1,FreqLocker.bufferSize);
            tempNormData = zeros(1,FreqLocker.bufferSize);
            tempPID1Data = zeros(1,FreqLocker.bufferSize);
            tempPID2Data = zeros(1,FreqLocker.bufferSize);
            tempPID3Data = zeros(1,FreqLocker.bufferSize);
            tempPID4Data = zeros(1,FreqLocker.bufferSize);
            tempDriftData = NaN(2,FreqLocker.bufferSize);
            obj.myDriftFitHandle = [];
            obj.myDriftPlotHandle = [];
            cla(myHandles.DriftAXES);
            
            
            
            %Initialize Liquid Crystal Waveplate
            if get(myHandles.bounceLCwaveplate, 'Value') && strcmp(get(myHandles.openSerialLC, 'Enable'), 'off')
                fprintf(obj.myLCuControl.mySerial, [':2;c' int2str(mod(seqPlace+1,8)) ';d0;t80000']);
            end
            

            %2.5 Initialize Frequency Synthesizer
            obj.myFreqSynth.initialize();
            %Start Frequency Loop / Check 'Run'
            set(myHandles.curFreq, 'BackgroundColor', 'green');
            
            if getappdata(obj.myTopFigure, 'run')
                        [path, fileName] = obj.createFileName();
                        try
                            mkdir(path);
                            fid = fopen([path filesep fileName], 'a');
                            fwrite(fid, datestr(now, 'mm/dd/yyyy\tHH:MM AM'))
                            fprintf(fid, '\r\n');
                            colNames = {'Frequency', 'Norm', 'GndState', ...
                                'ExcState', 'Background', 'TStamp', 'BLUEGndState', ...
                                'BLUEBackground', 'BLUEExcState', ...
                                'err1', 'cor1', 'servoVal1', ...
                                'err2', 'cor2', 'servoVal2', ...
                                'err3', 'cor3', 'servoVal3', ...
                                'err4', 'cor4', 'servoVal4', ...
                                'Vx', 'Vy', 'Vz', ...
                                'freqSr1', 'delta1', 'freqSr2', 'delta2', 'cycleNum', 'badData'};
%                             if get(myHandles.stepVoltages, 'Value')
%                                 colNames = [colNames obj.myAnalogStepper.myNames];
%                             end
                            n = length(colNames);
                            for i=1:n
                                fprintf(fid, '%s\t', colNames{i});
                            end
                                fprintf(fid, '\r\n');
                        catch
                            disp('Could not open file to write to.');
                        end
            end
            %Set to first frequency point
            curFrequency = newCenterFreqL1 - linewidth/2;
            ret = obj.myFreqSynth.setFrequency(num2str(curFrequency));
                if ~ret
                    setappdata(obj.myTopFigure, 'run', 0);
                end
            
            setappdata(obj.myTopFigure, 'normData', tempNormData);
            setappdata(obj.myTopFigure, 'scanData', tempScanData);
            setappdata(obj.myTopFigure, 'summedData', tempSummedData);
            setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
            setappdata(obj.myTopFigure, 'PID2Data', tempPID2Data);
            setappdata(obj.myTopFigure, 'PID3Data', tempPID3Data);
            setappdata(obj.myTopFigure, 'PID4Data', tempPID4Data);
            setappdata(obj.myTopFigure, 'DriftData', tempDriftData);
            setappdata(obj.myTopFigure, 'runNum', runNum);
            setappdata(obj.myTopFigure, 'fid', fid);
            setappdata(obj.myTopFigure, 'seqPlace', seqPlace);
            setappdata(obj.myTopFigure, 'prevExcPID1', prevExcPID1);
            setappdata(obj.myTopFigure, 'prevExcPID2', prevExcPID2);
            setappdata(obj.myTopFigure, 'prevExcPID3', prevExcPID3);
            setappdata(obj.myTopFigure, 'prevExcPID4', prevExcPID4);
            setappdata(obj.myTopFigure, 'newCenterFreqL1', newCenterFreqL1);
            setappdata(obj.myTopFigure, 'newCenterFreqL2', newCenterFreqL2);
            setappdata(obj.myTopFigure, 'newCenterFreqH1', newCenterFreqH1);
            setappdata(obj.myTopFigure, 'newCenterFreqH2', newCenterFreqH2);
            setappdata(obj.myTopFigure, 'prevFrequency', curFrequency);
            setappdata(obj.myTopFigure, 'nextStep', @obj.start4PeakLockRezero_takeNextPoint);
            
            %%% Stuff for rezeroing the field
            setappdata(obj.myTopFigure, 'rezeroSequenceNumber', rezeroSequenceNumber);
            setappdata(obj.myTopFigure, 'voltageStepSize', voltageStepSize);
            setappdata(obj.myTopFigure, 'zeroingExcAndVoltages', zeroingExcAndVoltages);
            setappdata(obj.myTopFigure, 'rezeroSeqPlace', rezeroSeqPlace);
            setappdata(obj.myTopFigure, 'meanFilterNum', meanFilterNum);
            setappdata(obj.myTopFigure, 'meanVx', meanVx);
            setappdata(obj.myTopFigure, 'meanVy', meanVy);
            setappdata(obj.myTopFigure, 'meanVz', meanVz);
            
            pause(0.5) %I think I need this to make sure we get our first point good
            guidata(obj.myTopFigure, myHandles);
            setappdata(obj.myTopFigure, 'readyForData', 1);
        end
        function start4PeakLockRezero_takeNextPoint(obj, data)
            myHandles = guidata(obj.myTopFigure);
            tempNormData = getappdata(obj.myTopFigure, 'normData');
            tempScanData = getappdata(obj.myTopFigure, 'scanData');
            tempSummedData = getappdata(obj.myTopFigure, 'summedData');
            tempPID1Data = getappdata(obj.myTopFigure, 'PID1Data');
            tempPID2Data = getappdata(obj.myTopFigure, 'PID2Data');
            tempPID3Data = getappdata(obj.myTopFigure, 'PID3Data');
            tempPID4Data = getappdata(obj.myTopFigure, 'PID4Data');
            tempDriftData = getappdata(obj.myTopFigure, 'DriftData');
            runNum = getappdata(obj.myTopFigure, 'runNum');
            fid = getappdata(obj.myTopFigure, 'fid');
            seqPlace = getappdata(obj.myTopFigure, 'seqPlace');
            prevExcPID1 = getappdata(obj.myTopFigure, 'prevExcPID1');
            prevExcPID2 = getappdata(obj.myTopFigure, 'prevExcPID2');
            prevExcPID3 = getappdata(obj.myTopFigure, 'prevExcPID3');
            prevExcPID4 = getappdata(obj.myTopFigure, 'prevExcPID4');
            linewidth = str2double(get(myHandles.linewidth, 'String'));
            linewidth2 = str2double(get(myHandles.linewidth2, 'String'));
            newCenterFreqL1 = getappdata(obj.myTopFigure, 'newCenterFreqL1');
            newCenterFreqL2 = getappdata(obj.myTopFigure, 'newCenterFreqL2');
            newCenterFreqH1 = getappdata(obj.myTopFigure, 'newCenterFreqH1');
            newCenterFreqH2 = getappdata(obj.myTopFigure, 'newCenterFreqH2');
            prevFrequency = getappdata(obj.myTopFigure, 'prevFrequency');
            badData = 0;
            
            %%%Stuff for rezeroing the field
            rezeroSequenceNumber = getappdata(obj.myTopFigure, 'rezeroSequenceNumber');
            voltageStepSize = getappdata(obj.myTopFigure, 'voltageStepSize');
            zeroingExcAndVoltages = getappdata(obj.myTopFigure, 'zeroingExcAndVoltages');
            rezeroSeqPlace = getappdata(obj.myTopFigure, 'rezeroSeqPlace');
            previousVoltages = obj.readAnalogVoltages();
            meanFilterNum = getappdata(obj.myTopFigure, 'meanFilterNum');
            meanVx = getappdata(obj.myTopFigure, 'meanVx');
            meanVy = getappdata(obj.myTopFigure, 'meanVy');
            meanVz = getappdata(obj.myTopFigure, 'meanVz');
            
            if runNum > 1
                tempH = getappdata(obj.myTopFigure, 'plottingHandles');
                taxis = getappdata(obj.myTopFigure, 'taxis');
            end
            
            if get(myHandles.cycleNumOnCN, 'Value')
                cycleNum = str2double(obj.myCycleNuControl.getCycleNum());
                if runNum ~= 0
                    prevCycleNum = getappdata(obj.myTopFigure, 'prevCycleNum');
                end
                rezeroSeqPlace = mod(cycleNum-2,rezeroSequenceNumber);% 1 for previous measurement and 1 for mike bishof's convention
                NEXTrezeroSeqPlace = mod(rezeroSeqPlace + 1, rezeroSequenceNumber);
                seqPlace = mod(cycleNum-2,8); % 1 for previous measurement and 1 for mike bishof's convention
                fprintf(1,['Cycle Number for data just taken : ' num2str(cycleNum-1) '\rTherfore we just took seqPlace: ' num2str(mod(cycleNum-2,8)) '\n']);
                if runNum ~= 0 && prevCycleNum ~= (cycleNum-1)
                    fprintf(1, 'Cycle Slipped\n');
                    badData = 1;
                    pause(0.1);
                end
                setappdata(obj.myTopFigure, 'prevCycleNum', cycleNum);
            end
            pointDone = 0;
            while(getappdata(obj.myTopFigure, 'run') && ~pointDone)
                plotstart = 1; %Needs to be out here so plots can be cleared
                %IMMEDIATELY READJUST LC WAVEPLATE and set frequency for
                %next point. Also decide if next time is a rezeroing
                %unpolarized sequence, and set comp coil voltages
                %accordingly.
                NEXTrezeroSeqPlace
                if (NEXTrezeroSeqPlace > 8)
                   switch mod(seqPlace+1,8) 
                        case 0 % left side of line 1
                            curFrequency = newCenterFreqL1 - linewidth/2;
                        case 1 % right side of line 1
                            curFrequency = newCenterFreqL1 + linewidth/2;
                        case 2 % left side of line 2
                            curFrequency = newCenterFreqL2 - linewidth2/2;
                        case 3 % right side of line 2
                            curFrequency = newCenterFreqL2 + linewidth2/2;
                        case 4 % left side of line 3
                            curFrequency = newCenterFreqH1 - linewidth/2;
                        case 5 % right side of line 3
                            curFrequency = newCenterFreqH1 + linewidth/2;
                        case 6 % left side of line 4
                            curFrequency = newCenterFreqH2 - linewidth2/2;
                        case 7 % right side of line 4
                            curFrequency = newCenterFreqH2 + linewidth2/2;
                   end
                    if get(myHandles.bounceLCwaveplate, 'Value') && strcmp(get(myHandles.openSerialLC, 'Enable'), 'off') %NEEDS TO BE FIXED
                        disp([':2;c' int2str(mod(seqPlace+1,8)) ';d0;t80000']); 
                        fprintf(obj.myLCuControl.mySerial, [':2;c' int2str(mod(seqPlace+1,8)) ';d0;t80000']);
                        %fscanf(obj.myLCuControl.mySerial)
                    end
                    else if (runNum > NEXTrezeroSeqPlace) % i think this helps with bootstrapping.
%                             runNum
%                             rezeroSeqPlace+1
%                             previousVoltages(1) - voltageStepSize
                        switch mod(rezeroSeqPlace+1,rezeroSequenceNumber) 
                            case 0 % Unpol,  Ix =  Ix0 - Delta
                                curFrequency = (newCenterFreqL1 + newCenterFreqH1)/2;
                                obj.changeAnalogVoltage(0, previousVoltages(1) - voltageStepSize);
                            case 1 % Unpol,  Ix =  Ix0
                                curFrequency = (newCenterFreqL1 + newCenterFreqH1)/2;
                                obj.changeAnalogVoltage(0, previousVoltages(1) + voltageStepSize); %need to add because of previous step in sequence.
                            case 2 % Unpol,  Ix =  Ix0 + Delta
                                curFrequency = (newCenterFreqL1 + newCenterFreqH1)/2;
                                obj.changeAnalogVoltage(0, previousVoltages(1) + voltageStepSize);
                            case 3 % Unpol,  Iy =  Iy0 - Delta
                                curFrequency = (newCenterFreqL1 + newCenterFreqH1)/2;
                                obj.changeAnalogVoltage(1, previousVoltages(2) - voltageStepSize);
                            case 4 % Unpol,  Iy =  Iy0
                                curFrequency = (newCenterFreqL1 + newCenterFreqH1)/2;
                                obj.changeAnalogVoltage(1, previousVoltages(2) + voltageStepSize); %need to add because of previous step in sequence.
                            case 5 % Unpol,  Iy =  Iy0 + Delta
                                curFrequency = (newCenterFreqL1 + newCenterFreqH1)/2;
                                obj.changeAnalogVoltage(1, previousVoltages(2) + voltageStepSize);
                            case 6 % Unpol,  Iz =  Iz0 - Delta
                                curFrequency = (newCenterFreqL1 + newCenterFreqH1)/2;
                                obj.changeAnalogVoltage(2, previousVoltages(3) - voltageStepSize);
                            case 7 % Unpol,  Iz =  Iz0
                                curFrequency = (newCenterFreqL1 + newCenterFreqH1)/2;
                                obj.changeAnalogVoltage(2, previousVoltages(3) + voltageStepSize); %need to add because of previous step in sequence.
                            case 8 % Unpol,  Iz =  Iz0 + Delta
                                curFrequency = (newCenterFreqL1 + newCenterFreqH1)/2;
                                obj.changeAnalogVoltage(2, previousVoltages(3) + voltageStepSize);
                        end
                        if get(myHandles.bounceLCwaveplate, 'Value') && strcmp(get(myHandles.openSerialLC, 'Enable'), 'off') %NEEDS TO BE FIXED
                            disp(':4;c0;d0;t80000'); 
                            fprintf(obj.myLCuControl.mySerial, ':4;c0;d0;t80000');
                        end
                    else
                        curFrequency = newCenterFreqL1 - linewidth/2;
                    end    
                end
                

                ret = obj.myFreqSynth.setFrequency(num2str(curFrequency));
                if ~ret
                    setappdata(obj.myTopFigure, 'run', 0);
                    break;
                end
                set(myHandles.curFreq, 'String', num2str(curFrequency));
                set(myHandles.curFreqL, 'String', num2str(curFrequency));
                
                if runNum == 0
                    runNum = runNum + 1;
                    setappdata(obj.myTopFigure, 'runNum', runNum);
                    return;
                end
                %4. Update Progress Bar
                drawnow;
                %5. Call Gage Card to gather data
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
                    %7. Clear the Raw Plots, Plot the Raw Plots
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
                    tempScanData(1:2, :) = [tempScanData(1:2, 2:end) tSCdat12];
                    tempScanData(3,:) = [tempScanData(3, 2:end) tSCdat3];
                    tempScanData(4:6,:) = [tempScanData(4:6, 2:end) tSCdat456];
                    %NORMALIZED counts are (E - bg)/(E + G - 2bg)
                    tNorm = (tSCdat12(2)) / (tSCdat12(2) + tSCdat12(1));
                    tempNormData = [tempNormData(2:end) tNorm];
                    %SUMMED counts
                    tSum = tSCdat12(2) + tSCdat12(1);
                    tempSummedData = [tempSummedData(2:end) tSum];
                    
                    if (rezeroSeqPlace > 8)
                    %Do some PID magic!
                    %Calculate Error for PID1
                        switch seqPlace
                            case {0, 1}
                                calcErr1 = tNorm - prevExcPID1;
                                tempPID1Data = getappdata(obj.myTopFigure, 'PID1Data');
                            case {2, 3}
                                calcErr2 = tNorm - prevExcPID2;
                                tempPID2Data = getappdata(obj.myTopFigure, 'PID2Data');
                            case {4, 5}
                                calcErr3 = tNorm - prevExcPID3;
                                tempPID3Data = getappdata(obj.myTopFigure, 'PID3Data');
                            case {6, 7}
                                calcErr4 = tNorm - prevExcPID4;
                                tempPID4Data = getappdata(obj.myTopFigure, 'PID4Data');
                        end

                        if runNum >= 2 && ~badData
                            switch seqPlace
                                case {0,1}
                                    prevExcPID1 = tNorm;
                                case {2, 3}
                                    prevExcPID2 = tNorm;
                                case {4, 5}
                                    prevExcPID3 = tNorm;
                                case {6, 7}
                                    prevExcPID4 = tNorm;
                            end

                            obj.updatePIDvalues();
                            obj.checkPIDenables();
                            deltaT1 = str2double(get(obj.myPID1gui.myDeltaT, 'String'));
                            deltaT2 = str2double(get(obj.myPID2gui.myDeltaT, 'String'));
                            deltaT3 = str2double(get(obj.myPID3gui.myDeltaT, 'String'));
                            deltaT4 = str2double(get(obj.myPID4gui.myDeltaT, 'String'));
                                switch seqPlace
                                    case 0
                                        calcCorr1 = 0;
                                    case 1
                                            if deltaT1 == 0
                                                calcCorr1 = obj.mysPID1.calculate(calcErr1, time);
                                            else
                                                calcCorr1 = obj.mysPID1.calculate(calcErr1, -deltaT1);
                                            end
                                            newCenterFreqL1 = newCenterFreqL1 + calcCorr1;
                                    case 2
                                        calcCorr2 = 0;
                                    case 3
                                            if deltaT2 == 0
                                                calcCorr2 = obj.mysPID2.calculate(calcErr2, time);
                                            else
                                                calcCorr2 = obj.mysPID2.calculate(calcErr2, -deltaT2);
                                            end
                                            newCenterFreqL2 = newCenterFreqL2 + calcCorr2;
                                    case 4
                                        calcCorr3 = 0;
                                    case 5
                                            if deltaT3 == 0
                                                calcCorr3 = obj.mysPID3.calculate(calcErr3, time);
                                            else
                                                calcCorr3 = obj.mysPID3.calculate(calcErr3, -deltaT3);
                                            end
                                            newCenterFreqH1 = newCenterFreqH1 + calcCorr3;
                                    case 6
                                        calcCorr4 = 0;
                                    case 7
                                            if deltaT4 == 0
                                                calcCorr4 = obj.mysPID4.calculate(calcErr4, time);
                                            else
                                                calcCorr4 = obj.mysPID4.calculate(calcErr4, -deltaT3);
                                            end
                                            newCenterFreqH2 = newCenterFreqH2 + calcCorr4;
                                end
                        end

                            switch seqPlace
                                case 1
                                    tempPID1Data = [tempPID1Data(2:end) calcErr1];
                                    tempDriftData(1, :) = [tempDriftData(1, 2:end) (newCenterFreqL1 + newCenterFreqH1)/2];
                                    tempDriftData(2, :) = [tempDriftData(2, 2:end) ((time- obj.refTime)/1000)];
                                case 3
                                    tempPID2Data = [tempPID2Data(2:end) calcErr2];
                                case 5
                                    tempPID3Data = [tempPID3Data(2:end) calcErr3];
                                    tempDriftData(1, :) = [tempDriftData(1, 2:end) (newCenterFreqL1 + newCenterFreqH1)/2];
                                    tempDriftData(2, :) = [tempDriftData(2, 2:end) ((time- obj.refTime)/1000)];
                                case 7
                                    tempPID4Data = [tempPID4Data(2:end) calcErr4];
                            end
                    else
                        switch rezeroSeqPlace 
                            case 0 % Unpol,  Ix =  Ix0 - Delta
                                zeroingExcAndVoltages(1,1) = tNorm;
                                zeroingExcAndVoltages(1,2) = previousVoltages(1);
                            case 1 % Unpol,  Ix =  Ix0
                                zeroingExcAndVoltages(2,1) = tNorm;
                                zeroingExcAndVoltages(2,2) = previousVoltages(1);
                            case 2 % Unpol,  Ix =  Ix0 + Delta
                                zeroingExcAndVoltages(3,1) = tNorm;
                                zeroingExcAndVoltages(3,2) = previousVoltages(1);
                                [C, I] = max(zeroingExcAndVoltages);
                                if (I(1) == 2)
                                    newVoltage = obj.findBestVoltage(zeroingExcAndVoltages);
                                    meanVx = ((meanFilterNum-1)*meanVx + newVoltage)/meanFilterNum;
                                    if (isnan(meanVx))
                                        meanVx = zeroingExcAndVoltages(2,2);
                                    end
                                elseif (I(1) == 1)
                                    meanVx = zeroingExcAndVoltages(2,2) - 0.3;
                                else
                                    meanVx = zeroingExcAndVoltages(2,2) + 0.3 ;   
                                end
                                pause(0.2)
                                if (~isnan(meanVx))
                                    obj.changeAnalogVoltage(0, meanVx);
                                end
                            case 3 % Unpol,  Iy =  Iy0 - Delta
                                zeroingExcAndVoltages(1,1) = tNorm;
                                zeroingExcAndVoltages(1,2) = previousVoltages(2);
                            case 4 % Unpol,  Iy =  Iy0
                                zeroingExcAndVoltages(2,1) = tNorm;
                                zeroingExcAndVoltages(2,2) = previousVoltages(2);
                            case 5 % Unpol,  Iy =  Iy0 + Delta
                                zeroingExcAndVoltages(3,1) = tNorm;
                                zeroingExcAndVoltages(3,2) = previousVoltages(2);
                                [C, I] = max(zeroingExcAndVoltages);
                                if (I(1) == 2)
                                    newVoltage = obj.findBestVoltage(zeroingExcAndVoltages);
                                    meanVy = ((meanFilterNum-1)*meanVy + newVoltage)/meanFilterNum;
                                    if (isnan(meanVy))
                                        meanVy = zeroingExcAndVoltages(2,2);
                                    end
                                elseif (I(1) == 1)
                                    meanVy = zeroingExcAndVoltages(2,2) - 0.3;
                                else
                                    meanVy = zeroingExcAndVoltages(2,2) + 0.3 ;   
                                end
                                pause(0.2)
                                if (~isnan(meanVy))
                                    obj.changeAnalogVoltage(1, meanVy);
                                end
                            case 6 % Unpol,  Iz =  Iz0 - Delta
                                zeroingExcAndVoltages(1,1) = tNorm;
                                zeroingExcAndVoltages(1,2) = previousVoltages(3);
                            case 7 % Unpol,  Iz =  Iz0
                                zeroingExcAndVoltages(2,1) = tNorm;
                                zeroingExcAndVoltages(2,2) = previousVoltages(3);
                            case 8 % Unpol,  Iz =  Iz0 + Delta
                                zeroingExcAndVoltages(3,1) = tNorm;
                                zeroingExcAndVoltages(3,2) = previousVoltages(3);
                                [C, I] = max(zeroingExcAndVoltages);
                                if (I(1) == 2)
                                    newVoltage = obj.findBestVoltage(zeroingExcAndVoltages);
                                    meanVz = ((meanFilterNum-1)*meanVz + newVoltage)/meanFilterNum;
                                    if (isnan(meanVz))
                                        meanVz = zeroingExcAndVoltages(2,2);
                                    end
                                elseif (I(1) == 1)
                                    meanVz = zeroingExcAndVoltages(2,2) - 0.3;
                                else
                                    meanVz = zeroingExcAndVoltages(2,2) + 0.3 ;   
                                end
                                pause(0.2)
                                if (~isnan(meanVz))
                                    obj.changeAnalogVoltage(2, meanVz);
                                end
                        end
                    end
                        
                    
                    %Do some Plotting
                    firstplot = 1;
                    if get(myHandles.ignoreFirstToggle, 'Value') && plotstart < 3
                        plotstart = 2;
                        firstplot = 2;
                    end
                    if runNum == 1
                        tempH(1) = plot(myHandles.sNormAxes, tempNormData(end-FreqLocker.plotSize:end), 'ok', 'LineWidth', 3);
                        tempH(2) = plot(myHandles.sEAxes, tempScanData(2,end-FreqLocker.plotSize:end), 'or', 'LineWidth', 2);
                        tempH(3) = plot(myHandles.sGAxes, tempScanData(1,end-FreqLocker.plotSize:end), 'ob', 'LineWidth', 2);
                        tempH(4) = plot(myHandles.sBGAxes, tempScanData(3,end-FreqLocker.plotSize:end), 'ob', 'LineWidth', 1);
                        tempH(5) = plot(myHandles.sSummedAxes, tempSummedData(end-FreqLocker.plotSize:end), 'og', 'LineWidth', 2);
                        tempH(6) = plot(myHandles.errPlot, tempPID1Data(end-FreqLocker.plotSize:end), 'ok', 'LineWidth', 2);
                    elseif runNum > 1
                        set(tempH(1), 'YData', tempNormData(end-FreqLocker.plotSize:end));
                        set(tempH(2), 'YData', tempScanData(2,end-FreqLocker.plotSize:end));
                        set(tempH(3), 'YData', tempScanData(1,end-FreqLocker.plotSize:end));
                        set(tempH(4), 'YData', tempScanData(3,end-FreqLocker.plotSize:end));
                        set(tempH(5), 'YData', tempSummedData(end-FreqLocker.plotSize:end));
                        set(tempH(6), 'YData', tempPID1Data(end-FreqLocker.plotSize:end));
                    end
                    if (rezeroSeqPlace > 8)
                        switch seqPlace
                            case {0,1}
                                obj.myPID1gui.updateMyPlots(calcErr1, runNum, FreqLocker.plotSize);
                            case {2,3}
                                obj.myPID2gui.updateMyPlots(calcErr2, runNum, FreqLocker.plotSize);
                            case {4,5}
                                obj.myPID3gui.updateMyPlots(calcErr3, runNum, FreqLocker.plotSize);
                            case {6,7}
                                obj.myPID4gui.updateMyPlots(calcErr4, runNum, FreqLocker.plotSize);
                        end
                    end
                    if (mod(rezeroSeqPlace+1,rezeroSequenceNumber) > 8) 
                        switch mod(seqPlace+1,8)
                            case 0
                                set(myHandles.lockStatus, 'String', 'Low1_L');
                            case 1
                                set(myHandles.lockStatus, 'String', 'Low1_R');
                            case 2
                                set(myHandles.lockStatus, 'String', 'Low2_L');
                            case 3
                                set(myHandles.lockStatus, 'String', 'Low2_R');
                            case 4
                                set(myHandles.lockStatus, 'String', 'High1_L');
                            case 5
                                set(myHandles.lockStatus, 'String', 'High1_R');
                            case 6
                                set(myHandles.lockStatus, 'String', 'High2_L');
                            case 7
                                set(myHandles.lockStatus, 'String', 'High2_R');
                        end
                    else
                        switch mod(rezeroSeqPlace+1,rezeroSequenceNumber)
                            case 0
                                set(myHandles.lockStatus, 'String', 'Unpolarized, Ix - Delta');
                            case 1
                                set(myHandles.lockStatus, 'String', 'Unpolarized, Ix');
                            case 2
                                set(myHandles.lockStatus, 'String', 'Unpolarized, Ix + Delta');
                            case 3
                                set(myHandles.lockStatus, 'String', 'Unpolarized, Iy - Delta');
                            case 4
                                set(myHandles.lockStatus, 'String', 'Unpolarized, Iy');
                            case 5
                                set(myHandles.lockStatus, 'String', 'Unpolarized, Iy + Delta');
                            case 6
                                set(myHandles.lockStatus, 'String', 'Unpolarized, Iz - Delta');
                            case 7
                                set(myHandles.lockStatus, 'String', 'Unpolarized, Iz');
                            case 8
                                set(myHandles.lockStatus, 'String', 'Unpolarized, Iz + Delta');
                        end
                    end
                    %9. Check Save and Write Data to file.
% 'Frequency', 'Norm', 'GndState', 'ExcState', 'Background', 'TStamp', 'BLUEGndState', 'BLUEBackground', 'BLUEExcState'
                    temp = [prevFrequency tNorm tSCdat12(1) tSCdat12(2) tSCdat3 time tSCdat456(1) tSCdat456(3) tSCdat456(2)];
                    
                        if runNum >= 2 && seqPlace == 1 && ~badData && rezeroSeqPlace > 8
                            tempPID1 = [calcErr1 calcCorr1 newCenterFreqL1];%err correctionApplied servoVal
                        else
                            tempPID1 = [0 0 0];%err correctionApplied servoVal
                        end
                        if runNum >= 2 && seqPlace == 3 && ~badData && rezeroSeqPlace > 8
                            tempPID2 = [calcErr2 calcCorr2 newCenterFreqL2];%err correctionApplied servoVal
                        else
                            tempPID2 = [0 0 0];
                        end

                        if runNum >= 2 && seqPlace == 5 && ~badData && rezeroSeqPlace > 8
                            tempPID3 = [calcErr3 calcCorr3 newCenterFreqH1];%err correctionApplied servoVal
                        else
                            tempPID3 = [0 0 0];
                        end

                        if runNum >= 2 && seqPlace == 7 && ~badData && rezeroSeqPlace > 8
                            tempPID4 = [calcErr4 calcCorr4 newCenterFreqH2];%err correctionApplied servoVal
                        else
                            tempPID4 = [0 0 0];
                        end
                    temp = [temp tempPID1 tempPID2 tempPID3 tempPID4];
                    temp = [temp previousVoltages];
                    if get(myHandles.calcSrFreq, 'Value') && runNum >= 8 && rezeroSeqPlace > 8
                        temp = [temp (newCenterFreqL1 + newCenterFreqH1)/2 (newCenterFreqL1 - newCenterFreqH1)];
                        temp = [temp (newCenterFreqL2 + newCenterFreqH2)/2 (newCenterFreqL2 - newCenterFreqH2)];
                    else
                        temp = [temp 0 0 0 0];
                    end
                    if get(myHandles.cycleNumOnCN, 'Value')
                        temp = [temp prevCycleNum];
                        setappdata(obj.myTopFigure, 'prevCycleNum', cycleNum);
                    else
                        temp = [temp 0];
                    end
                    temp = [temp badData];
                    fprintf(fid, '%8.6f\t', temp);
                    fprintf(fid, '\r\n');
                    
                    
                    if (runNum > 5 && tNorm >= 0.1 && tNorm <= 1.0)
                        set(myHandles.lowStartFrequency1, 'String', num2str(newCenterFreqL1 - linewidth/2));
                        set(myHandles.highStartFrequency1, 'String', num2str(newCenterFreqH1 + linewidth/2));
                        set(myHandles.lowStartFrequency2, 'String', num2str(newCenterFreqL2 - linewidth2/2));
                        set(myHandles.highStartFrequency2, 'String', num2str(newCenterFreqH2 + linewidth2/2));
                    end
                    pointDone = 1;
                    obj.updateDriftPlots(runNum);
            end
            if (getappdata(obj.myTopFigure, 'run')) % Prepare for a new data point
                if runNum == 1
                    setappdata(obj.myTopFigure, 'taxis', taxis);
                end
                runNum = runNum + 1;
                seqPlace = mod(seqPlace + 1,4);
                setappdata(obj.myTopFigure, 'prevFrequency', curFrequency);
                setappdata(obj.myTopFigure, 'normData', tempNormData);
                setappdata(obj.myTopFigure, 'scanData', tempScanData);
                setappdata(obj.myTopFigure, 'summedData', tempSummedData);
                setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
                setappdata(obj.myTopFigure, 'PID2Data', tempPID2Data);
                setappdata(obj.myTopFigure, 'PID3Data', tempPID3Data);
                setappdata(obj.myTopFigure, 'PID4Data', tempPID4Data);
                setappdata(obj.myTopFigure, 'DriftData', tempDriftData);
                setappdata(obj.myTopFigure, 'runNum', runNum);
                setappdata(obj.myTopFigure, 'seqPlace', seqPlace);
                setappdata(obj.myTopFigure, 'prevExcPID1', prevExcPID1);
                setappdata(obj.myTopFigure, 'prevExcPID2', prevExcPID2);
                setappdata(obj.myTopFigure, 'prevExcPID3', prevExcPID3);
                setappdata(obj.myTopFigure, 'prevExcPID4', prevExcPID4);
                setappdata(obj.myTopFigure, 'newCenterFreqL1', newCenterFreqL1);
                setappdata(obj.myTopFigure, 'newCenterFreqL2', newCenterFreqL2);
                setappdata(obj.myTopFigure, 'newCenterFreqH1', newCenterFreqH1);
                setappdata(obj.myTopFigure, 'newCenterFreqH2', newCenterFreqH2);
                setappdata(obj.myTopFigure, 'plottingHandles', tempH);
                
                setappdata(obj.myTopFigure, 'rezeroSequenceNumber', rezeroSequenceNumber);
                setappdata(obj.myTopFigure, 'voltageStepSize', voltageStepSize);
                setappdata(obj.myTopFigure, 'zeroingExcAndVoltages', zeroingExcAndVoltages);
                setappdata(obj.myTopFigure, 'rezeroSeqPlace', rezeroSeqPlace);
                setappdata(obj.myTopFigure, 'meanFilterNum', meanFilterNum);
                setappdata(obj.myTopFigure, 'meanVx', meanVx);
                setappdata(obj.myTopFigure, 'meanVy', meanVy);
                setappdata(obj.myTopFigure, 'meanVz', meanVz);
                
                guidata(obj.myTopFigure, myHandles);
               
            else %close everything done
                setappdata(obj.myTopFigure, 'readyForData', 0);
                %9.5 Close Frequency Synthesizer and Data file
                obj.mysPID1.clear();
                obj.mysPID2.clear();
                obj.mysPID3.clear();
                obj.mysPID4.clear();
                obj.myFreqSynth.close();
                fclose('all'); % weird matlab thing, can't just close fid, won't work.
                %10. If ~Run, make obvious and reset 'run'
                disp('Acquisistion Stopped');
                set(myHandles.curFreq, 'String', 'STOPPED');
                setappdata(obj.myTopFigure, 'run', 1);
                drawnow;
                try
                    rmappdata(obj.myTopFigure, 'normData');
                    rmappdata(obj.myTopFigure, 'scanData');
                    rmappdata(obj.myTopFigure, 'summedData');
                    rmappdata(obj.myTopFigure, 'PID1Data');
                    rmappdata(obj.myTopFigure, 'PID2Data');
                    rmappdata(obj.myTopFigure, 'PID3Data');
                    rmappdata(obj.myTopFigure, 'PID4Data');
                    rmappdata(obj.myTopFigure, 'DriftData');
                    rmappdata(obj.myTopFigure, 'runNum');
                    rmappdata(obj.myTopFigure, 'taxis');
                    rmappdata(obj.myTopFigure, 'fid');
                    rmappdata(obj.myTopFigure, 'seqPlace');
                    rmappdata(obj.myTopFigure, 'prevExcPID1');
                    rmappdata(obj.myTopFigure, 'prevExcPID2');
                    rmappdata(obj.myTopFigure, 'prevExcPID3');
                    rmappdata(obj.myTopFigure, 'prevExcPID4');
                    rmappdata(obj.myTopFigure, 'newCenterFreqL1');
                    rmappdata(obj.myTopFigure, 'newCenterFreqL2');
                    rmappdata(obj.myTopFigure, 'newCenterFreqH1');
                    rmappdata(obj.myTopFigure, 'newCenterFreqH2');
                    rmappdata(obj.myTopFigure, 'prevFrequency');
                    rmappdata(obj.myTopFigure, 'plottingHandles');
                    rmappdata(obj.myTopFigure, 'prevCycleNum');
                    
                    rmappdata(obj.myTopFigure, 'rezeroSequenceNumber');
                    rmappdata(obj.myTopFigure, 'voltageStepSize');
                    rmappdata(obj.myTopFigure, 'zeroingExcAndVoltages');
                    rmappdata(obj.myTopFigure, 'rezeroSeqPlace');
                    rmappdata(obj.myTopFigure, 'meanFilterNum');
                    rmappdata(obj.myTopFigure, 'meanVx');
                    rmappdata(obj.myTopFigure, 'meanVy');
                    rmappdata(obj.myTopFigure, 'meanVz');
                catch exception
                    exception.message
                end
                drawnow;
                
                guidata(obj.myTopFigure, myHandles);
                
                clear variables
                clear mex
            end
        end
        function start2PeakLockRezero_initialize(obj)
            setappdata(obj.myTopFigure, 'readyForData', 0);
            myHandles = guidata(obj.myTopFigure);
            rezeroSequenceNumber = str2num(['uint16(' get(myHandles.numRezero, 'String') ')']);
%             rezeroSequenceNumber = 41;
            voltageStepSize = 1.25;
            meanFilterNum = 3;
            meanVx = NaN;
            meanVy = NaN;
            meanVz = NaN;
            zeroingExcAndVoltages = [0, 0; 0, 0; 0, 0];
            prevExcPID1 = 0; %For use in calculating the present Error for PID1
            prevExcPID2 = 0; %For use in calculating the present Error for PID2
            linewidth = str2double(get(myHandles.linewidth, 'String'));
            newCenterFreqL1 = str2double(get(myHandles.lowStartFrequency1, 'String'))+ linewidth/2;
            newCenterFreqH1 = str2double(get(myHandles.highStartFrequency1, 'String'))- linewidth/2;
            runNum = 1;
            if get(myHandles.cycleNumOnCN, 'Value')
                runNum = 0;
                obj.myCycleNuControl.initialize();
            end
            seqPlace = 0; %0 = left side of PID1 - low Freq
                          %1 = right side of PID1  - low Freq
                          %2 = left side of PID2  - high Freq
                          %3 = right side of PID2 - high Freq
            rezeroSeqPlace = 9; %0 = Unpol,  Ix =  Ix0 - Delta
                                %1 = Unpol,  Ix =  Ix0
                                %2 = Unpol,  Ix =  Ix0 + Delta
                                %3 = Unpol,  Iy =  Iy0 - Delta
                                %4 = Unpol,  Iy =  Iy0
                                %5 = Unpol,  Iy =  Iy0 + Delta
                                %6 = Unpol,  Iz =  Iz0 - Delta
                                %7 = Unpol,  Iz =  Iz0
                                %8 = Unpol,  Iy =  Iy0 + Delta
                                %9 and on.....do whatever seqPlace says 
           
            %AVOID MEMORY MOVEMENT SLOWDOWNS
            tempScanData = zeros(6,FreqLocker.bufferSize);
            tempSummedData = zeros(1,FreqLocker.bufferSize);
            tempNormData = zeros(1,FreqLocker.bufferSize);
            tempPID1Data = zeros(1,FreqLocker.bufferSize);
            tempPID2Data = zeros(1,FreqLocker.bufferSize);
            tempDriftData = NaN(2,FreqLocker.bufferSize);
            obj.myDriftFitHandle = [];
            obj.myDriftPlotHandle = [];
            cla(myHandles.DriftAXES);
            
            
            
            %Initialize Liquid Crystal Waveplate
            if get(myHandles.bounceLCwaveplate, 'Value') && strcmp(get(myHandles.openSerialLC, 'Enable'), 'off')
                fprintf(obj.myLCuControl.mySerial, [':2;c' int2str(mod(seqPlace+1,8)) ';d0;t80000']);
            end
            

            %2.5 Initialize Frequency Synthesizer
            obj.myFreqSynth.initialize();
            %Start Frequency Loop / Check 'Run'
            set(myHandles.curFreq, 'BackgroundColor', 'green');
            
            if getappdata(obj.myTopFigure, 'run')
                        [path, fileName] = obj.createFileName();
                        try
                            mkdir(path);
                            fid = fopen([path filesep fileName], 'a');
                            fwrite(fid, datestr(now, 'mm/dd/yyyy\tHH:MM AM'))
                            fprintf(fid, '\r\n');
                            colNames = {'Frequency', 'Norm', 'GndState', ...
                                'ExcState', 'Background', 'TStamp', 'BLUEGndState', ...
                                'BLUEBackground', 'BLUEExcState', ...
                                'err1', 'cor1', 'servoVal1', ...
                                'err2', 'cor2', 'servoVal2', ...
                                'Vx', 'Vy', 'Vz', ...
                                'VFixed', 'CFixed', 'VBellows', 'CBellows', ...
                                'freqSr1', 'delta1', 'cycleNum', 'badData'};
%                             if get(myHandles.stepVoltages, 'Value')
%                                 colNames = [colNames obj.myAnalogStepper.myNames];
%                             end
                            n = length(colNames);
                            for i=1:n
                                fprintf(fid, '%s\t', colNames{i});
                            end
                                fprintf(fid, '\r\n');
                        catch
                            disp('Could not open file to write to.');
                        end
            end
            %Set to first frequency point
            curFrequency = newCenterFreqL1 - linewidth/2;
            ret = obj.myFreqSynth.setFrequency(num2str(curFrequency));
                if ~ret
                    setappdata(obj.myTopFigure, 'run', 0);
                end
                if get(myHandles.useTSensor, 'Value')
                    try
                            obj.myTempSensor = visa('ni', 'GPIB0::12::INSTR')
                            fopen(obj.myTempSensor)
                    catch err
                    end
                end
            setappdata(obj.myTopFigure, 'normData', tempNormData);
            setappdata(obj.myTopFigure, 'scanData', tempScanData);
            setappdata(obj.myTopFigure, 'summedData', tempSummedData);
            setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
            setappdata(obj.myTopFigure, 'PID2Data', tempPID2Data);
            setappdata(obj.myTopFigure, 'DriftData', tempDriftData);
            setappdata(obj.myTopFigure, 'runNum', runNum);
            setappdata(obj.myTopFigure, 'fid', fid);
            setappdata(obj.myTopFigure, 'seqPlace', seqPlace);
            setappdata(obj.myTopFigure, 'prevExcPID1', prevExcPID1);
            setappdata(obj.myTopFigure, 'prevExcPID2', prevExcPID2);
            setappdata(obj.myTopFigure, 'newCenterFreqL1', newCenterFreqL1);
            setappdata(obj.myTopFigure, 'newCenterFreqH1', newCenterFreqH1);
            setappdata(obj.myTopFigure, 'prevFrequency', curFrequency);
            setappdata(obj.myTopFigure, 'nextStep', @obj.start2PeakLockRezero_takeNextPoint);
            
            %%% Stuff for rezeroing the field
            setappdata(obj.myTopFigure, 'rezeroSequenceNumber', rezeroSequenceNumber);
            setappdata(obj.myTopFigure, 'voltageStepSize', voltageStepSize);
            setappdata(obj.myTopFigure, 'zeroingExcAndVoltages', zeroingExcAndVoltages);
            setappdata(obj.myTopFigure, 'rezeroSeqPlace', rezeroSeqPlace);
            setappdata(obj.myTopFigure, 'meanFilterNum', meanFilterNum);
            setappdata(obj.myTopFigure, 'meanVx', meanVx);
            setappdata(obj.myTopFigure, 'meanVy', meanVy);
            setappdata(obj.myTopFigure, 'meanVz', meanVz);
            
            pause(0.5) %I think I need this to make sure we get our first point good
            guidata(obj.myTopFigure, myHandles);
            setappdata(obj.myTopFigure, 'readyForData', 1);
        end
        function start2PeakLockRezero_takeNextPoint(obj, data)
            myHandles = guidata(obj.myTopFigure);
            tempNormData = getappdata(obj.myTopFigure, 'normData');
            tempScanData = getappdata(obj.myTopFigure, 'scanData');
            tempSummedData = getappdata(obj.myTopFigure, 'summedData');
            tempPID1Data = getappdata(obj.myTopFigure, 'PID1Data');
            tempPID2Data = getappdata(obj.myTopFigure, 'PID2Data');
            tempDriftData = getappdata(obj.myTopFigure, 'DriftData');
            runNum = getappdata(obj.myTopFigure, 'runNum');
            fid = getappdata(obj.myTopFigure, 'fid');
            seqPlace = getappdata(obj.myTopFigure, 'seqPlace');
            prevExcPID1 = getappdata(obj.myTopFigure, 'prevExcPID1');
            prevExcPID2 = getappdata(obj.myTopFigure, 'prevExcPID2');
            linewidth = str2double(get(myHandles.linewidth, 'String'));
            linewidth2 = str2double(get(myHandles.linewidth2, 'String'));
            newCenterFreqL1 = getappdata(obj.myTopFigure, 'newCenterFreqL1');
            newCenterFreqH1 = getappdata(obj.myTopFigure, 'newCenterFreqH1');
            prevFrequency = getappdata(obj.myTopFigure, 'prevFrequency');
            badData = 0;
            
            %%%Stuff for rezeroing the field
            rezeroSequenceNumber = getappdata(obj.myTopFigure, 'rezeroSequenceNumber');
            voltageStepSize = getappdata(obj.myTopFigure, 'voltageStepSize');
            zeroingExcAndVoltages = getappdata(obj.myTopFigure, 'zeroingExcAndVoltages');
            rezeroSeqPlace = getappdata(obj.myTopFigure, 'rezeroSeqPlace');
            previousVoltages = obj.readAnalogVoltages();
            meanFilterNum = getappdata(obj.myTopFigure, 'meanFilterNum');
            meanVx = getappdata(obj.myTopFigure, 'meanVx');
            meanVy = getappdata(obj.myTopFigure, 'meanVy');
            meanVz = getappdata(obj.myTopFigure, 'meanVz');
            
            if runNum > 1
                tempH = getappdata(obj.myTopFigure, 'plottingHandles');
                taxis = getappdata(obj.myTopFigure, 'taxis');
            end
            
            if get(myHandles.cycleNumOnCN, 'Value')
                cycleNum = str2double(obj.myCycleNuControl.getCycleNum());
                if runNum ~= 0
                    prevCycleNum = getappdata(obj.myTopFigure, 'prevCycleNum');
                end
                rezeroSeqPlace = mod(cycleNum-2,rezeroSequenceNumber);% 1 for previous measurement and 1 for mike bishof's convention
                NEXTrezeroSeqPlace = mod(rezeroSeqPlace + 1, rezeroSequenceNumber);
                seqPlace = mod(cycleNum-2,8); % 1 for previous measurement and 1 for mike bishof's convention
                fprintf(1,['Cycle Number for data just taken : ' num2str(cycleNum-1) '\rTherfore we just took seqPlace: ' num2str(mod(cycleNum-2,8)) '\n']);
                if runNum ~= 0 && prevCycleNum ~= (cycleNum-1)
                    fprintf(1, 'Cycle Slipped\n');
                    badData = 1;
                    pause(0.1);
                end
                setappdata(obj.myTopFigure, 'prevCycleNum', cycleNum);
            end
            pointDone = 0;
            while(getappdata(obj.myTopFigure, 'run') && ~pointDone)
                plotstart = 1; %Needs to be out here so plots can be cleared
                %IMMEDIATELY READJUST LC WAVEPLATE and set frequency for
                %next point. Also decide if next time is a rezeroing
                %unpolarized sequence, and set comp coil voltages
                %accordingly.
                if (NEXTrezeroSeqPlace > 8)
                   switch mod(seqPlace+1,4) 
                        case 0 % left side of line 1
                            curFrequency = newCenterFreqL1 - linewidth/2;
                        case 1 % right side of line 1
                            curFrequency = newCenterFreqL1 + linewidth/2;
                        case 2 % left side of line 3
                            curFrequency = newCenterFreqH1 - linewidth/2;
                        case 3 % right side of line 3
                            curFrequency = newCenterFreqH1 + linewidth/2;
                   end
                    if get(myHandles.bounceLCwaveplate, 'Value') && strcmp(get(myHandles.openSerialLC, 'Enable'), 'off') %NEEDS TO BE FIXED
                        disp([':0;c' int2str(mod(seqPlace+1,4)) ';d0;t80000']); 
                        fprintf(obj.myLCuControl.mySerial, [':0;c' int2str(mod(seqPlace+1,4)) ';d0;t80000']);
                        %fscanf(obj.myLCuControl.mySerial)
                    end
                    else if (runNum > NEXTrezeroSeqPlace) % i think this helps with bootstrapping.
%                             runNum
%                             rezeroSeqPlace+1
%                             previousVoltages(1) - voltageStepSize
                        switch mod(rezeroSeqPlace+1,rezeroSequenceNumber) 
                            case 0 % Unpol,  Ix =  Ix0 - Delta
                                curFrequency = (newCenterFreqL1 + newCenterFreqH1)/2;
                                obj.changeAnalogVoltage(0, previousVoltages(1) - voltageStepSize);
                            case 1 % Unpol,  Ix =  Ix0
                                curFrequency = (newCenterFreqL1 + newCenterFreqH1)/2;
                                obj.changeAnalogVoltage(0, previousVoltages(1) + voltageStepSize); %need to add because of previous step in sequence.
                            case 2 % Unpol,  Ix =  Ix0 + Delta
                                curFrequency = (newCenterFreqL1 + newCenterFreqH1)/2;
                                obj.changeAnalogVoltage(0, previousVoltages(1) + voltageStepSize);
                            case 3 % Unpol,  Iy =  Iy0 - Delta
                                curFrequency = (newCenterFreqL1 + newCenterFreqH1)/2;
                                obj.changeAnalogVoltage(1, previousVoltages(2) - voltageStepSize);
                            case 4 % Unpol,  Iy =  Iy0
                                curFrequency = (newCenterFreqL1 + newCenterFreqH1)/2;
                                obj.changeAnalogVoltage(1, previousVoltages(2) + voltageStepSize); %need to add because of previous step in sequence.
                            case 5 % Unpol,  Iy =  Iy0 + Delta
                                curFrequency = (newCenterFreqL1 + newCenterFreqH1)/2;
                                obj.changeAnalogVoltage(1, previousVoltages(2) + voltageStepSize);
                            case 6 % Unpol,  Iz =  Iz0 - Delta
                                curFrequency = (newCenterFreqL1 + newCenterFreqH1)/2;
                                obj.changeAnalogVoltage(2, previousVoltages(3) - voltageStepSize);
                            case 7 % Unpol,  Iz =  Iz0
                                curFrequency = (newCenterFreqL1 + newCenterFreqH1)/2;
                                obj.changeAnalogVoltage(2, previousVoltages(3) + voltageStepSize); %need to add because of previous step in sequence.
                            case 8 % Unpol,  Iz =  Iz0 + Delta
                                curFrequency = (newCenterFreqL1 + newCenterFreqH1)/2;
                                obj.changeAnalogVoltage(2, previousVoltages(3) + voltageStepSize);
                        end
                        if get(myHandles.bounceLCwaveplate, 'Value') && strcmp(get(myHandles.openSerialLC, 'Enable'), 'off') %NEEDS TO BE FIXED
                            disp(':4;c0;d0;t80000'); 
                            fprintf(obj.myLCuControl.mySerial, ':4;c0;d0;t80000');
                        end
                    else
                        curFrequency = newCenterFreqL1 - linewidth/2;
                    end    
                end
                

                ret = obj.myFreqSynth.setFrequency(num2str(curFrequency));
                if ~ret
                    setappdata(obj.myTopFigure, 'run', 0);
                    break;
                end
                set(myHandles.curFreq, 'String', num2str(curFrequency));
                set(myHandles.curFreqL, 'String', num2str(curFrequency));
                
                if runNum == 0
                    runNum = runNum + 1;
                    setappdata(obj.myTopFigure, 'runNum', runNum);
                    return;
                end
                %4. Update Progress Bar
                drawnow;
                %5. Call Gage Card to gather data
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
                    %7. Clear the Raw Plots, Plot the Raw Plots
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
                    tempScanData(1:2, :) = [tempScanData(1:2, 2:end) tSCdat12];
                    tempScanData(3,:) = [tempScanData(3, 2:end) tSCdat3];
                    tempScanData(4:6,:) = [tempScanData(4:6, 2:end) tSCdat456];
                    %NORMALIZED counts are (E - bg)/(E + G - 2bg)
                    tNorm = (tSCdat12(2)) / (tSCdat12(2) + tSCdat12(1));
                    tempNormData = [tempNormData(2:end) tNorm];
                    %SUMMED counts
                    tSum = tSCdat12(2) + tSCdat12(1);
                    tempSummedData = [tempSummedData(2:end) tSum];
                    
                    if (rezeroSeqPlace > 8)
                    %Do some PID magic!
                    %Calculate Error for PID1
                        switch seqPlace
                            case {0, 1}
                                calcErr1 = tNorm - prevExcPID1;
                                tempPID1Data = getappdata(obj.myTopFigure, 'PID1Data');
                            case {2, 3}
                                calcErr2 = tNorm - prevExcPID2;
                                tempPID2Data = getappdata(obj.myTopFigure, 'PID2Data');
                        end

                        if runNum >= 2 && ~badData
                            switch seqPlace
                                case {0,1}
                                    prevExcPID1 = tNorm;
                                case {2, 3}
                                    prevExcPID2 = tNorm;
                            end

                            obj.updatePIDvalues();
                            obj.checkPIDenables();
                            deltaT1 = str2double(get(obj.myPID1gui.myDeltaT, 'String'));
                            deltaT2 = str2double(get(obj.myPID2gui.myDeltaT, 'String'));
                                switch seqPlace
                                    case 0
                                        calcCorr1 = 0;
                                    case 1
                                            if deltaT1 == 0
                                                calcCorr1 = obj.mysPID1.calculate(calcErr1, time);
                                            else
                                                calcCorr1 = obj.mysPID1.calculate(calcErr1, -deltaT1);
                                            end
                                            newCenterFreqL1 = newCenterFreqL1 + calcCorr1;
                                    case 2
                                        calcCorr2 = 0;
                                    case 3
                                            if deltaT2 == 0
                                                calcCorr2 = obj.mysPID2.calculate(calcErr2, time);
                                            else
                                                calcCorr2 = obj.mysPID2.calculate(calcErr2, -deltaT2);
                                            end
                                            newCenterFreqH1 = newCenterFreqH1 + calcCorr2;
                                end
                        end

                            switch seqPlace
                                case 1
                                    tempPID1Data = [tempPID1Data(2:end) calcErr1];
                                    tempDriftData(1, :) = [tempDriftData(1, 2:end) (newCenterFreqL1 + newCenterFreqH1)/2];
                                    tempDriftData(2, :) = [tempDriftData(2, 2:end) ((time- obj.refTime)/1000)];
                                case 3
                                    tempPID2Data = [tempPID2Data(2:end) calcErr2];
                            end
                    else
                        switch rezeroSeqPlace 
                            case 0 % Unpol,  Ix =  Ix0 - Delta
                                zeroingExcAndVoltages(1,1) = tNorm;
                                zeroingExcAndVoltages(1,2) = previousVoltages(1);
                            case 1 % Unpol,  Ix =  Ix0
                                zeroingExcAndVoltages(2,1) = tNorm;
                                zeroingExcAndVoltages(2,2) = previousVoltages(1);
                            case 2 % Unpol,  Ix =  Ix0 + Delta
                                zeroingExcAndVoltages(3,1) = tNorm;
                                zeroingExcAndVoltages(3,2) = previousVoltages(1);
                                [C, I] = max(zeroingExcAndVoltages);
                                if (I(1) == 2)
                                    newVoltage = obj.findBestVoltage(zeroingExcAndVoltages);
                                    meanVx = ((meanFilterNum-1)*meanVx + newVoltage)/meanFilterNum;
                                    if (isnan(meanVx))
                                        meanVx = zeroingExcAndVoltages(2,2);
                                    end
                                elseif (I(1) == 1)
                                    meanVx = zeroingExcAndVoltages(2,2) - 0.3;
                                else
                                    meanVx = zeroingExcAndVoltages(2,2) + 0.3 ;   
                                end
                                pause(0.2)
                                if (~isnan(meanVx))
                                    obj.changeAnalogVoltage(0, meanVx);
                                end
                            case 3 % Unpol,  Iy =  Iy0 - Delta
                                zeroingExcAndVoltages(1,1) = tNorm;
                                zeroingExcAndVoltages(1,2) = previousVoltages(2);
                            case 4 % Unpol,  Iy =  Iy0
                                zeroingExcAndVoltages(2,1) = tNorm;
                                zeroingExcAndVoltages(2,2) = previousVoltages(2);
                            case 5 % Unpol,  Iy =  Iy0 + Delta
                                zeroingExcAndVoltages(3,1) = tNorm;
                                zeroingExcAndVoltages(3,2) = previousVoltages(2);
                                [C, I] = max(zeroingExcAndVoltages);
                                if (I(1) == 2)
                                    newVoltage = obj.findBestVoltage(zeroingExcAndVoltages);
                                    meanVy = ((meanFilterNum-1)*meanVy + newVoltage)/meanFilterNum;
                                    if (isnan(meanVy))
                                        meanVy = zeroingExcAndVoltages(2,2);
                                    end
                                elseif (I(1) == 1)
                                    meanVy = zeroingExcAndVoltages(2,2) - 0.3;
                                else
                                    meanVy = zeroingExcAndVoltages(2,2) + 0.3 ;   
                                end
                                pause(0.2)
                                if (~isnan(meanVy))
                                    obj.changeAnalogVoltage(1, meanVy);
                                end
                            case 6 % Unpol,  Iz =  Iz0 - Delta
                                zeroingExcAndVoltages(1,1) = tNorm;
                                zeroingExcAndVoltages(1,2) = previousVoltages(3);
                            case 7 % Unpol,  Iz =  Iz0
                                zeroingExcAndVoltages(2,1) = tNorm;
                                zeroingExcAndVoltages(2,2) = previousVoltages(3);
                            case 8 % Unpol,  Iz =  Iz0 + Delta
                                zeroingExcAndVoltages(3,1) = tNorm;
                                zeroingExcAndVoltages(3,2) = previousVoltages(3);
                                [C, I] = max(zeroingExcAndVoltages);
                                if (I(1) == 2)
                                    newVoltage = obj.findBestVoltage(zeroingExcAndVoltages);
                                    meanVz = ((meanFilterNum-1)*meanVz + newVoltage)/meanFilterNum;
                                    if (isnan(meanVz))
                                        meanVz = zeroingExcAndVoltages(2,2);
                                    end
                                elseif (I(1) == 1)
                                    meanVz = zeroingExcAndVoltages(2,2) - 0.3;
                                else
                                    meanVz = zeroingExcAndVoltages(2,2) + 0.3 ;   
                                end
                                pause(0.2)
                                if (~isnan(meanVz))
                                    obj.changeAnalogVoltage(2, meanVz);
                                end
                        end
                    end
                        
                    
                    %Do some Plotting
                    firstplot = 1;
                    if get(myHandles.ignoreFirstToggle, 'Value') && plotstart < 3
                        plotstart = 2;
                        firstplot = 2;
                    end
                    if runNum == 1
                        tempH(1) = plot(myHandles.sNormAxes, tempNormData(end-FreqLocker.plotSize:end), 'ok', 'LineWidth', 3);
                        tempH(2) = plot(myHandles.sEAxes, tempScanData(2,end-FreqLocker.plotSize:end), 'or', 'LineWidth', 2);
                        tempH(3) = plot(myHandles.sGAxes, tempScanData(1,end-FreqLocker.plotSize:end), 'ob', 'LineWidth', 2);
                        tempH(4) = plot(myHandles.sBGAxes, tempScanData(3,end-FreqLocker.plotSize:end), 'ob', 'LineWidth', 1);
                        tempH(5) = plot(myHandles.sSummedAxes, tempSummedData(end-FreqLocker.plotSize:end), 'og', 'LineWidth', 2);
                        tempH(6) = plot(myHandles.errPlot, tempPID1Data(end-FreqLocker.plotSize:end), 'ok', 'LineWidth', 2);
                    elseif runNum > 1
                        set(tempH(1), 'YData', tempNormData(end-FreqLocker.plotSize:end));
                        set(tempH(2), 'YData', tempScanData(2,end-FreqLocker.plotSize:end));
                        set(tempH(3), 'YData', tempScanData(1,end-FreqLocker.plotSize:end));
                        set(tempH(4), 'YData', tempScanData(3,end-FreqLocker.plotSize:end));
                        set(tempH(5), 'YData', tempSummedData(end-FreqLocker.plotSize:end));
                        set(tempH(6), 'YData', tempPID1Data(end-FreqLocker.plotSize:end));
                    end
                    if (rezeroSeqPlace > 8)
                        switch seqPlace
                            case {0,1}
                                obj.myPID1gui.updateMyPlots(calcErr1, runNum, FreqLocker.plotSize);
                            case {2,3}
                                obj.myPID2gui.updateMyPlots(calcErr2, runNum, FreqLocker.plotSize);
                        end
                    end
                    if (mod(rezeroSeqPlace+1,rezeroSequenceNumber) > 8) 
                        switch mod(seqPlace+1,8)
                            case 0
                                set(myHandles.lockStatus, 'String', 'Low1_L');
                            case 1
                                set(myHandles.lockStatus, 'String', 'Low1_R');
                            case 2
                                set(myHandles.lockStatus, 'String', 'High1_L');
                            case 3
                                set(myHandles.lockStatus, 'String', 'High2_R');
                        end
                    else
                        switch mod(rezeroSeqPlace+1,rezeroSequenceNumber)
                            case 0
                                set(myHandles.lockStatus, 'String', 'Unpolarized, Ix - Delta');
                            case 1
                                set(myHandles.lockStatus, 'String', 'Unpolarized, Ix');
                            case 2
                                set(myHandles.lockStatus, 'String', 'Unpolarized, Ix + Delta');
                            case 3
                                set(myHandles.lockStatus, 'String', 'Unpolarized, Iy - Delta');
                            case 4
                                set(myHandles.lockStatus, 'String', 'Unpolarized, Iy');
                            case 5
                                set(myHandles.lockStatus, 'String', 'Unpolarized, Iy + Delta');
                            case 6
                                set(myHandles.lockStatus, 'String', 'Unpolarized, Iz - Delta');
                            case 7
                                set(myHandles.lockStatus, 'String', 'Unpolarized, Iz');
                            case 8
                                set(myHandles.lockStatus, 'String', 'Unpolarized, Iz + Delta');
                        end
                    end
                    %9. Check Save and Write Data to file.
% 'Frequency', 'Norm', 'GndState', 'ExcState', 'Background', 'TStamp', 'BLUEGndState', 'BLUEBackground', 'BLUEExcState'
                    temp = [prevFrequency tNorm tSCdat12(1) tSCdat12(2) tSCdat3 time tSCdat456(1) tSCdat456(3) tSCdat456(2)];
                    
                        if runNum >= 2 && seqPlace == 1 && ~badData && rezeroSeqPlace > 8
                            tempPID1 = [calcErr1 calcCorr1 newCenterFreqL1];%err correctionApplied servoVal
                        else
                            tempPID1 = [0 0 0];%err correctionApplied servoVal
                        end
                        if runNum >= 2 && seqPlace == 3 && ~badData && rezeroSeqPlace > 8
                            tempPID2 = [calcErr2 calcCorr2 newCenterFreqH1];%err correctionApplied servoVal
                        else
                            tempPID2 = [0 0 0];
                        end
                    temp = [temp tempPID1 tempPID2];
                    temp = [temp previousVoltages];
                    if get(myHandles.useTSensor, 'Value')
                        [Vfixed, Cfixed, Vbellows, Cbellows] = obj.readTemps();
                        temp = [temp Vfixed Cfixed Vbellows Cbellows];
                        set(myHandles.TempFixed, 'String', num2str(Cfixed, '%5.8f'));
                        set(myHandles.TempBellows, 'String', num2str(Cbellows, '%5.8f'));
                    else
                    end
                    if get(myHandles.calcSrFreq, 'Value') && runNum >= 8 && rezeroSeqPlace > 8
                        temp = [temp (newCenterFreqL1 + newCenterFreqH1)/2 (newCenterFreqL1 - newCenterFreqH1)];
                    else
                        temp = [temp 0 0];
                    end
                    if get(myHandles.cycleNumOnCN, 'Value')
                        temp = [temp prevCycleNum];
                        setappdata(obj.myTopFigure, 'prevCycleNum', cycleNum);
                    else
                        temp = [temp 0];
                    end
                    temp = [temp badData];
                    fprintf(fid, '%8.6f\t', temp);
                    fprintf(fid, '\r\n');
                    
                    
                    if (runNum > 5 && tNorm >= 0.1 && tNorm <= 1.0)
                        set(myHandles.lowStartFrequency1, 'String', num2str(newCenterFreqL1 - linewidth/2));
                        set(myHandles.highStartFrequency1, 'String', num2str(newCenterFreqH1 + linewidth/2));
                    end
                    pointDone = 1;
                    obj.updateDriftPlots(runNum);
            end
            if (getappdata(obj.myTopFigure, 'run')) % Prepare for a new data point
                if runNum == 1
                    setappdata(obj.myTopFigure, 'taxis', taxis);
                end
                runNum = runNum + 1;
                seqPlace = mod(seqPlace + 1,4);
                setappdata(obj.myTopFigure, 'prevFrequency', curFrequency);
                setappdata(obj.myTopFigure, 'normData', tempNormData);
                setappdata(obj.myTopFigure, 'scanData', tempScanData);
                setappdata(obj.myTopFigure, 'summedData', tempSummedData);
                setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
                setappdata(obj.myTopFigure, 'PID2Data', tempPID2Data);
                setappdata(obj.myTopFigure, 'DriftData', tempDriftData);
                setappdata(obj.myTopFigure, 'runNum', runNum);
                setappdata(obj.myTopFigure, 'seqPlace', seqPlace);
                setappdata(obj.myTopFigure, 'prevExcPID1', prevExcPID1);
                setappdata(obj.myTopFigure, 'prevExcPID2', prevExcPID2);
                setappdata(obj.myTopFigure, 'newCenterFreqL1', newCenterFreqL1);
                setappdata(obj.myTopFigure, 'newCenterFreqH1', newCenterFreqH1);
                setappdata(obj.myTopFigure, 'plottingHandles', tempH);
                
                setappdata(obj.myTopFigure, 'rezeroSequenceNumber', rezeroSequenceNumber);
                setappdata(obj.myTopFigure, 'voltageStepSize', voltageStepSize);
                setappdata(obj.myTopFigure, 'zeroingExcAndVoltages', zeroingExcAndVoltages);
                setappdata(obj.myTopFigure, 'rezeroSeqPlace', rezeroSeqPlace);
                setappdata(obj.myTopFigure, 'meanFilterNum', meanFilterNum);
                setappdata(obj.myTopFigure, 'meanVx', meanVx);
                setappdata(obj.myTopFigure, 'meanVy', meanVy);
                setappdata(obj.myTopFigure, 'meanVz', meanVz);
                
                guidata(obj.myTopFigure, myHandles);
               
            else %close everything done
                if get(myHandles.useTSensor, 'Value')
                    try
                        fclose(obj.myTempSensor);
                        delete(obj.myTempSensor);
                    catch err
                    end
                end
                setappdata(obj.myTopFigure, 'readyForData', 0);
                %9.5 Close Frequency Synthesizer and Data file
                obj.mysPID1.clear();
                obj.mysPID2.clear();
                obj.myFreqSynth.close();
                fclose('all'); % weird matlab thing, can't just close fid, won't work.
                %10. If ~Run, make obvious and reset 'run'
                disp('Acquisistion Stopped');
                set(myHandles.curFreq, 'String', 'STOPPED');
                setappdata(obj.myTopFigure, 'run', 1);
                drawnow;
                try
                    rmappdata(obj.myTopFigure, 'normData');
                    rmappdata(obj.myTopFigure, 'scanData');
                    rmappdata(obj.myTopFigure, 'summedData');
                    rmappdata(obj.myTopFigure, 'PID1Data');
                    rmappdata(obj.myTopFigure, 'PID2Data');
                    rmappdata(obj.myTopFigure, 'DriftData');
                    rmappdata(obj.myTopFigure, 'runNum');
                    rmappdata(obj.myTopFigure, 'taxis');
                    rmappdata(obj.myTopFigure, 'fid');
                    rmappdata(obj.myTopFigure, 'seqPlace');
                    rmappdata(obj.myTopFigure, 'prevExcPID1');
                    rmappdata(obj.myTopFigure, 'prevExcPID2');
                    rmappdata(obj.myTopFigure, 'newCenterFreqL1');
                    rmappdata(obj.myTopFigure, 'newCenterFreqH1');
                    rmappdata(obj.myTopFigure, 'prevFrequency');
                    rmappdata(obj.myTopFigure, 'plottingHandles');
                    rmappdata(obj.myTopFigure, 'prevCycleNum');
                    
                    rmappdata(obj.myTopFigure, 'rezeroSequenceNumber');
                    rmappdata(obj.myTopFigure, 'voltageStepSize');
                    rmappdata(obj.myTopFigure, 'zeroingExcAndVoltages');
                    rmappdata(obj.myTopFigure, 'rezeroSeqPlace');
                    rmappdata(obj.myTopFigure, 'meanFilterNum');
                    rmappdata(obj.myTopFigure, 'meanVx');
                    rmappdata(obj.myTopFigure, 'meanVy');
                    rmappdata(obj.myTopFigure, 'meanVz');
                catch exception
                    exception.message
                end
                drawnow;
                
                guidata(obj.myTopFigure, myHandles);
                
                clear variables
                clear mex
            end
        end
        function startContinuousMultiLockAnalog_initialize(obj)
            setappdata(obj.myTopFigure, 'readyForData', 0);
            myHandles = guidata(obj.myTopFigure);
            prevExcL = 0; %For use in calculating the present Error for Low Freq Lock
            prevExcH = 0; %For use in calculating the present Error for Low Freq Lock
            linewidth = str2double(get(myHandles.linewidth, 'String'));
            newCenterFreqL = str2double(get(myHandles.lowStartFrequency1, 'String'))+ linewidth/2;
            newCenterFreqH = str2double(get(myHandles.highStartFrequency1, 'String'))- linewidth/2;
            runNum = 1;
            if get(myHandles.cycleNumOnCN, 'Value')
                runNum = 0;
                obj.myCycleNuControl.initialize();
            end
            seqPlace = 0; %0 = left side of line 1
                          %1 = right side of line 1
                          %2 = left side of line 2
                          %3 = right side of line 2
            
            %AVOID MEMORY MOVEMENT SLOWDOWNS
            tempScanData = zeros(6,FreqLocker.bufferSize);
            tempSummedData = zeros(1,FreqLocker.bufferSize);
            tempNormData = zeros(1,FreqLocker.bufferSize);
            tempPID1Data = zeros(1,FreqLocker.bufferSize);
            tempPID2Data = zeros(1,FreqLocker.bufferSize);
            tempDriftData = NaN(2,FreqLocker.bufferSize);
            obj.myDriftFitHandle = [];
            obj.myDriftPlotHandle = [];
            cla(myHandles.DriftAXES);
            
            

            %2.5 Initialize Frequency Synthesizer
            obj.myFreqSynth.initialize();
            %Start Frequency Loop / Check 'Run'
            set(myHandles.curFreq, 'BackgroundColor', 'green');
            
            if getappdata(obj.myTopFigure, 'run')
                        [path, fileName] = obj.createFileName();
                        try
                            mkdir(path);
                            fid = fopen([path filesep fileName], 'a');
                            fwrite(fid, datestr(now, 'mm/dd/yyyy\tHH:MM AM'));
                            fprintf(fid, '\r\n');
                            colNames = {'Frequency', 'Norm', 'GndState', ...
                                'ExcState', 'Background', 'TStamp', 'BLUEGndState', ...
                                'BLUEBackground', 'BLUEExcState', ...
                                'err1', 'cor1', 'servoVal1', ...
                                'err2', 'cor2', 'servoVal2', ...
                                'err3', 'cor3', 'servoVal3', ...
                                'freqSr', 'cycleNum', 'badData'};
                            
                            if get(myHandles.stepVoltages, 'Value')
                                colNames = [colNames obj.myAnalogStepper.myNames];
                            end
                            n = length(colNames);
                            for i=1:n
                                fprintf(fid, '%s\t', colNames{i});
                            end
                                fprintf(fid, '\r\n');
                        catch
                            disp('Could not open file to write to.');
                        end
            end
            %Set to first frequency point
            curFrequency = newCenterFreqL - linewidth/2;
            ret = obj.myFreqSynth.setFrequency(num2str(curFrequency));
                if ~ret
                    setappdata(obj.myTopFigure, 'run', 0);
                end
            
            setappdata(obj.myTopFigure, 'normData', tempNormData);
            setappdata(obj.myTopFigure, 'scanData', tempScanData);
            setappdata(obj.myTopFigure, 'summedData', tempSummedData);
            setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
            setappdata(obj.myTopFigure, 'PID2Data', tempPID2Data);
            setappdata(obj.myTopFigure, 'DriftData', tempDriftData);
            setappdata(obj.myTopFigure, 'runNum', runNum);
            setappdata(obj.myTopFigure, 'fid', fid);
            setappdata(obj.myTopFigure, 'seqPlace', seqPlace);
            setappdata(obj.myTopFigure, 'prevExcL', prevExcL);
            setappdata(obj.myTopFigure, 'prevExcH', prevExcH);
            setappdata(obj.myTopFigure, 'newCenterFreqL', newCenterFreqL);
            setappdata(obj.myTopFigure, 'newCenterFreqH', newCenterFreqH);
            setappdata(obj.myTopFigure, 'prevFrequency', curFrequency);
            setappdata(obj.myTopFigure, 'nextStep', @obj.startContinuousMultiLockAnalog_takeNextPoint);
            pause(0.5) %I think I need this to make sure we get our first point good
            guidata(obj.myTopFigure, myHandles);
            setappdata(obj.myTopFigure, 'readyForData', 1);
        end
        function startContinuousMultiLockAnalog_takeNextPoint(obj, data)
            myHandles = guidata(obj.myTopFigure);
            tempNormData = getappdata(obj.myTopFigure, 'normData');
            tempScanData = getappdata(obj.myTopFigure, 'scanData');
            tempSummedData = getappdata(obj.myTopFigure, 'summedData');
            tempPID1Data = getappdata(obj.myTopFigure, 'PID1Data');
            tempPID2Data = getappdata(obj.myTopFigure, 'PID2Data');
            tempDriftData = getappdata(obj.myTopFigure, 'DriftData');
            runNum = getappdata(obj.myTopFigure, 'runNum');
            fid = getappdata(obj.myTopFigure, 'fid');
            seqPlace = getappdata(obj.myTopFigure, 'seqPlace');
            prevExcL = getappdata(obj.myTopFigure, 'prevExcL');
            prevExcH = getappdata(obj.myTopFigure, 'prevExcH');
            linewidth = str2double(get(myHandles.linewidth, 'String'));
            newCenterFreqL = getappdata(obj.myTopFigure, 'newCenterFreqL');
            newCenterFreqH = getappdata(obj.myTopFigure, 'newCenterFreqH');
            prevFrequency = getappdata(obj.myTopFigure, 'prevFrequency');
            badData = 0;
            
            if runNum > 1
                tempH = getappdata(obj.myTopFigure, 'plottingHandles');
                taxis = getappdata(obj.myTopFigure, 'taxis');
            end
            
            if get(myHandles.cycleNumOnCN, 'Value')
                cycleNum = str2double(obj.myCycleNuControl.getCycleNum());
                if runNum ~= 0
                    prevCycleNum = getappdata(obj.myTopFigure, 'prevCycleNum');
                end
                seqPlace = mod(cycleNum-2,4); % 1 for previous measurement and 1 for mike bishof's convention
                fprintf(1,['Cycle Number for data just taken : ' num2str(cycleNum-1) '\rTherfore we just took seqPlace: ' num2str(mod(cycleNum-2,4)) '\n']);
                if runNum ~= 0 && prevCycleNum ~= (cycleNum-1)
                    fprintf(1, 'Cycle Slipped\n');
                    badData = 1;
                end
                setappdata(obj.myTopFigure, 'prevCycleNum', cycleNum);
            end
            pointDone = 0;
            while(getappdata(obj.myTopFigure, 'run') && ~pointDone)
                plotstart = 1; %Needs to be out here so plots can be cleared
                %IMMEDIATELY READJUST LC WAVEPLATE and set frequency for
                %next point.
                setappdata(obj.myTopFigure, 'DAQdata', obj.myDataToOutput);
                    switch mod(seqPlace+2,4) %we are in seqPlace+1's blueMOT
                        case 0 % left side of line 1
                            if ~badData
                                obj.myAnalogStepper.incrementCounter();
                            end
                        case 2 % left side of line 2
                            if ~badData
                                obj.myAnalogStepper.incrementCounter();
                            end
                    end
                    [prevSet, curSet, nextSet] = obj.myAnalogStepper.getNextAnalogValues();
                    fprintf(1, ['Analog Voltages for last measurement were: ' num2str(prevSet) '\n\n']);
%                     obj.myDataToOutput = cell2mat(arrayfun(@(x) x*ones(1,500)', nextSet, 'UniformOutput', 0));
                    obj.myDataToOutput = nextSet;
                    switch mod(seqPlace+1,4) %Change Frequencies like normal
                        case 0 % left side of line 1
                            curFrequency = newCenterFreqL - linewidth/2;
                        case 1 % right side of line 1
                            curFrequency = newCenterFreqL + linewidth/2;
                        case 2 % left side of line 2
                            curFrequency = newCenterFreqH - linewidth/2;
                        case 3 % right side of line 2
                            curFrequency = newCenterFreqH + linewidth/2;
                    end  

                ret = obj.myFreqSynth.setFrequency(num2str(curFrequency));
                if ~ret
                    setappdata(obj.myTopFigure, 'run', 0);
                    break;
                end
                set(myHandles.curFreq, 'String', num2str(curFrequency));
                set(myHandles.curFreqL, 'String', num2str(curFrequency));
                
                if runNum == 0
                    runNum = runNum + 1;
                    setappdata(obj.myTopFigure, 'runNum', runNum);
%                     setappdata(obj.myTopFigure, 'DAQcallback_DataRequired', @obj.advanceAnalogValues);
%                     obj.advanceAnalogValues(1,1);
                    return;
                end
                %4. Update Progress Bar
                drawnow;
                %5. Call Gage Card to gather data
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
                    %7. Clear the Raw Plots, Plot the Raw Plots
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
                    tempScanData(1:2, :) = [tempScanData(1:2, 2:end) tSCdat12];
                    tempScanData(3,:) = [tempScanData(3, 2:end) tSCdat3];
                    tempScanData(4:6,:) = [tempScanData(4:6, 2:end) tSCdat456];
                    %NORMALIZED counts are (E - bg)/(E + G - 2bg)
                    tNorm = (tSCdat12(2)) / (tSCdat12(2) + tSCdat12(1));
                    tempNormData = [tempNormData(2:end) tNorm];
                    %SUMMED counts
                    tSum = tSCdat12(2) + tSCdat12(1);
                    tempSummedData = [tempSummedData(2:end) tSum];
                    
                    
                    %Do some PID magic!
                    %Calculate Error for PID1
                    switch seqPlace
                        case {0, 1}
                            calcErr1 = tNorm - prevExcL;
                            tempPID1Data = getappdata(obj.myTopFigure, 'PID1Data');
                        case {2, 3}
                            calcErr2 = tNorm - prevExcH;
                            tempPID2Data = getappdata(obj.myTopFigure, 'PID2Data');
                    end
                    
                    if runNum >= 2 && ~badData
                        switch seqPlace
                            case {0,1}
                                prevExcL = tNorm;
                            case {2, 3}
                                prevExcH = tNorm;
                        end
                        switch seqPlace
                                case 0
                                    obj.mysPID1.setPolarity(-1);
                                    calcErr1 = -1*calcErr1;
                                case 1
                                    obj.mysPID1.setPolarity(1);
                                case 2
                                    obj.mysPID2.setPolarity(-1);
                                    calcErr2 = -1*calcErr2;
                                case 3
                                    obj.mysPID2.setPolarity(1);
                        end
                        obj.updatePIDvalues();
                        obj.checkPIDenables();
                        deltaT1 = str2double(get(obj.myPID1gui.myDeltaT, 'String'));
                        deltaT2 = str2double(get(obj.myPID1gui.myDeltaT, 'String'));
                            switch seqPlace
                                case 0
                                    calcCorr1 = 0;
                                case 1
                                        if deltaT1 == 0
                                            calcCorr1 = obj.mysPID1.calculate(calcErr1, time);
                                        else
                                            calcCorr1 = obj.mysPID1.calculate(calcErr1, -deltaT1);
                                        end
                                            newCenterFreqL = newCenterFreqL + calcCorr1;
                                case 2
                                    calcCorr2 = 0;
                                case 3
                                        if deltaT2 == 0
                                            calcCorr2 = obj.mysPID2.calculate(calcErr2, time);
                                        else
                                            calcCorr2 = obj.mysPID2.calculate(calcErr2, -deltaT2);
                                        end
                                            newCenterFreqH = newCenterFreqH + calcCorr2;
                            end
                    end
                    
                        switch seqPlace
                            case 1
                                tempPID1Data = [tempPID1Data(2:end) calcErr1];
                                tempDriftData(1, :) = [tempDriftData(1, 2:end) newCenterFreqL];
                                tempDriftData(2, :) = [tempDriftData(2, 2:end) ((time- obj.refTime)/1000)];
                            case 3
                                tempPID2Data = [tempPID2Data(2:end) calcErr2];
                        end
                    
                    %Do some Plotting
                    firstplot = 1;
                    if get(myHandles.ignoreFirstToggle, 'Value') && plotstart < 3
                        plotstart = 2;
                        firstplot = 2;
                    end
                    if runNum == 1
                        tempH(1) = plot(myHandles.sNormAxes, tempNormData(end-FreqLocker.plotSize:end), 'ok', 'LineWidth', 3);
                        tempH(2) = plot(myHandles.sEAxes, tempScanData(2,end-FreqLocker.plotSize:end), 'or', 'LineWidth', 2);
                        tempH(3) = plot(myHandles.sGAxes, tempScanData(1,end-FreqLocker.plotSize:end), 'ob', 'LineWidth', 2);
                        tempH(4) = plot(myHandles.sBGAxes, tempScanData(3,end-FreqLocker.plotSize:end), 'ob', 'LineWidth', 1);
                        tempH(5) = plot(myHandles.sSummedAxes, tempSummedData(end-FreqLocker.plotSize:end), 'og', 'LineWidth', 2);
                        tempH(6) = plot(myHandles.errPlot, tempPID1Data(end-FreqLocker.plotSize:end), 'ok', 'LineWidth', 2);
                    elseif runNum > 1
                        set(tempH(1), 'YData', tempNormData(end-FreqLocker.plotSize:end));
                        set(tempH(2), 'YData', tempScanData(2,end-FreqLocker.plotSize:end));
                        set(tempH(3), 'YData', tempScanData(1,end-FreqLocker.plotSize:end));
                        set(tempH(4), 'YData', tempScanData(3,end-FreqLocker.plotSize:end));
                        set(tempH(5), 'YData', tempSummedData(end-FreqLocker.plotSize:end));
                        set(tempH(6), 'YData', tempPID1Data(end-FreqLocker.plotSize:end));
                    end
                    switch seqPlace
                        case {0,1}
                            obj.myPID1gui.updateMyPlots(calcErr1, runNum, FreqLocker.plotSize);
                        case {2,3}
                            obj.myPID2gui.updateMyPlots(calcErr2, runNum, FreqLocker.plotSize);
                    end
                    switch mod(seqPlace+1,4)
                        case 0
                            set(myHandles.lockStatus, 'String', 'Low_L');
                        case 1
                            set(myHandles.lockStatus, 'String', 'Low_R');
                        case 2
                            set(myHandles.lockStatus, 'String', 'High_L');
                        case 3
                            set(myHandles.lockStatus, 'String', 'High_R');
                    end
                    %9. Check Save and Write Data to file.
% 'Frequency', 'Norm', 'GndState', 'ExcState', 'Background', 'TStamp', 'BLUEGndState', 'BLUEBackground', 'BLUEExcState'
                    temp = [prevFrequency tNorm tSCdat12(1) tSCdat12(2) tSCdat3 time tSCdat456(1) tSCdat456(3) tSCdat456(2)];
                    
                        if runNum >= 2 && seqPlace == 1 && ~badData
                            tempPID1 = [calcErr1 calcCorr1 newCenterFreqL];%err correctionApplied servoVal
                        else
                            tempPID1 = [0 0 0];%err correctionApplied servoVal
                        end

                        if runNum >= 2 && seqPlace == 3 && ~badData
                            tempPID2 = [calcErr2 calcCorr2 newCenterFreqH];%err correctionApplied servoVal
                        else
                            tempPID2 = [0 0 0];
                        end
                    tempPID3 = [0 0 0];
                    temp = [temp tempPID1 tempPID2 tempPID3];
                    if get(myHandles.calcSrFreq, 'Value') && runNum >= 4
                        temp = [temp (newCenterFreqL + newCenterFreqH)/2];
                    else
                        temp = [temp 0];
                    end
                    if get(myHandles.cycleNumOnCN, 'Value')
                        temp = [temp prevCycleNum];
                        setappdata(obj.myTopFigure, 'prevCycleNum', cycleNum);
                    else
                        temp = [temp 0];
                    end
                    temp = [temp badData];
                    if get(myHandles.stepVoltages, 'Value')
                        temp = [temp prevSet];
                    end
                    fprintf(fid, '%8.6f\t', temp);
                    fprintf(fid, '\r\n');
                    
                    
                    if (runNum > 5 && tNorm >= 0.1)
                        set(myHandles.lowStartFrequency1, 'String', num2str(newCenterFreqL - linewidth/2));
                        set(myHandles.highStartFrequency1, 'String', num2str(newCenterFreqH + linewidth/2));
                    end
                    pointDone = 1;
                    obj.updateDriftPlots(runNum);
            end
            if (getappdata(obj.myTopFigure, 'run')) % Prepare for a new data point
                if runNum == 1
                    setappdata(obj.myTopFigure, 'taxis', taxis);
                end
                runNum = runNum + 1;
                seqPlace = mod(seqPlace + 1,4);
                setappdata(obj.myTopFigure, 'prevFrequency', curFrequency);
                setappdata(obj.myTopFigure, 'normData', tempNormData);
                setappdata(obj.myTopFigure, 'scanData', tempScanData);
                setappdata(obj.myTopFigure, 'summedData', tempSummedData);
                setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
                setappdata(obj.myTopFigure, 'PID2Data', tempPID2Data);
                setappdata(obj.myTopFigure, 'DriftData', tempDriftData);
                setappdata(obj.myTopFigure, 'runNum', runNum);
                setappdata(obj.myTopFigure, 'seqPlace', seqPlace);
                setappdata(obj.myTopFigure, 'prevExcL', prevExcL);
                setappdata(obj.myTopFigure, 'prevExcH', prevExcH);
                setappdata(obj.myTopFigure, 'newCenterFreqL', newCenterFreqL);
                setappdata(obj.myTopFigure, 'newCenterFreqH', newCenterFreqH);
                setappdata(obj.myTopFigure, 'plottingHandles', tempH);
                
                guidata(obj.myTopFigure, myHandles);
               
            else %close everything done
                setappdata(obj.myTopFigure, 'DAQcallback_DataRequired', @(src, event) eval('return'));
                setappdata(obj.myTopFigure, 'readyForData', 0);
                %9.5 Close Frequency Synthesizer and Data file
                obj.mysPID1.clear();
                obj.mysPID2.clear();
                obj.myFreqSynth.close();
                fclose('all'); % weird matlab thing, can't just close fid, won't work.
                %10. If ~Run, make obvious and reset 'run'
                disp('Acquisistion Stopped');
                set(myHandles.curFreq, 'String', 'STOPPED');
                setappdata(obj.myTopFigure, 'run', 1);
                drawnow;
                try
                    rmappdata(obj.myTopFigure, 'normData');
                    rmappdata(obj.myTopFigure, 'scanData');
                    rmappdata(obj.myTopFigure, 'summedData');
                    rmappdata(obj.myTopFigure, 'PID1Data');
                    rmappdata(obj.myTopFigure, 'PID2Data');
                    rmappdata(obj.myTopFigure, 'DriftData');
                    rmappdata(obj.myTopFigure, 'runNum');
                    rmappdata(obj.myTopFigure, 'taxis');
                    rmappdata(obj.myTopFigure, 'fid');
                    rmappdata(obj.myTopFigure, 'seqPlace');
                    rmappdata(obj.myTopFigure, 'prevExcL');
                    rmappdata(obj.myTopFigure, 'prevExcH');
                    rmappdata(obj.myTopFigure, 'newCenterFreqL');
                    rmappdata(obj.myTopFigure, 'newCenterFreqH');
                    rmappdata(obj.myTopFigure, 'prevFrequency');
                    rmappdata(obj.myTopFigure, 'plottingHandles');
                    rmappdata(obj.myTopFigure, 'prevCycleNum');
                catch exception
                    exception.message
                end
                drawnow;
                
                guidata(obj.myTopFigure, myHandles);
                
                clear variables
                clear mex
            end
        end
        function [ newVoltage ] = findBestVoltage(obj, zeroingExcAndVoltages)
            %FINDBESTVOLTAGE Summary of this function goes here
            %   Fitting a parabola to the data to pull out the best Voltage
            %   Note: If I fit PeakExc = -b*(V-V0)^2 + c to pull out V0....
            %   PeakExc = -b*V^2 + 2*b*V0*V - b*V0^2 + c with....
            %   PeakExc = a2*V^2 + a1*V + a0
            %   Then, V0 = a1/(-2*a2)
            [p, S] = polyfit(zeroingExcAndVoltages(:,2), zeroingExcAndVoltages(:,1), 2);
            newVoltage = p(2)/(-2*p(1));
            %     x = (0: 0.1: 5)';
            %     f = polyval(p,x);
            %     plot(zeroingExcAndVoltages(:,2),zeroingExcAndVoltages(:,1),'o',x,f,'-')
        end
        function advanceAnalogValues(obj, ~,~)
            obj.myAnalogStepper.myDAQSession.queueOutputData(obj.myDataToOutput);
            obj.myDataToOutput(1)
            %obj.myAnalogStepper.myDAQSession.startBackground();
        end
        function changeAnalogVoltage(obj, chNum, newVoltage)
            myHandles = guidata(obj.myTopFigure);
            set(myHandles.(['dev1a' int2str(chNum)]), 'String', num2str(newVoltage, '%5.4f'));
            obj.myAnalogCC.outputCurrentVoltages_Callback();   
        end
        function volts = readAnalogVoltages(obj)
            myHandles = guidata(obj.myTopFigure);
            volts(1) = str2double(get(myHandles.(['dev1a' int2str(0)]), 'String'));
            volts(2) = str2double(get(myHandles.(['dev1a' int2str(1)]), 'String'));
            volts(3) = str2double(get(myHandles.(['dev1a' int2str(2)]), 'String'));
        end
        function [Vfixed, Cfixed, Vbellows, Cbellows] = readTemps(obj)
            fprintf(obj.myTempSensor, 'CRDG? 1');
            temps = fread(obj.myTempSensor);
            Cfixed = str2double(char(temps'));
            fprintf(obj.myTempSensor, 'LRDG? 1');
            temps = fread(obj.myTempSensor);
            Vfixed = str2double(char(temps'))/100;

            fprintf(obj.myTempSensor, 'CRDG? 5');
            temps = fread(obj.myTempSensor);
            Cbellows = str2double(char(temps'));
            fprintf(obj.myTempSensor, 'LRDG? 5');
            temps = fread(obj.myTempSensor);
            Vbellows = str2double(char(temps'))/100;
        end
        function updatePIDvalues(obj)
            obj.mysPID1.myPIDs{1}.myKp = str2double(get(obj.myPID1gui.myKp, 'String'));
            obj.mysPID1.myPIDs{1}.myTi = str2double(get(obj.myPID1gui.myTi, 'String'));
            obj.mysPID1.myPIDs{1}.myTd = str2double(get(obj.myPID1gui.myTd, 'String'));
            obj.mysPID1.myPIDs{2}.myKp = str2double(get(obj.myPID1gui.myKp2, 'String'));
            obj.mysPID1.myPIDs{2}.myTi = str2double(get(obj.myPID1gui.myTi2, 'String'));
            obj.mysPID1.myPIDs{2}.myTd = str2double(get(obj.myPID1gui.myTd2, 'String'));
            
            obj.mysPID2.myPIDs{1}.myKp = str2double(get(obj.myPID2gui.myKp, 'String'));
            obj.mysPID2.myPIDs{1}.myTi = str2double(get(obj.myPID2gui.myTi, 'String'));
            obj.mysPID2.myPIDs{1}.myTd = str2double(get(obj.myPID2gui.myTd, 'String'));
            obj.mysPID2.myPIDs{2}.myKp = str2double(get(obj.myPID2gui.myKp2, 'String'));
            obj.mysPID2.myPIDs{2}.myTi = str2double(get(obj.myPID2gui.myTi2, 'String'));
            obj.mysPID2.myPIDs{2}.myTd = str2double(get(obj.myPID2gui.myTd2, 'String'));
            
            obj.mysPID3.myPIDs{1}.myKp = str2double(get(obj.myPID3gui.myKp, 'String'));
            obj.mysPID3.myPIDs{1}.myTi = str2double(get(obj.myPID3gui.myTi, 'String'));
            obj.mysPID3.myPIDs{1}.myTd = str2double(get(obj.myPID3gui.myTd, 'String'));
            obj.mysPID3.myPIDs{2}.myKp = str2double(get(obj.myPID3gui.myKp2, 'String'));
            obj.mysPID3.myPIDs{2}.myTi = str2double(get(obj.myPID3gui.myTi2, 'String'));
            obj.mysPID3.myPIDs{2}.myTd = str2double(get(obj.myPID3gui.myTd2, 'String'));
            
            obj.mysPID4.myPIDs{1}.myKp = str2double(get(obj.myPID4gui.myKp, 'String'));
            obj.mysPID4.myPIDs{1}.myTi = str2double(get(obj.myPID4gui.myTi, 'String'));
            obj.mysPID4.myPIDs{1}.myTd = str2double(get(obj.myPID4gui.myTd, 'String'));
            obj.mysPID4.myPIDs{2}.myKp = str2double(get(obj.myPID4gui.myKp2, 'String'));
            obj.mysPID4.myPIDs{2}.myTi = str2double(get(obj.myPID4gui.myTi2, 'String'));
            obj.mysPID4.myPIDs{2}.myTd = str2double(get(obj.myPID4gui.myTd2, 'String'));
            
        end
        function checkPIDenables(obj)
            if ~get(obj.myPID1gui.myEnableBox, 'Value')
                obj.mysPID1.reset();
            end
            if ~get(obj.myPID2gui.myEnableBox, 'Value')
                obj.mysPID2.reset();
            end
            if ~get(obj.myPID3gui.myEnableBox, 'Value')
                obj.mysPID3.reset();
            end
            if ~get(obj.myPID4gui.myEnableBox, 'Value')
                obj.mysPID4.reset();
            end
                
        end
        function updateDriftPlots(obj, runNum)
            myHandles = guidata(obj.myTopFigure);
            tempDriftData = getappdata(obj.myTopFigure, 'DriftData');
            if isempty(obj.myDriftPlotHandle)
                obj.myDriftPlotHandle = plot(myHandles.DriftAXES, tempDriftData(2,:), tempDriftData(1,:),'ok', 'LineWidth', 3); 
                set(myHandles.DriftAXES, 'NextPlot', 'add');
            else
                set(obj.myDriftPlotHandle, 'YData', tempDriftData(1,:));
                set(obj.myDriftPlotHandle, 'XData', tempDriftData(2,:));
                refreshdata(obj.myDriftPlotHandle);
                drawnow;
                
                if(runNum >= 20)
                    criteria = ~isnan(tempDriftData(1,:));
                    xFull = tempDriftData(2,criteria);
                    yFull = tempDriftData(1,criteria);
                    if (length(xFull) > 15)
                        x = xFull(end-15:end);
                        y = yFull(end-15:end);
                    else
                        x = xFull;
                        y = yFull;
                    end
                    p = polyfit(x, y,1);
                    f = polyval(p,x);
                    if isempty(obj.myDriftFitHandle)
                        obj.myDriftFitHandle = plot(myHandles.DriftAXES, x, f);
                    else
                        set(obj.myDriftFitHandle, 'YData', f);
                        set(obj.myDriftFitHandle, 'XData', x);
                        title(myHandles.DriftAXES, ['Residual Drift is ' num2str(p(1)*1000, 3) ' mHz/s']);
                    end
                end
            end
            guidata(obj.myTopFigure, myHandles);
        end
        function [path, fileName] = createFileName(obj)
            myHandles = guidata(obj.myTopFigure);
%             basePath = get(myHandles.saveDirPID1, 'String');
            basePath = 'Z:\Sr3\data';
            folderPath = [datestr(now, 'yymmdd') filesep 'Lock'];
            curTime = datestr(now, 'HHMMSS');
            fileName = ['Lock_' curTime '.txt'];
            path = [basePath filesep folderPath];
        end
        function scanData = analyzeRawData(obj, data)
            scanData = cellfun(@sum, data);
        end
        function scanData = analyzeRawDataBLUE(obj, data)
            scanData = cellfun(@mean, data);
        end
        function quit(obj)
            obj.myTopFigure = [];
            obj.myFreqSynth = [];
            obj.myGageConfigFrontend = [];
            obj.myFreqSweeper = [];
            obj.mysPID1 = [];
            obj.myPID1gui = [];
            obj.mysPID2 = [];
            obj.myPID2gui = [];
            obj.mysPID3 = [];
            obj.myPID3gui = [];
            obj.mysPID4 = [];
            obj.myPID4gui = [];
            delete(obj.myPanel);
        end
        function saveState(obj)
            FreqLockerState.PID1myKp = get(obj.myPID1gui.myKp, 'String');
            FreqLockerState.PID1myTi = get(obj.myPID1gui.myTi, 'String');
            FreqLockerState.PID1myTd = get(obj.myPID1gui.myTd, 'String');
            FreqLockerState.PID1myDeltaT = get(obj.myPID1gui.myDeltaT, 'String');
            
            FreqLockerState.PID2myKp = get(obj.myPID2gui.myKp, 'String');
            FreqLockerState.PID2myTi = get(obj.myPID2gui.myTi, 'String');
            FreqLockerState.PID2myTd = get(obj.myPID2gui.myTd, 'String');
            FreqLockerState.PID2myDeltaT = get(obj.myPID2gui.myDeltaT, 'String');
            
            FreqLockerState.PID3myKp = get(obj.myPID3gui.myKp, 'String');
            FreqLockerState.PID3myTi = get(obj.myPID3gui.myTi, 'String');
            FreqLockerState.PID3myTd = get(obj.myPID3gui.myTd, 'String');
            FreqLockerState.PID3myDeltaT = get(obj.myPID3gui.myDeltaT, 'String');
            
            FreqLockerState.PID4myKp = get(obj.myPID4gui.myKp, 'String');
            FreqLockerState.PID4myTi = get(obj.myPID4gui.myTi, 'String');
            FreqLockerState.PID4myTd = get(obj.myPID4gui.myTd, 'String');
            FreqLockerState.PID4myDeltaT = get(obj.myPID4gui.myDeltaT, 'String');
            save FreqLockerState;
        end
        function loadState(obj)
             try
                load FreqLockerState
                myHandles = guidata(obj.myTopFigure);
                
                set(obj.myPID1gui.myKp, 'String', FreqLockerState.PID1myKp);
                set(obj.myPID1gui.myTi, 'String', FreqLockerState.PID1myTi);
                set(obj.myPID1gui.myTd, 'String', FreqLockerState.PID1myTd);
                set(obj.myPID1gui.myDeltaT, 'String', FreqLockerState.PID1myDeltaT);
                disp('1')

                set(obj.myPID2gui.myKp, 'String', FreqLockerState.PID2myKp);
                set(obj.myPID2gui.myTi, 'String', FreqLockerState.PID2myTi);
                set(obj.myPID2gui.myTd, 'String', FreqLockerState.PID2myTd);
                set(obj.myPID2gui.myDeltaT, 'String', FreqLockerState.PID2myDeltaT);

                set(obj.myPID3gui.myKp, 'String', FreqLockerState.PID3myKp);
                set(obj.myPID3gui.myTi, 'String', FreqLockerState.PID3myTi);
                set(obj.myPID3gui.myTd, 'String', FreqLockerState.PID3myTd);
                set(obj.myPID3gui.myDeltaT, 'String', FreqLockerState.PID3myDeltaT);
                
                set(obj.myPID4gui.myKp, 'String', FreqLockerState.PID4myKp);
                set(obj.myPID4gui.myTi, 'String', FreqLockerState.PID4myTi);
                set(obj.myPID4gui.myTd, 'String', FreqLockerState.PID4myTd);
                set(obj.myPID4gui.myDeltaT, 'String', FreqLockerState.PID4myDeltaT);
                guidata(obj.myTopFigure, myHandles);
            catch
                disp('No saved state for FreqLocker Exists');
            end
        end

    end
    
end

