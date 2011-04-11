%% testing daq stuff
clear all
a = AnalogChannel.AChanGroup(8,'Dev1', {'Ch0','Ch1','Ch2','Ch3','Ch4','Ch5','Ch6','Ch7'} ,'nidaq', containers.Map(...
{'SampleRate',...
'TriggerType',...
'HwDigitalTriggerSource'},...
{100000,...
'HwDigital',...
'PFI0'}))
h1 = get(gcf);
%%
ch0 = a.myAChans{1};
ch0.myWaveformType = 'Linear';
ch0.myDefaultVoltageValue = 0;
tempWaveform0 = ...
    [0.347, 80;...
    0.347, 125.5;...
    1.2, 55;...
    1.2, 0.5];
temp0 =[.001*[0; cumsum(tempWaveform0(:,2))], [tempWaveform0(:,1); ch0.myDefaultVoltageValue]];
set(ch0, 'myWaveform',temp0)
subplot(2,4,1)
plot(1000*temp0(:,1), temp0(:,2), 'LineWidth', 3)
xlabel('ms')
title(ch0.myName)
%%
ch1 = a.myAChans{2};
ch1.myWaveformType = 'Linear';
ch1.myDefaultVoltageValue = 0;
tempWaveform1 = ...
    [0.347, 80;...
    0.347, 125.5;...
    1.6, 200;...
    1.6, 0.5];
temp1 =[.001*[0; cumsum(tempWaveform1(:,2))], [tempWaveform1(:,1); ch1.myDefaultVoltageValue]];
set(ch1, 'myWaveform',temp1)
subplot(2,4,2)
plot(1000*temp1(:,1), temp1(:,2), 'LineWidth', 3)
xlabel('ms')
title(ch1.myName)
%%
ch2 = a.myAChans{3};
ch2.myWaveformType = 'Linear';
ch2.myDefaultVoltageValue = 0;
tempWaveform2 = ...
    [0.347, 80;...
    0.347, 125.5;...
    1.2, 260;...
    -1.2, 0.5];
temp2 =[.001*[0; cumsum(tempWaveform2(:,2))], [tempWaveform2(:,1); ch2.myDefaultVoltageValue]];
set(ch2, 'myWaveform',temp2)
subplot(2,4,3)
plot(1000*temp2(:,1), temp2(:,2), 'LineWidth', 3)
xlabel('ms')
title(ch2.myName)
%%
ch3 = a.myAChans{4};
ch3.myWaveformType = 'Linear';
ch3.myDefaultVoltageValue = 0;
tempWaveform3 = ...
    [0.347, 80;...
    0.347, 125.5;...
    1.2, 55;...
    1.2, 0.5];
temp3 =[.001*[0; cumsum(tempWaveform3(:,2))], [tempWaveform3(:,1); ch3.myDefaultVoltageValue]];
set(ch3, 'myWaveform',temp3)
subplot(2,4,4)
plot(1000*temp3(:,1), temp3(:,2), 'LineWidth', 3)
xlabel('ms')
title(ch3.myName)
%%
ch4 = a.myAChans{5};
ch4.myWaveformType = 'Linear';
ch4.myDefaultVoltageValue = 0;
tempWaveform4 = ...
    [0.347, 80;...
    0.347, 125.5;...
    1.2, 55;...
    1.2, 0.5];
temp4 =[.001*[0; cumsum(tempWaveform4(:,2))], [tempWaveform1(:,1); ch4.myDefaultVoltageValue]];
set(ch4, 'myWaveform',temp4)
subplot(2,4,5)
plot(1000*temp4(:,1), temp4(:,2), 'LineWidth', 3)
xlabel('ms')
title(ch4.myName)
%%
ch5 = a.myAChans{6};
ch5.myWaveformType = 'Linear';
ch5.myDefaultVoltageValue = 0;
tempWaveform5 = ...
    [0.347, 80;...
    0.347, 125.5;...
    1.2, 55;...
    1.2, 0.5];
temp5 =[.001*[0; cumsum(tempWaveform5(:,2))], [tempWaveform5(:,1); ch5.myDefaultVoltageValue]];
set(ch5, 'myWaveform',temp5)
subplot(2,4,6)
plot(1000*temp5(:,1), temp5(:,2), 'LineWidth', 3)
xlabel('ms')
title(ch5.myName)
%%
ch6 = a.myAChans{7};
ch6.myWaveformType = 'Linear';
ch6.myDefaultVoltageValue = 0;
tempWaveform6 = ...
    [0.347, 80;...
    0.347, 125.5;...
    1.2, 55;...
    1.2, 0.5];
temp6 =[.001*[0; cumsum(tempWaveform6(:,2))], [tempWaveform6(:,1); ch6.myDefaultVoltageValue]];
set(ch6, 'myWaveform',temp6)
subplot(2,4,7)
plot(1000*temp6(:,1), temp6(:,2), 'LineWidth', 3)
xlabel('ms')
title(ch6.myName)
%%
ch7 = a.myAChans{8};
ch7.myWaveformType = 'Linear';
ch7.myDefaultVoltageValue = 0;
tempWaveform7 = ...
    [0.347, 80;...
    0.347, 125.5;...
    1.2, 55;...
    1.2, 0.5];
temp7 =[.001*[0; cumsum(tempWaveform7(:,2))], [tempWaveform7(:,1); ch7.myDefaultVoltageValue]];
set(ch7, 'myWaveform',temp7)
subplot(2,4,8)
plot(1000*temp7(:,1), temp7(:,2), 'LineWidth', 3)
xlabel('ms')
title(ch7.myName)
%% run
uploadData(a)
% delete(a.myDevice) %for turning output off.