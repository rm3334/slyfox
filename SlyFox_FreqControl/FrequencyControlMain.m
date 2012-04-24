function FrequencyControlMain(DEBUGMODE )
%FREQUENCYCONTROLMAIN Main Function for Frequency Control Program
%   This constructs the relevant objects and creates a Frequency Control
%   GUI. Need to figure out GageCard AddPath.m
%   DEBUGMODE 0 - Normal Running
%             1 - Running with no GPIB installed
%             2 - Run with data coming from the GageStreamerClientFrontend
%   By Ben Bloom 04/23/2012 12:53

    f = figure('Menubar', 'none', 'Toolbar', 'none', 'NumberTitle', 'off', 'Name', 'Frequency Control')
    setappdata(gcf, 'run', 1);
    pan = uiextras.Panel('Parent', f, 'Tag', 'toppanel');
    setappdata(gcf, 'topPanel', pan);
    setappdata(gcf, 'DEBUGMODE', DEBUGMODE);
    tp = uiextras.TabPanel('Parent', pan);
    %Build Objects
    switch DEBUGMODE
        case {0,1}
            g1 = GageCard.GageConfigFrontend(f,tp);
            f1 = FreqSynth(f,tp);
            t1 = TimeSynth(f,tp);
            ardLC = uControlFrontend(f, tp, 1, 'LC');
            ardCN = uControlFrontend(f, tp, 2, 'CN');
            AVS = AnalogVoltageStepper(f, tp);
            fs1 = FreqSweeper(f,tp);
                fs1.setFreqSynth(f1);
                fs1.setTimeSynth(t1);
                fs1.setGageConfigFrontend(g1);
                fs1.setLCuControl(ardLC);
            fL = FreqLocker(f, tp);
                fL.setFreqSynth(f1);
                fL.setGageConfigFrontend(g1);
                fL.setFreqSweeper(fs1);
                fL.setLCuControl(ardLC);
                fL.setAnalogStepper(AVS);
            gs = GageStreamerClientFrontend(f, tp);
                gs.setFreqSweeper(fs1);
                gs.setFreqLocker(fL);
            tp.TabNames = {'Gage', 'FreqSynth',  'TimeSynth', 'LC_Arduino', 'NC_Arduino', 'AnalogVoltageStepper', 'Sweeper', 'FreqLocker', 'GageStreamer'};
        case 2
            f1 = FreqSynth(f,tp);
            t1 = TimeSynth(f,tp);
            ardLC = uControlFrontend(f, tp, 1, 'LC');
            ardCN = uControlFrontend(f, tp, 2, 'CN');
            AVS = AnalogVoltageStepper(f, tp);
            fs1 = FreqSweeper(f,tp);
                fs1.setFreqSynth(f1);
                fs1.setTimeSynth(t1);
                fs1.setLCuControl(ardLC);
                fs1.setCycleNuControl(ardCN);
            fL = FreqLocker(f, tp);
                fL.setFreqSynth(f1);
                fL.setFreqSweeper(fs1);
                fL.setLCuControl(ardLC);
                fL.setCycleNuControl(ardCN);
                fL.setAnalogStepper(AVS);
            gs = GageStreamerClientFrontend(f, tp);
                gs.setFreqSweeper(fs1);
                gs.setFreqLocker(fL);
            tp.TabNames = {'FreqSynth', 'TimeSynth', 'LC_Arduino', 'NC_Arduino', 'AnalogVoltageStepper', 'Sweeper', 'FreqLocker', 'GageStreamer'};
    end
    tp.TabSize = 100;

    mm = uimenu('Label', 'File');
    sm = uimenu(mm, 'Label', 'Save...');
    lm = uimenu(mm, 'Label', 'Load...');
    set(f, 'ResizeFcn', @resizeTopPanel);

    function menuSaveFcn(src, event)
        if DEBUGMODE ~= 2
            g1.saveState();
        end
        t1.saveState();
        f1.saveState();
        fs1.saveState();
        fL.saveState();
    end

    function menuLoadFcn(src, event)
        if DEBUGMODE ~=2
            g1.loadState();
        end
        t1.loadState();
        f1.loadState();
        fs1.loadState();
        fL.loadState();
    end

    function windowClose(src,event)
        if DEBUGMODE ~= 2
            g1.quit();
        end
        gs.quit();
        delete(gs);
        f1.quit();
        delete(f1);
        t1.quit();
        delete(t1);
        fs1.quit();
        delete(fs1);
        fL.quit();
        delete(fL);
        ardLC.quit();
        delete(ardLC);
        ardCN.quit();
        delete(ardCN);
        AVS.quit();
%         delete(AVS);
%         delete(pan);
%         delete(f);
%         clear all;
        delete(gcf)
        clear all
    end
    
    set(f,'CloseRequestFcn',@windowClose);
    set(sm, 'Callback', @menuSaveFcn);
    set(lm, 'Callback', @menuLoadFcn);
end

