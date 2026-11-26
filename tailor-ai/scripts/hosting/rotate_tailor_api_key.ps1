param([string]$KeyPath='C:\TextyleData\tailor\secrets\tailor_api_key.txt')
$ErrorActionPreference='Stop'
$parent=Split-Path -Parent $KeyPath
New-Item -ItemType Directory -Force -Path $parent | Out-Null
$bytes=New-Object byte[] 48
$generator=[Security.Cryptography.RandomNumberGenerator]::Create()
$generator.GetBytes($bytes)
$generator.Dispose()
$value=[Convert]::ToBase64String($bytes).Replace('+','-').Replace('/','_').TrimEnd('=')
$temporary="$KeyPath.new"
[IO.File]::WriteAllText($temporary,$value,[Text.UTF8Encoding]::new($false))
$user=[Security.Principal.WindowsIdentity]::GetCurrent().Name
& icacls $temporary /inheritance:r /grant:r "${user}:(F)" 'SYSTEM:(F)' | Out-Null
Move-Item -Force -LiteralPath $temporary -Destination $KeyPath
Write-Host 'Tailor API key rotated without displaying it. Restart Tailor before further requests.'
