classdef FreqSynth < hgsetget
    %FREQSYNTH Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        myGPIBvendor = 'ni'
        myGPIBboard = 0;
        myGPIBinstrumentAddress = 7;
        myFreqCommand = 'FREQ';
        myPanel = uiextras.Panel();
        myTopFigure = [];
        myGPIBobject = [];
    end
    
    methods
        function obj = FreqSynth(top,f)
            obj.myTopFigure = top;
            set(obj.myPanel, 'Parent', f);
            h1 = uiextras.Grid('Parent', obj.myPanel, 'Tag', 'freqGrid');
            
            bAddrBP = uiextras.BoxPanel(...
                'Parent', h1,...
                'Tag', 'baddrBP',...
                'Title', 'Board Address');
                bAddrVB = uiextras.VBox(...
                    'Parent', bAddrBP);
                uicontrol(...
                    'Parent', bAddrVB, ...
                    'Style', 'edit', ...
                    'Tag', 'boardAddress', ...
                    'String', '0',...
                    'BackgroundColor', 'White', ...
                    'Callback', @obj.updateFreqSynth);
                uiextras.Empty('Parent', bAddrVB);
                set(bAddrVB, 'Sizes', [-1 -9], 'Spacing', 5);
            
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
                    'Tag', 'testGPIB',...
                    'String', '*IDN?',...
                    'Callback', @obj.testGPIBcommunication);
                uicontrol(...
                    'Parent', testHB,...
                    'Style', 'edit',...
                    'Tag', 'testGPIBreply');
                set(testHB, 'Sizes', [-1 -3], 'Spacing', 5);
                uiextras.Empty('Parent', testVB);
                set(testVB, 'Sizes', [-1 -9], 'Spacing', 5);
            
            instAddrBP = uiextras.BoxPanel(...
                'Parent', h1,...
                'Tag', 'instaddrBP',...
                'Title', 'Instrument Address');
                instAddrVB = uiextras.VBox(...
                    'Parent', instAddrBP);
                uicontrol(...
                    'Parent', instAddrVB, ...
                    'Style', 'edit', ...
                    'Tag', 'instrumentAddress', ...
                    'String', '7',...
                    'BackgroundColor', 'White', ...
                    'Callback', @obj.updateFreqSynth);
                uiextras.Empty('Parent', instAddrVB);
                set(instAddrVB, 'Sizes', [-1 -9], 'Spacing', 5);
            
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
          
            set( h1, 'ColumnSizes', [-1 -1], 'RowSizes', [-1 -1] );
            myHandles = guihandles(top);
            guidata(top, myHandles);
            obj.loadState();
        end
        function updateFreqSynth(hObject, eventData, varargin)
            myHandles = guidata(hObject.myTopFigure);
            hObject.myGPIBboard = str2double(get(myHandles.boardAddress, 'String'));
            hObject.myGPIBinstrumentAddress = str2double(get(myHandles.instrumentAddress, 'String'));
            hObject.myFreqCommand = get(myHandles.frequencyCommand, 'String');
        end
        function testGPIBcommunication(hObject, eventData, varargin)
            hObject.updateFreqSynth(1);
            myHandles = guidata(hObject.myTopFigure);
            gtest = gpib(hObject.myGPIBvendor, hObject.myGPIBboard, hObject.myGPIBinstrumentAddress);
            try
                fopen(gtest);
                fprintf(gtest, '*IDN?');
                idn = fscanf(gtest);
                set(myHandles.testGPIBreply, 'String', idn(1:35));
                fclose(gtest);
                delete(gtest);
                clear gtest;
            catch
                try
                    delete(gtest)
                catch
                end
                set(myHandles.testGPIBreply, 'String', 'ERROR')
            end
        end
        function initialize(obj)
            obj.updateFreqSynth(1);
            g = gpib(obj.myGPIBvendor, obj.myGPIBboard, obj.myGPIBinstrumentAddress);
            fopen(g);
            obj.myGPIBobject = g;
        end
        function close(obj)
            fclose(obj.myGPIBobject);
            delete(obj.myGPIBobject);
            obj.myGPIBobject = [];
        end
        function ret = setFrequency(obj, newFreqStr)
            try
                fprintf(obj.myGPIBobject, [obj.myFreqCommand, ' ', newFreqStr]);
                ret = 1;
            catch
                errordlg('Abandon hope, could not set frequency.')
                ret = 0;
            end
        end
        function curFreq = readFrequency(obj)
            try
                fprintf(obj.myGPIBobject, [obj.myFreqCommand, '?'])
                curFreq = fscanf(obj.myGPIBobject);
            catch
                errordlg('Frequency? Never heard of her')
            end
        end
        function quit(obj)
            delete(obj.myPanel);
            obj.myTopFigure = [];
            try
                obj.close()
            catch
            end
        end
        function loadState(obj)
            try
                load FreqSynthState
                myHandles = guidata(obj.myTopFigure);
                set(myHandles.boardAddress, 'String', FreqSynthState.myGPIBboard);
                set(myHandles.instrumentAddress, 'String', FreqSynthState.myGPIBinstrumentAddress);
                set(myHandles.frequencyCommand, 'String', FreqSynthState.myFreqCommand);
                obj.updateFreqSynth(1);
                guidata(obj.myTopFigure, myHandles);
            catch
                disp('No previous FreqSynthState detected');
            end
        end
        function saveState(obj)
            myHandles = guidata(obj.myTopFigure);
            FreqSynthState.myGPIBboard = get(myHandles.boardAddress, 'String');
            FreqSynthState.myGPIBinstrumentAddress = get(myHandles.instrumentAddress, 'String');
            FreqSynthState.myFreqCommand = get(myHandles.frequencyCommand, 'String');
            save FreqSynthState
        end
    end
    
end

