function [data,time,ret] = GageMRecord(a)
    %GAGEMRECORD Performs a multiple record on a Gagecard
    %   This helper functions intializes, collects, transfers, and closes a
    %   gagecard during a multiple record event. It is heavily based off
    %   the Compuscope SDK version named GageMultipleRecord.m. To use this,
    %   it must be passed a GageConfig object. Throughout the waiting part
    %   of the execution it will consult the appdata of the gcf to see if
    %   it should abandon waiting for the gagecard to be triggered.
        systems = CsMl_Initialize;
        CsMl_ErrorHandler(systems);
        [ret, handle] = CsMl_GetSystem;
        CsMl_ErrorHandler(ret);

        [ret, sysinfo] = CsMl_GetSystemInfo(handle);

%         s = sprintf('-----Board name: %s\n', sysinfo.BoardName);
%         disp(s);

%         Setup(handle)
        [ret] = CsMl_ConfigureAcquisition(handle, a.acqInfo);
        CsMl_ErrorHandler(ret, 1, handle);

        [ret] = CsMl_ConfigureChannel(handle, a.chan);
        CsMl_ErrorHandler(ret, 1, handle);
        [ret] = CsMl_ConfigureTrigger(handle, a.trig);
        CsMl_ErrorHandler(ret, 1, handle);

        CsMl_ResetTimeStamp(handle);

        ret = CsMl_Commit(handle);
        CsMl_ErrorHandler(ret, 1, handle);

        [ret, acqInfo] = CsMl_QueryAcquisition(handle);
        ret = CsMl_Capture(handle);
        CsMl_ErrorHandler(ret, 1, handle);

        status = CsMl_QueryStatus(handle);
        flag = getappdata(gcf, 'run');
        while status ~= 0 & flag
           status = CsMl_QueryStatus(handle);
           drawnow
           flag = getappdata(gcf, 'run');
        end
        if flag
            % Get timestamp information
            
            time = sprintf('%10.0f',java.lang.System.currentTimeMillis());
            transfer.Channel = 1;
            transfer.Mode = CsMl_Translate('TimeStamp', 'TxMode');
            transfer.Length = acqInfo.SegmentCount;
            transfer.Segment = 1;
            [ret, tsdata, tickfr] = CsMl_Transfer(handle, transfer);

            transfer.Mode = CsMl_Translate('Default', 'TxMode');
            transfer.Start = -acqInfo.TriggerHoldoff;
            transfer.Length = acqInfo.SegmentSize;    

            % Regardless  of the Acquisition mode, numbers are assigned to channels in a 
            % CompuScope system as if they all are in use. 
            % For example an 8 channel system channels are numbered 1, 2, 3, 4, .. 8. 
            % All modes make use of channel 1. The rest of the channels indices are evenly
            % spaced throughout the CompuScope system. To calculate the index increment,
            % user must determine the number of channels on one CompuScope board and then
            % divide this number by the number of channels currently in use on one board.
            % The latter number is lower 12 bits of acquisition mode.

            MaskedMode = bitand(acqInfo.Mode, 15);
            ChannelsPerBoard = sysinfo.ChannelCount / sysinfo.BoardCount;
            ChannelSkip = ChannelsPerBoard / MaskedMode;

            % Format a string with the number of segments and channels so all filenames
            % have the same number of characters.
            format_string = sprintf('%d', acqInfo.SegmentCount);
            MaxSegmentNumber = length(format_string);
            format_string = sprintf('%d', sysinfo.ChannelCount);
            MaxChannelNumber = length(format_string);
            format_string = sprintf('%%s_CH%%0%dd-%%0%dd.dat', MaxChannelNumber, MaxSegmentNumber);

            data = zeros(sysinfo.ChannelCount, acqInfo.SegmentCount, acqInfo.Depth); %assuming no skipped channels
            for channel = 1:ChannelSkip:sysinfo.ChannelCount
                transfer.Channel = channel;
                for i = 1:acqInfo.SegmentCount
                    transfer.Segment = i;
                    [ret, datatemp, actual] = CsMl_Transfer(handle, transfer);
                    CsMl_ErrorHandler(ret, 1, handle);

                    % Note: to optimize the transfer loop, everything from
                    % this point on in the loop could be moved out and done
                    % after all the channels are transferred.

                    % Adjust the size so only the actual length of data is saved to the
                    % file
                    len= size(datatemp, 2);
                    if len > actual.ActualLength
                        datatemp(actual.ActualLength:end) = [];
                        len = size(datatemp, 2);
                    end;      
            %         figure
%                     plot(data)
            %         % Get channel info for file header    
            %         [ret, chanInfo] = CsMl_QueryChannel(handle, channel);            
            %         CsMl_ErrorHandler(ret, 1, handle);
            %         % Get information for ASCII file header
            %         info.Start = actual.ActualStart;
            %         info.Length = actual.ActualLength;
            %         info.SampleSize = acqInfo.SampleSize;
            %         info.SampleRes = acqInfo.SampleResolution;
            %         info.SampleOffset = acqInfo.SampleOffset;
            %         info.InputRange = chanInfo.InputRange;
            %         info.DcOffset = chanInfo.DcOffset;
            %         info.SegmentCount = acqInfo.SegmentCount;
            %         info.SegmentNumber = i;
            %         info.TimeStamp = tsdata(i);
            % 
            %         filename = sprintf(format_string, 'MulRec', transfer.Channel, i);
            %         CsMl_SaveFile(filename, data, info);
            data(channel, i, :) = datatemp;
                end;
            end;   
            disp('Data transferred successfully');
        else
            disp('Acquisition stopped');
            time = 0;
        end
            ret = CsMl_FreeSystem(handle);
end