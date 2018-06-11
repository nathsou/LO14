#! /bin/bash

declare -r port=$1

#check if port argument is given and valid
if ! [[ $# = 1 && $port =~ ^[0-9]+$ ]]; then
    echo -e "Usage : $0 port, where port is between 1 and 65535"
    exit 1
fi

mkfifo stdout_fifo

function clean_fifo() {
    rm -f stdout_fifo;
}
trap clean_fifo EXIT


echo "Listening on port $port"
#listen for commands and redirect the standard outpout to the client
while true; do
   #TODO: Send arguments to ./vsh_server.sh
   nc -l $port <stdout_fifo | ./vsh_server.sh>stdout_fifo
done



