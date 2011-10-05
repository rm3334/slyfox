%% Testing Script for DDS stuff
dds = DDS.DDS_Config(1)
dds.myMode = 'Single Tone'
[oFreq, ftw] = dds.calculateFTW(11.845698);
params = struct('FTW1', ftw);
iSet = dds.createInstructionSet('Single Tone', params)
fwrite(s, iSet)
fscanf(s)


%% Testing Frontend
f = figure;
DDS.DDS_Frontend(f,f)