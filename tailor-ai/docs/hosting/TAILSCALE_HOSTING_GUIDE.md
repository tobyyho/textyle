# Tailscale Hosting Guide

**Reviewed:** 2026-09-12  
**Installed client:** Tailscale 1.102.2 stable

Tailor uses the official Tailscale client on the Windows host. The authenticated
machine is `tailor-server`; its tailnet DNS name is
`tailor-server.tail857b40.ts.net`. MagicDNS and HTTPS capabilities are enabled.
Funnel exposes HTTPS port 443 and proxies only to `http://127.0.0.1:8000`.

Current official documentation states that Funnel is available on all plans,
publishes a local service to the public internet, and does not require the visitor
to use Tailscale. The current CLI accepts a loopback proxy target and supports
background operation. Funnel remains documented as beta, so behavior may change.

Official sources:

- [Tailscale Funnel documentation](https://tailscale.com/docs/features/tailscale-funnel)
- [Tailscale Funnel CLI reference](https://tailscale.com/docs/reference/tailscale-cli/funnel)
- [MagicDNS documentation](https://tailscale.com/docs/features/magicdns)
- [Tailscale pricing](https://tailscale.com/pricing)

Do not expose RDP, SSH, file shares, port 8000 directly, or another local service.
Do not add a router forward or Windows Firewall inbound rule for port 8000.
