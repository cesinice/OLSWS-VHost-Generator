#!/bin/bash
#=============================================================================#
# Title 			 : File Convert OLSWS                                           #
# Description  : This script analyses a text file and convert to VirtualHost  #
#								 for OpenLitespeed Web Server                                 #
# Author 			 : Tony Briet                                                   #
#	Date 				 : 7 December 2016                                              #
# Version      : 0.1.0                                                        #
#	Usage				 : bash file-convert.sh or ./file-convert.sh                    #
# Notes        : Install OLSWS, make sure to have sufficient permissions and  #
#								 tput installed in your system                                #
# Bash Version : 4.3.30(1)-release                                            #
#=============================================================================#



## Foreground Color Variables
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
blue=`tput setaf 4`
white=`tput setaf 7`

## Background Color Variables
bred=`tput setab 1`
bgreen=`tput setab 2`
byellow=`tput setab 3`
bblue=`tput setab 4`
bwhite=`tput setab 7`
resetcolor=`tput sgr0`

## Server and config files configurations
SERVER_PATH="/usr/local/lsws"
CONF_VHOST="$SERVER_PATH/conf/vhosts"
WEBSITE_DIR="$SERVER_PATH/websites"
CONF_SERVER="$SERVER_PATH/conf/httpd_config.conf"
ARCHIVE_DIR="/websites_archives"

## Skeletton Files Configration
CURRENT_DIR="$(dirname $0)"
SQUEL_FILE="$CURRENT_DIR/httpd_config.conf.squel"
VH_SQUEL_FILE="$CURRENT_DIR/virtualhost.squel"
VH_HTTP_SQUEL_FILE="$CURRENT_DIR/vhost_httpd.squel"

## Line count for the file analysis
COUNT=1;

## Reset the Server Configuration file with the skeletton
cp -f $SQUEL_FILE $CONF_SERVER

## Checking if there is less or more than one arguments
if [ $# != 1 ]
then
	echo "${bred}${white}Usage : ./file-convert.sh name ${resetcolor}"
	exit 2;
else
	rm -rf /usr/local/lsws/websites/*
	rm -rf /usr/local/lsws/conf/vhosts/*
fi

## Checking if website directory exists, if not, creating it
if [ ! -d "$WEBSITE_DIR" ]
then
	echo "${bwhite}${blue}${bwhite}Initial Directory Installation ${resetcolor}"
	mkdir "$WEBSITE_DIR"
	## Fail-Safe check before changing the permissions
	if [ -d "$WEBSITE_DIR" ]
	then
		chmod -R 755 "$WEBSITE_DIR"
		chown -R lsadm:lsadm "$WEBSITE_DIR"
		echo "${white}${bgreen}Website Directory Created Successfully ${resetcolor}"
	else
		echo "${white}${bred}Could not create Website Directory, please check your permissions"
		exit 1;
	fi
fi

## Instanciating Internal & VPN Domain List
LIST_DOMAIN_INTERNAL=""
LIST_DOMAIN_VPN=""

## Reading file line-by-line and checking if matching the Regex
while IFS='' read -r line || [[ -n "$line" ]]; do
	## Checking if line match to FQDN and boolean Regex using Grep
	if grep -qoP '((?:[a-z][a-z\.\d\-]+)\.(?:[a-z][a-z\-]+))(?![\w\.])(,| |, )(true|false)' <<< $line
	then
		## Catching the domain, the state boolean to identify VPN/Internal Domains
		DOMAIN=$(perl -lne 'print $1 if /((?:[a-z][a-z\.\d\-]+)\.(?:[a-z][a-z\-]+))(?![\w\.])/g' <<< $line)
	 	STATE=$(perl -lne 'print $1 if /(true|false)/g' <<< $line)
		## Generating the VirtualHost name based on the Hostname and the config variables
		VHOST_NAME=$(perl -lne 'print ucfirst($2) if /((?:[a-z][a-z]+)\.)((?:[a-z][a-z]+))(\.(?:[a-z][a-z]+))/g' <<< $line)
		VHOST_CONFIG_DIR="$CONF_VHOST/$VHOST_NAME"
		VHOST_CONFIG_FILE="$VHOST_CONFIG_DIR/vhconf.conf"
		VHOST_ROOT="$WEBSITE_DIR/$VHOST_NAME"
		VHOST_ZIP="$ARCHIVE_DIR/$VHOST_NAME.zip"
		VHOST_DOCUMENT_ROOT="$VHOST_ROOT/html"

		## Populating the differents domains lists
		LIST_DOMAIN_INTERNAL="$LIST_DOMAIN_INTERNAL $DOMAIN"

		## If state is true, the domain is written on the VPN Domain List
		if [ $STATE == true ]
		then
			LIST_DOMAIN_VPN="$LIST_DOMAIN_VPN $DOMAIN"
		fi

		## Checking if VirtualHost Configuration file already exists
	  if [[ ! -f $VHOST_CONFIG_FILE ]]
	  then
			## Initial VirtualHost Configuration
			echo "${bwhite}${blue}Init VHost for $DOMAIN ${resetcolor}"

			## VirtualHost Configuration Folder creation w/ permissions
			echo "${bwhite}${blue}Creating VHost folder at $VHOST_CONFIG_DIR ${resetcolor}"
			mkdir "$CONF_VHOST/$VHOST_NAME"

			## Fail-safe checking if the VHost Configuration Folder was created
			if [ ! -d "$CONF_VHOST/$VHOST_NAME" ]
			then
				echo "${white}${bred}Could not create the VHost Folder, please check your permissions ${resetcolor}"
				exit 3;
			else
				echo "${white}${bgreen}VHost Folder created successfully ! ${resetcolor}"
			fi

			## Adding new VirtualHost config file based on Skeletton
			echo "${bwhite}${blue}Creating new VHost Config File at $VHOST_CONFIG_FILE ${resetcolor}"
			touch $VHOST_CONFIG_FILE
			if ! sed -e "s#VHOST_ROOT#$VHOST_ROOT#g" -e "s#DOMAIN#$DOMAIN#g" $VH_SQUEL_FILE > $VHOST_CONFIG_FILE
			then
				echo "${white}${bred}There is an ERROR creating $VHOST_CONFIG_FILE file ${resetcolor}"
				exit 4;
			else
				echo "${white}${bgreen}VHost Configuration created with success !${resetcolor}"
			fi

			## Creating the VirtualHost Rool folder, if they don't exists
			echo "${bwhite}${blue}Creating new VHost Root folders at $VHOST_ROOT${resetcolor}"
			if [ ! -d $VHOST_ROOT ]
			then
				mkdir "$VHOST_ROOT"
				echo "${white}${bgreen}VHost Root Folder created successfully !${resetcolor}"
			else
				echo "${bwhite}${red}Folder already exists, skipping.. ${resetcolor}"
			fi

			## Appending VirtualHost Global Configuration through Skeletton
			echo "${bwhite}${blue}Adding VHost to global configuration${resetcolor}"
			if ! sed -e "s#VHOST_NAME#$VHOST_NAME#g" -e "s#VHOST_ROOT#$VHOST_ROOT#g" -e "s#VHOST_CONFIG_FILE#$VHOST_CONFIG_FILE#g" $VH_HTTP_SQUEL_FILE >> $CONF_SERVER
			then
				echo "${white}${bred}There is an ERROR adding VHost ${resetcolor}"
				exit 7;
			else
				echo "${white}${bgreen}VHost added with success !${resetcolor}"
			fi

			## Unzipping archive if it exists, or creating HTML document root
			echo "${bwhite}${blue}Creating document root for the VirtualHost${resetcolor}"
			if [ -f "$VHOST_ZIP" ]
			then
				echo "${bwhite}${blue}ZIP Archive found, extracting it to the document root ${resetcolor}"
				mkdir $VHOST_DOCUMENT_ROOT
				unzip $VHOST_ZIP -d $VHOST_DOCUMENT_ROOT
			else
				echo "${bblue}${white}ZIP Archive not found, skipping${resetcolor}"
				mkdir $VHOST_DOCUMENT_ROOT
			fi

			## Making the folders and files executable for the webserver group/user
			echo "${bwhite}${blue}Fixing files and folders permissions${resetcolor}"
			chmod -R 755 "$CONF_VHOST/$VHOST_NAME"
			chown -R lsadm:lsadm "$CONF_VHOST/$VHOST_NAME"
			chmod -R 755 "$VHOST_DOCUMENT_ROOT"
			chown -R lsadm:lsadm "$VHOST_DOCUMENT_ROOT"

	  fi
	else
		## No more analysis required
		echo "${bblue}${white}Line $COUNT is invalid, skipping..${resetcolor}"
	fi
	let "COUNT++"
done < "$1"

## Generating map for internal websites / domains
echo "${bwhite}${blue}Adding VHost to Internal Listeners to HTTP Configuration${resetcolor}"
printf "listener Internal {\naddress\t192.168.0.5:80\nbinding\t3\nsecure\t0\n" >> $CONF_SERVER
for dom in $LIST_DOMAIN_INTERNAL; do
	VHOST_NAME=$(perl -lne 'print ucfirst($2) if /((?:[a-z][a-z]+)\.)((?:[a-z][a-z]+))(\.(?:[a-z][a-z]+))/g' <<< $dom)
	echo "map $VHOST_NAME $dom" >> $CONF_SERVER
done
echo "}" >> $CONF_SERVER

echo "${white}${bgreen}VHost added to Internal Listeners successfully !${resetcolor}"

## Generating map for VPN websites / domains
echo "${bwhite}${blue}Adding VHost to VPN Listeners to HTTP Configuration${resetcolor}"
printf "listener VPN {\naddress\t192.168.0.35:80\nbinding\t3\nsecure\t0\n" >> $CONF_SERVER
for dom in $LIST_DOMAIN_VPN; do
	VHOST_NAME=$(perl -lne 'print ucfirst($2) if /((?:[a-z][a-z]+)\.)((?:[a-z][a-z]+))(\.(?:[a-z][a-z]+))/g' <<< $dom)
	echo "map $VHOST_NAME $dom" >> $CONF_SERVER
done
echo "}" >> $CONF_SERVER

## End of script
echo "${white}${bgreen}VHost added to VPN Listeners successfully !${resetcolor}"

service lsws restart
