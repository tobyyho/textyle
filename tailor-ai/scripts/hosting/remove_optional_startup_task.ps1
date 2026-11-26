param([switch]$DryRun)
if($DryRun){[pscustomobject]@{Task='TailorPrototypeAtLogon';WouldRemove=$true};exit}
& schtasks.exe /Delete /TN TailorPrototypeAtLogon /F
