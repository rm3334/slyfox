function [value] = CsMl_Translate(name, type)
% value = CsMl_Translate(name, type)
%
% CsMl_Translate is provided for convenience and allows conversion of 
% descriptive strings into constant values that are required by the driver, 
% thereby not requiring the user to look-up the values in tables.  
% The function converts a string that describes a CompuScope constant name 
% and a string that describes the context (or type) and returns the 
% corresponding constant value for the CompuScope driver.

if strcmpi(type, 'Mode') == 1
    if strcmpi(name, 'Single') == 1
        value = 1;
    elseif strcmpi(name, 'Dual') == 1
        value = 2;
    elseif strcmpi(name, 'Quad') == 1
        value = 4;
    elseif strcmpi(name, 'Octal') == 1
        value = 8;
    elseif strcmpi(name, 'Oct') == 1
        value = 8;
    elseif strcmpi(name, 'Power On') == 1
        value = 128;
    elseif strcmpi(name, 'PowerOn') == 1
        value = 128;
    elseif strcmpi(name, 'PreTrig MulRec') == 1
        value = 512;
    elseif strcmpi(name, 'PreTrigMulRec') == 1
        value = 512;
    elseif strcmpi(name, 'Reference Clock') == 1
        value = 1024;
    elseif strcmpi(name, 'ReferenceClock') == 1
        value = 1024;
    elseif strcmpi(name, 'RefClock') == 1
        value = 1024;        
    elseif strcmpi(name, 'Clock invert') == 1
        value = 2048;
    elseif strcmpi(name, 'ClockInvert') == 1
        value = 2048; 
    elseif strcmpi(name, 'Software Averaging') == 1
        value = 4096;
    elseif strcmpi(name, 'SoftwareAveraging') == 1
        value = 4096;
    elseif strcmpi(name, 'SW Averaging') == 1
        value = 4096;
    elseif strcmpi(name, 'SWAveraging') == 1
        value = 4096;        
    end;
elseif strcmpi(type, 'Coupling') == 1
    if strcmpi(name, 'DC') == 1
        value = 1;
    elseif strcmpi(name, 'AC') == 1
        value = 2;
    end;
elseif strcmpi(type, 'ExtCoupling') == 1
    if strcmpi(name, 'DC') == 1
        value = 1;
    elseif strcmpi(name, 'AC') == 1
        value = 2;
    end;    
elseif strcmpi(type, 'Slope') == 1
    if strcmpi(name, 'Negative') == 1
        value = 0;
    elseif strcmpi(name, 'Falling') == 1
        value = 0;
    elseif strcmpi(name, 'Positive') == 1
        value = 1;
    elseif strcmpi(name, 'Rising') == 1
        value = 1;        
    end;
elseif strcmpi(type, 'Source') == 1
    if strcmpi(name, 'External') == 1
        value = -1;
    elseif strcmpi(name, 'Disable') == 1
        value = 0;        
    elseif strcmpi(name, 'Disabled') == 1
        value = 0;                
    end;
elseif strcmpi(type, 'TimeStamp') == 1
    if strcmpi(name, 'Sample') == 1
        value = 0;
    elseif strcmpi(name, 'SampleClock') == 1
        value = 0;
    elseif strcmpi(name, 'Sample Clock') == 1
        value = 0;
    elseif strcmpi(name, 'Fixed') == 1
        value = 1;
    elseif strcmpi(name, 'FixedClock') == 1
        value = 1;
    elseif strcmpi(name, 'Fixed Clock') == 1
        value = 1;
    elseif strcmpi(name, 'FreeRun') == 1
        value = 16;
    elseif strcmpi(name, 'Free Run') == 1
        value = 16;
    end;
elseif strcmpi(type, 'Board') == 1
    value = CsMl_BoardNameToType(name);
elseif strcmpi(type, 'Caps') == 1
    if strcmpi(name, 'SampleRates') == 1
        value = hex2dec('10000');
    elseif strcmpi(name, 'Sample Rates') == 1
        value = hex2dec('10000');
    elseif strcmpi(name, 'Rates') == 1
        value = hex2dec('10000');
    elseif strcmpi(name, 'InputRanges') == 1
        value = hex2dec('20000');
    elseif strcmpi(name, 'Input Ranges') == 1
        value = hex2dec('20000');
    elseif strcmpi(name, 'Ranges') == 1
        value = hex2dec('20000');
    elseif strcmpi(name, 'Impedances') == 1
        value = hex2dec('30000');
    elseif strcmpi(name, 'Couplings') == 1
        value = hex2dec('40000');        
    elseif strcmpi(name, 'Modes') == 1
        value = hex2dec('50000');        
    elseif strcmpi(name, 'Terminations') == 1
        value = hex2dec('60000');
    elseif strcmpi(name, 'FlexibleTrigger') == 1
        value = hex2dec('70000');
    elseif strcmpi(name, 'Flexible Trigger') == 1
        value = hex2dec('70000');
    elseif strcmpi(name, 'BoardTrigEngines') == 1
        value = hex2dec('80000');
    elseif strcmpi(name, 'BoardTriggerEngines') == 1
        value = hex2dec('80000');
    end;
elseif strcmpi(type, 'TimeStamp') == 1
    if strcmpi(name, 'SampleClock') == 1
        value = 0;
    elseif strcmpi(name, 'Sample Clock') == 1
        value = 0;
    elseif strcmpi(name, 'Reset') == 1
        value = 0;
    elseif strcmpi(name, 'FixedClock') == 1
        value = 1;
    elseif strcmpi(name, 'Fixed Clock') == 1
        value = 1;
    elseif strcmpi(name, 'FreeRun') == 1
        value = 16;
    end;
elseif strcmpi(type, 'TxMode') == 1
    if strcmpi(name, 'Default') == 1
        value = 0;
    elseif strcmpi(name, 'Float') == 1
        value = 1;
    elseif strcmpi(name, 'TimeStamp') == 1
        value = 2;
    elseif strcmpi(name, 'Time Stamp') == 1
        value = 2;
    elseif strcmpi(name, 'TMB') == 1
        value = 2;
    elseif strcmpi(name, 'DATA16') == 1
        value = 4;
    elseif strcmpi(name, 'DATA 16') == 1
        value = 4;
    elseif strcmpi(name, 'DIGITAL') == 1
        value = 8;
    elseif strcmpi(name, 'DATA32') == 1
        value = 16;
    elseif strcmpi(name, 'DATA 16') == 1
        value = 16;
    elseif strcmpi(name, 'SLAVE') == 1
        value = hex2dec('80000000');
    elseif strcmpi(name, 'FFT') == 1
        value = 48;
    end;
elseif strcmpi(type, 'Options') == 1
    if strcmpi(name, 'fir') == 1
        value = 1;
    elseif strcmpi(name, 'finite impulse response') == 1
        value = 1;
    elseif strcmpi(name, 'averaging') == 1
        value = 2;
    elseif strcmpi(name, 'average') == 1
        value = 2;
    elseif strcmpi(name, 'Peak Detect') == 1
        value = 4;
    elseif strcmpi(name, 'PeakDetect') == 1
        value = 4;
    elseif strcmpi(name, 'MinMax') == 1
        value = 4;
    elseif strcmpi(name, 'Cascaded Streaming') == 1
        value = 8;
    elseif strcmpi(name, 'streaming') == 1
        value = 8;
    elseif strcmpi(name, 'cascadedstreaming') == 1
        value = 8;        
    elseif strcmpi(name, 'mulrec averaging') == 1
        value = 16;        
    elseif strcmpi(name, 'mul rec averaging') == 1
        value = 16;                
    elseif strcmpi(name, 'multiple record averaging') == 1
        value = 16;                        
    elseif strcmpi(name, 'smt') == 1
        value = 32;                        
    elseif strcmpi(name, 'storage media testing') == 1
        value = 32;                                
    elseif strcmpi(name, 'fft 512') == 1
        value = 64;                        
    elseif strcmpi(name, 'fft512') == 1
        value = 64;                         
    elseif strcmpi(name, 'fft 1024') == 1
        value = 128;                        
    elseif strcmpi(name, 'fft1024') == 1
        value = 128;                     
    elseif strcmpi(name, 'fft 2048') == 1
        value = 256;                        
    elseif strcmpi(name, 'fft2048') == 1
        value = 256;                     
    elseif strcmpi(name, 'fft 4096') == 1
        value = 512;                        
    elseif strcmpi(name, 'fft4096') == 1
        value = 512;                             
    elseif strcmpi(name, 'fft') == 1
        value = 960; % all fft values OR'ed together                          
    end;
end;   
       