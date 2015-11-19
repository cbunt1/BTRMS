#!/bin/sh
ScriptVersion="1.2.1"
##############################################################################
#
# GLOBALS -- These variables are used throughout the script. Edit them as
#   necessary to support your specific environment
#
# RouterName is the router's hostname as reported by NVRAM
# RunDate is the date and time the script is run
# OSVer is the OS version as reported by NVRAM
# WorkDir is the preferred working directory [DEFAULT: /tmp/~hostname~]
# TmpDir is used to define the various files used within the script
# OutputFile is the name of the final configuration script
# 
# TmpDir list (created by the script for processing. These are removed before
#   the script exits, assuming it exits cleanly. If it stops, they will be left
#   in the $WorkDir (usually /tmp/$RouterName).
#
# $TmpDir/TempFile-01	-NVRAM dump (RAW)
# $TmpDir/TempFile-02 -Hardware parameters removed from $TmpDir/TempFile-03
# $TmpDir/TempFile-03 -NVRAM file without hardware parameters 
# $TmpDir/TempFile-04 -Network parameters only (FINAL)
# $TmpDir/TempFile-05 -NVRAM file w/o HW or NW parameters (FINAL)
# $TmpDir/TempFile-11 -RouterSwap list of parameters to change
# $TmpDir/TempFile-12 -RouterSwap list of pre-change parameters and values
# $TmpDir/TempFile-13 -RouterSwap sed script
# $ModFileDest   	-RouterSwap Completed/merged script file
# OutputFile	        -	-Final output file (export) (.sh)
#
##############################################################################
clear
echo "Buntster's Tomato Router Manipulation Tools, version $ScriptVersion"
echo "Copyright (C) 2014, 2015  Chris A. Bunt"
echo "This program comes with ABSOLUTELY NO WARRANTY."
echo "This is free software, and you are welcome to redistribute it."
echo "See the file LICENSE for details."
echo "Initializing router manipulation script."
echo -n "Setting global variables..."
if [[ -x /bin/nvram ]]  # /bin/nvram only exists on router environments
then
    # If invoking from within a router
    RouterName=`nvram get router_name`
    RunDate=`date '+%F-%H%M'`
    OSVer=`nvram get os_version | cut -d ' ' -f2`
    echo ".operating within a router!"
else
    #if not invoking from within a router, assume debug mode
    RouterName=`uname -n`
    RunDate=`date '+%F-debug'`
    OSVer=`uname -i`
    DEBUG=1
    echo ".not running on a router! DEBUG options set!"
fi
# Remainder of variables work in either environment.
echo -n "Testing to see if we can write to `pwd`.."
	if [[ -w "./" ]]
	then
		echo ".yes!"
		WorkDir="./$RouterName"
	else
		echo ".no, so we will use /tmp"
		WorkDir="/tmp/$RouterName"
	fi
TmpDir="$WorkDir/temp/"
OutputFile="$WorkDir"/"$RunDate"_"$RouterName"_"$OSVer.sh"
CmdLnOpt="$1"
ModFileSource="$2"
ModFileDest="$WorkDir"/"$RunDate"_"$RouterName"_"$OSVer-mod.sh"
echo -e "
==============================================================================
                  Buntster's Tomato Router Manipulation Tools
==============================================================================
\e[0;33mTomato router manipulation tool run on : \e[0;32m$RunDate\e[0m
\e[0;33mRouter name is                         : \e[0;32m$RouterName\e[0m
\e[0;33mCurrent software version is            : \e[0;32m$OSVer\e[0m
\e[0;33mCreating working directory             : \e[0;32m$WorkDir\e[0m
==============================================================================
\e[0m "

CreateWorkDir()
{
#############################################################################
#
#	CreateWorkDir -- a quick routine to create our temp working directory
#		accepts no inputs, has no visible output.
#
##############################################################################

if [[ -n "$DEBUG" ]]    # Provide specialized output in Debug mode
then
	echo "NOTE: Working in DEBUG mode, script will delete working directory"
	rm -Rf "$TmpDir"   # Clobber any existing directory
	mkdir -p "$TmpDir"
	echo \
"==============================================================================
Debug variables
RouterName=$RouterName
RunDate=$RunDate
OSVer=$OSVer
DEBUG=$DEBUG
CmdLnOpt=$CmdLnOpt
ModFileSource=$ModFileSource
ModFileDest=$ModFileDest
WorkDir=$WorkDir
TmpDir=$TmpDir
OutputFile=$OutputFile
=============================================================================="

elif [[ -d "$TmpDir" ]]    # Presence of $TmpDir indicates prior run/crash
	then
		echo "WARNING: Working directory already exists!" >&2
		echo "Cannot continue. Swap file NOT created. Script terminated." >&2
		exit 1
else
	echo -n "Creating working directory..."
	mkdir  -p "$TmpDir"
	echo ".done!"
fi
}

CleanTmpFiles()
{
##############################################################################
#
# Quick routine to delete the working directory. Does not remove the directory
# if debug mode is set. It also verifies that we aren't creating a duplicate
#	export or modify script if we have a working 'diff' on board. 
#
##############################################################################

if [[ -n "$DEBUG" ]]
then
	DebugNotify "${FUNCNAME}" entry
    echo "DEBUG mode set, working files will not be deleted."
else
    echo -e -n  "Removing temporary directory..."
    rm -Rf "$TmpDir"
    echo ".done!" 
	if [ ! "$(ls -A $WorkDir)" ]
	then
		rmdir "$WorkDir"
	fi
fi
if [[ -n "$DEBUG" ]]
then
	DebugNotify "${FUNCNAME}" exit
fi
# If we have 'diff' on board, let's go ahead and prevent duplicates.
if which diff &> /dev/null
then
	DupSrcFileFlag=0
	DupModFileFlag=0
	echo -n "Checking for duplicate scripts.."
	for FILENAME in `ls -1 "$WorkDir"`
	do
		TestFile=$WorkDir/${FILENAME}
		if [ -f "$OutputFile" ]
		then
			if ( diff -q -I 'DIFFIGNORE' ${TestFile} "$OutputFile" &> /dev/null ) && [[ ${TestFile} != "$OutputFile" ]]
			then
				DupSrcFileFlag=$((DupSrcFileFlag+1))
				DupSourceFile=${TestFile}
				rm ${OutputFile}
				OutputFile=${DupSourceFile}
			fi
		fi
		if [ -f "$ModFileDest" ]
		then
			if ( diff -q -I 'DIFFIGNORE' ${TestFile} "$ModFileDest" &> /dev/null ) && [[ ${TestFile} != "$ModFileDest" ]]
			then
				DupModFileFlag=$((DupModFileFlag+1))
				DupModFile=${TestFile}
				rm ${ModFileDest}
				ModFileDest=${DupModFile}
			fi
		fi
		echo -n "."
	done
	echo ".done"
	# if [[ -n "$OutputFile" && "$DupSrcFileFlag" -gt 0 ]]
	if [ $DupSrcFileFlag -gt 0 ]
	then
		echo "Keeping duplicate export file."
	fi
	# if [[ -n "$ModFileDest" && "$DupModFileFlag" -gt 0 ]]
	if [ $DupModFileFlag -gt 0 ]
	then
		echo "Keeping duplicate modified file."
	fi
else
	echo "Sorry,no 'diff' binary on board, cannot check for duplicates."
fi
return 0   
}

NVRAMExportRaw()
{
##############################################################################
#
#   Export NVRAM contents to a working file. If running outside the router
#   environment, copy the contents of a "nvramexportset" from current directory
#
# INPUTS: No specific inputs
# OUTPUTS: nvram dump in $TmpDir/TempFile-01
#
##############################################################################
if [[ -n "$DEBUG" ]]
then
	DebugNotify "${FUNCNAME}" entry
fi

echo -n "Exporting NVRAM to file.."
if [[ -n "$DEBUG" ]]
then
    cat "./nvramexportset" > "$TmpDir/TempFile-01"
else
    nvram export --set > "$TmpDir/TempFile-01"
    # tinker with idea of:  nvram export --set | sed -e 's/nvram set //g'
fi
echo ".done!"
if [[ -n "$DEBUG" ]]
then
	DebugNotify "${FUNCNAME}" exit
fi
return 0
}

ParameterExport()
{
##############################################################################
#
# Function to prioritize the parameters and values in preparation for the final
#   router script. Primary purpose is to set up network and other precursor
#   parameters BEFORE the secondary parameters are passed into the config.
#
# INPUTS: $TmpDir-03 -- file upon which to operate. No specific interactive 
#   inputs, draws from PRIORITY_PARAMS hard coded array-style variable.
#
# OUTPUTS: $TmpDir-05 -- final NVRAM file w/o Network or Hardware parameters, 
#	file containing only the priority parameters with the problem parameters
#	removed. Creates $TmpDir-4, $TmpDir-5 and $TmpDir-6 during parsing as
#	interim steps.
#
# VARIABLES:  "TROUBLE_PARAMS" -- Specifically identified trouble parameters
#             "PRIORITY_PARAMS" -- to identify and adjust parameter order
#             "DISCARD_PARAMS" -- Hardware-specific parameters to remove
#
##############################################################################
if [[ -n "$DEBUG" ]]
then
	DebugNotify "${FUNCNAME}" entry
fi
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


if [[ -n "$DEBUG" ]]
then
	DebugNotify "${FUNCNAME}" exit
fi
return 0
}

ParameterMod()
{
##############################################################################
#
# PURPOSE: Present the user with a series of existing parameter/value pairs
#   and allow the option to change them. Verifies whether any changes were
#   made and if no changes, does not write a file. If changes were made, it
#   merges the changes back into the original file to create the final script.
#
# INPUTS: $ModFileSource, router configuration script passed to the function. 
#   Without this file we have nothing to manipulate.
#
# VARIABLES: CHANGE_PARAMS - An array-style variable containing the parameters
#   that may be manipulated within the script, Internally, VARIABLE, VALUE_OLD,
#	VALUE_NEW
#
# OUTPUTS: $TmpDir/TempFile-13, the sed script created with this function .
#
##############################################################################

if [[ -n "$DEBUG" ]]
then
	DebugNotify "${FUNCNAME}" entry
fi

if [[ ! -r "$ModFileSource" ]]
then
	echo "Cannot read $ModFileSource, check your file name and permissions."
	echo "Cannot continue."
	CleanTmpFiles
	exit
fi

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

echo -n "Parsing to separate network specifics..."
for PARAMETER in $CHANGE_PARAMS
do
    fgrep "$PARAMETER" "$ModFileSource" | sed -e 's/nvram set //g' >> "$TmpDir/TempFile-11"
    echo -n "."
done
fgrep -v echo "$TmpDir/TempFile-11" >> "$TmpDir/TempFile-12"
echo ".done!"

# Update the identified parameters

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

if [[ -n "$DEBUG" ]]
then
	DebugNotify "${FUNCNAME}" exit
fi
return 0
}

GenerateConfigScript()
{
##############################################################################
#
# PURPOSE: Function to merge the parts of now split configuration into a 
#   single configuration script that can be run on another router. This is 
#	where it all comes together. BEWARE: The generated script is designed to
#	wipe out your existing router configuration.
#
# INPUTS:   $TmpDir/TempFile-04 -- Network parameters only, with 'nvram set'
#           $TmpDir/TempFile-05 -- All other parameter w/'nvram set' stmt.
#
# OUTPUTS:  $OutputFile -- the final script completed, updated, and merged.
#
# VARIABLES:$OutputFile: Filename for the output file
#           $TmpDir/TempFile-04: Filename for network parameters
#           $TmpDir/TempFile-05: Filename for non-network/hardware parameters
#
##############################################################################

if [[ -n "$DEBUG" ]]
then
	DebugNotify "${FUNCNAME}" entry
fi
echo \
"#!/bin/sh
##############################################################################
#
# Auto-Generated script file to load the configuration of an Asus RT-66-AU
#   router from one router to another. Using this script will erase any and
#   all existing configurations on your router. USE WITH CARE!!
#
##############################################################################
" > "$OutputFile"
if [[ -n "$DEBUG" ]]
then
    echo "ORIGVERSION=\"$OSVer\"	###DIFFIGNORE###" >> "$OutputFile"
else
    echo "ORIGVERSION=\"`nvram get os_version`\"	###DIFFIGNORE###" >> "$OutputFile"
fi
# Put variable outputs here, so we don't have to contend with quoting issues
# Put a ###DIFFIGNORE### statement on any line you want to ignore when parsing
# for duplicate files. If you do not have a working diff it will not matter.
echo "OrigRunDate=\"$RunDate\"	###DIFFIGNORE###" >> "$OutputFile"
echo "OrigScriptVersion=\"$ScriptVersion\"	###DIFFIGNORE###" >> "$OutputFile"
echo "OrigRouterName=\"$RouterName\"	###DIFFIGNORE###" >> "$OutputFile"

echo \ '
WriteToNvram()
{
#############################################################################
# Module to commit nvram and pause for 15 seconds on each side. This may o  #
#   may not be a superstition, but it doesnt seem to hurt anything.			#
#############################################################################

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
echo "Now entering main set of parameters..."
' >> "$OutputFile"
cat "$TmpDir/TempFile-05" >> "$OutputFile"
echo \
'
echo "Main parameters entered!"
echo "Committing main parameters to NVRAM..."
WriteToNvram
echo "Main parameters committed!"
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
if [[ -n "$DEBUG" ]]
then
	DebugNotify "${FUNCNAME}" exit
fi
return 0
}

output()
{
##############################################################################
#
# Communicate final information to the user.
# INPUTS: $OutputFile, $ModFileSource, $ModFileDest, filenames generated by
#	other modules up to this point.
# OUTPUTS: Text to screen
#
##############################################################################
if [[ -n "$DEBUG" ]]
then
	DebugNotify "${FUNCNAME}" entry
fi
echo \
"Restoration script processing is complete. These scripts can be used to copy
a configuration to a hardware-identical router."

if [[ -r "$OutputFile" ]]
then
	echo \
"The NVRAM configuration of $RouterName has been backed up.
The exported configuration script is stored at:

$OutputFile
"
elif [[ -r "$ModFileSource" ]]
then
	echo \
"The original configuration file has not been changed. It is located at:

$ModFileSource
"
fi

if [[ -r "$ModFileDest" ]]
then
	echo \
"Your updates have been merged into the updated configuration script stored at:

$ModFileDest
"
fi

echo \
"Simply copy the script(s) to the target router, make it executable, and run.
NOTE: The generated script(s) are designed to wipe your configuration as a
first step. THIS IS A DESTRUCTIVE RESTORATION METHOD.
"
if [[ -n "$DEBUG" ]]
then
	DebugNotify "${FUNCNAME}" exit
fi
return 0
}

DebugNotify()
{
##############################################################################
#
# Debug option -- communicate module entry/exit status to user.
# INPUTS: $1 mode (entry or exit), $2--Calling Module
# OUTPUTS: Text to screen
# RETURNS: none
#
##############################################################################

# if DEBUG is 1 -- No, assume debug is 1 if this module is called.

# Set up the parameters from the command line parameters.
MODE="$2"
ModuleName="$1"
# set
# echo "DebugNotify Routine"
# echo "Parameters"
# echo $@
case $MODE in

entry)
	echo "Starting module $ModuleName()"
;;

exit)
	echo "Exiting module $ModuleName()"
;;

*)
	# Catch all for errors in syntax or other glitches
	echo "Message from ${FUNCNAME}(): You broke it, 'cuz you're a gross ignoramus as a programmer."
	return 1
;;
esac
return 0
}
   

case $CmdLnOpt in
export)
##############################################################################
# Configuration Export Routine
##############################################################################

CreateWorkDir         # Create a working directory
NVRAMExportRaw        # Exports the contents of the running NVRAM to a file
ParameterExport       # Prioritize network parameters to re-order the load
GenerateConfigScript  # Builds the final configuration script
CleanTmpFiles         # Deletes temp/working directories as appropriate
output                # Communicate with the user
;;

modify)

##############################################################################
# Router Swap Script Routine
##############################################################################

CreateWorkDir                     # Create a working directory
if [[ -z "$ModFileSource" ]]
then
	echo "ModFileSource not passed at command line, means we need to create"
	NVRAMExportRaw                  # Exports the contents of the running NVRAM
	ParameterExport                 # Re-order the parameters loaded
	GenerateConfigScript            # Builds the configuration script
	ModFileSource="$OutputFile"     # Modify the file we just created
fi
ParameterMod                      # Change parameters and merge script
CleanTmpFiles                     # Cleans up temporary directories
output                            # Communicate with the user
;;

*)
clear
echo "
usage: $0 [export|modify] [filename]

OPTIONS

 export - Exports nvram configuration into a portable restoration script for
	backup, or settings transfer to a hardware-identical router.
 
modify - In interactive mode (default) creates a portable restoration i
	identical to export mode, then allows direct modifications to several key
	parameters as direct entry. Passing a [filename] performs modifies the
	specified filename. 
			
[filename] -Optional existing filename to modify.

This is free software. It comes with no warranty or guarantee of fitness
or usability. If it breaks your router in two, you own both parts. If you wish
to add or modify the functionality, have at it. I'd love to get a copy to see
what you did or learn a better way to do it. I hope you find it as useful as
I do. I've spent too many hours automating a 15 minute task for the whole
thing to go to waste!
"

;;
   
esac
