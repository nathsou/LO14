#! /bin/bash

declare -r port=$1

#check if port argument was given and is valid
if ! [[ $# = 1 && $port =~ ^[0-9]+$ ]]; then
    echo "Usage : $0 port, where port is between 1 and 65535"
    exit 1
fi

declare -r FIFO=fifo

##create the fifo if it doesn't exist 
[ -e "$FIFO" ] || mkfifo "$FIFO"

function clean_fifo() {
    rm -f fifo;
}
trap clean_fifo EXIT

function interaction() {
    local mode args
    while true; do
        read mode args || exit -1
        /bin/bash vsh_server.sh $mode $args
    done
}

echo "Listening on port $port"
while true; do
    interaction < "$FIFO" | nc -l -k $port > "$FIFO"
done