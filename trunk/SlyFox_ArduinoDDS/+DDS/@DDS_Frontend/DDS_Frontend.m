classdef DDS_Frontend
    %DDS_FRONTEND GUI for controlling a DDS_Config Object
    %   DDS_Frontend has a panel and a DDS_Config object. In the panel it
    %   has many controls to change the various parameters of a DDS_Config
    %   object and also to change the characteristics of the DDS output.
    %   Written by Ben Bloom 10/4/2011
    
    properties
        myTopFigure = [];
        myPanel = uiextras.HBox();
    end
    
    methods
        function obj = DDS_Frontend(topFig, parentObj)
            obj.myTopFigure = topFig;
            set(obj.myPanel, 'Parent', parentObj);
            buttonVBox = uiextras.VBox('Parent', obj.myPanel);
            modeTabPanel = uiextras.TabPanel('Parent', obj.myPanel, ...
                'Tag', 'modeTabPanel');
            
                sTGrid = uiextras.Grid('Parent', modeTabPanel);
                FSKGrid = uiextras.Grid('Parent', modeTabPanel);
                rFSKGrid = uiextras.Grid('Parent', modeTabPanel);
                CHIRPGrid = uiextras.Grid('Parent', modeTabPanel);
                BPSKGrid = uiextras.Grid('Parent', modeTabPanel);
            modeTabPanel.TabNames = {'Single Tone', 'FSK', 'Ramped FSK', 'Chirp', 'BPSK'}
        end
    end
    
end

