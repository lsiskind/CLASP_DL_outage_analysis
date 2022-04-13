function [HSDataVol, CompressionOut, SDRAMbuffer] = CLASP_HSbuffer(AcqStatus,offind,CompressionRatio,QuantizationStep,DigBits,LineRate,ncores,cloudyind,dt,n)
%High speed buffer
%tic
HSratein = 1280*328*DigBits*LineRate/1e6; %Data rate into HS buffer
%HSratein = 7274.98752/5; %Mbps, rate used in updated-processing-data.csv
HSin = AcqStatus*HSratein; %Data reads into HS buffer when Acquisition Status is on

%HSrateout = 246.4*ncores; %Data rate out of HS buffer, Mbps
CoreInputRate = 7.7; %Msamples/s
HSrateout = ncores*CoreInputRate*DigBits*2; %Data rate out of HS buffer, Mbps
HSout = zeros(1,n);
HSout(offind) = HSrateout; %Data flows out of HS buffer when Acquisition Status is off
tempcloudcount = 0; %Variable for counting cloudy observations
Acqcount = 0; %Variable for counting number of acquisitions
Acqlength = 0; %Length of acquisition
cloudacqcount = 0; %Length of cloudy acquisition

HSDataVol = zeros(1,n);
for i=1:n-1
    if HSout(i) > 0
        HSout(i) = min([HSrateout, (HSDataVol(i) + HSin(i)*dt)/dt]); %Data rate out of HS buffer will be either max value (HSrateout) or remaining data vol in HS buffer
    end
    HSDataVol(i+1) = HSDataVol(i) + HSin(i)*dt - HSout(i)*dt; %During next time step, data vol will be previous data vol + data rate in for single time step - data rate out for single time step
end

inind = find(HSin>0); %Index vector of when EMIT is actively observing
outind = find(HSout>0); %Index vector of when HSbuffer is draining
cloudy_outind = []; %Vector of indices in outind corresponding to all cloudy observations
remvec_end = [];
remvec_beg = [];
remind_end = zeros(1,length(cloudacqcount));
remind_beg = zeros(1,length(cloudacqcount));

if ismember(inind(1),cloudyind)
    startind = 1; %in case first timestep of first observation is cloudy
end

for i=1:length(inind)-1 %Find indices in vector "inind" corresponding to cloudy observations
    if ismember(inind(i+1),cloudyind) && ~ismember(inind(i),cloudyind)
        startind = i+1; %Index indicating start of a cloudy observation
    elseif ~ismember(inind(i+1),cloudyind) && ismember(inind(i),cloudyind)
        endind = i; %Index indicating end of a cloudy observation
        cloudacqcount = cloudacqcount + 1;
        cloudacqind{cloudacqcount} = [startind:endind]; %Cell array containing vectors of all cloudy observation indices. This line appends latest cloudy observation into the next cell array element
    end
end

for i=1:cloudacqcount
    cloudy_outind_temp = floor(cloudacqind{i}(1)*(HSratein/HSrateout)):floor(cloudacqind{i}(end)*(HSratein/HSrateout)); %Indices in outind corresponding to current cloudy observation
    rem_beg = cloudacqind{i}(1)*(HSratein/HSrateout) - floor(cloudacqind{i}(1)*(HSratein/HSrateout)); %"Remainder" at beginning of cloudy observation
    rem_end = cloudacqind{i}(end)*(HSratein/HSrateout) - floor(cloudacqind{i}(end)*(HSratein/HSrateout)); %Remainder at end of cloudy observation
    remvec_beg = [remvec_beg rem_beg]; %Vector of all cloudy observation beginning remainders
    remvec_end = [remvec_end rem_end]; %Vector of all cloudy observation end remainders
    cloudy_outind = [cloudy_outind cloudy_outind_temp cloudy_outind_temp(end)+1]; %Append current cloudy observation indices
    remind_beg(i) = cloudy_outind_temp(1); %Index of cloudy observation remainders
    remind_end(i) = cloudy_outind_temp(end)+1; %Index of cloudy observation remainders
end

SDRAMbuffer = HSout./2; %Data flow into SDRAMbuffer/cores
SDRAMbuffer(outind(cloudy_outind)) = 0; %Throw out data chunks flowing out of HS buffer corresponding to cloudy observations
SDRAMbuffer(outind(remind_beg)) = SDRAMbuffer(outind(remind_beg)).*(1-remvec_beg); %Cloudy observation remainders
SDRAMbuffer(outind(remind_end)) = SDRAMbuffer(outind(remind_end)).*(1-remvec_end); %Cloudy observation remainders
CompressionOut = SDRAMbuffer*(14/CompressionRatio+2 - log2(QuantizationStep))/DigBits; %Reference: https://jira.jpl.nasa.gov/browse/EMIT-29
%CompressionOut = CompressionOut.*(462/404.25); %to match LS write speed used in EMIT-164 - data-model-okin-v5.csv
%toc
end