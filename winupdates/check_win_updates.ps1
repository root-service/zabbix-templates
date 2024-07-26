$zbxInstallPath = "$env:ProgramData\ZabbixAgent"

$computerDomain = Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem | Select-Object -Expandproperty Domain
$zbxInstallPath = "$env:ProgramData\ZabbixAgent"
$zbxConfigFilePath = "$zbxInstallPath\zabbix_agent2.conf"
$zbxSender = "$zbxInstallPath\zabbix_sender.exe"
$computerName = "$($env:computername).$computerdomain".ToLower()

Write-Host "Computername: $computerName" -ForegroundColor Cyan

$zbxValueTable = @{
	'Winupdates.Critical'       = 0
	'Winupdates.Hidden'         = 0
	'Winupdates.Optional'       = 0
	'Winupdates.Reboot'         = 0
	'Winupdates.LastUpdateDate' = ''
	'Winupdates.Updating'       = 0	
	'Winupdates.LastSearchDate' = ''
}
$windowsUpdateObject = New-Object -ComObject Microsoft.Update.AutoUpdate

$zbxValueTable['Winupdates.LastUpdateDate'] = $windowsUpdateObject.Results.LastInstallationSuccessDate.ToString('yyyy/MM/dd HH:mm')
$zbxValueTable['Winupdates.LastSearchDate'] = $windowsUpdateObject.Results.LastSearchSuccessDate.ToString('yyyy/MM/dd HH:mm')

if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") { 
	$zbxValueTable['Winupdates.Reboot'] = 1
	Write-Host "`t There is a reboot pending" -ForeGroundColor "Red"
}

else {
	Write-Host "`t No reboot pending" -ForeGroundColor "Green"
}

$updateSession = new-object -com "Microsoft.Update.Session"
$updates = $updateSession.CreateupdateSearcher().Search(("IsInstalled=0 and Type='Software'")).Updates

$criticalTitles = "";
$countCritical = 0;
$countOptional = 0;
$countHidden = 0;


foreach ($update in $updates) {
	if ($update.IsHidden) {
		$countHidden++
	}

	if ($update.AutoSelectOnWebSites) {
		$criticalTitles += $update.Title + " `n"
		$countCritical++
	}

	else {
		$countOptional++
	}
}

if (($countCritical + $countOptional) -gt 0) {
	$zbxValueTable['Winupdates.Critical'] = $countCritical
	$zbxValueTable['Winupdates.Optional'] = $countOptional
	$zbxValueTable['Winupdates.Hidden'] = $countHidden
	Write-Host "`t There are $($countCritical) critical updates available" -ForeGroundColor "Yellow"
	Write-Host "`t There are $($countOptional) optional updates available" -ForeGroundColor "Yellow"
	Write-Host "`t There are $($countHidden) hidden updates available" -ForeGroundColor "Yellow"
}	

foreach ($key in $zbxValueTable.Keys.GetEnumerator()) {
	& $zbxSender -c $zbxConfigFilePath -vv -k $key -o "$($zbxValueTable[$key])" -s $computerName
	Write-Host "Command: ($zbxSender -c $zbxConfigFilePath -vv -k $key -o $($zbxValueTable[$key]) -s $computerName)"  -ForegroundColor Cyan
}

$zbxValueTable['DateTime'] = (Get-Date -Format "yyyy-MM-dd_HH-mm-ss").ToString()
$zbxValueTable | Out-String | Out-File $PSScriptRoot\winUpdateData.txt -Encoding utf8 -Force