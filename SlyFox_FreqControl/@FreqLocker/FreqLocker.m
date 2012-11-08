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
    end
    
    properties (Constant)
        bufferSize = 256;
        plotSize = 40;
    end
    
    methods
        function obj = FreqLocker(top,f)
            obj.myTopFigure = top;
            obj.myPanel.Parent = f;
            import PID.*
            
            obj.myPID1gui = PID.PID_gui(top, obj.myPanel, '1');
            obj.mysPID1 = seriesPID({obj.myPID1gui.myPID, obj.myPID1gui.myPID2});
            obj.myPID2gui = PID.PID_gui(top, obj.myPanel, '2');
            obj.mysPID2 = seriesPID({obj.myPID2gui.myPID, obj.myPID2gui.myPID2});
            obj.myPID3gui = PID.PID_gui(top, obj.myPanel, '3');
            obj.mysPID3 = seriesPID({obj.myPID3gui.myPID, obj.myPID3gui.myPID2});
            obj.myPID4gui = PID.PID_gui(top, obj.myPanel, '4');
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
                        uicontrol(...
                            'Parent', multiPeakP, ...
                            'Style', 'popup', ...
                            'Tag', 'multiplePeakLockOptions', ...
                            'String', 'Continuous Stretched States Lock | Interleaved 2-Shot (DIO) Lock | Analog Stepper | 4 PID Lock');
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
                    obj.myLockModes.SelectedChild = 1;
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
                                'String', '10', ...
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
                                'String', '10', ...
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
                    axes('Tag', 'servoVal1AXES', 'Parent', p1, 'ActivePositionProperty', 'OuterPosition');
                p2 = uiextras.Panel('Parent', lockOutput);
                    axes('Tag', 'normExcAXES', 'Parent', p2, 'ActivePositionProperty', 'OuterPosition');
                    lockOutput.TabNames = {'SVal1', 'Normalized Exc'};
                    lockOutput.SelectedChild = 1;
            emptyBox = uiextras.Empty('Parent', obj.myPanel);
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
                        case 4 % STEP 4 PEAK LOCK
                            obj.start4PeakLock_initialize()
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
                   switch mod(seqPlace+1,4) 
                        case 0 % left side of line 1
                            curFrequency = newCenterFreqL - linewidth/2;
                        case 1 % right side of line 1
                            curFrequency = newCenterFreqL + linewidth/2;
                        case 2 % left side of line 2
                            curFrequency = newCenterFreqH - linewidth/2;
                        case 3 % right side of line 2
                            curFrequency = newCenterFreqH + linewidth/2;
                    end
                if get(myHandles.bounceLCwaveplate, 'Value') && strcmp(get(myHandles.openSerialLC, 'Enable'), 'off')
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
                                'freqSr1', 'freqSr2', 'cycleNum', 'badData'};
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
                            case 3
                                tempPID2Data = [tempPID2Data(2:end) calcErr2];
                            case 5
                                tempPID3Data = [tempPID3Data(2:end) calcErr3];
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
                        temp = [temp (newCenterFreqL1 + newCenterFreqH1)/2 (newCenterFreqL2 + newCenterFreqH2)/2];
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
                        set(myHandles.lowStartFrequency2, 'String', num2str(newCenterFreqL2 - linewidth2/2));
                        set(myHandles.highStartFrequency2, 'String', num2str(newCenterFreqH2 + linewidth2/2));
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
                setappdata(obj.myTopFigure, 'PID3Data', tempPID3Data);
                setappdata(obj.myTopFigure, 'PID4Data', tempPID4Data);
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
        function advanceAnalogValues(obj, ~,~)
            obj.myAnalogStepper.myDAQSession.queueOutputData(obj.myDataToOutput);
            obj.myDataToOutput(1)
            %obj.myAnalogStepper.myDAQSession.startBackground();
        end
        function updatePIDvalues(obj)
            obj.mysPID1.myPIDs{1}.myKp = str2double(get(obj.myPID1gui.myKp, 'String'));
            obj.mysPID1.myPIDs{1}.myKi = str2double(get(obj.myPID1gui.myKi, 'String'));
            obj.mysPID1.myPIDs{1}.myKd = str2double(get(obj.myPID1gui.myKd, 'String'));
            obj.mysPID1.myPIDs{2}.myKp = str2double(get(obj.myPID1gui.myKp2, 'String'));
            obj.mysPID1.myPIDs{2}.myKi = str2double(get(obj.myPID1gui.myKi2, 'String'));
            obj.mysPID1.myPIDs{2}.myKd = str2double(get(obj.myPID1gui.myKd2, 'String'));
            
            obj.mysPID2.myPIDs{1}.myKp = str2double(get(obj.myPID2gui.myKp, 'String'));
            obj.mysPID2.myPIDs{1}.myKi = str2double(get(obj.myPID2gui.myKi, 'String'));
            obj.mysPID2.myPIDs{1}.myKd = str2double(get(obj.myPID2gui.myKd, 'String'));
            obj.mysPID2.myPIDs{2}.myKp = str2double(get(obj.myPID2gui.myKp2, 'String'));
            obj.mysPID2.myPIDs{2}.myKi = str2double(get(obj.myPID2gui.myKi2, 'String'));
            obj.mysPID2.myPIDs{2}.myKd = str2double(get(obj.myPID2gui.myKd2, 'String'));
            
            obj.mysPID3.myPIDs{1}.myKp = str2double(get(obj.myPID3gui.myKp, 'String'));
            obj.mysPID3.myPIDs{1}.myKi = str2double(get(obj.myPID3gui.myKi, 'String'));
            obj.mysPID3.myPIDs{1}.myKd = str2double(get(obj.myPID3gui.myKd, 'String'));
            obj.mysPID3.myPIDs{2}.myKp = str2double(get(obj.myPID3gui.myKp2, 'String'));
            obj.mysPID3.myPIDs{2}.myKi = str2double(get(obj.myPID3gui.myKi2, 'String'));
            obj.mysPID3.myPIDs{2}.myKd = str2double(get(obj.myPID3gui.myKd2, 'String'));
            
            obj.mysPID4.myPIDs{1}.myKp = str2double(get(obj.myPID4gui.myKp, 'String'));
            obj.mysPID4.myPIDs{1}.myKi = str2double(get(obj.myPID4gui.myKi, 'String'));
            obj.mysPID4.myPIDs{1}.myKd = str2double(get(obj.myPID4gui.myKd, 'String'));
            obj.mysPID4.myPIDs{2}.myKp = str2double(get(obj.myPID4gui.myKp2, 'String'));
            obj.mysPID4.myPIDs{2}.myKi = str2double(get(obj.myPID4gui.myKi2, 'String'));
            obj.mysPID4.myPIDs{2}.myKd = str2double(get(obj.myPID4gui.myKd2, 'String'));
            
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
            FreqLockerState.PID1myKi = get(obj.myPID1gui.myKi, 'String');
            FreqLockerState.PID1myKd = get(obj.myPID1gui.myKd, 'String');
            FreqLockerState.PID1myDeltaT = get(obj.myPID1gui.myDeltaT, 'String');
            
            FreqLockerState.PID2myKp = get(obj.myPID2gui.myKp, 'String');
            FreqLockerState.PID2myKi = get(obj.myPID2gui.myKi, 'String');
            FreqLockerState.PID2myKd = get(obj.myPID2gui.myKd, 'String');
            FreqLockerState.PID2myDeltaT = get(obj.myPID2gui.myDeltaT, 'String');
            
            FreqLockerState.PID3myKp = get(obj.myPID3gui.myKp, 'String');
            FreqLockerState.PID3myKi = get(obj.myPID3gui.myKi, 'String');
            FreqLockerState.PID3myKd = get(obj.myPID3gui.myKd, 'String');
            FreqLockerState.PID3myDeltaT = get(obj.myPID3gui.myDeltaT, 'String');
            
            FreqLockerState.PID4myKp = get(obj.myPID4gui.myKp, 'String');
            FreqLockerState.PID4myKi = get(obj.myPID4gui.myKi, 'String');
            FreqLockerState.PID4myKd = get(obj.myPID4gui.myKd, 'String');
            FreqLockerState.PID4myDeltaT = get(obj.myPID4gui.myDeltaT, 'String');
            save FreqLockerState;
        end
        function loadState(obj)
             try
                load FreqLockerState
                myHandles = guidata(obj.myTopFigure);
                
                set(obj.myPID1gui.myKp, 'String', FreqLockerState.PID1myKp);
                set(obj.myPID1gui.myKi, 'String', FreqLockerState.PID1myKi);
                set(obj.myPID1gui.myKd, 'String', FreqLockerState.PID1myKd);
                set(obj.myPID1gui.myDeltaT, 'String', FreqLockerState.PID1myDeltaT);
                disp('1')

                set(obj.myPID2gui.myKp, 'String', FreqLockerState.PID2myKp);
                set(obj.myPID2gui.myKi, 'String', FreqLockerState.PID2myKi);
                set(obj.myPID2gui.myKd, 'String', FreqLockerState.PID2myKd);
                set(obj.myPID2gui.myDeltaT, 'String', FreqLockerState.PID2myDeltaT);

                set(obj.myPID3gui.myKp, 'String', FreqLockerState.PID3myKp);
                set(obj.myPID3gui.myKi, 'String', FreqLockerState.PID3myKi);
                set(obj.myPID3gui.myKd, 'String', FreqLockerState.PID3myKd);
                set(obj.myPID3gui.myDeltaT, 'String', FreqLockerState.PID3myDeltaT);
                
                set(obj.myPID4gui.myKp, 'String', FreqLockerState.PID4myKp);
                set(obj.myPID4gui.myKi, 'String', FreqLockerState.PID4myKi);
                set(obj.myPID4gui.myKd, 'String', FreqLockerState.PID4myKd);
                set(obj.myPID4gui.myDeltaT, 'String', FreqLockerState.PID4myDeltaT);
                guidata(obj.myTopFigure, myHandles);
            catch
                disp('No saved state for FreqLocker Exists');
            end
        end

    end
    
end

