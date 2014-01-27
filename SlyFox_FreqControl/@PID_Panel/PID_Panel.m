classdef PID_Panel < hgsetget
    %PID_Panel Panel holder for PIDs for DC stark and more
    %   This holds the PIDs for DC stark and the like
    %   Written by Ben Bloom. Last Updated 01/24/14
    
    properties
        myPanel = uiextras.Grid();
        myTopFigure = [];
        mysPID_DC = [];
        mysPID_DCgui = [];
    end
    
    
    methods
        function obj = PID_Panel(top,f)
            obj.myTopFigure = top;
            obj.myPanel.Parent = f;
            import PID.*
            
            initValues = struct('kP1',1.625,'Ti1',30,'Td1',0.24, 'kP2',1,'Ti2',10e10,'Td2',0,'delta', 8);
            
            obj.mysPID_DCgui = PID.PID_gui(top, obj.myPanel, 'DC Stark', initValues);
            obj.mysPID_DC = seriesPID({obj.mysPID_DCgui.myPID, obj.mysPID_DCgui.myPID2});
            
            uiextras.Empty('Parent', obj.myPanel);
            uiextras.Empty('Parent', obj.myPanel);
            uiextras.Empty('Parent', obj.myPanel);
            
            set(obj.myPanel, 'ColumnSizes', [-1], 'RowSizes', [-1 -1 -1 -1]);
            myHandles = guihandles(obj.myTopFigure);
            guidata(obj.myTopFigure, myHandles);
%             obj.loadState();
        end

        function quit(obj)
            obj.myTopFigure = [];
            obj.mysPID_DC = [];
            obj.mysPID_DCgui = [];
            delete(obj.myPanel);
        end
    end
    
end

