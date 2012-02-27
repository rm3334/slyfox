function FrequencyControlMain(DEBUGMODE )
%FREQUENCYCONTROLMAIN Main Function for Frequency Control Program
%   This constructs the relevant objects and creates a Frequency Control
%   GUI. Need to figure out GageCard AddPath.m
%   By Ben Bloom 01/20/2012 18:12

    f = figure('Menubar', 'none', 'Toolbar', 'none', 'NumberTitle', 'off', 'Name', 'Frequency Control');
    setappdata(gcf, 'run', 1);
    pan = uiextras.Panel('Parent', f, 'Tag', 'toppanel');
    setappdata(gcf, 'topPanel', pan);
    tp = uiextras.TabPanel('Parent', pan);
    %Build Objects
    g1 = GageCard.GageConfigFrontend(f,tp);
    f1 = FreqSynth(f,tp, DEBUGMODE);
    ard = uControlFrontend(f, tp);
    fs1 = FreqSweeper(f,tp);
        fs1.setFreqSynth(f1);
        fs1.setGageConfigFrontend(g1);
        fs1.setuControl(ard);
    fL = FreqLocker(f, tp);
        fL.setFreqSynth(f1);
        fL.setGageConfigFrontend(g1);
        fL.setFreqSweeper(fs1);
        fL.setuControl(ard);
    gs = GageStreamerClientFrontend(f, tp);
        gs.setFreqSweeper(fs1);
        gs.setFreqLocker(fL);
    tp.TabNames = {'Gage', 'FreqSynth',  'Arduino', 'FreqSweeper', 'FreqLocker', 'GageStreamer'};
    tp.TabSize = 100;

    mm = uimenu('Label', 'File');
    sm = uimenu(mm, 'Label', 'Save...');
    lm = uimenu(mm, 'Label', 'Load...');
    set(f, 'ResizeFcn', @resizeTopPanel);

    function menuSaveFcn(src, event)
        g1.saveState();
        f1.saveState();
        fs1.saveState();
        fL.saveState();
    end

    function menuLoadFcn(src, event)
        g1.loadState();
        f1.loadState();
        fs1.loadState();
        fL.loadState();
    end

    function windowClose(src,event)
        g1.quit();
        f1.quit();
        fs1.quit();
        fL.quit();
        ard.quit();
        delete(pan);
%         delete(tp);
        delete(f);
        clear all;
    end
    
    set(f,'CloseRequestFcn',@windowClose);
    set(sm, 'Callback', @menuSaveFcn);
    set(lm, 'Callback', @menuLoadFcn);
end

