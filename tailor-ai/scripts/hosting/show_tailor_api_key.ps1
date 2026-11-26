param([string]$KeyPath='C:\TextyleData\tailor\secrets\tailor_api_key.txt')
$ErrorActionPreference='Stop'
Write-Warning 'This displays the private prototype API key locally. Do not paste it into chat or commit it.'
Get-Content -Raw -LiteralPath $KeyPath
