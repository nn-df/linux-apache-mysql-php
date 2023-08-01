#!/bin/bash
set -euo pipefail

install_service() {
	apt -yq install $1
}

check_service_status() {
	systemctl status $1 --no-pager
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

    SERVICE_SELECTED=$(whiptail --title "LAM" --checklist "Select the LAM service want to install and configure :" 20 90 4 \
    "L" "Linux  - Initial Configuration for linux    " OFF \
    "A" "Apache - Install APACHE web server" OFF \
    "M" "Mysql  - Install MYSQL server" OFF \
    "4" "4" OFF 3>&1 1>&2 2>&3)

    if [ $? -eq 0 ]; then
        if [[ -z ${SERVICE_SELECTED} ]];then
            echo "No Service Selected! Please choose any [L] services ..."
            exit 1
        else
            if [[ ${SERVICE_SELECTED} == *"L"* ]];then
                LINUX="true"
            fi

			if [[ ${SERVICE_SELECTED} == *"A"* ]];then
                APACHE="true"
            fi

			if [[ ${SERVICE_SELECTED} == *"M"* ]];then
                MYSQL="true"
            fi
        fi
    fi


}

check_ufw_status() {
	UFW_STATUS=$(sudo ufw status | grep -i active | awk '{ print $2 }')
	if [ ${UFW_STATUS} == "active" ];then
		UFW_STATUS="enable"
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

# configure apache
configure_service_apache() {
	if [[ ${APACHE:-} == "true" ]];then
        echo "[+] Configure apache"
        install_service apache2
		
		echo "[+] check ufw"
		check_ufw_status
		if [[ ${UFW_STATUS} == "enable" ]];then
			echo "[+] Ufw fw enable. Allow port 80/443"
			sudo ufw allow 80
			sudo ufw allow 443
		fi
		
		echo "[+] Check apache status ..."
		check_service_status apache2
        echo "[+] Configure apache OK ..."
    fi
}

# configure mysql
configure_service_mysql() {
	if [[ ${MYSQL:-} == "true" ]];then
		echo "[+] Install MYSQL"
		install_service mysql-server

		echo "[+] Configure MYSQL"
		sudo mysql_secure_installation

		echo "[+] Check mysql status ..."
		check_service_status apache2
		echo "[+] Configure mysql OK ..."
	fi
}

# main
main() {
    check_dependency
    get_confirmation_service
    configure_service_linux
	configure_service_apache
	configure_service_mysql
}

main