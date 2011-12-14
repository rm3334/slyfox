%%
%Variables
currentNozSet = 250;
currentResSet = 100;

endNozSet = 625;
endResSet = 575;

accu = 20; %Accuracy for next step 

TimeBetweenReads = 10; %Seconds between decision making / reading off values
startTime = clock;

time = [];
nozTemp = [];
resTemp = [];
%%
% Setup
try
    noz
catch err
    noz = OmegaTempController('yesromega2.colorado.edu',2000);
end
try
    res
catch err
    res = OmegaTempController('yesromega1.colorado.edu',2000);
end

%% Check to make sure it is ok to run
fid = fopen('matlab_status_output.log');
txt = fread(fid, '*char')';
if(~strcmp(txt, 'idle'))
    exit;
end
%%
% Initialization

nozSuc = noz.setTemp(currentNozSet);
resSuc = res.setTemp(currentResSet);

        while ~nozSuc
            pause(2)
            nozSuc = noz.setTemp(currentNozSet);
        end
        while ~resSuc
            pause(2)
            resSuc = res.setTemp(currentResSet);
        end

noz.reset();
res.reset();
pause(10);

fid = fopen('matlab_status_output.log', 'w');
fprintf(fid, '%s\n', 'Heating');
fclose('all');

for i=1:2
    nozTemp = [nozTemp noz.readTemp()];
    resTemp = [resTemp res.readTemp()];
    time = [time etime(clock, startTime)];
    pause(5)
end

plot(time, nozTemp, time, resTemp, 'Linewidth', 2)
legend('Nozzle Temperature', 'Reservoir Temperature');
hold on

%%
% Loop
while currentNozSet < endNozSet && currentResSet < endResSet
    pause(TimeBetweenReads);
    
    nozTemp = [nozTemp noz.readTemp()];
    resTemp = [resTemp res.readTemp()];
    
    % Error Handling
    errors = 0;
    while isnan(nozTemp(end)) || isnan(resTemp(end))
        pause(5);
        if errors > 25
            error('Lost communication');
        end
        nozTemp(end) = noz.readTemp();
        resTemp(end) = res.readTemp();
        errors = errors + 1;
        
    end
    time = [time etime(clock, startTime)];
    
    plot(time, nozTemp, time, resTemp, 'LineWidth', 2)
    
    if abs(nozTemp(end) - currentNozSet) < accu && abs(resTemp(end) - currentResSet) < accu
        stepup = 1;
    else
        stepup = 0;
    end
    
    if stepup
        if currentResSet + 60 < endResSet
            currentResSet = currentResSet + 60;
        else
            currentResSet = endResSet;
        end
        
        if currentNozSet + 50 < endNozSet
            currentNozSet = currentNozSet + 50;
        else
            currentNozSet = endNozSet;
        end
        
        nozSuc = noz.setTemp(currentNozSet);
        resSuc = res.setTemp(currentResSet);
        
        while ~nozSuc
            pause(2)
            nozSuc = noz.setTemp(currentNozSet);
        end
        while ~resSuc
            pause(2)
            resSuc = res.setTemp(currentResSet);
        end

        noz.reset();
        res.reset();
        
    end

end

fid = fopen('matlab_status_output.log', 'w');
fprintf(fid, '%s\n', 'idle');
fclose('all');