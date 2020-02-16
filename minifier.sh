#! /bin/sh
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
                --css        CSS files are minified
                --html       HTML files are minified
                if none of the 2 previous options is present, the HTML and CSSfiles are minified
                
                -t tags_file the "white space" characters preceding and following the
                                tags (opening or closing) listed in the ’tags_file’ are deleted'
}


# Function checking if a string matching with pattern
# $1 : The string
# $2 : The pattern
match_pattern(){
  ! test -z $( echo "$1" | grep -E "$2" )
  return $?
}

# Function cheking if a variable is already initialized
# $1 : The variable name 
isSet()(
  ! test "$1" = ""
  return $?
)

# Function assigning the value '1' to variables with the same name as the given parameter
# $1 : The option (ex : css, f ...) without '-' or '--'
# $2 : 'double' if the original option is of type '--', else if is of type '-'
# Exemple : 
#           'set_option f' -> will create $F and $F=1
#           'set_option css double' -> will create $CSS and $CSS=1
#           'set_option css' or 'set_option t double' -> error
set_option(){
  # check option validity
  if test "$2" = 'double'; then
    ! match_pattern "$1" '(^css$|^html$)' && { echo "The '--$1' option is not supported\n$USAGE" >&2 && exit 1; }       # ===> EXIT : Wrong '--' option 
  else
    ! match_pattern "$1" '^[vft]$' && { echo "The '-$1' option is not supported\n$USAGE" >&2 && exit 1; }        # ===> EXIT : Wrong '-' option
  fi

  # Create the variable associated with the option and check if it's the first time
  OPT_NAME=$( echo "$1" | sed -e 's/\(.*\)/\U\1/' )
  isSet $( eval echo "\$$OPT_NAME" ) && { echo "The '$1' option can't be positioned more than one time\n$USAGE" >&2 && exit 1; }  # ===> EXIT : same option several times
  eval $OPT_NAME=1
  
}

# Function calling 'set_option' for each option in an options group
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

  ARG_NB=0 
  TAGS_FILE_INDEX=-1 # The number of the argument designating the tags_file  

  for OPT in "$@"; do 
    ARG_NB=$(($ARG_NB+1))
    OPT="$OPT"
    test $ARG_NB -eq $TAGS_FILE_INDEX && continue # skip the argument just after the '-t' option

    test $OPT = '--help' && { echo "The '--help' option must be alone\n$USAGE" >&2 && exit 1; }             # ===> EXIT : '--help' isn't alone
  

    # check '-' options
    if match_pattern $OPT "^-[^-]+$" ; then 
      set_group_options $OPT

      if match_pattern $OPT 't' ;then
        TAGS_FILE_INDEX=$(($ARG_NB+1))
        TAGS_FILE=$(eval echo \$$TAGS_FILE_INDEX)
        test -f "$TAGS_FILE" || { echo "Error : '-t' : Invalid tags_file '$TAGS_FILE'\n$USAGE">&2 && exit 3; }           # ===> EXIT : Invalid tags_file
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
      test -d "$OPT" || { echo "Invalid path to dir_sources : '$OPT'\n$USAGE" >&2 && exit 4 ;  }                  # ===> EXIT : Invalid source directory
      SRC_DIR="$OPT" 
      continue
    fi

    if ! isSet $DEST_DIR; then
      match_pattern $OPT "^$SRC_DIR$" && { echo "dir_source and dir_dest must be different\n$USAGE ">&2 && exit 1;}               # ===> EXIT : dest_dir is same as src_dir
      DEST_DIR="$OPT"
      continue
    fi
    
    echo "Invalid argument '$OPT'\n$USAGE" >&2 && exit 5                  # ===> EXIT : Invalid argument

  done

  if ! isSet $SRC_DIR ||  ! isSet $DEST_DIR ; then
    echo "Paths to 'dir_sources' and 'dir_dest' must be specified\n$USAGE" >&2
    exit 3                                                                                      # ===> EXIT : source or destination directory not specified
  fi

}


execute_minifier(){
  if isSet $HTML && test -f "$1" && match_pattern "$1" "^.+\.html$"; then
    echo "- html file : $1"
    minifier_html "$1"
  fi

  if isSet $CSS && test -f "$1" && match_pattern "$1" "^.+\.css$"; then
    echo "- css file : $1"
    minifier_css "$1"
  fi

  # if the argument isn't directory, we stop the function
  test -d "$1" || return 
  local I
  for I in "$1"/*; do
      execute_minifier "$I"
  done
}


minifier_html(){
  SVG_IFS=$IFS
  # echo "$1"
  cat "$1" | tr "\n" " " | sed -E -e 's/<!--([^(-->)])*-->/ /g'  -e 's/\t/ /g' -e 's/\r/ /g' -e 's/ +/ /g' -e 's/<([[:alpha:]]+ *)/<\L\1/g' -e 's/\/([[:alpha:]]+ *>)/\/\L\1/g' | tee "$1" >/dev/null
  
  if isSet $T ; then 
    IFS=':'
    for TAG in $TAGS_BLOCK; do
      TAG=$(echo "$TAG" | sed -e 's/\(.*\)/\L\1/')
      FILE=$(cat "$1")
      echo "$FILE" | sed -E -e "s/ ?<$TAG> ?/<$TAG>/g"  -e "s/ <$TAG([^>]*)> /<$TAG\1>/g" -e "s/ ?<\/$TAG ?> ?/<\/$TAG>/g"  | tee "$1" > /dev/null
      ! test -s "$1" && echo $TAG && exit 8
    done
  fi
  IFS=$SVG_IFS
}

minifier_css(){
  cat "$1" | tr "\n" " " | sed -r  -e 's/ +/ /g' -e 's/\t/ /g' -e 's/\r/ /g' -e "s/\/\*[^*]*\*+([^\/*][^*]*\*+)*\// /g" | tee "$1" >/dev/null
}


copy_directory(){
  if test -d "$2" && ! isSet $F ;then
    read -p "The '$2' directory already exist, would you overwrite it ? [Y/N] : " CHOICE
    test "$CHOICE" = "Y" || test "$CHOICE" = "y" || { echo "Execution canceled, end of program."; exit 4;}   # ===> EXIT : User don't want to overwrite
    rm -rf ./"$2" || { echo "Error :  overwrite cancelation"; exit 4;}
  fi 
  if isSet $F; then 
    rm -rf ./"$2"  || { echo "Error :  overwrite cancelation"; exit 4;}
  fi
 
  cp -r "$1" ./"$2" || { echo "Error : dest_dir creation canceled"; exit 4;}
}


#######################################################
#                       MAIN                          #
#######################################################

USAGE='Enter "./minifier.sh --help" for more informations.'

check_arguments "$@"

copy_directory "$SRC_DIR" "$DEST_DIR"

execute_minifier "$DEST_DIR"

echo "\n"
echo $"F:$F"
echo $"V:$V"
echo $"T:$T"
echo $"TAGS_FILE:$TAGS_FILE"
echo $"CSS:$CSS"
echo $"HTML:$HTML"
echo $"SRC_DIR:$SRC_DIR"
echo $"DEST_DIR:$DEST_DIR"









echo "<end>"




