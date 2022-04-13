%CLASP_storageMC
%----------------------
%Run CLASPdataread.m to load data
% includes CLASP_LSstorageMC, CLASP_HSbuffer, CLASP_HSbuffer_fixedcloudpercent
clearvars -except offind Status cloudyind
clc

tic

DownlinkRate = 3.2; %Effective 100% duty cycle downlink capacity, Mbps (nominal case is 3.2)
dt = 5; %timestep, seconds
DigBits = 16; %Digitization bits
%LineRate = 216;
LineRate = 216.6;
ncores = 3; %Number of cores
CompressionRatio = 4; 
QuantizationStep = 4;
SSDRLimit = 3.52; %Total SSDR data capacity, Tb
PacketizationOverhead = 0.1; %Set as fraction from 0 (0%) to 1 (100%)
realclouds = 1; %Set to 0 or 1. Logical flag for using true cloud data. Use assumed cloudy fraction if 0.
if ~realclouds
    cloudyfrac = 0.4; %Assume fixed percentage of observations obscured by clouds if not using real cloud data
end

n = length(Status)+1;
t = [1:n].*dt; %Time vector, s
AcqStatus = ones(1,n);
AcqStatus(offind) = 0; %Vector indicating active acquisitions. 1 if acquisition, 0 if no acquisition for given time step

% step through each DOY
days = 365;
start_DOYs = 1:1:365;
negmargin_t = zeros(1, days);
minmargin = zeros(1, days);
maxSSDRDataVol = zeros(1, days);
maxSDRAMbuffer = zeros(1, days);

updateStr = ''; %For progress update text
for i = 1: days
    
    start_DOY = start_DOYs(i);
    
    if realclouds
        CloudyStatus = zeros(1,n);
        CloudyStatus(cloudyind) = 1; %Cloudy status is 1 if active acquisition obscured by clouds, 0 otherwise
        [HSDataVol, CompressionOut, SDRAMbuffer] = CLASP_HSbuffer(AcqStatus,offind,CompressionRatio,QuantizationStep,DigBits,LineRate,ncores,cloudyind,dt,n); %High speed buffer with real cloud data
        maxSDRAMbuffer(i) = max(SDRAMbuffer);
        cloudyfrac = sum(CloudyStatus)/sum(AcqStatus); %Fraction of observations obscured by clouds
    else
        [HSDataVol, CompressionOut, SDRAMbuffer] = CLASP_HSbuffer_fixedcloudpercent(AcqStatus,offind,CompressionRatio,QuantizationStep,DigBits,LineRate,ncores,cloudyfrac,dt,n); %High speed buffer w/o real clouds
        maxSDRAMbuffer(i) = max(SDRAMbuffer);
    end

    [LSDataStorageVol, Downlink, outage_time] = CLASP_LSstorageMC(start_DOY, CompressionOut,DownlinkRate*1/(1+PacketizationOverhead),dt,n, HSDataVol); %Low speed storage

    %Total Data Storage
    SSDRDataVol = HSDataVol + LSDataStorageVol; %Volume of data stored in SSDR, Mb    
    DataMargin = (SSDRLimit - SSDRDataVol./1e6)./SSDRLimit * 100; % SSDR available data margin
    negtind = (DataMargin<0); %index for timesteps w/ negative margin
    negmargin_t(i) = sum(negtind)*dt; %Cumulative time w/ negative data margin, s
    minmargin(i) = min(DataMargin); % minimum margin value
    maxSSDRDataVol(i) = max(SSDRDataVol);
    
    percentDone = 100*i/days;
    msg = sprintf('Percent Completion: %0.1f\n',percentDone);
	fprintf([updateStr msg])
    updateStr = repmat(sprintf('\b'),1,length(msg)); %Deletes previous msg so that only current msg is visible
    
end

toc

%% ----------- make plots -----------------

figure()
ax1 = subplot(3,1,1); %SSDR Max Data Storage Volume scatter plot
hold on
set(gca,'fontsize',14)
grid minor
grid
redtot = maxSSDRDataVol./1e6 > SSDRLimit; %Mask to show overflowing data as red. SSDRDataVol in Mb, SSDRLimit in Tb
plot(start_DOYs(~redtot), maxSSDRDataVol(~redtot)./1e6,'.','markersize',14); %Positive margin data shown as blue
plot(start_DOYs(redtot), maxSSDRDataVol(redtot)./1e6,'r.','markersize',14); %Negative margin data shown as red
textheight = linspace(5,1.25,9.2); %Vector for vertical placement of text block in upper right corner
textx = 300; %x location of text block in upper right corner
plot([1 textx-5],[SSDRLimit SSDRLimit],'r--','linewidth',2) %Red dashed line showing 3.52 Tb storage limit
text(5, SSDRLimit*0.925,['SSDR Capacity: ' sprintf('%0.2f',SSDRLimit) 'Tb'],'FontSize',12,'Color','r')
axis([1 365 0 max(maxSSDRDataVol./1e6)+1])
xlabel('DOY beginning two week downlink outage');
ylabel('Max HS + LS Storage (Tb)');
text(textx,textheight(1),['Compression Factor: ' sprintf('%0.0f',CompressionRatio)],'fontsize',12);
text(textx,textheight(2),['Quantization Step: ' sprintf('%0.0f',QuantizationStep)],'fontsize',12);
text(textx,textheight(3),['Max Data Rate to Compressor: ' sprintf('%0.1f',max(maxSDRAMbuffer)) ' Mbps'],'fontsize',12);
text(textx,textheight(4),['ISS Downlink Rate: ' sprintf('%0.2f',DownlinkRate) ' Mbps'],'fontsize',12);
text(textx,textheight(5),['Acquisition Duty Cycle: ' sprintf('%0.2f',sum(AcqStatus)/n*100) ' %'],'fontsize',12);
plot([355 365],[SSDRLimit SSDRLimit],'r--','linewidth',2) %Short segment or red dashed line to the right of text block
hold off

ax2 = subplot(3,1,2); %SSDR Max Data Storage Volume scatter plot
hold on
set(gca,'fontsize',14)
grid minor
grid
redmar = minmargin < 0; %Mask to show overflowing data as red. minmargin in %
plot(start_DOYs(~redmar), minmargin(~redmar),'.','markersize',14) %Positive margin data shown as blue
plot(start_DOYs(redmar), minmargin(redmar),'r.','markersize',14) %Negative margin data shown as red
plot([1 365],[0 0],'r--','linewidth',2) % Red dashed line showing zero margin limit. Only visible if 0 in y axis limits
text(5, -10,'Zero Margin Limit','FontSize',12,'Color','r');
xlabel('DOY beginning two week downlink outage')
ylabel('Min Data Storage Margin (%)')
axis([1 365 min(minmargin)-10 100])
hold off

ax3 = subplot(3,1,3); %SSDR Max Data Storage Volume histogram
hold on
set(gca,'fontsize',14)
grid minor
grid

nbins = 20; %Number of bins between zero and SSDRlimit
maskmar = minmargin < 0; %Mask to show overflowing data as red. minmargin in %
h1 = histogram(minmargin(~maskmar),'BinWidth',100/nbins); %Positive margin data shown as blue
h2 = histogram(minmargin(maskmar),'BinWidth',100/nbins,'FaceColor','red'); %Negative margin data shown as red
xlabel('Min Data Storage Margin (%)') %Note that x and y axes on histogram flipped because of horizontal orientation
ylabel('Frequency')
set(gca,'view',[90 -90]) %Rotates histogram to horizontal orientation

% percent of minmargin < 0
percentbelowzero = sum(maskmar)/days*100;
text(0,120,['% Below Margin: ' sprintf('%0.2f',percentbelowzero) ' %'],'fontsize',12);
hold off

% which DOYs are bad
badDOYs = start_DOYs(maskmar);



