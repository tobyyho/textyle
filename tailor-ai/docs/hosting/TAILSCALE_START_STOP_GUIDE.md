# Tailor Start and Stop Guide

Run these commands from `C:\Textyle\tailor-ai` in PowerShell. They use a process-
scoped execution-policy bypass and do not change the system policy.

## Start

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\hosting\start_tailor_host.ps1
```

Wait for `Tailor ready at http://127.0.0.1:8000`. The script verifies readiness and
records the actual loopback listener process, not the short-lived wrapper process.
The existing background Funnel automatically resumes serving the same public URL.

## Status

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\hosting\status_tailor_host.ps1
```

## Stop

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\hosting\stop_tailor_host.ps1
```

Stopping Tailor leaves the Funnel configuration present, but visitors receive an
upstream error until Tailor is started again. To deliberately remove the public
Funnel as well, use `remove_tailscale_funnel.ps1`; re-enable it later with
`configure_tailscale_funnel.ps1`.

The manual start/stop workflow is the accepted default. Startup automation and
Windows sleep changes remain opt-in and are not enabled.
