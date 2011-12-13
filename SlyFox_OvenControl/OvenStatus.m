%%
% Setup
try
    noz;
catch err
    noz = OmegaTempController('yesromega2.colorado.edu',2000);
end
try
    res;
catch err
    res = OmegaTempController('yesromega1.colorado.edu',2000);
end

nozTemp = noz.readTemp();
resTemp = res.readTemp();

while isnan(nozTemp) || isnan(resTemp)
        pause(5);
        errors = 0;
        if errors > 25
            error('Lost communication');
        end
        nozTemp(end) = noz.readTemp();
        resTemp(end) = res.readTemp();
        errors = errors + 1;
        
end
time = datestr(clock);
output = {['Nozzle Temperature ' num2str(nozTemp)], ...
    ['Reservoir Temperature ' num2str(resTemp)], ...
    time};

fid = fopen('matlab_output.log', 'w');
cellfun(@(x) fprintf(fid, '%s\n', x), output);
fclose('all');

    