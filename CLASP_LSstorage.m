function [LSDataStorageVol, Downlink] = CLASP_LSstorage(CompressionOut,DownlinkRate,dt,n)
    %Low speed data storage

    Downlink = zeros(1,n);
    LSDataStorageVol = zeros(1,n);
% 
    start_DOY = 141; %randi([1,365],1,1);     % DOY to start downlink freeze
    start_index = start_DOY*24*60*60/dt;
    end_index = start_index + 10*24*60*60/dt;
% 
    for i=1:n-1
        Downlink(i) = min([DownlinkRate, (LSDataStorageVol(i) + CompressionOut(i)*dt)/dt]); %Downlink rate will be either max value (DownlinkRate) or remaining data volume in LS buffer
        
% uncomment if not simulating downlink freeze
%         LSDataStorageVol(i+1) = LSDataStorageVol(i) + CompressionOut(i)*dt - Downlink(i)*dt; %LS vol during next time step = previous LS vol + data rate in for single time step - downlink rate out for single time step

% uncomment if simulating downlink freeze
%
         if end_index >= n
            if i >= start_index && i<= n
                Downlink(i) = 0;
                LSDataStorageVol(i+1) = LSDataStorageVol(i) + CompressionOut(i)*dt  - Downlink(i)*dt;
            else
                LSDataStorageVol(i+1) = LSDataStorageVol(i) + CompressionOut(i)*dt  - Downlink(i)*dt;
            end 
        elseif end_index < n
            if i >= start_index && i<= end_index
                Downlink(i) = 0;
                LSDataStorageVol(i+1) = LSDataStorageVol(i) + CompressionOut(i)*dt  - Downlink(i)*dt;
            else
                LSDataStorageVol(i+1) = LSDataStorageVol(i) + CompressionOut(i)*dt  - Downlink(i)*dt;
            end
        end
%
    end