% %% Create a GageCardFrontend
% clear all
% f = figure();
% GageCard.GageConfigFrontend(f,f)

% %% Create a FreqSynth
% clear all
% f = figure();
% FreqSynth(f,f)

%% Testing creation of a larger program that includes both GUIs
clear all
f = figure();
tp = uiextras.TabPanel('Parent', f)
g1 = GageCard.GageConfigFrontend(f,tp)
f1 = FreqSynth(f,tp)
tp.TabNames = {'Gage', 'FreqSynth'}