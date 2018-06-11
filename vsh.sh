#! /bin/bash

#parameters
declare -r mode=$1 #should be -list, -browse or -extract
declare -r server_name=$2 #archive server address
declare -r port=$3 #archive server port

function send_cmd() {
    echo $1 | nc $server_name $port
}

if [ $mode = "-list" ]; then
    send_cmd "list"
elif [ $mode = "-browse" ]; then
    while true; do
        #send browse mode commands to server
        read -p "vsh> " cmd
        send_cmd $cmd
    done
elif [ $mode = "extract" ]; then
    send_cmd "extract"
else 
    echo "usage"
fi