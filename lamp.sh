#!/bin/bash
set -euo pipefail

install_service() {
	apt -yq install $1
}

check_service_status() {
	systemctl status $1 --no-pager
}

cmd_reboot() {
	whiptail --title "Reboting..." --msgbox "This server will reboot in 5 seconds" 8 78
	sleep 5
	reboot

}

display_ascii() {
	echo -e '
	m        mm   m    m mmmmm          mmmm mmmmmmm   mm     mmm  m    m
	#        ##   ##  ## #   "#        #"   "   #      ##   m"   " #  m" 
	#       #  #  # ## # #mmm#"        "#mmm    #     #  #  #      #m#   
	#       #mm#  # "" # #                 "#   #     #mm#  #      #  #m 
	#mmmmm #    # #    # #             "mmm#"   #    #    #  "mmm" #   "m
	'
	sleep 1

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

    SERVICE_SELECTED=$(whiptail --title "LAMP" --checklist "Select the LAMP service want to install and configure :" 20 90 4 \
    "L" "Linux  - Initial Configuration for linux    " OFF \
    "A" "Apache - Install APACHE web server" OFF \
    "M" "Mysql  - Install MYSQL server" OFF \
    "P" "PHP    - Install PHP" OFF 3>&1 1>&2 2>&3)

    if [ $? -eq 0 ]; then
        if [[ -z ${SERVICE_SELECTED} ]];then
            echo "No Service Selected! Please choose any [LAMP] services ..."
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

			if [[ ${SERVICE_SELECTED} == *"P"* ]];then
                PHP="true"
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
		check_service_status mysql
		echo "[+] Configure mysql OK ..."
	fi
}

# configure php
configure_service_php() {
	if [[ ${PHP:-} == "true" ]];then
		echo "[+] Install PHP"
		install_service "php libapache2-mod-php php-mysql php-curl php-json php-cgi \
		php-curl php-gd php-mbstring php-xml php-xmlrpc"

		if (whiptail --title "PHP test file" --yesno "This script will create php test file. Do you agree?" 8 78)
			then
				echo "[+] Test PHP created at /var/www/html/info.php"
				echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/info.php
				whiptail --title "PHP test file created" --msgbox \
				"\\n PHP test page can be access by: \
				\\n http://{server-ip}/info.php
				\\n [WARNING] Please delete the file if this is production server \
				\\n Location file: "/var/www/html/info.php"
				\\n" 14 100
				echo "[+] PHP test page can be access by: http://{server-ip}/info.php"

			else
				:
		fi
	fi
}


# main
main() {
	display_ascii
    check_dependency
    get_confirmation_service
    configure_service_linux
	configure_service_apache
	configure_service_mysql
	configure_service_php
	echo "[+] Installation Done"
	cmd_reboot
}

main