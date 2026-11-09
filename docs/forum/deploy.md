# Self-Hosted DSH Community Forum (Optional)

This guide provides Discourse deployment templates for setting up an optional community forum. Configuration files reside in `infra/forum/`. The mobile app operates independently without a self-hosted forum.

All customizable placeholders are formatted as `<<FILL: ...>>`.

## 0. File Overview

| File | Purpose |
|---|---|
| `infra/forum/containers/app.yml` | Container config (Standalone): Discourse binds 80/443 directly and issues Let's Encrypt TLS certificates |
| `infra/forum/containers/app.reverse-proxy.yml` | Container config (Reverse Proxy): When upstream Nginx/Caddy occupies 80/443 |
| `infra/forum/settings/site_settings.yml` | Site settings: SSO callback, trust levels, anti-spam, backups |
| `infra/forum/settings/community.yml` | Categories (Announcements, Plugins, Configurations, Tips, Support, Feedback), tags, and UI labels |
| `infra/forum/settings/secrets.example.yml` | Secret templates for OAuth and S3 storage |
| `infra/forum/scripts/apply.sh` | Automated script to apply settings |
| `infra/forum/scripts/install_theme.sh` | Installs/updates DSH share code preview theme component |
| `infra/forum/theme-dshgo/` | Theme component rendering DSH share links as interactive cards |

## 1. Prerequisites

- **VPS**: Linux (Ubuntu 22.04 / 24.04 LTS), 64-bit; minimum 2 GB RAM (4 GB recommended), 2 vCPU, 40 GB SSD. Open ports: 22, 80, 443.
- **Domain**: Dedicated subdomain (e.g. `forum.example.com`). Set DNS A record pointing to server IPv4.
- **SMTP Provider**: Transactional email service for email confirmations and notifications (Amazon SES, Brevo, Mailgun, Postmark, or Resend). Ensure SPF, DKIM, and DMARC DNS records are configured.

## 2. Deployment Steps

1. Install Docker and clone Discourse Docker setup:
   ```bash
   sudo git clone https://github.com/discourse/discourse_docker.git /var/discourse
   cd /var/discourse
   ```
2. Copy configuration from `infra/forum/containers/app.yml` to `/var/discourse/containers/app.yml`. Fill in domain and SMTP credentials.
3. Build and launch:
   ```bash
   sudo ./launcher rebuild app
   ```
4. Access `https://forum.example.com` to create the initial administrator account.
5. Apply community settings:
   ```bash
   ./infra/forum/scripts/apply.sh
   ```
