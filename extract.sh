#extracts a text archive
arch=$1

#remove '/' at the end of a directory name
function clean_dir_name(){
    dir=$1
    echo $(echo $dir | sed 's:/*$::')
}

root_dir=$(clean_dir_name $2)


function get_header(){
    
    info=$(head -n 1 $arch)
    header_start=$(echo $info | cut -d ':' -f1)
    header_end=$(expr $(echo $info | cut -d ':' -f2) - 1)
    head -n $header_end $arch | tail -n+$header_start
}

function get_body(){
    
    body_start=$(head -n 1 $arch | cut -d ':' -f2)
    tail -n+$body_start $arch
}

#retrieve a subsection of the body
function get_body_lines(){
    from=$1
    nb=$2
    to=$(($from + $nb - 1))

    get_body $arch | head -n $to | tail -n+$from
}

function dir_exists(){
    dir=$(clean_dir_name $1)

    if [[ $(grep -c "^directory $dir/\?$" $arch) -eq 1 ]]; then
        return 0
    else
        return 1
    fi
}

function check_directory(){
    if ! dir_exists $1; then
        echo "Directory $1 does not exist"
        exit 1;
    fi
}

function get_dir_contents(){
    dir=$(clean_dir_name $1)
    check_directory $dir

    #get start and end lines of the directory header
    header_dir_start=$(($(grep -n "^directory $dir/\?$" $arch | cut -d ':' -f1) + 1))
    header_dir_end=$(($(tail -n +$header_dir_start $arch | grep -n -m 1 "@" | cut -d ':' -f1) + $header_dir_start - 2))
    head -n $header_dir_end $arch | tail -n+$header_dir_start
}

function change_permissions(){
    file=$1
    permissions=$2
    user=${permissions:0:3}
    user=${user//-/}
    group=${permissions:3:3}
    group=${group//-/}
    others=${permissions:6:3}
    others=${others//-/}

    chmod u=$user,g=$group,o=$others $file
}

function extract_dir(){
    dir=$1
    perms=$2

    mkdir -p "$root_dir/$dir"

    echo $dir

    get_dir_contents "$dir" |
    while read -r line; do
        name=$(echo $line | cut -d ' ' -f1)
        rights=$(echo $line | cut -d ' ' -f2)
        type=${rights:0:1}
        #check element type (directory or file)
        if [[ $type = "d" ]]; then
            echo "dir $dir/$name"
            mkdir -p "$root_dir/$dir"
        else
            echo "file $dir/$name"
            content_start=$(echo $line | cut -d ' ' -f4)
            content_len=$(echo $line | cut -d ' ' -f5)
            get_body_lines $content_start $content_len >> "$root_dir/$dir/$name"
        fi

        change_permissions "$root_dir/$dir/$name" ${rights:1}
    done
    echo ""
}

function extract_archive(){
    for dir in $(grep "^directory" $arch); do
        if [[ $dir != "directory" ]]; then
            extract_dir $(clean_dir_name $dir)
        fi
    done
}

extract_archive