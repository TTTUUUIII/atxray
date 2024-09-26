#!/bin/bash

ATXRAY_HOME=${ATXRAY_HOME:-$HOME/.atxray}

if [ -d $ATXRAY_HOME ]; then
	echo -e "\e[31m$ATXRAY_HOME already exists, aborted!\e[0m"
	exit 1
fi

if ! git --version >/dev/null 2>&1; then
	read -p "Continue after installing git? [Y/n]" agreed
	agreed=$(echo ${argeed:-Y} | tr A-Z a-z)
	if [ $agreed != "y" ] && [ $agreed != "yes" ]; then
		echo -e "\e[31mGit not install, aborted!\e[0m"
		exit 1
	fi
	apt install -y git
fi

git clone https://github.com/TTTUUUIII/atxray.git $ATXRAY_HOME &&
	chmod +x $HOME/.atxray/atxray.sh &&
	ln -sf $ATXRAY_HOME/atxray.sh $HOME/atxray.sh

exit $?
