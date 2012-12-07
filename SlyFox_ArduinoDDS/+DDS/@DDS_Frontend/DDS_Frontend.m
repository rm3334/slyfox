classdef DDS_Frontend < hgsetget
    %DDS_FRONTEND GUI for controlling a DDS_Config Object
    %   DDS_Frontend has a panel and a DDS_Config object. In the panel it
    %   has many controls to change the various parameters of a DDS_Config
    %   object and also to change the characteristics of the DDS output.
    %   Written by Ben Bloom 10/4/2011
    
    properties
        myTopFigure = [];
        myTitlePanel = [];
        mySuperPanel = [];
        myPanel = [];
        myDDS;
        mySerial;
        myBoardAddr;
        myCurrentMode = 1;
        myAvailableModes = {'Single Tone', 'FSK', 'Ramped FSK', 'Chirp', 'BPSK'};
        myCurrentRegister = 1;
    end
    
    methods
        function obj = DDS_Frontend(topFig, parentObj, boardAddr)
            obj.myTopFigure = topFig;
            obj.myTitlePanel = uiextras.Panel('Parent', parentObj, ...
                'Title', ['DDS' num2str(boardAddr)]);
            %%sara edits!%%
            obj.mySuperPanel = uiextras.VBox('Parent', obj.myTitlePanel, ...
                'Spacing', 5, ...
                'Padding', 5);
            %%%%%%%
            obj.myPanel = uiextras.HBox('Parent', obj.mySuperPanel, ...
                'Spacing', 5, ...
                'Padding', 5);
            obj.myDDS = DDS.DDS_Config(boardAddr);
            obj.myBoardAddr = boardAddr;
            
            buttonVBox = uiextras.VBox('Parent', obj.myPanel, ...
                'Spacing', 5, ...
                'Padding', 5);
                uiextras.Empty('Parent', buttonVBox);
                uicontrol(...
                           'Parent', buttonVBox,...
                           'Style', 'popupmenu', ...
                           'Tag', 'cardList',...
                           'String', {'AD9854'});
                uicontrol(...
                                'Parent', buttonVBox,...
                                'Style', 'pushbutton', ...
                                'Tag', 'sendCommand',...
                                'String', 'Send Command',...
                                'Callback', @obj.sendCommand_Callback);
                sysClkHB = uiextras.HBox('Parent', buttonVBox, ...
                    'Padding', 5, ...
                    'Spacing', 5);
                    uicontrol(...
                        'Parent', sysClkHB, ...
                        'Style', 'text', ...
                        'String', 'SysCLK (MHz)');
                    uicontrol(...
                        'Parent', sysClkHB, ...
                        'Style', 'edit', ...
                        'String', '200', ...
                        'Tag', ['sysClk' num2str(obj.myBoardAddr)]);
                setDefaultButton = uicontrol( ...
                            'Parent', buttonVBox,...
                            'Style', 'pushbutton', ...
                            'Tag', ['setDefault' num2str(obj.myBoardAddr)],...
                            'String', 'Set Default',...
                            'Callback', @obj.setDefaultButton_Callback);
                reinitializeDDS = uicontrol( ...
                            'Parent', buttonVBox,...
                            'Style', 'pushbutton', ...
                            'Tag', ['reinitializeDDS' num2str(obj.myBoardAddr)],...
                            'String', 'Reinitialize DDS',...
                            'Callback', @obj.reinitializeDDS_Callback);
                uiextras.Empty('Parent', buttonVBox);
                set(buttonVBox, 'Sizes', [-3 -1 -2 -1 -1 -1 -3]);
                

                
            modeTabPanel = uiextras.TabPanel('Parent', obj.myPanel, ...
                'Tag', 'modeTabPanel', ...
                'Callback', @obj.modeTabPanel_Callback);
            
                stVB = uiextras.VBox('Parent', modeTabPanel);
                    uiextras.Empty('Parent', stVB);
                    stHB = uiextras.HBox('Parent', stVB, ...
                        'Spacing', 5, ...
                        'Padding', 5);
                        textVB = uiextras.VBox('Parent', stHB);
                            uiextras.Empty('Parent', textVB);
                            uicontrol(...
                                'Parent', textVB,...
                                'Style', 'text', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.5, ...
                                'String', 'Frequency (MHz)');
                            uiextras.Empty('Parent', textVB);
                            textVB.Sizes = [-1 -4 -1];
                        uicontrol(...
                            'Parent', stHB,...
                            'Style', 'edit', ...
                            'Tag', ['stFTW' num2str(obj.myBoardAddr)],...
                            'FontUnits', 'normalized', ...
                            'FontSize', 0.5, ...
                            'String', '75.000000');
                        stHB.Sizes = [-2 -1];
                    uiextras.Empty('Parent', stVB);
                    stVB.Sizes = [-2 -1 -2];
                FSKVB = uiextras.VBox('Parent', modeTabPanel, ...
                    'Spacing', 5, ...
                    'Padding', 5);
                    FSKHBcontrol = uiextras.HBox('Parent', FSKVB);
                        uiextras.Empty('Parent', FSKHBcontrol);
                        fskSetVB = uiextras.VBox('Parent', FSKHBcontrol);
                            uiextras.Empty('Parent', fskSetVB);
                            uicontrol(...
                                'Parent', fskSetVB, ...
                                'Style', 'popupmenu', ...
                                'Tag', ['FSKsetting' num2str(obj.myBoardAddr)], ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.2, ...
                                'String', {'Send F1&F2', ...
                                    'Send F1', ...
                                    'Send F2', ...
                                    'Pseudo-Single Tone'}, ...
                                'Callback', @obj.FSKsetting_Callback);
                            uiextras.Empty('Parent', fskSetVB);
                            fskSetVB.Sizes = [-1 -3 -1];
                        uiextras.Empty('Parent', FSKHBcontrol);
                    FSKHB0 = uiextras.HBox('Parent', FSKVB, ...
                        'Spacing', 5, ...
                        'Padding', 5);
                        text2VB = uiextras.VBox('Parent', FSKHB0);
                            uiextras.Empty('Parent', text2VB);
                            uicontrol(...
                                'Parent', text2VB,...
                                'Style', 'text', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.6, ...
                                'String', 'Frequency 1 (MHz)');
                            uiextras.Empty('Parent', text2VB);
                            text2VB.Sizes = [-1 -4 -1];
                        uicontrol(...
                            'Parent', FSKHB0,...
                            'Style', 'edit', ...
                            'Tag', ['fskFTW1' num2str(obj.myBoardAddr)],...
                            'FontUnits', 'normalized', ...
                            'FontSize', 0.6, ...
                            'String', '70.000000');
                        FSKHB0.Sizes = [-2 -1];
                    uiextras.Empty('Parent', FSKVB);
                    FSKHB1 = uiextras.HBox('Parent', FSKVB, ...
                        'Spacing', 5, ...
                        'Padding', 5);
                        text3VB = uiextras.VBox('Parent', FSKHB1);
                            uiextras.Empty('Parent', text3VB);
                            uicontrol(...
                                'Parent', text3VB,...
                                'Style', 'text', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.6, ...
                                'String', 'Frequency 2 (MHz)');
                            uiextras.Empty('Parent', text3VB);
                            text3VB.Sizes = [-1 -4 -1];
                        uicontrol(...
                            'Parent', FSKHB1,...
                            'Style', 'edit', ...
                            'Tag', ['fskFTW2' num2str(obj.myBoardAddr)],...
                            'FontUnits', 'normalized', ...
                            'FontSize', 0.6, ...
                            'String', '80.000000');
                        FSKHB1.Sizes = [-2 -1];
                    uiextras.Empty('Parent', FSKVB);
                    FSKVB.Sizes = [-2 -1 -2 -1 -2];
                rFSKGrid = uiextras.VBox('Parent', modeTabPanel);
                CHIRPVB = uiextras.VBox('Parent', modeTabPanel, ...
                    'Spacing', 5, ...
                    'Padding', 5);
                    CHIRPHBcontrol = uiextras.HBox('Parent', CHIRPVB);
                        uiextras.Empty('Parent', CHIRPHBcontrol);
                        chirpSetVB = uiextras.VBox('Parent', CHIRPHBcontrol);
                            uiextras.Empty('Parent', chirpSetVB);
                            uicontrol(...
                                'Parent', chirpSetVB, ...
                                'Style', 'popupmenu', ...
                                'Tag', ['CHIRPsetting' num2str(obj.myBoardAddr)], ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.2, ...
                                'String', {'Send Base Frequency', ...
                                'Send Slope'});
                            uiextras.Empty('Parent', chirpSetVB);
                            chirpSetVB.Sizes = [-1 -3 -1];
                        uiextras.Empty('Parent', CHIRPHBcontrol);
                    CHIRPHB0 = uiextras.HBox('Parent', CHIRPVB, ...
                        'Spacing', 5, ...
                        'Padding', 5);
                        text3VB = uiextras.VBox('Parent', CHIRPHB0);
                            uiextras.Empty('Parent', text3VB);
                            uicontrol(...
                                'Parent', text3VB,...
                                'Style', 'text', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.6, ...
                                'String', 'Slope (mHz/sec)');
                            uiextras.Empty('Parent', text3VB);
                            text3VB.Sizes = [-1 -4 -1];
                        uicontrol(...
                            'Parent', CHIRPHB0,...
                            'Style', 'edit', ...
                            'Tag', ['chirpSlope' num2str(obj.myBoardAddr)],...
                            'FontUnits', 'normalized', ...
                            'FontSize', 0.6, ...
                            'String', '70.000000');
                        CHIRPHB0.Sizes = [-2 -1];
                    uiextras.Empty('Parent', CHIRPVB);
                    CHIRPHB1 = uiextras.HBox('Parent', CHIRPVB, ...
                        'Spacing', 5, ...
                        'Padding', 5);
                        text4VB = uiextras.VBox('Parent', CHIRPHB1);
                            uiextras.Empty('Parent', text4VB);
                            uicontrol(...
                                'Parent', text4VB,...
                                'Style', 'text', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.6, ...
                                'String', 'Base Frequency (MHz)');
                            uiextras.Empty('Parent', text4VB);
                            text4VB.Sizes = [-1 -4 -1];
                        uicontrol(...
                            'Parent', CHIRPHB1,...
                            'Style', 'edit', ...
                            'Tag', ['chirpFTW1' num2str(obj.myBoardAddr)],...
                            'FontUnits', 'normalized', ...
                            'FontSize', 0.6, ...
                            'String', '75.000000');
                        CHIRPHB1.Sizes = [-2 -1];
                    uiextras.Empty('Parent', CHIRPVB);
                    CHIRPVB.Sizes = [-2 -1 -2 -1 -2];
                BPSKGrid = uiextras.VBox('Parent', modeTabPanel);
            modeTabPanel.TabNames = obj.myAvailableModes;
            modeTabPanel.SelectedChild = 1;
            
            
            %%%%%% here Sara tries to add amplitude box at the bottom %%%%%%
            buttonHBox = uiextras.HBox('Parent', obj.mySuperPanel, ...
                'Spacing', 5, ...
                'Padding', 5);
                uiextras.Empty('Parent', buttonHBox);
                
                ampTextVB = uiextras.VBox('Parent', buttonHBox);
                            uiextras.Empty('Parent', ampTextVB);
                            uicontrol(...
                                'Parent', ampTextVB,...
                                'Style', 'text', ...
                                'FontWeight', 'bold', ...
                                'FontUnits', 'normalized', ...
                                'FontSize', 0.5, ...
                                'String', 'Amplitude');
                            uiextras.Empty('Parent', ampTextVB);
                            ampTextVB.Sizes = [-1 -4 -1];
                        
                        
                uicontrol(...
                            'Parent', buttonHBox, ...
                            'Style', 'edit', ...
                            'String', '4095', ...
                            'Tag', ['amp' num2str(obj.myBoardAddr)], ...
                            'Callback', @obj.amp_Callback);                       
                        
                uicontrol(...
                                'Parent', buttonHBox,...
                                'Style', 'pushbutton', ...
                                'Tag', 'updateAmp',...
                                'String', 'Update Amplitude',...
                                'Callback', @obj.updateAmp_Callback);            
                buttonHBox.Sizes = [-1 -5 -5 -6];        
            %%%%%%%%%%%%%%%
            
            set(obj.mySuperPanel, 'Sizes', [-10 -2]);
            set(obj.myPanel, 'Sizes', [-1 -3]);
        end
        
        
        
        %%%% adding a callback function for the amplitude %%%%
        function amp_Callback(obj, src, eventData)
            lower_limit = 0;
            upper_limit = 4096;
            myHandles = guidata(obj.myTopFigure);            
            %if not an integer from 1 to 4096, perform no action and send
            %an error message
            num_entered = str2double(get(myHandles.(['amp' num2str(obj.myBoardAddr)]), 'String'));
            if (num_entered > upper_limit)               
                set(myHandles.(['amp' num2str(obj.myBoardAddr)]), 'String', num2str(upper_limit));
            elseif (num_entered < lower_limit)
                set(myHandles.(['amp' num2str(obj.myBoardAddr)]), 'String', num2str(lower_limit));
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function updateAmp_Callback(obj, src, eventData)
            myHandles = guidata(obj.myTopFigure);   
            
            amp = str2double(get(myHandles.(['amp' num2str(obj.myBoardAddr)]), 'String'));
            ampHex = obj.myDDS.calculateAmp(amp)
            params = struct('ampHex', ampHex);
                    
            iSet = obj.myDDS.createInstructionSet('Amplitude', params);
            fwrite(obj.mySerial, iSet{1});
            fscanf(obj.mySerial)
        end
        
        
        function setDefaultButton_Callback(obj, src, eventData)
            myHandles = guidata(obj.myTopFigure);
            
            dAmplitude = str2double(get(myHandles.(['amp' num2str(obj.myBoardAddr)]), 'String'));
            dAmpHex = obj.myDDS.calculateAmp(dAmplitude);
            
            
            dFrequency = str2double(get(myHandles.(['stFTW' num2str(obj.myBoardAddr)]), 'String'));
            [~, dftw] = obj.myDDS.calculateFTW(dFrequency);
            
            params = struct('ampHex', dAmpHex, 'FTW1', dftw);
            iSet = obj.myDDS.createInstructionSet('Defaults', params);
%             iSet{1}
            fwrite(obj.mySerial, iSet{1});
            fscanf(obj.mySerial)
        end
        
        function reinitializeDDS_Callback(obj, src, eventData)
            % Makes the Arduino send the initializations bits to the DDS
            myHandles = guidata(obj.myTopFigure);
            
            params = struct('board', obj.myBoardAddr);
            iSet = obj.myDDS.createInstructionSet('Reinitialize', params);
            fwrite(obj.mySerial, iSet{1});
            fscanf(obj.mySerial)
        end
        function modeTabPanel_Callback(obj, src, eventData)
            obj.myCurrentMode = eventData.SelectedChild;
        end
        
        function FSKsetting_Callback(obj, src, eventData)
            myHandles = guidata(obj.myTopFigure);
            if get(myHandles.(['FSKsetting' num2str(obj.myBoardAddr)]), 'Value') == 4
                set(myHandles.(['fskFTW2' num2str(obj.myBoardAddr)]), 'Enable', 'off');
            else
                set(myHandles.(['fskFTW2' num2str(obj.myBoardAddr)]), 'Enable', 'on');
            end
        end
        
        function sendCommand_Callback(obj, src, eventData)
            myHandles = guidata(obj.myTopFigure);
            myMode = obj.myAvailableModes{obj.myCurrentMode};
            
            obj.myDDS.mySysClk = str2double(get(myHandles.(['sysClk' num2str(obj.myBoardAddr)]), 'String'));
            
            switch myMode
                case 'Single Tone'
                    freq = str2double(get(myHandles.(['stFTW' num2str(obj.myBoardAddr)]), 'String'));
                    [oFreq, ftw] = obj.myDDS.calculateFTW(freq);
                    params = struct('FTW1', ftw);
                    
                    iSet = obj.myDDS.createInstructionSet(myMode, params);
                    fwrite(obj.mySerial, iSet{1});
                    fscanf(obj.mySerial)
                case 'FSK'
                    fskWriteMode = get(myHandles.(['FSKsetting'  num2str(obj.myBoardAddr)]), 'Value');
                    if fskWriteMode ~= 4
                         freq1 = str2double(get(myHandles.(['fskFTW1' num2str(obj.myBoardAddr)]), 'String')); 
                         freq2 = str2double(get(myHandles.(['fskFTW2' num2str(obj.myBoardAddr)]), 'String')); 
                         [oFreq, ftw] = obj.myDDS.calculateFTW([freq1 freq2]);
                         params = struct('FTW1', ftw(1,:), 'FTW2', ftw(2, :), 'WriteMode', fskWriteMode);

                         iSet = obj.myDDS.createInstructionSet(myMode, params);
                    else
                        freq1 = str2double(get(myHandles.(['fskFTW1' num2str(obj.myBoardAddr)]), 'String'));
                        [oFreq, ftw] = obj.myDDS.calculateFTW(freq1);
                        params = struct('FTW', ftw, 'WriteRegister', ['FTW' num2str(obj.myCurrentRegister) '_Reg'], 'WriteMode', fskWriteMode);
                        
                        iSet = obj.myDDS.createInstructionSet(myMode, params);
                    end
                    switch fskWriteMode
                        case 1 % Send F1&F2
                            fwrite(obj.mySerial, iSet{1});
                            fscanf(obj.mySerial)
                            fwrite(obj.mySerial, iSet{2});
                            fscanf(obj.mySerial)
                        case 2 % Send F1
                            fwrite(obj.mySerial, iSet{1});
                            fscanf(obj.mySerial);
                        case 3 % Send F2
                            fwrite(obj.mySerial, iSet{1});
                            fscanf(obj.mySerial);
                        case 4 % Pseudo-Single Tone
                            fwrite(obj.mySerial, iSet{1});
                            fscanf(obj.mySerial)
                            fwrite(obj.mySerial, iSet{2});
                            fscanf(obj.mySerial)
                            if obj.myCurrentRegister == 1
                                obj.myCurrentRegister = 2;
                            else
                                obj.myCurrentRegister = 1;
                            end
                    end
                case 'Ramped FSK'
                case 'Chirp'
                    chirpWriteMode = get(myHandles.(['CHIRPsetting'  num2str(obj.myBoardAddr)]), 'Value');
                    switch chirpWriteMode
                        case 1 %Send Base Frequency
                            freq1 = str2double(get(myHandles.(['chirpFTW1' num2str(obj.myBoardAddr)]), 'String'));
                            [oFreq, ftw] = obj.myDDS.calculateFTW(freq1);
                            
                            params = struct('FTW1', ftw, 'WriteMode', chirpWriteMode);
                            iSet = obj.myDDS.createInstructionSet(myMode, params);
                            fwrite(obj.mySerial, iSet{1});
                            fscanf(obj.mySerial)
                            fwrite(obj.mySerial, iSet{2});
                            fscanf(obj.mySerial)
                            fwrite(obj.mySerial, iSet{3});
                            fscanf(obj.mySerial)
                        case 2 %Send Slope
                            desiredSlope = str2double(get(myHandles.(['chirpSlope' num2str(obj.myBoardAddr)]), 'String'));
                            [realSlope, RRW, DFTW] = obj.myDDS.calculateRRW(desiredSlope);
                            params = struct('RRW', RRW, 'DFTW', DFTW, 'WriteMode', chirpWriteMode);
                            iSet = obj.myDDS.createInstructionSet(myMode, params);
                            fwrite(obj.mySerial, iSet{1});
                            fscanf(obj.mySerial)
                            fwrite(obj.mySerial, iSet{2});
                            fscanf(obj.mySerial)
                            fwrite(obj.mySerial, iSet{3});
                            fscanf(obj.mySerial)
                            set(myHandles.(['chirpSlope' num2str(obj.myBoardAddr)]), 'String', num2str(realSlope));
                    end
            end
            
            if ~strcmp(myMode, obj.myDDS.myMode)
                params = struct('NEWMODE', myMode);
                iSet = obj.myDDS.createInstructionSet('CHANGEMODE', params);
                fwrite(obj.mySerial, iSet{1});
                fscanf(obj.mySerial)
            end
        end
    end
    
end

