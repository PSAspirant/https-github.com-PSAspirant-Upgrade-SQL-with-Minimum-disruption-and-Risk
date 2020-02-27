########################################################################
##############  Cluster operating system rolling upgrade (Windows Server 2012 R2 --> Windows Server 2016) ###############
######################################################################## 

<# Cluster OS Rolling Upgrade provides the following benefits:

1. Failover clusters running Hyper-V virtual machine and Scale-out File Server (SOFS) workloads can be upgraded from Windows Server 2012 R2 (running on all nodes in the cluster) to Windows Server 2016 (running on all cluster nodes of the cluster) without downtime. 
2. Other cluster workloads, such as SQL Server, will be unavailable during the time (typically less than five minutes) it takes to failover to Windows Server 2016.
3. It doesn't require any additional hardware. Although, you can add additional cluster nodes temporarily to small clusters to improve availability of the cluster during the Cluster OS Rolling Upgrade process.
4. The cluster doesn't need to be stopped or restarted.
5. A new cluster is not required. The existing cluster is upgraded. In addition, existing cluster objects stored in Active Directory are used.
6. The upgrade process is reversible until the customer choses the "point-of-no-return", when all cluster nodes are running Windows Server 2016, and when the Update-ClusterFunctionalLevel PowerShell cmdlet is run.
7. The cluster can support patching and maintenance operations while running in the mixed-OS mode.
8. It supports automation via PowerShell and WMI.  #>

<# Requirements : Complete the following requirements before you begin the Cluster OS Rolling Upgrade process:

1. Start with a Failover Cluster running Windows Server, Windows Server 2016, or Windows Server 2012 R2.
2. If the cluster workload is Hyper-V VMs, or Scale-Out File Server, you can expect zero-downtime upgrade.
3. Verify that the Hyper-V nodes have CPUs that support Second-Level Addressing Table (SLAT) #>

##### Perform Windows Server 2012 R2 In-Place Upgrade #####

#### In-place upgrade paths to Windows Server 2016 ####

<#---------------------------------------
||Current Server - Windows Server 2012 R2
  Upgrade To     - Windows Server 2016 ||
 ---------------------------------------#>

 # Windows Server 2016 Install Options

    #Cluster OS Rolling Upgrade requires removing one node at a time from the cluster.
    #Check that any workload backups have completed, and consider backing-up the cluster.
    #Check that all cluster nodes are online /running/up using the Get-ClusterNode cmdlet .


 ##########################################################################################
 #                                                                                        #
 ################################ SQLPROD03 In-Place Upgrade ##############################
 #                                                                                        #
 ##########################################################################################

 $TimeStamp1 = (Get-date -Format dd-MM-yyyy) + "|" + (get-date -format HHMMsstt) 
 $logfile1 = "G:\WinServer_2016_$TimeStamp1.txt"
 $logfile1

 Start-Transcript -Path $logfile1


 $serverlist = @('SQLPROD01','SQLPROD02','SQLPROD03')
 foreach($s in $serverlist){

 Get-WmiObject Win32_OperatingSystem | Select-Object LastBootUpTime | Out-File -FilePath $logfile 
 Invoke-Sqlcmd -ServerInstance $s -Query "select sqlserver_start_time from sys.dm_os_sys_info " | Out-File -FilePath $logfile 

 }

 
    # Copying Windows Server 2016 Silent Install Media from shared location to Servers

    $servers = @('SQLPROD01','SQLPROD02','SQLPROD03')
    foreach($s in $servers){
    
    $path = "G:\WinServer_2016\"
    If(!(test-path $path))
   {
      New-Item -ItemType Directory -Force -Path $path
   }

   Copy-Item -Path "\\source\SW_DVD_Win_Server_2016.ISO" -Destination G:\WinServer_2016\
   
   Copy-Item -Path "\\source\unattend.xml" -Destination G:\WinServer_2016\

   Get-ChildItem -Path G:\WinServer_2016\ -Recurse -Force | Out-File -FilePath $logfile -Append
    
    }

 
Try {
Invoke-Command -ComputerName SQLPROD03 -ScriptBlock {

 $TimeStamp = (Get-date -Format dd-MM-yyyy) + "|" + (get-date -format HHMMsstt) 
 $logfile = "G:\WinServer_2016_$TimeStamp.txt"
 $logfile


     #Determining node status using Get-ClusterNode cmdlet
    Import-Module FailoverClusters -Force
    
    Get-clusternode | Out-File -FilePath $logfile -Append 

    #Drain Cluster Roles

    Suspend-ClusterNode -Name "SQLPROD03"  | Out-File -FilePath $logfile -Append 

    Start-Sleep 30

    #Evict the Paused Node from Cluster 

    Remove-ClusterNode -Name "SQLPROD03" | Out-File -FilePath $logfile -Append 

    Start-Sleep 60

    } 
    } catch { $_ | Out-File -FilePath $logfile -Append } 



    <## Reformat the system drive and perform a "clean operating system install" of Windows Server 2016 on the node using the Upgrade: 
    Install Windows only (advanced) installation  option in setup.exe. #>


Try {
Invoke-Command -ComputerName SQLPROD03 -ScriptBlock {

$path = "G:\WinServer_2016\"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path | Out-File -FilePath $logfile -Append 
}

$unattend = "G:\WinServer_2016\\unattend.xml"

$mount = Mount-DiskImage -ImagePath ("G:\WinServer_2016\SW_DVD_Win_Server_2016.ISO") -PassThru
$driveLetter = ($mount | Get-Volume).DriveLetter

$setup = $driveLetter + “:\setup.exe”
$param = “/Auto:Upgrade /Unattend:$unattend /DynamicUpdate Disable”

Start-Process -FilePath $setup -WorkingDirectory ($driveLetter + “:\”) -ArgumentList $param | Out-File -FilePath $logfile -Append 

###Using the Server Manager UI or Install-WindowsFeature PowerShell cmdlet, install the Failover Clustering feature.

}

Start-Sleep 60

Install-WindowsFeature -Name Failover-Clustering  

##Install any additional features needed by your cluster workloads.

##Check network and storage connectivity settings using the Failover Cluster Manager UI.

##If Windows Firewall is used, check that the Firewall settings are correct for the cluster.
## For example, Cluster Aware Updating (CAU) enabled clusters may require Firewall configuration.

###On a Windows Server 2016 node (do not use a Windows Server 2012 R2 node), use the Failover Cluster Manager to connect to the cluster.

Get-Cluster -Name WinClu2016 | Out-File -FilePath $logfile -Append

Start-Sleep 60

#Adding a node to the cluster using Failover Cluster Manager

Add-ClusterNode -Name SQLPROD03 -Cluster WinClu2016 | Out-File -FilePath $logfile -Append


<# Note :  When the first Windows Server 2016 node joins the cluster, 
the cluster enters "Mixed-OS" mode, and the cluster core resources are moved to the Windows Server 2016 node. 
A "Mixed-OS" mode cluster is a fully functional cluster where the new nodes run in a compatibility mode with the old nodes.
 "Mixed-OS" mode is a transitory mode for the cluster. #>

 ##Check that all cluster roles are running on the cluster as expected.

 Get-ClusterGroup | Out-File -FilePath $logfile -Append

## Check that all cluster nodes are online and running

 Get-ClusterNode | Out-File -FilePath $logfile -Append

 } catch {"Please lookout for the error messages happened during the In Place upgrade" | Out-File -FilePath $logfile -Append }

 ##########################################################################################
 #                                                                                        #
 ################################ SQLPROD02 In-Place Upgrade ##############################
 #                                                                                        #
 ##########################################################################################

 #Determining node status using Get-ClusterNode cmdlet


 Try {
Invoke-Command -ComputerName SQLPROD02 -ScriptBlock {

 $TimeStamp = (Get-date -Format dd-MM-yyyy) + "|" + (get-date -format HHMMsstt) 
 $logfile = "G:\WinServer_2016_$TimeStamp.txt"
 $logfile
    Import-Module FailoverClusters -Force
    
    Get-clusternode | Out-File -FilePath $logfile -Append

    #Drain Cluster Roles

    Suspend-ClusterNode -Name "SQLPROD02"  | Out-File -FilePath $logfile -Append

    Start-Sleep 30

    #Evict the Paused Node from Cluster 

    Remove-ClusterNode -Name "SQLPROD02" | Out-File -FilePath $logfile -Append

    Start-Sleep 60

    <## Reformat the system drive and perform a "clean operating system install" of Windows Server 2016 on the node using the Upgrade: 
    Install Windows only (advanced) installation  option in setup.exe. #>

    Invoke-Command -ComputerName SQLPROD02 -ScriptBlock {

$path = "G:\WinServer_2016\"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

$unattend = "G:\WinServer_2016\unattend.xml"

$mount = Mount-DiskImage -ImagePath ("G:\WinServer_2016\SW_DVD_Win_Server_2016.ISO") -PassThru
$driveLetter = ($mount | Get-Volume).DriveLetter

$setup = $driveLetter + “:\setup.exe”
$param = “/Auto:Upgrade /Unattend:$unattend /DynamicUpdate Disable”

Start-Process -FilePath $setup -WorkingDirectory ($driveLetter + “:\”) -ArgumentList $param | Out-File -FilePath $logfile -Append

###Using the Server Manager UI or Install-WindowsFeature PowerShell cmdlet, install the Failover Clustering feature.

}

Start-Sleep 60

Install-WindowsFeature -Name Failover-Clustering 
 }
}
catch {"Please lookout for the error messages happened during the In Place upgrade" | Out-File -FilePath $logfile -Append }


 ##########################################################################################
 #                                                                                        #
 ################################ SQLPROD01 In-Place Upgrade ##############################
 #                                                                                        #
 ##########################################################################################

 #Determining node status using Get-ClusterNode cmdlet
 Try {
Invoke-Command -ComputerName SQLPROD01 -ScriptBlock {

 $TimeStamp = (Get-date -Format dd-MM-yyyy) + "|" + (get-date -format HHMMsstt) 
 $logfile = "G:\WinServer_2016_$TimeStamp.txt"
 $logfile

    Import-Module FailoverClusters -Force | Out-File -FilePath $logfile -Append
    
    Get-clusternode 

    #Drain Cluster Roles

    Suspend-ClusterNode -Name "SQLPROD01" | Out-File -FilePath $logfile -Append

    Start-Sleep 30

    #Evict the Paused Node from Cluster 

    Remove-ClusterNode -Name "SQLPROD01" | Out-File -FilePath $logfile -Append

    Start-Sleep 60

    <## Reformat the system drive and perform a "clean operating system install" of Windows Server 2016 on the node using the Upgrade: 
    Install Windows only (advanced) installation  option in setup.exe. #>

    Invoke-Command -ComputerName SQLPROD01 -ScriptBlock {

$path = "G:\WinServer_2016\"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

$unattend = "G:\WinServer_2016\\unattend.xml"

$mount = Mount-DiskImage -ImagePath ("G:\WinServer_2016\SW_DVD_Win_Server_2016.ISO") -PassThru
$driveLetter = ($mount | Get-Volume).DriveLetter
$setup = $driveLetter + “:\setup.exe”
$param = “/Auto:Upgrade /Unattend:$unattend /DynamicUpdate Disable”

Start-Process -FilePath $setup -WorkingDirectory ($driveLetter + “:\”) -ArgumentList $param | Out-File -FilePath $logfile -Append

###Using the Server Manager UI or Install-WindowsFeature PowerShell cmdlet, install the Failover Clustering feature.

}

Start-Sleep 60

Install-WindowsFeature -Name Failover-Clustering 

<# IMPORTANT NOTE : When every node has been upgraded to Windows Server 2016 and added back to the cluster, or when any remaining Windows Server 2012 R2 nodes have been evicted, do the following:

 1. After you update the cluster functional level, you cannot go back to Windows Server 2012 R2 functional level and Windows Server 2012 R2 nodes cannot be added to the cluster.
 2. Until the Update-ClusterFunctionalLevel cmdlet is run, the process is fully reversible and Windows Server 2012 R2 nodes can be added to this cluster and Windows Server 2016 nodes can be removed.
 3. After the Update-ClusterFunctionalLevel cmdlet is run, new features will be available. #>

 ### Check that all cluster nodes are online and running :
 
 Get-ClusterNode 

 } 
 }catch {"Please lookout for the error messages happened during the In Place upgrade of SQLPROD01" | Out-File -FilePath $logfile -Append }

 #Updating the functional level of a cluster 

 $server = @('SQLPROD01','SQLPROD02','SQLPROD03')
 foreach($s in $server){
 
 Get-Cluster | select ClusterFunctionalLevel | Out-File -FilePath $logfile -Append
 Start-Sleep 5
 Invoke-Command -ComputerName $s -ScriptBlock { Update-ClusterFunctionalLevel -Force  | Out-File -FilePath $logfile -Append }
 
  
 }

 ###After the Update-ClusterFunctionalLevel cmdlet is run, new features are available.

###Windows Server 2016 - resume normal cluster updates 

#Testing SQL Server AOAG Health status

Get-ChildItem SQLSERVER:\Sql\Computer\Instance\AvailabilityGroups | Test-SqlAvailabilityGroup | Where-Object { $_.HealthState -eq "Error" }

## To get  the synchronization state of the availability group databases for the Cluster

# NOTE: Please change the Server name and AOAGname below code.

[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
$SqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server("SQLPROD01")
$SqlServer.AvailabilityGroups["AvailabilityGroupsName"].DatabaseReplicaStates | Select-Object AvailabilityReplicaServerName, AvailabilityDatabaseName, SynchronizationState | Out-File -FilePath $logfile -Append

 #####################################################################################################################################
 #                                                                                                                                   #
 ################################ Distribution Server In-Place Upgrade (Transactional Replication Case) ##############################
 #                                                                                                                                   #
 #####################################################################################################################################

 #Determining node status using Get-ClusterNode cmdlet
 Try {
Invoke-Command -ComputerName SQLPRODDIST -ScriptBlock {

 $TimeStamp = (Get-date -Format dd-MM-yyyy) + "|" + (get-date -format HHMMsstt) 
 $logfile = "G:\WinServer_2016_$TimeStamp.txt"
 $logfile

 
    Start-Sleep 60

    <## Reformat the system drive and perform a "clean operating system install" of Windows Server 2016 on the node using the Upgrade: 
    Install Windows only (advanced) installation  option in setup.exe. #>

    Invoke-Command -ComputerName SQLPROD01 -ScriptBlock {

$path = "G:\WinServer_2016\"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

$unattend = "G:\WinServer_2016\\unattend.xml"

$mount = Mount-DiskImage -ImagePath ("G:\WinServer_2016\SW_DVD_Win_Server_2016.ISO") -PassThru
$driveLetter = ($mount | Get-Volume).DriveLetter
$setup = $driveLetter + “:\setup.exe”
$param = “/Auto:Upgrade /Unattend:$unattend /DynamicUpdate Disable”

Start-Process -FilePath $setup -WorkingDirectory ($driveLetter + “:\”) -ArgumentList $param | Out-File -FilePath $logfile -Append

}

Start-Sleep 60


 } 
 }catch {"Please lookout for the error messages happened during the In Place upgrade of SQLPRODDIST" | Out-File -FilePath $logfile -Append }

 #Updating the functional level of a cluster 

 $server = @('SQLPROD01','SQLPROD02','SQLPROD03')
 foreach($s in $server){
 
 Get-Cluster | select ClusterFunctionalLevel | Out-File -FilePath $logfile -Append
 Start-Sleep 5
 Invoke-Command -ComputerName $s -ScriptBlock { Update-ClusterFunctionalLevel -Force  | Out-File -FilePath $logfile -Append }
 
  
 }

 ###After the Update-ClusterFunctionalLevel cmdlet is run, new features are available.

###Windows Server 2016 - resume normal cluster updates 

#Testing SQL Server AOAG Health status

Get-ChildItem SQLSERVER:\Sql\Computer\Instance\AvailabilityGroups | Test-SqlAvailabilityGroup | Where-Object { $_.HealthState -eq "Error" }

## To get  the synchronization state of the availability group databases for the Cluster

# NOTE: Please change the Server name and AOAGname below code.

[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
$SqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server("SQLPROD01")
$SqlServer.AvailabilityGroups["AvailabilityGroupsName"].DatabaseReplicaStates | Select-Object AvailabilityReplicaServerName, AvailabilityDatabaseName, SynchronizationState | Out-File -FilePath $logfile -Append


## Finally Restarting the Cluster Nodes and getting ready for SQL Server upgrade from 2017 to 2019

 ########################################################################
#
# 
#
# <Usage>			Temp_Restart_EMS4Servers.ps1
# <Usage example>	Temp_Restart_EMS4Servers.ps1
# <History> 
#      2018/09/14     First Release.
#
########################################################################

#Logsettings
#Get sctipt run dat
$Date = Get-Date -Format "yyyyMMdd"
$Location = "Envir"

#Get current folder path
$Current_Folder = (Get-Location).Path

#Set log folder
$log_Folder = "log"
$log_Folderpath = $Current_Folder + "\" + $log_folder
IF(Test-Path $log_Folder){}else{New-Item $log_Folderpath -ItemType d}

$log_File = "After_Update_Reboot_" + $Location + "_" + $date + ".log"
$log_Filepath = $log_Folderpath + "\" + $log_File

# DBServerlist
$AGsrvarray_DB = @(
	"SQLDR01",
	"SQLDR02",
	"SQLDR03"
)

# DBServerlist
$Winsrvarray_DB = @(
	"SQLPROD01",
	"SQLPROD02",
	"SQLPROD03"
)


#AGInformation
$AG = "SQL2017_AG"
$AGLSN = "ListenerName"

# SQL Query
$Q_AGStatus = "
SELECT  node_name as ServerName, 
       group_name as AGName, 
       role_desc as Replica_Role , 
       dns_name as AOAG_Listener ,
ip_address as AGListener_IP,
(SELECT cluster_name FROM   sys.dm_hadr_cluster) as Cluster,
synchronization_health_desc as Replica_Health , availability_mode_desc AS Sync_Mode
FROM   sys.dm_hadr_availability_replica_cluster_nodes 
       LEFT JOIN sys.dm_hadr_availability_replica_cluster_states 
              ON 
       sys.dm_hadr_availability_replica_cluster_nodes.replica_server_name = 
       sys.dm_hadr_availability_replica_cluster_states.replica_server_name 
       INNER JOIN sys.dm_hadr_availability_replica_states 
               ON sys.dm_hadr_availability_replica_cluster_states.replica_id = 
                  sys.dm_hadr_availability_replica_states.replica_id  
inner join sys.availability_group_listeners  
on sys.availability_group_listeners.group_id = sys.dm_hadr_availability_replica_states.group_id
Inner join sys.availability_replicas  ON sys.dm_hadr_availability_replica_cluster_nodes.replica_server_name  = sys.availability_replicas.replica_server_name
inner join sys.availability_group_listener_ip_addresses ON sys.availability_group_listener_ip_addresses.listener_id = sys.availability_group_listeners.listener_id 
where state_desc = 'ONLINE'
" 
$Q_FailOver = "ALTER AVAILABILITY GROUP [" + $AG + "] FAILOVER"


#######################################################################
# DB Servers Restarts while checking the Failover Part of AG Replicas #
#######################################################################


$WkLogTimeMsg = Get-Date -format yyyy/MM/dd-HH:mm:ss
$msg = "Restarting DB Servers:" + $WkLogTimeMsg
Write-Output $msg | Out-File $log_Filepath -Append -Encoding UTF8


Foreach($srvname in $srvarray_DB){

$SQL_FCHK = 0
Do{
	$SQL_Role_Status = Invoke-Command -ComputerName $AGLSN -ScriptBlock{Invoke-Sqlcmd -Query $Using:Q_AGStatus}
	$SQL_Role_CHK = ($SQL_Role_Status | Where-Object{($_.ServerName -eq $srvname)}).Replica_Role
		IF($SQL_Role_CHK -eq "PRIMARY"){
            $WkLogTimeMsg = Get-Date -format yyyy/MM/dd-HH:mm:ss
            $msg = "Current AOAG Status is bellow:" + $WkLogTimeMsg
            Write-Output $msg | Out-File $log_Filepath -Append -Encoding UTF8
            $SQL_Role_Status | Select-Object ServerName,AGName,Replica_Role,Replica_Health,Sync_Mode| ft -AutoSize | Out-File $log_Filepath -Append -Encoding UTF8 
            $SQL_SECONDARY_Replica = ($SQL_Role_Status | Where-Object{($_.Replica_Role -eq "SECONDARY") -and ($_.Sync_Mode -eq "SYNCHRONOUS_COMMIT")}).ServerName
			$WkLogTimeMsg = Get-Date -format yyyy/MM/dd-HH:mm:ss
			$msg = $srvname + " is Primary Replica need FailOver:" + $WkLogTimeMsg
			Write-Output $msg | Out-File $log_Filepath -Append -Encoding UTF8
			
	        	Invoke-Command -ComputerName $SQL_SECONDARY_Replica -ScriptBlock{
				Invoke-Sqlcmd -Query $Using:Q_FailOver 
				Start-Sleep -Seconds 60
			                                                                    }
	
		}elseIF($SQL_Role_CHK -eq "SECONDARY"){
			$SQL_FCHK = 1
            $WkLogTimeMsg = Get-Date -format yyyy/MM/dd-HH:mm:ss
            $msg = "Current AOAG Status is bellow:" + $WkLogTimeMsg
            Write-Output $msg | Out-File $log_Filepath -Append -Encoding UTF8
            $SQL_Role_Status | Select-Object ServerName,AGName,Replica_Role,Replica_Health,Sync_Mode| ft -AutoSize | Out-File $log_Filepath -Append -Encoding UTF8 
			$WkLogTimeMsg = Get-Date -format yyyy/MM/dd-HH:mm:ss
			$msg = $srvname + " is Secondary Replica will restart" + $WkLogTimeMsg
			Write-Output $msg | Out-File $log_Filepath -Append -Encoding UTF8
			
		}
} 
Until ($SQL_FCHK -eq 1)

foreach($winsrv in $Winsrvarray_DB){

	# Restart Server
	$WkLogTimeMsg = Get-Date -format yyyy/MM/dd-HH:mm:ss
	$msg = $srvname + " will restart:" + $WkLogTimeMsg
	Write-Output $msg | Out-File $log_Filepath -Append -Encoding UTF8
	Restart-Computer -ComputerName $Winsrv -force -wait -Protocol WSMan
}

    # Verify Service
    $SQL_CHK = 0
    $SQL_Run_CHK = $empty

     Do{
	    $SQL_Run_Status = Invoke-Command -ComputerName $srvname -ScriptBlock{gwmi -Class WIn32_Service | Where-Object{($_.Name -like "*SQL*") -and ($_.StartMode -eq "Auto")}}
        $SQL_Role_Status = Invoke-Command -ComputerName $AGLSN -ScriptBlock{Invoke-Sqlcmd -Query $Using:Q_AGStatus}
        $SQL_Run_CHK = $SQL_Run_Status | Where-Object{($_.State -ne "Running")}
        $SQL_Role_CHK = $SQL_Role_Status | Where-Object{$_.Replica_Health -ne "HEALTHY"}
        $WkLogTimeMsg = Get-Date -format yyyy/MM/dd-HH:mm:ss
        $msg = $srvname + " Verify SQLService and Role State:" + $WkLogTimeMsg
        Write-Output $msg | Out-File $log_Filepath -Append -Encoding UTF8		
        $SQL_Run_Status | ft -AutoSize | Out-File $log_Filepath -Append -Encoding UTF8
	    IF([string]::IsNullOrEmpty($SQL_Run_CHK) -or [string]::IsNullOrEmpty($SQL_Role_CHK)){
		    $SQL_CHK = 1
		    $WkLogTimeMsg = Get-Date -format yyyy/MM/dd-HH:mm:ss
		    $msg = $srvname + " Complete Verify SQLService and Role State:" + $WkLogTimeMsg
		    Write-Output $msg | Out-File $log_Filepath -Append -Encoding UTF8
	    }else{
		    start-sleep 180
	        $SQL_Run_Status = Invoke-Command -ComputerName $srvname -ScriptBlock{gwmi -Class WIn32_Service | Where-Object{($_.Name -like "*SQL*") -and ($_.StartMode -eq "Auto")}}
            $SQL_Role_Status = Invoke-Command -ComputerName $AGLSN -ScriptBlock{Invoke-Sqlcmd -Query $Using:Q_AGStatus}
            $SQL_Run_CHK = $SQL_Run_Status | Where-Object{($_.State -ne "Running")}
            $SQL_Role_CHK = $SQL_Role_Status | Where-Object{$_.Replica_Health -ne "HEALTHY"}
    	    IF([string]::IsNullOrEmpty($SQL_Run_CHK) -or [string]::IsNullOrEmpty($SQL_Role_CHK)){
            }else{
		        $WkLogTimeMsg = Get-Date -format yyyy/MM/dd-HH:mm:ss
		        $msg = $srvname + " Starting stopeed SQLService:" + $WkLogTimeMsg
		        Write-Output $msg | Out-File $log_Filepath -Append -Encoding UTF8
                $SQL_Run_CHK | ft -AutoSize | Out-File $log_Filepath -Append -Encoding UTF8
                Invoke-Command -ComputerName $srvname -ScriptBlock{(gwmi -Class WIn32_Service | Where-Object{($_.Name -like "*SQL*") -and ($_.StartMode -eq "Auto")-and ($_.state -eq "Stopped")}).StartService()}
                 }
	    }
    } 
    Until ($SQL_CHK -eq 1)
    $WkLogTimeMsg = Get-Date -format yyyy/MM/dd-HH:mm:ss
    $msg = "Current SQL Service and AOAG Status is bellow:" + $WkLogTimeMsg
    Write-Output $msg | Out-File $log_Filepath -Append -Encoding UTF8
    $SQL_Run_Status | ft -AutoSize | Out-File $log_Filepath -Append -Encoding UTF8
	$SQL_Role_Status | Select-Object ServerName,AGName,Replica_Role,Replica_Health,Sync_Mode| ft -AutoSize | Out-File $log_Filepath -Append -Encoding UTF8
    $WkLogTimeMsg = Get-Date -format yyyy/MM/dd-HH:mm:ss
	$msg = $srvname + " Complete Restart and Verify SQLService State Next step" + $WkLogTimeMsg
    Write-Output $msg | Out-File $log_Filepath -Append -Encoding UTF8
}

$SQL_Role_Status = Invoke-Command -ComputerName $AGLSN -ScriptBlock{Invoke-Sqlcmd -Query $Using:Q_AGStatus}
$msg = "Current AOAG Status is bellow:" + $WkLogTimeMsg
Write-Output $msg | Out-File $log_Filepath -Append -Encoding UTF8
$SQL_Role_Status | Select-Object ServerName,AGName,Replica_Role,Replica_Health,Sync_Mode| ft -AutoSize | Out-File $log_Filepath -Append -Encoding UTF8
$WkLogTimeMsg = Get-Date -format yyyy/MM/dd-HH:mm:ss
$msg = "Complete Restarted All Servers:" + $WkLogTimeMsg
Write-Output $msg | Out-File $log_Filepath -Append -Encoding UTF8


Stop-Transcript 



