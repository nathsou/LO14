declare -r mode=$1
declare -r args=$2
declare -r archive_dir="archives"

function archive_exists(){
    if [[ -f "$archive_dir/$1" ]]; then
         return 0
    else
        return 1
    fi
}

function check_archive(){
    if ! archive_exists $1; then
        echo "Archive '$1' does not exist"
        exit 1
    fi
}

#vsh modes  

#lists all files in a given archive
function vsh_list(){
    for archive in $(ls -1 $archive_dir); do
        echo $archive
    done
}

function vsh_browse(){
    bash utils/browse.sh $1
}

if [ $mode == "list" ]; then 
    vsh_list
elif [ $mode == "extract" ]; then
    arch=$(echo $args | cut -d ' ' -f1)
    if ! archive_exists $arch; then
        echo -e "\nVSH_EXTRACT_UNK_ARCH"
        echo -e "\nno archive named $arch"
        exit 1
    fi
    cat "$archive_dir/$arch"
    echo -e "\nVSH_END_EXTRACT"
    #./extract.sh "$archive_dir/$arch" $dir
elif [ $mode == "browse" ]; then
    arch=$(echo $args | cut -d ' ' -f1)
    check_archive $arch
    vsh_browse $arch
elif [ $mode == "exit" ]; then
    exit 0
fi