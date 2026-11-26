param([switch]$DryRun)
if($DryRun){[pscustomobject]@{Command='tailscale funnel reset';RemovesOnlyFunnel=$true};exit}
if(!(Get-Command tailscale -ErrorAction SilentlyContinue)){throw 'Tailscale is not installed.'};& tailscale funnel reset
