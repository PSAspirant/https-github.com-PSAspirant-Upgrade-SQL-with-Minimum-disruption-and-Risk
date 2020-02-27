# https-github.com-PSAspirant-Upgrade-SQL-with-Minimum-disruption-and-Risk

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
    
    
    
    
####### SQL Server 2017 to SQL Server 2019 upgrade ########

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

