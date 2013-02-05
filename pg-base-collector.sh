#!/bin/bash
#===============================================================================================================
# Backup script for postgres
#===============================================================================================================
#
# Version 0.7 (Beta)
# ------------------
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
# --> 30 3 * * 7         /opt/pg-base-collector auto 2> /dev/null
#
# Changelog
# ---------
#
# v0.7
# Changed the way it finds the old archive logs. This way seems much cleaner
# though i really wanted to make sure that any other logs in here are not 
# likely to be deleted by mistake (though ideally this folder should be bare 
# postgres backup data). Or else it could be cleaner still.
#
# v0.6 
# More of a detailed report is now available afterwards. 
# It also allows the alility for email here too.
#
# v0.5 
# Tidied up the config a little.
# Added a notify example at the bottom. 
#
# v0.4
# Seems to work quite well. Bit of tidying done. 
#
# v0.3.2
# Minor bug on delete.  eek.
#
# v0.3.1
# Forgot to actually put the rm in *redface*
#
# v0.3
# Added delete option of old wals
#
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
# Environment:
pg_dir="/var/lib/postgresql/9.2/main"                                 # Postgres directory
archive_location="/srv/pg_archive/"                                   # WAL location
backup_prefix="backup_"                                               # This is used when deleting old archives!!
backup_file="${backup_prefix}$(date +%d%m%Y%H%M).tar"                 # Format of the backup tar (backup filename)   
backup_folder="/opt/pg-base-collector/backupfolder"                   # I have decided to use a backup folder
copy_command="mv ${backup_folder}/${backup_file} ${archive_location}" # This could be a mounted shared drive
                                                                      # or set to "" to keep it in $backup_folder
log_file="${backup_folder}/backup.log"                                # _If_ this is set, all output will go here 
finish_script="/opt/pg-base-collector/success_notify.sh"              # Leave this as nothing if you dont want one. 
email_report_recipient="an@emal.addy"                                 # Recipient address
email_report_title="pg-base-collector Report"                         # Email title
email_report="N"                                                      # Set this to Y (capital) if you want to send

# Assumed:
required_user="postgres"                                              # So that all perms etc are correct
leave_count=5                                                         # How many "backups" to leave. This includes
                                                                      #   the WALs that are applicable.
tar_command="tar -czf ${backup_folder}/${backup_file} ${pg_dir}"      # Command to tar (or gzip etc)
                                                        
# Examples / other: 
# copy_command="scp ${backup_folder}/${backup_file} server:/srv/pg/"  # or an ssh copy (remember to setup keys!)

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
# check for a non-specified logfile
#---------------------------------------------------------------------------------------------------------------
if [ -z "$log_file" ]; then
   log_file="${backup_folder}/pg-base-collector.log"                     # If no logfile, then push to current dir. 
fi

#---------------------------------------------------------------------------------------------------------------
# Turn on silent operation if running in auto mode. 
#---------------------------------------------------------------------------------------------------------------
if [ "$auto" == 'Y' ]; then
   exec >> $log_file 2>&1                                  # Turn this on for silent operation if unattended
fi

#---------------------------------------------------------------------------------------------------------------
# Check running as postgres
#---------------------------------------------------------------------------------------------------------------
if [ "$(whoami)" != "$required_user" ]; then
   echo "Please run as postgres user"
   exit 1
fi

#---------------------------------------------------------------------------------------------------------------
# Check that the pg_dir exists
#---------------------------------------------------------------------------------------------------------------
if [ ! -d "$pg_dir" ]; then
   echo "Your designated postgres directory does not exist: $pg_dir"
   exit 1
fi

#---------------------------------------------------------------------------------------------------------------
# Check that the archive exists            (If you dont need/want WALs - then you can delete/ignore this check)
#---------------------------------------------------------------------------------------------------------------
if [ ! -d "$archive_location" ]; then
   echo "Your designated WAL archive directory does not exist: $archive_location"
   exit 1
fi


#---------------------------------------------------------------------------------------------------------------
# Check that the backup_dir exists
#---------------------------------------------------------------------------------------------------------------
if [ ! -d "$backup_folder" ]; then
   echo "Your designated backup directory does not exist: $backup_folder"
   exit 1
fi

#---------------------------------------------------------------------------------------------------------------
# Check write permissions for the backup directory (as will need for the tar creation)
#---------------------------------------------------------------------------------------------------------------
if touch ${backup_folder}/check.del; then
   rm ${backup_folder}/check.del 
else
   echo "You dont have permission to write to the backup destination"
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
echo "Database folder : ${pg_dir}"
echo "Backup directory: ${backup_folder}"
echo "Backup filename : ${PWD}/${backup_file}"
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
# sql backup start command. This tells postgres: "Hey! go into backup mode for me please." This means that we
# can then start to take a base backup without interrupting 

echo "Starting backup mode"
if psql -o /dev/null -c "${start_backup}"; then
   echo "   Backup Mode.............................[OK] "
else
   echo "   Backup mode.............................[FAIL]"
   echo "   ........................................QUITTING"
   exit 1
fi


#---------------------------------------------------------------------------------------------------------------
# Check for backup_label
#---------------------------------------------------------------------------------------------------------------
# The backup label will exist if the above backup command started. Its a double check for the script so that we 
# do not begin to take a backup of the "base". It will subsequently disappear once the backup has been stopped. 

echo "Check for backup label"
if [ -f "${pg_dir}/backup_label" ]; then
   echo "   Found the backup label..................[OK]"
else
   echo "   Cannot find the backup file.............[FAIL]"
   echo "   ........................................QUITTING"
   exit 127
fi


#---------------------------------------------------------------------------------------------------------------
# Tar up the file
#---------------------------------------------------------------------------------------------------------------
echo "Starting the tar of the backup file"
if $tar_command; then
   echo "   Tarring up the file ....................[OK]"
else
   echo "   Tarring up the file ....................[FAILED]"
   echo "   ........................................STOPPING BACKUP"
fi

#---------------------------------------------------------------------------------------------------------------
# Stop 'backup' mode
# - You will always want to set backup mode to stop if it ever started. 
#---------------------------------------------------------------------------------------------------------------
echo "Stopping backup mode on postgres"
if psql -o /dev/null -c "${stop_backup}"; then
   echo "   Stopping backup mode....................[OK]"
else
   echo "   Stopping backup mode....................[FAILED]"
fi

#---------------------------------------------------------------------------------------------------------------
# Copy across to storage
# - this should have a shared key for passwordless copy in automatic mode. 
#---------------------------------------------------------------------------------------------------------------
echo "Copy to backup resting place"
if [ -f ${backup_folder}/${backup_file} ]; then
   if $copy_command ; then
      echo "   Copying to destination..................[OK]"
   else
      echo "   Copying to destination..................[FAILED]"
   fi
else
   echo "   Copying to destination..................[FAILED]"
   echo "   ........................................NO BACKUP TO COPY"
fi

#---------------------------------------------------------------------------------------------------------------
# Find the old backup files and set to delete. 
#---------------------------------------------------------------------------------------------------------------
# 
# Maybe this could be a little more effective - but as it's done by count and NOT date - it's as it is for now. 
#
# 1. List the order of the backup files by date
# 2. find the $leave_count entry.
# 3. If the files do not count up to the required Xth entry, then exit WITHOUT delete
# 4. Array all files BEFORE this file (oldest first)
backup_count=0                                       # Init counts
cd "$archive_location"                               # Jump into archive directory explicitly
IFS=$'\n'                                            # Set field separator

# 1. List the order of the backups by date
# -----------------------------------------
for backup_found in $(ls -lt *.backup); do
    backup_count=$(($backup_count + 1))
    backup_file=$(echo $backup_found | awk '{print $9}')

    # 2. Find the $leave_count entry. 
    # -------------------------------
    # Find the X'th backup file via it's counted parameter. 
    # Once the X'th number is reached, we want to keep all files AFTER this backup entry. 
    if [ $backup_count -eq $leave_count ]; then
        last_backup_entry="$backup_file"  # <--- here's our last file to keep
    fi
done

# 3. If the files do not count up to the required Xth entry, then exit WITHOUT delete
if [ $backup_count -le $leave_count ]; then
   # --------------------------------------------------------------------------------------------------------------
   echo "No backups need to be removed"
   # --------------------------------------------------------------------------------------------------------------
   # Set these for reporting purposes
   report_wal_count=0
   report_backup_count=0

else
   #---------------------------------------------------------------------------------------------------------------
   # Prepare WAL and backup files ready for delete
   #---------------------------------------------------------------------------------------------------------------
   report_st_delete=$(date +%H:%M:%S)

   wal_count=0
   delete_rest="N"

   # Delete all the files in the folder assumed to be WAL files:
   for found_walfile in $(ls -lt 0000* ${backup_prefix}* | awk '{print $9}') ; do          

      # Count found for report purposes:
      wal_found_count=$(($wal_found_count +1))

      # Ignore files until we get to the file we want to delete after
      # as these files will be newer. 
      if [ "$delete_rest" == "Y" ]; then
         rm -v $found_walfile
         report_wal_delete_count=$(($report_wal_delete_count +1))
      fi 

      # Test for the file AFTER the above, or it will set flag on the file we want 
      # to keep as the Nth backup :-s
      if [ "$found_walfile" == "$last_backup_entry" ]; then
          # Ignore until this loop is satisfied
          delete_rest="Y"
      fi
   done
   report_wal_found_count=$wal_found_count
   report_wal_delete_count=$wal_del_count

   report_fi_delete=$(date +%H:%M:%S)
fi


#---------------------------------------------------------------------------------------------------------------
# Finishing summary
#---------------------------------------------------------------------------------------------------------------
summary_backup_files=$(ls -l ${archive_location}/*.backup | wc -l)
summary_tar_files=$(ls -l ${archive_location}/*.backup | wc -l)
summary_wal_files=$(ls ${archive_location} | grep -v ".tar" | grep -v ".backup" | wc -l)

# Example to use in a pushover message:
quick_summary="\n
Retained file count:               \n
Backup files: $summary_backup_files\n
Tar files   : $summary_tar_files   \n
WAL Files   : $summary_wal_files"   

# Example to use in an email message:
detailed_summary="\n
Number of remaining .backup files: $summary_backup_files                 \n
Number of remaining .tar files   : $summary_tar_files                    \n
Number of remaining WAL files    : $summary_wal_files                    \n
Number of purged WAL files       : $report_wal_count                     \n
Number of purged backup files    : $report_backup_count                  \n"


#---------------------------------------------------------------------------------------------------------------
# Output the summary to STDOUT if not in automatic mode. 
#---------------------------------------------------------------------------------------------------------------
echo -e "$detailed_summary"
echo -e "$quick_summary"

#---------------------------------------------------------------------------------------------------------------
# Email the detailed report out
#---------------------------------------------------------------------------------------------------------------
if [ "$email_report" == "Y" ]; then
   echo -e "$detailed_summary" | mail "$email_report_recipient" -s "$email_report_title"
fi

#---------------------------------------------------------------------------------------------------------------
# launch custom script (pushover script in this case)
#---------------------------------------------------------------------------------------------------------------
# Just a script you can add at will. In my case i have a pushover notification script and email.  
$finish_script "Backup completed: $backup_file $quick_summary"

# Go back to orig dir
cd -


