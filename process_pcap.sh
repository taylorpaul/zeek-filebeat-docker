#!/bin/bash
LAST_FILE='';

inotifywait -m /share/pcap_raw -e create -e moved_to |
    while read -r dir action file; do
        echo "The file '$file' appeared in directory '$dir' via '$action', waiting for next file before processing";
        if [ -z "$LAST_FILE" ]
        then
            echo "Passing on first file!";
        else
            FILE_PATH=$dir$LAST_FILE
            echo "Starting Zeek $FILE_PATH";
            zeek -Qr "$FILE_PATH";
            echo "Zeek logs produced for " "$FILE_PATH";
        fi
        LAST_FILE=$file; 
        
    done

# Assumes the following command running on windows (administrator CMD prompt): 
# tshark -i Wi-Fi -w \\wsl$\Ubuntu-18.04\home\taylor\lab\share\pcap_raw\capture.pcap --ring-buffer  duration:60

# NOTE 25 APRIL: contianer/script working. Need to create K8s .yaml to spin up inside of our Confluent namespace to facilitate next steps of writing data to kafka (either filebeat or use this repo https://github.com/SeisoLLC/zeek-kafka)