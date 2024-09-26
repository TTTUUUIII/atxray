#!/bin/bash

ATXRAY_HOME=${ATXRAY_HOME:-$HOME/.atxray}

if ! git --version >/dev/null 2>&1; then
	read -p "Continue after installing git? [Y/n]" agreed
	agreed=$(echo ${argeed:-Y} | tr A-Z a-z)
	if [ $agreed != "y" ] && [ $agreed != "yes" ]; then
		echo -e "\e[31mInstall aborted!"
		exit 1
	fi
	apt install -y git
fi

git clone https://github.com/TTTUUUIII/atxray.git $ATXRAY_HOME &&
	chmod +x $HOME/.atxray/atxray.sh &&
	ln -sf $ATXRAY_HOME/atxray.sh $HOME/atxray.sh

exit $?
