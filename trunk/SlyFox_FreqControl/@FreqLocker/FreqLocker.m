classdef FreqLocker < hgsetget
    %FREQLOCKER Rabi Spectroscopy locking program
    %   This program is intended to be used in conjunction with the
    %   freqsweeper program and is meant to be used to lock to Rabi
    %   lineshapes for use in atomic clock experiments, or to carefully
    %   cancel drifts between shots. This program should have a few
    %   different modes once it is done. Single-peak locking, Stretched
    %   State locking, and intermittent locking mode for canceling drifts
    %   between experiments. Written by Ben Bloom. Last Updated 01/22/12
    %   15:31:00
    
    properties
        myPanel = uiextras.Grid();
        myTopFigure = [];
        myFreqSynth = [];
        myGageConfigFrontend = [];
        myFreqSweeper = [];
        myuControl = [];
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
                            'String', 'Continuous Strectched States Lock | Intermittent Lock');
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
                                'Value', 1);
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
        function setuControl(obj, uC)
            obj.myuControl = uC;
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
                case 1
                    tempVal = get(myHandles.singlePeakLockOptions, 'Value');
                    switch tempVal
                        case 1 %CONTINUOUS LOCK
                            obj.startContinousLock();
                    end
                case 2
                    tempVal = get(myHandles.multiplePeakLockOptions, 'Value');
                    switch tempVal
                        case 1 %MULTIPLE STRETCHED STATES CONTINUOUS LOCK
                            obj.startContinuousMultiLock();
                    end
            end
        end
        
        function startContinousLock(obj)
            myHandles = guidata(obj.myTopFigure);
            prevExc = 0; %For use in calculating the present Error
            linewidth = str2double(get(myHandles.linewidth, 'String'));
            newCenterFreq = str2double(get(myHandles.lowStartFrequency, 'String'))+ linewidth/2;
            runNum = 0;
            seqPlace = 0; %0 = left side of line 1
                          %1 = right side of line 1
            
            %AVOID MEMORY MOVEMENT SLOWDOWNS
            bufferSize = 50;
            tempScanData = zeros(6,bufferSize);
            tempSummedData = zeros(1,bufferSize);
            tempNormData = zeros(1,bufferSize);
            tempPID1Data = zeros(1,bufferSize);
            setappdata(obj.myTopFigure, 'normData', tempNormData);
            setappdata(obj.myTopFigure, 'scanData', tempScanData);
            setappdata(obj.myTopFigure, 'summedData', tempSummedData);
            setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
            
            
            %Create stuff for raw Plotting Later on
            aInfo = obj.myGageConfigFrontend.myGageConfig.acqInfo;
            sampleRate = aInfo.SampleRate;
            depth = aInfo.Depth;
            taxis = 1:depth;
            taxis = 1/sampleRate*taxis;
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
                                'err3', 'cor3', 'servoVal3'};
                            n = length(colNames);
                            for i=1:n
                                fprintf(fid, '%s\t', colNames{i});
                            end
                                fprintf(fid, '\r\n');
                        catch
                            disp('Could not open file to write to.');
                        end
            end
            
            plotstart = 1; %Needs to be out here so plots can be cleared
            while(getappdata(obj.myTopFigure, 'run'))
                runNum = runNum + 1;
                
                %3. Set Frequency (Display + Synthesizer)
                switch seqPlace
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
                %4. Update Progress Bar
                drawnow;
                %5. Call Gage Card to gather data
                if runNum==1
                       systems = CsMl_Initialize;
                       CsMl_ErrorHandler(systems);
                       [ret, handle] = CsMl_GetSystem;  %this takes like 2 seconds....I should try and move this.
                       CsMl_ErrorHandler(ret);
                end
                [data,time,ret] = GageCard.GageMRecord(obj.myGageConfigFrontend.myGageConfig, handle, runNum);
                if ~ret
                    setappdata(obj.myTopFigure, 'run', 0);
                    break;
                end
                if ~getappdata(obj.myTopFigure, 'run')
                    ret = CsMl_FreeSystem(handle);
                    break;
                end
                    %6. Call AnalyzeRawData
                    scanDataCH1 = obj.analyzeRawData(data(1,:));
                    scanDataCH2 = obj.analyzeRawDataBLUE(data(2,:));
                    %7. Clear the Raw Plots, Plot the Raw Plots
                if runNum == 1
                    tempH(7) = plot(myHandles.rGSAxes, taxis(1:length(data{1,2})), ...
                                reshape(data{1,2}, [1 length(data{1,2})]));

                    tempH(8) = plot(myHandles.rEAxes, taxis(1:length(data{1,3})), ...
                                reshape(data{1,3}, [1 length(data{1,3})]));

                    tempH(9) = plot(myHandles.rBGAxes, taxis(1:length(data{1,4})), ...
                                reshape(data{1,4}, [1 length(data{1,4})]));

                    tempH(10) = plot(myHandles.rBGSAxes, taxis(1:length(data{2,2})), ...
                                reshape(data{2,2}, [1 length(data{2,2})]));

                    tempH(11) = plot(myHandles.rBEAxes, taxis(1:length(data{2,3})), ...
                                reshape(data{2,3}, [1 length(data{2,3})]));

                    tempH(12) = plot(myHandles.rBBGAxes, taxis(1:length(data{2,4})), ...
                                reshape(data{2,4}, [1 length(data{2,4})]));
                else
                    set(tempH(7), 'XData',  taxis(1:length(data{1,2})));
                    set(tempH(7), 'YData', reshape(data{1,2}, [1 length(data{1,2})]));
                    set(tempH(8), 'XData',  taxis(1:length(data{1,3})));
                    set(tempH(8), 'YData', reshape(data{1,3}, [1 length(data{1,3})]));
                    set(tempH(9), 'XData',  taxis(1:length(data{1,4})));
                    set(tempH(9), 'YData', reshape(data{1,4}, [1 length(data{1,4})]));
                    set(tempH(10), 'XData',  taxis(1:length(data{2,2})));
                    set(tempH(10), 'YData', reshape(data{2,2}, [1 length(data{2,2})]));
                    set(tempH(11), 'XData',  taxis(1:length(data{2,3})));
                    set(tempH(11), 'YData', reshape(data{2,3}, [1 length(data{2,3})]));
                    set(tempH(12), 'XData',  taxis(1:length(data{2,4})));
                    set(tempH(12), 'YData', reshape(data{2,4}, [1 length(data{2,4})]));

                end
                    %8. Update Scan Plots
                    tempScanData = getappdata(obj.myTopFigure, 'scanData');
                    tempNormData = getappdata(obj.myTopFigure, 'normData');
                    tempSummedData = getappdata(obj.myTopFigure, 'summedData');
                    tSCdat12 = (double(scanDataCH1(2:3) - scanDataCH1(4)));
                    tSCdat3 = double(scanDataCH1(4));
                    tSCdat456 = double(scanDataCH2(2:end));
                    tempScanData(1:2, :) = [tempScanData(1:2, 2:end) tSCdat12'];
                    tempScanData(3,:) = [tempScanData(3, 2:end) tSCdat3];
                    tempScanData(4:6,:) = [tempScanData(4:6, 2:end) tSCdat456'];
                    %NORMALIZED counts are (E - bg)/(E + G - 2bg)
                    tNorm = (tSCdat12(2)) / (tSCdat12(2) + tSCdat12(1));
                    tempNormData = [tempNormData(2:end) tNorm];
                    %SUMMED counts
                    tSum = tSCdat12(2) + tSCdat12(1);
                    tempSummedData = [tempSummedData(2:end) tSum];
                    setappdata(obj.myTopFigure, 'normData', tempNormData);
                    setappdata(obj.myTopFigure, 'scanData', tempScanData);
                    setappdata(obj.myTopFigure, 'summedData', tempSummedData);
                    
                    
                    %MAKE SAVE FUNCTIONS
                    
                    %Do some PID magic!
                    %Calculate Error for PID1
                    calcErr1 = tNorm - prevExc;
                    tempPID1Data = getappdata(obj.myTopFigure, 'PID1Data');
                    
                    
                    if runNum >= 2
                        prevExc = tNorm;
                        seqPlace = mod(seqPlace + 1,2);
                        if runNum ~= 2
                            if seqPlace == 0
                                obj.myPID1.myPolarity = 1;
                            else
                                obj.myPID1.myPolarity = -1;
                                calcErr1 = -1*calcErr1;
                            end
                            obj.updatePIDvalues();
                            obj.checkPIDenables();
                            calcCorr1 = obj.myPID1.calculate(calcErr1, str2double(time));
                            newCenterFreq = newCenterFreq + calcCorr1;
                        end
                    end
                    
                    tempPID1Data = [tempPID1Data(2:end) calcErr1];
                    setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
                    
                    %Do some Plotting
                    firstplot = 1;
                    if get(myHandles.ignoreFirstToggle, 'Value') && plotstart < 3
                        plotstart = 2;
                        firstplot = 2;
                    end
                    if runNum == 2
                        tempH(1) = plot(myHandles.sNormAxes, tempNormData, 'ok', 'LineWidth', 3);
                        tempH(2) = plot(myHandles.sEAxes, tempScanData(2,:), 'or', 'LineWidth', 2);
                        tempH(3) = plot(myHandles.sGAxes, tempScanData(1,:), 'ob', 'LineWidth', 2);
                        tempH(4) = plot(myHandles.sBGAxes, tempScanData(3,:), 'ob', 'LineWidth', 1);
                        tempH(5) = plot(myHandles.sSummedAxes, tempSummedData, 'og', 'LineWidth', 2);
                        tempH(6) = plot(myHandles.errPlot, tempPID1Data, 'ok', 'LineWidth', 2);
                    elseif runNum > 2
                        set(tempH(1), 'YData', tempNormData);
                        set(tempH(2), 'YData', tempScanData(2,:));
                        set(tempH(3), 'YData', tempScanData(1,:));
                        set(tempH(4), 'YData', tempScanData(3,:));
                        set(tempH(5), 'YData', tempSummedData);
                        set(tempH(6), 'YData', tempPID1Data);
                        refreshdata(tempH);
                    end
                    obj.myPID1gui.updateMyPlots(calcErr1, runNum, plotstart);
                    if seqPlace == 0
                        set(myHandles.lockStatus, 'String', 'L1');
                    else
                        set(myHandles.lockStatus, 'String', 'R1');
                    end
                    %9. Check Save and Write Data to file.
% 'Frequency', 'Norm', 'GndState', 'ExcState', 'Background', 'TStamp', 'BLUEGndState', 'BLUEBackground', 'BLUEExcState'

                    temp = [curFrequency tNorm tSCdat12(1) tSCdat12(2) tSCdat3 str2double(time) tSCdat456(1) tSCdat456(3) tSCdat456(2)];                    
                    if get(obj.myPID1gui.mySaveLog, 'Value')
                        if runNum > 2
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
                    pause(0.05);
            end
            %9.5 Close Frequency Synthesizer and Data file
            obj.myPID1.clear();
            obj.myFreqSynth.close();
            fclose('all'); % weird matlab thing, can't just close fid, won't work.
            %10. If ~Run, make obvious and reset 'run'
            if ~getappdata(obj.myTopFigure, 'run')
                disp('Acquisistion Stopped');
                set(myHandles.curFreq, 'String', 'STOPPED');
                setappdata(obj.myTopFigure, 'run', 1);
                drawnow;
            end
            guidata(obj.myTopFigure, myHandles);
            
            clear variables
            clear mex
        end
        function startContinuousMultiLock(obj)
            myHandles = guidata(obj.myTopFigure);
            prevExcL = 0; %For use in calculating the present Error for Low Freq Lock
            prevExcH = 0; %For use in calculating the present Error for Low Freq Lock
            linewidth = str2double(get(myHandles.linewidth, 'String'));
            newCenterFreqL = str2double(get(myHandles.lowStartFrequency, 'String'))+ linewidth/2;
            newCenterFreqH = str2double(get(myHandles.highStartFrequency, 'String'))- linewidth/2;
            runNum = 0;
            
            %AVOID MEMORY MOVEMENT SLOWDOWNS
            bufferSize = 10;
            tempScanData = zeros(6,bufferSize);
            tempSummedData = zeros(1,bufferSize);
            tempNormData = zeros(1,bufferSize);
            tempPID1Data = zeros(1,bufferSize);
            tempPID2Data = zeros(1,bufferSize);
            setappdata(obj.myTopFigure, 'normData', tempNormData);
            setappdata(obj.myTopFigure, 'scanData', tempScanData);
            setappdata(obj.myTopFigure, 'summedData', tempSummedData);
            setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
            setappdata(obj.myTopFigure, 'PID2Data', tempPID2Data);
            
            
            seqPlace = 0; %0 = left side of line 1
                          %1 = right side of line 1
                          %2 = left side of line 2
                          %3 = right side of line 2
            %Initialize Liquid Crystal Waveplate
            if get(myHandles.bounceLCwaveplate, 'Value') && strcmp(get(myHandles.openSerial, 'Enable'), 'off')
                fprintf(obj.myuControl.mySerial, 'H');
                %fscanf(obj.myuControl.mySerial)
            end
            
            
            %Create stuff for raw Plotting Later on
            aInfo = obj.myGageConfigFrontend.myGageConfig.acqInfo;
            sampleRate = aInfo.SampleRate;
            depth = aInfo.Depth;
            taxis = 1:depth;
            taxis = 1/sampleRate*taxis;
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
                                'freqSr'};
                            n = length(colNames);
                            for i=1:n
                                fprintf(fid, '%s\t', colNames{i});
                            end
                                fprintf(fid, '\r\n');
                        catch
                            disp('Could not open file to write to.');
                        end
            end
            
            plotstart = 1; %Needs to be out here so plots can be cleared
            while(getappdata(obj.myTopFigure, 'run'))
                runNum = runNum + 1;
                %3. Set Frequency (Display + Synthesizer)
                switch seqPlace
                    case 0 % left side of line 1
                        curFrequency = newCenterFreqL - linewidth/2;
                    case 1 % right side of line 2
                        curFrequency = newCenterFreqL + linewidth/2;
                    case 2 % left side of line 1
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
                %4. Update Progress Bar
                drawnow;
                %5. Call Gage Card to gather data
                if runNum==1
                       systems = CsMl_Initialize;
                       CsMl_ErrorHandler(systems);
                       [ret, handle] = CsMl_GetSystem;  %this takes like 2 seconds....I should try and move this.
                       CsMl_ErrorHandler(ret);
                end
                [data,time,ret] = GageCard.GageMRecord(obj.myGageConfigFrontend.myGageConfig, handle, runNum);
                %IMMEDIATELY READJUST LC WAVEPLATE
                if get(myHandles.bounceLCwaveplate, 'Value') && strcmp(get(myHandles.openSerial, 'Enable'), 'off')
                    switch mod(seqPlace+1,4) 
                        case 0
                            fprintf(obj.myuControl.mySerial, 'H');
                        case 1
                            fprintf(obj.myuControl.mySerial, 'H');
                        case 2
                            fprintf(obj.myuControl.mySerial, 'L');
                        case 3
                            fprintf(obj.myuControl.mySerial, 'L');
                    end
                end
                if ~ret
                    setappdata(obj.myTopFigure, 'run', 0);
                    break;
                end
                if ~getappdata(obj.myTopFigure, 'run')
                    ret = CsMl_FreeSystem(handle);
                    break;
                end
                    %6. Call AnalyzeRawData
                    scanDataCH1 = obj.analyzeRawData(data(1,:));
                    scanDataCH2 = obj.analyzeRawDataBLUE(data(2,:));
                    %7. Clear the Raw Plots, Plot the Raw Plots
                    if runNum == 1
                    tempH(7) = plot(myHandles.rGSAxes, taxis(1:length(data{1,2})), ...
                                reshape(data{1,2}, [1 length(data{1,2})]));

                    tempH(8) = plot(myHandles.rEAxes, taxis(1:length(data{1,3})), ...
                                reshape(data{1,3}, [1 length(data{1,3})]));

                    tempH(9) = plot(myHandles.rBGAxes, taxis(1:length(data{1,4})), ...
                                reshape(data{1,4}, [1 length(data{1,4})]));

                    tempH(10) = plot(myHandles.rBGSAxes, taxis(1:length(data{2,2})), ...
                                reshape(data{2,2}, [1 length(data{2,2})]));

                    tempH(11) = plot(myHandles.rBEAxes, taxis(1:length(data{2,3})), ...
                                reshape(data{2,3}, [1 length(data{2,3})]));

                    tempH(12) = plot(myHandles.rBBGAxes, taxis(1:length(data{2,4})), ...
                                reshape(data{2,4}, [1 length(data{2,4})]));
                else
                    set(tempH(7), 'XData',  taxis(1:length(data{1,2})));
                    set(tempH(7), 'YData', reshape(data{1,2}, [1 length(data{1,2})]));
                    set(tempH(8), 'XData',  taxis(1:length(data{1,3})));
                    set(tempH(8), 'YData', reshape(data{1,3}, [1 length(data{1,3})]));
                    set(tempH(9), 'XData',  taxis(1:length(data{1,4})));
                    set(tempH(9), 'YData', reshape(data{1,4}, [1 length(data{1,4})]));
                    set(tempH(10), 'XData',  taxis(1:length(data{2,2})));
                    set(tempH(10), 'YData', reshape(data{2,2}, [1 length(data{2,2})]));
                    set(tempH(11), 'XData',  taxis(1:length(data{2,3})));
                    set(tempH(11), 'YData', reshape(data{2,3}, [1 length(data{2,3})]));
                    set(tempH(12), 'XData',  taxis(1:length(data{2,4})));
                    set(tempH(12), 'YData', reshape(data{2,4}, [1 length(data{2,4})]));

                end
                    %8. Update Scan Plots
                    tempScanData = getappdata(obj.myTopFigure, 'scanData');
                    tempNormData = getappdata(obj.myTopFigure, 'normData');
                    tempSummedData = getappdata(obj.myTopFigure, 'summedData');
                    tSCdat12 = (double(scanDataCH1(2:3) - scanDataCH1(4)));
                    tSCdat3 = double(scanDataCH1(4));
                    tSCdat456 = double(scanDataCH2(2:end));
                    tempScanData(1:2, :) = [tempScanData(1:2, 2:end) tSCdat12'];
                    tempScanData(3,:) = [tempScanData(3, 2:end) tSCdat3];
                    tempScanData(4:6,:) = [tempScanData(4:6, 2:end) tSCdat456'];
                    %NORMALIZED counts are (E - bg)/(E + G - 2bg)
                    tNorm = (tSCdat12(2)) / (tSCdat12(2) + tSCdat12(1));
                    tempNormData = [tempNormData(2:end) tNorm];
                    %SUMMED counts
                    tSum = tSCdat12(2) + tSCdat12(1);
                    tempSummedData = [tempSummedData(2:end) tSum];
                    setappdata(obj.myTopFigure, 'normData', tempNormData);
                    setappdata(obj.myTopFigure, 'scanData', tempScanData);
                    setappdata(obj.myTopFigure, 'summedData', tempSummedData);
                    
                    
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
                                if runNum >= 4
                                    prevExcH = tNorm;
                                end
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
                        switch seqPlace
                            case {0,1}
                                if runNum ~=2
                                    calcCorr1 = obj.myPID1.calculate(calcErr1, str2double(time));
                                    newCenterFreqL = newCenterFreqL + calcCorr1;
                                end
                            case {2,3}
                                if runNum ~=4
                                    calcCorr2 = obj.myPID2.calculate(calcErr2, str2double(time));
                                    newCenterFreqH = newCenterFreqH + calcCorr2;
                                end
                        end
                    end
                    
                    switch seqPlace
                        case {0,1}
                            tempPID1Data = [tempPID1Data(2:end) calcErr1];
                            setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
                        case {2,3}
                            tempPID2Data = [tempPID2Data(2:end) calcErr2];
                            setappdata(obj.myTopFigure, 'PID2Data', tempPID2Data);
                    end
                    
                    %Do some Plotting
                    firstplot = 1;
                    if get(myHandles.ignoreFirstToggle, 'Value') && plotstart < 3
                        plotstart = 2;
                        firstplot = 2;
                    end
                    if runNum == 2
                        tempH(1) = plot(myHandles.sNormAxes, tempNormData, 'ok', 'LineWidth', 3);
                        tempH(2) = plot(myHandles.sEAxes, tempScanData(2,:), 'or', 'LineWidth', 2);
                        tempH(3) = plot(myHandles.sGAxes, tempScanData(1,:), 'ob', 'LineWidth', 2);
                        tempH(4) = plot(myHandles.sBGAxes, tempScanData(3,:), 'ob', 'LineWidth', 1);
                        tempH(5) = plot(myHandles.sSummedAxes, tempSummedData, 'og', 'LineWidth', 2);
                        tempH(6) = plot(myHandles.errPlot, tempPID1Data, 'ok', 'LineWidth', 2);
                    elseif runNum > 2
                        set(tempH(1), 'YData', tempNormData);
                        set(tempH(2), 'YData', tempScanData(2,:));
                        set(tempH(3), 'YData', tempScanData(1,:));
                        set(tempH(4), 'YData', tempScanData(3,:));
                        set(tempH(5), 'YData', tempSummedData);
                        set(tempH(6), 'YData', tempPID1Data);
                        refreshdata(tempH);
                    end
                    switch seqPlace
                        case {0,1}
                            obj.myPID1gui.updateMyPlots(calcErr1, runNum, plotstart);
                        case {2,3}
                            obj.myPID2gui.updateMyPlots(calcErr2, runNum, plotstart);
                    end
                    switch seqPlace
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
                    temp = [curFrequency tNorm tSCdat12(1) tSCdat12(2) tSCdat3 str2double(time) tSCdat456(1) tSCdat456(3) tSCdat456(2)];
                    
                    if get(obj.myPID1gui.mySaveLog, 'Value')
                        if runNum > 2
                            tempPID1 = [calcErr1 calcCorr1 newCenterFreqL];%err correctionApplied servoVal
                        else
                            tempPID1 = [calcErr1 0 newCenterFreqL];%err correctionApplied servoVal
                        end
                    else
                        tempPID1 = [0 0 0];
                    end
                    if get(obj.myPID2gui.mySaveLog, 'Value')
                        if runNum > 4
                            tempPID2 = [calcErr2 calcCorr2 newCenterFreqH];%err correctionApplied servoVal
                        elseif runNum == 4
                            tempPID2 = [calcErr2 0 newCenterFreqH];%err correctionApplied servoVal
                        else
                            tempPID2 = [0 0 0];
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
                    fprintf(fid, '%8.6f\t', temp);
                    fprintf(fid, '\r\n');
                    
                    if runNum >= 2
                        seqPlace = mod(seqPlace + 1,4);
                    end
                    

            end
            %9.5 Close Frequency Synthesizer and Data file
            obj.myPID1.clear();
            obj.myPID2.clear();
            obj.myFreqSynth.close();
            fclose('all'); % weird matlab thing, can't just close fid, won't work.
            %10. If ~Run, make obvious and reset 'run'
            if ~getappdata(obj.myTopFigure, 'run')
                disp('Acquisistion Stopped');
                set(myHandles.curFreq, 'String', 'STOPPED');
                setappdata(obj.myTopFigure, 'run', 1);
                drawnow;
            end
            guidata(obj.myTopFigure, myHandles);
            
            clear variables
            clear mex
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
            myHandles = guidata(obj.myTopFigure);
        end
        function loadState(obj)
            try
%                 load FreqSweeperState
                myHandles = guidata(obj.myTopFigure);
%                 set(myHandles.startFrequency, 'String', FreqSweeperState.startFrequency);
%                 set(myHandles.stepFrequency, 'String', FreqSweeperState.stepFrequency);
%                 set(myHandles.stopFrequency, 'String', FreqSweeperState.stopFrequency);
%                 set(myHandles.startScan, 'Value', FreqSweeperState.saveScan);
%                 set(myHandles.saveDir, 'String', FreqSweeperState.saveDir);
                guidata(obj.myTopFigure, myHandles);
            catch
                disp('No saved state for FreqLocker Exists');
            end
        end

    end
    
end

