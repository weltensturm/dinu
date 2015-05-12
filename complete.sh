#!/bin/bash

. /usr/share/bash-completion/bash_completion

cmd=$(echo $1 | awk '{print $1;}')
if [ "$cmd" == "$1" ]; then
	exit
fi

if [ -f /usr/share/bash-completion/completions/$cmd ]; then
	. /usr/share/bash-completion/completions/$cmd
fi

__print_completions(){
	for ((i=0;i<${#COMPREPLY[*]};i++)); do
		echo ${COMPREPLY[i]};
	done
};

cmd_complete=$(complete -p | grep " $cmd\$" | sed 's/.* -F \(.*\) '$cmd'/\1/')

COMP_WORDS=($1);
COMP_LINE=\"$1\";
COMP_COUNT=${#1};
COMP_CWORD=$(($(echo $1 | wc -w)))
if [[ "${1: -1}" != " " ]]; then
	((COMP_CWORD--))
	((COMP_COUNT++))
fi
COMP_POINT=$COMP_COUNT

${cmd_complete}


for ((i=0;i<${#COMPREPLY[*]};i++)); do
	if [ ! -e "${COMPREPLY[i]}" ]; then
		__print_completions
		exit
	fi
done


