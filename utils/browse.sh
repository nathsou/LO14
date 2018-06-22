#!/bin/bash

declare -r archive_dir="archives"
declare -r archive="$archive_dir/$1"
declare -r root=$(awk '/^directory/ {print $2; exit 0}' $archive | cut -d "/" -f1,2)
working_dir=$root

function get_absolute_path(){
    path=$1

	if [[ $(echo $path | grep "^/") || $(echo $path | grep "^$root") ]]; then	#absolute path
        if [[ $path == "/" ]]; then
            path=$root
        else 
            path=$path
        fi
	else
		path="$working_dir/$path"
	fi

    #remove '/' duplicates
    path=$(echo $path | sed -e 's/\/\{2,\}/\//g')
    #remove './''
    path=$(echo $path | sed -e 's/\/\.\//\//g');
    #replace 'A/B/../C' by 'A/C'
    while [[ $(echo $path | grep -c '\.\.') -ne 0 ]]; do
        path=$(echo $path | sed -e 's/[^\.\/]\{1,\}\/\.\.\/\{0,1\}//g')
    done
    #remove trailing slashes and replace duplicates
    path=$(echo $path | sed -e 's:/*$::')

	echo "$path"
}

function dir_exists(){
    dir=$(echo $1 | sed -e 's/\/$//')
    if [[ $(grep -c "^directory $dir/\?" $archive) -eq 0 ]]; then
        return 1
    else
        return 0
    fi
}

#returns infos about a file or "0" if it doesn't exist
function get_file_info(){
    path="$(get_absolute_path $1)"
    file=$(echo $path | awk -F/ '{print $NF}')
    dir=$(echo $path | sed -e 's/'$file'$//')

    #echo "$path : $file : $dir"

    if dir_exists $dir; then
        echo $(get_dir_contents $dir | awk -v file=$file '
        NF == 5 && $1 == file {
            found = 1;
            info = $0;
            exit 0;
        }
        END {
            if (found == 1) {
                print info
            } else {
                    print "0"
                }
            }
        ')
    else
        echo "0"
    fi
}

function file_exists(){
    if [[ "$(get_file_info $1)" == "0" ]]; then
        return 1
    else
        return 0
    fi
}

function get_dir_contents(){
    dir=$1

    #get start and end lines of the directory header
    header_dir_start=$(($(grep -n "^directory $dir/\?$" $archive | cut -d ':' -f1) + 1))
    header_dir_end=$(($(tail -n +$header_dir_start $archive | grep -n -m 1 "@" | cut -d ':' -f1) + $header_dir_start - 2))
    head -n $header_dir_end $archive | tail -n+$header_dir_start
}

function vsh_cd(){
    arg=$1
    path=$(get_absolute_path $1)
    if dir_exists $path; then
        working_dir=$path
    else
        if file_exists $path; then
            echo "cd: Not a directory: $arg"
        else 
            echo "cd: $arg: No such file or directory"
        fi
    fi
}

function vsh_pwd(){
    display_dir=$(echo $working_dir | sed "s:$root::g")
    echo "$display_dir/"
}

function vsh_ls(){
    arg=$1
    path=$(get_absolute_path $1)

    if dir_exists $path; then
        dir=$(grep $path $archive | sed "s:directory $path/::g" | sed "s:directory $root::g" | sed 'y;/;:;' | awk -F":" '{print $1}' | awk '!a[$0]++' | sed '/^$/d' | sed 's:$:/:g') 
        w_dir=$(echo $path | sed 's:/:\\/:g' )
        files=$(awk "/^directory $w_dir(\/$|$)/,/^@$/ {print}" $archive | awk 'NF==5 && $2 !~ /x/ {print $1}' )
        exe=$(awk "/^directory $w_dir(\/$|$)/,/^@$/ {print}" $archive | awk 'NF==5 && $2 ~ /x/ {print $1}' | sed 's/$/*/g' )
        path=$(echo $path | sed 's:\\/:/:g' )
        echo $dir $exe $files
    else
        if file_exists $path; then
            echo $1
        else 
            echo "ls: $arg: No such file or directory"
        fi
    fi
}

function vsh_cat(){
    arg=$1
    path=$(get_absolute_path $arg)

    if file_exists $path; then
        infos=$(get_file_info $path)
        body_start=$(grep "[0-9]\{1,\}:[0-9]\{1,\}" $archive | cut -d ":" -f2)
        file_start=$(echo $infos | awk '{print $4}' )
        file_size=$(echo $infos | awk '{print $5}' )

        #don't display anything if file is empty
        if [[ file_size -gt 0 ]]; then
            true_file_start=$((file_start + body_start - 1))
            true_file_end=$((file_start + file_size + body_start - 2))
            sed -n "${true_file_start},${true_file_end}p" $archive
        fi
    else 
        if dir_exists $path; then
            echo "cat: $arg: Is a directory"
        else
            echo "cat: $arg: No such file or directory"
        fi
    fi
}

function vsh_rm(){
    arg=$(get_absolute_path $1)
    directory=$(grep ^directory $archive) # Récupération des chemins des dossiers de l'archive

    # Check si l'argument est dossier
    if [[ "$directory" = *"$arg"* ]]
        then
            echo "Suppression du dossier "$arg
            escaped_arg=$(echo $arg | sed 's:/:\\/:g' )# Préparation de $arg pour sed et awk              


            # Check récursif si le dossier contient un sous-dossier et placement dans ce sous-dossier
            while [[ $(sed -n "/^directory $escaped_arg\(\/$\|$\)/,/^@$/{/^directory $escaped_arg/d; /^@$/d; p;}" $archive | awk 'NR==1 {print NF}' ) = '3' ]] 
            do
                sub_dir=$(sed -n "/^directory $escaped_arg\(\/$\|$\)/,/^@$/{/^directory $escaped_arg/d; /^@$/d; p;}" $archive | awk 'NR==1 {print $1}' )                # Récupération du nom du sous-dossier
                arg=$arg"/"$sub_dir
                echo "Appel de rm dans le sous-dossier " $arg
                echo ""
                vsh_rm $arg
            done


            # Suppression des fichiers contenus dans le dossier
            get_contained_files             # Récupération des fichiers contenus dans le dossier


            # Check si le dossier contient encore des fichiers
            while [[ "$contained_files" =~ [0-9] ]]
            do
                echo "Le dossier contient "$(echo $contained_files | awk '{print $1}')                        
                get_header_end              # Récupération de la fin du header de l'archive
                file_size=$(echo $contained_files | awk '{print $5}' )              # Récupération de la taille du fichier


                # Check si le fichier est vide
                if [[ "$file_size" = "0" ]]
                    then echo "Le fichier est vide. Il n'y a rien à supprimer."
                else                            
                    delete_file_content             # Suppression du contenu du fichier
                fi
                delete_file             # Suppression du fichier dans le header
                get_contained_files             # Update de $contained_files maintenant que le fichier est supprimé
            done


            # Suppression du dossier et de son contenu pour se débarasser de @ et des éventuels restes de sous-dossiers
            echo "Suppression de "$arg
            sed -i "/^directory $escaped_arg\(\/$\|$\)/,/^@$/ {/^directory $escaped_arg/d; /^@$/d; d;}" $archive
                
            
            # Suppression du sous-dossier ou du dossier s'il n'a plus de sous-dossier
            sub_dir=$(sed -n "/^directory $escaped_arg\(\/$\|$\)/,/^@$/{/^directory $escaped_arg/d; /^@$/d; p;}" $archive | awk 'NR==1 {print $1}' )                # Récupération du sous-dossier


            #Check s'il y a un sous-dossier
            if [[ "$sub_dir" =~ [A-Za-z0-9] ]]
                then
                    delete_sub_dir              # Suppression du sous-dossier
                    arg=$(echo $arg | sed "s/$sub_dir//g")              # Mise à jour de $arg
            else
                delete_last_dir             # Suppression du dossier
                arg=$(echo $arg | sed "s/$last_dir//g")             # Mise à jour de $arg    
            fi

            arg=$(echo $arg | sed "s:/$::g")                # Mise à jour de $arg (ponction du dernier slash)
            escaped_arg=$(echo $arg | sed 's:/:\\/:g')              # Mise à jour de $escaped_arg


    # Si l'argument est un fichier
    elif file_exists $arg; then
        echo "Suppression du fichier "$arg                
        escaped_arg=$(echo $arg | sed 's:/:\\/:g' )             # Création de escaped_arg pour sed et awk
        get_header_end              # Récupération de la fin du header de l'archive
        file_to_delete=$(echo $escaped_arg | awk -F"/" '{print $NF}')               # Récupération du fichier à supprimer 
        file_to_delete=$(grep $file_to_delete $archive)             # Récupération des caractéristiques du fichier
        file_size=$(echo $file_to_delete | awk '{print $5}' )               # Récupération du nombre de lignes du fichier


        # Check si le fichier est vide
        if [[ "$file_size" = "0" ]]
            then echo $(echo $file_to_delete | awk '{print $1}')" est vide."


        # Si le fichier n'est pas vide
        else                            
            file_start=$(echo $file_to_delete | awk '{print $4}' )              # Récupération du début du contenu du fichier                 
            true_file_start=$((file_start + header_end))                # Mise à jour du début avec la fin du header
            true_file_end=$((file_start + file_size + header_end - 1))              # Récupération de la fin du contenu du fichier
            echo "Suppression de "$file_size" lignes"
            sed -i "${true_file_start},${true_file_end}d" $archive              # Suppression du contenu du fichier
        fi


        # Suppression du fichier dans le header
        file_to_delete_1st=$(echo $file_to_delete | awk '{print $1}')               # Récupération du nom du fichier    
        sed -i "/$file_to_delete_1st/d" $archive                # Suppression du fichier dans le header
    else
        echo "rm: $1: No such file or directory"
    fi
    
}

#clears the console
function vsh_clear(){
    clear
}

function delete_file_content {
    file_start=$(echo $contained_files | awk '{print $4}' )                        
    true_file_start=$((file_start + header_end))
    true_file_end=$((file_start + file_size + header_end - 1))
    echo "Suppression du contenu de "$(echo $contained_files | awk '{print $1}')
    sed -i "${true_file_start},${true_file_end}d" $archive 
}

function delete_file {
    contained_files_1st=$(echo $contained_files | awk '{print $1}')             # Récupération du nom du fichier dans le dossier
    sed -i "/^$contained_files_1st /d" $archive                                 
    echo "Suppression de "$contained_files_1st
}

function get_contained_files {
    contained_files=$(sed -n "/^directory $escaped_arg\(\/$\|$\)/,/^@$/{/^directory $escaped_arg/d; /^@$/d; p;}" $archive | awk 'NF==5 {print}' | awk 'NR==1 {print}')              # Récupération du nom du fichier dans le dossier
}

function get_header_end {
    header_end=$(grep -n ^@$ $archive | tail -1 | awk -F: '{print $1}')             # Récupération de la fin du header
}

function delete_last_dir {
    last_dir=$(echo $escaped_arg | awk -F'/' '{print $NF}')             # Récupération du nom du dossier
    sed -i "/^$last_dir /d" $archive                # Suppression du dossier dans le header
    echo "Suppression de "$last_dir" dans le header"
}

function delete_sub_dir {
    echo "Suppression de "$sub_dir" dans le header"
    sed -i "/^$sub_dir /d" $archive 
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
        cat)
            vsh_cat $arg
            ;;
        rm)
            vsh_rm $arg
            ;;
        clear)
            vsh_clear
            ;;
        info)
            get_file_info $arg
            ;;
        exit)
            #echo "exiting"
            exit 0
            ;;
        *)
            echo "vsh: command not found: $cmd"
            ;;
    esac
done