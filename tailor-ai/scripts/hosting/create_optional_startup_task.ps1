param([switch]$DryRun)
$project=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path;$start=Join-Path $project 'scripts\hosting\start_tailor_host.ps1';$command="powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$start`""
if($DryRun){[pscustomobject]@{Task='TailorPrototypeAtLogon';Trigger='current user logon';Command=$command;ChangesSleep=$false;Installed=$false};exit}
Write-Warning 'This opt-in task starts Tailor at user logon and can increase electricity use. Windows sleep remains unchanged.'
& schtasks.exe /Create /TN TailorPrototypeAtLogon /SC ONLOGON /TR $command /RL LIMITED /F
