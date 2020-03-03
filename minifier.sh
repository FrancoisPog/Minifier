#! /bin/dash

#######################################################
#                     FUNCTIONS                       #
#######################################################

# Function displaying the help message
help(){
      echo 'usage : ./minifier.sh [OPTION]... dir_source dir_dest

        Minifies HTML and/or CSS files with :
            dir_source   path to the root directory of the website to be minified
            dir_dest     path to the root directory of the minified website
        OPTIONS
            --help       show help and exit
            -v           displays the list of minified files; and for each
                            file, its final and initial sizes, and its reduction
                            percentage
            -f           if the dir_dest file exists, its content is
                            removed without asking for confirmation of deletion
            -p           remove also the space before and after "(" and ")" in css files
            --css        CSS files are minified
            --html       HTML files are minified
            if none of the 2 previous options is present, the HTML and CSSfiles are minified
            
            -t tags_file the "white space" characters preceding and following the
                            tags (opening or closing) listed in the ’tags_file’ are deleted'
}


# Function checking if a string match with pattern
# $1 : The string
# $2 : The pattern
match_pattern(){
  test -z "$1" && { test "$2" = "^$" && return 0 || return 1;}
  ! test -z $( echo "$1" | grep -E "$2" )
  return $?
}

# Function cheking if a variable is already initialized
# $1 : The variable name 
isSet()(
  ! test "$1" = ""
  return $?
)

# Function setting the flag variable of given option at 1
# $1 : The option without '-' or '--' (ex : css, f ...)
# $2 : 'double' if the original option is of type '--', else if is of type '-'
# Exemple : 
#           'set_option f' -> will set $F at 1
#           'set_option css double' -> will set $CSS at 1
#           'set_option css' or 'set_option t double' -> error
set_option(){
  # check option validity
  if test "$2" = 'double'; then
    ! match_pattern "$1" '(^css$|^html$)' && { echo "The '--$1' option is not supported\n$USAGE" >&2 && exit 1; }       # ===> EXIT : Wrong '--' option 
  else
    ! match_pattern "$1" '^[vftp]$' && { echo "The '-$1' option is not supported\n$USAGE" >&2 && exit 2; }        # ===> EXIT : Wrong '-' option
  fi

  # set flag variable and check if it's the first time
  OPT_NAME=$( echo "$1" | sed -e 's/\(.*\)/\U\1/' )
  isSet $( eval echo "\$$OPT_NAME" ) && { echo "The '$1' option can't be positioned more than one time\n$USAGE" >&2 && exit 3; }  # ===> EXIT : same option several times
  eval $OPT_NAME=1
  
}

# Function calling the function 'set_option' for each option in an options group
# $1 : The options group (ex : -vf, -t ...) 
set_group_options(){
  OPTS=$( echo "$1" | sed -e 's/^-//g') # deleting '-'
  
  for I in $(seq 1 ${#OPTS}); do
    set_option $(echo $OPTS | cut -c$I)
  done
}


# Function checking the arguments entered by user
# $1 : The arguments list 
check_arguments(){
  if test $# -eq 1 && test "$1" = "--help"; then
    help
    exit 0                                 # ===> EXIT : after help message
  fi

  ARG_INDEX=0 # Index of current argument
  TAGS_FILE_INDEX=-1 # The number of the argument designating the tags_file  

  for OPT in "$@"; do 
    
    ARG_INDEX=$(($ARG_INDEX+1))
    
    OPT="$OPT"

    # check empty argument
    if ! isSet $OPT; then
      echo "An argument is empty\n$USAGE" >&2 && exit 14;
    fi

    test $ARG_INDEX -eq $TAGS_FILE_INDEX && continue # skip the argument just after the '-t' option

    test $OPT = '--help' && { echo "The '--help' option must be alone\n$USAGE" >&2 && exit 4; }             # ===> EXIT : '--help' isn't alone
  
    # check '-' options
    if match_pattern $OPT "^-[^-]+$" ; then 
      set_group_options $OPT

      if match_pattern $OPT 't' ;then
        TAGS_FILE_INDEX=$(($ARG_INDEX+1))
        TAGS_FILE=$(eval echo \$$TAGS_FILE_INDEX)
        test -f "$TAGS_FILE" || { echo "Error : '-t' : Invalid tags_file '$TAGS_FILE'\n$USAGE">&2 && exit 5; }           # ===> EXIT : Invalid tags_file
        TAGS_BLOCK=$(cat $TAGS_FILE)
      fi

      continue
    fi 

    # check '--' options
    if match_pattern $OPT "^--" ; then
      OPT=$(echo $OPT | sed -r -e 's/^--//'); # deleting '--'
      set_option $OPT double
      continue
    fi

    if ! isSet $SRC_DIR ;then
      test -d "$OPT" || { echo "Invalid path to dir_sources : '$OPT'\n$USAGE" >&2 && exit 6 ;  }                  # ===> EXIT : Invalid source directory
      SRC_DIR="$OPT" 
      continue
    fi

    if ! isSet $DEST_DIR; then
      match_pattern $OPT "^$SRC_DIR$" && { echo "dir_source and dir_dest must be different\n$USAGE ">&2 && exit 7;}               # ===> EXIT : dest_dir is same as src_dir
      DEST_DIR="$OPT"
      continue
    fi
    
    echo "Invalid argument '$OPT'\n$USAGE" >&2 && exit 8                  # ===> EXIT : Invalid argument

  done

  if ! isSet $SRC_DIR ||  ! isSet $DEST_DIR ; then
    echo "Paths to 'dir_sources' and 'dir_dest' must be specified\n$USAGE" >&2
    exit 9                                                                                     # ===> EXIT : source or destination directory not specified
  fi

  if ! isSet $CSS && ! isSet $HTML; then
    set_option css double
    set_option html double
  fi

}

# Function browsing the copy of sources directory to minifie files
# $1 : The destination directory
execute_minifier(){
  if isSet $HTML && test -f "$1" && match_pattern "$1" "^.+\.html?$"; then
    minifier_html "$1"
  fi

  if isSet $CSS && test -f "$1" && match_pattern "$1" "^.+\.css$"; then
    minifier_css "$1"
  fi

  # if the argument isn't directory, we stop the function
  test -d "$1" || return 

  local I
  for I in "$1"/*; do
      execute_minifier "$I"
  done
  rm /tmp/minifier_tmp.txt 2>/dev/null
}

# Function executing the minification of an html file
# $1 : The html file
# N.B. in this function we have to pass by a temporary file ('tmp.txt') because we can't do 'cat file.txt > file.txt', 
#      and "cat file.txt | tee file.txt" doesn't always work
minifier_html(){
  SIZE_B=$(get_size $1)

  # main minification
  cat "$1" | tr "\n" " " | sed -E -e 's/<!--([^-]|-[^-])*--+([^>-]([^-]|-[^-])*--+)*>//g' -e 's/\t/ /g'   -e 's/<([[:alpha:]]+ *)/<\L\1/g' -e 's/\/([[:alpha:]]+ *>)/\/\L\1/g' -e 's/\r/ /g' -e 's/ +/ /g' > /tmp/minifier_tmp.txt
  cat /tmp/minifier_tmp.txt > "$1"

  
  if isSet $T ; then 
    # minification with tags_file
    for TAG in $TAGS_BLOCK; do
      TAG=$(echo "$TAG" | sed -e 's/\(.*\)/\L\1/')
      cat "$1" | sed -E -e "s/ ?<$TAG> ?/<$TAG>/g"  -e "s/ <$TAG([^>]*)> /<$TAG\1>/g" -e "s/ ?<\/$TAG ?> ?/<\/$TAG>/g" > /tmp/minifier_tmp.txt
      cat /tmp/minifier_tmp.txt > "$1"
    done
  fi
  
  SIZE_A=$(get_size $1)
  
  if isSet $V; then
    GAIN=$(echo "scale=6;100-($SIZE_A/$SIZE_B)*100" | bc)
    GAIN=$(echo $GAIN | sed -E -e 's/(.*\..?).*/\1/g')
    echo "FILE HTML : $1 --> $SIZE_A/$SIZE_B : $GAIN%"
  fi
}

# Function executing the minification of a css file
# $1 : The css file
# N.B. in this function we have to pass by a temporary file ('tmp.txt') because we can't do 'cat file.txt > file.txt', 
#      and "cat file.txt | tee file.txt" doesn't always work
minifier_css(){
  SIZE_B=$(get_size "$1")

  cat "$1" | tr "\n" " " | sed -E   -e 's/\t/ /g' -e 's/\r/ /g' -e "s/\/\*[^*]*\*+([^\/*][^*]*\*+)*\// /g" -e 's/ +/ /g' -e 's/^ //g' -e 's/ *([,;:{}>]) */\1/g' > /tmp/minifier_tmp.txt
  cat /tmp/minifier_tmp.txt > "$1"

  if isSet $P ;then
    cat "$1" | sed -E -e 's/ *([()]) */\1/g' > /tmp/minifier_tmp.txt 
    cat /tmp/minifier_tmp.txt > "$1"
  fi
  
  SIZE_A=$(get_size "$1")
  
  if isSet $V; then
    GAIN=$(echo "scale=6;100-($SIZE_A/$SIZE_B)*100" | bc)
    GAIN=$(echo $GAIN | sed -E -e 's/(.*\..?).*/\1/g')
    echo "FILE CSS : $1 --> $SIZE_A/$SIZE_B : $GAIN%"
  fi
}

# Function copying the source directory in the destination directory
# $1 : The source directory
# $2 : The destination directory
copy_directory(){
  PARENTS_NAME=$(echo "$2" | sed -E  -e 's/[^\/]*$//g')
 
  # Asking confirmation to overwrite
  if test -d "$2" ;then 
    if ! isSet $F ; then
      read -p "The '$2' directory already exist, would you overwrite it ? [Y/N] : " CHOICE
      test "$CHOICE" = "Y" || test "$CHOICE" = "y" || { echo "Execution canceled, end of program"; exit 10;}   # ===> EXIT : User don't want to overwrite
    fi
      rm -rf ./"$2" || { echo "Error :  cancellation of overwrite, end of program"; exit 11;} # ===> EXIT : User can't remove folders
  else 
    #  Creation of parents file
    test -z "$PARENTS_NAME" || { mkdir -p "$PARENTS_NAME" || { echo "Error :  folders creation failed, end of program"; exit 12;};} # ===> EXIT : User can't create folders
  fi

  cp -r "$1" "$2" || { echo "Error : '$2' creation canceled, end of program"; exit 13;} # ===> EXIT : User can't copy folder
}

# Function to get the size of a file
get_size(){
  echo $(wc -c "$1" | cut -d" " -f1 )
}

#######################################################
#                       MAIN                          #
#######################################################

USAGE='Enter "./minifier.sh --help" for more informations.'

check_arguments "$@"

DEST_DIR="$(echo $DEST_DIR | sed -E -e 's/\/$//')" # eventually remove '/' at the end 

copy_directory "$SRC_DIR" "$DEST_DIR"

execute_minifier "$DEST_DIR"



