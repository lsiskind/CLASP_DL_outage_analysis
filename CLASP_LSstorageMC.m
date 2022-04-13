function [LSDataStorageVol, Downlink, outage_time] = CLASP_LSstorageMC(start_DOY, CompressionOut,DownlinkRate,dt,n,HSDataVol)
    
    %Low speed data storage
    SSDRLimit = 3.52; %Total SSDR data capacity, Tb

    Downlink = zeros(1,n);
    LSDataStorageVol = zeros(1,n);

    start_index = start_DOY*24*60*60/dt;
    end_index = start_index + 14*24*60*60/dt;
    outage_time = 0; % seconds of downlink freeze before ssdr overload

    for i=1:n-1
        Downlink(i) = min([DownlinkRate, (LSDataStorageVol(i) + CompressionOut(i)*dt)/dt]); %Downlink rate will be either max value (DownlinkRate) or remaining data volume in LS buffer
    %   LSDataStorageVol(i+1) = LSDataStorageVol(i) + CompressionOut(i)*dt - Downlink(i)*dt; %LS vol during next time step = previous LS vol + data rate in for single time step - downlink rate out for single time step

        if end_index >= n
            if i >= start_index && i<= n
                Downlink(i) = 0;
                LSDataStorageVol(i+1) = LSDataStorageVol(i) + CompressionOut(i)*dt  - Downlink(i)*dt;
                %Total Data Storage
                SSDRDataVol = HSDataVol(i) + LSDataStorageVol(i); %Volume of data stored in SSDR, Mb
                if SSDRDataVol/1e6 < SSDRLimit
                    outage_time = outage_time + dt/60/60;
                end  
            else
                LSDataStorageVol(i+1) = LSDataStorageVol(i) + CompressionOut(i)*dt  - Downlink(i)*dt;
            end 
        elseif end_index < n
            if i >= start_index && i<= end_index
                Downlink(i) = 0;
                LSDataStorageVol(i+1) = LSDataStorageVol(i) + CompressionOut(i)*dt  - Downlink(i)*dt;
                %Total Data Storage
                SSDRDataVol = HSDataVol(i) + LSDataStorageVol(i); %Volume of data stored in SSDR, Mb
                if SSDRDataVol/1e6 < SSDRLimit
                    outage_time = outage_time + dt; % seconds
                end
            else
                LSDataStorageVol(i+1) = LSDataStorageVol(i) + CompressionOut(i)*dt  - Downlink(i)*dt;
            end
        end
        
    end        

end