#!/bin/bash

function my_readlink() {
    cd $1
    pwd
    cd - > /dev/null
}

function cat_readme() {
    echo ""
    echo "Usage: $(basename $0) DELIVERY_DIR REPORTS_DIR"
    echo -e "\tDELIVERY_DIR\tShould be the directory where your project files are"
    echo -e "\tREPORTS_DIR\tShould be the directory where we output the reports"
    echo -e "\t\t\tTake note that existing reports will be overriden"
    echo ""
}

GRAY=""
BLUE=""
RED=""
GREEN=""
YELLOW=""
NO_CLR=""

ITALLIC=$(tput sitm)

if [ -n "$COLORTERM" ]; then
    GRAY=$(tput setaf 0)
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    NO_CLR=$(tput sgr0)
fi

print_custom_error_message() {
    local log_file="$1"

    # Define a table that maps error types to custom messages
    declare -A error_messages
    error_messages["C-G1"]="Multiline statements should not use backslash"
    error_messages["C-G1"]="C files must contain header files (*.h && *.c)"
    error_messages["C-G2"]="In sources files, functions must be separated by a single blank line"
    error_messages["C-G3"]="Preprocessor directives (#ifndef, #define, ...) must be indented"
    error_messages["C-G4"]="Global variables must be avoided, only global constants are allowed"
    error_messages["C-G5"]="Include directives must only include C header files (.h)"
    error_messages["C-G6"]="Lines must end with a single line feed (LF) character ('\n')"
    error_messages["C-G7"]="No trailing whitespaces must be present at the end of the line"
    error_messages["C-G8"]="No more than 1 empty line must be present"
    error_messages["C-G9"]="Non-trivial constant must be defined as macros or global constants"
    error_messages["C-G10"]="Inline assembly are not allowed"
    error_messages["C-O1"]="Repository must not contain compiled files (.o, .a, .out, .exe, ...)"
    error_messages["C-O2"]="Sources in a C programm must only have .c or .h extension"
    error_messages["C-O3"]="Files cannot exeed 10 functions (at most 5 non-static functions)"
    error_messages["C-O4"]="The file name must be clear, explicit following the snake_case convention"
    error_messages["C-F1"]="A function should do one thing and only one thing"
    error_messages["C-F2"]="1 function must contain a verb, be english and follow the snake_case convention"
    error_messages["C-F3"]="The lenght of a column must not exceed 80 characters ('\\n' included)"
    error_messages["C-F4"]="The body of a function must not exceed 20 lines"
    error_messages["C-F5"]="A function must not contain more than 4 parameters"
    error_messages["C-F6"]="A function without parameters must be declared with 'void'"
    error_messages["C-F7"]="Structures must be passed by pointer"
    error_messages["C-F8"]="There must be no comment within a function"
    error_messages["C-F9"]="Nested functions are not allowed"
    error_messages["C-L1"]="A line must correspond to a only a SINGLE statement"
    error_messages["C-L2"]="Indentation must be done with 4 spaces"
    error_messages["C-L3"]="place a space after a comma or keyword"
    error_messages["C-L4"]="Curly brackets"
    error_messages["C-L5"]="Variables must be declared at the beginning of a block, one per line"
    error_messages["C-L6"]="A blank line must separate declarations from instructions"
    error_messages["C-V1"]="Identifiers must be in Eng, following snake_case, and *_t for typedefs, macros with UPPER_CASE"
    error_messages["C-V2"]="Variables can only be grouped in a structure if they are related"
    error_messages["C-V3"]="Pointer's asterisk must be placed next to the variable name"
    error_messages["C-C1"]="Conditional statements cannont be nested more than 3 times"
    error_messages["C-C2"]="Ternary operator is allowed if kept readable"
    error_messages["C-C3"]="Using goto is forbidden"
    error_messages["C-H1"]="Header files cannot contain any function definition"
    error_messages["C-H2"]="Headers must be protected from double inclusion"
    error_messages["C-H3"]="Macros must match only one statement on a single line"
    error_messages["C-A1"]="If a data from a pointer is not modified it should be declared as const"
    error_messages["C-A2"]="Use more accurate types instead of int (size_t, ssize_t, ...)"
    error_messages["C-A3"]="Files must end with a line break (LF, '\\n')"
    error_messages["C-A4"]="Global variables and function unused outside of the file must be declared as static"

    # Add more error types and messages as needed

    while IFS=: read -r file line_number major_error error_type; do
        # Lookup the custom error message based on the error type
        custom_message="${error_messages[$error_type]:-Unknown Error}"

        # Set color based on major error type
        case "$major_error" in
            " MAJOR") COLOR=$RED ;;
            " MINOR") COLOR=$YELLOW ;;
            " INFO")  COLOR=$GREEN ;;
            *)      COLOR=$NO_CLR;;
        esac

        echo "$file:$line_number Error: $COLOR$error_type$NO_CLR $ITALLIC\"$custom_message\"$NO_CLR"
    done < <(grep -E '^.+:[0-9]+: [A-Z]+:C-[A-Z0-9]+$' "$log_file")
}

if [ $# == 1 ] && [ $1 == "--help" ]; then
    cat_readme
elif [ $# = 2 ]; then
    DELIVERY_DIR=$(my_readlink "$1")
    REPORTS_DIR=$(my_readlink "$2")
    DOCKER_SOCKET_PATH=/var/run/docker.sock
    HAS_SOCKET_ACCESS=$(
        test -r $DOCKER_SOCKET_PATH
        echo "$?"
    )
    GHCR_REGISTRY_TOKEN=$(curl -s "https://ghcr.io/token?service=ghcr.io&scope=repository:epitech/coding-style-checker:pull" | grep -o '"token":"[^"]*' | grep -o '[^"]*$')
    GHCR_REPOSITORY_STATUS=$(curl -I -f -s -o /dev/null -H "Authorization: Bearer $GHCR_REGISTRY_TOKEN" "https://ghcr.io/v2/epitech/coding-style-checker/manifests/latest" && echo 0 || echo 1)
    BASE_EXEC_CMD="docker"
    EXPORT_FILE="$REPORTS_DIR"/coding-style-reports.log
    ### delete existing report file
    rm -f "$EXPORT_FILE"

    ### Pull new version of docker image and clean olds
    if [ $HAS_SOCKET_ACCESS -ne 0 ]; then
        echo -n "$(tput setaf 5)WARNING:${GRAY} Socket access is denied$(tput sgr0)"
        echo -n "To fix this we will add the current user to docker group with : sudo usermod -a -G docker $USER"
        read -p "Do you want to proceed? (yes/no) " yn
        case $yn in
        yes | Y | y | Yes | YES)
            echo "ok, we will proceed"
            sudo usermod -a -G docker $USER
            echo "$(tput setaf 1)You must reboot your computer for the changes to take effect"
            ;;
        no | N | n | No | NO) echo "ok, Skipping" ;;
        *) echo "invalid response, Skipping" ;;
        esac
        BASE_EXEC_CMD="sudo ${BASE_EXEC_CMD}"
    fi

    if [ $GHCR_REPOSITORY_STATUS -eq 0 ]; then
        echo "${GRAY} Downloading new image and cleaning old one..."
        $BASE_EXEC_CMD pull ghcr.io/epitech/coding-style-checker:latest && $BASE_EXEC_CMD image prune -f
        echo "${GRAY} Download OK$(tput sgr0)"
    else
        echo "$(tput setaf 5)WARNING: Skipping image download$(tput sgr0)"
    fi

    ### generate reports
    $BASE_EXEC_CMD run --rm --security-opt "label:disable" -i -v "$DELIVERY_DIR":"/mnt/delivery" -v "$REPORTS_DIR":"/mnt/reports" ghcr.io/epitech/coding-style-checker:latest "/mnt/delivery" "/mnt/reports"
    [[ -f "$EXPORT_FILE" ]] && echo "$(tput setaf 1)$(wc -l <"$EXPORT_FILE")$(tput sgr0) coding style error(s) reported in $(tput setaf 4)"$EXPORT_FILE"$(tput sgr0)"
    if [ -s $EXPORT_FILE ]; then
        echo "Here is the report:"
        print_custom_error_message "$EXPORT_FILE"
    fi
else
    cat_readme
fi
