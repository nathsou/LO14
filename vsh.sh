#! /bin/bash

#parameters
declare -r mode=${1:1} #should be list, browse or extract
declare -r server_name=$2 #archive server address
declare -r port=$3 #archive server port
declare -r args=$(echo $* | cut -d " " -f4-)
tmp_arch="tmp.arch" #mktemp

send_cmd_fast(){
    echo $1 | nc $server_name $port
}

function send_cmd() {
    (echo $1; sleep .2) | nc $server_name $port
}

function clean_up() {
    [[ -f $tmp_arch ]] && rm -rf $tmp_arch 
    send_cmd_fast "exit"
}
trap clean_up SIGINT EXIT SIGTERM

function extract() {
    touch $tmp_arch
    arch=$1
    #by default, extract to the current directory
    [ ${#2} -ne 0 ] && dir=$2 || dir="./"

    while true; do
        read -r cmd

        if [[ $cmd = "VSH_END_EXTRACT" ]]; then
            break
        fi
        echo $cmd >> $tmp_arch
    done < <((echo "extract $arch"; sleep .2) | nc $server_name $port)

    /bin/bash extract.sh $tmp_arch $dir
}

function browse() {
    send_cmd_fast "browse $args"
    nc $server_name $port
}

case $mode in 
    list)
        send_cmd "list"
        ;;
    
    extract)
        extract $args
        ;;

    browse)
        browse $args
        #echo "browse $args" | nc $server_name $port
        ;;
    *)
        echo "Usage : vsh -[list, browse, extract] server_address port"
        ;;
    esac
