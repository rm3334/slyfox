classdef TimeSynth < hgsetget
    %TIMESYNTH Arbitrary Waveform Pulse Generator
    %   Arbitrary Waveform Pulse Generator Used for Rabi Flopping
    
    properties
        myPanel = uiextras.Panel();
        myDEBUGmode = 0;
        myTopFigure = [];
        myVISAconstructor = [];
        myVISAobject = [];
    end
    
    methods
        function obj = TimeSynth(top,f)
            obj.myTopFigure = top;
            obj.myDEBUGmode = getappdata(obj.myTopFigure, 'DEBUGMODE');
            set(obj.myPanel, 'Parent', f);
            h0 = uiextras.VBox('Parent', obj.myPanel, 'Tag', 'timeGrid');
            
            info = instrhwinfo('visa', 'ni');
            visaCMD = uicontrol(...
                'Parent', h0, ...
                'Tag', 'visaCMDTime', ...
                'Style', 'popup', ...
                'String', info.ObjectConstructorName, ...
                'Callback', @obj.updateTimeSynth);
            
            h1 = uiextras.HBox('Parent', h0, 'Tag', 'timeGrid');
            testBP = uiextras.BoxPanel(...
                'Parent', h1,...
                'Tag', 'testBPTime',...
                'Title', 'Test Communication');
                testVB = uiextras.VBox(...
                    'Parent', testBP);
                testHB = uiextras.HBox(...
                    'Parent', testVB);
                uicontrol(...
                    'Parent', testHB,...
                    'Style', 'pushbutton', ...
                    'Tag', 'testVISATime',...
                    'String', '*IDN?',...
                    'Callback', @obj.testVISAcommunication);
                uicontrol(...
                    'Parent', testHB,...
                    'Style', 'edit',...
                    'Tag', 'testVISAreplyTime');
                set(testHB, 'Sizes', [-1 -3], 'Spacing', 5);
                uiextras.Empty('Parent', testVB);
                set(testVB, 'Sizes', [-1 -9], 'Spacing', 5);
            
          
            myHandles = guihandles(top);
            guidata(top, myHandles);
            obj.loadState();
        end
        function updateTimeSynth(hObject, eventData, varargin)
            myHandles = guidata(hObject.myTopFigure);
            tVal = get(myHandles.visaCMDTime, 'Value');
            tStrings = get(myHandles.visaCMDTime, 'String');
            if ~isempty(hObject.myVISAobject)
                hObject.close();
            end
            hObject.myVISAconstructor = tStrings{tVal};
        end
        function testVISAcommunication(hObject, eventData, varargin)
            hObject.updateTimeSynth(1);
            myHandles = guidata(hObject.myTopFigure);
            vtest = eval(hObject.myVISAconstructor);
            try
                fopen(vtest);
                fprintf(vtest, '*IDN?');
                idn = fscanf(vtest);
                set(myHandles.testVISAreplyTime, 'String', idn(1:35));
                fclose(vtest);
                delete(vtest);
                clear vtest;
            catch
                try
                    delete(vtest)
                catch
                end
                if hObject.myDEBUGmode == 1
                    set(myHandles.testVISAreply, 'String', 'DEBUGMODE')
                else
                    set(myHandles.testVISAreply, 'String', 'ERROR')
                end
            end
        end
        function initialize(obj)
            if obj.myDEBUGmode ~= 1
                obj.updateTimeSynth(1);
                g = eval(obj.myVISAconstructor);
                fopen(g);
                obj.myVISAobject = g;
            end
        end
        function realPulseTime = setSinglePulse(obj, delayTime, pulseTime)
            try
                delayTime = delayTime*1e-3;
                pulseTime = pulseTime*1e-3;
                totalTime = delayTime + pulseTime; %s


                N = ceil(totalTime/16300*40000000);
                frequency = 40000000/N;

                delayTimeRAM = int16(ceil(delayTime*frequency));
                if delayTimeRAM == 0
                    delayTimeRAM = 1;
                end
                pulseTimeRAM = int16(ceil(pulseTime*frequency));
                endOffsetRAM = 16300 - delayTimeRAM - pulseTimeRAM;
                if endOffsetRAM < 0
                    delayTimeRAM = int16(floor(delayTime*frequency));
                    if delayTimeRAM == 0
                        delayTimeRAM = 1;
                    end
                    pulseTimeRAM = int16(floor(pulseTime*frequency));
                    endOffsetRAM = 16300 - delayTimeRAM - pulseTimeRAM;
                end
                
                realPulseTime = double(pulseTimeRAM)/frequency;
                if endOffsetRAM == 0
                    if pulseTimeRAM > 1 && delayTimeRAM > 5
                        data = [0, 0, ...
                            1, 0, ...
                            2, 0, ...
                            3, 0, ...
                            4, 0, ...
                            16299-pulseTimeRAM, 0, ...
                            16300-pulseTimeRAM, 2047, ...
                            16299, 2047];
                    elseif delayTimeRAM < 5
                        data = [...
                            16299-pulseTimeRAM, 0, ...
                            16300-pulseTimeRAM, 2047, ...
                            16294, 2047, ...
                            16295, 2047, ...
                            16296, 2047, ...
                            16297, 2047, ...
                            16298, 2047, ...
                            16299, 2047];
                    elseif pulseTimeRAM == 1
                            data = [0, 0, ...
                            1, 0, ...
                            2, 0, ...
                            3, 0, ...
                            4, 0, ...
                            5, 0, ...
                            16299-pulseTimeRAM, 0, ...
                            16300-pulseTimeRAM, 2047];
                    end
                else
                    if pulseTimeRAM > 1 && delayTimeRAM >= 4
                        data = [0, 0, ...
                            1, 0, ...
                            2, 0, ...
                            3, 0, ...
                            16299-endOffsetRAM - pulseTimeRAM, 0, ...
                            16300-endOffsetRAM - pulseTimeRAM, 2047, ...
                            16299-endOffsetRAM, 2047, ...
                            16299-(endOffsetRAM -1), 0];
                    elseif delayTimeRAM > 0 && delayTimeRAM < 4
                        data = [...
                            16299-endOffsetRAM - pulseTimeRAM, 0, ...
                            16300-endOffsetRAM - pulseTimeRAM, 2047, ...
                            16295-endOffsetRAM, 2047, ...
                            16296-endOffsetRAM, 2047, ...
                            16297-endOffsetRAM, 2047, ...
                            16298-endOffsetRAM, 2047, ...
                            16299-endOffsetRAM, 2047, ...
                            16299-(endOffsetRAM -1), 0];
                    elseif pulseTimeRAM == 1
                            data = [0, 0, ...
                            1, 0, ...
                            2, 0, ...
                            3, 0, ...
                            4, 0, ...
                            5, 0, ...
                            16298-endOffsetRAM - pulseTimeRAM, 0, ...
                            16299-endOffsetRAM - pulseTimeRAM, 2047, ...
                            16299-endOffsetRAM, 0, ...
                            16299-(endOffsetRAM -1), 0];
                    end
                end
                data = double(data);

                checksum = sum(data);
                while checksum > 65535
                    checksum = checksum - 65536;
                end
                data = [data, checksum];
tic
                pause(0.3)
                fprintf(obj.myVISAobject, ['LDWF?1,' int2str((length(data)-1)/2) ]);
                fscanf(obj.myVISAobject);
                fwrite(obj.myVISAobject,data(1:end-1),'int16');
                fwrite(obj.myVISAobject,data(end),'uint16');
                fprintf(obj.myVISAobject, 'MENA 0');
                fprintf(obj.myVISAobject, 'FUNC 5'); % Function - Arb
                fprintf(obj.myVISAobject, 'MTYP 5'); % Modulation Type - Burst
                fprintf(obj.myVISAobject, ['FSMP ' num2str(frequency)]); % Stepping Frequency
                fprintf(obj.myVISAobject, 'TSRC 2'); % Trigger Source - Single (0) - Positive Slope (2) - for testing
                fprintf(obj.myVISAobject, 'MENA 1'); % Enable Modulation
                toc
            catch
                if obj.myDEBUGmode ~= 1
                    errordlg('Abandon hope, could not set Time.')
                    ret = 0;
                else
                    ret = 1;
                end
            end
        end
        function close(obj)
            if obj.myDEBUGmode ~= 1
                fclose(obj.myVISAobject);
                delete(obj.myVISAobject);
                obj.myVISAobject = [];
            end
        end
        function quit(obj)
            delete(obj.myPanel);
            obj.myPanel = [];
            obj.myTopFigure = [];
%             try
%                 obj.close()
%             catch
%             end
        end
        function loadState(obj)
            try
                load TimeSynthState
                myHandles = guidata(obj.myTopFigure);
                set(myHandles.visaCMDTime, 'Value', TimeSynthState.myVISAcmd);
                obj.updateTimeSynth(1);
                guidata(obj.myTopFigure, myHandles);
            catch
                disp('No previous TimeSynthState detected');
            end
        end
        function saveState(obj)
            myHandles = guidata(obj.myTopFigure);
            TimeSynthState.myVISAcmd = get(myHandles.visaCMDTime, 'Value');
            save TimeSynthState
        end
    end
    
end

