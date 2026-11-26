$ErrorActionPreference='Stop';if(!(Get-Command tailscale -ErrorAction SilentlyContinue)){throw 'Tailscale is not installed.'};& tailscale status;& tailscale funnel status --json
