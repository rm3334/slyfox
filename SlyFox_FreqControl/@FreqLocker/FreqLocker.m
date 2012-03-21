classdef FreqLocker < hgsetget
    %FREQLOCKER Rabi Spectroscopy locking program
    %   This program is intended to be used in conjunction with the
    %   freqsweeper program and is meant to be used to lock to Rabi
    %   lineshapes for use in atomic clock experiments, or to carefully
    %   cancel drifts between shots. This program should have a few
    %   different modes once it is done. Single-peak locking, Stretched
    %   State locking, and intermittent locking mode for canceling drifts
    %   between experiments. Written by Ben Bloom. Last Updated 03/09/12
    
    properties
        myPanel = uiextras.Grid();
        myTopFigure = [];
        myFreqSynth = [];
        myGageConfigFrontend = [];
        myFreqSweeper = [];
        myLCuControl = [];
        myCycleNuControl = [];
        myLockModes = [];
        myPID1 = [];
        myPID1gui = [];
        myPID2 = [];
        myPID2gui = [];
        myPID3 = [];
        myPID3gui = [];
    end
    
    methods
        function obj = FreqLocker(top,f)
            obj.myTopFigure = top;
            obj.myPanel.Parent = f;
            import PID.*
            
            obj.myPID1gui = PID.PID_gui(top, obj.myPanel, '1');
            obj.myPID1 = obj.myPID1gui.myPID;
            obj.myPID2gui = PID.PID_gui(top, obj.myPanel, '2');
            obj.myPID2 = obj.myPID2gui.myPID;
            obj.myPID3gui = PID.PID_gui(top, obj.myPanel, '3');
            obj.myPID3 = obj.myPID3gui.myPID;
            
            lockOptPanel = uiextras.Panel('Parent', obj.myPanel, ...
                'Title', 'Locking Options');
                obj.myLockModes = uiextras.TabPanel('Parent', lockOptPanel, ...
                    'Tag', 'lockModes');
                    singlePeakP = uiextras.Panel('Parent', obj.myLockModes);
                        uicontrol(...
                            'Parent', singlePeakP, ...
                            'Style', 'popup', ...
                            'Tag', 'singlePeakLockOptions', ...
                            'String', 'Continuous Lock | Intermittent Lock');
                    multiPeakP = uiextras.HBox('Parent', obj.myLockModes);
                        uicontrol(...
                            'Parent', multiPeakP, ...
                            'Style', 'popup', ...
                            'Tag', 'multiplePeakLockOptions', ...
                            'String', 'Continuous Strectched States Lock | Interleaved 2-Shot (DIO) Lock | Intermittent Lock');
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
                        lowFreqVBL = uiextras.VBox(...
                            'Parent', freqParamHBL, ...
                            'Spacing', 5, ...
                            'Padding', 5);
                            uiextras.Empty('Parent', lowFreqVBL);
                            uicontrol(...
                                'Parent', lowFreqVBL, ...
                                'Style', 'text', ...
                                'String', 'Low Frequency', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.6);
                            uicontrol(...
                                'Parent', lowFreqVBL, ...
                                'Style', 'edit', ...
                                'Tag', 'lowStartFrequency', ...
                                'String', '24000000', ...
                                'FontWeight', 'normal', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.6); 
                            uiextras.Empty('Parent', lowFreqVBL);
                                
                        widthFreqVBL = uiextras.VBox(...
                            'Parent', freqParamHBL, ...
                            'Spacing', 5, ...
                            'Padding', 5);
                            uicontrol(...
                                'Parent', widthFreqVBL, ...
                                'Style', 'text', ...
                                'String', 'Current Frequency', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.7);
                            uicontrol(...
                                'Parent', widthFreqVBL, ...
                                'Style', 'text', ...
                                'Tag', 'curFreqL', ...
                                'String', 'curFreq', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.7);
                            uiextras.Empty('Parent', widthFreqVBL);
                            uicontrol(...
                                'Parent', widthFreqVBL, ...
                                'Style', 'text', ...
                                'String', 'Linewidth (FWHM)', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.7);
                            uicontrol(...
                                'Parent', widthFreqVBL, ...
                                'Style', 'edit', ...
                                'Tag', 'linewidth', ...
                                'String', '10', ...
                                'FontWeight', 'normal', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.7); 
                        highFreqVBL = uiextras.VBox(...
                            'Parent', freqParamHBL, ...
                            'Spacing', 5, ...
                            'Padding', 5);
                            uiextras.Empty('Parent', highFreqVBL);
                            uicontrol(...
                                'Parent', highFreqVBL, ...
                                'Style', 'text', ...
                                'String', 'High Frequency', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.6);
                            uicontrol(...
                                'Parent', highFreqVBL, ...
                                'Style', 'edit', ...
                                'Tag', 'highStartFrequency', ...
                                'String', '24000010', ...
                                'FontWeight', 'normal', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.6); 
                            uiextras.Empty('Parent', highFreqVBL);
                       controlBox = uiextras.HButtonBox('Parent', lockControl);
                            uicontrol(...
                                'Parent', controlBox, ...
                                'Style', 'pushbutton', ...
                                'Callback', @obj.grabFromSweeper_Callback, ...
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
            lockOutput = uiextras.Panel('Parent', obj.myPanel, ...
                'Title', 'Locking Output');
            set(obj.myPanel, 'ColumnSizes', [-1 -1], 'RowSizes', [-1 -1 -1]);
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
        function grabFromSweeper_Callback(obj, src, eventData)
            myHandles = guidata(obj.myTopFigure);
            lowF = get(myHandles.c1Freq, 'String');
            highF = get(myHandles.c2Freq, 'String');
            set(myHandles.highStartFrequency, 'String', highF);
            set(myHandles.lowStartFrequency, 'String', lowF);
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
                    end
                case 2 % Multiple PID
                    tempVal = get(myHandles.multiplePeakLockOptions, 'Value');
                    switch tempVal
                        case 1 %MULTIPLE STRETCHED STATES CONTINUOUS LOCK
                            obj.startContinuousMultiLock_initialize();
                        case 2 % INTERLEAVED 2-SHOT (DIO) LOCK
                            obj.startInterleaved2ShotLock_initialize();
                    end
            end
        end
        
        function startContinuousLock_initialize(obj)
            setappdata(obj.myTopFigure, 'readyForData', 0);
            myHandles = guidata(obj.myTopFigure);
            prevExc = 0; %For use in calculating the present Error
            linewidth = str2double(get(myHandles.linewidth, 'String'));
            newCenterFreq = str2double(get(myHandles.lowStartFrequency, 'String'))+ linewidth/2;
            runNum = 1;
            if get(myHandles.cycleNumOnCN, 'Value')
                runNum = 0;
                obj.myCycleNuControl.initialize();
            end
            seqPlace = 0; %0 = left side of line 1
                          %1 = right side of line 1
            
            %AVOID MEMORY MOVEMENT SLOWDOWNS
            bufferSize = 50;
            tempScanData = zeros(6,bufferSize);
            tempSummedData = zeros(1,bufferSize);
            tempNormData = zeros(1,bufferSize);
            tempPID1Data = zeros(1,bufferSize);
            
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
                                'cycleNum'};
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
            setappdata(obj.myTopFigure, 'linewidth', linewidth);
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
            linewidth = getappdata(obj.myTopFigure, 'linewidth');
            newCenterFreq = getappdata(obj.myTopFigure, 'newCenterFreq');
            prevFrequency = getappdata(obj.myTopFigure, 'prevFrequency');
            
            if runNum~=1
                tempH = getappdata(obj.myTopFigure, 'plottingHandles');
                taxis = getappdata(obj.myTopFigure, 'taxis');
            end
            
            if get(myHandles.cycleNumOnCN, 'Value')
                cycleNum = str2double(obj.myCycleNuControl.getCycleNum());
                seqPlace = mod(cycleNum-2,2); % 1 for previous measurement and 1 for mike bishof's convention
                disp(['Cycle Number was : ' num2str(cycleNum-1) '\rTherfore we just took seqPlace: ' num2str(mod(cycleNum-2,2))]);
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
                    
                    if runNum >= 2
                        prevExc = tNorm;
                        seqPlace = mod(seqPlace + 1,2);
                            if seqPlace == 0
                                obj.myPID1.myPolarity = 1;
                            else
                                obj.myPID1.myPolarity = -1;
                                calcErr1 = -1*calcErr1;
                            end
                            obj.updatePIDvalues();
                            obj.checkPIDenables();
                            deltaT = str2double(get(obj.myPID1gui.myDeltaT, 'String'));
                            if deltaT == 0
                                calcCorr1 = obj.myPID1.calculate(calcErr1, time);
                            else
                                calcCorr1 = obj.myPID1.calculate(calcErr1, -deltaT);
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
                        tempH(1) = plot(myHandles.sNormAxes, tempNormData, 'ok', 'LineWidth', 3);
                        tempH(2) = plot(myHandles.sEAxes, tempScanData(2,:), 'or', 'LineWidth', 2);
                        tempH(3) = plot(myHandles.sGAxes, tempScanData(1,:), 'ob', 'LineWidth', 2);
                        tempH(4) = plot(myHandles.sBGAxes, tempScanData(3,:), 'ob', 'LineWidth', 1);
                        tempH(5) = plot(myHandles.sSummedAxes, tempSummedData, 'og', 'LineWidth', 2);
                        tempH(6) = plot(myHandles.errPlot, tempPID1Data, 'ok', 'LineWidth', 2);
                    elseif runNum > 1
                        set(tempH(1), 'YData', tempNormData);
                        set(tempH(2), 'YData', tempScanData(2,:));
                        set(tempH(3), 'YData', tempScanData(1,:));
                        set(tempH(4), 'YData', tempScanData(3,:));
                        set(tempH(5), 'YData', tempSummedData);
                        set(tempH(6), 'YData', tempPID1Data);
                    end
                    obj.myPID1gui.updateMyPlots(calcErr1, runNum, plotstart);
                    if mod(seqPlace+1,2) == 0
                        set(myHandles.lockStatus, 'String', 'L1');
                    else
                        set(myHandles.lockStatus, 'String', 'R1');
                    end
                    %9. Check Save and Write Data to file.
% 'Frequency', 'Norm', 'GndState', 'ExcState', 'Background', 'TStamp', 'BLUEGndState', 'BLUEBackground', 'BLUEExcState'

                    temp = [prevFrequency tNorm tSCdat12(1) tSCdat12(2) tSCdat3 str2double(time) tSCdat456(1) tSCdat456(3) tSCdat456(2)];                    
                    if get(obj.myPID1gui.mySaveLog, 'Value')
                        if runNum >= 2
                            tempPID1 = [calcErr1 calcCorr1 newCenterFreq];%err correctionApplied servoVal
                        else
                            tempPID1 = [calcErr1 0 newCenterFreq];%err correctionApplied servoVal
                        end
                    else
                        tempPID1 = [0 0 0];
                    end
                    tempPID2 = [0 0 0];
                    tempPID3 = [0 0 0];
                    temp = [temp tempPID1 tempPID2 tempPID3];
                    fprintf(fid, '%8.6f\t', temp);
                    fprintf(fid, '\r\n');
                    
                    if (runNum > 5 && tNorm >= 0.1)
                        set(myHandles.lowStartFrequency, 'String', num2str(newCenterFreq - linewidth/2));
                        set(myHandles.highStartFrequency, 'String', num2str(newCenterFreq + linewidth/2));
                    end
                    pointDone = 1;
            end
            if (getappdata(obj.myTopFigure, 'run')) % Prepare for a new data point
                if runNum == 1
                    setappdata(obj.myTopFigure, 'taxis', taxis);
                end
                runNum = runNum + 1;
                seqPlace = mod(seqPlace + 1,2);
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
                obj.myPID1.clear();
                obj.myFreqSynth.close();
                fclose('all'); % weird matlab thing, can't just close fid, won't work.
                %10. If ~Run, make obvious and reset 'run'
                disp('Acquisistion Stopped');
                set(myHandles.curFreq, 'String', 'STOPPED');
                setappdata(obj.myTopFigure, 'run', 1);
                drawnow;
                rmappdata(obj.myTopFigure, 'normData');
                rmappdata(obj.myTopFigure, 'scanData');
                rmappdata(obj.myTopFigure, 'summedData');
                rmappdata(obj.myTopFigure, 'PID1Data');
                rmappdata(obj.myTopFigure, 'runNum');
                rmappdata(obj.myTopFigure, 'taxis');
                rmappdata(obj.myTopFigure, 'fid');
                rmappdata(obj.myTopFigure, 'seqPlace');
                rmappdata(obj.myTopFigure, 'prevExc');
                rmappdata(obj.myTopFigure, 'linewidth');
                rmappdata(obj.myTopFigure, 'newCenterFreq');
                rmappdata(obj.myTopFigure, 'plottingHandles');
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
            newCenterFreqL = str2double(get(myHandles.lowStartFrequency, 'String'))+ linewidth/2;
            newCenterFreqH = str2double(get(myHandles.highStartFrequency, 'String'))- linewidth/2;
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
            bufferSize = 50;
            tempScanData = zeros(6,bufferSize);
            tempSummedData = zeros(1,bufferSize);
            tempNormData = zeros(1,bufferSize);
            tempPID1Data = zeros(1,bufferSize);
            tempPID2Data = zeros(1,bufferSize);
            

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
                                'freqSr', 'cycleNum'};
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
            setappdata(obj.myTopFigure, 'linewidth', linewidth);
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
            linewidth = getappdata(obj.myTopFigure, 'linewidth');
            newCenterFreqL = getappdata(obj.myTopFigure, 'newCenterFreqL');
            newCenterFreqH = getappdata(obj.myTopFigure, 'newCenterFreqH');
            prevFrequency = getappdata(obj.myTopFigure, 'prevFrequency');
            
            if runNum > 1
                tempH = getappdata(obj.myTopFigure, 'plottingHandles');
                taxis = getappdata(obj.myTopFigure, 'taxis');
            end
            
            if get(myHandles.cycleNumOnCN, 'Value')
                cycleNum = str2double(obj.myCycleNuControl.getCycleNum());
                seqPlace = mod(cycleNum-2,4); % 1 for previous measurement and 1 for mike bishof's convention
                disp(['Cycle Number was : ' num2str(cycleNum-1) '\rTherfore we just took seqPlace: ' num2str(mod(cycleNum-2,4))]);
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
                    
                    if runNum >= 2
                        switch seqPlace
                            case {0,2}
                                prevExcL = tNorm;
                            case {1, 3}
                                prevExcH = tNorm;
                        end
                        switch seqPlace
                                case 0
                                    obj.myPID1.myPolarity = -1;
                                    calcErr1 = -1*calcErr1;
                                case 2
                                    obj.myPID1.myPolarity = 1;
                                case 1
                                    obj.myPID2.myPolarity = -1;
                                    calcErr2 = -1*calcErr2;
                                case 3
                                    obj.myPID2.myPolarity = 1;
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
                                        calcCorr1 = obj.myPID1.calculate(calcErr1, time);
                                    else
                                        calcCorr1 = obj.myPID1.calculate(calcErr1, -deltaT1);
                                    end
                                        newCenterFreqL = newCenterFreqL + calcCorr1;
                            case 1
                                calcCorr2 = 0;
                            case 3
                                    if deltaT2 == 0
                                        calcCorr2 = obj.myPID2.calculate(calcErr2, time);
                                    else
                                        calcCorr2 = obj.myPID2.calculate(calcErr2, -deltaT2);
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
                        tempH(1) = plot(myHandles.sNormAxes, tempNormData, 'ok', 'LineWidth', 3);
                        tempH(2) = plot(myHandles.sEAxes, tempScanData(2,:), 'or', 'LineWidth', 2);
                        tempH(3) = plot(myHandles.sGAxes, tempScanData(1,:), 'ob', 'LineWidth', 2);
                        tempH(4) = plot(myHandles.sBGAxes, tempScanData(3,:), 'ob', 'LineWidth', 1);
                        tempH(5) = plot(myHandles.sSummedAxes, tempSummedData, 'og', 'LineWidth', 2);
                        tempH(6) = plot(myHandles.errPlot, tempPID1Data, 'ok', 'LineWidth', 2);
                    elseif runNum > 1
                        set(tempH(1), 'YData', tempNormData);
                        set(tempH(2), 'YData', tempScanData(2,:));
                        set(tempH(3), 'YData', tempScanData(1,:));
                        set(tempH(4), 'YData', tempScanData(3,:));
                        set(tempH(5), 'YData', tempSummedData);
                        set(tempH(6), 'YData', tempPID1Data);
                    end
                    switch seqPlace
                        case {0,2}
                            obj.myPID1gui.updateMyPlots(calcErr1, runNum, plotstart);
                        case {1,3}
                            obj.myPID2gui.updateMyPlots(calcErr2, runNum, plotstart);
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
                    
                    if get(obj.myPID1gui.mySaveLog, 'Value')
                        if runNum >= 2 && seqPlace == 2
                            tempPID1 = [calcErr1 calcCorr1 newCenterFreqL];%err correctionApplied servoVal
                        else
                            tempPID1 = [0 0 0];%err correctionApplied servoVal
                        end
                    else
                        tempPID1 = [0 0 0];
                    end
                    if get(obj.myPID2gui.mySaveLog, 'Value')
                        if runNum >= 2 && seqPlace == 3
                            tempPID2 = [calcErr2 calcCorr2 newCenterFreqH];%err correctionApplied servoVal
                        else
                            tempPID2 = [0 0 newCenterFreqH];
                        end
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
                        temp = [temp cycleNum-1];
                    else
                        temp = [temp 0];
                    end
                    fprintf(fid, '%8.6f\t', temp);
                    fprintf(fid, '\r\n');
                    
                    
                    if (runNum > 5 && tNorm >= 0.1)
                        set(myHandles.lowStartFrequency, 'String', num2str(newCenterFreqL - linewidth/2));
                        set(myHandles.highStartFrequency, 'String', num2str(newCenterFreqH + linewidth/2));
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
                obj.myPID1.clear();
                obj.myPID2.clear();
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
                    rmappdata(obj.myTopFigure, 'linewidth');
                    rmappdata(obj.myTopFigure, 'newCenterFreqL');
                    rmappdata(obj.myTopFigure, 'newCenterFreqH');
                    rmappdata(obj.myTopFigure, 'prevFrequency');
                    rmappdata(obj.myTopFigure, 'plottingHandles');
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
            newCenterFreqL = str2double(get(myHandles.lowStartFrequency, 'String'))+ linewidth/2;
            newCenterFreqH = str2double(get(myHandles.highStartFrequency, 'String'))- linewidth/2;
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
            bufferSize = 50;
            tempScanData = zeros(6,bufferSize);
            tempSummedData = zeros(1,bufferSize);
            tempNormData = zeros(1,bufferSize);
            tempPID1Data = zeros(1,bufferSize);
            tempPID2Data = zeros(1,bufferSize);
            
            
            
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
                                'freqSr', 'cycleNum'};
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
            setappdata(obj.myTopFigure, 'linewidth', linewidth);
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
            linewidth = getappdata(obj.myTopFigure, 'linewidth');
            newCenterFreqL = getappdata(obj.myTopFigure, 'newCenterFreqL');
            newCenterFreqH = getappdata(obj.myTopFigure, 'newCenterFreqH');
            prevFrequency = getappdata(obj.myTopFigure, 'prevFrequency');
            
            if runNum > 1
                tempH = getappdata(obj.myTopFigure, 'plottingHandles');
                taxis = getappdata(obj.myTopFigure, 'taxis');
            end
            
            if get(myHandles.cycleNumOnCN, 'Value')
                cycleNum = str2double(obj.myCycleNuControl.getCycleNum());
                seqPlace = mod(cycleNum-2,4); % 1 for previous measurement and 1 for mike bishof's convention
                disp(['Cycle Number was : ' num2str(cycleNum-1) '\rTherfore we just took seqPlace: ' num2str(mod(cycleNum-2,4))]);
            end
            pointDone = 0;
            while(getappdata(obj.myTopFigure, 'run') && ~pointDone)
                plotstart = 1; %Needs to be out here so plots can be cleared
                %IMMEDIATELY READJUST LC WAVEPLATE and set frequency for
                %next point.
                if get(myHandles.bounceLCwaveplate, 'Value') && strcmp(get(myHandles.openSerialLC, 'Enable'), 'off')
                    switch mod(seqPlace+1,4) 
                        case 0 % left side of line 1
                            fprintf(obj.myLCuControl.mySerial, 'H');
                            curFrequency = newCenterFreqL - linewidth/2;
                        case 1 % right side of line 1
                            fprintf(obj.myLCuControl.mySerial, 'H');
                            curFrequency = newCenterFreqL + linewidth/2;
                        case 2 % left side of line 2
                            fprintf(obj.myLCuControl.mySerial, 'L');
                            curFrequency = newCenterFreqH - linewidth/2;
                        case 3 % right side of line 2
                            fprintf(obj.myLCuControl.mySerial, 'L');
                            curFrequency = newCenterFreqH + linewidth/2;
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
                    
                    if runNum >= 2
                        switch seqPlace
                            case {0,1}
                                prevExcL = tNorm;
                            case {2, 3}
                                prevExcH = tNorm;
                        end
                        switch seqPlace
                                case 0
                                    obj.myPID1.myPolarity = -1;
                                    calcErr1 = -1*calcErr1;
                                case 1
                                    obj.myPID1.myPolarity = 1;
                                case 2
                                    obj.myPID2.myPolarity = -1;
                                    calcErr2 = -1*calcErr2;
                                case 3
                                    obj.myPID2.myPolarity = 1;
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
                                        calcCorr1 = obj.myPID1.calculate(calcErr1, time);
                                    else
                                        calcCorr1 = obj.myPID1.calculate(calcErr1, -deltaT1);
                                    end
                                        newCenterFreqL = newCenterFreqL + calcCorr1;
                            case 2
                                calcCorr2 = 0;
                            case 3
                                    if deltaT2 == 0
                                        calcCorr2 = obj.myPID2.calculate(calcErr2, time);
                                    else
                                        calcCorr2 = obj.myPID2.calculate(calcErr2, -deltaT2);
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
                        tempH(1) = plot(myHandles.sNormAxes, tempNormData, 'ok', 'LineWidth', 3);
                        tempH(2) = plot(myHandles.sEAxes, tempScanData(2,:), 'or', 'LineWidth', 2);
                        tempH(3) = plot(myHandles.sGAxes, tempScanData(1,:), 'ob', 'LineWidth', 2);
                        tempH(4) = plot(myHandles.sBGAxes, tempScanData(3,:), 'ob', 'LineWidth', 1);
                        tempH(5) = plot(myHandles.sSummedAxes, tempSummedData, 'og', 'LineWidth', 2);
                        tempH(6) = plot(myHandles.errPlot, tempPID1Data, 'ok', 'LineWidth', 2);
                    elseif runNum > 1
                        set(tempH(1), 'YData', tempNormData);
                        set(tempH(2), 'YData', tempScanData(2,:));
                        set(tempH(3), 'YData', tempScanData(1,:));
                        set(tempH(4), 'YData', tempScanData(3,:));
                        set(tempH(5), 'YData', tempSummedData);
                        set(tempH(6), 'YData', tempPID1Data);
                    end
                    switch seqPlace
                        case {0,1}
                            obj.myPID1gui.updateMyPlots(calcErr1, runNum, plotstart);
                        case {2,3}
                            obj.myPID2gui.updateMyPlots(calcErr2, runNum, plotstart);
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
                    
                    if get(obj.myPID1gui.mySaveLog, 'Value')
                        if runNum >= 2 && seqPlace == 1
                            tempPID1 = [calcErr1 calcCorr1 newCenterFreqL];%err correctionApplied servoVal
                        else
                            tempPID1 = [0 0 0];%err correctionApplied servoVal
                        end
                    else
                        tempPID1 = [0 0 0];
                    end
                    if get(obj.myPID2gui.mySaveLog, 'Value')
                        if runNum >= 2 && seqPlace == 3
                            tempPID2 = [calcErr2 calcCorr2 newCenterFreqH];%err correctionApplied servoVal
                        else
                            tempPID2 = [0 0 newCenterFreqH];
                        end
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
                        temp = [temp cycleNum-1];
                    else
                        temp = [temp 0];
                    end
                    fprintf(fid, '%8.6f\t', temp);
                    fprintf(fid, '\r\n');
                    
                    
                    if (runNum > 5 && tNorm >= 0.1)
                        set(myHandles.lowStartFrequency, 'String', num2str(newCenterFreqL - linewidth/2));
                        set(myHandles.highStartFrequency, 'String', num2str(newCenterFreqH + linewidth/2));
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
                obj.myPID1.clear();
                obj.myPID2.clear();
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
                    rmappdata(obj.myTopFigure, 'linewidth');
                    rmappdata(obj.myTopFigure, 'newCenterFreqL');
                    rmappdata(obj.myTopFigure, 'newCenterFreqH');
                    rmappdata(obj.myTopFigure, 'prevFrequency');
                    rmappdata(obj.myTopFigure, 'plottingHandles');
                catch exception
                    exception.message
                end
                drawnow;
                
                guidata(obj.myTopFigure, myHandles);
                
                clear variables
                clear mex
            end
        end
        function updatePIDvalues(obj)
            obj.myPID1.myKp = str2double(get(obj.myPID1gui.myKp, 'String'));
            obj.myPID1.myKi = str2double(get(obj.myPID1gui.myKi, 'String'));
            obj.myPID1.myKd = str2double(get(obj.myPID1gui.myKd, 'String'));
            
            obj.myPID2.myKp = str2double(get(obj.myPID2gui.myKp, 'String'));
            obj.myPID2.myKi = str2double(get(obj.myPID2gui.myKi, 'String'));
            obj.myPID2.myKd = str2double(get(obj.myPID2gui.myKd, 'String'));
            
            obj.myPID3.myKp = str2double(get(obj.myPID3gui.myKp, 'String'));
            obj.myPID3.myKi = str2double(get(obj.myPID3gui.myKi, 'String'));
            obj.myPID3.myKd = str2double(get(obj.myPID3gui.myKd, 'String'));
            
        end
        function checkPIDenables(obj)
            if ~get(obj.myPID1gui.myEnableBox, 'Value')
                obj.myPID1.myKp = 0;
                obj.myPID1.myKi = 0;
                obj.myPID1.myKd = 0;
                obj.myPID1.myT0 = 0;
                obj.myPID1.myIntE = 0;
            end
            if ~get(obj.myPID2gui.myEnableBox, 'Value')
                obj.myPID2.myKp = 0;
                obj.myPID2.myKi = 0;
                obj.myPID2.myKd = 0;
                obj.myPID2.myT0 = 0;
                obj.myPID2.myIntE = 0;
            end
            if ~get(obj.myPID3gui.myEnableBox, 'Value')
                obj.myPID3.myKp = 0;
                obj.myPID3.myKi = 0;
                obj.myPID3.myKd = 0;
                obj.myPID3.myT0 = 0;
                obj.myPID3.myIntE = 0;
            end
                
        end
        function [path, fileName] = createFileName(obj)
            myHandles = guidata(obj.myTopFigure);
            basePath = get(myHandles.saveDirPID1, 'String');
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
            obj.myPID1 = [];
            obj.myPID1gui = [];
            obj.myPID2 = [];
            obj.myPID2gui = [];
            obj.myPID3 = [];
            obj.myPID3gui = [];
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
                
                guidata(obj.myTopFigure, myHandles);
            catch
                disp('No saved state for FreqLocker Exists');
            end
        end

    end
    
end

