function FrequencySweeperMain(DEBUGMODE )
%FREQUENCYSWEEPERMAIN Main Function for Frequency Sweeper Program
%   This constructs the relevant objects and creates a Frequency Sweeper
%   GUI. Need to figure out GageCard AddPath.m
%   By Ben Bloom 01/22/2012 15:18

    f = figure('Menubar', 'none', 'Toolbar', 'none', 'NumberTitle', 'off', 'Name', 'Frequency Sweeper');
    setappdata(gcf, 'run', 1);
    pan = uiextras.Panel('Parent', f, 'Tag', 'toppanel');
    setappdata(gcf, 'topPanel', pan);
    tp = uiextras.TabPanel('Parent', pan);
    %Build Objects
    g1 = GageCard.GageConfigFrontend(f,tp);
    f1 = FreqSynth(f,tp, DEBUGMODE);
    fs1 = FreqSweeper(f,tp);
        fs1.setFreqSynth(f1);
        fs1.setGageConfigFrontend(g1);
    tp.TabNames = {'Gage', 'FreqSynth', 'FreqSweeper'};
    tp.TabSize = 100;

    mm = uimenu('Label', 'File');
    sm = uimenu(mm, 'Label', 'Save...');
    lm = uimenu(mm, 'Label', 'Load...');
    set(f, 'ResizeFcn', @resizeTopPanel);

    function menuSaveFcn(src, event)
        g1.saveState();
        f1.saveState();
        fs1.saveState();
    end

    function menuLoadFcn(src, event)
        g1.loadState();
        f1.loadState();
        fs1.loadState();
    end

    function windowClose(src,event)
        g1.quit();
        f1.quit();
        fs1.quit();
        delete(pan);
%         delete(tp);
        delete(f);
        clear all;
    end
    
    set(f,'CloseRequestFcn',@windowClose);
    set(sm, 'Callback', @menuSaveFcn);
    set(lm, 'Callback', @menuLoadFcn);
end

