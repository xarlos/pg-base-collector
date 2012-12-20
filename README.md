pg-base-collector
=================

Postgres base collector script (bash)
This is a little script that allows you to take a base backup of your postgres database. As the postgres docs suggest, 
its neither desireable or required to stop the database - and shouldnt cause any impact to use during the backup period. 

Background
----------
I have often been looking for a method to aid me in taking postgres db snapshot-backups on a weekly/monthly/however
basis. I have seen the likes of barman and other tools out there, but seems to extract the knowledge of how/what the 
tools are doing to produce the backup results, and _seems_ overcomplicating. 

Use condition
-------------
This is for anyone who needs a snapshot of the base folder of a database on occasion. This is required if you chose 
to keep archived wals, but then realise that space is filling up after a while, and in order to keep archived wals 
you need a base backup to accompany it.

So you would run this script on say a weekly basis (on the chosen database host), and then remove all unrequired wals 
from your archive directory. 

How it works
------------
This script simply requests that the database perform a 'start backup', tars up the base folder, and then tells the 
postgres database to stop the backup function. 

Currently, this is written to be performed on the master (called by cron or so) - but will expand to perform copy soon. 

Take a look. Its very simple. 

Suggestions welcome
-------------------
If you have any suggestions, please let me know. 