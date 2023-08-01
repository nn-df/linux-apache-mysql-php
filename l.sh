#!/bin/bash
set -euo pipefail

install_service() {
	apt -yq install $1
}

check_dependency() {
	# check root
	if [[ $EUID -ne 0 ]]; then
	   echo "[!] This script must be run as root" 
	   exit 1
	fi

	# check network status (internet and dns)
	if ping -q -c 3 -W 1 www.google.com > /dev/null 2>&1;then
		echo "[+] Checking network OK"
	else 
		if ping -q -c 3 -W 1 8.8.8.8 > /dev/null 2>&1;then
			echo "[!] Check your DNS setting"
			exit $?
		else
			echo "[!] Check your NETWORK setting"
			exit $?
		fi
	fi

	# check whiptail
	if which whiptail > /dev/null 2>&1; then
		echo "[+] Checking whiptail OK"
		:
	else
		install_service whiptail
	fi
	
}

get_confirmation_service() {

    SERVICE_SELECTED=$(whiptail --title "L" --checklist "Select the L service want to install and configure :" 20 90 4 \
    "L" "Linux - Initial Configuration for linux    " OFF \
    "2" "2" OFF \
    "3" "3" OFF \
    "4" "4" OFF 3>&1 1>&2 2>&3)

    if [ $? -eq 0 ]; then
        if [[ -z ${SERVICE_SELECTED} ]];then
            echo "No Service Selected! Please choose any [L] services ..."
            exit 1
        else
            if [[ ${SERVICE_SELECTED} == *"L"* ]];then
                LINUX="true"
            fi
        fi
    fi


}

# configure linux
configure_service_linux() {
    if [[ ${LINUX:-} == "true" ]];then
        echo "[+] Configure linux"
        sudo bash linux/linux.sh
        echo "[+] Configure linux OK ..."
    fi
}


# main
main() {
    check_dependency
    get_confirmation_service
    configure_service_linux
}

main