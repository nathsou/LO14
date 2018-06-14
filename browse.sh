#!/bin/bash

declare -r archive_dir="archives"
declare -r archive="$archive_dir/$1"
declare -r root=$(grep ^directory $archive | sed 's/directory //g' | awk -F "/" '{print $1}' | head -1)
working_dir=$root

function get_absolute_path(){
    path=$1
	if [ $(echo $path | grep "^/") ]; then	#absolute path
		path=$path
	else
		path="$working_dir/$path"
	fi

    #remove '/' duplicates
    path=$(echo $path | sed -e 's/\/\{2,\}/\//g')
    #remove './''
    path=$(echo $path | sed -e 's/\/\.\//\//g');
    #replace 'A/B/../C' by 'A/C'
    path=$(echo $path | sed -e 's/[^\.\/]\{1,\}\/\.\.\///g');
    #remove trailing slashes and replace duplicates
    path=$(echo $path | sed -e 's:/*$::')

	echo $path
}

function vsh_cd(){
    path_save=$1
    path=$(get_absolute_path $1)
    if [ $(grep -c "^directory $path" $archive) -gt 0 ]; then
        working_dir=$path
    else
        echo "cd: no such file or directory: $path_save"
    fi
}

function vsh_pwd(){
    echo "/$working_dir"
}

function vsh_ls(){
    path=$(get_absolute_path $1)

    dir=$(grep $path $archive | sed "s:directory $path/::g" | sed "s:directory $root::g" | sed 'y;/;:;' | awk -F":" '{print $1}' | awk '!a[$0]++' | sed '/^$/d' | sed 's:$:/:g') 
    working_dir=$(echo $path | sed 's:/:\\/:g' )
    files=$(awk "/^directory $path(\/$|$)/,/^@$/ {print}" $archive | awk 'NF==5 && !/x/ {print $1}' )
    exe=$(awk "/^directory $path(\/$|$)/,/^@$/ {print}" $archive | awk 'NF==5 && /x/ {print $1}' | sed 's/$/*/g' )
    working_dir=$(echo $path | sed 's:\\/:/:g' )
    echo $dir $exe $files
}

while true; do
    printf "vsh> "
    read cmd arg
    case $cmd in 

    ls)
        vsh_ls $arg
        ;;
    cd)
        vsh_cd $arg
        ;;
    pwd)
        vsh_pwd
        ;;
    exit)
        #echo "exiting"
        break
        ;;
    *)
        echo "vsh: command not found: $cmd"
        ;;
    esac
done