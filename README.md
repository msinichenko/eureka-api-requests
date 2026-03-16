# eureka-requests

Bruno collection for FOLIO/Eureka operational and migration requests (Keycloak, consortia, MGR, reindex, users/roles, mark migrations, and related modules).

## Requirements

- [Bruno](https://www.usebruno.com/) desktop app
- Network access to your target FOLIO/Kong/Keycloak environment
- Valid tenant/client/user credentials for the target environment

## Quick Start

1. Open this folder in Bruno.
2. Create/select an environment (e.g. `local`, `dev`, `int`, `prod-like`).
3. Define required variables (see below).
4. Run auth requests first (recommended order):
   - `auth/get-keycloak-tenant-token`
   - `auth/get-keycloak-master-realm-admin-token` (if you use Keycloak admin endpoints)
   - `auth/user-login-token` (if you use cookie-based user token flows)
5. Run the target request(s) from the relevant folder.

## Required Environment Variables

Most requests rely on these variables:

- `folio` — environment prefix used in hostnames
- `domain` — base domain (for Kong/Keycloak)
- `realm` — tenant realm / `x-okapi-tenant`
- `tenant_client` — Keycloak client id for tenant token
- `tenant_client_secret` — Keycloak client secret
- `keycloak_username` — Keycloak admin/service username
- `keycloak_password` — Keycloak admin/service password
- `tenant_username` — user login username (for login-with-expiry flows)
- `tenant_password` — user login password

These are set automatically by auth scripts when token requests succeed:

- `okapi-token`
- `master-realm-token`
- `folio-user-token`

## Collection Layout

Top-level folders are grouped by capability:

- `auth/` — token acquisition and login flows
- `mgr/` — manager applications, discovery, entitlements, tenant actions
- `consortia/` — consortia tenant and affiliation operations
- `users-roles/` — users, roles, capabilities, migrations
- `reindex/` — reindex and inventory/instance workflows
- `mark-migrations/` — MARC remap/save/retry/error-report flows
- `Keycloak/` — Keycloak realm/client/user admin requests
- `inventory-storage migration/`, `timers/`, `mod-reading-room/`, `mod-record-specification/`, `bulk operations/`, `maping rules/`, `Module reinstall/`

## Usage Notes

- Many requests assume `x-okapi-token` and `x-okapi-tenant` are already available.
- Several requests use path/query IDs that are environment-specific; replace with your own IDs before running.
- Some requests have duplicate `Copy` variants used as working examples.

## Security / Sanitization

Before sharing or committing changes:

- Never commit real tokens, passwords, or client secrets.
- Keep credentials only in Bruno environment variables.
- Replace hardcoded IDs/tenant names/emails with placeholders where possible.
- Avoid storing long-lived tokens in files.

## Suggested Workflow

1. Authenticate using `auth/` requests.
2. Execute read-only GET checks first.
3. Execute write/update/delete requests only after verifying tenant and IDs.
4. Re-run token requests if you receive authentication/expiry errors.
