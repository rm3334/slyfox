classdef uControlFrontend < hgsetget
    %DDS_UCONTROLFRONTEND Frontend for Controlling 2 DDS Boards
    %   This a GUI frontend for 1 microController that controls 2 DDS
    %   boards.  By Ben Bloom 02/01/12 17:42:00
    
    properties
        myTopFigure = [];
        myPanel = [];
        mySerial;
    end
    
    methods
        function obj = uControlFrontend(topFig, parentObj)
            obj.myTopFigure = topFig;
            obj.myPanel = uiextras.HBox('Parent', parentObj, ...
                'Spacing', 5, ...
                'Padding', 5);
            
            uCbuttonVB = uiextras.VBox('Parent', obj.myPanel);
                uicontrol(...
                            'Parent', uCbuttonVB, ...
                            'Style', 'text', ...
                            'String', 'Arduino Control', ...
                            'FontWeight', 'bold', ...
                            'FontUnits', 'normalized', ...
                            'FontSize', 0.1);
                comPortListHB = uiextras.HBox('Parent', uCbuttonVB);
                    uiextras.Empty('Parent', comPortListHB);
                    a = instrhwinfo('serial');
                    uicontrol(...
                                'Parent', comPortListHB,...
                                'Style', 'popupmenu', ...
                                'Tag', 'comPortListMenu',...
                                'String', a.SerialPorts);
                    uicontrol(...
                                'Parent', comPortListHB,...
                                'Style', 'pushbutton', ...
                                'Tag', 'refreshComPortList',...
                                'String', 'Refresh',...
                                'Callback', @obj.refreshComPortList_Callback);        
                    uiextras.Empty('Parent', comPortListHB);
                    set(comPortListHB, 'Sizes', [-0.2 -4 -1 -0.2]);
                uicontrol(...
                                'Parent', uCbuttonVB,...
                                'Style', 'pushbutton', ...
                                'Tag', 'openSerial',...
                                'String', 'FOpen',...
                                'Callback', @obj.openSerial_Callback);
                uicontrol(...
                                'Parent', uCbuttonVB,...
                                'Style', 'pushbutton', ...
                                'Tag', 'closeSerial',...
                                'String', 'FClose',...
                                'Enable', 'off', ...
                                'Callback', @obj.closeSerial_Callback);
                uiextras.Empty('Parent', uCbuttonVB);
            uCbuttonVB.Sizes = [-2 -1 -1 -1 -2];
            
            myHandles = guihandles(obj.myTopFigure);
            guidata(obj.myTopFigure, myHandles);
        end
        
        function refreshComPortList_Callback(obj, src, eventData)
            myHandles = guidata(obj.myTopFigure);
            a = instrhwinfo('serial');
            set(myHandles.comPortListMenu, 'String', a.SerialPorts);
            guidata(obj.myTopFigure, myHandles);
        end
        
        function openSerial_Callback(obj, src, eventData)
            myHandles = guidata(obj.myTopFigure);
            mySerialPortList = get(myHandles.comPortListMenu, 'String');
            myVal = get(myHandles.comPortListMenu, 'Value');
            mySerialAddr = mySerialPortList{myVal};
            obj.mySerial = serial(mySerialAddr);
            
            success = 0;
            try
                fopen(obj.mySerial);
                success = 1;
                disp('Open Success!')
            catch
                disp('Error: Open Failed');
            end
            
            if success
                set(myHandles.closeSerial, 'Enable', 'on');
                set(myHandles.openSerial, 'Enable', 'off');
                set(myHandles.comPortListMenu, 'Enable', 'off');
            end
            guidata(obj.myTopFigure, myHandles);
        end
        
        function closeSerial_Callback(obj, src, eventData)
            myHandles = guidata(obj.myTopFigure);            
            success = 0;
            try
                fclose(obj.mySerial);
                success = 1;
                delete(obj.mySerial);
                disp('Close Success!')
            catch
                disp('Error: Close Failed');
            end
            
            if success
                set(myHandles.closeSerial, 'Enable', 'off');
                set(myHandles.openSerial, 'Enable', 'on');
                set(myHandles.comPortListMenu, 'Enable', 'on');
            end
            guidata(obj.myTopFigure, myHandles);
        end
        
        function quit(obj)
            myHandles = guidata(obj.myTopFigure);
            success = 0;
            try
                fclose(obj.mySerial);
                success = 1;
                delete(obj.mySerial);
                disp('Close Success!')
            catch
                disp('Error: Close Arduino Failed');
            end
        end
    end
    
end

