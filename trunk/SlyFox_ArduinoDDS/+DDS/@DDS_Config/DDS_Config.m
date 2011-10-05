classdef DDS_Config < hgsetget
    %DDS_CONFIG Backend for Controlling various DDS parameters
    %   DDS_Config holds both the settings that are needed to communicate
    %   to the DDS through the Arduino. But also relevant paremeters about
    %   the model of DDS eval board being used. 
    %   Written by Ben Bloom 10/4/2011
    
    properties
        myBoardAddress = 0;
        myBoardModel = 'AD9854'
        mySysClk = 200;
        myHWProps;
        myMode;
    end
    
    methods
        function obj = DDS_Config(boardAddress)
            obj.myBoardAddress = boardAddress;
            obj.setBoardModel(obj.myBoardModel);
        end
        
        function setBoardModel(obj, boardModel)
            obj.myBoardModel = boardModel;
            switch boardModel
                case 'AD9854'
                    %see ad9854 datasheet for data on this chip                       
                    keys = {'Resolution', ...
                        'ConfigReg', ...
                        'ConfigBytes', ...
                        'ConfigModePos', ...
                        'FTW1_Reg', ...
                        'FTW2_Reg', ...
                        'DeltaFW_Reg', ...
                        'RampRate_Reg', ...
                        'AvailableModes', ...
                        'ModeCodes'};
                        
                    vals = {48, ...
                        '7', ...
                        '1014000021', ...
                        [21:23], ...
                        '2', ...
                        '3', ...
                        '4', ...
                        '6', ...
                        {'Single Tone', ...
                            'FSK', ...
                            'Ramped FSK', ...
                            'Chirp', ...
                            'BPSK'}, ...
                        {'000', ...
                            '001', ...
                            '010', ...
                            '011', ...
                            '100'}};
                    obj.myHWProps = containers.Map(keys, vals);
            end
        end
        
        function [outFreq, ftw] = calculateFTW(obj, desiredFrequency)
            %This function calculates the correct Frequency Tuning Word
            %needed to reach the desired frequency given the chips system
            %clock.
            q = quantizer('ufixed','round', [48 0]);
            ftwRAW = (desiredFrequency*2^48)/obj.mySysClk;
            ftw = num2hex(q, ftwRAW);
            outFreq = obj.mySysClk/(hex2num(ftw));
        end
        
        function instrSet = createInstructionSet(obj, selectedMode, params)
            %Creates instructionSet for the selectedMode
            instrSet = [];
            if ~strcmp(obj.myMode, selectedMode)
                obj.setupMode(selectedMode);
            end
            switch selectedMode
                case 'Single Tone'
                    instrSet = [instrSet; uint8(':')]; %tells the microprocessor to enter passthrough mode
                    instrSet = [instrSet; obj.myBoardAddress]; %which board to use
                    instrSet = [instrSet; 7]; %Number of Bytes in Instruction after this point
                    obj.myHWProps('FTW1_Reg')
                    instrSet = [instrSet; uint8(hex2dec(obj.myHWProps('FTW1_Reg')))]; %Address of register on the DDS to write to.
                    FTW1 = params.FTW1
                    for i=1:2:length(FTW1)
                        instrSet = [instrSet; uint8(hex2dec(FTW1(i:i+1)))]; %Yea I know its sloppy, but come on did that last 5 uS cost you that much time
                    end
                    checkSum = sum(instrSet(2:end));
                    q = quantizer('ufixed','round', [48 0]);
                    checkSumBIN = num2bin(q, checkSum);
                    lowByteCheckSumBIN = checkSumBIN(41:end);
                    checkSumLow = bin2num(q, lowByteCheckSumBIN);
                    instrSet = [instrSet; uint8(checkSumLow)];
            end
        end
            
    end
    
end

