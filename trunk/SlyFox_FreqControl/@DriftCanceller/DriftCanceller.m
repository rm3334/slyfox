classdef DriftCanceller < hgsetget
    %DRIFTCANCELLER Actively or Passively Control Drift DDS
    %   This program can be used to control one Drift DDS, it will include
    %   an arduino controlled DDS frontend and a PID module to control the
    %   drift. It will actuate on a field inside guidata, and will be
    %   called when necessary to update the active drift. Written by Ben
    %   Bloom. Last updated by Ben Bloom 12/07/12.
    
    properties
        myPanel = uiextras.VBox();
        myTopFigure = [];
        mysPID1 = [];
        myPID1gui = [];
        myDDSFrontend;
    end
    
    methods
        function obj = DriftCanceller(top, f)
            obj.myTopFigure = top;
            obj.myPanel.Parent = f;
            import PID.*
            
            initValues = struct('kP1',0.025,'Ti1',40,'Td1',0, 'kP2',1,'Ti2',10e10,'Td2',0,'delta', 0);
            obj.myPID1gui = PID.PID_gui(top, obj.myPanel, 'D1', initValues);
            obj.mysPID1 = seriesPID({obj.myPID1gui.myPID, obj.myPID1gui.myPID2});
            obj.myDDSFrontend = DDS.DriftDDS_uControlFrontend(top, obj.myPanel);
            obj.myDDSFrontend.setDriftMode(1);
        end
        
        function quit(obj)
            obj.myPanel = [];
            obj.myDDSFrontend.quit();
        end
    end
    
end    
