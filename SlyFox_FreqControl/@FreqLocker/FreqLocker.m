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
                lockModes = uiextras.TabPanel('Parent', lockOptPanel, ...
                    'Tag', 'lockModes');
                    singlePeakP = uiextras.Panel('Parent', lockModes);
                        uicontrol(...
                            'Parent', singlePeakP, ...
                            'Style', 'popup', ...
                            'String', 'Continuous Lock | Intermittent Lock');
                    multiPeakP = uiextras.Panel('Parent', lockModes);
                    lockModes.SelectedChild = 1;
                    lockModes.TabNames = {'Single Peak Lock', 'Multiple Peak Lock'};
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
            
%             modeSelected = get(myHandles.lockModes, 'SelectedChild');
            modeSelected = 1;
            
            switch modeSelected
                case 1
                    obj.startContinousLock();
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
                        [path, fileName] = obj.createFileName()
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
                [data,time,ret] = GageCard.GageMRecord(obj.myGageConfigFrontend.myGageConfig, handle);
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
                    plot(myHandles.rGSAxes, taxis(1:length(data{1,2})), reshape(data{1,2}, [1 length(data{1,2})]));
                    plot(myHandles.rEAxes, taxis(1:length(data{1,3})), reshape(data{1,3}, [1 length(data{1,3})]));
                    plot(myHandles.rBGAxes, taxis(1:length(data{1,4})), reshape(data{1,4}, [1 length(data{1,4})]));
                    plot(myHandles.rBGSAxes, taxis(1:length(data{2,2})), reshape(data{2,2}, [1 length(data{2,2})]));
                    plot(myHandles.rBEAxes, taxis(1:length(data{2,3})), reshape(data{2,3}, [1 length(data{2,3})]));
                    plot(myHandles.rBBGAxes, taxis(1:length(data{2,4})), reshape(data{2,4}, [1 length(data{2,4})]));
                    %8. Update Scan Plots
                    tempScanData = getappdata(obj.myTopFigure, 'scanData');
                    tempNormData = getappdata(obj.myTopFigure, 'normData');
                    tempSummedData = getappdata(obj.myTopFigure, 'summedData');
                    tempScanData(1:2,runNum) = double(scanDataCH1(2:3) - scanDataCH1(4));
                    tempScanData(3,runNum) = double(scanDataCH1(4));
                    tempScanData(4:6,runNum) = double(scanDataCH2(2:end));
                    %NORMALIZED counts are (E - bg)/(E + G - 2bg)
                    tempNormData(runNum) = (tempScanData(2,runNum)) / (tempScanData(2,runNum) + tempScanData(1,runNum));
                    %SUMMED counts
                    tempSummedData(runNum) = tempScanData(2,runNum)+tempScanData(1,runNum);
                    setappdata(obj.myTopFigure, 'normData', tempNormData);
                    setappdata(obj.myTopFigure, 'scanData', tempScanData);
                    setappdata(obj.myTopFigure, 'summedData', tempSummedData);
                    
                    
                    %MAKE SAVE FUNCTIONS
                    
                    %Do some PID magic!
                    %Calculate Error for PID1
                    calcErr1 = tempNormData(runNum) - prevExc;
                    tempPID1Data = getappdata(obj.myTopFigure, 'PID1Data');
                    tempPID1Data(runNum) = calcErr1;
                    setappdata(obj.myTopFigure, 'PID1Data', tempPID1Data);
                    
                    if runNum >= 2
                        prevExc = tempNormData(runNum);
                        seqPlace = mod(seqPlace + 1,2);
                        if runNum ~= 2
                            if seqPlace == 0
                                obj.myPID1.myPolarity = -1;
                            else
                                obj.myPID1.myPolarity = 1;
                            end
                            obj.updatePIDvalues();
                            obj.checkPIDenables();
                            calcCorr1 = obj.myPID1.calculate(calcErr1, str2double(time));
                            newCenterFreq = newCenterFreq + calcCorr1;
                        end
                    end
                    
                    %Do some Plotting
                    plotstart = 1;
                    firstplot = 1;
                    if get(myHandles.ignoreFirstToggle, 'Value')
                        plotstart = 2;
                        firstplot = 2;
                    end
                    if runNum == 2
                        tempH(1) = plot(myHandles.sNormAxes, tempNormData(plotstart:runNum), 'ok', 'LineWidth', 3);
                        tempH(2) = plot(myHandles.sEAxes, tempScanData(2,plotstart:runNum), 'or', 'LineWidth', 2);
                        tempH(3) = plot(myHandles.sGAxes, tempScanData(1,plotstart:runNum), 'ob', 'LineWidth', 2);
                        tempH(4) = plot(myHandles.sBGAxes, tempScanData(3,plotstart:runNum), 'ob', 'LineWidth', 1);
                        tempH(5) = plot(myHandles.sSummedAxes, tempSummedData(plotstart:runNum), 'og', 'LineWidth', 2);
                        tempH(6) = plot(myHandles.errPlot, tempPID1Data(plotstart:runNum), 'ok', 'LineWidth', 2);
                    elseif runNum > 2
                        set(tempH(1), 'YData', tempNormData(plotstart:runNum));
                        set(tempH(2), 'YData', tempScanData(2,plotstart:runNum));
                        set(tempH(3), 'YData', tempScanData(1,plotstart:runNum));
                        set(tempH(4), 'YData', tempScanData(3,plotstart:runNum));
                        set(tempH(5), 'YData', tempSummedData(plotstart:runNum));
                        set(tempH(6), 'YData', tempPID1Data(plotstart:runNum));
                        refreshdata(tempH);
                    end
                    obj.myPID1gui.updateMyPlots(calcErr1, runNum);
                    if seqPlace == 0
                        set(myHandles.lockStatus, 'String', 'L1');
                    else
                        set(myHandles.lockStatus, 'String', 'R1');
                    end
                    %9. Check Save and Write Data to file.
% 'Frequency', 'Norm', 'GndState', 'ExcState', 'Background', 'TStamp', 'BLUEGndState', 'BLUEBackground', 'BLUEExcState'
                    temp = 0;
                    temp = [curFrequency tempNormData(runNum) tempScanData(1,runNum) tempScanData(2,runNum) tempScanData(3,runNum) str2double(time) tempScanData(4,runNum) tempScanData(6,runNum) tempScanData(5,runNum)];
                    
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
