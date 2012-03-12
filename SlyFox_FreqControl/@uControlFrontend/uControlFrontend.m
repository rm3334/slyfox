classdef uControlFrontend < hgsetget
    %DDS_UCONTROLFRONTEND Frontend for Controlling 2 DDS Boards
    %   This a GUI frontend for 1 microController By Ben Bloom 03/12/12 10:26:00
    
    properties
        myTopFigure = [];
        myPanel = [];
        mySerial = [];
    end
    
    methods
        function obj = uControlFrontend(topFig, parentObj, MODE)
            %MODE - 0 = mode with just a popup menu and no buttons
            %MODE - 1 = normal mode with open and close buttons
            %MODE - 2 = 
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
                switch MODE
                    case {0,1}
                        comPortListHB = uiextras.HBox('Parent', uCbuttonVB);
                            uiextras.Empty('Parent', comPortListHB);
                            info = instrhwinfo('visa', 'ni');
                            comPortListMenu = uicontrol(...
                                'Parent', comPortListHB, ...
                                'Tag', ['comPortListMenu' num2str(MODE)], ...
                                'Style', 'popup', ...
                                'String', info.ObjectConstructorName);
                            uicontrol(...
                                        'Parent', comPortListHB,...
                                        'Style', 'pushbutton', ...
                                        'Tag', 'refreshComPortList',...
                                        'String', 'Refresh',...
                                        'Callback', @obj.refreshComPortList_Callback);
                    case 2
                        comPortListHB = uiextras.HBox('Parent', uCbuttonVB);
                            uiextras.Empty('Parent', comPortListHB);
                            comPortListMenu = uicontrol(...
                                'Parent', comPortListHB, ...
                                'Tag', 'comPortListMenu', ...
                                'Style', 'edit', ...
                                'String', '''tcpip(''yesrarduino1.colorado.edu'', 3001)''');
                            uiextras.Empty('Parent', comPortListHB);
                end
                    uiextras.Empty('Parent', comPortListHB);
                    set(comPortListHB, 'Sizes', [-0.2 -4 -1 -0.2]);
                    if MODE ~= 2
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
                uicontrol(...
                                'Parent', uCbuttonVB,...
                                'Style', 'checkbox', ...
                                'Tag', ['cycleNumOn' num2str(MODE)],...
                                'String', 'CycleNum on?',...
                                'Visible', 'on', ...
                                'Value', 0);
                    else
                            uiextras.Empty('Parent', uCbuttonVB);
                         uiextras.Empty('Parent', uCbuttonVB);
                uicontrol(...
                                'Parent', uCbuttonVB,...
                                'Style', 'checkbox', ...
                                'Tag', ['cycleNumOn' num2str(MODE)],...
                                'String', 'CycleNum on?',...
                                'Visible', 'on', ...
                                'Value', 0);
                    end
                uiextras.Empty('Parent', uCbuttonVB);
            uCbuttonVB.Sizes = [-2 -1 -1 -1 -1 -2];
            
            
            myHandles = guihandles(obj.myTopFigure);
            
%             switch MODE
%                 case {0, 2}
%                   set(myHandles.openSerial, 'Visible', 'off');
%                   set(myHandles.closeSerial, 'Visible', 'off');
%                   set(myHandles.cycleNumOn, 'Visible', 'on');
%                 case 1
%                   set(myHandles.openSerial, 'Visible', 'on');
%                   set(myHandles.closeSerial, 'Visible', 'on');
%                   set(myHandles.cycleNumOn, 'Visible', 'off');
%             end
            guidata(obj.myTopFigure, myHandles);
        end
        
        function refreshComPortList_Callback(obj, src, eventData)
            myHandles = guidata(obj.myTopFigure);
            a = instrhwinfo('visa', 'ni');
            set(myHandles.comPortListMenu, 'String', a.ObjectConstructorName);
            guidata(obj.myTopFigure, myHandles);
        end
        
        function initialize(obj)
            if ~isempty(obj.mySerial)
                delete(obj.mySerial);
                obj.mySerial = [];
            end
            myHandles = guidata(obj.myTopFigure);
%             mySerialCMD = get(myHandles.comPortListMenu, 'String');
%             obj.mySerial = eval(mySerialCMD);
            obj.mySerial = tcpip('yesrarduino1.colorado.edu', 3001);
        end
        function cycleNum = getCycleNum(obj)
                try
                    fopen(obj.mySerial);
                    fwrite(obj.mySerial, 'c');
                    cycleNum = fscanf(obj.mySerial);
                    fclose(obj.mySerial);
                catch exception
                    exception.message
                    disp('Error when getting cycleNum');
                end
        end
        
        function openSerial_Callback(obj, src, eventData)
            myHandles = guidata(obj.myTopFigure);
            mySerialPortList = get(myHandles.comPortListMenu1, 'String');
            myVal = get(myHandles.comPortListMenu1, 'Value');
            mySerialAddr = mySerialPortList{myVal};
            obj.mySerial = eval(mySerialAddr);
            
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
                set(myHandles.comPortListMenu1, 'Enable', 'off');
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

