classdef GageStreamerClientFrontend < hgsetget
    %GAGESTREAMERCLIENTFRONTEND Frontend for recieving data from
    %GageStreamer
    %   This a GUI frontend for receiving data across the network from and
    %   instance of GageStreamer. By Ben Bloom 02/27/12 12:14
    
    properties
        myTopFigure = [];
        myPanel = [];
        myClient = [];
        myFreqSweeper = [];
        myFreqLocker = [];
    end
    
    methods
        function obj = GageStreamerClientFrontend(topFig, parentObj)
            obj.myTopFigure = topFig;
            obj.myPanel = uiextras.HBox('Parent', parentObj, ...
                'Spacing', 5, ...
                'Padding', 5);
            
            uCbuttonVB = uiextras.VBox('Parent', obj.myPanel);
                uicontrol(...
                            'Parent', uCbuttonVB, ...
                            'Style', 'text', ...
                            'String', 'Gage Streamer Client Control', ...
                            'FontWeight', 'bold', ...
                            'FontUnits', 'normalized', ...
                            'FontSize', 0.1);
                uicontrol(...
                                'Parent', uCbuttonVB,...
                                'Style', 'edit', ...
                                'Tag', 'TCPIPaddress',...
                                'String', 'yesr4.colorado.edu');        
                uicontrol(...
                                'Parent', uCbuttonVB,...
                                'Style', 'pushbutton', ...
                                'Tag', 'openClient',...
                                'String', 'Client Connect',...
                                'Callback', @obj.openClient_Callback);
                uicontrol(...
                                'Parent', uCbuttonVB,...
                                'Style', 'pushbutton', ...
                                'Tag', 'closeClient',...
                                'String', 'Client Disconnect',...
                                'Enable', 'off', ...
                                'Callback', @obj.closeClient_Callback);
                uiextras.Empty('Parent', uCbuttonVB);
            uCbuttonVB.Sizes = [-2 -1 -1 -1 -2];
            
            myHandles = guihandles(obj.myTopFigure);
            guidata(obj.myTopFigure, myHandles);
        end
        function setFreqSweeper(obj, fs)
            obj.myFreqSweeper = fs;
        end
        function setFreqLocker(obj, fl)
            obj.myFreqLocker = fl;
        end
        function openClient_Callback(obj, src, eventData)
            myHandles = guidata(obj.myTopFigure);
            obj.myClient = tcpip(get(myHandles.TCPIPaddress, 'String'), 30000, 'NetworkRole', 'client', 'InputBufferSize', 8192);
            obj.myClient.BytesAvailableFcn = @obj.dataReceived;
            obj.myClient.BytesAvailableFcnMode = 'byte';
            obj.myClient.BytesAvailableFcnCount = 4912; %HARD CODED FOR TIMING REASONS. I'm doing this because I don't want data to be skipped.
            success = 0;
            try
                fopen(obj.myClient);
                success = 1;
                disp('Open Success!')
            catch
                disp('Error: Open TCPIP Failed');
            end
            
            if success
                set(myHandles.closeClient, 'Enable', 'on');
                set(myHandles.openClient, 'Enable', 'off');
            end
            guidata(obj.myTopFigure, myHandles);
        end
        function closeClient_Callback(obj, src, eventData)
            myHandles = guidata(obj.myTopFigure);            
            success = 0;
            try
                fclose(obj.myClient);
                success = 1;
                delete(obj.myClient);
                disp('Close Success!')
            catch exception
                exception.message
                disp('Error: Close TCPIP Failed');
            end
            
            if success
                set(myHandles.closeClient, 'Enable', 'off');
                set(myHandles.openClient, 'Enable', 'on');
            end
            guidata(obj.myTopFigure, myHandles);
        end
        function dataReceived(obj, src, eventData)
            data = fread(obj.myClient, 4912/8, 'double');  %HARD CODED FOR TIMING REASONS. I'm doing this because I don't want data to be skipped.
            if getappdata(obj.myTopFigure, 'readyForData')
                nextStep = getappdata(obj.myTopFigure, 'nextStep');
                nextStep(data);
            end
        end
        function quit(obj)
            myHandles = guidata(obj.myTopFigure);
            success = 0;
            try
                fclose(obj.myClient);
                success = 1;
                delete(obj.myClient);
                disp('Close Success!')
            catch exception
                exception.message
                disp('Error: Close TCPIP Failed');
            end
        end
    end
    
end

