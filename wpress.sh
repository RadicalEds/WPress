#!/bin/bash
#####################################
VERSION="0.1"
NAME="wpress"
AUTHOR="RadicalEd"
DESCRIPTION="Installs and configures a LAMP Server with Wordpress."
LICENSE=""
PROGRAM=$0
HIGHLIGHT="cyan"
#####################################
# Defaults

DIRECTORY="/var/www"
DBUSER="groot"
DBPASS="toorg"
ADMINUSER="groot"
ADMINPASS="toorg"

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
cat << 'EOF' | sed -e "1s/^/$(c blue)/" -e "4s/$/$(c n)/" -e "5s/^/$(c cyan)/" -e "6s/$/$(c n)/" >&2
  .::    .   .:::::::::::::. :::::::..  .,:::::: .::::::.  .::::::. 
  ';;,  ;;  ;;;'  `;;;```.;;;;;;;``;;;; ;;;;'''';;;`    ` ;;;`    ` 
   '[[, [[, [['    `]]nnn]]'  [[[,/[[['  [[cccc '[==/[[[[,'[==/[[[[,
     Y$c$$$c$P      $$$""     $$$$$$c    $$""""   '''    $  '''    $
      "88"888       888o      888b "88bo,888oo,__88b    dP 88b    dP
       "M "M"       YMMMb     MMMM   "W" """"YUMMM"YMmMY"   "YMmMY" 
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
	-v            : enable debugging messages
	-x <path>     : install site to this path     ($DIRECTORY)
	-n <name>     : name of the database to use   (same as domain)
	-u <user>     : database user to setup/assign ($DBUSER)
	-p <pass>     : password for the db user      ($DBPASS)
	-U <User>     : New Admin Username            ($ADMINUSER)
	-P <Password> : New Admin Password            ($ADMINPASS)

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

hr () { # Horizontal Rule
	character="${1:--}"
	printf -v _hr "%*s" $(tput cols) && echo "${_hr// /$character}";
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
		printf "\r	$(c yellow)[${symbols[$((idx % len))]}]$(c n) $*" >&2
		idx=$((idx+1))
		sleep 0.3
	done
	clearline >&2
}

blocksay() { # $1=color $*=text
	color="$1"
	shift
	echo "	$(c $color)[+]$(c n) $*" >&2
}

# End of Printing Functions
#####################################
# Arguments

while getopts "hvx:n:u:p:U:P:" o;do
	case "${o}" in
		(h) usage && exit      ;;
		(v) DEBUG="true"       ;;
		(x) DIRECTORY="$OPTARG";;
		(n) DBNAME="$OPTARG"   ;;
		(u) DBUSER="$OPTARG"   ;;
		(p) DBPASS="$OPTARG"   ;;
		(U) ADMINUSER="$OPTARG";;
		(P) ADMINPASS="$OPTARG";;
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
DBUSER="${DBUSER:-groot}"
DBPASS="${DBPASS:-toorg}"
ADMINUSER="${ADMINUSER:-groot}"
ADMINPASS="${ADMINPASS:-toorg}"

# End Of Variables
#####################################
# Requirements

	# Required Packages for LAMP Wordpress

# End of Requirements
#####################################
# Functions

install_packages() {
	PACKAGES=(
		'curl'               # To Retrieve Wordpress
		'unzip'              # To Unzip Wordpress
		'certbot'            # For Setting up TLS
		'apache2'            # Our Server
		'mariadb-server'     # Our Database
		'php'                # Our Language
		'libapache2-mod-php' # Teach Server our Language
		'ghostscript'        # Wordpress Dependency 
		'php-mysql'          # Wordpress Dependency
		'php-zip'            # Wordpress Dependency
		'php-xml'            # Wordpress Dependency
		'php-mbstring'       # Wordpress Dependency
		'php-json'           # Wordpress Dependency
		'php-intl'           # Wordpress Dependency
		'php-imagick'        # Wordpress Dependency
		'php-curl'           # Wordpress Dependency
		'php-bcmath'         # Wordpress Dependency
	)
	apt install -y ${PACKAGES[@]} 1>/dev/null 2>/dev/null &
	spinner $! "Installing Packages..."
	blocksay green "Packages Installed"
	# need a way to tell if install failed
}

check_services() {
	(
		echo "" >/dev/null
	) &
	spinner $! "Installing Wordpress..."
	blocksay green "Services Are Running"
}
check_firewall() {
	(
		echo "" >/dev/null
	) &
	spinner $! "Checking Firewall..."
	blocksay green "Firewall is Ok"
}
check_domain() {
	(
		echo "" >/dev/null
	) &
	spinner $! "Checking Domain..."
	blocksay green "Domain Is Working"
}
create_site_tree() {
	(
		echo "" >/dev/null
	) &
	spinner $! "Installing Wordpress..."
}
install_wordpress() {
	(
		echo "" >/dev/null
	) &
	spinner $! "Installing Wordpress..."
	blocksay green "Wordpress Installed"
}
install_vhost() {
	(
		echo "" >/dev/null
	) &
	spinner $! "Creating Vhost..."
	blocksay green "VHost Created"
}
install_cert() {
	(
		echo "" >/dev/null
	) &
	spinner $! "Installing Certificate With Certbot..."
	blocksay green "Certificate Installed"
}


# End of Functions
#####################################
# Execution

	# Display Fancy Banner
clear
echo >&2
banner >&2
echo >&2
echo "	$DESCRIPTION" >&2
hr >&2

	# Display Details
echo >&2
echo "	Domain:   $DOMAIN" >&2
echo "	Path:     $DIRECTORY/$DOMAIN" >&2
echo "	Admin:    $ADMINUSER" >&2
echo "	DB User:  $DBUSER" >&2
echo "	Database: $DBNAME" >&2
echo >&2
hr >&2
echo >&2

	# Do The Things
install_packages
create_site_tree
install_vhost
check_services
check_firewall
check_domain
install_cert
install_wordpress




# End of Execution
#####################################
sleep 1
