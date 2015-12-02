#!/bin/sh
# BTRMS remote-exec.sh
# Copyright (C) 2015  Chris A. Bunt
# All rights reserved.
# This program comes with ABSOLUTELY NO WARRANTY.
# This is free software, and you are welcome to redistribute it.
# See the file LICENSE for details.

# BTRMS remote executable. Backs up a router's configuration for offline
#   storage. Designed to be run remotely, but will run locally as well.
#   Execute this script with a crontab entry or similar for an automated
#   backup that self-resolves all dependencies.

# This script will remove optware, install entware, add diffutils, wget, and
#   he BTRMS main tool if they don't already exist.

# For directories, use no trailing slashes.

###  USER CONFIGURABLE VARIABLES  ###
VerTag="v-1.2.1"                    # Version of the BTRMS tool used
RootDir=/jffs                       # Main working directory default
BinDir="$RootDir/BTRMS-$VerTag"     # Main Binary Directory
OutputRoot="$BinDir"                # Default. Can be changed at leisure.
ScriptName="transfersettings.sh"    # Executable script name
#####################################

# System-generated/operating variables
HostName=`nvram get router_name`
DomainName=`nvram get wan_domain`

# Do we have our core tools? Verify and install if necessary.
if [[ ! -x "/opt/bin/opkg" ]] ; then
	# If no entware, start by clearing out optware, then install entware.
	for folder in bin etc include lib sbin share tmp usr var
	do rm -Rf "/opt/$folder"
	done
	# /usr/sbin/entware-install.sh        # Included in Shibby builds.
	# Go ahead and update to entware-ng until upgrade is built-into firmware.
	# Should add a firmware version check to reduce a step.
	# wget -O - http://entware.zyxmon.org/binaries/mipsel/installer/upgrade.sh | sh
	# Can I just use the below line as a single-step entware installation?
	wget -O - http://entware.zyxmon.org/binaries/mipsel/installer/installer.sh | sh
fi
# Verify presence of a fully functional wget, if not, install it.
if [[ ! -x "/opt/bin/wget" ]] ; then
	opkg install wget
fi
# Verify presence of diff, if not, install it.
if [[ ! -x "/opt/bin/diff" ]] ; then
	opkg install diffutils
fi
# Verify the chosen $RootDir is writable, if not, use /tmp
if [[ ! -w "$RootDir" ]] ; then
	RootDir="/tmp"
fi
# Test whether we have the BTRMS software, if not, install it.
if [[ ! -x "$BinDir/$ScriptName" ]] ; then
	/opt/bin/wget --no-check-certificate https://github.com/cbunt1/BTRMS/archive/"$VerTag".tar.gz -O /tmp/BTRMS-"$VerTag".tar.gz
	tar -C "$RootDir" -xzf /tmp/BTRMS-"$VerTag".tar.gz
	rm "/tmp/BTRMS-$VerTag.tar.gz"
	chmod +x "$BinDir/$ScriptName"
fi
# Verify the chosen $OutputRoot is writable, if not use /tmp
if [[ ! -w "$OutputRoot" ]] ; then
	OutputRoot="/tmp"
fi
# Now let's do what we came here to do.
cd $OutputRoot
${BinDir}/${ScriptName} export > /dev/null        # Quiet the core script output
# Make a note in the system log that the backup was successful.
logger "NVRAM Configuration backed up to $OutputRoot/$HostName"
# Feed the scp-formatted filename back to the host.
echo "$HostName.$DomainName:$OutputRoot/$HostName"
exit
