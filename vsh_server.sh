#! /bin/bash

declare -r archive_dir="archives"

#vsh utils

function archive_exists(){
    
    if [[ -f "$archive_dir/$1" ]]; then
         return 0
    else
        return 1
    fi
}

function check_archive(){
    if ! archive_exists $1; then
        echo "Archive $1 does not exist"
        exit 1;
    fi
}

function dir_exists(){
    arch=$1
    dir=$2
    
    check_archive $arch

    if [[ $(grep -c "^directory $dir$" "$archive_dir/$arch") -eq 1 ]]; then
        return 0
    else
        return 1
    fi
}

function check_directory(){
    if ! dir_exists $1 $2; then
        echo "Directory $2 does not exist in archive $1"
        exit 1;
    fi
}

function get_dir_contents(){
    arch=$1
    dir=$2

    check_directory $arch $dir

    arch="$archive_dir/$arch"

    #get start and end lines of the directory header
    header_dir_start=$(($(grep -n "^directory $dir$" $arch | cut -d ':' -f1) + 1))
    header_dir_end=$(($(tail -n +$header_dir_start $arch | grep -n -m 1 "@" | cut -d ':' -f1) + $header_dir_start - 2))
    head -n $header_dir_end $arch | tail -n+$header_dir_start
}


function file_exists(){
    arch=$1
    file=$2
    
    check_archive $arch

    if [[ $(grep -c "^directory $dir$" "$archive_dir/$arch") -eq 1 ]]; then
        return 0
    else
        return 1
    fi
}

function get_header(){
    arch=$1
    check_archive $arch
    
    info=$(head -n 1 "$archive_dir/$arch")
    header_start=$(echo $info | cut -d ':' -f1)
    header_end=$(expr $(echo $info | cut -d ':' -f2) - 1)
    head -n $header_end "$archive_dir/$arch" | tail -n+$header_start
}

function get_body(){
    arch=$1
    check_archive $arch
    
    body_start=$(head -n 1 "$archive_dir/$arch" | cut -d ':' -f2)
    tail -n+$body_start "$archive_dir/$arch"
}

#retrieve a subsection of the body
function get_body_lines(){
    arch=$1
    from=$2
    nb=$3
    to=$(($from + $nb - 1))

    get_body $arch | head -n $to | tail -n+$from
}

#vsh modes  

#lists all files in a given archive
function vsh_list(){
    for archive in $(ls -1 $archive_dir); do
        echo $archive
    done
}

#extracts all the files in the archive on the client's machine
function vsh_extract(){
    arch=$1
    check_archive $arch

    cat "$archive_dir/$arch"
}

function execute_vsh_cmd(){
    cmd=$1

    if [ "$cmd" = "list" ]; then 
        vsh_list
    elif [ "$cmd" = "extract" ]; then
        vsh_extract $2
    fi
}

execute_vsh_cmd $*