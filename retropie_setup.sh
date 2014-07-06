#!/usr/bin/env bash

#  RetroPx86-Setup - Shell script for initializing Raspberry Pi 
#  with RetroArch, various cores, and EmulationStation (a graphical 
#  front end).
# 
#  (c) Copyright 2012-2014  Florian Müller (contact@petrockblock.com)
# 
#  RetroPx86-Setup homepage: https://github.com/Dervol03/RetroPx86-Setup
# 
#  Permission to use, copy, modify and distribute RetroPx86-Setup in both binary and
#  source form, for non-commercial purposes, is hereby granted without fee,
#  providing that this license information and copyright notice appear with
#  all copies and any derived work.
# 
#  This software is provided 'as-is', without any express or implied
#  warranty. In no event shall the authors be held liable for any damages
#  arising from the use of this software.
# 
#  RetroPx86-Setup is freeware for PERSONAL USE only. Commercial users should
#  seek permission of the copyright holders first. Commercial use includes
#  charging money for RetroPx86-Setup or software derived from RetroPx86-Setup.
# 
#  The copyright holders request that bug fixes and improvements to the code
#  should be forwarded to them so everyone can benefit from the modifications
#  in future versions.
# 
#  Many, many thanks go to all people that provide the individual packages!!!
# 
#  Raspberry Pi is a trademark of the Raspberry Pi Foundation.
# 

function getScriptAbsoluteDir() {
    # @description used to get the script path
    # @param $1 the script $0 parameter
    local script_invoke_path="$1"
    local cwd=`pwd`

    # absolute path ? if so, the first character is a /
    if test "x${script_invoke_path:0:1}" = 'x/'
    then
        RESULT=`dirname "$script_invoke_path"`
    else
        RESULT=`dirname "$cwd/$script_invoke_path"`
    fi
}

function import() { 
    # @description importer routine to get external functionality.
    # @description the first location searched is the script directory.
    # @description if not found, search the module in the paths contained in $SHELL_LIBRARY_PATH environment variable
    # @param $1 the .shinc file to import, without .shinc extension
    module=$1

    if test "x$module" == "x"
    then
        echo "$script_name : Unable to import unspecified module. Dying."
        exit 1
    fi

    if test "x${script_absolute_dir:-notset}" == "xnotset"
    then
        echo "$script_name : Undefined script absolute dir. Did you remove getScriptAbsoluteDir? Dying."
        exit 1
    fi

    if test "x$script_absolute_dir" == "x"
    then
        echo "$script_name : empty script path. Dying."
        exit 1
    fi

    if test -e "$script_absolute_dir/$module.shinc"
    then
        # import from script directory
        . "$script_absolute_dir/$module.shinc"
        # echo "Loaded module $script_absolute_dir/$module.shinc"
        return
    elif test "x${SHELL_LIBRARY_PATH:-notset}" != "xnotset"
    then
        # import from the shell script library path
        # save the separator and use the ':' instead
        local saved_IFS="$IFS"
        IFS=':'
        for path in $SHELL_LIBRARY_PATH
        do
            if test -e "$path/$module.shinc"
            then
                . "$path/$module.shinc"
                return
            fi
        done
        # restore the standard separator
        IFS="$saved_IFS"
    fi
    echo "$script_name : Unable to find module $module."
    exit 1
}

function initImport() {
	script_invoke_path="$0"
	script_name=`basename "$0"`
	getScriptAbsoluteDir "$script_invoke_path"
	script_absolute_dir=$RESULT	
}

function rps_checkNeededPackages() {
    # Some packages existing by default in Ubuntu repos need to be loaded from jessie under Debian
    if [[ $(grep -ie "debian" /proc/version | wc -l) -ne 0 ]]; then
        echo "You are running Debian, checking for jessie repo in sources..."
        if [[ $(grep -ie "jessie" /etc/apt/sources.list | wc -l) -eq 0 ]]; then
          echo "installing jessie repo to sources..."
          echo "deb http://ftp.de.debian.org/debian jessie main" >> /etc/apt/sources.list
          apt-get update
          echo "Installation if jessie completed."
        else
          echo "jessie is already installed, no changes made."
        fi
    fi

    if [[ -z $(type -P git) || -z $(type -P dialog) || -z $(type -P g++) ]]; then
        echo "Did not find needed packages 'git' and/or 'dialog', 'g++'. I am trying to install these now."
        apt-get update
        apt-get install -y git dialog g++
        if [ $? == '0' ]; then
            echo "Successfully installed 'git' and/or 'dialog'."
        else
            echo "Could not install 'git' and/or 'dialog'. Aborting now."
            exit 1
        fi
    else
        echo "Found needed packages 'git' and 'dialog'."
    fi 
}

function rps_availFreeDiskSpace() {
    local __required=$1
    local __avail=`df -P $rootdir | tail -n1 | awk '{print $4}'`

    required_MB=`expr $__required / 1024`
    available_MB=`expr $__avail / 1024`

    if [[ "$__required" -le "$__avail" ]] || ask "Minimum recommended disk space ($required_MB MB) not available. Try 'sudo raspi-config' to resize partition to full size. Only $available_MB MB available at $rootdir continue anyway?"; then
        return 0;
    else
        exit 0;
    fi
}

function checkForLogDirectory() {
	# make sure that RetroPx86-Setup log directory exists
	if [[ ! -d $scriptdir/logs ]]; then
	    mkdir -p "$scriptdir/logs"
	    chown $user "$scriptdir/logs"
	    chgrp $user "$scriptdir/logs"
	    if [[ ! -d $scriptdir/logs ]]; then
	      echo "Couldn't make directory $scriptdir/logs"
	      exit 1
	    fi
	fi	
}

# =============================================================
#  START OF THE MAIN SCRIPT
# =============================================================

user=$SUDO_USER
if [ -z "$user" ]
then
    user=$(whoami)
fi
home=$(eval echo ~$user)

rootdir=/opt/retropie
homedir="$home/RetroPx86"
romdir="$homedir/roms"
if [[ ! -d $romdir ]]; then
	mkdir -p $romdir
fi

# check, if sudo is used
if [ $(id -u) -ne 0 ]; then
    printf "Script must be run as root. Try 'sudo ./retropackages'\n"
    exit 1
fi   

export ARCHITECTURE="x86"
[[ $(grep "amd64" /proc/version | wc -l) -ew 1 ]] && export ARCHITECTURE="amd64"

scriptdir=`dirname $0`
scriptdir=`cd $scriptdir && pwd`

# load script modules
initImport
import "scriptmodules/helpers"
import "scriptmodules/retropiesetup"

checkForLogDirectory

rps_checkNeededPackages

# make sure that enough space is available
if [[ ! -d $rootdir ]]; then
	mkdir -p $rootdir
fi
rps_availFreeDiskSpace 800000

while true; do
    cmd=(dialog --backtitle "PetRockBlock.com - RetroPx86 Setup. Installation folder: $rootdir for user $user" --menu "Choose installation either based on binaries or on sources." 22 76 16)
    options=(1 "Source-based INSTALLATION (16-20 hours (!), but up-to-date versions)"
             2 "SETUP (only if you already have run one of the installations above)"
             3 "UPDATE RetroPx86 Setup script"
             4 "UPDATE RetroPx86 Binaries"
             5 "Perform REBOOT" )
    choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)    
    if [ "$choices" != "" ]; then
        case $choices in
            1) rps_main_options ;;
            2) rps_main_setup ;;
            3) rps_main_updatescript ;;
            4) rps_downloadBinaries ;;
            5) rps_main_reboot ;;
        esac
    else
        break
    fi
done

# make sure that the user has access to all files in the home folder
chown -R $user:$user $homedir


