classdef OmegaTempController
    %OMEGATEMPCONTROLLER Utility functions for OmegaTempController
    %   Houses Data on Addresses and whatnot for OmegaTempController
    
    properties
        myAddress = '';
        myPort = 2000;
        myTCPIP;
    end
    
    methods
         function obj = OmegaTempController(networkAddress, networkPort)
             obj.myAddress = networkAddress;
             obj.myPort = networkPort;
             obj.myTCPIP = tcpip(obj.myAddress, obj.myPort,'InputBufferSize',1024);
         end
         
         function currentTemp = readTemp(obj)
            try
                fopen(obj.myTCPIP);
                fprintf(obj.myTCPIP,'%s\r','*01X01');
                back2 = fread(obj.myTCPIP, 11);
                fclose(obj.myTCPIP);

                fullRead = char(back2)';
                currentTemp = str2double(fullRead(6:end));
            catch err
                currentTemp = 0;
            end
         end
         
         function success = setTemp(obj, newTempNum)
            temp = dec2hex(round(newTempNum*10),4);
            
            try
                fopen(obj.myTCPIP);
                fprintf(obj.myTCPIP,'*01W0120%s\r',temp);
                back2 = fread(obj.myTCPIP, 5);
                fclose(obj.myTCPIP);
                
                success = strcmp('01W01', char(back2)');
            catch err
                success = 0;
            end
         end
         
         function reset(obj)
            fopen(obj.myTCPIP);
            fprintf(obj.myTCPIP,'%s\r','*01Z02');
            fclose(obj.myTCPIP);
         end
         
         function delete(obj)
             delete(obj.myTCPIP)
         end
        
    end
    
end

