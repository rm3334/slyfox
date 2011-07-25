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
f = figure('Menubar', 'none', 'Toolbar', 'none');
setappdata(gcf, 'run', 1);
pan = uiextras.Panel('Parent', f, 'Tag', 'toppanel');
setappdata(gcf, 'topPanel', pan);
tp = uiextras.TabPanel('Parent', pan);
g1 = GageCard.GageConfigFrontend(f,tp);
f1 = FreqSynth(f,tp);
fs1 = FreqSweeper(f,tp,f1);
tp.TabNames = {'Gage', 'FreqSynth', 'FreqSweeper'};
tp.TabSize = 100;
% pan.Position = [1 1 1900 1020];
set(f, 'ResizeFcn', @resizeTopPanel);
% %%
% setappdata(gcf, 'run', 1);
% 
% [data, time, ret] = GageCard.GageMRecord(g1.myGageConfig);
% %%
% tic
% sum(data,3);
% toc