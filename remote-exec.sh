#!/bin/sh
###############################################################################
# Copyright (C) 2015  Chris A. Bunt (cbunt1@yahoo.com)
#   All rights reserved.
#   This program comes with ABSOLUTELY NO WARRANTY.
#   This is free software, and you are welcome to redistribute it.
#   See the file LICENSE for details.
###############################################################################
# remote-exec.sh --  BTRMS remote executable. Backs up a router's 
#   configuration for offline storage. Designed to be run remotely, but will 
#   run locally as well. This script is designed to run within the embedded
#   router environment only. Execute this script with a crontab entry or 
#   similar for an automated route  backup that automatically resolves all 
#   dependencies.
###############################################################################

# First things first: Are we on a router? If not, cowardly refuse to execute.
if [ $(uname -m) != "mips" ] ; then echo "Error: script must be run on a router!" &&
   exit 1
fi

# Initialize non-user variables -- probably shouldn't change these.
ScriptName="transfersettings.sh"
VerTag="v-1.2.1"  
HostName=`nvram get router_name`
DomainName=`nvram get wan_domain`

###  USER CONFIGURABLE VARIABLES - Edit these for your environment
RootDir=/jffs                       # Main working directory default
BinDir="$RootDir/BTRMS-$VerTag"     # Main Binary Directory
OutputRoot="$BinDir"                # Default. Can be changed at leisure.

# Do not edit below this line unless you want to change the actual program.

# Check for our core tools, and install if necessary.
if [[ ! -x "/opt/bin/opkg" ]] ; then
    # If no entware, start by clearing out optware, then install entware.
    for folder in bin etc include lib sbin share tmp usr var
    do
        rm -Rf "/opt/$folder"
    done
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
