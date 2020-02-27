
#########################################################
##### Upgrade SQL with Minimum disruption and Risk ######
#########################################################

<# Code for In-Place upgrade of SQL Server 2017 to SQL Server 2019 #>

###### (NOT A BEST OPTION FOR PRODUCTION SERVERS CONSIDERING THE AMOUNT OF BUSINESS RISK ASSOCIATED) ########
###### (NOT A BEST OPTION FOR PRODUCTION SERVERS CONSIDERING THE AMOUNT OF BUSINESS RISK ASSOCIATED) ########

<###################################################################################################################### 

#####################################################
#### Considering Fatcs for this In-Place upgrade ####
#####################################################

    1. SQL Server is installed on Windows Cluster (WSFC) - 3 Nodes  
    2. User Databases are part of AlwaysOn Availability Group - 3 Replica and in AG read-only workload is redirected to Secondary Replica
    3. Databases also have Transaction Replication configured with Remote Distributor

    *************************************************************************************

NOTE: Below Pre-Requisites are *MANDATORY* for the Data Recovery and Smooth In-Place upgrade of SQL Server 2017 to SQL Server 2019

        1. Verify that backups and Log backups exist for all databases (user and system).Verify that these backups are able to be restored.
        2. Make sure you have Admin Rights over the Instances for proper Installation (To avoid Access Denbied issues)
        3. Make sure you script out all important SQL Server Jobs , SQL Server Logins 
        4. Make sure you script out all Transactional Replication Jobs , Publishers , Subscribers etc ...
        5. Script out any and all necessary system objects.
        6. Script out any and all necessary SSIS packages (either from MSDB or as flat files).

    **************************************************************************************
NOTE: USE ONLY the upper version ConfigurationFile.ini in case of "/ACTION = UPGRADE"
NOTE: During Upgrade below ConfigurationFile.ini Parameters are NOT accepted & make sure they are either DELETED or COMMENTED 

    1.The /IAcceptSQLServerLicenseTerms command line parameter is missing or has not been set to true. It is a required parameter for the setup action you are running. 
    2.The setting 'FEATURES' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    3.The setting 'INSTALLSHAREDDIR' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    4.The setting 'INSTALLSHAREDWOWDIR' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    5.The setting 'INSTANCEDIR' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    6.The setting 'AGTSVCACCOUNT' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    7.The setting 'AGTSVCSTARTUPTYPE' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    8.The setting 'COMMFABRICPORT' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    9.The setting 'COMMFABRICNETWORKLEVEL' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    10.The setting 'COMMFABRICENCRYPTION' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    11.The setting 'MATRIXCMBRICKCOMMPORT' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    12.The setting 'SQLSVCSTARTUPTYPE' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    13.The setting 'FILESTREAMLEVEL' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    14.The setting 'SQLMAXDOP' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    15.The setting 'SQLMAXMEMORY' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    16.The setting 'SQLMINMEMORY' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    17.The setting 'ENABLERANU' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    18.The setting 'SQLCOLLATION' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    19.The setting 'SAPWD' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    20.The setting 'SQLSVCACCOUNT' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    21.The setting 'SQLSVCINSTANTFILEINIT' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    22.The setting 'SQLSYSADMINACCOUNTS' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    23.The setting 'SQLTEMPDBFILECOUNT' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    24.The setting 'SQLTEMPDBFILESIZE' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    25.The setting 'SQLTEMPDBLOGFILEGROWTH' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    26.The setting 'ADDCURRENTUSERASSQLADMIN' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    27.The setting 'TCPENABLED' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    28.The setting 'TCPENABLED' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    29.The setting 'NPENABLED' is not allowed when the value of setting 'ACTION' is 'Upgrade'.
    30.The setting 'BROWSERSVCSTARTUPTYPE' is not allowed when the value of setting 'ACTION' is 'Upgrade'.

##############################################################################################################################>

## SQL Services test function

function ss{

$ss =  "select status_desc from sys.dm_server_services where servicename = 'SQL Server (MSSQLSERVER)'"

Invoke-Sqlcmd -ServerInstance . -Query "$ss"
}


"Upgrade SQL with Minimum disruption and Risk" | Out-File G:\SQLServer2019\Log.txt


# Noting the Server disk space in all 3 AG Replicas ##
$SQLMachines = @('SQLDR01','SQLDR02','SQLDR03')
foreach($sm in $SQLMachines){ Invoke-command -ComputerName $sm -ScriptBlock {
$Disk = Get-PhysicalDisk | Out-File G:\SQLServer2019\Log.txt -Append }
}

## Taking Pre-Image of Transactional Replication Details ####
### Script out Publisher , Subscriber and Distributor using GUI ### 

Invoke-Sqlcmd -ServerInstance SQLDR01 -Database master -InputFile "G:\SQLServer2019\Monitoring Replication using Scripts.sql" |`
 Out-File G:\SQLServer2019\Log.txt -Append

#####Creating Core Media & Log files folder ######
"$time : Setting the execution Policy to enable PS SQL Server Module" | Out-File G:\SQLServer2019\Log.txt -Append 
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
"$time : Importing the PS SQL Server Module" | Out-File G:\SQLServer2019\Log.txt -Append
Import-Module -Name SQLPS -DisableNameChecking 

$SQLMachines = @('SQLDR01','SQLDR02','SQLDR03')
foreach($sm in $SQLMachines){ Invoke-command -ComputerName $sm -ScriptBlock {
$path = "G:\SQLServer2019\"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
} }}
if(Test-Path G:\SQLServer2019\InplaceUpgrade.txt) {Remove-Item -Path G:\SQLServer2019\InplaceUpgrade.txt}
Start-Transcript -Path G:\SQLServer2019\InplaceUpgrade.txt
$date = get-date 
$time = $Date.ToString("yyyyMMdd hh:mm:ss") 
"$time : Upgrade SQL with Minimum disruption and Risk"| Out-File G:\SQLServer2019\Log.txt -Append

### Identifying all Windows Cluster Hosted AG Replicas ###
"$time : Identifying all Windows Cluster Hosted AG Replicas"|`
 Out-File G:\SQLServer2019\Log.txt -Append
$serverlist = @("SQLDR01","SQLDR02","SQLDR03")
foreach($s in $serverlist){Invoke-Sqlcmd -ServerInstance $s -Query "select @@servername" |`
 Out-File G:\SQLServer2019\Log.txt -Append}

### Copying In-Place Upgrade SQL Server 2019 Media in all SQL Server 2017 Machines ###
### NOTE : Make sure G:\SQLServer2019 folder exists in all the above Server List ###

 $sourceRoot = "\\MediaServer\G$\SQLServer2019\SQLServer2019-x64-ENU"
 $destinationRoot = "G:\SQLServer2019\"

 foreach($s in $serverlist){ Invoke-Command -ComputerName $s -ScriptBlock {

 $destinationRoot = "G:\SQLServer2019\"
 If(!(test-path $destinationRoot))
{
      New-Item -ItemType Directory -Force -Path $destinationRoot
}

 Copy-Item -Path $sourceRoot -Recurse -Destination $destinationRoot -Container -Force
 $SQLMachines = @('SQLDR01','SQLDR02','SQLDR03')
foreach($sm in $SQLMachines){ Invoke-command -ComputerName $sm -ScriptBlock {
 Copy-Item -Path "\\MediaServer\G$\SQLServer2019\ConfigurationFile.ini" -Destination "G:\SQLServer2019\ConfigurationFile.ini" 
 }}}}

 foreach($s in $serverlist){ Invoke-Command -ComputerName $s -ScriptBlock {

"$time : Starting the Inplace Upgrade (SQL Server 2017 --> SQL Server 2019)" | Out-File G:\SQLServer2019\Log.txt -Append
"$time : Note:Typically SQL Server Install log is found at C:\Program Files\Microsoft SQL Server\[Version]\Setup Bootstrap\Log\[DateTimeStamp]\." |`
 Out-File G:\SQLServer2019\Log.txt -Append
 }
 }
 <#
Now the SQL Server 2019 install media is copied to all AG Replicas . 
We will connect to SQLDR03 AG Replica and Upgrade to SQL2019 # First Level of Upgrade
#>

### This dynamic management view exposes state information on both the primary and secondary replicas



"We will connect to SQLDR03 AG Replica and Upgrade to SQL2019 # First Level of Upgrade" | Out-File G:\SQLServer2019\Log.txt -Append
$AGState = "select synchronization_state_desc, 
       is_primary_replica, 
       last_sent_time, 
       last_received_time, 
       last_hardened_time, 
       last_redone_time, 
       last_commit_time
from sys.dm_hadr_database_replica_states DRS "

Invoke-Sqlcmd -ServerInstance SQLDR01 -Database master -Query $setaync | Out-File G:\SQLServer2019\Log.txt -Append
$ser = @('SQLDR01','SQLDR02','SQLDR03')
foreach($se in $ser){
Invoke-Sqlcmd -ServerInstance $se -Database master -Query "select @@servername" | Out-File G:\SQLServer2019\Log.txt -Append
Invoke-Sqlcmd -ServerInstance $se -Database master -Query "select @@version" | Out-File G:\SQLServer2019\Log.txt -Append

 #Starting the InPlace Upgrade from SQL Server 2017 --> SQL Server 2019 in SQLDR03 AG Replica

 Invoke-Command -ComputerName SQLDR03 -ScriptBlock {

 $media = "G:\SQLServer2019\SQLServer2019-x64-ENU" 
"$time : SQL Server 2019 Media is located at $media" | Out-File G:\SQLServer2019\Log.txt -Append
 $pathToConfigurationFile = "G:\SQLServer2019\ConfigurationFile.ini"
 $errorOutputFile = "G:\SQLServer2019\ErrorOutput.txt"
 $standardOutputFile = "G:\SQLServer2019\StandardOutput.txt" ## Check all the errors at the bottom of this log file 

 $user = "$env:UserDomain\$env:USERNAME"

"$time : $user" | Out-File G:\SQLServer2019\Log.txt -Append

 "$time : Starting the In-Place Upgrade of SQL Server 2017 --> SQL Server 2019 in SQLDR03" |`
  Out-File G:\SQLServer2019\Log.txt -Append
  Start-Process $media\Setup.exe "/ConfigurationFile=$pathToConfigurationFile"`
  -Wait `
  -RedirectStandardOutput $standardOutputFile `
  -RedirectStandardError  $errorOutputFile

 }


ss | select status_desc  | Out-File G:\SQLServer2019\Log.txt -Append

### Restartin the Server post upgrade ####

Restart-Computer -ComputerName SQLDR03 -Force
Start-Sleep 5

ss | select status_desc  | Out-File G:\SQLServer2019\Log.txt -Append

$status = ss | select -ExpandProperty status_desc
Invoke-Command -ComputerName SQLDR03 -ScriptBlock { if ( $status -eq 'running'){

" SQL Service on this machine is Running "}



$ser = @('SQLDR01','SQLDR02','SQLDR03')
foreach($se in $ser){
Invoke-Sqlcmd -ServerInstance $se -Database master -Query "select @@servername" | Out-File G:\SQLServer2019\Log.txt -Append
Invoke-Sqlcmd -ServerInstance $se -Database master -Query "select @@version" | Out-File G:\SQLServer2019\Log.txt -Append

ss | select status_desc  | Out-File G:\SQLServer2019\Log.txt -Append

} 


 ## Setting SQLDR02 to Asynchronous Mode ## Run the below command in Primary Replica of AG ###
 ### so that transactions on the primary can be committed without waiting for confirmation from the secondary replica ####
 try{
 $status = ss | select -ExpandProperty status_desc
Invoke-Command -ComputerName SQLDR03 -ScriptBlock { if ( $status -eq 'running'){

 "continue ....." | Out-File G:\SQLServer2019\Log.txt -Append


 "We will connect to SQLDR02 AG Replica and Upgrade to SQL2019 # Second Level of Upgrade" | Out-File G:\SQLServer2019\Log.txt -Append

 $setAsync = "USE [master]
GO
 ALTER AVAILABILITY GROUP [AOAG1]
MODIFY REPLICA ON N'SQLDR02'
WITH ( AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT ); "

Invoke-Sqlcmd -ServerInstance SQLDR01 -Database master -Query $setAsync | Out-File G:\SQLServer2019\Log.txt -Append

Start-Sleep 45
                   
<#
Now the SQL Server 2019 install media is copied to all AG Replicas . 
We will connect to SQLDR02 AG Replica and Upgrade to SQL2019 # First Level of Upgrade
#>

Invoke-Command -ComputerName SQLDR02 -ScriptBlock {

 $media = "G:\SQLServer2019\SQLServer2019-x64-ENU" 
"$time : SQL Server 2019 Media is located at $media" | Out-File G:\SQLServer2019\Log.txt -Append
 $pathToConfigurationFile = "G:\SQLServer2019\ConfigurationFile.ini"
 $errorOutputFile = "G:\SQLServer2019\ErrorOutput.txt"
 $standardOutputFile = "G:\SQLServer2019\StandardOutput.txt" ## Check all the errors at the bottom of this log file 

 $user = "$env:UserDomain\$env:USERNAME"

"$time : $user" | Out-File G:\SQLServer2019\Log.txt -Append

#Starting the InPlace Upgrade from SQL Server 2017 --> SQL Server 2019

 "$time : Starting the In-Place Upgrade of SQL Server 2017 --> SQL Server 2019" |`
  Out-File G:\SQLServer2019\Log.txt -Append
  Start-Process $media\Setup.exe "/ConfigurationFile=$pathToConfigurationFile"`
  -Wait `
  -RedirectStandardOutput $standardOutputFile `
  -RedirectStandardError  $errorOutputFile

 }
}} }Catch {"Check Errors if any" | Out-File G:\SQLServer2019\Log.txt -Append }

$status = ss | select -ExpandProperty status_desc
Invoke-Command -ComputerName SQLDR03 -ScriptBlock { if ( $status -eq 'running'){

### Restartin the Server post upgrade ####

Restart-Computer -ComputerName SQLDR02 -Force }}

Start-Sleep 30
## Setting SQLDR02 to Asynchronous Mode ## Run the below command in Primary Replica of AG ###


 $setSync = "USE [master]
 GO
 ALTER AVAILABILITY GROUP [AOAG1]
 MODIFY REPLICA ON N'SQLDR02'
 WITH ( AVAILABILITY_MODE = SYNCHRONOUS_COMMIT ); "

Invoke-Sqlcmd -ServerInstance SQLDR01 -Database master -Query $setaync


#### Failover AOAG from SQLDR01 --> SQLDR02

$AGFailoverSQLDR02 = "USE [master]
GO
 
ALTER AVAILABILITY GROUP [AOAG1] FAILOVER;
GO"

Invoke-Sqlcmd -ServerInstance SQLDR01 -Database master -Query $AGFailoverSQLDR02

Start-Sleep 45

$AGState = "select synchronization_state_desc, 
       is_primary_replica, 
       last_sent_time, 
       last_received_time, 
       last_hardened_time, 
       last_redone_time, 
       last_commit_time
from sys.dm_hadr_database_replica_states DRS "

Invoke-Sqlcmd -ServerInstance SQLDR01 -Database master -Query $setaync | Out-File G:\SQLServer2019\Log.txt -Append
$ser = @('SQLDR01','SQLDR02','SQLDR03')
foreach($se in $ser){
Invoke-Sqlcmd -ServerInstance $se -Database master -Query "select @@servername" | Out-File G:\SQLServer2019\Log.txt -Append
Invoke-Sqlcmd -ServerInstance $se -Database master -Query "select @@version" | Out-File G:\SQLServer2019\Log.txt -Append

Start-Sleep 45


try{
 Invoke-Command -ComputerName SQLDR02 -ScriptBlock { if (ss | select -ExpandProperty status_desc -eq 'running'){

 "continue ....." | Out-File G:\SQLServer2019\Log.txt -Append


 ## Setting SQLDR01 to Asynchronous Mode ## Run the below command in Primary Replica of AG ###
 ### so that transactions on the primary can be committed without waiting for confirmation from the secondary replica ####
 "We will connect to SQLDR01 AG Replica and Upgrade to SQL2019 # Second Level of Upgrade" | Out-File G:\SQLServer2019\Log.txt -Append

 $setAsync = "USE [master]
GO
 ALTER AVAILABILITY GROUP [AOAG1]
MODIFY REPLICA ON N'SQLDR01'
WITH ( AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT ); "

Invoke-Sqlcmd -ServerInstance SQLDR02 -Database master -Query $setaync | Out-File G:\SQLServer2019\Log.txt -Append

Start-Sleep 45
                   
<#
Now the SQL Server 2019 install media is copied to all AG Replicas . 
We will connect to SQLDR02 AG Replica and Upgrade to SQL2019 # First Level of Upgrade
#>

Invoke-Command -ComputerName SQLDR01 -ScriptBlock {

 $media = "G:\SQLServer2019\SQLServer2019-x64-ENU" 
"$time : SQL Server 2019 Media is located at $media" | Out-File G:\SQLServer2019\Log.txt -Append
 $pathToConfigurationFile = "G:\SQLServer2019\ConfigurationFile.ini"
 $errorOutputFile = "G:\SQLServer2019\ErrorOutput.txt"
 $standardOutputFile = "G:\SQLServer2019\StandardOutput.txt" ## Check all the errors at the bottom of this log file 

 $user = "$env:UserDomain\$env:USERNAME"

"$time : $user" | Out-File G:\SQLServer2019\Log.txt -Append

#Starting the InPlace Upgrade from SQL Server 2017 --> SQL Server 2019

 "$time : Starting the In-Place Upgrade of SQL Server 2017 --> SQL Server 2019" |`
  Out-File G:\SQLServer2019\Log.txt -Append
  Start-Process $media\Setup.exe "/ConfigurationFile=$pathToConfigurationFile"`
  -Wait `
  -RedirectStandardOutput $standardOutputFile `
  -RedirectStandardError  $errorOutputFile

 }
}}}Catch {"Check Errors if any" | Out-File G:\SQLServer2019\Log.txt -Append }

Start-Sleep 60

### Restartin the Server post upgrade ####

Restart-Computer -ComputerName SQLDR01 -Force


<# In Place upgrade of Transaction Replication Distribution Server to SQL Server 2019 after  #>

 $sourceRoot = "\\MediaServer\G$\SQLServer2019\SQLServer2019-x64-ENU"
 $destinationRoot = "G:\SQLServer2019\"
Invoke-Command -ComputerName $s -ScriptBlock {

 $destinationRoot = "G:\SQLServer2019\"
 If(!(test-path $destinationRoot))
{
      New-Item -ItemType Directory -Force -Path $destinationRoot
}

 Copy-Item -Path $sourceRoot -Recurse -Destination $destinationRoot -Container -Force
 $SQLMachines = @('SQLDR01','SQLDR02','SQLDR03')
foreach($sm in $SQLMachines){ Invoke-command -ComputerName $sm -ScriptBlock {
 Copy-Item -Path "\\MediaServer\G$\SQLServer2019\ConfigurationFile.ini" -Destination "G:\SQLServer2019\ConfigurationFile.ini" 
 }}}

Invoke-Command -ComputerName SQLDRDISTRIBUTION -ScriptBlock {

 $media = "G:\SQLServer2019\SQLServer2019-x64-ENU" 
"$time : SQL Server 2019 Media is located at $media" | Out-File G:\SQLServer2019\Log.txt -Append
 $pathToConfigurationFile = "G:\SQLServer2019\ConfigurationFile.ini"
 $errorOutputFile = "G:\SQLServer2019\ErrorOutput.txt"
 $standardOutputFile = "G:\SQLServer2019\StandardOutput.txt" ## Check all the errors at the bottom of this log file 

 $user = "$env:UserDomain\$env:USERNAME"

"$time : $user" | Out-File G:\SQLServer2019\Log.txt -Append

#Starting the InPlace Upgrade from SQL Server 2017 --> SQL Server 2019

 "$time : Starting the In-Place Upgrade of SQL Server 2017 --> SQL Server 2019" |`
  Out-File G:\SQLServer2019\Log.txt -Append
  Start-Process $media\Setup.exe "/ConfigurationFile=$pathToConfigurationFile"`
  -Wait `
  -RedirectStandardOutput $standardOutputFile `
  -RedirectStandardError  $errorOutputFile

 }
}}Catch {"Check Errors if any" | Out-File G:\SQLServer2019\Log.txt -Append }


$status = ss | select -ExpandProperty status_desc -eq 'running'
if ($status -eq 'running'){

### Restartin the Server post upgrade ####

Restart-Computer -ComputerName SQLDR01 -Force }



## Setting SQLDR01 to Synchronous Mode ## Run the below command in Primary Replica of AG ###


 $setSync = "USE [master]
 GO
 ALTER AVAILABILITY GROUP [AOAG1]
 MODIFY REPLICA ON N'SQLDR01'
 WITH ( AVAILABILITY_MODE = SYNCHRONOUS_COMMIT ); "

Invoke-Sqlcmd -ServerInstance SQLDR02 -Database master -Query $setaync

Start-Sleep 45

#### Failover AOAG from SQLDR02 --> SQLDR01

$AGFailoverSQLDR01 = "USE [master]
GO
 
ALTER AVAILABILITY GROUP [AOAG1] FAILOVER;
GO"

Invoke-Sqlcmd -ServerInstance SQLDR02 -Database master -Query $AGFailoverSQLDR01

Start-Sleep 45

$AGState = "select synchronization_state_desc, 
       is_primary_replica, 
       last_sent_time, 
       last_received_time, 
       last_hardened_time, 
       last_redone_time, 
       last_commit_time
from sys.dm_hadr_database_replica_states DRS "

Invoke-Sqlcmd -ServerInstance SQLDR01 -Database master -Query $setaync | Out-File G:\SQLServer2019\Log.txt -Append

$ser = @('SQLDR01','SQLDR02','SQLDR03')
foreach($se in $ser){
Invoke-Sqlcmd -ServerInstance $se -Database master -Query "select @@servername" | Out-File G:\SQLServer2019\Log.txt -Append
Invoke-Sqlcmd -ServerInstance $se -Database master -Query "select @@version" | Out-File G:\SQLServer2019\Log.txt -Append
}

Start-Sleep 45



####
$ser = @('SQLDR01','SQLDR02','SQLDR03')
foreach($se in $ser){
$Databases = Invoke-Sqlcmd -ServerInstance "." -query "select name from sys.databases where name like 'AOAG_DBs%'" |`
 select -ExpandProperty name | Out-File G:\SQLServer2019\Log.txt -Append
$dbresume = "ALTER DATABASE $dbs SET HADR RESUME;"
foreach($dbs in $Databases ){Invoke-Sqlcmd -ServerInstance $se -Database master -Query $dbresume 
 }
} 

#### Failback AOAG from SQLDR02 --> SQLDR01

$AGFailoverSQLDR01 = "USE [master]
GO
 
ALTER AVAILABILITY GROUP [AOAG1] FAILOVER;
GO"

Invoke-Sqlcmd -ServerInstance SQLDR02 -Database master -Query $AGFailoverSQLDR01

Start-Sleep 45 

$AGState = "select synchronization_state_desc, 
       is_primary_replica, 
       last_sent_time, 
       last_received_time, 
       last_hardened_time, 
       last_redone_time, 
       last_commit_time
from sys.dm_hadr_database_replica_states DRS "

Invoke-Sqlcmd -ServerInstance SQLDR01 -Database master -Query $AGState | Out-File G:\SQLServer2019\Log.txt -Append

$ser = @('SQLDR01','SQLDR02','SQLDR03')
foreach($se in $ser){
Invoke-Sqlcmd -ServerInstance $se -Database master -Query "select @@servername" | Out-File G:\SQLServer2019\Log.txt -Append
Invoke-Sqlcmd -ServerInstance $se -Database master -Query "select @@version" | Out-File G:\SQLServer2019\Log.txt -Append
}

<# Monitoring Transactional Replication after successful SQL Server 2019 upgrade #>

Invoke-Sqlcmd -ServerInstance SQLDR01 -Database master -Query "

DECLARE @srvname VARCHAR(100)
DECLARE @pub_db VARCHAR(100)
DECLARE @pubname VARCHAR(100)
CREATE TABLE #replmonitor(status    INT NULL,warning    INT NULL,subscriber    sysname NULL,subscriber_db    sysname NULL,publisher_db    sysname NULL,
publication    sysname NULL,publication_type    INT NULL,subtype    INT NULL,latency    INT NULL,latencythreshold    INT NULL,agentnotrunning    INT NULL,
agentnotrunningthreshold    INT NULL,timetoexpiration    INT NULL,expirationthreshold    INT NULL,last_distsync    DATETIME,
distribution_agentname    sysname NULL,mergeagentname    sysname NULL,mergesubscriptionfriendlyname    sysname NULL,mergeagentlocation    sysname NULL,
mergeconnectiontype    INT NULL,mergePerformance    INT NULL,mergerunspeed    FLOAT,mergerunduration    INT NULL,monitorranking    INT NULL,
distributionagentjobid    BINARY(16),mergeagentjobid    BINARY(16),distributionagentid    INT NULL,distributionagentprofileid    INT NULL,
mergeagentid    INT NULL,mergeagentprofileid    INT NULL,logreaderagentname VARCHAR(100))
DECLARE replmonitor CURSOR FOR
SELECT b.srvname,a.publisher_db,a.publication
FROM distribution.dbo.MSpublications a,  master.dbo.sysservers b
WHERE a.publisher_id=b.srvid
OPEN replmonitor 
FETCH NEXT FROM replmonitor INTO @srvname,@pub_db,@pubname
WHILE @@FETCH_STATUS = 0
BEGIN
INSERT INTO #replmonitor
EXEC distribution.dbo.sp_replmonitorhelpsubscription  @publisher = @srvname
     , @publisher_db = @pub_db
     ,  @publication = @pubname
     , @publication_type = 0
FETCH NEXT FROM replmonitor INTO @srvname,@pub_db,@pubname
END
CLOSE replmonitor
DEALLOCATE replmonitor
 
SELECT publication,publisher_db,subscriber,subscriber_db,
        CASE publication_type WHEN 0 THEN 'Transactional publication'
            WHEN 1 THEN 'Snapshot publication'
            WHEN 2 THEN 'Merge publication'
            ELSE 'Not Known' END,
        CASE subtype WHEN 0 THEN 'Push'
            WHEN 1 THEN 'Pull'
            WHEN 2 THEN 'Anonymous'
            ELSE 'Not Known' END,
        CASE status WHEN 1 THEN 'Started'
            WHEN 2 THEN 'Succeeded'
            WHEN 3 THEN 'In progress'
            WHEN 4 THEN 'Idle'
            WHEN 5 THEN 'Retrying'
            WHEN 6 THEN 'Failed'
            ELSE 'Not Known' END,
        CASE warning WHEN 0 THEN 'No Issues in Replication' ELSE 'Check Replication' END,
        latency, latencythreshold, 
        'LatencyStatus'= CASE WHEN (latency > latencythreshold) THEN 'High Latency'
        ELSE 'No Latency' END,
        distribution_agentname,'DistributorStatus'= CASE WHEN (DATEDIFF(hh,last_distsync,GETDATE())>1) THEN 'Distributor has not executed more than n hour'
        ELSE 'Distributor running fine' END
        FROM #replmonitor
DROP TABLE #replmonitor

" |Export-Csv G:\SQLServer2019\Log.csv 

"This completed the In Place of SQL Server 2017 Server's with AOAG to SQL Server 2019 Successfully " | Out-File G:\SQLServer2019\Log.txt -Append
"For more details / Logs please check the log files at C:\Program Files\Microsoft SQL Server\150\Setup Bootstrap\Log : " | Out-File G:\SQLServer2019\Log.txt -Append



 

