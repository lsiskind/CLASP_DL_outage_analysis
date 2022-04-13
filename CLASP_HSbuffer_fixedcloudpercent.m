function [HSDataVol CompressionOut SDRAMbuffer] = CLASP_HSbuffer_fixedcloudpercent(AcqStatus,offind,CompressionRatio,QuantizationStep,DigBits,LineRate,ncores,cloudyfrac,dt,n)
%High speed buffer

HSratein = 1280*328*DigBits*LineRate/1e6; %Data rate into HS buffer
%HSratein = 1280*325*DigBits*LineRate/1e6; %Mbps, rate used in Tableau Export.EMIT244b_1.8mbps_40pctclouds_0cont_0overhead.xlsx
HSin = AcqStatus*HSratein; %Data reads into HS buffer when Acquisition Status is on

%HSrateout = 246.4*ncores; %Data rate out of HS buffer, Mbps
CoreInputRate = 7.7; %Msamples/s
HSrateout = ncores*CoreInputRate*DigBits*2; %Data rate out of HS buffer, Mbps
HSout = zeros(1,n);
HSout(offind) = HSrateout; %Data flows out of HS buffer when Acquisition Status is off

HSDataVol = zeros(1,n);
for i=1:n-1
    if HSout(i) > 0
        HSout(i) = min([HSrateout, (HSDataVol(i) + HSin(i)*dt)/dt]); %Data rate out of HS buffer will be either max value (HSrateout) or remaining data vol in HS buffer
    end
%     if HSout(i) > (HSDataVol(i) + HSin(i)*dt)/dt
%         HSout(i) = 0;
%     end
    HSDataVol(i+1) = HSDataVol(i) + HSin(i)*dt - HSout(i)*dt; %During next time step, data vol will be previous data vol + data rate in for single time step - data rate out for single time step
end

%TROUBLESHOOTING:
%Tableau ignores entries at end of clearing HS buffer
%lowind = find(HSout<max(HSout));
%HSout(lowind)=0;

SDRAMbuffer = HSout./2 * (1-cloudyfrac); %Data flow into SDRAMbuffer/cores
CompressionOut = SDRAMbuffer*(14/CompressionRatio+2 - log2(QuantizationStep))/DigBits; %Reference: https://jira.jpl.nasa.gov/browse/EMIT-29
end