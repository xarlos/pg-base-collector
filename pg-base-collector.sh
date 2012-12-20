#!/bin/bash
#
#====================================
# Backup script for postgres
#====================================

# Config
# ------
required_user="postgres"                             # So that all perms etc are correct
backup_dir="/var/lib/postgresql/9.2/main"            # Backup directory (main)
backup_file="backup_$(date +%d%m%Y%H%M).tar"         # What the tar will be called
tar_command="tar -czf ${backup_file} ${backup_dir}"    # Command to tar (or gzip etc)
copy_command="scp $backup_file postgres@192.168.111.22:/srv/pg_backup/" # Make sure passwordless access enabled

# Internal config
# ---------------
psql=$(which psql)
start_backup=" SELECT pg_start_backup('${backup_file}');"
stop_backup=" SELECT pg_stop_backup();"


#====================================
# Initial checks
#====================================

# Check running as postgres
# -------------------------
if [ "$(whoami)" != "$required_user" ]; then
   echo "Please run as postgres user"
   exit 1
fi


# Check that the backup_dir exists
# --------------------------------
if [ ! -d "$backup_dir" ]; then
   echo "Your designated backup directory does not exist"
   exit 1
fi

# Check the psql command was found
# --------------------------------
if [ -z "$psql" ]; then
   echo "Cannot find the psql binary!"
   exit 1
fi

#=====================================
# Show the config
#=====================================
   
# clear
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
read pressenter

#====================================
# Start backup routine
#====================================
# Start postgres 'backup' mode
psql -c "${start_backup}" || exit 127

# Check for backup_label
[ -f "$backup_dir/backup_label" ] || exit 127

# Tar up the file
$tar_command || exit 127

# Stop 'backup' mode
psql -c "${stop_backup}" || exit 127

echo "Backup completed"
