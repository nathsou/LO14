#! /bin/bash

#parameters
declare -r mode=${1:1} #should be list, browse or extract
declare -r server_name=$2 #archive server address
declare -r port=$3 #archive server port
declare -r args=$(echo $* | cut -d " " -f4-)
tmp_arch="tmp.arch" #mktemp
needs_exit=0

send_cmd_fast(){
    echo $1 | nc $server_name $port
}

function send_cmd() {
    (echo $1; sleep .2) | nc $server_name $port
}

function clean_up() {
    [[ -f $tmp_arch ]] && rm -rf $tmp_arch 
    if [[ needs_exit -eq 1 ]]; then
        send_cmd_fast "exit"
    fi
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

    bash utils/extract.sh $tmp_arch $dir
}

function browse() {
    send_cmd_fast "browse $args"
    nc $server_name $port
}

function check_server(){
    if ! nc -zv $server_name $port 2>/dev/null; then
        echo "server at address $server_name is not listening on port $port"
        exit 1
    fi

    needs_exit=1
}

case $mode in 
    list)
        check_server
        send_cmd "list"
        ;;
    
    extract)
        check_server
        extract $args
        ;;

    browse)
        check_server
        browse $args
        #echo "browse $args" | nc $server_name $port
        ;;
    *)
        echo "Usage : vsh <mode> <server_address> <port> <archive_name>"
        echo "mode can be :"
        echo "  -list : display all archives available on the server"
        echo "  -extract : extract the given archive locally"
        echo "  -browse : enter the vsh shell"
        echo "server_address : adresse IP du serveur"
        echo "port : port du serveur"
        echo "archive_name : nom de l'archive utilisée pour les modes browse et extract"
        echo ""
        ;;
esac
