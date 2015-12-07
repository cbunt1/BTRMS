#!/bin/sh
###############################################################################
# Copyright (c) 2015  Chris A. Bunt (cbunt1@yahoo.com)
#   All rights reserved.
#   This program comes with ABSOLUTELY NO WARRANTY.
#   This is free software, and you are welcome to redistribute it.
#   See the file LICENSE for details.
###############################################################################
###############################################################################
# USER VARIABLES:
#   WorkDir     -- The preferred working directory [DEFAULT: /tmp/~hostname~]
#   TmpDir      -- Used to define the various files used within the script
#   OutputFile  -- The name of the final configuration script
#   ModFileDest -- RouterSwap Completed/merged script file
#   OutputFile  -- Final output file (export) (.sh)
###############################################################################
clear
ScriptVersion="1.3.0-alpha"
echo "Buntster's Tomato Router Maintenance System, v$ScriptVersion"
echo -e "Copyright (C) 2015  Chris A. Bunt" \n
echo "This program comes with ABSOLUTELY NO WARRANTY."
echo "This is free software, and you are welcome to redistribute it."
echo -e "See the file LICENSE for details." \n
echo "Initializing router maintenance script."
echo -n "Setting global variables..."
if [[ -x /bin/nvram ]]  # /bin/nvram only exists on router environments
then
    # If invoking from within a router
    RouterName=`nvram get router_name`
    OSVer=`nvram get os_version | cut -d ' ' -f2`
    echo ".operating within a router."
else
    #if not invoking from within a router, setup external environment
    RouterName=`uname -n`
    OSVer=`uname -i`
    echo ".running outside a router."
    ExtEnv=1
    # Put the rest of the non-router confirmations here and save a lot of hassle
    
##### New Code Begins Here ##                      # DEBUG
    # Validate that we're calling a valid non-router mode
    ValidMode="modify"
    echo "Debug: Parsing module names" # DEBUG
    echo "Debug: \$1=$1" # DEBUG
    if [[ ! -n $1 ]] ; then echo "Debug: Nul value is OK" ; else
        for ModName in $ValidMode ; do
            echo "Debug: ModName=$ModName"  # DEBUG
            if [ "$1" = "$ModName" ] ; then GoodMode=1 ; fi
        done
        if [[ ! -n $GoodMode ]] ; then echo "Fatal error: mode \"$1\" not valid in this environment."
            exit 1 ; fi
        echo "Debug: Passed mode test" #DEBUG
        # Validate that we have a valid filename to work from.
        if [[ ! -n $2 ]] ; then echo "Fatal error: mode \"$1\" requires filename outside router."
            exit 1 ; fi 
        # And that we can actually read it.
        if [[ ! -r "$2" ]] ; then echo "Fatal error: Cannot read \"$2\". Check filename and permissions."
            exit 1 ; fi
    fi
    # exit    # DEBUG
    #
    #
##### New Code Ends Here ##                        # DEBUG
    
fi
# Remainder of variables work in either environment.
echo -n "Testing to see if we can write to `pwd`.."
if [[ -w "./" ]]
then
    echo ".yes!"
    if [[ -n "$ExtEnv" ]] ; then WorkDir=`pwd` ; else
    WorkDir="./$RouterName"
    fi
else
    echo ".no, using /tmp"
    WorkDir="/tmp/$RouterName"
fi
# USER AND GLOBAL VARIABLES
TmpDir="$WorkDir/temp/"
RunDate=`date '+%F-%H%M'`
OutputFile="$WorkDir"/"$RunDate"_"$RouterName"_"$OSVer.sh"
CmdLnOpt="$1"
ModFileSource="$2"
ModFileDest="$WorkDir"/"$RunDate"_"$RouterName"_"$OSVer-mod.sh"
echo -e "
==============================================================================
                Buntster's Tomato Router Maintenance Tools
==============================================================================
\e[0;33mTomato router maintenance tool run on   : \e[0;32m$RunDate\e[0m
\e[0;33mRouter name is                          : \e[0;32m$RouterName\e[0m
\e[0;33mCurrent software version is             : \e[0;32m$OSVer\e[0m
\e[0;33mCreating working directory              : \e[0;32m$WorkDir\e[0m
==============================================================================
\e[0m "

CreateWorkDir()
{
###############################################################################
# CreateWorkDir -- Quietly create temp working directory, provide framework
#   for sanity checking or debugging should we need it later.
###############################################################################

if [[ -d "$TmpDir" ]] ; then
    rm -Rf "$TmpDir" ; fi  # Clobber any existing directory
echo -n "Creating working directory..."
mkdir  -p "$TmpDir"
echo ".done!"
}

CleanTmpFiles()
{
###############################################################################
# Clean up after ourselves. Delete the temp directory, and if for some reason
#   we didn't write to $WorkDir, delete it. If we have working 'diff', Verify
#   we aren't creating a duplicate export or modify script. 
###############################################################################

echo -e -n  "Removing temporary directory..."
rm -Rf "$TmpDir"
echo ".done!" 
if [ ! "$(ls -A $WorkDir)" ]
then
    rmdir "$WorkDir"
fi

# If we have 'diff' on board, let's go ahead and prevent duplicates.
if which diff &> /dev/null
then
    DupSrcFileFlag=0
    DupModFileFlag=0
    echo -n "Checking for duplicate scripts.."
    for FileName in `ls -1 "$WorkDir"`
    do
        TestFile=$WorkDir/${FileName}
        if [ -f "$OutputFile" ]
        then
            if ( diff -q -I 'DIFFIGNORE' ${TestFile} "$OutputFile" &> /dev/null ) && 
				[[ ${TestFile} != "$OutputFile" ]]
            then
                DupSrcFileFlag=$((DupSrcFileFlag+1))
                DupSourceFile=${TestFile}
                rm ${OutputFile}
                OutputFile=${DupSourceFile}
            fi
        fi
        if [ -f "$ModFileDest" ]
        then
            if ( diff -q -I 'DIFFIGNORE' ${TestFile} "$ModFileDest" &> /dev/null ) && 
				[[ ${TestFile##*/} != "$ModFileDest" ]] && 
                [[ ${TestFile} != "$ModFileDest"  ]]
            then
                DupModFileFlag=$((DupModFileFlag+1))
                DupModFile=${TestFile}
                rm ${ModFileDest}
                ModFileDest=${DupModFile}
            fi
        fi
        echo -n "."
    done
    echo ".done!"
    if [ $DupSrcFileFlag -gt 0 ]
    then
        echo "Keeping existing export file."
    fi
    if [ $DupModFileFlag -gt 0 ]
    then
        echo "Keeping existing modified file."
    fi
else
    echo "Can not check for duplicate scripts."
fi
return 0
}

NVRAMExportRaw()
{
###############################################################################
# Export NVRAM contents to a working file. If not running within a router then
#   gracefully exit. 
#   environment, copy the contents of a "nvramexportset" from current directory
# OUTPUTS: nvram dump in $TmpDir/TempFile-01
###############################################################################

echo -n "Exporting NVRAM to file.."
if [[ -n "$ExtEnv" ]]
then
    echo "Cannot export nvram outside a router environment. Cowardly exiting!" &&
    exit 1
else
    nvram export --set > "$TmpDir/TempFile-01"
fi
echo ".done!"
return 0
}

ParameterExport()
{
###############################################################################
# ParameterExport
#
# Prioritize particular primary parameters prior to producing (let's see how
#   many "P's" we can get in here) the final router script. Currently pulls out
#   the network parameters and sorts them to the top of the output stream,
#   removes the troublesome parameters and exports the final list of parameters
#
# INPUTS:       $TmpDir/Tempfile-01 -- Raw nvram export file
#
# OUTPUTS:      $TmpDir/TempFile-04 -- Final list of nvram network parameters
#               $TmpDir/TempFile-05 -- Final list of remaining nvram parameters
#
# VARIABLES:    "TROUBLE_PARAMS"  -- Specifically identified trouble parameters
#               "PRIORITY_PARAMS" -- to identify and adjust parameter order
#               "DISCARD_PARAMS"  -- Hardware-specific parameters to remove
###############################################################################
PRIORITY_PARAMS="
wan_
lan_
lan1_
lan2_
lan3_
dns_
dhcp_
dhcpd_
dhcp1_
dhcpd1_
dhcp2_
dhcpd2_
dhcp3_
dhcpd3_
ddns_
router_name
wl_
wl0_
wl0.1_
wl0.2_
wl0.3_
wl1_
wl1.1_
wl1.2_
wl1.3_
ntp_
"

NETWORK_PARAMS="
hwaddr
macaddr
mac_wan
sshd_hostkey
secret_code
http_id
sshd_dsskey
tomatoanon_id
t_model_name
os_version
wan_lease
wan_gateway
wan_hwname
wan_get_dns
wan_gateway_get
wan_ipaddr
wan_netmask
"

TROUBLE_PARAMS="
iptables
"

# Remove hardware specific and other problem parameters
DISCARD_PARAMS="$NETWORK_PARAMS $TROUBLE_PARAMS"
echo -n "Creating a list of problematic parameters to remove.."
for PARAMETER in $DISCARD_PARAMS    
do
    echo "$PARAMETER" >> "$TmpDir/TempFile-02"
    echo -n "."
done
echo ".done!"
echo -n "Removing problematic parameters.."
fgrep -v -f "$TmpDir/TempFile-02" "$TmpDir/TempFile-01" >> "$TmpDir/TempFile-03"
echo ".done!"

# Sort out the network specific entries
echo -n "Parsing to separate network specifics..."
for PARAMETER in $PRIORITY_PARAMS
do
    fgrep "$PARAMETER" "$TmpDir/TempFile-03" >> "$TmpDir/TempFile-04"
    echo -n "."
done
echo ".done!"

# Drop Duplicate Parameters
echo -n "Removing duplicate parameters.."
fgrep -v -f "$TmpDir/TempFile-04" "$TmpDir/TempFile-03" >> "$TmpDir/TempFile-05"
echo -n "."
echo ".done!"
return 0
}

ParameterMod()
{
###############################################################################
# ParameterMod
# Present the user with a series of parameter/value pairs and allow the user to
#   modify them. The function verifies whether any changes were made and if so
#   will merge the changes back into the original file to create a final script
#
# INPUTS: $ModFileSource, router configuration script passed to the function. 
#
# USER VARIABLES: CHANGE_PARAMS - An array-style variable containing the 
#   parameters that may be manipulated within the script
#
# OUTPUTS: $ModFileDest: The updated router configuration script created here.
###############################################################################

# First, check that we can read the source file
if [[ ! -r "$ModFileSource" ]]
then
    echo "Cannot read $ModFileSource, check your file name and permissions."
    echo "Cannot continue."
    CleanTmpFiles
    exit
fi
# Then make any necessary changes for a non-router environment
######## Begin New Code ######
if [[ -n "$ExtEnv" ]] ; then
    # Parse the $ModFileSource for parameters in the head and use them as vars.
    for NewCommnd in "`fgrep '##DIFFIGNORE##' "$ModFileSource"`" ; do
        eval "$NewCommnd"  # WORKS! -- There's a better way, but this works.
    done
    OSVer=`echo "$OrigVersion" | cut -d ' ' -f2`
    ModFileDest="$RunDate"_"$OrigRouterName"_"$OSVer"-mod.sh
fi

######### Original code below this line ##################


CHANGE_PARAMS="
router_name
lan_hostname
lan_domain
lan_ipaddr
lan_netmask
wan_hostname
wan_domain
wan_wins
lan1_ipadddr
lan1_netmask
lan2_ipaddr
lan2_netmask
lan3_ipaddr
lan3_netmask
dhcpd_startip
dhcpd_endip
dhcpd1_startip
dhcpd1_endip
dhcpd2_startip
dhcpd2_endip
dhcpd3_startip
dhcpd3_endip
wl0_ssid
wl1_ssid
wl10.1_ssid
wl_ssid
wl0_wpa_psk
wl1_wpa_psk
wl0.1_wpa_psk
wl1.1_wpa_psk
wl_wpa_psk
"

echo -n "Parsing to separate updatable parameters..."
for PARAMETER in $CHANGE_PARAMS
do
    fgrep "$PARAMETER" "$ModFileSource" | sed -e 's/nvram set //g' >> "$TmpDir/TempFile-11"
    echo -n "."
done
fgrep -v echo "$TmpDir/TempFile-11" >> "$TmpDir/TempFile-12"
echo ".done!"

# Interactively update the identified parameters
echo "
==============================================================================
This is your opportunity to change the parameters in your router script

CAUTION: No sanity checking is implemented, if you enter an improper value it
will be written directly to the script. Watch for netmasks, IP address ranges, 
and DHCP range conflicts on your own.

Enter desired parameters at the prompt. or press [RETURN] to accept
the default (existing) settings. Do NOT quote parameters -- they are entered 
automatically by the script. Enter 'nul' to clear an existing value.
==============================================================================
"
for LINE in `cat $TmpDir/TempFile-12`
do
    VARIABLE=`echo "$LINE" | cut -d '=' -f1`
    VALUE_OLD=`echo "$LINE" | cut -d '=' -f2`
    echo -e -n "\e[1;32m$VARIABLE\e[0m"="[\e[1;34m$VALUE_OLD\e[0m]: "
    read VALUE_NEW
    if [[ "$VALUE_NEW" = "nul" ]]
    then
        echo "s|$VARIABLE"="$VALUE_OLD|$VARIABLE"="\"\"|" >> $TmpDir/TempFile-13
    elif [[ ! -n "$VALUE_NEW" ]]
    then  
        VALUE_NEW="$VALUE_OLD"
    else
        VALUE_NEW=\""$VALUE_NEW\""
        echo "s|$VARIABLE"="$VALUE_OLD|$VARIABLE"="$VALUE_NEW|" >> $TmpDir/TempFile-13
    fi    
done 

# Now merge it back into the original script file
echo -n "Merging changes into a final script.."
if [[ -e "$TmpDir/TempFile-13" ]]
then
    sed -f "$TmpDir/TempFile-13" <"$ModFileSource" > "$ModFileDest"
    echo ".done!"
else
    echo ".done, no parameters changed!"
fi
return 0
}

GenerateConfigScript()
{
###############################################################################
# GenerateConfigScript
# Merge the parts of now split configuration into a single configuration script
#   that can be run on another router. This is where it all comes together. 
#   n: The generated script is designed to wipe out your existing config.
#
# INPUTS:   $TmpDir/TempFile-04 -- Network parameters only, with 'nvram set'
#           $TmpDir/TempFile-05 -- All other parameter w/'nvram set' stmt.
#
# OUTPUTS:  $OutputFile -- the final script completed, updated, and merged.
#
# VARIABLE: $OutputFile: Filename for the output file
###############################################################################

echo \
"#!/bin/sh
###############################################################################
#
# Auto-Generated script file to load the configuration of an Asus RT-66-AU
#   router from one router to another. Using this script will erase any and
#   all existing configurations on your router. USE WITH CARE!!
#
###############################################################################
" > "$OutputFile"
if [[ -n "$ExtEnv" ]]
then
    echo "OrigVersion=\"$OrigVersion\"    ###DIFFIGNORE###" >> "$OutputFile"
else
    echo "OrigVersion=\"`nvram get os_version`\"    ###DIFFIGNORE###" >> "$OutputFile"
fi
# Put variable outputs here, so we don't have to contend with quoting issues
# Put a ###DIFFIGNORE### statement on any line you want to ignore when parsing
# for duplicate files. If you do not have a working diff it will not matter.
echo "OrigRunDate=\"$RunDate\"  ###DIFFIGNORE###" >> "$OutputFile"
echo "OrigScriptVersion=\"$ScriptVersion" >> "$OutputFile"
echo "OrigRouterName=\"$RouterName\"    ###DIFFIGNORE###" >> "$OutputFile"
echo \ '
WriteToNvram()
{
###############################################################################
# Module to commit nvram and pause for 15 seconds on each side. The wait time #
#   may or may not be a superstition, but it doesnt seem to hurt anything.    #
#   No harm, no foul, watch the cool dotted output.                           #
###############################################################################

echo -n "Save to NVRAM phase 1/2, this takes a few seconds..."
ElapsedLoops=0
while [ $ElapsedLoops -lt 15 ]
do
    echo -n "."
    sleep 1s
    ElapsedLoops=$((ElapsedLoops+1))
    done
echo ".done!"
nvram commit
echo -n "Save to NVRAM phase 2/2, this takes a few seconds..."
ElapsedLoops=0
while [ $ElapsedLoops -lt 15 ]
do
    echo -n "."
    sleep 1s
    ElapsedLoops=$((ElapsedLoops+1))
    done
echo ".done!"
}
' >> "$OutputFile"
echo \ '
CURRENTVERSION="`nvram get os_version`"
if [[ "$ORIGVERSION" != "$CURRENTVERSION" ]]
then
    echo \
"
        **************************************************************
        *                                                            *
        *   <--===-->  SCRIPT FIRMWARE VERSION MISMATCH  <--===-->   *
        *                                                            *
        **************************************************************

This router is not running the same version of the firmware
as the script contained within. This script was generated for
a different version.

ORIGINAL FIRMWARE: $ORIGVERSION
CURRENT FIRMWARE : $CURRENTVERSION

This may present problems. These versions do not match. Proceed with care!
"
    echo -n "YOU MUST ACKNOWLEDGE VERSION DIFFERENCE TO CONTINUE (y/N): "
    read i
    if [[ "$i" != "y" && "$i" != "Y" ]]
    then
        echo "Aborted by user!"
    exit 0
    fi
fi
clear
echo -e "
==============================================================================
                  Buntsters Tomato Router Manipulation Tools
==============================================================================
\e[0;33mOriginal Script Date (yyyy-mm-dd-hhmm)      : \e[0;32m$OrigRunDate\e[0m
\e[0;33mOriginal Router Name                        : \e[0;32m$OrigRouterName\e[0m
\e[0;33mGenerated by manipulation script version    : \e[0;32m$OrigScriptVersion\e[0m
==============================================================================
\e[0m

This script is designed to place a configuration on your soon-to-be blanked 
router. This is a data-destructive process. You have been warned.

The process takes up 5-10 minutes. Do not give up, do not reset the router
unless 10 minutes have passed and you are not seeing results.

This script will erase any and all contents of the NVRAM on this router and
replace it with the configuration in this script. THIS CANNOT BE UNDONE!!
"
echo -n "Are you sure you want to continue? (y/N): "
read i
if [[ "$i" != "y" && "$i" != "Y" ]]
then
    echo "Aborted by user!"
    exit 0
fi
echo "Doing the deed!"
echo -n "Clearing NVRAM to erase any existing or conflicting parameters..."
mtd-erase -d nvram > /dev/null
nvram erase
WriteToNvram
' >> "$OutputFile"
cat "$TmpDir/TempFile-04" >> "$OutputFile"
echo \
'
echo "Committing network parameters to NVRAM..."
WriteToNvram
echo "Network parameters commited to NVRAM!"
echo "Now entering remaining parameters..."
' >> "$OutputFile"
cat "$TmpDir/TempFile-05" >> "$OutputFile"
echo \
'
echo "All parameters entered!"
echo "Committing parameters to NVRAM..."
WriteToNvram
echo "Parameters committed to NVRAM!"
echo "Configuration loaded and committed to NVRAM."
echo "Rebooting the router to start under new configuration"
echo
echo "You may want to release and renew your IP address or otherwise refresh"
echo "your network connections. Your subnet has likely changed."
echo "after reboot the router hostname will be: "`nvram get router_name`
echo "and the IP address will be: " `nvram get lan_ipaddr`
echo
reboot > /dev/null
echo -n "Rebooting..."
while true
do
    echo -n "."
    sleep 1s
done
echo ".done!" # should never get this far!
' >> "$OutputFile"
return 0
}

output()
{
##############################################################################
# Communicate final information to the user, identifying the locations of the
#   files modified, stored, and output.
##############################################################################
echo \
"
Buntster's Tomato Router Maintenance System has created an executable shell
script that can be used to copy a configuration to a hardware-identical router.
"
if [[ -r "$OutputFile" ]] ; then
echo \
"The NVRAM configuration of $RouterName has been backed up.
The exported configuration script is stored at:
$OutputFile
"
elif [[ -r "$ModFileSource" ]] ; then
echo \
"The original configuration file has not been changed. It is stored at:
$ModFileSource
" ; fi

if [[ -r "$ModFileDest" ]] ; then
echo \
"Your updates have been merged into the updated configuration script stored at:
$ModFileDest
" ; fi
echo \
"Simply copy the script(s) to the target router, make it executable, and run.
NOTE: The generated script(s) are designed to wipe your configuration as a
first step. THIS IS A DESTRUCTIVE RESTORATION METHOD.
"
return 0
}

case $CmdLnOpt in
export)
###############################################################################
# Configuration Export Routine
###############################################################################

CreateWorkDir         # Create a working directory
NVRAMExportRaw        # Exports the contents of the running NVRAM to a file
ParameterExport       # Prioritize network parameters to re-order the load
GenerateConfigScript  # Builds the final configuration script
CleanTmpFiles         # Deletes temp/working directories as appropriate
output                # Communicate with the user
;;

modify)

###############################################################################
# Router Swap Script Routine
###############################################################################

CreateWorkDir                   # Create a working directory
if [[ -z "$ModFileSource" ]]
then
    echo "ModFileSource not passed at command line, means we need to create"
    NVRAMExportRaw              # Exports the contents of the running NVRAM
    ParameterExport             # Re-order the parameters loaded
    GenerateConfigScript        # Builds the configuration script
    ModFileSource="$OutputFile" # Modify the file we just created
fi
ParameterMod                    # Change parameters and merge script
CleanTmpFiles                   # Cleans up temporary directories
output                          # Communicate with the user
;;

*)
echo "
USAGE: $0 [export|modify] [filename]

OPTIONS

export      Exports nvram configuration into a portable restoration script for
            backup, or settings transfer to a hardware-identical router.
 
modify      In interactive mode (default) creates a portable restoration just
            like export mode, then allows direct modifications to several key
            parameters as direct entry. Passing a [filename] performs modifies
            the specified pre-existing file.

[filename]  Optional: existing filename to modify.

Copyright (c) 2015 Chris A. Bunt (cbunt1@yahoo.com)
This program comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it.
See the file LICENSE for details.
"
;;
esac
