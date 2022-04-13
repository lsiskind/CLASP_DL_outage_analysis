%CLASP MATLAB DATA READING
%----------------------

clear all
close all
clc

tic
realclouds = 1; %Set to 0 or 1. Logical flag for using true cloud data. Use assumed cloudy fraction if 0.

%Read data
% filedir = 'C:\Users\dpoe\Documents\GitHub\'; %Note: file directory format will have to be modified for other users
%filedir = 'Users/boaida/Documents/GitRepo/CLASP/';  % Bogdan's Mac Setup
%filedir = 'C:\Users\boaida\Documents\GitHub\CLASP\';    % Bogdan's PC Setup
filedir = 'Users/lsiskind/Documents/GitRepo/CLASP_MC/'; % Lena's Mac Setup

data = readcell([filedir 'emit-340-416km-summary.csv'],'Range','E:E'); %Acquisition status. "off", "on", or "pad" (treated as "on")
Timestamp = readcell([filedir 'emit-340-416km-summary.csv'],'Range','A:A'); %Time stamp
%data = readcell([filedir 'EMIT-164 - data-model-okin-v5.csv'],'Range','E3140:E3160');
%data = readcell([filedir 'EMIT-164 - data-model-okin-v5.csv'],'Range','E:E');

Status = strings(1,length(data)-1);

if realclouds
    cloudydata = readcell([filedir 'emit-340-416km-summary.csv'],'Range','H:H'); %During acquisition, either "TRUE" or "FALSE"
    %cloudydata = readcell([filedir 'EMIT-164 - data-model-okin-v5.csv'],'Range','H3140:H3160');
    %cloudydata = readcell([filedir 'EMIT-164 - data-model-okin-v5.csv'],'Range','H:H');
    CloudyStr = strings(1,length(data)-1);
end

for i=2:length(data) %readcell function creates cell arrays. This loop converts them to string vectors.
    cell = data(i);
    str = cell{1};
    Status(i-1) = str;
    
    if realclouds
        cloudycell = cloudydata(i);
        cloudystr = cloudycell{1};
        CloudyStr(i-1) = cloudystr;
    end
end

offind = find(Status == 'off'); %Index of when acquisition status is off. Aquisition is on for all other indices ("on" or "pad")
if realclouds
    cloudyind = find(CloudyStr == 'true'); %Index of cloudy acquisitions
end
toc