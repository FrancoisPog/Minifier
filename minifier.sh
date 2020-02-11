#! /bin/sh

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

# Function checking if a pattern is present in a string
# $1 : The string
# $2 : The pattern
contains_pattern()(
  ! test -z $( echo "$1" | grep -E "$2" )
  exit $?
)

# Function assigning the value '1' to variables with the same name as the given parameter
# $1 : The option (ex : css, f ...)
# $2 : 'double' if the original option is of type '--', else if is of type '-'
# Exemple : 
#           set_option f -> will create $F and F=1
#           set_option css double -> will create $CSS and CSS=1
#           set_option css or set_option t double -> error
set_option(){
  # check option validity
  if test "$2" = 'double'; then
    ! contains_pattern "$1" '(^css$|^html$)' && { echo "Unsupported option : '--$1'" >&2 && exit 1; }
  else
    ! contains_pattern "$1" '^[vft]$' && { echo "Unsupported option : '-$1'" >&2 && exit 1; }
  fi

  # Create the variable associated with the option and check if it's the first time, if not EXIT
  OPT_NAME=$( echo "$1" | sed -e 's/\(.*\)/\U\1/' )
  test -z $( eval echo "\$$OPT_NAME" ) || { echo "The '$1' option can't be positioned more than one time\n$USAGE" >&2 && exit 1; }
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
    exit 0
  fi

  ARG_NB=0 
  TAGS_FILE=-1 # The number of the argument designating the tags_file  

  for OPT in "$@"; do 
    ARG_NB=$(($ARG_NB+1))

    test $ARG_NB -eq $TAGS_FILE && continue # skip the argument just after the '-t' option

    test $OPT = '--help' && { echo "The '--help' option must be alone\n$USAGE" >&2 && exit 1; }
  

    # check '-' options
    if ! test -z $( echo $OPT | grep -E "^-[^-]+$" ) ; then 
      set_group_options $OPT

      if ! test -z $(echo $OPT | grep 't');then
        TAGS_FILE=$(($ARG_NB+1))
        test -f "$(eval echo $"$(($ARG_NB+1))")" || { echo "Invalid tags_file" && exit 3; }
      fi

      continue
    fi 

    # check '--' options
    if ! test -z $( echo $OPT | grep -E "^--" ) ; then
      OPT=$(echo $OPT | sed -r -e 's/^--//');
      set_option $OPT double
      continue
    fi

    
    test -d $OPT || { echo "Invalid path to 'dir_sources'\n$USAGE" >&2 && exit 4 ;  }

  done
}

# MAIN

USAGE='Enter "./minifier.sh --help" for more informations.'

check_arguments "$@"


echo $"F:$F"
echo $"V:$V"
echo $"T:$T"
echo $"CSS:$CSS"
echo $"HTML:$HTML"



echo "<end>"
