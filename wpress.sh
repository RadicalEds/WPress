#!/bin/bash
#####################################
VERSION="1.0"
NAME="wpress"
AUTHOR="RadicalEd"
DESCRIPTION="Installs and Configures a LAMP Server with a Wordpress VHost."
LICENSE=""
PROGRAM=$0
HIGHLIGHT="cyan"
#####################################
# Defaults

DIRECTORY="/var/www"
DBUSER="groot"
DBPASS="wpress"
ADMINUSER="groot"
ADMINPASS="wpress"

# End of Defaults
#####################################
# Printing Functions

c () { # Set/Clear Colors
	case "${1}" in
		(black)      tput setaf 0;;
		(red)        tput setaf 1;;
		(green)      tput setaf 2;;
		(yellow)     tput setaf 3;;
		(blue)       tput setaf 4;;
		(magenta)    tput setaf 5;;
		(cyan)       tput setaf 6;;
		(white)      tput setaf 7;;
		(bg_black)   tput setab 0;;
		(bg_red)     tput setab 1;;
		(bg_green)   tput setab 2;;
		(bg_yellow)  tput setab 3;;
		(bg_blue)    tput setab 4;;
		(bg_magenta) tput setab 5;;
		(bg_cyan)    tput setab 6;;
		(bg_white)   tput setab 7;;
		(n)          tput sgr0;;
		(none)       tput sgr0;;
		(clear)      tput sgr0;;
	esac
}

banner () {
cat << 'EOF' | cut -c1-$(tput cols) | sed -e "1s/^/$(c blue)/" -e "4s/$/$(c n)/" -e "5s/^/$(c cyan)/" -e "6s/$/$(c n)/" -e 's/   / . /g' -e 's/   / + /g' >&2
  .::    .   .:::::::::::. :::::::..  .,:::::: .::::::.  .::::::.   
  ';;,  ;;  ;;;'`;;;```.;;;;;;;``;;;; ;;;;'''';;;`    ` ;;;`    `   
   '[[, [[, [['  `]]nnn]]'  [[[,/[[['  [[cccc '[==/[[[[,'[==/[[[[,  
     Y$c$$$c$P    $$$""     $$$$$$c    $$""""   '''    $  '''    $  
      "88"888     888o      888b "88bo,888oo,__88b    dP 88b    dP  
       "M "M"     YMMMb     MMMM   "W" """"YUMMM"YMmMY"   "YMmMY"   
EOF
}


usage () {
banner

cat << EOF >&2

$(c $HIGHLIGHT)$NAME$(c n) v$VERSION - Written By $(c $HIGHLIGHT)$AUTHOR$(c n)

$(echo -n "	$DESCRIPTION" | fmt -w $(tput cols))

	Requires root, internet access, and a working domain name

$(c $HIGHLIGHT)USAGE$(c n): $PROGRAM [options] <working-domain.com>

	-h            : show usage
	-x <path>     : install site to this path     ($DIRECTORY)
	-n <name>     : name of the database to use   (same as domain)
	-u <user>     : database user to setup/assign ($DBUSER)
	-p <pass>     : password for the db user      ($DBPASS)
	-U <User>     : New Admin Username            ($ADMINUSER)
	-P <Password> : New Admin Password            ($ADMINPASS)
	-e <email>    : Email for both Cert & WPAdmin (webmaster@your-domain)

EOF
}

error () {
	code="$1";shift
	case "$code" in
		(1) usage;;
	esac
	echo "Error $code: $*" >&2
	exit "$code"
}

hr () { # Horizontal Rule the length of the banner
	character="${1:--}"
	twidth=$(tput cols)
	bwidth=$(banner 2>&1 | wc -L)
	printf -v _hr "%*s" $((twidth<bwidth-3 ? twidth : bwidth-3)) && echo "${_hr// /$character}";
}
clearline () {
	printf "\r%*s\r" $(tput cols);
}
statusline () {
    if [ "$DEBUG" ];then
        echo "$*" >&2
    else
        echo -e -n "\r$*" >&2
    fi
}
spinner () { # $1=pid $*=text
	# show a spinner while pid is active
	symbols=('/' '-' '\' '|')
	len=${#symbols[@]}
	idx=0

	pid=$1
	shift

	while ps -p $pid >/dev/null;do
		clearline >&2
		printf "\r  $(c yellow)[${symbols[$((idx % len))]}]$(c n) $*" >&2
		idx=$((idx+1))
		sleep 0.1
	done
	clearline >&2
}

blocksay() { # $1=color $*=text
	color="$1"
	symbol=${BLOCKSAYSYMBOL:-+}
	shift
	echo "  $(c $color)[$symbol]$(c n) $*" >&2
}

# End of Printing Functions
#####################################
# Arguments

while getopts "hvx:n:u:p:U:P:e:" o;do
	case "${o}" in
		(h) usage && exit          ;;
		(v) DEBUG="true"           ;;
		(x) DIRECTORY="$OPTARG"    ;;
		(n) DBNAME="$OPTARG"       ;;
		(u) DBUSER="$OPTARG"       ;;
		(p) DBPASS="$OPTARG"       ;;
		(U) ADMINUSER="$OPTARG"    ;;
		(P) ADMINPASS="$OPTARG"    ;;
		(e) CERTMAIL="$OPTARG"     ;;
		(*) echo "Try Using $PROGRAM -h for Help And Information" >&2 && exit 1;;
	esac
done

# Require Root Access
if (( $EUID != 0 ));then
	echo "This program requires root access." >&2
	# if we are not root, launch with sudo
    sudo "${BASH_SOURCE[0]}" $@
	# then exit to prevent a second run
    exit $?
fi

shift $((OPTIND-1))

[ "$1" ] && DOMAIN="$1" || error 1 "We Need a Domain"

# End of Arguments
#####################################
# Variables

DIRECTORY="${DIRECTORY:-/var/www}"
DBNAME="${DBNAME:-$DOMAIN}"
DBNAME="$(echo -n "$DBNAME" | sed 's/[^A-Za-z0-9]/_/g')"
DBUSER="${DBUSER:-groot}"
DBPASS="${DBPASS:-wpress}"
ADMINUSER="${ADMINUSER:-groot}"
ADMINPASS="${ADMINPASS:-wpress}"
LOGDIR="${LOGDIR:-/var/log/apache2}"
CERTMAIL="${CERTMAIL:-webmaster@$DOMAIN}"

# End Of Variables
#####################################
# Requirements

	# Required Packages for LAMP Wordpress

# End of Requirements
#####################################
# Functions

success () {
	echo 0 > /tmp/$$.tmpfile
}
failure () {
	rv=${1:-1}
	echo "$rv" > /tmp/$$.tmpfile
	return "$rv"
}
cleanup () {
	erm () { # remove a file/directory if it exists
		[ -e "$1" ] && rm -rf "$1" 2> /dev/null 1> /dev/null
	}
	erm "$DIRECTORY/$DOMAIN/docroot/firewall.test"
	erm /tmp/$$.tmpfile
	erm /tmp/wordpress.tar.gz
}
evaluate () {
	rv=$(cat /tmp/$$.tmpfile)
	rm /tmp/$$.tmpfile
	if [ "$rv" -eq 0 ];then
		blocksay green "$1"
	else
		BLOCKSAYSYMBOL="-" blocksay red "$2 (Code: $?)"
	fi
	return $rv
}
close () {
	cleanup
	exit "${1:-0}"
}
print_vhost () {
cat << EOF
<VirtualHost *:80>
	ServerName $DOMAIN
	ServerAdmin webmaster@localhost

	DocumentRoot $DIRECTORY/$DOMAIN/docroot

	<Directory $DIRECTORY/$DOMAIN/docroot>
		Options FollowSymLinks
		AllowOverride Limit Options FileInfo
		DirectoryIndex index.php
		Require all granted
	</Directory>

	<Directory $DIRECTORY/$DOMAIN/wp-content>
		Options FollowSymLinks
		Require all granted
	</Directory>

	ErrorLog $LOGDIR/$DOMAIN/error.log
	CustomLog $LOGDIR/$DOMAIN/access.log combined

</VirtualHost>
EOF
}

install_packages() {
	PACKAGES=(
		'curl'                   # To Retrieve Wordpress
		'tar'                    # To Decompress Wordpress
		'certbot'                # For Setting up TLS
		'python3-certbot-apache' # For Setting up TLS
		'apache2'                # Our Server
		'mariadb-server'         # Our Database
		'php'                    # Our Language
		'libapache2-mod-php'     # Teach Server our Language
		'ghostscript'            # Wordpress Dependency 
		'php-mysql'              # Wordpress Dependency
		'php-zip'                # Wordpress Dependency
		'php-xml'                # Wordpress Dependency
		'php-mbstring'           # Wordpress Dependency
		'php-json'               # Wordpress Dependency
		'php-intl'               # Wordpress Dependency
		'php-imagick'            # Wordpress Dependency
		'php-curl'               # Wordpress Dependency
		'php-bcmath'             # Wordpress Dependency
	);
	(
		apt update 2>/dev/null 1>/dev/null || failure || exit
		apt install -y ${PACKAGES[@]} 1>/dev/null 2>/dev/null || failure || exit

		# install wp-cli, a php commandline library that performs common wordpress tasks
		if [ ! -e "/usr/local/bin/wp" ];then
			curl --silent https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar > /usr/local/bin/wp 2> /dev/null || failure || exit
			chmod +x "/usr/local/bin/wp"
		fi
		success
	) &
	spinner $! "Installing Packages..."
	evaluate "Packages Installed" "Apt Error" || close $?
}

check_services() {
	(
		systemctl restart apache2 || failure || exit
		systemctl restart mysql || failure || exit
		success
	) &
	spinner $! "Restarting Services..."
	evaluate "Services Are Running" "There Was a Problem Starting the Services" || close $?
}
check_firewall() {
	(
		if which ufw >/dev/null;then
			ufw allow http > /dev/null 2> /dev/null
			ufw allow https > /dev/null 2> /dev/null
		fi
		testfile="$DIRECTORY/$DOMAIN/docroot/firewall.test"
		date +%s > "$testfile"
		curl --silent "http://$DOMAIN/firewall.test" > /dev/null 2> /dev/null || failure || exit
		rm "$testfile"
		success
	) &
	spinner $! "Checking Firewall..."
	evaluate "Firewall is allowing traffic" "There was an Error with the Firewall" || close $?
}
check_domain() {
	(
		if which dig > /dev/null;then
			# check with dig
			[ "$(dig $DOMAIN +short)" ] || failure || exit
		else
			# check with ping
			ping -c1 $DOMAIN > /dev/null 2> /dev/null || failure || exit
		fi
		success
	) &
	spinner $! "Checking Domain..."
	evaluate "The Domain is Working" "Could not resolve the domain" || close $?
}
create_directories() {
	(
		if [ ! -e "$DIRECTORY/$DOMAIN/docroot" ];then
			mkdir -p "$DIRECTORY/$DOMAIN/docroot" || failure || exit # Site Root
		fi
		if [ ! -e "$LOGDIR/$DOMAIN" ];then
			mkdir -p "$LOGDIR/$DOMAIN/" || failure || exit # For Log Files
			touch "$LOGDIR/$DOMAIN/access.log" # so vhost will find it
			touch "$LOGDIR/$DOMAIN/error.log"  # so vhost will find it
			chgrp -hR adm "$LOGDIR/$DOMAIN/" || failure || exit # So Server Can Write Logs
		fi
		success
	) &
	spinner $! "Creating Directory Structure..."
	evaluate "Directories Created" "There was an Issue creating Directories" || close $?
}
install_wordpress() {
	(

		# get wordpress
		curl --silent https://wordpress.org/latest.tar.gz >> /tmp/wordpress.tar.gz || failure || exit
		tar -xzf /tmp/wordpress.tar.gz -C "$DIRECTORY/$DOMAIN/" 2>/dev/null 1>/dev/null || failure || exit
		rm -rf "$DIRECTORY/$DOMAIN/docroot" "/tmp/wordpress.tar.gz" 2> /dev/null 1> /dev/null || failure || exit
		mv "$DIRECTORY/$DOMAIN/wordpress" "$DIRECTORY/$DOMAIN/docroot" 2> /dev/null 1> /dev/null || failure || exit
		chown -R www-data:www-data "$DIRECTORY/$DOMAIN"

		# setup wordpress
		cd "$DIRECTORY/$DOMAIN/docroot"
		sudo -u www-data /usr/local/bin/wp core config --dbname="$DBNAME" --dbuser="$DBUSER" --dbpass="$DBPASS" 2> /dev/null 1> /dev/null || failure || exit
		sudo -u www-data /usr/local/bin/wp core install --url="https://$DOMAIN/" --title="$DOMAIN" --admin_user="$ADMINUSER" --admin_password="$ADMINPASS" --admin_email="$CERTMAIL" 2> /dev/null 1> /dev/null || failure || exit

		success
	) &
	spinner $! "Installing Wordpress..."
	evaluate "Wordpress Installed" "Something went wrong while installing Wordpress" || close $?
}
install_vhost() {
	(
		sdir="/etc/apache2/sites-available"
		print_vhost > "$sdir/$DOMAIN.conf" || failure || exit
		a2ensite $DOMAIN.conf 2>/dev/null 1>/dev/null || failure || exit
		a2enmod rewrite 2>/dev/null 1>/dev/null || failure || exit
		success
	) &
	spinner $! "Creating VHost..."
	evaluate "VHost Created" "Error when creating VHost" || close $?
}
install_cert() {
	(
		certbot -d $DOMAIN -m $CERTMAIL --reinstall --agree-tos --no-eff-email 2>/dev/null 1>/dev/null || failure || exit
		success
	) &
	spinner $! "Installing Certificate With Certbot..."
	evaluate "Certificate Installed" "Error while installing Certificate" || close $?
}
setup_database() {
	(
		mysql -u root -e "CREATE DATABASE IF NOT EXISTS $DBNAME;" 2>/dev/null 1>/dev/null || failure || exit
		mysql -u root -e "CREATE USER IF NOT EXISTS '$DBUSER'@'localhost' IDENTIFIED BY '$DBPASS';" 2>/dev/null 1>/dev/null || failure || exit
		mysql -u root -e "GRANT ALL PRIVILEGES ON $DBNAME.* TO '$DBUSER'@'localhost';" 2>/dev/null 1>/dev/null || failure || exit
		mysql -u root -e "FLUSH PRIVILEGES;" 2>/dev/null 1>/dev/null || failure || exit
		success
	) &
	spinner $! "Building Database..."
	evaluate "Database Configured" "Error while Configuring Database" || close $?
}


# End of Functions
#####################################
# Execution

trap 'close' SIGINT

	# Display Fancy Banner
clear
echo >&2
banner >&2
echo >&2
echo "    $DESCRIPTION" | fmt -w $(tput cols) >&2
hr | sed -e 's/^../ </g' -e 's/..$/> /g' >&2

	# Display Details
echo >&2
cat << EOF >&2
	Domain:   $DOMAIN
	Admin:    $ADMINUSER/$ADMINPASS
	DB User:  $DBUSER/$DBPASS
	Database: $DBNAME
	Sitepath: $DIRECTORY/$DOMAIN
	Logpath:  $LOGDIR/$DOMAIN
EOF
echo >&2
hr | sed -e 's/^../ </g' -e 's/..$/> /g' >&2

	# Do The Things
echo >&2
check_domain
install_packages
create_directories
install_vhost
check_services
check_firewall
install_cert
setup_database
install_wordpress
echo >&2
hr | sed -e 's/^../ </g' -e 's/..$/> /g' >&2
echo >&2
cat << EOF >&2
	$(c green)Wordpress Successfully Installed$(c n)
	$(c cyan)https://$DOMAIN/$(c n)
EOF
echo >&2
close



# End of Execution
#####################################
