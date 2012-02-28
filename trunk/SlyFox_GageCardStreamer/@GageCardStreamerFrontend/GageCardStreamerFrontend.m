classdef GageCardStreamerFrontend < handle
    %GAGECARDSTREAMERFRONTEND Constantly reads the GageCard and Streams
    %Results
    %   This will have two buttons 
    
    properties
        myPanel = uiextras.Panel();
        myTopFigure = [];
        myGageConfigFrontend = [];
        myServer = [];
    end
    
    methods
        function obj = GageCardStreamerFrontend(top,f, DEBUGMODE)
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
                %Starting and Stopping
                uiVB = uiextras.VBox(...
                    'Parent', hsplit, ...
                    'Tag', 'uiVB', ...
                    'Spacing', 5, ...
                    'Padding', 5);
                
                    
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
                                'String', 'Start Gage',...
                                'Callback', @obj.startButton_Callback);
                            uiextras.Empty('Parent', startStopHB);
                            uicontrol(...
                                'Parent', startStopHB,...
                                'Style', 'pushbutton', ...
                                'Tag', 'stopButton',...
                                'String', 'Stop Gage',...
                                'Callback', @obj.stopButton_Callback);
                            set(startStopHB, 'Sizes', [-2 -1 -2]);
                        startStopServerHB = uiextras.HBox(...
                            'Parent', startStopVB, ...
                            'Spacing', 5, ...
                            'Padding', 5);
                            uicontrol(...
                                'Parent', startStopServerHB,...
                                'Style', 'pushbutton', ...
                                'Tag', 'startButtonServer',...
                                'String', 'Start Server',...
                                'Callback', @obj.startButtonServer_Callback);
                            uiextras.Empty('Parent', startStopServerHB);
                            uicontrol(...
                                'Parent', startStopServerHB,...
                                'Style', 'pushbutton', ...
                                'Tag', 'stopButtonServer',...
                                'Enable', 'off', ...
                                'String', 'Stop Server',...
                                'Callback', @obj.stopButtonServer_Callback);
                        set(startStopServerHB, 'Sizes', [-2 -1 -2]);
                        set(startStopHB, 'Sizes', [-2 -1 -2]);
                        set(startStopVB, 'Sizes', [-1 -2 -1]);
                    

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
        function setGageConfigFrontend(obj, gc)
            obj.myGageConfigFrontend = gc;
        end        
        function startButton_Callback(obj, src, eventData)
            obj.stream_initialize();
            obj.stream_takeNextPoint();
        end
        function startButtonServer_Callback(obj, src, eventData)
           obj.myServer = tcpip('0.0.0.0', 30000, 'NetworkRole', 'server', 'OutputBufferSize', 16536);
           fopen(obj.myServer);
           myHandles = guidata(obj.myTopFigure);
           setappdata(obj.myTopFigure, 'serverGood', 1);
           set(myHandles.startButtonServer, 'Enable', 'off');
           set(myHandles.stopButtonServer, 'Enable', 'on');     
        end
        function stopButtonServer_Callback(obj, src, eventData)
            fclose(obj.myServer);
            delete(obj.myServer);
            myHandles = guidata(obj.myTopFigure);
            setappdata(obj.myTopFigure, 'serverGood', 0);
            set(myHandles.startButtonServer, 'Enable', 'on');
            set(myHandles.stopButtonServer, 'Enable', 'off');     
        end
        function stream_initialize(obj)
            myHandles = guidata(obj.myTopFigure);
            set(myHandles.startButton, 'Enable', 'off');
            set(myHandles.stopButton, 'Enable', 'on');
            
                %Preallocate data
                tempNormData = zeros(1, 50);
                tempSummedData = zeros(1, 50);
                tempScanData = zeros(6, 50);
                
                
            %Create stuff for raw Plotting Later on
            aInfo = obj.myGageConfigFrontend.myGageConfig.acqInfo;
            sampleRate = aInfo.SampleRate;
            depth = aInfo.Depth;
            taxis = 1:depth;
            taxis = 1/sampleRate*taxis;
            
            setappdata(obj.myTopFigure, 'normData', tempNormData);
            setappdata(obj.myTopFigure, 'scanData', tempScanData);
            setappdata(obj.myTopFigure, 'summedData', tempSummedData);
            setappdata(obj.myTopFigure, 'runNum', 1);
            setappdata(obj.myTopFigure, 'taxis', taxis);
            guidata(obj.myTopFigure, myHandles);
        end
        function stream_takeNextPoint(obj)
            myHandles = guidata(obj.myTopFigure);
            tempNormData = getappdata(obj.myTopFigure, 'normData');
            tempScanData = getappdata(obj.myTopFigure, 'scanData');
            tempSummedData = getappdata(obj.myTopFigure, 'summedData');
            runNum = getappdata(obj.myTopFigure, 'runNum');
            taxis = getappdata(obj.myTopFigure, 'taxis');

            
            if runNum==1
                       systems = CsMl_Initialize;
                       CsMl_ErrorHandler(systems);
                       [ret, handle] = CsMl_GetSystem;  %this takes like 2 seconds
                       CsMl_ErrorHandler(ret);
            else
                handle = getappdata(obj.myTopFigure, 'gageHandle');
                tempH = getappdata(obj.myTopFigure, 'plottingHandles');
            end
            
            pointDone = 0; 
            while( getappdata(obj.myTopFigure, 'run') && ~pointDone)
                
                drawnow;
                %5. Call Gage Card to gather data
                [data,time,ret] = GageCard.GageMRecord(obj.myGageConfigFrontend.myGageConfig, handle, runNum);
                
                if ~getappdata(obj.myTopFigure, 'run')
                    ret = CsMl_FreeSystem(handle);
                    break;
                end
                %6. Call AnalyzeRawData
                size(reshape(data{1,2}, [1 length(data{1,2})]))
                scanDataCH1 = obj.analyzeRawData(data(1,:));
                scanDataCH2 = obj.analyzeRawDataBLUE(data(2,:));
                %7. Clear the Raw Plots, Plot the Raw Plots
                temp7 = reshape(data{1,2}, [1 length(data{1,2})]);
                temp8 = reshape(data{1,3}, [1 length(data{1,3})]);
                temp9 = reshape(data{1,4}, [1 length(data{1,4})]);
                temp10 = reshape(data{2,2}, [1 length(data{2,2})]);
                temp11 = reshape(data{2,3}, [1 length(data{2,3})]);
                temp12 = reshape(data{2,4}, [1 length(data{2,4})]);
                stepSize = 1;%floor(length(data{1,2})/50); %Trying to decrease the number of plotted points
                if runNum == 1
                    tempH(7) = plot(myHandles.rGSAxes, taxis(1:stepSize:length(data{1,2})), ...
                                temp7(1:stepSize:end));

                    tempH(8) = plot(myHandles.rEAxes, taxis(1:stepSize:length(data{1,3})), ...
                                temp8(1:stepSize:end));

                    tempH(9) = plot(myHandles.rBGAxes, taxis(1:stepSize:length(data{1,4})), ...
                                temp9(1:stepSize:end));

                    tempH(10) = plot(myHandles.rBGSAxes, taxis(1:stepSize:length(data{2,2})), ...
                                temp10(1:stepSize:end));

                    tempH(11) = plot(myHandles.rBEAxes, taxis(1:stepSize:length(data{2,3})), ...
                                temp11(1:stepSize:end));

                    tempH(12) = plot(myHandles.rBBGAxes, taxis(1:stepSize:length(data{2,4})), ...
                                temp12(1:stepSize:end));
                else
                    set(tempH(7), 'XData',  taxis(1:stepSize:length(data{1,2})));
                    set(tempH(7), 'YData', temp7(1:stepSize:end));
                    set(tempH(8), 'XData',  taxis(1:stepSize:length(data{1,3})));
                    set(tempH(8), 'YData', temp8(1:stepSize:end));
                    set(tempH(9), 'XData',  taxis(1:stepSize:length(data{1,4})));
                    set(tempH(9), 'YData', temp9(1:stepSize:end));
                    set(tempH(10), 'XData',  taxis(1:stepSize:length(data{2,2})));
                    set(tempH(10), 'YData', temp10(1:stepSize:end));
                    set(tempH(11), 'XData',  taxis(1:stepSize:length(data{2,3})));
                    set(tempH(11), 'YData', temp11(1:stepSize:end));
                    set(tempH(12), 'XData',  taxis(1:stepSize:length(data{2,4})));
                    set(tempH(12), 'YData', temp12(1:stepSize:end));

                end
                %8. Update Scan Plots
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
                
                if getappdata(obj.myTopFigure, 'serverGood')
                    % PREPARE ARRAY OF DATA TO STREAM
                    tic
                    stepSize = floor(length(data{1,2})/100); %Trying to decrease the number of plotted points
                    tStep = taxis(3*stepSize)- taxis(2*stepSize);
                    lengthEach = length(temp7(1:stepSize:end));
                    dataToStream = zeros(1+6+6*100,1);
                    dataToStream(1:8) = [str2num(time) tSCdat12 tSCdat3 tSCdat456 tStep];
                    dataToStream(9:8+lengthEach) = temp7(1:stepSize:end);
                    dataToStream(9+1*lengthEach:8+2*lengthEach) = temp8(1:stepSize:end);
                    dataToStream(9+2*lengthEach:8+3*lengthEach) = temp9(1:stepSize:end);
                    dataToStream(9+3*lengthEach:8+4*lengthEach) = temp10(1:stepSize:end);
                    dataToStream(9+4*lengthEach:8+5*lengthEach) = temp11(1:stepSize:end);
                    dataToStream(9+5*lengthEach:8+6*lengthEach) = temp12(1:stepSize:end);
                    % STREAM DATA ACROSS THE NETWORK
                    try
                          fwrite(obj.myServer, dataToStream, 'double');
                          disp(['Number of bytes sent: ' num2str(length(dataToStream)*8 + 2)])
                    catch
                        obj.stopButtonServer_callback();
                    end
                    toc
                end
                
                
                if runNum == 1  %First time you have to plot....the rest of the time we will "refreshdata"
                    tempH(1) = plot(myHandles.sNormAxes, tempNormData, '-ok', 'LineWidth', 3);
                    tempH(2) = plot(myHandles.sEAxes, tempScanData(2,:), '-or', 'LineWidth', 2);
                    tempH(3) = plot(myHandles.sGAxes, tempScanData(1,:), '-ob', 'LineWidth', 2);
                    tempH(4) = plot(myHandles.sBGAxes, tempScanData(3,:), '-ob', 'LineWidth', 1);
                    tempH(5) = plot(myHandles.sSummedAxes, tempSummedData, '-og', 'LineWidth', 2);
                elseif runNum > 1
                    set(tempH(1), 'YData', tempNormData);
                    set(tempH(2), 'YData', tempScanData(2,:));
                    set(tempH(3), 'YData', tempScanData(1,:));
                    set(tempH(4), 'YData', tempScanData(3,:));
                    set(tempH(5), 'YData', tempSummedData);
                end
                data = [];
                
                if ~getappdata(obj.myTopFigure, 'run')
                   ret = CsMl_FreeSystem(handle);
                end
                pointDone = 1;
            end
            if (getappdata(obj.myTopFigure, 'run')) % Prepare for a new data point
                if runNum == 1
                    setappdata(obj.myTopFigure, 'gageHandle', handle);
                end
                runNum = runNum + 1;
                setappdata(obj.myTopFigure, 'normData', tempNormData);
                setappdata(obj.myTopFigure, 'scanData', tempScanData);
                setappdata(obj.myTopFigure, 'summedData', tempSummedData);
                setappdata(obj.myTopFigure, 'runNum', runNum);
                setappdata(obj.myTopFigure, 'plottingHandles', tempH);
                
                guidata(obj.myTopFigure, myHandles);
                
                %Destroy any timers that might exist
                if ~isempty(timerfind)
                    stop(timerfind);
                    delete(timerfind);
                end
                %Create startup timer - This HAS to be done this way in
                %order to get around a plotting bug in Matlab specific to
                %windows XP
                t = timer('TimerFcn',@(x,y) stream_takeNextPoint(obj), 'StartDelay', 0.1);
                start(t);
            else %close everything done
                if ~isempty(timerfind)
                    stop(timerfind);
                    delete(timerfind);
                end
                delete(timerfind);
                    %10. If ~Run, make obvious and reset 'run'
                    if ~getappdata(obj.myTopFigure, 'run')
                        try
                            ret = CsMl_FreeSystem(handle);
                        catch
                        end
                        disp('Acquisistion Stopped');
                        setappdata(obj.myTopFigure, 'run', 1);
                        drawnow;
                    end
                    %Make obvious that the scan stopped
                    set(myHandles.startButton, 'Enable', 'on');
                    set(myHandles.stopButton, 'Enable', 'off');
                    
%                     rmappdata(obj.myTopFigure, 'normData'); % keep for fitting later on
                    rmappdata(obj.myTopFigure, 'scanData');
                    rmappdata(obj.myTopFigure, 'summedData');
                    rmappdata(obj.myTopFigure, 'runNum');
                    rmappdata(obj.myTopFigure, 'taxis');
                    rmappdata(obj.myTopFigure, 'gageHandle');
                    rmappdata(obj.myTopFigure, 'plottingHandles');
                    
                    drawnow;

                    guidata(obj.myTopFigure, myHandles);
                    
                    clear variables %Fixing memory leak?
                    clear mex
            end
        end
        function stopButton_Callback(obj, src, eventData)
            setappdata(obj.myTopFigure, 'run', 0);
        end
        function scanData = analyzeRawData(obj, data)
            scanData = cellfun(@sum, data);
        end
        function scanData = analyzeRawDataBLUE(obj, data)
            scanData = cellfun(@mean, data);
        end
        function quit(obj)
            obj.myGageConfigFrontend = [];
            obj.myTopFigure = [];
            delete(obj.myPanel);
        end
        function saveState(obj)
            myHandles = guidata(obj.myTopFigure);
            save FreqSweeperState;
        end
        function loadState(obj)
            try
                load FreqSweeperState
                myHandles = guidata(obj.myTopFigure);
                guidata(obj.myTopFigure, myHandles);
            catch
                disp('No saved state for FreqSweeper Exists');
            end
        end
    end
    
end

