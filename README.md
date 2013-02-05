pg-base-collector
=================

Postgres base collector script (bash)
This is a little script that allows you to take a base backup of your postgres database. As the postgres docs suggest, 
its neither desireable or required to stop the database - and shouldnt cause any impact to use during the backup period. 

Background
----------
I have often been looking for a method to aid me in taking postgres db snapshot-backups on a weekly/monthly/however
basis. I have seen the likes of barman and other tools out there, but seems to extract the knowledge of how/what the 
tools are doing to produce the backup results, and _seems_ overcomplicated. 

Use condition
-------------
This is for anyone who needs a snapshot of the base folder of a database on occasion. This is required if you chose 
to keep archived wals, but then realise that space is filling up after a while, and in order to keep archived wals 
you need a base backup to accompany it.

So you would run this script on say a weekly basis (on the chosen database host), and specify how many backups you want to 
keep. 

Its simple bash, and should show you all you need to know - coupled with a few test conditions and variables. 

How it works
------------
This script simply requests that the database perform a 'start backup', tars up the base folder, and then tells the 
postgres database to stop the backup function. 

Once this has been completed, it will then check the archive folder, and remove older than <specified> WALs.

This should be run on the master DB. 

Take a look. Its very simple. 

How i would run
---------------
I usually run the command manually as the postgres user in the home directory (~postgres). I have pg-base-collector 
located in the /opt/pg-base-collector area. 

I run /opt/pg-base-collector and check the settings, and launch. 

After a few checks (and happy with the outcome) i then add as a cronjob. Check the cron, as things like starting
directories etc will be completely different and may cause pg-base-collector to fail or put the backup tar somewhere
unexpected. 


Suggestions welcome
-------------------
If you have any suggestions, please let me know. 
