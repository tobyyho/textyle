param([switch]$DryRun)
$ErrorActionPreference='Stop'
if($DryRun){[pscustomobject]@{Command='tailscale funnel --bg --https=443 http://127.0.0.1:8000';PublicPort=443;Target='http://127.0.0.1:8000';ChangesFirewall=$false;ChangesRouter=$false};exit}
if(!(Get-Command tailscale -ErrorAction SilentlyContinue)){throw 'Official Tailscale CLI is not installed.'}
& tailscale funnel --bg --https=443 http://127.0.0.1:8000
if($LASTEXITCODE){throw 'Tailscale Funnel configuration failed.'}
& tailscale funnel status
