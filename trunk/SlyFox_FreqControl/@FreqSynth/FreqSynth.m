classdef FreqSynth < hgsetget
    %FREQSYNTH Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        myFreqCommand = 'FREQ';
        myPanel = uiextras.Panel('Tag', 'poop');
        myDEBUGmode = 0;
        myTopFigure = [];
        myVISAconstructor = [];
        myVISAobject = [];
        myTimeSynth = [];
    end
    
    methods
        function obj = FreqSynth(top,f)
            obj.myTopFigure = top;
            obj.myDEBUGmode = getappdata(obj.myTopFigure, 'DEBUGMODE');
            set(obj.myPanel, 'Parent', f);
            h0 = uiextras.VBox('Parent', obj.myPanel, 'Tag', 'freqGrid');
            
            info = instrhwinfo('visa', 'ni');
            visaCMD = uicontrol(...
                'Parent', h0, ...
                'Tag', 'visaCMD', ...
                'Style', 'popup', ...
                'String', [{'Use Time Synth Object'}; info.ObjectConstructorName], ...
                'Callback', @obj.updateFreqSynth);
            
            h1 = uiextras.HBox('Parent', h0, 'Tag', 'freqGrid');
            testBP = uiextras.BoxPanel(...
                'Parent', h1,...
                'Tag', 'testBP',...
                'Title', 'Test Communication');
                testVB = uiextras.VBox(...
                    'Parent', testBP);
                testHB = uiextras.HBox(...
                    'Parent', testVB);
                uicontrol(...
                    'Parent', testHB,...
                    'Style', 'pushbutton', ...
                    'Tag', 'testVISA',...
                    'String', '*IDN?',...
                    'Callback', @obj.testVISAcommunication);
                uicontrol(...
                    'Parent', testHB,...
                    'Style', 'edit',...
                    'Tag', 'testVISAreply');
                set(testHB, 'Sizes', [-1 -3], 'Spacing', 5);
                uiextras.Empty('Parent', testVB);
                set(testVB, 'Sizes', [-1 -9], 'Spacing', 5);
            
            
            freqComBP = uiextras.BoxPanel(...
                'Parent', h1,...
                'Tag', 'freqComBP',...
                'Title', 'Frequency Command');
                freqComVB = uiextras.VBox(...
                    'Parent', freqComBP);
                uicontrol(...
                    'Parent', freqComVB, ...
                    'Style', 'edit', ...
                    'Tag', 'frequencyCommand', ...
                    'String', 'FREQ',...
                    'BackgroundColor', 'White', ...
                    'Callback', @obj.updateFreqSynth);
                uiextras.Empty('Parent', freqComVB);
                set(freqComVB, 'Sizes', [-1 -9], 'Spacing', 5);
          
            myHandles = guihandles(top);
            guidata(top, myHandles);
            obj.loadState();
        end
        function setTimeSynth(obj, tSynth)
            obj.myTimeSynth = tSynth;
        end
        function updateFreqSynth(hObject, eventData, varargin)
            myHandles = guidata(hObject.myTopFigure);
            tVal = get(myHandles.visaCMD, 'Value');
            tStrings = get(myHandles.visaCMD, 'String');
            
            if tVal == 1 %use time synth is selected
                hObject.myTimeSynth.updateTimeSynth();
                hObject.myVISAobject = hObject.myTimeSynth.myVISAobject;
            else
                if ~isempty(hObject.myVISAobject)
                    hObject.close();
                end
                hObject.myVISAconstructor = tStrings{tVal};
                hObject.myFreqCommand = get(myHandles.frequencyCommand, 'String');
            end
        end
        function testVISAcommunication(hObject, eventData, varargin)
            hObject.updateFreqSynth(1);
            myHandles = guidata(hObject.myTopFigure);
            tVal = get(myHandles.visaCMD, 'Value');
            if tVal ~= 1
                vtest = eval(hObject.myVISAconstructor);
                try
                    fopen(vtest);
                    fprintf(vtest, '*IDN?');
                    idn = fscanf(vtest);
                    set(myHandles.testVISAreply, 'String', idn(1:35));
                    fclose(vtest);
                    delete(vtest);
                    clear vtest;
                catch
                    try
                        delete(vtest)
                    catch err
                    end
                    if hObject.myDEBUGmode == 1
                        set(myHandles.testVISAreply, 'String', 'DEBUGMODE')
                    else
                        set(myHandles.testVISAreply, 'String', 'ERROR')
                    end
                end
            end
        end
        function initialize(obj)
            if obj.myDEBUGmode ~= 1
                if tVal ~= 1
                    obj.updateFreqSynth(1);
                    g = eval(obj.myVISAconstructor);
                    fopen(g);
                    obj.myVISAobject = g;
                else
                    obj.myTimeSynth.initialize();
                    obj.myVISAobject = obj.myTimeSynth.myVISAobject;
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
        function ret = setFrequency(obj, newFreqStr)
            try
                fprintf(obj.myVISAobject, [obj.myFreqCommand, ' ', newFreqStr]);
                ret = 1;
            catch
                if obj.myDEBUGmode ~= 1
                    errordlg('Abandon hope, could not set frequency.')
                    ret = 0;
                else
                    ret = 1;
                end
            end
        end
        function curFreq = readFrequency(obj)
            try
                fprintf(obj.myVISAobject, [obj.myFreqCommand, '?'])
                curFreq = fscanf(obj.myVISAobject);
            catch
                if obj.myDEBUGmode ~= 1
                    errordlg('Frequency? Never heard of her')
                else
                    curFreq = 10;
                end
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
                load FreqSynthState
                myHandles = guidata(obj.myTopFigure);
                set(myHandles.visaCMD, 'Value', FreqSynthState.myVISAcmd);
                set(myHandles.frequencyCommand, 'String', FreqSynthState.myFreqCommand);
                obj.updateFreqSynth(1);
                guidata(obj.myTopFigure, myHandles);
            catch
                disp('No previous FreqSynthState detected');
            end
        end
        function saveState(obj)
            myHandles = guidata(obj.myTopFigure);
            FreqSynthState.myVISAcmd = get(myHandles.visaCMD, 'Value');
            FreqSynthState.myFreqCommand = get(myHandles.frequencyCommand, 'String');
            save FreqSynthState
        end
    end
    
end

