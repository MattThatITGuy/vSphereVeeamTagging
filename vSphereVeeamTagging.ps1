#############################
## vCenter Tagging & Veeam Backup & Replication job builder
## Matt Crape / @MattThatITGuy / 42u.ca
############################

#CSV That contains two columns (Name and Tag)
$csvFile = "c:\temp\VMs.csv"

#vSphere info
$vCenterServerName = "vcenter.42u.local"
$vCenterUserName = "administrator@vsphere.local"
$vCenterPassword = "VMware123!"

#Tag names (used in spreadsheet & vCenter) and Veeam Job Name
$dailyTagName = "Daily"
$weeklyTagName = "Weekly"
$monthlyTagName = "Monthly"

#Retention points for jobs
$dailyRetention = 14
$weeklyRetention = 8
$monthlyRetention = 2

#Veeam Job Settings
$repositoryName = "V drive"
$dailyRunTime = "23:30"
$weeklyRunTime = "0:15"
$monthlyRunTime = "3:00"

#Connect to vCenter
Connect-VIServer -Server $vCenterServerName -User $vCenterUserName -Password $vCenterPassword

#Dump list of VMs - Do this to create spreadsheet for tags
#Get-VM | Select-Object Name | Export-csv $csvFile

#Import based on tag
$listOfDailyVMs = Import-Csv -LiteralPath $csvFile |  Where-Object -FilterScript {$_.Tag -eq $dailyTagName}
$listOfWeeklyVMs = Import-Csv -LiteralPath $csvFile | Where-Object -FilterScript {$_.Tag -eq $weeklyTagName}
$listOfMonthlyVMs = Import-Csv -LiteralPath $csvFile | Where-Object -FilterScript {$_.Tag -eq $monthlyTagName}

#Create Backup Tag Category & Tags
New-TagCategory -Name Backups -Description "Used to define backup jobs"
New-Tag -Category Backups -Name $dailyTagName
New-Tag -Category Backups -Name $weeklyTagName
New-Tag -Category Backups -Name "Monthly"


foreach ($vmDaily in $listOfDailyVMs){
    
    New-TagAssignment -Tag $dailyTagName -Entity $vmDaily.Name
}

foreach ($vmWeekly in $listOfWeeklyVMs){
    
    New-TagAssignment -Tag $weeklyTagName -Entity $vmWeekly.Name
}

foreach ($vmMonthly in $listOfMonthlyVMs){
    
    New-TagAssignment -Tag $monthlyTagName -Entity $vmMonthly.Name
}

#Begin Veeam Job Creation

Add-PSSnapin VeeamPSSnapin


#Create Daily Job

$JobName = $dailyTagName
$VMwareTag = $dailyTagName

$VeeamRepository = Get-VBRBackupRepository -Name $repositoryName
Get-VBRServer -Name $vCenterServerName

$VeeamTag = Find-VBRViEntity -Name $VMwareTag -Tags -Server $vCenterServerName

Add-VBRViBackupJob -Name $JobName -Description 'Daily backup Job' -BackupRepository $VeeamRepository -Entity $VeeamTag
$retentionDaily = New-VBRJobOptions -ForBackupJob
$retentionDaily.BackupStorageOptions.RetainCycles = $dailyRetention
Set-VBRJobOptions -Job $JobName -Options $retentionDaily

Get-VBRJob -Name $JobName | Enable-VBRJobSchedule
Get-VBRJob -Name $JobName | Set-VBRJobSchedule -At $dailyRunTime -DailyKind Everyday

#Create Weekly Job

$JobName = $weeklyTagName
$VMwareTag = $weeklyTagName

$VeeamRepository = Get-VBRBackupRepository -Name $repositoryName
Get-VBRServer -Name $repositoryName

$VeeamTag = Find-VBRViEntity -Name $VMwareTag -Tags -Server $vCenterServerName

Add-VBRViBackupJob -Name $JobName -Description 'Weekly backup Job' -BackupRepository $VeeamRepository -Entity $VeeamTag
$retentionWeekly = New-VBRJobOptions -ForBackupJob
$retentionWeekly.BackupStorageOptions.RetainCycles = $weeklyRetention
Set-VBRJobOptions -Job $JobName -Options $retentionWeekly

Enable-VBRJobSchedule -Job $JobName 
Set-VBRJobSchedule -Job $JobName  -At $weeklyRunTime -DailyKind SelectedDays -Days Saturday

#Create Monthly Job

$JobName = $monthlyTagName
$VMwareTag = $monthlyTagName

$VeeamRepository = Get-VBRBackupRepository -Name $repositoryName
Get-VBRServer -Name $repositoryName

$VeeamTag = Find-VBRViEntity -Name $VMwareTag -Tags -Server $vCenterServerName

Add-VBRViBackupJob -Name $JobName -Description 'Monthly backup Job' -BackupRepository $VeeamRepository -Entity $VeeamTag
$retentionMonthly = New-VBRJobOptions -ForBackupJob
$retentionMonthly.BackupStorageOptions.RetainCycles = $monthlyRetention
Set-VBRJobOptions -Job $JobName -Options $retentionMonthly

Get-VBRJob -Name $JobName | Enable-VBRJobSchedule
Get-VBRJob -Name $JobName | Set-VBRJobSchedule -At $monthlyRunTime -Monthly -NumberInMonth Last -Days Sunday