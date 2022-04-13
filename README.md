# CLASP_DL_outage_analysis
# Thermal-Data-Analysis
| Title | Function |
| ------------- | ------------- |
| CLASPdataread | Reads in data from emit-340-416km-summary.csv. Must be run before any other files|
| CLASP_storageMC | Steps through each day of the year and places the downlink outage on a different DOY. Runs the entire clasp sim for each downlink outage and saves the minimum margin for each outage period and the max volume reached. Returns a single output that combines the data from 365 dl outages.|
| CLASP_LSstorageMC | Low speed buffer, but includes functionality to place a 14 day downlink outage starting at specified DOY |
| CLASP_LSstorage | Low speed buffer without downlink outage|
| CLASP_HSbuffer_fixedcloudpercent | High speed buffer for a fixed cloud percent |
| CLASP_HSbuffer | HS buffer with real cloud data|
| CLASP_createPlots | Returns same plots as CLASP_datatool, but loops through each day of the year and places downlink outage starting on each day. Also provides days since start of downlink outage until SSDR overflow. |
