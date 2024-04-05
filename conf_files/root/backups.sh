#!/bin/sh

set -eu

BORG_COMMAND=/usr/local/bin/borg
BACKUP_DATE=`date '+%Y%m%d-%H%M'`
SAVE_ROOT_DIR=/var/backups/matomo
DB_SAVED_DIR=$SAVE_ROOT_DIR/mysql
DATA_SAVE_DIR=$SAVE_ROOT_DIR/matomo
CONFIG_SAVE_DIR=$SAVE_ROOT_DIR/config

db_local_backup()
{
	LATEST=$DB_SAVED_DIR/latest

	PREVIOUS=`readlink -f $LATEST`
	NEXT=$DB_SAVED_DIR/$BACKUP_DATE


	if [ -d "$NEXT" ]; then
		echo "'$NEXT' already exists."
		exit 1
	fi

	# See https://github.com/omegazeng/run-mariabackup for mariabackup options for
	# compressed and incremental backups.

	if [ "$#" -ge 1 ] && [ "$1" = "full" ]; then
		NEXT=$NEXT-full
		mkdir $NEXT
		mariabackup --backup --stream=xbstream --extra-lsndir $NEXT 2> $NEXT/mariabackup.log | gzip > $NEXT/backup.stream.gz
	else
		if ! [ -L "$LATEST" ]; then
			echo "'$LATEST' does not exists. Consider doing a full backup first."
			exit 1
		fi

		mkdir $NEXT
		mariabackup --backup --stream=xbstream --extra-lsndir $NEXT --incremental-basedir $PREVIOUS 2> $NEXT/mariabackup.log | gzip > $NEXT/backup.stream.gz
	fi

	rm -f $LATEST $LATEST.log
	ln -s $NEXT $LATEST
	ln -s $NEXT/mariabackup.log $LATEST.log
}

data_local_backup()
{
	echo "** Starting local backup of Matomo application code..."
	rsync -a --exclude="tmp/*" /usr/share/matomo/ $DATA_SAVE_DIR
}

config_local_backup()
{
	echo "** Starting local backup of Matomo configuration..."
	rsync -a /etc/matomo/ $CONFIG_SAVE_DIR
}

backup2beta()
{
	echo "Send backup to the beta server..."
	$BORG_COMMAND create                                 \
	    --verbose                                        \
	    --filter AME                                     \
	    --list                                           \
	    --stats                                          \
	    --show-rc                                        \
	    --compression zstd,6                             \
	    --exclude-caches                                 \
	    --info                                           \
	    beta-backup:/opt/sauvegarde/matomo::$BACKUP_DATE \
	    $SAVE_ROOT_DIR
}

# Add here other functions to backup to external servers

db_clean()
{
	echo "** Removing old local backups of the database..."

	BACKUPS="`echo $DB_SAVED_DIR/*-*/ | tr ' ' '\n' | sort -nr`"

	TO_DELETE="`
		echo "$BACKUPS" | awk '
			BEGIN { full=0 }
			{ if (full >= 1) { print $0 } }
			/full/ { full++ }
		'
	`"

	echo "To be removed: $TO_DELETE"
	[ -z "$TO_DELETE" ] || rm -r $TO_DELETE
}


# Big separator in log between executions of the script:
echo "#######################################################################################################################"
echo "Starting script ($(date))"

if [ "$#" -ge 1 ] && [ "$1" = "full" ]; then
	echo "** Starting a local full backup of the database..."
	db_local_backup full
	db_clean
else
	echo "** Starting a local incremental backup of the database..."
	db_local_backup
fi

data_local_backup
config_local_backup

set +e
backup2beta2023; err1=$?
# Call here functions to backup to external servers
# backup2toto; err2=$?
err=$((err1+err2))
set -e

if [ $err -gt 0 ]; then
	echo "At least one backup failed!"
else
	echo "All backups completed successfully!"

	curl -s -m 10 --retry 5 $(cat /root/healthchecks/matomo-sauvegardes.txt)
	echo # to make a newline after the "OK" written by curl
fi

echo "End of script ($(date))"
# Big separator in log between executions of the script:
echo "#######################################################################################################################"
