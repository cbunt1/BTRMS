#!/bin/sh
###############################################################################
# Copyright (C) 2015  Chris A. Bunt (cbunt1@yahoo.com)
#   All rights reserved.
#   This program comes with ABSOLUTELY NO WARRANTY.
#   This is free software, and you are welcome to redistribute it.
#   See the file LICENSE for details.
###############################################################################
# BTRMS host-exec.sh -- This is the host-side executable. It runs on the host
#   machine, and will connect to client routers remotely via certificate
#   based ssh login (no password) and runs the remote script. 
#
# The script loops through a list of hostnames, defined in the file remotehosts
#   Configurable as a variable below) and execute the backup process via the
#   remote-exec.sh script. It then loops through the remotehosts file and
#   uses scp to collect the backup files and store them in the
#   $BackupStorageDir.
###############################################################################

# USER CONFIGURABLE VARIABLES -- Edit these for your environment
RemoteScript="./remote-exec.sh"         # Script to execute on remotes
RemoteHosts="./remotehosts"             # File listing machines to backup
RemoteUserID="root"                     # Usually root, but some change this
BackupStorageDir="./RouterBackups"      # Dir where we store the backups
DropBearRSA="$HOME/.ssh/id_rsa.db"      # Location of Dropbear identity file

# Initialize non-user variables -- probably shouldn't change these.
SysType=`uname -m`                       # if return 'mips' we're in a router.

# Do not edit below this line unless you want to change the actual program.

echo "BTRMS automated backup tool. Copyright (c) 2015 Chris A. Bunt"
echo "All rights reserved."
echo "This program comes with ABSOLUTELY NO WARRANTY."
echo "This is free software, and you are welcome to redistribute it."
echo "See the file LICENSE for details."

# This section would be a good spot to MOUNT a remote directory for your
#   BackupStorageDir should you be so inclined. I mount a cifs directory
#   and symlink it to my homedir when I run it directly in a router, but
#   I usually run this from an external GNU/Linux environment.

# Initialize the storage directory for our backups.
if [[ ! -w "$BackupStorageDir" ]] ; then
    mkdir "$BackupStorageDir"
    # Double check that we can write to the directory we blindly created.
    if [[ ! -w "$BackupStorageDir" ]] ; then echo "You don't have write access to your storage directory!" && exit ; fi
fi

grep -v '^#' "$RemoteHosts" | while read -r MachineName
do 
        echo -n "Backing up $MachineName.."
        if [ $SysType == "mips" ]
        then
        RemoteFile=`ssh -T ${RemoteUserID}@${MachineName} -i ${DropBearRSA} '/bin/sh -s' < ${RemoteScript}` && scp -pri "$DropBearRSA" "$RemoteUserID@$RemoteFile" "$BackupStorageDir"
        echo ".done!"
        else
        RemoteFile=`ssh ${RemoteUserID}@${MachineName} '/bin/sh' < ${RemoteScript}` &&  scp -Cpr "$RemoteUserID"@"$RemoteFile" "$BackupStorageDir"
        fi
done

# This would be a good spot to UNMOUNT any remote directories for 
#   BackupStorageDir you mounted above. It also serves as a great 
#   place to make final file copies to permanent locations, update
#   log files or any othr post-processing you wish.
exit 0      # Ensure a clean exit