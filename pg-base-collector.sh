#!/bin/bash
#===============================================================================================================
# Backup script for postgres
#===============================================================================================================
#
# Version 0.3
# -----------
# Author: Xarlos
# 
# Howto:
# ------
# 1. Amend the config below to suit your setup
# 2. Run manually ./$0
# 3. Check the output, and make sure its what you expect. 
# 4. Confirm this with a press of the enter. 
# 5. Watch the work as it happens. 
# 6. Consider adding as a cron job. (doing so with the auto argument). 
# --> 30 3 * * 7 Sunday /opt/pg-base-collector auto 2> /dev/null
#
# Changelog
# ---------
# v0.2
# Added a bit nicer information
# Added automatic "auto" option which limites the output.  $0 auto
#
# v0.1 
# Backs up file
# Work in progress
#===============================================================================================================

#---------------------------------------------------------------------------------------------------------------
# automatic argument sent?
#---------------------------------------------------------------------------------------------------------------
[ "$1" == "auto" ] && auto='Y' || auto='N'


#---------------------------------------------------------------------------------------------------------------
# Config
#---------------------------------------------------------------------------------------------------------------
required_user="postgres"                                # So that all perms etc are correct
backup_dir="/var/lib/postgresql/9.2/main"               # Backup directory (main)
backup_file="backup_$(date +%d%m%Y%H%M).tar"            # What the tar will be called
tar_command="tar -czf ${backup_file} ${backup_dir}"     # Command to tar (or gzip etc)
copy_command="cp $backup_file /srv/pg_archive/"         # This could be a mounted shared drive
# copy_command="scp $backup_file server:/srv/pg/"       # or an ssh copy (remember to setup keys!)
leave_count=5                                           # How many "backups" to leave
archive_location="/srv/pg_archive/"                     # WAL location
#log_file="$PWD/backup.log"                             # _If_ this is set, all output will go here. 

#---------------------------------------------------------------------------------------------------------------
# Internal config
#---------------------------------------------------------------------------------------------------------------
psql=$(which psql)
start_backup="SELECT pg_start_backup('${backup_file}');"
stop_backup="SELECT pg_stop_backup();"

#===============================================================================================================
# Initial checks
#===============================================================================================================
#---------------------------------------------------------------------------------------------------------------
# Turn on silent operation if running in auto mode. 
#---------------------------------------------------------------------------------------------------------------
if [ -z "$log_file" ]; then
   log_file="/dev/null"                                   # If no logfile, then push to /dev/null
fi

#---------------------------------------------------------------------------------------------------------------
# Turn on silent operation if running in auto mode. 
#---------------------------------------------------------------------------------------------------------------
if [ "$auto" == 'Y' ]; then
   exec > $log_file 2>&1                                  # Turn this on for silent operation if unattended
fi

#---------------------------------------------------------------------------------------------------------------
# Check running as postgres
#---------------------------------------------------------------------------------------------------------------
if [ "$(whoami)" != "$required_user" ]; then
   echo "Please run as postgres user"
   exit 1
fi

#---------------------------------------------------------------------------------------------------------------
# Check that the backup_dir exists
#---------------------------------------------------------------------------------------------------------------
if [ ! -d "$backup_dir" ]; then
   echo "Your designated backup directory does not exist"
   exit 1
fi

#---------------------------------------------------------------------------------------------------------------
# Check perms for the PWD (as will need for the tar creation)
#---------------------------------------------------------------------------------------------------------------
if touch ${PWD}/check.del; then
   rm ${PWD}/check.del 
else
   echo "You dont have permission to write to the tar destination"
   exit 1
fi

#---------------------------------------------------------------------------------------------------------------
# Check the psql command was found
#---------------------------------------------------------------------------------------------------------------
if [ -z "$psql" ]; then
   echo "Cannot find the psql binary!"
   exit 1
fi

#===============================================================================================================
# Show the config
#===============================================================================================================
clear
#---------------------------------------------------------------------------------------------------------------
# Mark the start of the backup in the logfile
#---------------------------------------------------------------------------------------------------------------
echo "BASE BACKUP"
echo "==========="
echo -e "Started: \c"
echo $(date +%d%m%y%H%M)
echo "---------------------------------------------------------------------------------------------------------"
echo " "
echo "Check parameters"
echo "----------------"
echo "backup directory: ${backup_dir}"
echo "backup filename : ${PWD}/${backup_file}"
echo " "
echo "Routine"
echo "-------"
echo "pg start backup : $start_backup"
echo "tar using       : $tar_command"
echo "pg stop backup  : $stop_backup"
echo "copy using      : $copy_command"
echo " "
echo -e ".... Press enter to start\c"
echo " "

#---------------------------------------------------------------------------------------------------------------
# Prompt the pressenter to continue if run manually 
#---------------------------------------------------------------------------------------------------------------
if [ "$auto" != 'Y' ]; then
   read pressenter
fi

#===============================================================================================================
# Start backup routine
#===============================================================================================================
# Supress all the outputs to the logfile. 
# exec >> $log_file 2>&1                                  # Turn off if you want better visability on stdout

#---------------------------------------------------------------------------------------------------------------
# Start postgres 'backup' mode
#---------------------------------------------------------------------------------------------------------------
echo "Starting backup mode__________________________"
if psql -o /dev/null -c "${start_backup}"; then
   echo "Backup Mode.............................[OK] "
else
   echo "Backup mode.............................[FAIL]"
   echo "........................................QUITTING"
   exit 1
fi

#---------------------------------------------------------------------------------------------------------------
# Check for backup_label
#---------------------------------------------------------------------------------------------------------------
echo "Check for backup label________________________"
if [ -f "$backup_dir/backup_label" ]; then
   echo "Found the backup label..................[OK]"
else
   echo "Cannot find the backup file.............[FAIL]"
   echo "........................................QUITTING"
   exit 127
fi

#---------------------------------------------------------------------------------------------------------------
# Tar up the file
#---------------------------------------------------------------------------------------------------------------
echo "Starting the tar of the backup file___________"
if $tar_command; then
   echo "Tarring up the file ....................[OK]"
else
   echo "Tarring up the file ....................[FAILED]"
   echo "........................................STOPPING BACKUP"
fi

#---------------------------------------------------------------------------------------------------------------
# Stop 'backup' mode
# - You will always want to set backup mode to stop if it ever started. 
#---------------------------------------------------------------------------------------------------------------
echo "Stopping backup mode on postgres______________"
if psql -o /dev/null -c "${stop_backup}"; then
   echo "Stopping backup mode....................[OK]"
else
   echo "Stopping backup mode....................[FAILED]"
fi

#---------------------------------------------------------------------------------------------------------------
# Copy across to storage
# - this should have a shared key for passwordless copy in automatic mode. 
#---------------------------------------------------------------------------------------------------------------
echo "Copy to backup resting place_____________________"
if [ -f ${backup_file} ]; then
   if $copy_command ; then
      echo "Copying to destination..................[OK]"
   else
      echo "Copying to destination..................[FAILED]"
   fi
else
   echo "Copying to destination..................[FAILED]"
   echo "........................................NO BACKUP TO COPY"
fi

#---------------------------------------------------------------------------------------------------------------
# Find the old backup files
#---------------------------------------------------------------------------------------------------------------
# 
# List the order of the backup files by date
# find the $leave_count entry.
# If the files do not count up to the required Xth entry, then exit WITHOUT delete
# array all files BEFORE this file (oldest first)

backup_count=0
cd "$archive_location"

# Find the $leave_count entry. 
IFS=$'\n'
for backup_found in $(ls -lt *.backup); do
    backup_count=$(($backup_count + 1))
    backup_file[$backup_count]=$(echo $backup_found | awk '{print $9}')
done

echo "Backups found: $backup_count"
echo "----------------------------"

count=0
while [ $count -le $backup_count ]; do
   count=$(($count + 1))
   if [ $count -le $leave_count ]; then
      echo "[keep] ${backup_file[$count]}"
   else
      echo "[Delete] ${backup_file[$count]}"
   fi
done

if [ $backup_count -le $leave_count ]; then
   echo "There are less backups in storage than what we want"
   echo "- Therefor no backups will be deleted"
else
   # Gather each WAL file
   wal_count=0
   for delete_wal_list in $(ls -lt 000000*) ; do
      wal_count=$(($wal_count + 1))
      delete_wal[$wal_count]=$(echo $delete_wal_list | awk '{print $9}')
   done

   # Gather each BACKUP file (if any)
   back_count=0
   for delete_back_list in $(ls -lt 000000*) ; do
      back_count=$(($back_count + 1))
      delete_back[$back_count]=$(echo $delete_back_list | awk '{print $9}')
   done

   
#---------------------------------------------------------------------------------------------------------------
# Deleting WALs (Counting BACKWARDS)
#---------------------------------------------------------------------------------------------------------------
   while [ "${delete_wal[$wal_count]}" != "${backup_file[$leave_count]}" ]; do
      echo "Deleting: ${delete_wal[$wal_count]}"
      wal_count=$(($wal_count - 1))
   done
    
#---------------------------------------------------------------------------------------------------------------
# Deleting Backups (Counting BACKWARDS)
#---------------------------------------------------------------------------------------------------------------
   while [ "${delete_back[$back_count]}" != "${backup_file[$leave_count]}" ]; do
      echo "Deleting: ${delete_back[$back_count]}"
      back_count=$(($back_count - 1))
   done
fi

# Go back to usual dir
cd -


