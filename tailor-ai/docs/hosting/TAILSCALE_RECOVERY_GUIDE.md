# Tailscale Recovery Guide

1. Confirm Tailor locally: run `status_tailor_host.ps1` and open
   `http://127.0.0.1:8000/readyz`.
2. If Tailor is stopped, run `start_tailor_host.ps1`. If port 8000 belongs to another
   process, do not terminate it blindly; identify the owner first.
3. Check `tailscale status` and `tailscale funnel status --json`.
4. The only expected mapping is HTTPS 443 on
   `tailor-server.tail857b40.ts.net` to `http://127.0.0.1:8000`.
5. If authentication has expired, use the official Tailscale UI to sign in. Never
   share a password, recovery code, reusable auth key, or API token.
6. If the mapping is absent and the confirmed plan remains free, run
   `configure_tailscale_funnel.ps1`. Do not accept a paid trial or enter billing.
7. Run `remote_acceptance_test.py` against the public HTTPS base URL.

Renaming the machine or tailnet can change or break the public URL. Funnel is beta,
and the host PC, network, power, API process, certificate provisioning, or Tailscale
control plane can each affect availability.
