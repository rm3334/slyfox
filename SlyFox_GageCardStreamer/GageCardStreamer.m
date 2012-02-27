function GageCardStreamer(DEBUGMODE )
%GAGECARDSTREAMER Main Function for Streamer program
%   This constructs the relevant objects and creates a GageCardStreamer for
%   reading off the gage card and sending the data to another computer.
%   By Ben Bloom 02/27/12 10:47

    f = figure('Menubar', 'none', 'Toolbar', 'none', 'NumberTitle', 'off', 'Name', 'Frequency Control');
    setappdata(gcf, 'run', 1);
    pan = uiextras.Panel('Parent', f, 'Tag', 'toppanel');
    setappdata(gcf, 'topPanel', pan);
    tp = uiextras.TabPanel('Parent', pan);
    %Build Objects
    g1 = GageCard.GageConfigFrontend(f,tp);
    gs1 = GageCardStreamerFrontend(f,tp, DEBUGMODE);
        gs1.setGageConfigFrontend(g1);
    tp.TabNames = {'GageConfig', 'GageCardStreamer'};
    tp.TabSize = 100;

    mm = uimenu('Label', 'File');
    sm = uimenu(mm, 'Label', 'Save...');
    lm = uimenu(mm, 'Label', 'Load...');
    set(f, 'ResizeFcn', @resizeTopPanel);

    function menuSaveFcn(src, event)
        g1.saveState();
        gs1.saveState();
    end

    function menuLoadFcn(src, event)
        g1.loadState();
        gs1.loadState();
    end

    function windowClose(src,event)
        g1.quit();
        gs1.quit();
        delete(pan);
        delete(f);
        clear all;
    end
    
    set(f,'CloseRequestFcn',@windowClose);
    set(sm, 'Callback', @menuSaveFcn);
    set(lm, 'Callback', @menuLoadFcn);
end

