%----------------------
%Run CLASPdataread.m to load data
% includes CLASP_LSstorageMC, CLASP_HSbuffer, CLASP_HSbuffer_fixedcloudpercent
clearvars -except offind Status cloudyind
close all
clc

% create file folder
mkdir SSDR_DL_Freeze_Plots
tic

DownlinkRate = 3.2; %Effective 100% duty cycle downlink capacity, Mbps
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
start_DOYs = 1:1:days;

updateStr = ''; %For progress update text
for i = 1: days
    
    start_DOY = start_DOYs(i);

    if realclouds
        CloudyStatus = zeros(1,n);
        CloudyStatus(cloudyind) = 1; %Cloudy status is 1 if active acquisition obscured by clouds, 0 otherwise
        [HSDataVol, CompressionOut, SDRAMbuffer] = CLASP_HSbuffer(AcqStatus,offind,CompressionRatio,QuantizationStep,DigBits,LineRate,ncores,cloudyind,dt,n); %High speed buffer with real cloud data
        cloudyfrac = sum(CloudyStatus)/sum(AcqStatus); %Fraction of observations obscured by clouds
    else
        [HSDataVol, CompressionOut, SDRAMbuffer] = CLASP_HSbuffer_fixedcloudpercent(AcqStatus,offind,CompressionRatio,QuantizationStep,DigBits,LineRate,ncores,cloudyfrac,dt,n); %High speed buffer w/o real clouds
    end

    [LSDataStorageVol, Downlink, outage_time] = CLASP_LSstorageMC(start_DOY, CompressionOut,DownlinkRate*1/(1+PacketizationOverhead),dt,n,HSDataVol); %Low speed storage

    %Total Data Storage
    SSDRDataVol = HSDataVol + LSDataStorageVol; %Volume of data stored in SSDR, Mb

    DataMargin = (SSDRLimit - SSDRDataVol./1e6)./SSDRLimit * 100; %SSDR available data margin
    negtind = (DataMargin<0); %index for timesteps w/ negative margin
    negmargin_t = sum(negtind)*dt; %Cumulative time w/ negative data margin, s

    %
    % --------------Plot--------------
    figure(i)
    xts = 0.05; %x position of time series plots
    wts = 0.725; %width of time series plots
    xhist = 0.825; %x position of histograms
    whist = 0.15; %width of histograms
    ytickvec = linspace(0,n,11); %Actual locations of tick marks for cartesian scale. These show up on horizontal axis since histogram is rotated 90 deg
    ytickveclog = logspace(log10(n*1e-5),log10(n),6); %Actual locations of tick marks for log scale. Also on horizontal axis
    yticklabelvec = [0:10:100]; %Horizontal tick labels for cartesian scale. Bin heights are actually total data point counts, which range from zero to n (~6e6). We want to show this as a percent from zero to 100
    yticklabelveclog = logspace(-3,2,6); %Same note as above, but for log scale. Tick marks range from 1e-3 to 1e2
    nbins = 20; %Number of bins between zero and SSDRlimit
    logthreshold = 5; %Factor of largest bin to second largest, triggers log scale on histograms

    ax1 = subplot(4,2,1); %High Speed Buffer Data Volume time series plot
    hold on
    set(gca,'fontsize',14)
    grid minor
    grid
    redHS = HSDataVol./1e6 > SSDRLimit; %Mask to show overflowing data as red. HSDataVol in Mb, SSDRLimit in Tb
    plot(t(~redHS)./(3600*24),HSDataVol(~redHS)./1e6,'.','linewidth',2) %Positive margin data shown as blue
    plot(t(redHS)./(3600*24),HSDataVol(redHS)./1e6,'r.','linewidth',2) %Negative margin data shown as red
    xlabel('Day of Year')
    ylabel('HS Data Vol (Tb)')
    title(['14 Day Downlink Outage Starting on DOY ' sprintf('%d',start_DOY)]);
    if sum(SSDRDataVol./1e6 > SSDRLimit)<= 0
        subtitle('Days Since Start of Downlink Outage until SSDR Overflow: N/A');
    else
        subtitle(['Days Since Start of Downlink Outage until SSDR Overflow: ' sprintf('%2.1f', outage_time/60/60/24)]);
    end
    axis([0 max(t./(3600*24)) 0 4])
    textheight = linspace(3.8,1.25,8); %Vector for vertical placement of text block in upper right corner
    textx = 275; %x location of text block in upper right corner
    plot([t(1)/(3600*24) textx-5],[SSDRLimit SSDRLimit],'r--','linewidth',2) %Red dashed line showing 3.52 Tb storage limit
    text(t(1),SSDRLimit*0.925,['SSDR Capacity: ' sprintf('%0.2f',SSDRLimit) 'Tb'],'FontSize',12,'Color','r')
    %Text block of parameters
    if realclouds
        text(textx,textheight(1),['Cloud Scenes Removed: ' sprintf('%0.1f',cloudyfrac*100) ' %'],'fontsize',12)
        plot([325 t(end)/(3600*24)],[SSDRLimit SSDRLimit],'r--','linewidth',2) %Short segment or red dashed line to the right of text block
    else
        text(textx,textheight(1),['Assumed Cloud Scenes Removed: ' sprintf('%0.1f',cloudyfrac*100) ' %'],'fontsize',12)
        plot([textx+64 t(end)/(3600*24)],[SSDRLimit SSDRLimit],'r--','linewidth',2) %Short segment or red dashed line to the right of text block
    end
    text(textx,textheight(2),['Compression Factor: ' sprintf('%0.0f',CompressionRatio)],'fontsize',12)
    text(textx,textheight(3),['Quantization Step: ' sprintf('%0.0f',QuantizationStep)],'fontsize',12)
    text(textx,textheight(4),['Data Rate to Compressor: ' sprintf('%0.1f',max(SDRAMbuffer)) ' Mbps'],'fontsize',12)
    text(textx,textheight(5),['ISS Downlink Rate: ' sprintf('%0.2f',DownlinkRate) ' Mbps'],'fontsize',12)
    text(textx,textheight(6),['Acquisition Duty Cycle: ' sprintf('%0.2f',sum(AcqStatus)/n*100) ' %'],'fontsize',12)
    text(textx,textheight(7),['Processing Duty Cycle: ' sprintf('%0.2f',sum(CompressionOut>0)/n*100) ' %'],'fontsize',12)
    text(textx,textheight(8),['Downlink Duty Cycle: ' sprintf('%0.2f',sum(Downlink>0)/n*100) ' %'],'fontsize',12)
    hold off

    ax2 = subplot(4,2,2); %HS histogram
    hold on
    set(gca,'fontsize',14)
    grid minor
    grid
    maskHS = HSDataVol./1e6 > SSDRLimit; %Mask to show overflowing data as red. HSDataVol in Mb, SSDRLimit in Tb
    histogram(HSDataVol(~maskHS)./1e6,'BinWidth',SSDRLimit/nbins) %Positive margin data shown as blue
    histogram(HSDataVol(maskHS)./1e6,'BinWidth',SSDRLimit/nbins,'FaceColor','red') %Negative margin data shown as red
    N_HS = histcounts(HSDataVol./1e6,'BinWidth',SSDRLimit/nbins); %Vector of bin heights
    if length(N_HS)==1 %If all data points in one bin, show log scale to better see that other bins are empty
        set(gca, 'YScale', 'log')
        set(gca,'Ytick',ytickveclog,'YTickLabel',yticklabelveclog)
        ylim([ytickveclog(1) ytickveclog(end)])
    elseif N_HS(1)/N_HS(2)>logthreshold %If significant ratio between first bin and second bin heights, trigger log scale
        set(gca, 'YScale', 'log')
        set(gca,'Ytick',ytickveclog,'YTickLabel',yticklabelveclog)
        ylim([ytickveclog(1) ytickveclog(end)])
    else %If ratio of first to second bin height less than logthreshold, no log scale
        set(gca,'Ytick',ytickvec,'YTickLabel',yticklabelvec)
        ylim([0 n+1]) %Tick mark for 100% not visible without this line
    end
    xlabel('HS data vol (Tb)') %Note that x and y axes on histogram flipped because of horizontal orientation
    ylabel('Time on orbit (%)')
    xlim([0 4]) %Appears as y limit on histogram
    set(gca,'view',[90 -90]) %Rotates histogram to horizontal orientation
    hold off

    ax3 = subplot(4,2,3); %Low Speed Data Storage Volume time series plot
    hold on
    set(gca,'fontsize',14)
    grid minor
    grid
    redLS = LSDataStorageVol./1e6 > SSDRLimit; %Mask to show overflowing data as red. LSDataStorageVol in Mb, SSDRLimit in Tb
    plot(t(~redLS)./(3600*24),LSDataStorageVol(~redLS)./1e6,'.','linewidth',2) %Positive margin data shown as blue
    plot(t(redLS)./(3600*24),LSDataStorageVol(redLS)./1e6,'r.','linewidth',2) %Negative margin data shown as red
    plot([t(1) t(end)]./(3600*24),[SSDRLimit SSDRLimit],'r--','linewidth',2) %Red dashed line showing 3.52 Tb storage limit
    text(t(1),SSDRLimit*0.925,['SSDR Capacity: ' sprintf('%0.2f',SSDRLimit) 'Tb'],'FontSize',12,'Color','r')
    xlabel('Day of Year')
    ylabel('LS Data Vol (Tb)')
    axis([0 max(t./(3600*24)) 0 4])
    hold off

    ax4 = subplot(4,2,4); %LS histogram
    hold on
    set(gca,'fontsize',14)
    grid minor
    grid
    maskLS = LSDataStorageVol./1e6 > SSDRLimit; %Mask to show overflowing data as red. LSDataStorageVol in Mb, SSDRLimit in Tb
    histogram(LSDataStorageVol(~maskLS)./1e6,'BinWidth',SSDRLimit/nbins) %Positive margin data shown as blue
    histogram(LSDataStorageVol(maskLS)./1e6,'BinWidth',SSDRLimit/nbins,'FaceColor','red') %Negative margin data shown as red
    N_LS = histcounts(LSDataStorageVol./1e6,'BinWidth',SSDRLimit/nbins); %Vector of bin heights
    if length(N_LS)==1 %If all data points in one bin, show log scale to better see that other bins are empty
        set(gca, 'YScale', 'log')
        set(gca,'Ytick',ytickveclog,'YTickLabel',yticklabelveclog)
        ylim([ytickveclog(1) ytickveclog(end)])
    elseif N_LS(1)/N_LS(2)>logthreshold %If significant ratio between first bin and second bin heights, trigger log scale
        set(gca, 'YScale', 'log')
        set(gca,'Ytick',ytickveclog,'YTickLabel',yticklabelveclog)
        ylim([ytickveclog(1) ytickveclog(end)])
    else %If ratio of first to second bin height less than logthreshold, no log scale
        set(gca,'Ytick',ytickvec,'YTickLabel',yticklabelvec)
        ylim([0 n+1]) %Tick mark for 100% not visible without this line
    end
    xlabel('LS data vol (Tb)') %Note that x and y axes on histogram flipped because of horizontal orientation
    ylabel('Time on orbit (%)')
    xlim([0 4]) %Appears as y limit on histogram
    set(gca,'view',[90 -90]) %Rotates histogram to horizontal orientation
    hold off

    ax5 = subplot(4,2,5); %SSDR Total Data Storage Volume time series plot
    hold on
    set(gca,'fontsize',14)
    grid minor
    grid
    redtot = SSDRDataVol./1e6 > SSDRLimit; %Mask to show overflowing data as red. SSDRDataVol in Mb, SSDRLimit in Tb
    plot(t(~redtot)./(3600*24),SSDRDataVol(~redtot)./1e6,'.','linewidth',2) %Positive margin data shown as blue
    plot(t(redtot)./(3600*24),SSDRDataVol(redtot)./1e6,'r.','linewidth',2) %Negative margin data shown as red
    plot([t(1) t(end)]./(3600*24),[SSDRLimit SSDRLimit],'r--','linewidth',2) %Red dashed line showing 3.52 Tb storage limit
    text(t(1),SSDRLimit*0.925,['SSDR Capacity: ' sprintf('%0.2f',SSDRLimit) 'Tb'],'FontSize',12,'Color','r')
    xlabel('Day of Year')
    ylabel('HS + LS (Tb)')
    axis([0 max(t./(3600*24)) 0 4])
    hold off

    ax6 = subplot(4,2,6); %SSDR total data histogram
    hold on
    set(gca,'fontsize',14)
    grid minor
    grid
    masktot = SSDRDataVol./1e6 > SSDRLimit; %Mask to show overflowing data as red. SSDRDataVol in Mb, SSDRLimit in Tb
    histogram(SSDRDataVol(~masktot)./1e6,'BinWidth',SSDRLimit/nbins) %Positive margin data shown as blue
    histogram(SSDRDataVol(masktot)./1e6,'BinWidth',SSDRLimit/nbins,'FaceColor','red') %Negative margin data shown as red
    N_tot = histcounts(SSDRDataVol./1e6,'BinWidth',SSDRLimit/nbins); %Vector of bin heights
    if length(N_tot)==1 %If all data points in one bin, show log scale to better see that other bins are empty
        set(gca, 'YScale', 'log')
        set(gca,'Ytick',ytickveclog,'YTickLabel',yticklabelveclog)
        ylim([ytickveclog(1) ytickveclog(end)])
    elseif N_tot(1)/N_tot(2)>logthreshold %If significant ratio between first bin and second bin heights, trigger log scale
        set(gca, 'YScale', 'log')
        set(gca,'Ytick',ytickveclog,'YTickLabel',yticklabelveclog)
        ylim([ytickveclog(1) ytickveclog(end)])
    else %If ratio of first to second bin height less than logthreshold, no log scale
        set(gca,'Ytick',ytickvec,'YTickLabel',yticklabelvec)
        ylim([0 n+1]) %Tick mark for 100% not visible without this line
    end
    xlabel('SSDR total (Tb)') %Note that x and y axes on histogram flipped because of horizontal orientation
    ylabel('Time on orbit (%)')
    xlim([0 4]) %Appears as y limit on histogram
    set(gca,'view',[90 -90]) %Rotates histogram to horizontal orientation
    hold off

    ax7 = subplot(4,2,7); %Data Storage Margin time series plot
    hold on
    set(gca,'fontsize',14)
    grid minor
    grid
    redmar = DataMargin < 0; %Mask to show overflowing data as red. Datamargin in %
    plot(t(~redmar)./(3600*24),DataMargin(~redmar),'.','linewidth',2) %Positive margin data shown as blue
    plot(t(redmar)./(3600*24),DataMargin(redmar),'r.','linewidth',2) %Negative margin data shown as red
    plot([t(1) t(end)]./(3600*24),[0 0],'r--','linewidth',2) %Red dashed line showing zero margin limit. Only visible if 0 in y axis limits
    plot([t(1) t(end)]./(3600*24),[min(DataMargin) min(DataMargin)],'k--') %Black dashed line showing minimum margin reached
    text(t(1),min(DataMargin)+7.5,['Min margin: ' sprintf('%0.1f',min(DataMargin)) '%'],'FontSize',12) %Text for min margin
    xlabel('Day of Year')
    ylabel('Data Storage Margin (%)')
    axis([0 max(t./(3600*24)) min(DataMargin)-20 100])
    hold off

    ax8 = subplot(4,2,8); %Margin histogram
    hold on
    set(gca,'fontsize',14)
    grid minor
    grid
    maskmar = DataMargin < 0; %Mask to show overflowing data as red. Datamargin in %
    histogram(DataMargin(~maskmar),'BinWidth',100/nbins) %Positive margin data shown as blue
    histogram(DataMargin(maskmar),'BinWidth',100/nbins,'FaceColor','red') %Negative margin data shown as red
    N_mar = histcounts(DataMargin,'BinWidth',100/nbins); %Vector of bin heights
    if length(N_HS)==1 %If all data points in one bin, show log scale to better see that other bins are empty
        set(gca, 'YScale', 'log')
        set(gca,'Ytick',ytickveclog,'YTickLabel',yticklabelveclog)
        ylim([ytickveclog(1) ytickveclog(end)])
    elseif N_mar(end)/N_mar(end-1)>logthreshold %If significant ratio between first bin and second bin heights, trigger log scale
        set(gca, 'YScale', 'log')
        set(gca,'Ytick',ytickveclog,'YTickLabel',yticklabelveclog)
        ylim([ytickveclog(1) ytickveclog(end)])
    else %If ratio of first to second bin height less than logthreshold, no log scale
        set(gca,'Ytick',ytickvec,'YTickLabel',yticklabelvec)
        ylim([0 n+1]) %Tick mark for 100% not visible without this line
    end
    xlabel('Margin (%)') %Note that x and y axes on histogram flipped because of horizontal orientation
    ylabel('Time on orbit (%)')
    xlim([min(DataMargin)-20 100]) %Appears as y limit on histogram
    set(gca,'view',[90 -90]) %Rotates histogram to horizontal orientation
    hold off

    %Set subplot positions
    set(ax1,'Position',[xts 0.7673 wts 0.1577]) %HS time series
    set(ax2,'Position',[xhist 0.7673 whist 0.1577]) %HS histogram
    set(ax3,'Position',[xts 0.5482 wts 0.1577]) %LS time series
    set(ax4,'Position',[xhist 0.5482 whist 0.1577]) %LS histogram
    set(ax5,'Position',[xts 0.3291 wts 0.1577]) %Total time series
    set(ax6,'Position',[xhist 0.3291 whist 0.1577]) %Total histogram
    set(ax7,'Position',[xts 0.11 wts 0.1577]) %Margin time series
    set(ax8,'Position',[xhist 0.11 whist 0.1577]) %Margin histogram
   
    
    set(gcf, 'Position', get(0, 'Screensize'));
    plotname = ['DL_freeze' sprintf('%d',start_DOY) '.png'];
    location = '/Users/lsiskind/Documents/GitRepo/CLASP_MC/SSDR_DL_Freeze_Plots';
    filename = fullfile(location, plotname);
    saveas(gcf,filename);
    
    percentDone = 100*i/days;
    msg = sprintf('Percent Completion: %0.1f\n',percentDone);
	fprintf([updateStr msg])
    updateStr = repmat(sprintf('\b'),1,length(msg)); %Deletes previous msg so that only current msg is visible
    toc
    close all

end

