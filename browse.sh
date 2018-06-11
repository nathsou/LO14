#!/bin/bash


archive="archives/arch"
root=$(grep ^directory $archive | sed 's/directory //g' | awk -F "/" '{print $1}' | head -1)

function initialiser {
echo $root > /tmp/projet_path.txt
}

function cd {

    arg=$1
    export path=$(cat /tmp/projet_path.txt)
    available=$(grep ^directory $archive | sed "s:directory $path/::g")

    if [ "$arg" = "root" ]
        then 
            path=$root
            echo $path

        elif [ "$arg" = ".." ]
            then
                if [ "$path" != "$root" ]                   #si user n'est pas déjà dans root
                    then 
                        remove=$(echo $path | rev | cut -d'/' -f1 | rev)                      
                        path=$(echo $path | sed "s:/$remove::")
                        echo $path
                    else echo "Vous êtes déjà à la racine."
                fi

        elif [[ "$arg" = *"$root"* ]]                           #si user donne le chemin absolu sans faire d'erreur
            then
            path=$arg 
            echo $path                                        #cd dans le dossier demandé
        
        elif [[ "$available" = *"$arg"* ]]                    #le chemin demandé existe dans l'archive (bug si user entre un nom incomplet d'un dossier disponible ou si user entre le nom d'un dossier existant mais indisponible) 
            then
                    path="$path""/""$arg"
                    echo $path 
        else
            echo "Un problème de chemin est survenu."
            echo $path
    fi

    echo $path > /tmp/projet_path.txt
}

function ls {
    export path=$(cat /tmp/projet_path.txt)
    arg=$1    

    if [ $# -eq 0 ]
        then
            dir=$(grep $path $archive | sed "s:directory $path/::g" | sed "s:directory $root::g" | sed 'y;/;:;' | awk -F":" '{print $1}' | awk '!a[$0]++' | sed '/^$/d' | sed 's:$:/:g') 
            path=$(echo $path | sed 's:/:\\/:g' )
            files=$(awk "/^directory $path(\/$|$)/,/^@$/ {print}" $archive | awk 'NF==5 && !/x/ {print $1}' )
            exe=$(awk "/^directory $path(\/$|$)/,/^@$/ {print}" $archive | awk 'NF==5 && /x/ {print $1}' | sed 's/$/*/g' )
            path=$(echo $path | sed 's:\\/:/:g' )
            echo $dir $exe $files

        else
            dir=$(grep $arg $archive | sed "s:directory $arg/::g" | sed "s:directory $root::g" | sed 'y;/;:;' | awk -F":" '{print $1}' | awk '!a[$0]++' | sed '/^$/d' | sed 's:$:/:g') 
            arg=$(echo $arg | sed 's:/:\\/:g' )
            files=$(awk "/^directory $arg(\/$|$)/,/^@$/ {print}" $archive | awk 'NF==5 && !/x/ {print $1}' )
            exe=$(awk "/^directory $arg(\/$|$)/,/^@$/ {print}" $archive | awk 'NF==5 && /x/ {print $1}' | sed 's/$/*/g' )
            arg=$(echo $arg | sed 's:\\/:/:g' )
            echo $dir $exe $files
    fi
}






"$@"
